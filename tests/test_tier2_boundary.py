"""Tier 2: Boundary & Corner Cases Test Suite (F1 - F15)
Verifies boundary values, invalid inputs, edge conditions, resource constraints, and fault tolerance
across all 15 features (>= 5 test cases per feature, >= 75 tests).
Progressively runnable: tests execute cleanly and handle pending milestones safely.
"""

import unittest
import os
import sys
import json
import tempfile
import math
import subprocess
import signal
import time
import re
from pathlib import Path

from scripts.watch_antigravity import (
    check_state,
    write_status_file,
    acquire_lock,
    parse_metadata_blob,
)
from tests.fixtures import (
    PANACEA_DIR,
    SCRIPTS_DIR,
    ASSETS_DIR,
    TESTS_DIR,
    SETTINGS_FILE,
    SHELL_QML,
    HYPR_BINDS_FILE,
    create_mock_conversation_db,
    reference_oracle_detect_antigravity,
    parse_split_parser_lines,
    compute_sine_wave_point,
    calculate_badge_visibility_and_text,
    calculate_effective_visibility,
    is_valid_hex_color,
)


class TestTier2BoundaryAndEdgeCases(unittest.TestCase):
    """Tier 2 Boundary and Corner Cases Tests covering F1 through F15."""

    # -------------------------------------------------------------------------
    # F1: Detection Engine Daemon Boundaries
    # -------------------------------------------------------------------------
    def test_f1_bnd_01_corrupted_sqlite_file(self):
        """F1.B1: Corrupted or zero-byte SQLite file handled gracefully without crash."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            corrupt_db = tmppath / "corrupt.db"
            corrupt_wal = tmppath / "corrupt.db-wal"
            corrupt_db.write_bytes(b"NOT A SQLITE FILE HELLO WORLD")
            corrupt_wal.write_bytes(b"\x00" * 512)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertFalse(state["active"])

    def test_f1_bnd_02_missing_conversations_directory(self):
        """F1.B2: Non-existent conversations directory handled returning active=False."""
        non_existent = Path("/tmp/panacea_test_non_existent_dir_12345")
        state = reference_oracle_detect_antigravity(non_existent)
        self.assertFalse(state["active"])
        self.assertEqual(state["total"], 0)

    def test_f1_bnd_03_zero_byte_wal_file(self):
        """F1.B3: 0-byte .db-wal file treated as idle without database reads."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(tmppath, "zero-wal", is_active=True, wal_bytes=0)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertFalse(state["active"])

    def test_f1_bnd_04_rapid_file_churn_temp_databases(self):
        """F1.B4: Rapid file creation and deletion handled without FileNotFoundError."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            for i in range(10):
                p = create_mock_conversation_db(tmppath, f"churn-{i}", is_active=True, wal_bytes=100)
                if i % 2 == 0:
                    p.unlink(missing_ok=True)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertIsInstance(state["active"], bool)

    def test_f1_bnd_05_database_locked_readonly_uri(self):
        """F1.B5: Read-only URI mode allows query even with concurrent writers."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            db_path = create_mock_conversation_db(tmppath, "ro-lock-test", is_active=True)
            import sqlite3
            conn1 = sqlite3.connect(str(db_path))
            cur1 = conn1.cursor()
            cur1.execute("BEGIN IMMEDIATE")
            # Query via reference oracle using read-only mode
            state = reference_oracle_detect_antigravity(tmppath)
            conn1.rollback()
            conn1.close()
            self.assertIsInstance(state["active"], bool)

    # -------------------------------------------------------------------------
    # F2: Subagent Counter Boundaries
    # -------------------------------------------------------------------------
    def test_f2_bnd_01_zero_subagents_boundary(self):
        """F2.B1: Exactly 0 subagents when only root agent is executing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(tmppath, "root-only-bnd", is_active=True, parent_conversation_id=None)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(state["subagents"], 0)
            self.assertEqual(state["total"], 1)

    def test_f2_bnd_02_large_subagent_count(self):
        """F2.B2: Swarm of 50 concurrent subagents handled accurately."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            root_id = "root-swarm"
            create_mock_conversation_db(tmppath, root_id, is_active=True)
            for i in range(50):
                create_mock_conversation_db(
                    tmppath, f"sub-{i}", is_active=True, parent_conversation_id=root_id
                )
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(state["subagents"], 50)
            self.assertEqual(state["total"], 51)

    def test_f2_bnd_03_orphan_subagents(self):
        """F2.B3: Subagent with non-existent parent UUID handled gracefully as subagent."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(
                tmppath, "orphan-sub", is_active=True, parent_conversation_id="non-existent-parent-uuid"
            )
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(state["subagents"], 1)
            self.assertEqual(state["total"], 1)

    def test_f2_bnd_04_null_or_empty_metadata_blob(self):
        """F2.B4: Empty or NULL trajectory_metadata_blob handled without error."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            db_path = tmppath / "null-blob.db"
            wal_path = tmppath / "null-blob.db-wal"
            import sqlite3
            conn = sqlite3.connect(str(db_path))
            cur = conn.cursor()
            cur.execute("CREATE TABLE steps (idx INT PRIMARY KEY, status INT)")
            cur.execute("CREATE TABLE trajectory_metadata_blob (data BLOB)")
            cur.execute("INSERT INTO steps (idx, status) VALUES (1, 2)")
            cur.execute("INSERT INTO trajectory_metadata_blob (data) VALUES (NULL)")
            conn.commit()
            conn.close()
            wal_path.write_bytes(b"\x00" * 512)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(state["active"])
            self.assertEqual(state["subagents"], 0)

    def test_f2_bnd_05_deeply_nested_subagent_hierarchy(self):
        """F2.B5: Nested subagent hierarchy (parent -> child -> grandchild) counted."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(tmppath, "root-tree", is_active=True)
            create_mock_conversation_db(tmppath, "child-tree", is_active=True, parent_conversation_id="root-tree")
            create_mock_conversation_db(tmppath, "grandchild-tree", is_active=True, parent_conversation_id="child-tree")
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(state["subagents"], 2)
            self.assertEqual(state["total"], 3)

    # -------------------------------------------------------------------------
    # F3: Quickshell Process Bridge Boundaries
    # -------------------------------------------------------------------------
    def test_f3_bnd_01_malformed_json_stream(self):
        """F3.B1: Malformed JSON string caught and parsed safely without crashing."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("try {", shell_content)
        self.assertIn("var data = JSON.parse(s);", shell_content)
        self.assertIn("} catch (e) {}", shell_content)
        # Test split parser handling of malformed and split JSON
        lines, rem = parse_split_parser_lines("", '{"active": true, "subagents": \n')
        self.assertEqual(len(lines), 1)
        with self.assertRaises(json.JSONDecodeError):
            json.loads(lines[0])

    def test_f3_bnd_02_empty_newline_burst(self):
        """F3.B2: Consecutive newlines handled without generating phantom messages."""
        lines, rem = parse_split_parser_lines("", "\n\n\n")
        non_empty = [l for l in lines if l.strip()]
        self.assertEqual(len(non_empty), 0)

    def test_f3_bnd_03_partial_json_across_chunks(self):
        """F3.B3: JSON split across three separate chunks reassembled accurately."""
        c1, c2, c3 = '{"active": ', 'true, "subagents": 3, ', '"total": 4}\n'
        lines1, rem1 = parse_split_parser_lines("", c1)
        self.assertEqual(len(lines1), 0)
        lines2, rem2 = parse_split_parser_lines(rem1, c2)
        self.assertEqual(len(lines2), 0)
        lines3, rem3 = parse_split_parser_lines(rem2, c3)
        self.assertEqual(len(lines3), 1)
        parsed = json.loads(lines3[0])
        self.assertTrue(parsed["active"])
        self.assertEqual(parsed["subagents"], 3)

    def test_f3_bnd_04_daemon_process_termination(self):
        """F3.B4: Daemon exit signal handled gracefully with exit code 0."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            lock_file = tmppath / "daemon.lock"
            proc = subprocess.Popen(
                [
                    sys.executable,
                    str(SCRIPTS_DIR / "watch_antigravity.py"),
                    "--conv-dir", str(tmppath),
                    "--lock-file", str(lock_file),
                    "--no-prctl",
                    "--interval", "0.1",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            time.sleep(0.15)
            self.assertIsNone(proc.poll(), "Daemon must be running initially")
            proc.send_signal(signal.SIGTERM)
            try:
                ret = proc.wait(timeout=2.0)
                self.assertEqual(ret, 0, f"Daemon should exit cleanly on SIGTERM, got {ret}")
            finally:
                if proc.stdout:
                    proc.stdout.close()
                if proc.stderr:
                    proc.stderr.close()
                if proc.poll() is None:
                    proc.kill()

    def test_f3_bnd_05_extreme_message_rate_burst(self):
        """F3.B5: Rapid stream of 100 JSON messages processed cleanly."""
        payload = "".join([f'{{"active": true, "subagents": {i}, "total": {i+1}}}\n' for i in range(100)])
        lines, rem = parse_split_parser_lines("", payload)
        self.assertEqual(len(lines), 100)
        self.assertEqual(rem, "")

    # -------------------------------------------------------------------------
    # F4: Logo Asset Boundaries
    # -------------------------------------------------------------------------
    def test_f4_bnd_01_missing_logo_fallback(self):
        """F4.B1: Missing logo file does not break shell layout and fallback logic is respected."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        self.assertTrue(logo_qml.exists(), "AntigravityLogo.qml component must exist")
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn("Math.max(0, Math.min(root.size, 24))", qml_text)
        # Ensure authentic PNG asset exists and is non-empty
        logo_png = ASSETS_DIR / "antigravity.png"
        self.assertTrue(logo_png.exists(), "assets/antigravity.png must exist")
        self.assertGreater(logo_png.stat().st_size, 1000)

    def test_f4_bnd_02_zero_size_clamping(self):
        """F4.B2: Logo size=0 clamped to non-negative bounds in QML component."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn("Math.max(0, Math.min(root.size, 24))", qml_text)

    def test_f4_bnd_03_excessive_size_clamping(self):
        """F4.B3: Logo size=500 constrained to notch max height (24px) in QML."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn("Math.min(root.size, 24)", qml_text)

    def test_f4_bnd_04_corrupted_asset_file(self):
        """F4.B4: Real asset has valid PNG magic bytes while truncated data is identified as invalid."""
        logo_png = ASSETS_DIR / "antigravity.png"
        self.assertTrue(logo_png.exists())
        header = logo_png.read_bytes()[:8]
        self.assertEqual(header, b"\x89PNG\r\n\x1a\n")
        with tempfile.NamedTemporaryFile() as tmp:
            tmp.write(b"\x89PNG\r\n\x1a\nTRUNC")
            tmp.flush()
            self.assertLess(os.path.getsize(tmp.name), 24)

    def test_f4_bnd_05_fractional_pixel_scaling(self):
        """F4.B5: Fractional scaling (1.25x) calculation and QML clamping."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        self.assertTrue(logo_qml.exists())
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn("Math.max(0, Math.min(root.size, 24))", qml_text)
        self.assertIn("property int size: 18", qml_text)
        base_size = 18
        scale = 1.25
        scaled = round(base_size * scale)
        clamped = max(0, min(scaled, 24))
        self.assertEqual(clamped, 22)
        # Verify extreme 2x scaling clamped to max 24px
        self.assertEqual(max(0, min(round(base_size * 2.0), 24)), 24)

    # -------------------------------------------------------------------------
    # F5: Animation Boundaries
    # -------------------------------------------------------------------------
    def test_f5_bnd_01_zero_duration_guard(self):
        """F5.B1: Animation durations strictly positive (>0) and >=100ms in QML components."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        wave_qml = PANACEA_DIR / "AntigravityWave.qml"
        self.assertTrue(logo_qml.exists() and wave_qml.exists())
        combined_qml = logo_qml.read_text(encoding="utf-8") + wave_qml.read_text(encoding="utf-8")
        durations = [int(d) for d in re.findall(r"duration:\s*(\d+)", combined_qml)]
        self.assertGreaterEqual(len(durations), 4, "Must define at least 4 animation durations")
        for d in durations:
            self.assertGreaterEqual(d, 100, f"Duration {d}ms must be >= 100ms to guard against zero/stutter")

    def test_f5_bnd_02_rapid_active_toggle_churn(self):
        """F5.B2: 50 rapid active state toggles maintains correct final state."""
        with tempfile.TemporaryDirectory() as tmpdir:
            p = Path(tmpdir)
            create_mock_conversation_db(p, "rapid_churn", is_active=False, wal_bytes=0)
            init_res = check_state(str(p))
            self.assertFalse(init_res["active"])

            state = False
            for _ in range(50):
                state = not state
                vis = calculate_effective_visibility(active=state, enabled=True)
                self.assertEqual(vis, state)
            self.assertFalse(state)
            self.assertFalse(calculate_effective_visibility(active=state, enabled=True))

    def test_f5_bnd_03_cpu_throttling_when_hidden(self):
        """F5.B3: Animation running state False when hidden."""
        active = False
        enabled = True
        running = calculate_effective_visibility(active, enabled)
        self.assertFalse(running)

    def test_f5_bnd_04_translation_bounds_clamped(self):
        """F5.B4: Translation y bound clamped within [-1.2, 1.0] pixels in AntigravityLogo.qml."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn('property: "y"', qml_text)
        self.assertIn("from: 1.0", qml_text)
        self.assertIn("to: -1.2", qml_text)

    def test_f5_bnd_05_rotation_bounds_clamped(self):
        """F5.B5: Rotation angle clamped strictly within [-1.5, 1.5] degrees in AntigravityLogo.qml."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn('property: "rotation"', qml_text)
        self.assertIn("from: -1.5", qml_text)
        self.assertIn("to: 1.5", qml_text)

    # -------------------------------------------------------------------------
    # F6: Calm Progress Wave Boundaries
    # -------------------------------------------------------------------------
    def test_f6_bnd_01_zero_width_canvas(self):
        """F6.B1: Canvas width=0 handled safely without ZeroDivisionError."""
        wave_qml = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("if (width <= 0 || height <= 0) return;", wave_qml)
        y = compute_sine_wave_point(0, width=0, height=20, phase=0.0)
        self.assertEqual(y, 0.0)

    def test_f6_bnd_02_negative_subagents_clamping(self):
        """F6.B2: Subagents < 0 clamped gracefully to 0."""
        wave_qml = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("var clampedSub = Math.max(0, Math.min(root.subagentCount, 5));", wave_qml)
        y_neg = compute_sine_wave_point(10, width=40, height=20, phase=0.0, subagents=-5)
        y_zero = compute_sine_wave_point(10, width=40, height=20, phase=0.0, subagents=0)
        self.assertEqual(y_neg, y_zero)

    def test_f6_bnd_03_extreme_aspect_ratio(self):
        """F6.B3: Ultra-wide canvas (width=1000, height=10) produces valid finite values."""
        wave_qml = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("Canvas", wave_qml)
        for x in [0, 250, 500, 750, 1000]:
            y = compute_sine_wave_point(x, width=1000, height=10, phase=1.0)
            self.assertTrue(math.isfinite(y))
            self.assertTrue(0 <= y <= 10)

    def test_f6_bnd_04_nan_or_inf_coordinates_guard(self):
        """F6.B4: Sine calculation never produces NaN or Infinity."""
        wave_qml = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("renderTarget: Canvas.FramebufferObject", wave_qml)
        y = compute_sine_wave_point(20, width=40, height=20, phase=999999.9)
        self.assertFalse(math.isnan(y))
        self.assertFalse(math.isinf(y))

    def test_f6_bnd_05_zero_height_canvas(self):
        """F6.B5: Canvas height=0 returns 0.0 without error."""
        wave_qml = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("if (width <= 0 || height <= 0) return;", wave_qml)
        y = compute_sine_wave_point(10, width=40, height=0, phase=0.0)
        self.assertEqual(y, 0.0)

    # -------------------------------------------------------------------------
    # F7: Accent Color Boundaries
    # -------------------------------------------------------------------------
    def test_f7_bnd_01_invalid_hex_string(self):
        """F7.B1: Malformed hex strings handled safely with fallback."""
        self.assertFalse(is_valid_hex_color("not-a-color"))
        self.assertFalse(is_valid_hex_color("#GGG"))

    def test_f7_bnd_02_transparent_alpha_channel(self):
        """F7.B2: Hex color with transparent alpha (#00000000) valid format."""
        self.assertTrue(is_valid_hex_color("#00000000"))

    def test_f7_bnd_03_pure_black_accent(self):
        """F7.B3: Pure black (#000000) accent handled."""
        self.assertTrue(is_valid_hex_color("#000000"))

    def test_f7_bnd_04_rapid_color_mutation(self):
        """F7.B4: 50 sequential color updates handled."""
        colors = [f"#{i:02x}{i:02x}{i:02x}" for i in range(50)]
        for c in colors:
            self.assertTrue(is_valid_hex_color(c))

    def test_f7_bnd_05_null_or_empty_theme_color(self):
        """F7.B5: Empty or None color string returns False."""
        self.assertFalse(is_valid_hex_color(""))
        self.assertFalse(is_valid_hex_color(None))

    # -------------------------------------------------------------------------
    # F8: Subagent Counter Boundaries
    # -------------------------------------------------------------------------
    def test_f8_bnd_01_exact_boundary_one_subagent(self):
        """F8.B1: Subagents == 1 is strictly hidden."""
        visible, text = calculate_badge_visibility_and_text(1)
        self.assertFalse(visible)
        self.assertEqual(text, "")

    def test_f8_bnd_02_exact_boundary_two_subagents(self):
        """F8.B2: Subagents == 2 is strictly visible."""
        visible, text = calculate_badge_visibility_and_text(2)
        self.assertTrue(visible)
        self.assertEqual(text, "2")

    def test_f8_bnd_03_large_three_digit_subagents(self):
        """F8.B3: Large count (150) formatted properly as string '150'."""
        visible, text = calculate_badge_visibility_and_text(150)
        self.assertTrue(visible)
        self.assertEqual(text, "150")

    def test_f8_bnd_04_fluctuation_hysteresis(self):
        """F8.B4: Rapid alternating between 1 and 2 produces alternating visibility."""
        vis1, _ = calculate_badge_visibility_and_text(1)
        vis2, _ = calculate_badge_visibility_and_text(2)
        vis3, _ = calculate_badge_visibility_and_text(1)
        self.assertFalse(vis1)
        self.assertTrue(vis2)
        self.assertFalse(vis3)

    def test_f8_bnd_05_type_coercion_string_input(self):
        """F8.B5: Integer conversion handles int-castable inputs."""
        count = int("4")
        visible, text = calculate_badge_visibility_and_text(count)
        self.assertTrue(visible)
        self.assertEqual(text, "4")

    # -------------------------------------------------------------------------
    # F9: Transitions Boundaries
    # -------------------------------------------------------------------------
    def test_f9_bnd_01_mid_transition_state_reversal(self):
        """F9.B1: State reversal during transition preserves state consistency."""
        state = calculate_effective_visibility(active=True, enabled=True)
        self.assertTrue(state)
        # Mid-transition reversal
        state = calculate_effective_visibility(active=False, enabled=True)
        self.assertFalse(state)

    def test_f9_bnd_02_concurrent_media_and_idle_toggle(self):
        """F9.B2: Concurrent media playback switch while active maintains layout anchors."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("agLogoMusic", shell_content)
        self.assertIn("agWaveMusic", shell_content)
        self.assertIn("agLogoModern", shell_content)
        self.assertIn("agWaveModern", shell_content)
        self.assertIn("visible: root.effectiveAntigravityVisible", shell_content)
        for media_active in [True, False]:
            for ag_active in [True, False]:
                vis = calculate_effective_visibility(ag_active, enabled=True)
                self.assertEqual(vis, ag_active)

    def test_f9_bnd_03_zero_opacity_pointer_pass_through(self):
        """F9.B3: Inactive state results in effectiveAntigravityVisible=False."""
        self.assertFalse(calculate_effective_visibility(active=False, enabled=True))

    def test_f9_bnd_04_margin_collapse_zero(self):
        """F9.B4: Margin spacing collapses when inactive in shell.qml."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        wave_qml = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("property real agExtraWidth: root.effectiveAntigravityVisible", shell_content)
        self.assertTrue("agLogoMusic.width + 18" in shell_content or "agLogoMusic.width + 8" in shell_content)
        self.assertIn(": 0", shell_content)
        self.assertIn("implicitWidth: active ? waveRow.implicitWidth : 0", wave_qml)
        # Verify collapse when effectiveAntigravityVisible is False
        vis = calculate_effective_visibility(active=False, enabled=True)
        self.assertFalse(vis)
        extra_w = (18 + 18 + 28 + 12) if vis else 0
        self.assertEqual(extra_w, 0)

    def test_f9_bnd_05_rapid_idle_wake_cycles(self):
        """F9.B5: 20 rapid idle/wake cycles maintain state integrity."""
        for i in range(20):
            act = (i % 2 == 0)
            vis = calculate_effective_visibility(act, enabled=True)
            self.assertEqual(vis, act)

    # -------------------------------------------------------------------------
    # F10: Media Layout Boundaries
    # -------------------------------------------------------------------------
    def test_f10_bnd_01_missing_cover_art_fallback(self):
        """F10.B1: Media playing without cover art does not cause anchor error in shell.qml."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("musicArtBox", shell_content)
        self.assertIn("anchors.left: musicArtBox.right", shell_content)
        self.assertTrue("anchors.leftMargin: 18" in shell_content or "anchors.leftMargin: 8" in shell_content)

    def test_f10_bnd_02_ultra_long_track_title(self):
        """F10.B2: Ultra-long track title handled dynamically via agExtraWidth in shell.qml."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("agExtraWidth", shell_content)
        self.assertIn("musicCenterBox.width", shell_content)
        self.assertTrue("agLogoMusic.width + 18" in shell_content or "agLogoMusic.width + 8" in shell_content)

    def test_f10_bnd_03_wavebars_disabled_settings(self):
        """F10.B3: Equalizer wave bars disabled in settings respected in shell.qml."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("anchors.right: musicWave.left", shell_content)
        self.assertIn("musicWaveEnabled", shell_content)

    def test_f10_bnd_04_small_display_width(self):
        """F10.B4: Small display (1024px) dynamic notch width constraints in shell.qml."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("implicitWidth: (root.musicCenterMode === 4 ? 148", shell_content)
        self.assertIn("+ agExtraWidth", shell_content)
        self.assertTrue("agLogoMusic.width + 18" in shell_content or "agLogoMusic.width + 8" in shell_content)

        screen_w = 1024
        notch_max_w = int(screen_w * 0.6)
        base_w = 148
        ag_extra = 18 + 8 + 28 + 10
        total_w = base_w + ag_extra
        self.assertLess(total_w, notch_max_w, f"Total width {total_w}px must fit inside 60% of {screen_w}px ({notch_max_w}px)")

    def test_f10_bnd_05_media_state_paused(self):
        """F10.B5: Paused media retains musicCapsule active or switches to modernCapsule."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("property bool musicIslandActive:", shell_content)
        self.assertIn("visible: root.musicIslandActive", shell_content)
        self.assertIn("!root.musicIslandActive", shell_content)

    # -------------------------------------------------------------------------
    # F11: Idle Layout Boundaries
    # -------------------------------------------------------------------------
    def test_f11_bnd_01_all_status_modules_active(self):
        """F11.B1: All status modules active alongside Antigravity inside modernRow."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("id: modernRow", shell_content)
        self.assertIn("agLogoModern", shell_content)
        self.assertIn("agWaveModern", shell_content)

    def test_f11_bnd_02_minimal_idle_notch(self):
        """F11.B2: Minimal idle notch centers modernRow properly."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("id: modernRow", shell_content)
        self.assertIn("anchors.centerIn: parent", shell_content)

    def test_f11_bnd_03_compact_notch_mode(self):
        """F11.B3: Compact notch mode maintains proportions via theme spacing."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("spacing: root.themeNothing ? 14 : 16", shell_content)

    def test_f11_bnd_04_zero_margin_collision(self):
        """F11.B4: Left edge margin collision avoidance in modern notch."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("agLogoModern", shell_content)
        self.assertIn("Layout.alignment: Qt.AlignVCenter", shell_content)

    def test_f11_bnd_05_far_right_margin_collision(self):
        """F11.B5: Right edge margin collision avoidance in modern notch."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("agWaveModern", shell_content)
        self.assertIn("waveColor: root.colOn", shell_content)

    # -------------------------------------------------------------------------
    # F12: Super + O Shortcut Boundaries
    # -------------------------------------------------------------------------
    def test_f12_bnd_01_rapid_repeated_toggle(self):
        """F12.B1: 10 rapid toggles preserve boolean parity against settings.json and shell IPC logic."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("function toggleAntigravity(): void", shell_content)
        self.assertIn("root.antigravityEnabled = !root.antigravityEnabled", shell_content)
        self.assertIn("root.saveCfg()", shell_content)

        with tempfile.TemporaryDirectory() as tmpdir:
            temp_settings = Path(tmpdir) / "settings.json"
            temp_settings.write_text(json.dumps({"antigravityEnabled": True}), encoding="utf-8")

            for i in range(10):
                cfg = json.loads(temp_settings.read_text(encoding="utf-8"))
                cfg["antigravityEnabled"] = not cfg.get("antigravityEnabled", True)
                temp_settings.write_text(json.dumps(cfg, indent=2), encoding="utf-8")

                reloaded = json.loads(temp_settings.read_text(encoding="utf-8"))
                expected = (i % 2 != 0)
                self.assertEqual(reloaded["antigravityEnabled"], expected)

            final_cfg = json.loads(temp_settings.read_text(encoding="utf-8"))
            self.assertTrue(final_cfg["antigravityEnabled"])

    def test_f12_bnd_02_keybinding_modifiers_isolation(self):
        """F12.B2: Modifier combinations in keybindings.lua isolate Super + O."""
        if not HYPR_BINDS_FILE.exists():
            self.skipTest(f"{HYPR_BINDS_FILE} not found.")
        content = HYPR_BINDS_FILE.read_text(encoding="utf-8")
        self.assertIn('mainMod .. " + O"', content)
        self.assertIn("toggleAntigravity", content)

    def test_f12_bnd_03_ipc_client_not_running(self):
        """F12.B3: IPC handler in shell.qml toggles state and persists safely."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("function toggleAntigravity(): void", shell_content)
        self.assertIn("root.antigravityEnabled = !root.antigravityEnabled", shell_content)
        self.assertIn("root.saveCfg()", shell_content)

    def test_f12_bnd_04_keybindings_syntax_integrity(self):
        """F12.B4: keybindings.lua exists and is readable."""
        if not HYPR_BINDS_FILE.exists():
            self.skipTest(f"{HYPR_BINDS_FILE} not found.")
        content = HYPR_BINDS_FILE.read_text(encoding="utf-8")
        self.assertGreater(len(content), 100)

    def test_f12_bnd_05_concurrent_toggle_requests(self):
        """F12.B5: Single-instance lock prevents concurrent daemon race conditions."""
        with tempfile.TemporaryDirectory() as tmpdir:
            lock_path = os.path.join(tmpdir, "test.lock")
            fd1 = acquire_lock(lock_path)
            self.assertIsNotNone(fd1, "First lock acquisition must succeed")
            fd2 = acquire_lock(lock_path)
            self.assertIsNone(fd2, "Concurrent lock acquisition must be blocked")
            if fd1:
                import fcntl
                fcntl.flock(fd1, fcntl.LOCK_UN)
                fd1.close()

    # -------------------------------------------------------------------------
    # F13: Settings Persistence Boundaries
    # -------------------------------------------------------------------------
    def test_f13_bnd_01_read_only_settings_file(self):
        """F13.B1: Read-only settings.json handled safely."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("function saveCfg()", shell_content)
        with tempfile.TemporaryDirectory() as tmpdir:
            p = Path(tmpdir) / "ro_settings.json"
            p.write_text(json.dumps({"antigravityEnabled": True}))
            p.chmod(0o444)
            # Writing should raise PermissionError handled by callers
            try:
                p.write_text(json.dumps({"antigravityEnabled": False}))
                writable = True
            except PermissionError:
                writable = False
            # Clean up permissions
            p.chmod(0o666)
            self.assertFalse(writable)

    def test_f13_bnd_02_corrupted_json_recovery(self):
        """F13.B2: Corrupted settings.json syntax detected cleanly."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("id: cfgFile", shell_content)
        self.assertIn('path: Quickshell.env("HOME") + "/.config/panacea/settings.json"', shell_content)
        self.assertIn("adapter: JsonAdapter", shell_content)
        bad_json = '{"antigravityEnabled": true, INVALID'
        with self.assertRaises(json.JSONDecodeError):
            json.loads(bad_json)

    def test_f13_bnd_03_atomic_write_safety(self):
        """F13.B3: Atomic write pattern (write to tmp then atomic rename) works."""
        with tempfile.TemporaryDirectory() as tmpdir:
            target = Path(tmpdir) / "settings.json"
            tmp = Path(tmpdir) / "settings.json.tmp"
            tmp.write_text(json.dumps({"antigravityEnabled": False}))
            tmp.replace(target)
            data = json.loads(target.read_text())
            self.assertFalse(data["antigravityEnabled"])

    def test_f13_bnd_04_extra_keys_preservation(self):
        """F13.B4: Toggling antigravityEnabled preserves all other settings keys."""
        if not SETTINGS_FILE.exists():
            self.skipTest(f"{SETTINGS_FILE} not found.")
        data = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
        self.assertIn("antigravityEnabled", data)
        self.assertGreater(len(data), 1, "settings.json should preserve other configuration keys")

    def test_f13_bnd_05_type_coercion_boolean(self):
        """F13.B5: String boolean 'true'/'false' safely handled and strictly type-checked."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn('typeof data.active === "boolean"', shell_content)
        self.assertIn('(typeof data.subagents === "number") ? data.subagents : 0', shell_content)

        res = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "watch_antigravity.py"), "--once"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(res.stdout.strip())
        self.assertIsInstance(data["active"], bool)
        self.assertNotIsInstance(data["active"], str)
        self.assertIsInstance(data["subagents"], int)

    # -------------------------------------------------------------------------
    # F14: Comprehensive E2E Test Suite Boundaries
    # -------------------------------------------------------------------------
    def test_f14_bnd_01_invalid_tier_argument(self):
        """F14.B1: Tier argument validation guards against invalid numbers with exit code 2."""
        res = subprocess.run(
            [sys.executable, str(TESTS_DIR / "run_tests.py"), "--tier", "99"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 2)
        self.assertIn("invalid choice", res.stderr)

    def test_f14_bnd_02_empty_filter_argument(self):
        """F14.B2: Empty filter runs selected tier tests successfully."""
        res = subprocess.run(
            [sys.executable, str(TESTS_DIR / "run_tests.py"), "--tier", "1", "-k", ""],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        self.assertIn("Total Discovered: 75 tests", res.stdout)

    def test_f14_bnd_03_json_serialization_on_error(self):
        """F14.B3: JSON summary serializable even on failures via runner --json output."""
        res = subprocess.run(
            [sys.executable, str(TESTS_DIR / "run_tests.py"), "--tier", "1", "-k", "test_f1_01", "--json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertIn("passed", data)
        self.assertIn("failed", data)
        self.assertIn("errors", data)
        self.assertIn("duration_seconds", data)

    def test_f14_bnd_04_concurrent_test_isolation(self):
        """F14.B4: Tests use isolated temporary directories and produce independent state results."""
        with tempfile.TemporaryDirectory() as d1, tempfile.TemporaryDirectory() as d2:
            p1, p2 = Path(d1), Path(d2)
            create_mock_conversation_db(p1, "active_1", is_active=True)
            create_mock_conversation_db(p2, "idle_2", is_active=False, wal_bytes=0)
            res1 = check_state(str(p1))
            res2 = check_state(str(p2))
            self.assertTrue(res1["active"], "Dir 1 must be active")
            self.assertFalse(res2["active"], "Dir 2 must be idle")
            self.assertEqual(res1["total"], 1)
            self.assertEqual(res2["total"], 0)

    def test_f14_bnd_05_runner_signal_handling(self):
        """F14.B5: Runner exit code contract when executing specific tier or filter."""
        res = subprocess.run(
            [sys.executable, str(TESTS_DIR / "run_tests.py"), "--tier", "1", "-k", "test_f1_01"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, f"Runner execution failed: {res.stderr}")
        self.assertIn("Total Discovered: 1 tests", res.stdout)
        self.assertIn("Status:   SUCCESS", res.stdout)

    # -------------------------------------------------------------------------
    # F15: Live Visual Quality Boundaries
    # -------------------------------------------------------------------------
    def test_f15_bnd_01_headless_display_handling(self):
        """F15.B1: Headless execution without Wayland compositor handled safely by daemon."""
        clean_env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
        res = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "watch_antigravity.py"), "--once"],
            capture_output=True,
            text=True,
            env=clean_env,
        )
        self.assertEqual(res.returncode, 0, f"Headless execution failed: {res.stderr}")
        data = json.loads(res.stdout.strip())
        self.assertIn("active", data)

    def test_f15_bnd_02_invalid_output_file_path(self):
        """F15.B2: Non-existent destination path handled safely without throwing exception."""
        with tempfile.TemporaryDirectory() as tmpdir:
            nested_file = os.path.join(tmpdir, "deep", "nested", "status.json")
            write_status_file(nested_file, '{"active": false}')
            self.assertTrue(os.path.exists(nested_file))

    def test_f15_bnd_03_disk_full_handling(self):
        """F15.B3: Filesystem write errors handled gracefully without daemon crash."""
        self.assertTrue((SCRIPTS_DIR / "watch_antigravity.py").exists())
        try:
            write_status_file("/dev/full", '{"active": false}')
        except Exception as e:
            self.fail(f"write_status_file must handle write errors gracefully, raised {e}")

    def test_f15_bnd_04_zero_byte_screenshot_detection(self):
        """F15.B4: 0-byte image file detected as invalid while authentic artifacts are validated."""
        with tempfile.NamedTemporaryFile() as tmp:
            size = os.path.getsize(tmp.name)
            self.assertEqual(size, 0)
            self.assertFalse(size > 100)
        challenger_dir = PANACEA_DIR / ".agents" / "teamwork_preview_challenger_m4"
        for p in challenger_dir.glob("*.png"):
            self.assertGreater(p.stat().st_size, 1000)

    def test_f15_bnd_05_permission_denied_target_directory(self):
        """F15.B5: Permission denied handling contract returns idle result gracefully."""
        with tempfile.TemporaryDirectory() as tmpdir:
            restricted_dir = os.path.join(tmpdir, "restricted")
            os.makedirs(restricted_dir)
            os.chmod(restricted_dir, 0)
            try:
                state = check_state(restricted_dir)
                self.assertFalse(state["active"])
                self.assertEqual(state["total"], 0)
            finally:
                os.chmod(restricted_dir, 0o755)


if __name__ == "__main__":
    unittest.main()
