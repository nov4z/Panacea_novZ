#!/usr/bin/env python3
"""
Real-time Antigravity activity and subagent detection engine for Panacea notch.
Monitors SQLite WAL files in ~/.gemini/antigravity/conversations/ and streams
newline-delimited JSON state events to stdout whenever state changes:
{"active": bool, "subagents": int, "total": int}
"""

import sys
import os
import time
import json
import sqlite3
import fcntl
import signal
import re
import argparse

DEFAULT_CONV_DIR = os.path.expanduser("~/.gemini/antigravity/conversations")
DEFAULT_LOCK_FILE = "/tmp/panacea_watch_antigravity.lock"
DEFAULT_STATUS_FILE = os.path.expanduser("~/.config/panacea/.antigravity_status.json")
DEFAULT_INTERVAL = 0.15  # 150ms

# Protobuf enum CortexStepStatus active values:
# 1: PENDING, 2: RUNNING (tool execution), 8: GENERATING (LLM stream), 11: QUEUED
ACTIVE_STEP_STATUSES = {1, 2, 8, 11}


def parse_metadata_blob(data: bytes) -> dict:
    """
    Parses protobuf wire-format trajectory_metadata_blob to extract:
    - Tag 5: parent_conversation_id (length-delimited string)
    - Tag 17: nesting_depth (varint integer)
    Returns:
    {"parent_conversation_id": str | None, "nesting_depth": int, "is_subagent": bool}
    """
    if not data or not isinstance(data, (bytes, bytearray, memoryview)):
        return {"parent_conversation_id": None, "nesting_depth": 0, "is_subagent": False}

    data = bytes(data)
    pos = 0
    length = len(data)
    parent_id = None
    nesting_depth = 0

    try:
        while pos < length:
            # Read varint for tag and wire_type
            varint = 0
            shift = 0
            while pos < length:
                b = data[pos]
                pos += 1
                varint |= (b & 0x7F) << shift
                shift += 7
                if not (b & 0x80):
                    break

            tag = varint >> 3
            wire_type = varint & 7

            if wire_type == 0:  # Varint
                val = 0
                s = 0
                while pos < length:
                    b = data[pos]
                    pos += 1
                    val |= (b & 0x7F) << s
                    s += 7
                    if not (b & 0x80):
                        break
                if tag == 17:
                    nesting_depth = val
            elif wire_type == 1:  # 64-bit fixed
                pos += 8
            elif wire_type == 2:  # Length-delimited (string / bytes / message)
                val_len = 0
                s = 0
                while pos < length:
                    b = data[pos]
                    pos += 1
                    val_len |= (b & 0x7F) << s
                    s += 7
                    if not (b & 0x80):
                        break
                if pos + val_len > length:
                    break
                chunk = data[pos:pos + val_len]
                pos += val_len
                if tag == 5:
                    decoded = chunk.decode("utf-8", errors="ignore").strip()
                    if decoded:
                        parent_id = decoded
            elif wire_type == 5:  # 32-bit fixed
                pos += 4
            else:
                break
    except Exception:
        pass

    # Regex fallback for Tag 5 (0x2a = wire 2 tag 5) followed by length 36 (0x24) UUID
    if not parent_id:
        m = re.search(rb"\x2a\x24([0-9a-fA-F\-]{36})", data)
        if m:
            parent_id = m.group(1).decode("utf-8", errors="ignore")

    is_sub = bool((parent_id and len(parent_id) > 0) or nesting_depth >= 1)
    return {
        "parent_conversation_id": parent_id,
        "nesting_depth": nesting_depth,
        "is_subagent": is_sub,
    }


def is_conversation_subagent(db_path: str, cid: str, meta_cache: dict) -> bool:
    """
    Checks if a conversation DB belongs to a subagent, using an in-memory cache.
    """
    if cid in meta_cache:
        return meta_cache[cid]

    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=0.1)
        try:
            cur = conn.cursor()
            cur.execute("SELECT data FROM trajectory_metadata_blob WHERE id='main'")
            row = cur.fetchone()
            if row and row[0]:
                meta = parse_metadata_blob(row[0])
                is_sub = meta["is_subagent"]
                # Cache successful determination
                if len(meta_cache) > 2000:
                    meta_cache.clear()
                meta_cache[cid] = is_sub
                return is_sub
            return False
        finally:
            conn.close()
    except (sqlite3.Error, OSError):
        return False


def check_state(conv_dir: str = DEFAULT_CONV_DIR, meta_cache: dict = None) -> dict:
    """
    Scans the conversations directory for active Antigravity tasks.
    Zero-overhead fast-path: checks non-empty .db-wal files using os.scandir.
    Returns: {"active": bool, "subagents": int, "total": int}
    """
    if meta_cache is None:
        meta_cache = {}

    idle_result = {"active": False, "subagents": 0, "total": 0}

    if not os.path.isdir(conv_dir):
        return idle_result

    # 1. Fast scandir filter: check for non-empty .db-wal files
    active_wals = []
    try:
        with os.scandir(conv_dir) as entries:
            for entry in entries:
                try:
                    if entry.name.endswith(".db-wal"):
                        st = entry.stat()
                        if st.st_size > 0:
                            active_wals.append(entry.path)
                except OSError:
                    continue
    except OSError:
        return idle_result

    if not active_wals:
        return idle_result

    total_active = 0
    active_subagents = 0

    # 2. Inspect latest step status for each active WAL
    for wal_path in active_wals:
        db_path = wal_path[:-4]  # Strip -wal suffix
        cid = os.path.basename(db_path)
        if cid.endswith(".db"):
            cid = cid[:-3]

        if not os.path.isfile(db_path):
            continue

        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=0.1)
            try:
                cur = conn.cursor()
                cur.execute("SELECT status FROM steps ORDER BY idx DESC LIMIT 1")
                row = cur.fetchone()
                if row is not None and row[0] in ACTIVE_STEP_STATUSES:
                    total_active += 1
                    if is_conversation_subagent(db_path, cid, meta_cache):
                        active_subagents += 1
            finally:
                conn.close()
        except (sqlite3.Error, OSError):
            continue

    return {
        "active": total_active > 0,
        "subagents": active_subagents,
        "total": total_active,
    }


def acquire_lock(lock_file_path: str):
    """
    Acquires an exclusive, non-blocking file lock.
    Returns the open file descriptor on success, or None if already locked.
    """
    lock_fd = None
    try:
        lock_fd = open(lock_file_path, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return lock_fd
    except (IOError, OSError):
        if lock_fd is not None:
            try:
                lock_fd.close()
            except Exception:
                pass
        return None


def setup_parent_death_signal():
    """
    Binds process lifecycle to parent via libc prctl(PR_SET_PDEATHSIG, SIGTERM).
    Ensures the daemon terminates immediately when its parent process terminates.
    """
    try:
        import ctypes
        libc = ctypes.CDLL("libc.so.6")
        # PR_SET_PDEATHSIG = 1, SIGTERM = 15
        libc.prctl(1, signal.SIGTERM)
    except Exception:
        pass


def write_status_file(status_file_path: str, payload_str: str):
    """
    Atomically writes the current status JSON to disk for external readers.
    """
    if not status_file_path:
        return
    try:
        parent_dir = os.path.dirname(status_file_path)
        if not os.path.exists(parent_dir):
            os.makedirs(parent_dir, exist_ok=True)
        tmp_file = f"{status_file_path}.tmp.{os.getpid()}"
        with open(tmp_file, "w") as f:
            f.write(payload_str + "\n")
        os.replace(tmp_file, status_file_path)
    except Exception:
        pass


def run_watch_loop(
    conv_dir: str = DEFAULT_CONV_DIR,
    status_file: str = DEFAULT_STATUS_FILE,
    interval: float = DEFAULT_INTERVAL,
    once: bool = False,
    max_iterations: int = 0,
):
    """
    Executes the polling loop, streaming state updates to stdout.
    """
    meta_cache = {}
    last_state = None
    initial_ppid = os.getppid()
    iteration = 0

    while True:
        iteration += 1

        # Check if parent process exited (adopted by PID 1 or changed PPID)
        if initial_ppid > 1 and (os.getppid() != initial_ppid or os.getppid() == 1):
            break

        try:
            curr = check_state(conv_dir=conv_dir, meta_cache=meta_cache)
            if curr != last_state:
                payload = json.dumps(curr)
                print(payload, flush=True)
                write_status_file(status_file, payload)
                last_state = curr
        except BrokenPipeError:
            # Stdout closed by parent process (e.g. Quickshell shut down)
            sys.exit(0)
        except Exception:
            # Catch all unexpected errors gracefully so daemon never crashes
            pass

        if once or (max_iterations > 0 and iteration >= max_iterations):
            break

        time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(description="Watch Antigravity task activity and subagents")
    parser.add_argument("--conv-dir", default=os.environ.get("ANTIGRAVITY_CONVERSATIONS_DIR", DEFAULT_CONV_DIR))
    parser.add_argument("--lock-file", default=os.environ.get("PANACEA_WATCH_LOCK_FILE", DEFAULT_LOCK_FILE))
    parser.add_argument("--status-file", default=os.environ.get("PANACEA_STATUS_FILE", DEFAULT_STATUS_FILE))
    parser.add_argument("--interval", type=float, default=float(os.environ.get("PANACEA_WATCH_INTERVAL", DEFAULT_INTERVAL)))
    parser.add_argument("--once", action="store_true", help="Check state once, output to stdout, and exit")
    parser.add_argument("--no-lock", action="store_true", help="Skip single-instance locking")
    parser.add_argument("--no-prctl", action="store_true", help="Skip prctl parent death binding")
    args = parser.parse_args()

    # Graceful signal handling
    def sig_handler(signum, frame):
        sys.exit(0)

    signal.signal(signal.SIGTERM, sig_handler)
    signal.signal(signal.SIGINT, sig_handler)

    # 1. Single-instance locking
    lock_fd = None
    if not args.no_lock and not args.once:
        lock_fd = acquire_lock(args.lock_file)
        if lock_fd is None:
            # Another instance is already running; exit gracefully
            sys.exit(0)

    # 2. Parent lifecycle binding
    if not args.no_prctl and not args.once and os.environ.get("PANACEA_DISABLE_PRCTL") != "1":
        setup_parent_death_signal()

    try:
        run_watch_loop(
            conv_dir=args.conv_dir,
            status_file=args.status_file,
            interval=args.interval,
            once=args.once,
        )
    finally:
        if lock_fd is not None:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_UN)
                lock_fd.close()
            except Exception:
                pass


if __name__ == "__main__":
    main()
