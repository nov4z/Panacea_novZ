#!/usr/bin/env python3
"""
Comprehensive test suite and performance benchmark for watch_antigravity.py.
Verifies:
- Idle detection across various empty/dormant states
- Active step status filtering (1, 2, 8, 11) and step ordering
- Subagent identification via protobuf trajectory metadata
- Newline-delimited JSON streaming, immediate flushing, and diffing
- Single-instance locking behavior
- Fault tolerance against corrupted, missing, or locked files
- Performance benchmark: loop time < 1 ms and steady-state CPU < 0.05%
"""

import unittest
import tempfile
import sqlite3
import os
import sys
import time
import json
import io
import subprocess
import fcntl
import psutil
from unittest.mock import patch

# Import functions from watch_antigravity
import watch_antigravity as wa


def encode_varint(val: int) -> bytes:
    """Encodes an integer into protobuf varint bytes."""
    res = bytearray()
    while True:
        b = val & 0x7F
        val >>= 7
        if val:
            res.append(b | 0x80)
        else:
            res.append(b)
            break
    return bytes(res)


def create_metadata_blob(parent_id: str = None, nesting_depth: int = 0, root_id: str = None) -> bytes:
    """Builds a valid protobuf trajectory_metadata_blob for testing."""
    out = bytearray()
    if parent_id is not None:
        out.extend(encode_varint((5 << 3) | 2))
        pid_bytes = parent_id.encode("utf-8")
        out.extend(encode_varint(len(pid_bytes)))
        out.extend(pid_bytes)
    if root_id is not None:
        out.extend(encode_varint((6 << 3) | 2))
        rid_bytes = root_id.encode("utf-8")
        out.extend(encode_varint(len(rid_bytes)))
        out.extend(rid_bytes)
    if nesting_depth > 0:
        out.extend(encode_varint((17 << 3) | 0))
        out.extend(encode_varint(nesting_depth))
    return bytes(out)


def create_mock_conversation(
    conv_dir: str,
    conv_id: str,
    step_statuses: list[int] = None,
    parent_id: str = None,
    nesting_depth: int = 0,
    wal_size: int = 1024,
) -> tuple[str, str]:
    """
    Creates a mock SQLite conversation database and corresponding .db-wal file.
    """
    db_path = os.path.join(conv_dir, f"{conv_id}.db")
    wal_path = os.path.join(conv_dir, f"{conv_id}.db-wal")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Steps table
    cur.execute("CREATE TABLE steps (idx INTEGER PRIMARY KEY, status INTEGER)")
    if step_statuses:
        for idx, status in enumerate(step_statuses, start=1):
            cur.execute("INSERT INTO steps VALUES (?, ?)", (idx, status))

    # Metadata table
    cur.execute("CREATE TABLE trajectory_metadata_blob (id TEXT PRIMARY KEY, data BLOB)")
    meta_bytes = create_metadata_blob(parent_id=parent_id, nesting_depth=nesting_depth)
    cur.execute("INSERT INTO trajectory_metadata_blob VALUES ('main', ?)", (meta_bytes,))

    conn.commit()
    conn.close()

    # Create WAL file
    if wal_size > 0:
        with open(wal_path, "wb") as f:
            f.write(b"\x00" * wal_size)
    elif wal_size == 0:
        with open(wal_path, "wb") as f:
            pass  # 0 bytes

    return db_path, wal_path


class TestIdleDetection(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_idle_empty_directory(self):
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_idle_no_wal_files(self):
        # Database exists with active step, but NO .db-wal file exists (idle/checkpointed)
        create_mock_conversation(self.conv_dir, "idle-conv", step_statuses=[2], wal_size=-1)
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_idle_zero_byte_wal_file(self):
        # WAL file exists but is 0 bytes (dormant)
        create_mock_conversation(self.conv_dir, "dormant-conv", step_statuses=[2], wal_size=0)
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_idle_completed_status(self):
        # WAL exists and is non-empty, but latest step is 3 (CORTEX_STEP_STATUS_DONE)
        create_mock_conversation(self.conv_dir, "done-conv", step_statuses=[2, 3], wal_size=512)
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_idle_waiting_and_terminal_statuses(self):
        # Terminal statuses: 4 (invalid), 5 (cleared), 6 (canceled), 7 (error), 9 (waiting), 10 (interrupted), 12 (halted)
        for terminal_status in [4, 5, 6, 7, 9, 10, 12]:
            with self.subTest(status=terminal_status):
                cid = f"term-{terminal_status}"
                create_mock_conversation(self.conv_dir, cid, step_statuses=[terminal_status], wal_size=512)
                res = wa.check_state(conv_dir=self.conv_dir)
                self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_idle_nonexistent_directory(self):
        res = wa.check_state(conv_dir="/nonexistent/directory/path/here")
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})


class TestActiveStepDetection(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_active_statuses(self):
        # 1: PENDING, 2: RUNNING, 8: GENERATING, 11: QUEUED
        for active_status in [1, 2, 8, 11]:
            with self.subTest(status=active_status):
                cid = f"active-{active_status}"
                create_mock_conversation(self.conv_dir, cid, step_statuses=[active_status], wal_size=1024)
                res = wa.check_state(conv_dir=self.conv_dir)
                self.assertTrue(res["active"])
                self.assertEqual(res["total"], 1)
                # Cleanup for next subtest
                for f in os.listdir(self.conv_dir):
                    os.remove(os.path.join(self.conv_dir, f))

    def test_step_ordering_resolves_latest_step(self):
        # Case A: Step 1 is running (2), Step 2 is DONE (3) -> Latest is 3 -> Idle
        create_mock_conversation(self.conv_dir, "step-order-a", step_statuses=[2, 3], wal_size=1024)
        res_a = wa.check_state(conv_dir=self.conv_dir)
        self.assertFalse(res_a["active"])
        self.assertEqual(res_a["total"], 0)

        # Case B: Step 1 is DONE (3), Step 2 is GENERATING (8) -> Latest is 8 -> Active
        create_mock_conversation(self.conv_dir, "step-order-b", step_statuses=[3, 8], wal_size=1024)
        res_b = wa.check_state(conv_dir=self.conv_dir)
        self.assertTrue(res_b["active"])
        self.assertEqual(res_b["total"], 1)

    def test_multiple_active_conversations(self):
        create_mock_conversation(self.conv_dir, "agent-1", step_statuses=[2], wal_size=512)
        create_mock_conversation(self.conv_dir, "agent-2", step_statuses=[8], wal_size=512)
        create_mock_conversation(self.conv_dir, "agent-3", step_statuses=[11], wal_size=512)
        create_mock_conversation(self.conv_dir, "agent-4", step_statuses=[3], wal_size=512)  # Done

        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertTrue(res["active"])
        self.assertEqual(res["total"], 3)


class TestSubagentParsing(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_parse_metadata_blob_root_session(self):
        # Root session: no parent ID, nesting_depth = 0
        raw = create_metadata_blob(parent_id="", nesting_depth=0)
        parsed = wa.parse_metadata_blob(raw)
        self.assertFalse(parsed["is_subagent"])
        self.assertEqual(parsed["nesting_depth"], 0)

    def test_parse_metadata_blob_subagent_with_parent_id(self):
        # Subagent with parent ID
        raw = create_metadata_blob(parent_id="2a227a31-3d76-4d0a-8b72-7e6fca717093", nesting_depth=0)
        parsed = wa.parse_metadata_blob(raw)
        self.assertTrue(parsed["is_subagent"])
        self.assertEqual(parsed["parent_conversation_id"], "2a227a31-3d76-4d0a-8b72-7e6fca717093")

    def test_parse_metadata_blob_subagent_with_nesting_depth(self):
        # Subagent with nesting depth >= 1
        raw = create_metadata_blob(parent_id=None, nesting_depth=2)
        parsed = wa.parse_metadata_blob(raw)
        self.assertTrue(parsed["is_subagent"])
        self.assertEqual(parsed["nesting_depth"], 2)

    def test_parse_metadata_blob_corrupted_data(self):
        corrupted = b"\xff\xff\x00\x12\x34garbage"
        parsed = wa.parse_metadata_blob(corrupted)
        self.assertFalse(parsed["is_subagent"])

    def test_parse_metadata_blob_empty_or_none(self):
        self.assertFalse(wa.parse_metadata_blob(b"")["is_subagent"])
        self.assertFalse(wa.parse_metadata_blob(None)["is_subagent"])

    def test_mixed_root_and_subagent_counting(self):
        # 1 root agent (active, status 2)
        create_mock_conversation(self.conv_dir, "root-agent", step_statuses=[2], parent_id="", nesting_depth=0)
        # 2 subagents (active, status 8 and 2)
        create_mock_conversation(self.conv_dir, "sub-agent-1", step_statuses=[8], parent_id="root-agent", nesting_depth=1)
        create_mock_conversation(self.conv_dir, "sub-agent-2", step_statuses=[2], parent_id="root-agent", nesting_depth=2)

        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertTrue(res["active"])
        self.assertEqual(res["total"], 3)
        self.assertEqual(res["subagents"], 2)

    def test_metadata_cache(self):
        create_mock_conversation(self.conv_dir, "sub-agent", step_statuses=[2], parent_id="root-1", nesting_depth=1)
        cache = {}
        db_path = os.path.join(self.conv_dir, "sub-agent.db")

        # First call populates cache
        is_sub1 = wa.is_conversation_subagent(db_path, "sub-agent", cache)
        self.assertTrue(is_sub1)
        self.assertIn("sub-agent", cache)
        self.assertTrue(cache["sub-agent"])

        # Second call returns cached value directly
        cache["sub-agent"] = "cached-marker"
        is_sub2 = wa.is_conversation_subagent(db_path, "sub-agent", cache)
        self.assertEqual(is_sub2, "cached-marker")


class TestJsonEmissionAndDiffing(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name
        self.status_file = os.path.join(self.conv_dir, "status.json")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_initial_emission(self):
        with patch("sys.stdout", new=io.StringIO()) as fake_stdout:
            wa.run_watch_loop(
                conv_dir=self.conv_dir,
                status_file=self.status_file,
                once=True,
            )
            output = fake_stdout.getvalue().strip()

        parsed = json.loads(output)
        self.assertEqual(parsed, {"active": False, "subagents": 0, "total": 0})

    def test_state_diffing_no_duplicate_lines(self):
        # Run 5 iterations on static idle directory; should emit exactly 1 line
        with patch("sys.stdout", new=io.StringIO()) as fake_stdout:
            wa.run_watch_loop(
                conv_dir=self.conv_dir,
                status_file=self.status_file,
                interval=0.01,
                max_iterations=5,
            )
            lines = [line.strip() for line in fake_stdout.getvalue().strip().splitlines() if line.strip()]

        self.assertEqual(len(lines), 1)
        self.assertEqual(json.loads(lines[0]), {"active": False, "subagents": 0, "total": 0})

    def test_status_file_updated_atomically(self):
        create_mock_conversation(self.conv_dir, "sub1", step_statuses=[2], parent_id="p1", nesting_depth=1)
        with patch("sys.stdout", new=io.StringIO()):
            wa.run_watch_loop(
                conv_dir=self.conv_dir,
                status_file=self.status_file,
                once=True,
            )

        self.assertTrue(os.path.isfile(self.status_file))
        with open(self.status_file, "r") as f:
            data = json.loads(f.read().strip())
        self.assertEqual(data, {"active": True, "subagents": 1, "total": 1})


class TestLockHandling(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.lock_path = os.path.join(self.temp_dir.name, "test.lock")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_lock_acquire_and_release(self):
        fd1 = wa.acquire_lock(self.lock_path)
        self.assertIsNotNone(fd1)

        # Second attempt must fail
        fd2 = wa.acquire_lock(self.lock_path)
        self.assertIsNone(fd2)

        # Release first lock
        fcntl.flock(fd1, fcntl.LOCK_UN)
        fd1.close()

        # Re-acquire succeeds
        fd3 = wa.acquire_lock(self.lock_path)
        self.assertIsNotNone(fd3)
        fcntl.flock(fd3, fcntl.LOCK_UN)
        fd3.close()

    def test_process_exits_gracefully_when_locked(self):
        # Hold lock
        fd = wa.acquire_lock(self.lock_path)
        self.assertIsNotNone(fd)

        # Spawn watch_antigravity.py pointing to same lock file
        proc = subprocess.run(
            [
                sys.executable,
                wa.__file__,
                "--lock-file", self.lock_path,
                "--no-prctl",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
        )

        # Must exit cleanly with returncode 0
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout.decode().strip(), "")

        fcntl.flock(fd, fcntl.LOCK_UN)
        fd.close()


class TestErrorResilience(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_wal_without_db(self):
        # Orphaned WAL file
        wal_path = os.path.join(self.conv_dir, "orphan.db-wal")
        with open(wal_path, "wb") as f:
            f.write(b"data")

        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_corrupted_db(self):
        db_path = os.path.join(self.conv_dir, "corrupt.db")
        wal_path = os.path.join(self.conv_dir, "corrupt.db-wal")
        with open(db_path, "wb") as f:
            f.write(b"this is not a valid sqlite database file!")
        with open(wal_path, "wb") as f:
            f.write(b"wal content")

        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})

    def test_missing_steps_table(self):
        db_path = os.path.join(self.conv_dir, "notables.db")
        wal_path = os.path.join(self.conv_dir, "notables.db-wal")
        conn = sqlite3.connect(db_path)
        conn.execute("CREATE TABLE dummy (x INT)")
        conn.commit()
        conn.close()
        with open(wal_path, "wb") as f:
            f.write(b"wal content")

        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": False, "subagents": 0, "total": 0})


class TestBenchmarkAndPerformance(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_idle_loop_time_under_1ms(self):
        # Warm up
        for _ in range(10):
            wa.check_state(conv_dir=self.conv_dir)

        iterations = 500
        times = []
        for _ in range(iterations):
            t0 = time.perf_counter()
            wa.check_state(conv_dir=self.conv_dir)
            t1 = time.perf_counter()
            times.append(t1 - t0)

        avg_ms = (sum(times) / len(times)) * 1000.0
        p95_ms = sorted(times)[int(len(times) * 0.95)] * 1000.0

        print(f"\n[BENCHMARK] Idle loop time over {iterations} iterations: avg = {avg_ms:.4f} ms, p95 = {p95_ms:.4f} ms")
        self.assertLess(avg_ms, 1.0, f"Average idle loop time {avg_ms:.4f} ms exceeds 1.0 ms threshold")

    def test_active_loop_time_under_1ms(self):
        # Create active mock DBs
        create_mock_conversation(self.conv_dir, "active-1", step_statuses=[2], parent_id="", nesting_depth=0)
        create_mock_conversation(self.conv_dir, "active-2", step_statuses=[8], parent_id="active-1", nesting_depth=1)

        # Warm up & cache metadata
        meta_cache = {}
        for _ in range(10):
            wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)

        iterations = 200
        times = []
        for _ in range(iterations):
            t0 = time.perf_counter()
            wa.check_state(conv_dir=self.conv_dir, meta_cache=meta_cache)
            t1 = time.perf_counter()
            times.append(t1 - t0)

        avg_ms = (sum(times) / len(times)) * 1000.0
        print(f"[BENCHMARK] Active loop time over {iterations} iterations: avg = {avg_ms:.4f} ms")
        self.assertLess(avg_ms, 1.0, f"Average active loop time {avg_ms:.4f} ms exceeds 1.0 ms threshold")

    def test_steady_state_cpu_under_0_05_percent(self):
        # Measure CPU time of steady-state subprocess over 2 seconds
        lock_file = os.path.join(self.conv_dir, "bench.lock")
        status_file = os.path.join(self.conv_dir, "bench_status.json")

        proc = subprocess.Popen(
            [
                sys.executable,
                wa.__file__,
                "--conv-dir", self.conv_dir,
                "--lock-file", lock_file,
                "--status-file", status_file,
                "--no-prctl",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            # Wait for startup output line
            proc.stdout.readline()

            p = psutil.Process(proc.pid)
            c_start = p.cpu_times()
            t_start = time.perf_counter()

            # Run for 2.0 seconds in steady state
            time.sleep(2.0)

            t_end = time.perf_counter()
            c_end = p.cpu_times()

            wall_duration = t_end - t_start
            cpu_duration = (c_end.user - c_start.user) + (c_end.system - c_start.system)
            cpu_percent = (cpu_duration / wall_duration) * 100.0

            print(f"[BENCHMARK] Steady-state CPU% over {wall_duration:.2f}s: {cpu_percent:.4f}% CPU (Limit: < 0.05%)")
            self.assertLess(cpu_percent, 0.05, f"Steady-state CPU {cpu_percent:.4f}% exceeds 0.05% limit")
        finally:
            proc.terminate()
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()
            proc.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)
