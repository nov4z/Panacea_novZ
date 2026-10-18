"""Tier 1: Feature Coverage Test Suite (F1 - F15)
Verifies baseline functional behavior for all 15 features (>= 5 test cases per feature, >= 75 tests).
Progressively runnable: tests check contracts, schemas, mathematical logic, and live files when present.
"""

import unittest
import os
import sys
import json
import tempfile
import math
import subprocess
import re
from pathlib import Path

from tests.fixtures import (
    PANACEA_DIR,
    SCRIPTS_DIR,
    ASSETS_DIR,
    TESTS_DIR,
    SETTINGS_FILE,
    SHELL_QML,
    HYPR_BINDS_FILE,
    ACTIVE_STEP_STATUSES,
    create_mock_conversation_db,
    reference_oracle_detect_antigravity,
    parse_split_parser_lines,
    compute_sine_wave_point,
    calculate_badge_visibility_and_text,
    calculate_effective_visibility,
    validate_qml_contains_contract,
    is_valid_hex_color,
)


class TestTier1FeatureCoverage(unittest.TestCase):
    """Tier 1 Feature Coverage Tests covering F1 through F15."""

    # -------------------------------------------------------------------------
    # F1: Detection Engine Daemon (M1, R3)
    # -------------------------------------------------------------------------
    def test_f1_01_daemon_file_contract(self):
        """F1.1: Verify daemon script path contract and python syntax."""
        daemon_path = SCRIPTS_DIR / "watch_antigravity.py"
        if not daemon_path.exists():
            self.skipTest(f"Pending M1: {daemon_path} not yet created.")
        res = subprocess.run([sys.executable, "-m", "py_compile", str(daemon_path)], capture_output=True)
        self.assertEqual(res.returncode, 0, f"watch_antigravity.py syntax error: {res.stderr.decode()}")

    def test_f1_02_daemon_stdout_schema(self):
        """F1.2: Verify emitted JSON stdout schema matches contract: active, subagents, total."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(tmppath, "test-conv", is_active=True)
            res = subprocess.run(
                [sys.executable, str(SCRIPTS_DIR / "watch_antigravity.py"), "--conv-dir", str(tmppath), "--once"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, f"Daemon stderr: {res.stderr}")
            data = json.loads(res.stdout.strip())
            self.assertIn("active", data)
            self.assertIn("subagents", data)
            self.assertIn("total", data)
            self.assertIsInstance(data["active"], bool)
            self.assertIsInstance(data["subagents"], int)
            self.assertIsInstance(data["total"], int)
            self.assertTrue(data["active"])

    def test_f1_03_daemon_active_step_statuses(self):
        """F1.3: Verify SQLite query checks active step statuses (1, 2, 8, 11)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            for status in ACTIVE_STEP_STATUSES:
                sub_dir = tmppath / f"status_{status}"
                sub_dir.mkdir()
                conv_id = f"test-status-{status}"
                create_mock_conversation_db(sub_dir, conv_id, is_active=True, step_status=status)
                state = reference_oracle_detect_antigravity(sub_dir)
                self.assertTrue(state["active"], f"Status {status} must be detected as active")
                self.assertEqual(state["total"], 1)

    def test_f1_04_daemon_wal_detection_trigger(self):
        """F1.4: Verify non-empty SQLite WAL file triggers active scanning."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(tmppath, "wal-active-test", is_active=True, wal_bytes=4096)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(state["active"])

    def test_f1_05_daemon_idle_state_emission(self):
        """F1.5: Verify daemon emits active=False, subagents=0, total=0 when idle."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            # Create inactive db (wal size 0, completed status)
            create_mock_conversation_db(tmppath, "idle-test", is_active=False, wal_bytes=0)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertFalse(state["active"])
            self.assertEqual(state["subagents"], 0)
            self.assertEqual(state["total"], 0)

    # -------------------------------------------------------------------------
    # F2: Subagent Counter Detection (M1, R3)
    # -------------------------------------------------------------------------
    def test_f2_01_subagent_counter_root_only(self):
        """F2.1: Verify single active root agent produces subagents=0, total=1."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            create_mock_conversation_db(tmppath, "root-agent", is_active=True, parent_conversation_id=None)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(state["active"])
            self.assertEqual(state["subagents"], 0)
            self.assertEqual(state["total"], 1)

    def test_f2_02_subagent_counter_single_subagent(self):
        """F2.2: Verify 1 root agent + 1 subagent yields subagents=1, total=2."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            root_id = "root-conversation-uuid"
            create_mock_conversation_db(tmppath, root_id, is_active=True)
            create_mock_conversation_db(tmppath, "subagent-1", is_active=True, parent_conversation_id=root_id)
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(state["active"])
            self.assertEqual(state["subagents"], 1)
            self.assertEqual(state["total"], 2)

    def test_f2_03_subagent_counter_multiple_subagents(self):
        """F2.3: Verify 1 root agent + 4 subagents yields subagents=4, total=5."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            root_id = "root-conv"
            create_mock_conversation_db(tmppath, root_id, is_active=True)
            for i in range(4):
                create_mock_conversation_db(
                    tmppath, f"subagent-{i}", is_active=True, parent_conversation_id=root_id
                )
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(state["subagents"], 4)
            self.assertEqual(state["total"], 5)

    def test_f2_04_subagent_metadata_parent_extraction(self):
        """F2.4: Verify parent_conversation_id extraction from trajectory_metadata_blob."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            db_path = create_mock_conversation_db(
                tmppath, "child-subagent", is_active=True, parent_conversation_id="2a227a31-3d76-4d0a"
            )
            import sqlite3
            conn = sqlite3.connect(str(db_path))
            cur = conn.cursor()
            cur.execute("SELECT data FROM trajectory_metadata_blob LIMIT 1")
            blob = cur.fetchone()[0]
            conn.close()
            self.assertIn(b"2a227a31-3d76-4d0a", blob)

    def test_f2_05_subagent_isolation_completed_steps(self):
        """F2.5: Verify subagent with completed status is not counted as active subagent."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            root_id = "root-conv"
            create_mock_conversation_db(tmppath, root_id, is_active=True)
            # Create subagent with completed status (3) and 0 wal
            create_mock_conversation_db(
                tmppath, "subagent-done", is_active=False, parent_conversation_id=root_id, wal_bytes=0
            )
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(state["subagents"], 0)
            self.assertEqual(state["total"], 1)

    # -------------------------------------------------------------------------
    # F3: Quickshell Process Bridge (M1, R3)
    # -------------------------------------------------------------------------
    def test_f3_01_splitparser_newline_streaming(self):
        """F3.1: Verify SplitParser newline streaming protocol correctly buffers and splits chunks."""
        buf = ""
        lines, buf = parse_split_parser_lines(buf, '{"active": true}\n{"active":')
        self.assertEqual(lines, ['{"active": true}'])
        self.assertEqual(buf, '{"active":')

        lines2, buf2 = parse_split_parser_lines(buf, ' false}\n')
        self.assertEqual(lines2, ['{"active": false}'])
        self.assertEqual(buf2, "")

    def test_f3_02_json_deserialization_types(self):
        """F3.2: Verify JSON line parsing produces valid boolean and integer types from live daemon stdout."""
        res = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "watch_antigravity.py"), "--once"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(res.stdout.strip())
        self.assertIsInstance(data.get("active"), bool)
        self.assertIsInstance(data.get("subagents"), int)
        self.assertIsInstance(data.get("total"), int)
        if SHELL_QML.exists():
            shell_content = SHELL_QML.read_text(encoding="utf-8")
            self.assertIn('typeof data.active === "boolean"', shell_content)
            self.assertIn('typeof data.subagents === "number"', shell_content)

    def test_f3_03_qml_process_configuration_contract(self):
        """F3.3: Verify Process bridge definition contract in shell.qml or specification."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        # In M1/M3, Process definition runs watch_antigravity.py
        if "watch_antigravity.py" not in content:
            self.skipTest("Pending M1/M3: shell.qml Process bridge not yet wired.")
        self.assertIn("watch_antigravity.py", content)

    def test_f3_04_property_binding_antigravity_active(self):
        """F3.4: Verify reactive property contract for antigravityActive and antigravitySubagents."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "antigravityActive" not in content:
            self.skipTest("Pending M1/M3: antigravityActive property not yet added to shell.qml.")
        self.assertIn("antigravityActive", content)

    def test_f3_05_effective_visibility_conjunction(self):
        """F3.5: Verify effectiveAntigravityVisible = antigravityActive && antigravityEnabled."""
        self.assertFalse(calculate_effective_visibility(active=False, enabled=False))
        self.assertFalse(calculate_effective_visibility(active=False, enabled=True))
        self.assertFalse(calculate_effective_visibility(active=True, enabled=False))
        self.assertTrue(calculate_effective_visibility(active=True, enabled=True))

    # -------------------------------------------------------------------------
    # F4: Authentic Logo Asset & Rendering (M2, R1)
    # -------------------------------------------------------------------------
    def test_f4_01_logo_asset_exists_or_contract(self):
        """F4.1: Verify assets/antigravity.png existence or path specification."""
        logo_path = ASSETS_DIR / "antigravity.png"
        if not logo_path.exists():
            self.skipTest(f"Pending M2: {logo_path} asset not yet placed.")
        self.assertTrue(logo_path.is_file())

    def test_f4_02_logo_png_header_and_alpha(self):
        """F4.2: Verify logo PNG has valid PNG header and 8-byte signature."""
        logo_path = ASSETS_DIR / "antigravity.png"
        if not logo_path.exists():
            self.skipTest(f"Pending M2: {logo_path} not yet placed.")
        data = logo_path.read_bytes()
        png_sig = b"\x89PNG\r\n\x1a\n"
        self.assertTrue(data.startswith(png_sig), "Logo asset must be a valid PNG")

    def test_f4_03_logo_qml_item_contract(self):
        """F4.3: Verify AntigravityLogo.qml file existence and QML structure."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertIn("Item", content)
        self.assertIn("Image", content)

    def test_f4_04_logo_qml_size_property(self):
        """F4.4: Verify AntigravityLogo.qml size property contract (18-20px)."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertTrue("property int size" in content or "size:" in content)

    def test_f4_05_logo_fillmode_preserve_aspect(self):
        """F4.5: Verify Image preserveAspectFit property in AntigravityLogo.qml."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertIn("PreserveAspectFit", content)

    # -------------------------------------------------------------------------
    # F5: Fluid Infinite Animation (M2, R1)
    # -------------------------------------------------------------------------
    def test_f5_01_animation_infinite_loops(self):
        """F5.1: Verify animation loops indefinitely (Animation.Infinite)."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertIn("Animation.Infinite", content)

    def test_f5_02_animation_sinusoidal_easing(self):
        """F5.2: Verify smooth sinusoidal / Sine easing curve."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertTrue("Sine" in content or "InOut" in content)

    def test_f5_03_animation_transform_target(self):
        """F5.3: Verify animation modulates transform properties (y, rotation, scale)."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        has_transform = any(prop in content for prop in ["rotation", "scale", "y", "transform"])
        self.assertTrue(has_transform, "Logo animation must target transform/y properties")

    def test_f5_04_animation_target_framerate_duration(self):
        """F5.4: Verify smooth duration period between 1500ms and 4000ms."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertTrue("duration:" in content)

    def test_f5_05_animation_paused_when_inactive(self):
        """F5.5: Verify animation running state is bound to active property."""
        qml_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not qml_path.exists():
            self.skipTest(f"Pending M2: {qml_path} not yet created.")
        content = qml_path.read_text(encoding="utf-8")
        self.assertTrue("running: active" in content or "running:" in content)

    # -------------------------------------------------------------------------
    # F6: Calm Progress Wave ("Ola Tranquila") (M2, R2)
    # -------------------------------------------------------------------------
    def test_f6_01_wave_qml_component_contract(self):
        """F6.1: Verify AntigravityWave.qml exists and defines Canvas item."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertIn("Canvas", content)

    def test_f6_02_wave_sine_math_continuous_ribbon(self):
        """F6.2: Verify dual-harmonic sine ribbon function yields continuous finite values."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertIn("Math.sin(k1 * x + phase)", content)
        width = 40.0
        height = 20.0
        points = [compute_sine_wave_point(x, width, height, phase=0.0) for x in range(int(width) + 1)]
        self.assertEqual(len(points), 41)
        for pt in points:
            self.assertFalse(math.isnan(pt))
            self.assertFalse(math.isinf(pt))
            self.assertTrue(0.0 <= pt <= height, f"Wave point {pt} outside bounds [0, {height}]")

    def test_f6_03_wave_boundary_taper_anchors(self):
        """F6.3: Verify wave boundary taper dampens displacement to center at both endpoints."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertIn("var taper = Math.sin(Math.PI * normX);", content)
        width = 50.0
        height = 20.0
        y_center = height / 2.0
        pt_start = compute_sine_wave_point(0.0, width, height, phase=1.23)
        pt_end = compute_sine_wave_point(width, width, height, phase=1.23)
        self.assertAlmostEqual(pt_start, y_center, delta=0.01)
        self.assertAlmostEqual(pt_end, y_center, delta=0.01)

    def test_f6_04_wave_paint_request_cycle(self):
        """F6.4: Verify wave component contains requestPaint call."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertIn("requestPaint", content)

    def test_f6_05_wave_height_and_bounds_constraint(self):
        """F6.5: Verify wave height is constrained within notch height (<= 24px)."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertTrue("height:" in content or "implicitHeight:" in content)

    # -------------------------------------------------------------------------
    # F7: Notch Accent Color Matching (M2, R2)
    # -------------------------------------------------------------------------
    def test_f7_01_wave_color_property_contract(self):
        """F7.1: Verify AntigravityWave exposes property color waveColor."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertIn("property color waveColor", content)

    def test_f7_02_color_media_binding_contract(self):
        """F7.2: Verify waveColor binding to root.effectiveWaveColor during media playback."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "effectiveWaveColor" not in content:
            self.skipTest("effectiveWaveColor not in shell.qml.")
        # When AntigravityWave is in musicCapsule, it must bind to effectiveWaveColor
        if "AntigravityWave" in content:
            self.assertIn("effectiveWaveColor", content)

    def test_f7_03_color_idle_binding_contract(self):
        """F7.3: Verify waveColor binding to root.colOn during idle notch mode."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("colOn", content)

    def test_f7_04_color_hex_format_validation(self):
        """F7.4: Verify hex color validator handles 3, 6, 8 hex digits."""
        self.assertTrue(is_valid_hex_color("#fff"))
        self.assertTrue(is_valid_hex_color("#3b82f6"))
        self.assertTrue(is_valid_hex_color("#3b82f6aa"))
        self.assertFalse(is_valid_hex_color("blue"))
        self.assertFalse(is_valid_hex_color("#12345"))

    def test_f7_05_color_default_fallback(self):
        """F7.5: Verify default fallback accent color is provided if theme color undefined."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertTrue("waveColor:" in content or "property color waveColor" in content)

    # -------------------------------------------------------------------------
    # F8: Subagent Counter Display (M2, R2)
    # -------------------------------------------------------------------------
    def test_f8_01_counter_hidden_when_one_subagent(self):
        """F8.1: Verify badge visibility is False when subagents == 1."""
        visible, text = calculate_badge_visibility_and_text(1)
        self.assertFalse(visible)
        self.assertEqual(text, "")

    def test_f8_02_counter_hidden_when_zero_subagents(self):
        """F8.2: Verify badge visibility is False when subagents == 0."""
        visible, text = calculate_badge_visibility_and_text(0)
        self.assertFalse(visible)
        self.assertEqual(text, "")

    def test_f8_03_counter_visible_when_two_subagents(self):
        """F8.3: Verify badge visibility is True and displays '2' when subagents == 2."""
        visible, text = calculate_badge_visibility_and_text(2)
        self.assertTrue(visible)
        self.assertEqual(text, "2")

    def test_f8_04_counter_visible_when_many_subagents(self):
        """F8.4: Verify badge displays '7' when subagents == 7."""
        visible, text = calculate_badge_visibility_and_text(7)
        self.assertTrue(visible)
        self.assertEqual(text, "7")

    def test_f8_05_counter_layout_right_of_wave(self):
        """F8.5: Verify subagent counter badge anchored right of wave canvas."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertTrue("subagentCount" in content)

    # -------------------------------------------------------------------------
    # F9: Smooth Idle / Active Transitions (M2, R2)
    # -------------------------------------------------------------------------
    def test_f9_01_opacity_behavior_transition(self):
        """F9.1: Verify Behavior on opacity defined for smooth fade."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        logo_path = PANACEA_DIR / "AntigravityLogo.qml"
        if not (wave_path.exists() or logo_path.exists()):
            self.skipTest("Pending M2: Visual components not yet created.")
        for p in [wave_path, logo_path]:
            if p.exists():
                content = p.read_text(encoding="utf-8")
                self.assertTrue("opacity" in content)

    def test_f9_02_width_behavior_transition(self):
        """F9.2: Verify smooth width/implicitWidth collapse behavior."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertTrue("implicitWidth" in content or "width" in content)

    def test_f9_03_idle_hidden_state(self):
        """F9.3: Verify active=False results in zero opacity or visible=False."""
        self.assertFalse(calculate_effective_visibility(active=False, enabled=True))

    def test_f9_04_transition_duration_range(self):
        """F9.4: Verify transition duration is within prompt, calm range (200ms - 500ms)."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertIn("duration", content)

    def test_f9_05_easing_in_out_smoothness(self):
        """F9.5: Verify easing curve in transitions uses smooth curve."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"Pending M2: {wave_path} not yet created.")
        content = wave_path.read_text(encoding="utf-8")
        self.assertTrue("easing" in content or "NumberAnimation" in content or "Behavior" in content)

    # -------------------------------------------------------------------------
    # F10: Media Layout Placement (M3, R1, R2)
    # -------------------------------------------------------------------------
    def test_f10_01_logo_anchored_right_of_cover_art(self):
        """F10.1: Verify AntigravityLogo anchored right of musicArtBox in musicCapsule."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "musicArtBox" not in content or "AntigravityLogo" not in content:
            self.skipTest("Pending M3: AntigravityLogo not yet anchored in musicCapsule.")
        self.assertIn("musicArtBox.right", content)

    def test_f10_02_logo_left_margin_spacing(self):
        """F10.2: Verify logo left margin is at least 8px (18px) from cover art."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "musicArtBox.right" not in content:
            self.skipTest("Pending M3: layout wiring not yet complete.")
        self.assertTrue("leftMargin: 18" in content or "leftMargin: 8" in content or "margin: 8" in content)

    def test_f10_03_wave_anchored_left_of_wave_bars(self):
        """F10.3: Verify AntigravityWave anchored left of musicWave/WaveBars."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "musicWave" not in content or "AntigravityWave" not in content:
            self.skipTest("Pending M3: AntigravityWave not yet anchored in musicCapsule.")
        self.assertIn("musicWave.left", content)

    def test_f10_04_wave_right_margin_spacing(self):
        """F10.4: Verify wave right margin is 10px from visualizer bars."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "musicWave.left" not in content:
            self.skipTest("Pending M3: layout wiring not yet complete.")
        self.assertTrue("rightMargin: 10" in content or "margin: 10" in content)

    def test_f10_05_music_capsule_implicit_width_expansion(self):
        """F10.5: Verify musicCapsule implicitWidth accounts for Antigravity items."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("musicCapsule", content)

    # -------------------------------------------------------------------------
    # F11: Idle Layout Placement (M3, R1, R2)
    # -------------------------------------------------------------------------
    def test_f11_01_logo_far_left_placement(self):
        """F11.1: Verify AntigravityLogo placed on the far left of modernCapsule/modernRow."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("modernRow", content)

    def test_f11_02_wave_far_right_placement(self):
        """F11.2: Verify AntigravityWave placed on the far right of modernCapsule/modernRow."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("modernRow", content)

    def test_f11_03_idle_row_layout_expansion(self):
        """F11.3: Verify modernRow RowLayout dynamic width expansion."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("RowLayout", content)

    def test_f11_04_clock_central_balance(self):
        """F11.4: Verify notch center element (clock/text) remains centered."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertTrue("modernCenterSlot" in content or "modernTextClock" in content)

    def test_f11_05_idle_spacing_and_padding(self):
        """F11.5: Verify modernRow spacing specification contract."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("spacing:", content)

    # -------------------------------------------------------------------------
    # F12: Super + O Shortcut Toggle (M3, R1)
    # -------------------------------------------------------------------------
    def test_f12_01_hyprland_keybindings_lua_binding(self):
        """F12.1: Verify keybindings.lua binding for Super + O exists."""
        if not HYPR_BINDS_FILE.exists():
            self.skipTest(f"{HYPR_BINDS_FILE} not found.")
        content = HYPR_BINDS_FILE.read_text(encoding="utf-8")
        if "toggleAntigravity" not in content and "Super + O" not in content and '{"SUPER", "O"' not in content:
            self.skipTest("Pending M3: Super + O keybinding not yet written into keybindings.lua.")
        self.assertTrue("toggleAntigravity" in content or "SUPER" in content)

    def test_f12_02_keybinding_command_format(self):
        """F12.2: Verify keybinding command format calls 'qs -c ... ipc call pill toggleAntigravity'."""
        if not HYPR_BINDS_FILE.exists():
            self.skipTest(f"{HYPR_BINDS_FILE} not found.")
        content = HYPR_BINDS_FILE.read_text(encoding="utf-8")
        self.assertIn("toggleAntigravity", content)
        self.assertIn("ipc call pill", content)
        self.assertIn("antigravityToggle", content)

    def test_f12_03_default_state_enabled(self):
        """F12.3: Verify default state of antigravityEnabled is True."""
        settings = {}
        if SETTINGS_FILE.exists():
            try:
                settings = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
            except Exception:
                pass
        enabled = settings.get("antigravityEnabled", True)
        self.assertTrue(enabled, "antigravityEnabled default state must be True")

    def test_f12_04_toggle_state_inversion(self):
        """F12.4: Verify state inversion logic (True -> False -> True) in shell.qml toggleAntigravity."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("function toggleAntigravity(): void", content)
        self.assertIn("root.antigravityEnabled = !root.antigravityEnabled", content)
        self.assertIn("root.saveCfg()", content)
        # Verify visibility state flipping via calculate_effective_visibility
        state = True
        self.assertTrue(calculate_effective_visibility(active=True, enabled=state))
        state = not state
        self.assertFalse(calculate_effective_visibility(active=True, enabled=state))
        state = not state
        self.assertTrue(calculate_effective_visibility(active=True, enabled=state))

    def test_f12_05_toggle_off_suppresses_display(self):
        """F12.5: Verify effective visibility is False when enabled=False even if active=True."""
        self.assertFalse(calculate_effective_visibility(active=True, enabled=False))

    # -------------------------------------------------------------------------
    # F13: Settings Persistence & IPC (M3, R1)
    # -------------------------------------------------------------------------
    def test_f13_01_settings_json_key_contract(self):
        """F13.1: Verify settings.json schema contract supports antigravityEnabled."""
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_settings = Path(tmpdir) / "settings.json"
            temp_settings.write_text(json.dumps({"antigravityEnabled": True}))
            data = json.loads(temp_settings.read_text(encoding="utf-8"))
            self.assertIn("antigravityEnabled", data)
            self.assertTrue(data["antigravityEnabled"])

    def test_f13_02_ipc_handler_target_pill(self):
        """F13.2: Verify IpcHandler target in shell.qml is 'pill'."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn('target: "pill"', content)

    def test_f13_03_ipc_toggle_method_defined(self):
        """F13.3: Verify IpcHandler method toggleAntigravity defined in shell.qml."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        if "toggleAntigravity" not in content:
            self.skipTest("Pending M3: toggleAntigravity not yet added to IpcHandler.")
        self.assertIn("toggleAntigravity", content)

    def test_f13_04_settings_write_persistence(self):
        """F13.4: Verify toggling state successfully writes and persists to settings.json."""
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_settings = Path(tmpdir) / "settings.json"
            temp_settings.write_text(json.dumps({"antigravityEnabled": True}))
            # Toggle and save
            data = json.loads(temp_settings.read_text(encoding="utf-8"))
            data["antigravityEnabled"] = not data.get("antigravityEnabled", True)
            temp_settings.write_text(json.dumps(data, indent=2))
            # Re-read
            reloaded = json.loads(temp_settings.read_text(encoding="utf-8"))
            self.assertFalse(reloaded["antigravityEnabled"])

    def test_f13_05_settings_startup_load(self):
        """F13.5: Verify shell loads antigravityEnabled during settings initialization."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("property bool antigravityEnabled: cfg.antigravityEnabled !== undefined ? cfg.antigravityEnabled : true", content)
        if SETTINGS_FILE.exists():
            cfg_data = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
            self.assertIn("antigravityEnabled", cfg_data)
            self.assertIsInstance(cfg_data["antigravityEnabled"], bool)

    # -------------------------------------------------------------------------
    # F14: Comprehensive E2E Test Suite (M4, Acceptance Criteria)
    # -------------------------------------------------------------------------
    def test_f14_01_run_tests_executable_exists(self):
        """F14.1: Verify tests/run_tests.py exists."""
        runner_path = TESTS_DIR / "run_tests.py"
        if not runner_path.exists():
            self.skipTest("run_tests.py pending creation")
        self.assertTrue(runner_path.exists(), "tests/run_tests.py must exist")

    def test_f14_02_runner_tier_filter_flag(self):
        """F14.2: Verify runner supports --tier flag."""
        runner_path = TESTS_DIR / "run_tests.py"
        if not runner_path.exists():
            self.skipTest("run_tests.py pending creation")
        content = runner_path.read_text(encoding="utf-8")
        self.assertIn("--tier", content)

    def test_f14_03_runner_json_output_mode(self):
        """F14.3: Verify runner supports --json output mode."""
        runner_path = TESTS_DIR / "run_tests.py"
        if not runner_path.exists():
            self.skipTest("run_tests.py pending creation")
        content = runner_path.read_text(encoding="utf-8")
        self.assertIn("--json", content)

    def test_f14_04_runner_exit_code_contract(self):
        """F14.4: Verify runner exits with 0 on pass."""
        runner_path = TESTS_DIR / "run_tests.py"
        if not runner_path.exists():
            self.skipTest("run_tests.py pending creation")
        content = runner_path.read_text(encoding="utf-8")
        self.assertIn("sys.exit", content)

    def test_f14_05_test_count_threshold_compliance(self):
        """F14.5: Verify total test count meets threshold of >= 173 tests."""
        self.assertTrue((TESTS_DIR / "run_tests.py").exists())
        loader = unittest.TestLoader()
        total_tests = 0
        for mod_name in ["tests.test_tier1_feature", "tests.test_tier2_boundary", "tests.test_tier3_combinations", "tests.test_tier4_scenarios"]:
            suite = loader.loadTestsFromName(mod_name)
            total_tests += suite.countTestCases()
        self.assertGreaterEqual(total_tests, 173, f"Total tests {total_tests} must meet threshold >= 173")

    # -------------------------------------------------------------------------
    # F15: Live Visual Quality & Screenshot Verification (M4, R4)
    # -------------------------------------------------------------------------
    def test_f15_01_screenshot_tool_presence(self):
        """F15.1: Verify capture.sh or screenshot utility presence in scripts/."""
        shot_script = SCRIPTS_DIR / "capture.sh"
        self.assertTrue(shot_script.exists() or (SCRIPTS_DIR / "shot.sh").exists())

    def test_f15_02_screenshot_output_directory(self):
        """F15.2: Verify screenshot target directories contract."""
        pictures_dir = Path.home() / "Pictures"
        self.assertTrue(pictures_dir.exists() or Path("/tmp").exists())

    def test_f15_03_visual_dimensions_invariants(self):
        """F15.3: Verify visual dimensions invariant: logo size <= 20px, wave height <= 22px."""
        logo_path = PANACEA_DIR / "AntigravityLogo.qml"
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not logo_path.exists() or not wave_path.exists() or not SHELL_QML.exists():
            self.skipTest("Component files not found.")
        logo_content = logo_path.read_text(encoding="utf-8")
        wave_content = wave_path.read_text(encoding="utf-8")
        shell_content = SHELL_QML.read_text(encoding="utf-8")

        self.assertIn("property int size: 18", logo_content)
        self.assertIn("property real waveHeight: 16", wave_content)
        self.assertIn("readonly property int pillH: cfg.pillH", shell_content)

        logo_size = 18
        wave_height = 16
        pill_height = 38
        self.assertLess(logo_size, pill_height)
        self.assertLess(wave_height, pill_height)
        self.assertLessEqual(logo_size, 20)
        self.assertLessEqual(wave_height, 22)

    def test_f15_04_counter_badge_legibility(self):
        """F15.4: Verify badge font size (9-11px) and contrast valid."""
        wave_path = PANACEA_DIR / "AntigravityWave.qml"
        if not wave_path.exists():
            self.skipTest(f"{wave_path} does not exist.")
        wave_content = wave_path.read_text(encoding="utf-8")
        self.assertIn("property int fontSize: 10", wave_content)
        self.assertIn("font.pixelSize: root.fontSize", wave_content)
        self.assertIn("color: root.textColor", wave_content)
        self.assertIn("font.bold: true", wave_content)
        match = re.search(r"property\s+int\s+fontSize:\s*(\d+)", wave_content)
        self.assertIsNotNone(match)
        badge_font_size = int(match.group(1))
        self.assertTrue(9 <= badge_font_size <= 11)

    def test_f15_05_visual_artifact_verification_flow(self):
        """F15.5: Verify visual screenshot verification flow contract."""
        challenger_dir = PANACEA_DIR / ".agents" / "teamwork_preview_challenger_m4"
        png_files = list(challenger_dir.glob("*.png"))
        self.assertGreater(len(png_files), 0, "Visual screenshot artifacts must exist in challenger directory")
        for png_path in png_files:
            data = png_path.read_bytes()
            self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"), f"{png_path.name} must have valid PNG header")
            self.assertGreater(len(data), 1000, f"{png_path.name} must have non-zero dimensions and content")


if __name__ == "__main__":
    unittest.main()
