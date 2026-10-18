#!/usr/bin/env python3
"""
Tier 5 Adversarial and Robustness Test Suite for watch_antigravity.py (Milestone 1).

Covers:
1. High filesystem turnover: rapid creation/removal of 100 SQLite WAL files under concurrent polling.
2. Malformed data resilience: truncated, empty, garbage, schema-invalid, and locked SQLite files.
3. Race conditions: files deleted or checkpointed while read transactions begin; concurrent WAL writers.
4. Process signal handling and flock release on termination (SIGTERM, SIGINT, SIGKILL, parent death, BrokenPipe).
5. Burst workload performance and resource utilization (50-100 concurrent active agents, memory stability).
"""

import unittest
import tempfile
import sqlite3
import os
import sys
import time
import json
import threading
import subprocess
import fcntl
import signal
import psutil
from pathlib import Path

# Add project root and scripts directory to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import watch_antigravity as wa


def create_test_db(db_path: str, step_statuses: list[int] = None, parent_id: str = None, nesting_depth: int = 0):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode=WAL")
    cur.execute("CREATE TABLE steps (idx INTEGER PRIMARY KEY, status INTEGER)")
    if step_statuses:
        for idx, s in enumerate(step_statuses, start=1):
            cur.execute("INSERT INTO steps VALUES (?, ?)", (idx, s))
    cur.execute("CREATE TABLE trajectory_metadata_blob (id TEXT PRIMARY KEY, data BLOB)")
    if parent_id is not None or nesting_depth > 0:
        out = bytearray()
        if parent_id:
            out.extend(b"\x2a")
            pid_bytes = parent_id.encode("utf-8")
            out.append(len(pid_bytes))
            out.extend(pid_bytes)
        if nesting_depth > 0:
            out.extend(b"\x88\x01")  # tag 17 wire 0
            out.append(nesting_depth)
        cur.execute("INSERT INTO trajectory_metadata_blob VALUES ('main', ?)", (bytes(out),))
    conn.commit()
    conn.close()


class TestHighFilesystemTurnover(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_rapid_creation_and_removal_100_wal_files(self):
        """Rapidly create and remove 100 SQLite WAL files while check_state is executing."""
        num_cycles = 100
        stop_event = threading.Event()
        errors = []

        def churn_worker():
            for i in range(num_cycles):
                cid = f"turnover_agent_{i}"
                db_p = os.path.join(self.conv_dir, f"{cid}.db")
                wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
                try:
                    create_test_db(db_p, step_statuses=[2], parent_id="root_1")
                    with open(wal_p, "wb") as f:
                        f.write(b"\x00" * 4096)
                    time.sleep(0.001)
                    if os.path.exists(wal_p):
                        os.unlink(wal_p)
                    if os.path.exists(db_p):
                        os.unlink(db_p)
                except Exception as ex:
                    errors.append(f"Worker error at cycle {i}: {ex}")
            stop_event.set()

        worker_thread = threading.Thread(target=churn_worker)
        worker_thread.start()

        checks_performed = 0
        while not stop_event.is_set():
            try:
                res = wa.check_state(conv_dir=self.conv_dir)
                self.assertIsInstance(res, dict)
                self.assertIn("active", res)
                self.assertIn("subagents", res)
                self.assertIn("total", res)
                checks_performed += 1
            except Exception as e:
                self.fail(f"check_state crashed during rapid turnover: {e}")
            time.sleep(0.0005)

        worker_thread.join(timeout=5)
        self.assertEqual(len(errors), 0, f"Worker errors: {errors}")
        self.assertGreater(checks_performed, 20, "Should perform multiple state checks during turnover")

        final_res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(final_res, {"active": False, "subagents": 0, "total": 0})

    def test_burst_100_wal_files_simultaneous_churn(self):
        """Create 100 WAL files simultaneously, poll, then remove all 100."""
        file_pairs = []
        for i in range(100):
            cid = f"burst_turnover_{i}"
            db_p = os.path.join(self.conv_dir, f"{cid}.db")
            wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
            create_test_db(db_p, step_statuses=[2], parent_id=f"parent_{i % 5}")
            with open(wal_p, "wb") as f:
                f.write(b"wal_data" * 64)
            file_pairs.append((db_p, wal_p))

        res_full = wa.check_state(conv_dir=self.conv_dir)
        self.assertTrue(res_full["active"])
        self.assertEqual(res_full["total"], 100)
        self.assertEqual(res_full["subagents"], 100)

        for db_p, wal_p in file_pairs:
            if os.path.exists(wal_p):
                try: os.unlink(wal_p)
                except OSError: pass
            if os.path.exists(db_p):
                try: os.unlink(db_p)
                except OSError: pass

        res_cleared = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res_cleared, {"active": False, "subagents": 0, "total": 0})


class TestMalformedDataResilience(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_empty_zero_byte_db_file(self):
        """0-byte .db file with non-empty .db-wal."""
        db_p = os.path.join(self.conv_dir, "empty.db")
        wal_p = os.path.join(self.conv_dir, "empty.db-wal")
        with open(db_p, "wb") as f:
            pass
        with open(wal_p, "wb") as f:
            f.write(b"wal")
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_truncated_db_files_varying_sizes(self):
        """Truncated .db files from 1 to 120 bytes."""
        for size in [1, 15, 32, 64, 99, 100, 101, 120]:
            with self.subTest(size=size):
                cid = f"trunc_{size}"
                db_p = os.path.join(self.conv_dir, f"{cid}.db")
                wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
                with open(db_p, "wb") as f:
                    f.write(b"SQLite format 3\x00"[:size].ljust(size, b"\x00"))
                with open(wal_p, "wb") as f:
                    f.write(b"wal" * 10)
                res = wa.check_state(conv_dir=self.conv_dir)
                self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})
                if os.path.exists(db_p):
                    try: os.unlink(db_p)
                    except OSError: pass
                if os.path.exists(wal_p):
                    try: os.unlink(wal_p)
                    except OSError: pass

    def test_pure_garbage_binary_data(self):
        """Completely random binary garbage in DB and WAL."""
        db_p = os.path.join(self.conv_dir, "garbage.db")
        wal_p = os.path.join(self.conv_dir, "garbage.db-wal")
        with open(db_p, "wb") as f:
            f.write(os.urandom(8192))
        with open(wal_p, "wb") as f:
            f.write(os.urandom(4096))
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_invalid_steps_schema(self):
        """Valid SQLite DB but steps table has wrong columns or unexpected types."""
        db_p = os.path.join(self.conv_dir, "bad_schema.db")
        wal_p = os.path.join(self.conv_dir, "bad_schema.db-wal")
        conn = sqlite3.connect(db_p)
        conn.execute("CREATE TABLE steps (wrong_col TEXT, another_col BLOB)")
        conn.execute("INSERT INTO steps VALUES ('some_string', X'010203')")
        conn.commit()
        conn.close()
        with open(wal_p, "wb") as f:
            f.write(b"wal")

        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_steps_table_null_and_string_statuses(self):
        """Steps table containing NULL, strings, and out-of-range floats."""
        for bad_status in [None, "ACTIVE", "RUNNING", 99999, -1, 3.1415]:
            with self.subTest(status=bad_status):
                cid = f"status_{hash(bad_status)}"
                db_p = os.path.join(self.conv_dir, f"{cid}.db")
                wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
                conn = sqlite3.connect(db_p)
                conn.execute("CREATE TABLE steps (idx INTEGER PRIMARY KEY, status)")
                conn.execute("INSERT INTO steps VALUES (1, ?)", (bad_status,))
                conn.commit()
                conn.close()
                with open(wal_p, "wb") as f:
                    f.write(b"wal")

                res = wa.check_state(conv_dir=self.conv_dir)
                self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})
                if os.path.exists(db_p):
                    try: os.unlink(db_p)
                    except OSError: pass
                if os.path.exists(wal_p):
                    try: os.unlink(wal_p)
                    except OSError: pass

    def test_corrupted_protobuf_payloads(self):
        """Adversarial protobuf blobs: massive varint, invalid wire type, truncated length."""
        bad_blobs = [
            b"\x80" * 10000,  # Never-ending varint stream
            b"\x2a\xff\xff",  # Tag 5 with huge length but truncated data
            b"\x0b\x01\x02",  # Tag 1 with wire_type 3 (start group - invalid)
            b"\x0f",          # Tag 1 with wire_type 7 (reserved/invalid)
            b"\x2a\x00",      # Tag 5 with 0 length
            b"\x88\x01\x80\x80\x80\x80\x80\x01",  # Deep nesting varint
        ]
        for idx, blob in enumerate(bad_blobs):
            with self.subTest(blob_idx=idx):
                parsed = wa.parse_metadata_blob(blob)
                self.assertIsInstance(parsed, dict)
                self.assertIn("is_subagent", parsed)

    def test_exclusive_locked_db(self):
        """Database locked by an exclusive transaction in another connection."""
        db_p = os.path.join(self.conv_dir, "locked.db")
        wal_p = os.path.join(self.conv_dir, "locked.db-wal")
        create_test_db(db_p, step_statuses=[2])
        with open(wal_p, "wb") as f:
            f.write(b"wal")

        locking_conn = sqlite3.connect(db_p)
        locking_conn.execute("BEGIN EXCLUSIVE")

        try:
            t0 = time.perf_counter()
            res = wa.check_state(conv_dir=self.conv_dir)
            t1 = time.perf_counter()
            self.assertIsInstance(res, dict)
            self.assertLess(t1 - t0, 1.0)
        finally:
            locking_conn.rollback()
            locking_conn.close()

    def test_massive_steps_history_b_tree(self):
        """Database with 10,000 completed steps and 1 active step at the end."""
        db_p = os.path.join(self.conv_dir, "massive.db")
        wal_p = os.path.join(self.conv_dir, "massive.db-wal")
        conn = sqlite3.connect(db_p)
        conn.execute("CREATE TABLE steps (idx INTEGER PRIMARY KEY, status INTEGER)")
        conn.executemany("INSERT INTO steps VALUES (?, 3)", [(i,) for i in range(1, 10001)])
        conn.execute("INSERT INTO steps VALUES (10001, 2)")
        conn.commit()
        conn.close()

        with open(wal_p, "wb") as f:
            f.write(b"wal")

        t0 = time.perf_counter()
        res = wa.check_state(conv_dir=self.conv_dir)
        t1 = time.perf_counter()

        self.assertTrue(res["active"])
        self.assertEqual(res["total"], 1)
        lookup_ms = (t1 - t0) * 1000.0
        self.assertLess(lookup_ms, 5.0, f"B-tree index lookup took {lookup_ms:.2f} ms")


class TestRaceConditions(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_db_deleted_between_scandir_and_connect(self):
        """Simulate db deletion right after active_wals list is constructed."""
        db_p = os.path.join(self.conv_dir, "race_agent.db")
        wal_p = os.path.join(self.conv_dir, "race_agent.db-wal")
        create_test_db(db_p, step_statuses=[2])
        with open(wal_p, "wb") as f:
            f.write(b"wal")

        os.unlink(db_p)
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_wal_deleted_concurrently_with_check(self):
        """Concurrent thread unlinks WAL files right as check_state iterates."""
        db_p = os.path.join(self.conv_dir, "race2.db")
        wal_p = os.path.join(self.conv_dir, "race2.db-wal")
        create_test_db(db_p, step_statuses=[2])

        def deleter():
            time.sleep(0.002)
            if os.path.exists(wal_p):
                try:
                    os.unlink(wal_p)
                except OSError:
                    pass

        for _ in range(20):
            with open(wal_p, "wb") as f:
                f.write(b"wal_data")
            t = threading.Thread(target=deleter)
            t.start()
            res = wa.check_state(conv_dir=self.conv_dir)
            self.assertIsInstance(res, dict)
            t.join()

    def test_concurrent_active_sqlite_writer_and_checkpointer(self):
        """Concurrent SQLite writer committing steps and running wal_checkpoint while checking state."""
        db_p = os.path.join(self.conv_dir, "active_writer.db")
        wal_p = os.path.join(self.conv_dir, "active_writer.db-wal")
        create_test_db(db_p, step_statuses=[2], parent_id="root_writer")

        stop_writer = threading.Event()
        started_event = threading.Event()
        writer_errors = []

        def writer():
            conn = sqlite3.connect(db_p, timeout=1.0)
            conn.execute("PRAGMA journal_mode=WAL")
            step = 10
            conn.execute("INSERT INTO steps VALUES (?, 2)", (step,))
            conn.commit()
            started_event.set()
            while not stop_writer.is_set():
                try:
                    step += 1
                    conn.execute("INSERT INTO steps VALUES (?, 2)", (step,))
                    conn.commit()
                    if step % 5 == 0:
                        conn.execute("PRAGMA wal_checkpoint(PASSIVE)")
                    time.sleep(0.001)
                except Exception as ex:
                    writer_errors.append(str(ex))
            conn.close()

        w_thread = threading.Thread(target=writer)
        w_thread.start()
        started_event.wait(timeout=2)

        meta_cache = {}
        for _ in range(100):
            res = wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)
            self.assertTrue(res["active"])
            self.assertEqual(res["total"], 1)
            time.sleep(0.001)

        stop_writer.set()
        w_thread.join(timeout=3)
        self.assertEqual(len(writer_errors), 0, f"Writer errors: {writer_errors}")


class TestSignalHandlingAndFlock(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.lock_p = os.path.join(self.temp_dir.name, "signal_test.lock")
        self.status_p = os.path.join(self.temp_dir.name, "signal_test_status.json")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_sigterm_handling_and_lock_release(self):
        """Verify process handles SIGTERM cleanly (exit 0) and releases flock immediately."""
        proc = subprocess.Popen(
            [
                sys.executable,
                str(SCRIPTS_DIR / "watch_antigravity.py"),
                "--lock-file", self.lock_p,
                "--status-file", self.status_p,
                "--no-prctl",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            proc.stdout.readline()

            fd_blocked = wa.acquire_lock(self.lock_p)
            self.assertIsNone(fd_blocked, "Second lock acquisition should fail while process runs")

            proc.terminate()
            proc.wait(timeout=3)
            self.assertEqual(proc.returncode, 0, "SIGTERM must exit with returncode 0")

            fd_acquired = wa.acquire_lock(self.lock_p)
            self.assertIsNotNone(fd_acquired, "Lock must be released immediately after SIGTERM exit")
            fcntl.flock(fd_acquired, fcntl.LOCK_UN)
            fd_acquired.close()
        finally:
            if proc.stdout: proc.stdout.close()
            if proc.stderr: proc.stderr.close()
            if proc.poll() is None:
                proc.kill()
                proc.wait()

    def test_sigint_handling_and_lock_release(self):
        """Verify process handles SIGINT cleanly (exit 0) and releases flock immediately."""
        proc = subprocess.Popen(
            [
                sys.executable,
                str(SCRIPTS_DIR / "watch_antigravity.py"),
                "--lock-file", self.lock_p,
                "--status-file", self.status_p,
                "--no-prctl",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            proc.stdout.readline()

            proc.send_signal(signal.SIGINT)
            proc.wait(timeout=3)
            self.assertEqual(proc.returncode, 0, "SIGINT must exit with returncode 0")

            fd_acquired = wa.acquire_lock(self.lock_p)
            self.assertIsNotNone(fd_acquired, "Lock must be released immediately after SIGINT exit")
            fcntl.flock(fd_acquired, fcntl.LOCK_UN)
            fd_acquired.close()
        finally:
            if proc.stdout: proc.stdout.close()
            if proc.stderr: proc.stderr.close()
            if proc.poll() is None:
                proc.kill()
                proc.wait()

    def test_sigkill_kernel_flock_release(self):
        """Verify OS kernel automatically releases flock even on uncatchable SIGKILL."""
        proc = subprocess.Popen(
            [
                sys.executable,
                str(SCRIPTS_DIR / "watch_antigravity.py"),
                "--lock-file", self.lock_p,
                "--status-file", self.status_p,
                "--no-prctl",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            proc.stdout.readline()

            proc.kill()
            proc.wait(timeout=3)

            fd_acquired = wa.acquire_lock(self.lock_p)
            self.assertIsNotNone(fd_acquired, "Lock must be released immediately after SIGKILL")
            fcntl.flock(fd_acquired, fcntl.LOCK_UN)
            fd_acquired.close()
        finally:
            if proc.stdout: proc.stdout.close()
            if proc.stderr: proc.stderr.close()
            if proc.poll() is None:
                proc.kill()
                proc.wait()

    def test_broken_pipe_termination_and_lock_release(self):
        """Verify daemon terminates and releases flock when stdout pipe breaks."""
        proc = subprocess.Popen(
            [
                sys.executable,
                str(SCRIPTS_DIR / "watch_antigravity.py"),
                "--conv-dir", self.temp_dir.name,
                "--lock-file", self.lock_p,
                "--status-file", self.status_p,
                "--no-prctl",
                "--interval", "0.01",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            proc.stdout.readline()
            # Close the reader side of stdout
            proc.stdout.close()

            # Now create an active DB to trigger print() in the loop
            create_test_db(os.path.join(self.temp_dir.name, "conv.db"), step_statuses=[2])
            with open(os.path.join(self.temp_dir.name, "conv.db-wal"), "wb") as f:
                f.write(b"data")

            # Process must terminate within 3 seconds
            ret = proc.wait(timeout=3)
            # Python prints BrokenPipeError during final stdout flush and returns 120 or 0
            self.assertIn(ret, (0, 120), f"Process should terminate on BrokenPipe, returned {ret}")

            # Verify flock is freed immediately upon termination
            fd_acquired = wa.acquire_lock(self.lock_p)
            self.assertIsNotNone(fd_acquired, "Lock must be released after BrokenPipe termination")
            if fd_acquired:
                fcntl.flock(fd_acquired, fcntl.LOCK_UN)
                fd_acquired.close()
        finally:
            if proc.stderr: proc.stderr.close()
            if proc.poll() is None:
                proc.kill()
                proc.wait()

    def test_parent_death_lifecycle_termination(self):
        """Verify child terminates when parent dies (via PPID or PR_SET_PDEATHSIG)."""
        parent_script = f"""
import subprocess, sys, time, os
child = subprocess.Popen([
    sys.executable,
    '{SCRIPTS_DIR / "watch_antigravity.py"}',
    '--lock-file', '{self.lock_p}',
    '--status-file', '{self.status_p}'
], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
child.stdout.readline()
print(child.pid, flush=True)
sys.exit(0)
"""
        parent_proc = subprocess.Popen(
            [sys.executable, "-c", parent_script],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        child_pid_str = parent_proc.stdout.readline().decode().strip()
        self.assertTrue(child_pid_str.isdigit())
        child_pid = int(child_pid_str)

        parent_proc.stdout.close()
        parent_proc.stderr.close()
        parent_proc.wait(timeout=2)
        self.assertEqual(parent_proc.returncode, 0)

        child_dead = False
        for _ in range(20):
            time.sleep(0.1)
            try:
                p = psutil.Process(child_pid)
                if not p.is_running() or p.status() == psutil.STATUS_ZOMBIE:
                    child_dead = True
                    break
            except psutil.NoSuchProcess:
                child_dead = True
                break

        self.assertTrue(child_dead, f"Child process {child_pid} should terminate when parent dies")

        fd_acquired = wa.acquire_lock(self.lock_p)
        self.assertIsNotNone(fd_acquired, "Lock must be released after child termination")
        if fd_acquired:
            fcntl.flock(fd_acquired, fcntl.LOCK_UN)
            fd_acquired.close()


class TestBurstWorkloadAndResourceUtilization(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_burst_50_active_conversations_benchmark(self):
        """Simulate 50 concurrent active conversations (40 subagents, 10 root)."""
        num_convs = 50
        for i in range(num_convs):
            cid = f"active_agent_{i}"
            db_p = os.path.join(self.conv_dir, f"{cid}.db")
            wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
            is_sub = (i % 5 != 0)
            pid = "root_parent" if is_sub else None
            depth = 1 if is_sub else 0
            create_test_db(db_p, step_statuses=[2], parent_id=pid, nesting_depth=depth)
            with open(wal_p, "wb") as f:
                f.write(b"wal_burst_data" * 32)

        meta_cache = {}
        wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)

        iterations = 100
        latencies = []
        for _ in range(iterations):
            t0 = time.perf_counter()
            res = wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)
            t1 = time.perf_counter()
            latencies.append((t1 - t0) * 1000.0)

        avg_lat = sum(latencies) / len(latencies)
        p95_lat = sorted(latencies)[int(len(latencies) * 0.95)]
        max_lat = max(latencies)

        print(f"\n[BURST BENCHMARK - 50 CONVS] Avg: {avg_lat:.3f} ms | P95: {p95_lat:.3f} ms | Max: {max_lat:.3f} ms")
        self.assertTrue(res["active"])
        self.assertEqual(res["total"], 50)
        self.assertEqual(res["subagents"], 40)

        self.assertLess(avg_lat, 10.0, f"Average latency {avg_lat:.2f} ms exceeds 10.0 ms under 50-conv burst")

    def test_burst_100_active_conversations_benchmark(self):
        """Simulate 100 concurrent active conversations (80 subagents, 20 root)."""
        num_convs = 100
        for i in range(num_convs):
            cid = f"burst_100_{i}"
            db_p = os.path.join(self.conv_dir, f"{cid}.db")
            wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
            is_sub = (i % 5 != 0)
            pid = "root_parent" if is_sub else None
            depth = 1 if is_sub else 0
            create_test_db(db_p, step_statuses=[2], parent_id=pid, nesting_depth=depth)
            with open(wal_p, "wb") as f:
                f.write(b"wal_data" * 16)

        meta_cache = {}
        wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)

        iterations = 50
        latencies = []
        for _ in range(iterations):
            t0 = time.perf_counter()
            res = wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)
            t1 = time.perf_counter()
            latencies.append((t1 - t0) * 1000.0)

        avg_lat = sum(latencies) / len(latencies)
        p95_lat = sorted(latencies)[int(len(latencies) * 0.95)]
        max_lat = max(latencies)

        print(f"[BURST BENCHMARK - 100 CONVS] Avg: {avg_lat:.3f} ms | P95: {p95_lat:.3f} ms | Max: {max_lat:.3f} ms")
        self.assertTrue(res["active"])
        self.assertEqual(res["total"], 100)
        self.assertEqual(res["subagents"], 80)
        self.assertLess(avg_lat, 20.0, f"Average latency {avg_lat:.2f} ms exceeds 20.0 ms under 100-conv burst")

    def test_rapid_state_change_throughput(self):
        """Measure throughput during 100 alternating active/idle transitions."""
        cid = "rapid_toggle"
        db_p = os.path.join(self.conv_dir, f"{cid}.db")
        wal_p = os.path.join(self.conv_dir, f"{cid}.db-wal")
        create_test_db(db_p, step_statuses=[2], parent_id="root_toggle")

        meta_cache = {}
        t0 = time.perf_counter()
        transitions = 50
        for i in range(transitions):
            with open(wal_p, "wb") as f:
                f.write(b"data")
            wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)
            if os.path.exists(wal_p):
                os.unlink(wal_p)
            wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)
        t1 = time.perf_counter()

        elapsed = t1 - t0
        rate = (transitions * 2) / elapsed
        print(f"[THROUGHPUT] Executed {transitions * 2} state checks in {elapsed:.3f}s ({rate:.1f} checks/sec)")
        self.assertGreater(rate, 200.0, "State checking rate should exceed 200 checks/sec")

    def test_meta_cache_bounding(self):
        """Verify meta_cache clears when exceeding 2000 entries to prevent memory leaks."""
        meta_cache = {}
        db_p = os.path.join(self.conv_dir, "cache_bound.db")
        create_test_db(db_p, step_statuses=[2], parent_id="root_parent")

        for i in range(2005):
            meta_cache[f"dummy_{i}"] = False

        self.assertEqual(len(meta_cache), 2005)
        wa.is_conversation_subagent(db_p, "new_cid", meta_cache)
        self.assertEqual(len(meta_cache), 1)
        self.assertIn("new_cid", meta_cache)

    def test_active_workload_cpu_utilization(self):
        """Measure CPU utilization of the daemon under active multi-agent workload over 2 seconds."""
        lock_file = os.path.join(self.conv_dir, "bench_active.lock")
        status_file = os.path.join(self.conv_dir, "bench_active_status.json")

        for i in range(5):
            db_p = os.path.join(self.conv_dir, f"active_cpu_{i}.db")
            wal_p = os.path.join(self.conv_dir, f"active_cpu_{i}.db-wal")
            create_test_db(db_p, step_statuses=[2], parent_id="root_cpu" if i > 0 else None)
            with open(wal_p, "wb") as f:
                f.write(b"wal_cpu_data" * 16)

        proc = subprocess.Popen(
            [
                sys.executable,
                str(SCRIPTS_DIR / "watch_antigravity.py"),
                "--conv-dir", self.conv_dir,
                "--lock-file", lock_file,
                "--status-file", status_file,
                "--no-prctl",
                "--interval", "0.15",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            line = proc.stdout.readline().decode().strip()
            self.assertTrue(len(line) > 0)

            p = psutil.Process(proc.pid)
            c_start = p.cpu_times()
            t_start = time.perf_counter()

            time.sleep(2.0)

            t_end = time.perf_counter()
            c_end = p.cpu_times()

            wall = t_end - t_start
            cpu_time = (c_end.user - c_start.user) + (c_end.system - c_start.system)
            cpu_pct = (cpu_time / wall) * 100.0

            print(f"[ACTIVE CPU BENCHMARK] Active CPU% over {wall:.2f}s with 5 active tasks: {cpu_pct:.4f}% CPU")
            self.assertLess(cpu_pct, 5.0, f"Active CPU% {cpu_pct:.4f}% exceeds 5.0% limit")
        finally:
            proc.terminate()
            if proc.stdout: proc.stdout.close()
            if proc.stderr: proc.stderr.close()
            proc.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)
