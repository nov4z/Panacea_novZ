"""Shared test fixtures, mocks, and specification oracles for panacea-antigravity-notch test suite."""

import os
import sys
import json
import sqlite3
import tempfile
import math
import re
from pathlib import Path

# Base Paths
PANACEA_DIR = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
SCRIPTS_DIR = PANACEA_DIR / "scripts"
ASSETS_DIR = PANACEA_DIR / "assets"
TESTS_DIR = PANACEA_DIR / "tests"
SETTINGS_FILE = PANACEA_DIR / "settings.json"
SHELL_QML = PANACEA_DIR / "shell.qml"
ANTIGRAVITY_DIR = Path(os.environ.get("HOME", "/home/nova")) / ".gemini" / "antigravity"
ANTIGRAVITY_CONV_DIR = ANTIGRAVITY_DIR / "conversations"
HYPR_BINDS_FILE = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))) / "hypr" / "lua" / "keybindings.lua"

# Add project root to sys.path
if str(PANACEA_DIR) not in sys.path:
    sys.path.insert(0, str(PANACEA_DIR))
from scripts.watch_antigravity import check_state, parse_metadata_blob, is_conversation_subagent

# Active step statuses as defined in PROJECT.md: (1, 2, 8, 11)
ACTIVE_STEP_STATUSES = (1, 2, 8, 11)

# Default specification constraints
SPEC_MAX_LATENCY_MS = 150
SPEC_MAX_CPU_PERCENT = 0.05
SPEC_DEFAULT_LOGO_SIZE = 18
SPEC_DEFAULT_WAVE_HEIGHT = 20


def create_mock_conversation_db(
    directory: Path,
    conversation_id: str,
    is_active: bool = True,
    parent_conversation_id: str | None = None,
    step_status: int = 2,
    wal_bytes: int = 1024,
) -> Path:
    """Creates a mock Antigravity conversation SQLite database and WAL file.
    
    Args:
        directory: Target directory for database files
        conversation_id: UUID or identifier for conversation
        is_active: Whether active step statuses exist
        parent_conversation_id: If set, designates this conversation as a subagent
        step_status: Integer status for steps table (default: 2)
        wal_bytes: Number of bytes for .db-wal file
    """
    directory.mkdir(parents=True, exist_ok=True)
    db_path = directory / f"{conversation_id}.db"
    wal_path = directory / f"{conversation_id}.db-wal"
    shm_path = directory / f"{conversation_id}.db-shm"

    conn = sqlite3.connect(str(db_path))
    try:
        cur = conn.cursor()
        # Create steps table
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS steps (
                idx INTEGER PRIMARY KEY,
                step_type INTEGER DEFAULT 0,
                status INTEGER DEFAULT 0,
                has_subtrajectory NUMERIC DEFAULT 'false',
                metadata BLOB,
                error_details BLOB,
                permissions BLOB,
                task_details BLOB,
                render_info BLOB,
                step_payload BLOB,
                step_format INTEGER DEFAULT 0
            )
            """
        )

        # Create trajectory metadata blob table matching live schema
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS trajectory_metadata_blob (
                id TEXT DEFAULT 'main',
                data BLOB,
                PRIMARY KEY (id)
            )
            """
        )

        # Insert steps
        status_val = step_status if is_active else 3
        cur.execute(
            "INSERT INTO steps (idx, status) VALUES (1, ?)", (status_val,)
        )

        # Insert metadata blob with parent ID if subagent
        if parent_conversation_id:
            pid_bytes = parent_conversation_id.encode("utf-8")
            # Tag 5 (wire 2 = 0x2a): length-delimited parent_conversation_id
            # Tag 17 (wire 0 = 0x88 0x01): varint nesting_depth = 1
            payload = (
                b"\x2a" + bytes([len(pid_bytes)]) + pid_bytes
                + b"\x88\x01\x01"
            )
            cur.execute("INSERT OR REPLACE INTO trajectory_metadata_blob (id, data) VALUES ('main', ?)", (payload,))
        else:
            payload = b"\x12\x0c\x08\xd4\xf2\x9b\xd6\x06\x10\xc4\xcd\xfc\x81\x03\x1a$root-conversation"
            cur.execute("INSERT OR REPLACE INTO trajectory_metadata_blob (id, data) VALUES ('main', ?)", (payload,))

        conn.commit()
    finally:
        conn.close()

    # Create WAL file
    if wal_bytes > 0:
        wal_path.write_bytes(b"\x00" * wal_bytes)
    else:
        wal_path.write_bytes(b"")

    shm_path.write_bytes(b"\x00" * 32768)
    return db_path


def reference_oracle_detect_antigravity(directory: Path) -> dict:
    """Authoritative detection engine executing scripts/watch_antigravity.py:check_state.
    
    1. Scans directory for non-empty .db-wal files.
    2. For each matching database, queries active step statuses IN (1, 2, 8, 11).
    3. Distinguishes root agents from subagents via parent_conversation_id in trajectory_metadata_blob.
    4. Returns {"active": bool, "subagents": int, "total": int}
    """
    return check_state(str(directory))


def parse_split_parser_lines(buffer: str, chunk: str) -> tuple[list[str], str]:
    """Simulates Quickshell SplitParser newline splitting behavior.
    
    Takes existing accumulator buffer + incoming chunk,
    splits by newline, returns (completed_lines, remaining_buffer).
    """
    accum = buffer + chunk
    lines = accum.split("\n")
    return lines[:-1], lines[-1]


def compute_sine_wave_point(
    x: float, width: float, height: float, phase: float, subagents: int = 0
) -> float:
    """Simulates AntigravityWave.qml continuous sine ribbon math.
    
    Uses dual-harmonic sine formula with boundary taper:
    f(x) = y_center + A * taper(x) * (sin(k1*x + phase) + 0.35*sin(k2*x - 0.5*phase))
    """
    if width <= 0 or height <= 0:
        return 0.0
    norm_x = x / width
    # Taper at edges so wave anchors gracefully at 0
    taper = math.sin(norm_x * math.pi)
    clamped_subagents = max(0, min(subagents, 5))
    base_amplitude = (height * 0.35) * (1.0 + clamped_subagents * 0.05)
    k1 = 2.0 * math.pi / width * 1.5
    k2 = 2.0 * math.pi / width * 3.0
    y_center = height / 2.0
    displacement = base_amplitude * taper * (
        math.sin(k1 * x + phase) + 0.35 * math.sin(k2 * x - 0.5 * phase)
    )
    return y_center + displacement


def calculate_badge_visibility_and_text(subagents: int) -> tuple[bool, str]:
    """Specification rule from ORIGINAL_REQUEST §R2:
    - 0 subagents: hidden ("")
    - 1 subagent: hidden ("")
    - >=2 subagents: visible (str(subagents))
    """
    if subagents >= 2:
        return True, str(subagents)
    return False, ""


def calculate_effective_visibility(active: bool, enabled: bool) -> bool:
    """Specification rule: effectiveAntigravityVisible = antigravityActive && antigravityEnabled"""
    return bool(active and enabled)


def validate_qml_contains_contract(qml_text: str, contracts: list[str]) -> tuple[bool, list[str]]:
    """Checks whether QML file content satisfies specified contracts."""
    missing = [c for c in contracts if c not in qml_text]
    return len(missing) == 0, missing


def is_valid_hex_color(hex_str: str) -> bool:
    """Validates 3, 6, or 8 digit hex color codes."""
    if not isinstance(hex_str, str):
        return False
    hex_str = hex_str.strip()
    return bool(re.match(r"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", hex_str))
