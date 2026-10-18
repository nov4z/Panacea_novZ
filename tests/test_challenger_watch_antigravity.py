#!/usr/bin/env python3
"""
Adversarial Challenger Test Suite: watch_antigravity.py Subagent Counting & State Transitions.

Empirically verifies:
1. Diverse trajectory structures:
   - Root sessions (depth 0, no parent ID, empty parent, whitespace parent, missing metadata table/row)
   - Subagents with depth 1, 2, 5 (with and without parent ID, multi-byte varints, rich production payloads)
   - Edge cases: depth 0 with parent ID, corrupt protobuf, infinite continuation varints, regex fallback
2. State transitions across diverse structures:
   - Full cycle: 0 agents -> 1 agent -> 2 agents -> 5 agents -> 1 agent -> 0 agents
   - Variations: pure subagents, mixed root + subagents, step status mutations in-place, WAL lifecycle
   - Out-of-order step indices resolving strictly by ORDER BY idx DESC
3. Real-time JSON streaming, strict state diffing, and immediate stdout flushing:
   - Verifies exact line sequence emitted by daemon subprocess
   - Verifies no duplicate lines during static states
   - Verifies immediate line availability (< 250ms flush latency)
   - Verifies strict JSON schema conformance: {"active": bool, "subagents": int, "total": int}
4. Live system activity verification:
   - Verifies execution against ~/.gemini/antigravity/conversations
   - Verifies invariants: active == (total > 0), subagents <= total
"""

import unittest
import tempfile
import sqlite3
import os
import sys
import time
import json
import subprocess
import select
from pathlib import Path

# Add scripts directory to sys.path
SCRIPTS_DIR = Path("/home/nova/.config/panacea/scripts")
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import watch_antigravity as wa


def encode_varint(val: int) -> bytes:
    """Encodes an unsigned integer into protobuf varint bytes."""
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


def build_protobuf_metadata(
    parent_id: str | None = None,
    nesting_depth: int | None = None,
    include_extra_tags: bool = False,
    corrupt_trailing_bytes: bool = False,
) -> bytes:
    """
    Constructs protobuf wire format data simulating Antigravity trajectory metadata.
    """
    buf = bytearray()

    if include_extra_tags:
        # Tag 2 (wire 2): timestamps / UUID
        buf.extend(encode_varint((2 << 3) | 2))
        dummy = b"\x08\x9c\xfa\x9b\xd6\x06\x10\xdb\xb5\xe4\xb5\x02"
        buf.extend(encode_varint(len(dummy)))
        buf.extend(dummy)

        # Tag 3 (wire 2): conversation UUID
        buf.extend(encode_varint((3 << 3) | 2))
        cid_str = b"11111111-2222-3333-4444-555555555555"
        buf.extend(encode_varint(len(cid_str)))
        buf.extend(cid_str)

    # Tag 5 (wire 2): parent_conversation_id
    if parent_id is not None:
        buf.extend(encode_varint((5 << 3) | 2))
        pid_bytes = parent_id.encode("utf-8")
        buf.extend(encode_varint(len(pid_bytes)))
        buf.extend(pid_bytes)

    # Tag 17 (wire 0): nesting_depth
    if nesting_depth is not None:
        buf.extend(encode_varint((17 << 3) | 0))
        buf.extend(encode_varint(nesting_depth))

    if include_extra_tags:
        # Tag 18 (wire 2): scope string
        buf.extend(encode_varint((18 << 3) | 2))
        scope_str = b"outside-of-project"
        buf.extend(encode_varint(len(scope_str)))
        buf.extend(scope_str)

    if corrupt_trailing_bytes:
        buf.extend(b"\xff\xff\xfe\x00corrupt")

    return bytes(buf)


def create_conversation_db(
    conv_dir: str,
    conv_id: str,
    step_statuses: list[int] | None = None,
    parent_id: str | None = None,
    nesting_depth: int | None = None,
    create_metadata: bool = True,
    include_extra_tags: bool = False,
    wal_size: int = 1024,
) -> tuple[str, str]:
    """
    Creates a mock conversation SQLite database with exact Antigravity schema.
    """
    db_path = os.path.join(conv_dir, f"{conv_id}.db")
    wal_path = os.path.join(conv_dir, f"{conv_id}.db-wal")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS steps (
            idx INTEGER PRIMARY KEY,
            step_type INTEGER DEFAULT 0,
            status INTEGER DEFAULT 0,
            has_subtrajectory NUMERIC DEFAULT 'false'
        )
        """
    )

    if step_statuses is not None:
        for idx, status in enumerate(step_statuses, start=1):
            cur.execute(
                "INSERT INTO steps (idx, status) VALUES (?, ?)", (idx, status)
            )

    if create_metadata:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS trajectory_metadata_blob (
                id TEXT DEFAULT 'main',
                data BLOB,
                PRIMARY KEY (id)
            )
            """
        )
        data_blob = build_protobuf_metadata(
            parent_id=parent_id,
            nesting_depth=nesting_depth,
            include_extra_tags=include_extra_tags,
        )
        cur.execute(
            "INSERT OR REPLACE INTO trajectory_metadata_blob (id, data) VALUES ('main', ?)",
            (data_blob,),
        )

    conn.commit()
    conn.close()

    if wal_size >= 0:
        with open(wal_path, "wb") as f:
            f.write(b"\x00" * wal_size)

    return db_path, wal_path


def update_conversation_step(conv_dir: str, conv_id: str, new_status: int, keep_wal: bool = True):
    """Appends or updates step in existing conversation database."""
    db_path = os.path.join(conv_dir, f"{conv_id}.db")
    wal_path = os.path.join(conv_dir, f"{conv_id}.db-wal")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT MAX(idx) FROM steps")
    row = cur.fetchone()
    next_idx = (row[0] + 1) if (row and row[0] is not None) else 1
    cur.execute("INSERT INTO steps (idx, status) VALUES (?, ?)", (next_idx, new_status))
    conn.commit()
    conn.close()
    if keep_wal:
        with open(wal_path, "wb") as f:
            f.write(b"\x00" * 1024)


class TestDiverseTrajectoryStructures(unittest.TestCase):
    """
    Test suite verifying subagent detection across varied trajectory structures:
    - Root sessions (depth 0, no parent)
    - Subagents at depths 1, 2, 5
    - Deeply nested subagents (depth 10, 100, 128)
    - Missing or corrupted metadata blobs
    """

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_root_session_depth_0_no_parent(self):
        """Root session with depth 0 and no parent must be classified as non-subagent."""
        create_conversation_db(
            self.conv_dir,
            "root-session-1",
            step_statuses=[2],
            parent_id=None,
            nesting_depth=0,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 0, "total": 1})

    def test_root_session_empty_and_whitespace_parent(self):
        """Root session with empty or whitespace parent_conversation_id must be non-subagent."""
        create_conversation_db(
            self.conv_dir,
            "root-empty-parent",
            step_statuses=[2],
            parent_id="",
            nesting_depth=0,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 0, "total": 1})

        # Whitespace parent
        create_conversation_db(
            self.conv_dir,
            "root-ws-parent",
            step_statuses=[8],
            parent_id="    ",
            nesting_depth=0,
        )
        res2 = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res2, {"active": True, "subagents": 0, "total": 2})

    def test_root_session_missing_metadata(self):
        """Root session without trajectory_metadata_blob table or row must be non-subagent."""
        create_conversation_db(
            self.conv_dir,
            "root-no-meta",
            step_statuses=[1],
            create_metadata=False,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 0, "total": 1})

    def test_subagent_depth_1(self):
        """Subagent with depth 1 must be classified as subagent (with and without parent ID)."""
        # With parent ID
        create_conversation_db(
            self.conv_dir,
            "sub-d1-with-p",
            step_statuses=[2],
            parent_id="2a227a31-3d76-4d0a-8b72-7e6fca717093",
            nesting_depth=1,
            include_extra_tags=True,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 1, "total": 1})

        # Without parent ID (only tag 17)
        create_conversation_db(
            self.conv_dir,
            "sub-d1-no-p",
            step_statuses=[8],
            parent_id=None,
            nesting_depth=1,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 2, "total": 2})

    def test_subagent_depth_2(self):
        """Subagent with depth 2 must be classified as subagent."""
        create_conversation_db(
            self.conv_dir,
            "sub-d2",
            step_statuses=[2],
            parent_id="parent-d1-uuid",
            nesting_depth=2,
            include_extra_tags=True,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 1, "total": 1})

    def test_subagent_depth_5(self):
        """Subagent with depth 5 must be classified as subagent."""
        create_conversation_db(
            self.conv_dir,
            "sub-d5",
            step_statuses=[11],
            parent_id="parent-d4-uuid",
            nesting_depth=5,
            include_extra_tags=True,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 1, "total": 1})

    def test_subagent_deeply_nested_and_multibyte_varint(self):
        """Subagents with depth > 127 requiring multi-byte protobuf varint encoding."""
        # depth = 128 (varint: \x80\x01)
        create_conversation_db(
            self.conv_dir,
            "sub-d128",
            step_statuses=[2],
            parent_id="parent-uuid-xyz",
            nesting_depth=128,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 1, "total": 1})

    def test_subagent_depth_0_with_parent_id(self):
        """A conversation with depth 0 but valid parent_conversation_id is classified as subagent."""
        create_conversation_db(
            self.conv_dir,
            "sub-d0-with-parent",
            step_statuses=[8],
            parent_id="38a9367d-a86a-405d-b560-f77c1169f0ec",
            nesting_depth=0,
        )
        res = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res, {"active": True, "subagents": 1, "total": 1})

    def test_adversarial_infinite_varint_and_fuzzed_protobuf(self):
        """Adversarial byte sequences must never hang or crash parse_metadata_blob."""
        # 1. Varint with 1000 continuation bits (0x80)
        infinite_varint = b"\x80" * 1000
        p1 = wa.parse_metadata_blob(infinite_varint)
        self.assertFalse(p1["is_subagent"])

        # 2. Truncated length-delimited field claiming 255 bytes when only 2 exist
        truncated = b"\x2a\xff\x01\x02"
        p2 = wa.parse_metadata_blob(truncated)
        self.assertFalse(p2["is_subagent"])

        # 3. Regex fallback: corrupted protobuf container with embedded valid tag 5 UUID
        embedded_uuid = b"garbage\x2a\x24" + b"12345678-1234-1234-1234-123456789abc" + b"junk"
        p3 = wa.parse_metadata_blob(embedded_uuid)
        self.assertTrue(p3["is_subagent"])
        self.assertEqual(p3["parent_conversation_id"], "12345678-1234-1234-1234-123456789abc")


class TestStateTransitions(unittest.TestCase):
    """
    Test suite verifying the full transition cycle:
    0 agents -> 1 agent -> 2 agents -> 5 agents -> 1 agent -> 0 agents
    """

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_transition_pure_subagents(self):
        """
        Transitions 0 -> 1 -> 2 -> 5 -> 1 -> 0 with subagents of diverse depths (1, 2, 5).
        """
        cache = {}

        # 0 agents
        s0 = wa.check_state(conv_dir=self.conv_dir, meta_cache=cache)
        self.assertEqual(s0, {"active": False, "subagents": 0, "total": 0})

        # 1 agent (Subagent depth 1, status 2 RUNNING)
        create_conversation_db(
            self.conv_dir, "agent-1", step_statuses=[2], parent_id="root-p", nesting_depth=1
        )
        s1 = wa.check_state(conv_dir=self.conv_dir, meta_cache=cache)
        self.assertEqual(s1, {"active": True, "subagents": 1, "total": 1})

        # 2 agents (Subagent depth 1 + Subagent depth 2, status 8 GENERATING)
        create_conversation_db(
            self.conv_dir, "agent-2", step_statuses=[8], parent_id="agent-1", nesting_depth=2
        )
        s2 = wa.check_state(conv_dir=self.conv_dir, meta_cache=cache)
        self.assertEqual(s2, {"active": True, "subagents": 2, "total": 2})

        # 5 agents (Add depth 3, depth 4, depth 5)
        create_conversation_db(
            self.conv_dir, "agent-3", step_statuses=[1], parent_id="agent-2", nesting_depth=3
        )
        create_conversation_db(
            self.conv_dir, "agent-4", step_statuses=[2], parent_id="agent-3", nesting_depth=4
        )
        create_conversation_db(
            self.conv_dir, "agent-5", step_statuses=[11], parent_id="agent-4", nesting_depth=5
        )
        s3 = wa.check_state(conv_dir=self.conv_dir, meta_cache=cache)
        self.assertEqual(s3, {"active": True, "subagents": 5, "total": 5})

        # 1 agent (Agents 1, 2, 3, 4 complete with status 3 DONE; agent-5 remains running)
        for cid in ["agent-1", "agent-2", "agent-3", "agent-4"]:
            update_conversation_step(self.conv_dir, cid, 3, keep_wal=True)

        s4 = wa.check_state(conv_dir=self.conv_dir, meta_cache=cache)
        self.assertEqual(s4, {"active": True, "subagents": 1, "total": 1})

        # 0 agents (agent-5 completes with status 3 DONE)
        update_conversation_step(self.conv_dir, "agent-5", 3, keep_wal=True)
        s5 = wa.check_state(conv_dir=self.conv_dir, meta_cache=cache)
        self.assertEqual(s5, {"active": False, "subagents": 0, "total": 0})

    def test_transition_mixed_root_and_subagents(self):
        """
        Transitions 0 -> 1 -> 2 -> 5 -> 1 -> 0 with a mixture of root sessions and subagents.
        """
        cache = {}

        # 0 agents
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir, meta_cache=cache),
            {"active": False, "subagents": 0, "total": 0},
        )

        # 1 agent: 1 root session (status 2 RUNNING, depth 0, no parent)
        create_conversation_db(
            self.conv_dir, "root-1", step_statuses=[2], parent_id=None, nesting_depth=0
        )
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir, meta_cache=cache),
            {"active": True, "subagents": 0, "total": 1},
        )

        # 2 agents: 1 root session + 1 subagent (depth 1)
        create_conversation_db(
            self.conv_dir, "sub-1", step_statuses=[8], parent_id="root-1", nesting_depth=1
        )
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir, meta_cache=cache),
            {"active": True, "subagents": 1, "total": 2},
        )

        # 5 agents: 1 root session + 4 subagents (depths 1, 2, 2, 5)
        create_conversation_db(
            self.conv_dir, "sub-2", step_statuses=[2], parent_id="root-1", nesting_depth=1
        )
        create_conversation_db(
            self.conv_dir, "sub-3", step_statuses=[11], parent_id="sub-1", nesting_depth=2
        )
        create_conversation_db(
            self.conv_dir, "sub-4", step_statuses=[2], parent_id="sub-3", nesting_depth=5
        )
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir, meta_cache=cache),
            {"active": True, "subagents": 4, "total": 5},
        )

        # 1 agent: root and 3 subagents finish, only sub-4 (depth 5) active
        update_conversation_step(self.conv_dir, "root-1", 3, keep_wal=True)
        update_conversation_step(self.conv_dir, "sub-1", 3, keep_wal=True)
        update_conversation_step(self.conv_dir, "sub-2", 3, keep_wal=True)
        update_conversation_step(self.conv_dir, "sub-3", 3, keep_wal=True)
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir, meta_cache=cache),
            {"active": True, "subagents": 1, "total": 1},
        )

        # 0 agents: sub-4 finishes
        update_conversation_step(self.conv_dir, "sub-4", 3, keep_wal=True)
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir, meta_cache=cache),
            {"active": False, "subagents": 0, "total": 0},
        )

    def test_transition_via_wal_truncation_and_removal(self):
        """
        Transitions where active status is toggled by WAL file size / existence (checkpointing).
        """
        # Create 2 subagents with active status in DB
        _, wal1 = create_conversation_db(
            self.conv_dir, "sub-wal-1", step_statuses=[2], parent_id="p", nesting_depth=1
        )
        _, wal2 = create_conversation_db(
            self.conv_dir, "sub-wal-2", step_statuses=[8], parent_id="p", nesting_depth=2
        )

        # Both have non-empty WAL -> 2 active
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir),
            {"active": True, "subagents": 2, "total": 2},
        )

        # Truncate wal1 to 0 bytes (simulating SQLite checkpoint completion)
        with open(wal1, "wb") as f:
            pass
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir),
            {"active": True, "subagents": 1, "total": 1},
        )

        # Remove wal2 (simulating WAL deletion)
        os.remove(wal2)
        self.assertEqual(
            wa.check_state(conv_dir=self.conv_dir),
            {"active": False, "subagents": 0, "total": 0},
        )

    def test_out_of_order_step_indices(self):
        """Steps inserted out of index order must strictly resolve by ORDER BY idx DESC."""
        db_path, wal_path = create_conversation_db(self.conv_dir, "ooo-steps", step_statuses=[])
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        # Insert idx 100 with status 3 (DONE) first
        cur.execute("INSERT INTO steps (idx, status) VALUES (100, 3)")
        # Insert idx 10 with status 2 (RUNNING) second
        cur.execute("INSERT INTO steps (idx, status) VALUES (10, 2)")
        conn.commit()
        conn.close()
        with open(wal_path, "wb") as f:
            f.write(b"\x00" * 1024)

        # Highest idx is 100 (DONE) -> must be idle
        res1 = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res1, {"active": False, "subagents": 0, "total": 0})

        # Now insert idx 200 with status 8 (GENERATING) -> highest idx is 200 -> active
        conn = sqlite3.connect(db_path)
        conn.execute("INSERT INTO steps (idx, status) VALUES (200, 8)")
        conn.commit()
        conn.close()
        with open(wal_path, "wb") as f:
            f.write(b"\x00" * 1024)

        res2 = wa.check_state(conv_dir=self.conv_dir)
        self.assertEqual(res2["active"], True)
        self.assertEqual(res2["total"], 1)


class TestJsonStreamingAndDiffingEngine(unittest.TestCase):
    """
    Subprocess test verifying:
    1. Real-time newline-delimited JSON streaming
    2. State diffing: emissions occur ONLY when state changes
    3. Immediate stdout flushing (no pipe buffering delays)
    4. Exact transition sequence over a live process execution
    """

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.conv_dir = self.temp_dir.name
        self.status_file = os.path.join(self.conv_dir, "status.json")
        self.lock_file = os.path.join(self.conv_dir, "test.lock")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_subprocess_stream_exact_transition_sequence(self):
        """
        Spawns watch_antigravity.py as a live subprocess, mutates DB across
        0 -> 1 -> 2 -> 5 -> 1 -> 0, and asserts exact JSON line sequence.
        """
        cmd = [
            sys.executable,
            str(SCRIPTS_DIR / "watch_antigravity.py"),
            "--conv-dir", self.conv_dir,
            "--status-file", self.status_file,
            "--lock-file", self.lock_file,
            "--interval", "0.05",
            "--no-prctl",
        ]

        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,  # Line buffered
        )

        def read_next_line(timeout=2.0) -> str:
            """Reads the next JSON line from process stdout with timeout."""
            rlist, _, _ = select.select([proc.stdout], [], [], timeout)
            if not rlist:
                raise TimeoutError("Timeout waiting for JSON line on process stdout")
            line = proc.stdout.readline()
            if not line:
                raise EOFError("Process stdout closed unexpectedly")
            return line.strip()

        received_events = []

        try:
            # 1. Initial emission on startup: 0 agents
            t0 = time.perf_counter()
            line0 = read_next_line()
            t_initial = time.perf_counter() - t0
            self.assertLess(t_initial, 1.0)
            data0 = json.loads(line0)
            self.assertEqual(data0, {"active": False, "subagents": 0, "total": 0})
            received_events.append(data0)

            # Wait 0.15s (3 intervals) without state change: assert NO extra lines emitted
            rlist, _, _ = select.select([proc.stdout], [], [], 0.15)
            self.assertEqual(rlist, [], "Unexpected duplicate line emitted during static state")

            # 2. Transition to 1 agent (Subagent depth 1)
            t_start = time.perf_counter()
            create_conversation_db(
                self.conv_dir, "stream-sub-1", step_statuses=[2], parent_id="root", nesting_depth=1
            )
            line1 = read_next_line()
            flush_latency1 = time.perf_counter() - t_start
            self.assertLess(flush_latency1, 0.25, f"Flush latency {flush_latency1:.3f}s exceeds 0.25s")
            data1 = json.loads(line1)
            self.assertEqual(data1, {"active": True, "subagents": 1, "total": 1})
            received_events.append(data1)

            # Assert no duplicates for static 1 agent
            rlist, _, _ = select.select([proc.stdout], [], [], 0.15)
            self.assertEqual(rlist, [], "Unexpected duplicate line emitted for static 1 agent")

            # 3. Transition to 2 agents (Subagent depth 2)
            t_start = time.perf_counter()
            create_conversation_db(
                self.conv_dir, "stream-sub-2", step_statuses=[8], parent_id="stream-sub-1", nesting_depth=2
            )
            line2 = read_next_line()
            flush_latency2 = time.perf_counter() - t_start
            self.assertLess(flush_latency2, 0.25)
            data2 = json.loads(line2)
            self.assertEqual(data2, {"active": True, "subagents": 2, "total": 2})
            received_events.append(data2)

            # Assert no duplicates for static 2 agents
            rlist, _, _ = select.select([proc.stdout], [], [], 0.15)
            self.assertEqual(rlist, [], "Unexpected duplicate line emitted for static 2 agents")

            # 4. Transition to 5 agents (Add depths 3, 4, 5)
            t_start = time.perf_counter()
            create_conversation_db(
                self.conv_dir, "stream-sub-3", step_statuses=[2], parent_id="p", nesting_depth=3
            )
            create_conversation_db(
                self.conv_dir, "stream-sub-4", step_statuses=[1], parent_id="p", nesting_depth=4
            )
            create_conversation_db(
                self.conv_dir, "stream-sub-5", step_statuses=[11], parent_id="p", nesting_depth=5
            )
            line3 = read_next_line()
            flush_latency3 = time.perf_counter() - t_start
            self.assertLess(flush_latency3, 0.35)
            data3 = json.loads(line3)
            # Intermediate state may catch partial additions or full 5; loop until final 5
            while data3["total"] < 5:
                line3 = read_next_line()
                data3 = json.loads(line3)
            self.assertEqual(data3, {"active": True, "subagents": 5, "total": 5})
            received_events.append(data3)

            # Assert no duplicates for static 5 agents
            rlist, _, _ = select.select([proc.stdout], [], [], 0.15)
            self.assertEqual(rlist, [], "Unexpected duplicate line emitted for static 5 agents")

            # 5. Transition to 1 agent (Complete agents 1, 2, 3, 4 -> 3 DONE)
            t_start = time.perf_counter()
            for cid in ["stream-sub-1", "stream-sub-2", "stream-sub-3", "stream-sub-4"]:
                update_conversation_step(self.conv_dir, cid, 3, keep_wal=True)

            line4 = read_next_line()
            flush_latency4 = time.perf_counter() - t_start
            self.assertLess(flush_latency4, 0.35)
            data4 = json.loads(line4)
            while data4["total"] > 1:
                line4 = read_next_line()
                data4 = json.loads(line4)
            self.assertEqual(data4, {"active": True, "subagents": 1, "total": 1})
            received_events.append(data4)

            # Assert no duplicates for static 1 agent
            rlist, _, _ = select.select([proc.stdout], [], [], 0.15)
            self.assertEqual(rlist, [], "Unexpected duplicate line emitted for static 1 agent")

            # 6. Transition to 0 agents (Complete agent 5 -> 3 DONE)
            t_start = time.perf_counter()
            update_conversation_step(self.conv_dir, "stream-sub-5", 3, keep_wal=True)
            line5 = read_next_line()
            flush_latency5 = time.perf_counter() - t_start
            self.assertLess(flush_latency5, 0.25)
            data5 = json.loads(line5)
            self.assertEqual(data5, {"active": False, "subagents": 0, "total": 0})
            received_events.append(data5)

            # Assert no duplicates for idle 0 agents
            rlist, _, _ = select.select([proc.stdout], [], [], 0.15)
            self.assertEqual(rlist, [], "Unexpected duplicate line emitted for idle state")

            # Verify status file was maintained in sync
            self.assertTrue(os.path.isfile(self.status_file))
            with open(self.status_file, "r") as f:
                last_disk_status = json.loads(f.read().strip())
            self.assertEqual(last_disk_status, {"active": False, "subagents": 0, "total": 0})

        finally:
            proc.terminate()
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()
            proc.wait(timeout=2.0)

        # Verify key state checkpoints were hit in order
        expected_checkpoints = [
            {"active": False, "subagents": 0, "total": 0},
            {"active": True, "subagents": 1, "total": 1},
            {"active": True, "subagents": 2, "total": 2},
            {"active": True, "subagents": 5, "total": 5},
            {"active": True, "subagents": 1, "total": 1},
            {"active": False, "subagents": 0, "total": 0},
        ]
        for exp in expected_checkpoints:
            self.assertIn(exp, received_events, f"Missing required transition checkpoint: {exp}")


class TestLiveSystemVerification(unittest.TestCase):
    """
    Empirically tests watch_antigravity.py against live Antigravity system activity.
    """

    def test_live_check_state_execution(self):
        """Verifies check_state on live ~/.gemini/antigravity/conversations."""
        live_dir = os.path.expanduser("~/.gemini/antigravity/conversations")
        if not os.path.isdir(live_dir):
            self.skipTest("Live conversations directory not found")

        state = wa.check_state(conv_dir=live_dir)

        # 1. Schema check
        self.assertIsInstance(state["active"], bool)
        self.assertIsInstance(state["subagents"], int)
        self.assertIsInstance(state["total"], int)

        # 2. Invariants
        self.assertGreaterEqual(state["subagents"], 0)
        self.assertGreaterEqual(state["total"], 0)
        self.assertLessEqual(state["subagents"], state["total"])
        self.assertEqual(state["active"], state["total"] > 0)

        print(f"\n[LIVE SYSTEM CHECK] Current state: {state}")

    def test_live_cli_once_flag(self):
        """Verifies CLI execution with --once flag against live system."""
        cmd = [sys.executable, str(SCRIPTS_DIR / "watch_antigravity.py"), "--once"]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
        self.assertEqual(res.returncode, 0)

        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(len(lines), 1)

        payload = json.loads(lines[0])
        self.assertIn("active", payload)
        self.assertIn("subagents", payload)
        self.assertIn("total", payload)
        self.assertLessEqual(payload["subagents"], payload["total"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
