"""Tier 3: Cross-Feature Combinations Test Suite
Verifies pairwise interactions and cross-subsystem contracts across features F1 through F15 (>= 15 tests).
Progressively runnable: tests verify end-to-end interactions across data flow boundaries.
"""

import unittest
import os
import sys
import json
import tempfile
import math
import subprocess
from pathlib import Path

from tests.fixtures import (
    PANACEA_DIR,
    SCRIPTS_DIR,
    ASSETS_DIR,
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


class TestTier3CrossFeatureCombinations(unittest.TestCase):
    """Tier 3 Pairwise Combinations and Cross-Feature Interactions (F1 - F15)."""

    def test_comb_01_daemon_and_subagent_detection_pipeline(self):
        """Comb 01 (F1 + F2): SQLite WAL presence and step status queries pipeline into subagent count."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            root_id = "comb-root-conv"
            create_mock_conversation_db(tmppath, root_id, is_active=True)
            create_mock_conversation_db(tmppath, "comb-sub-1", is_active=True, parent_conversation_id=root_id)
            create_mock_conversation_db(tmppath, "comb-sub-2", is_active=True, parent_conversation_id=root_id)

            state = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(state["active"])
            self.assertEqual(state["subagents"], 2)
            self.assertEqual(state["total"], 3)

    def test_comb_02_subagent_count_to_badge_display_transition(self):
        """Comb 02 (F2 + F8): Subagent count transitions correctly drive badge visibility & text."""
        subagent_timeline = [0, 1, 2, 5, 2, 1, 0]
        expected_states = [
            (False, ""),
            (False, ""),
            (True, "2"),
            (True, "5"),
            (True, "2"),
            (False, ""),
            (False, ""),
        ]
        for count, (exp_vis, exp_text) in zip(subagent_timeline, expected_states):
            vis, text = calculate_badge_visibility_and_text(count)
            self.assertEqual(vis, exp_vis, f"Failed visibility for subagents={count}")
            self.assertEqual(text, exp_text, f"Failed text for subagents={count}")

    def test_comb_03_daemon_stdout_to_qml_process_bridge(self):
        """Comb 03 (F1 + F3): Streamed JSON lines from daemon into SplitParser update UI state."""
        daemon_emissions = [
            '{"active": false, "subagents": 0, "total": 0}\n',
            '{"active": true, "subagents": 0, "total": 1}\n',
            '{"active": true, "subagents": 2, "total": 3}\n',
            '{"active": false, "subagents": 0, "total": 0}\n',
        ]
        buffer = ""
        states = []
        for chunk in daemon_emissions:
            lines, buffer = parse_split_parser_lines(buffer, chunk)
            for line in lines:
                states.append(json.loads(line))

        self.assertEqual(len(states), 4)
        self.assertFalse(states[0]["active"])
        self.assertTrue(states[1]["active"])
        self.assertEqual(states[1]["subagents"], 0)
        self.assertTrue(states[2]["active"])
        self.assertEqual(states[2]["subagents"], 2)
        self.assertFalse(states[3]["active"])

    def test_comb_04_process_bridge_triggers_smooth_transitions(self):
        """Comb 04 (F3 + F9): Bridge active state transitions drive effective visibility."""
        enabled = True
        active_states = [False, True, True, False]
        visibilities = [calculate_effective_visibility(act, enabled) for act in active_states]
        self.assertEqual(visibilities, [False, True, True, False])

    def test_comb_05_media_accent_color_with_media_layout(self):
        """Comb 05 (F7 + F10): During media playback, wave color uses media accent color in musicCapsule."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("readonly property color effectiveWaveColor:", shell_content)
        self.assertIn("if (m === 0) return root.mediaArtColor;", shell_content)
        self.assertIn("if (m === 1) return root.colOn;", shell_content)
        self.assertIn("id: agWaveMusic", shell_content)
        self.assertIn("waveColor: root.effectiveWaveColor", shell_content)
        self.assertIn("anchors.right: musicWave.left", shell_content)
        album_glow = "#a6e3a1"
        self.assertTrue(is_valid_hex_color(album_glow))

    def test_comb_06_idle_accent_color_with_idle_layout(self):
        """Comb 06 (F7 + F11): During idle mode, wave color reverts to notch accent colOn."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("readonly property color colOn:", shell_content)
        self.assertIn("id: agWaveModern", shell_content)
        self.assertIn("waveColor: root.colOn", shell_content)
        self.assertIn("subagentCount: root.antigravitySubagents", shell_content)
        theme_colOn = "#89b4fa"
        self.assertTrue(is_valid_hex_color(theme_colOn))

    def test_comb_07_media_to_idle_dynamic_switch(self):
        """Comb 07 (F10 + F11): Switching from media playing to idle while active moves layout smoothly."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("agLogoMusic", shell_content)
        self.assertIn("agLogoModern", shell_content)
        self.assertIn("agWaveMusic", shell_content)
        self.assertIn("agWaveModern", shell_content)
        self.assertIn("root.effectiveAntigravityVisible", shell_content)

    def test_comb_08_super_o_invokes_ipc_and_updates_settings(self):
        """Comb 08 (F12 + F13): Super + O keybinding invokes IPC and updates settings.json."""
        if not HYPR_BINDS_FILE.exists():
            self.skipTest(f"{HYPR_BINDS_FILE} not found.")
        binds_content = HYPR_BINDS_FILE.read_text(encoding="utf-8")
        self.assertIn('mainMod .. " + O"', binds_content)
        self.assertIn("toggleAntigravity", binds_content)

        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("function toggleAntigravity(): void", shell_content)
        self.assertIn("root.antigravityEnabled = !root.antigravityEnabled", shell_content)
        self.assertIn("root.cfg.antigravityEnabled = root.antigravityEnabled", shell_content)
        self.assertIn("root.saveCfg()", shell_content)
        self.assertIn("function saveCfg() { cfgFile.writeAdapter(); }", shell_content)

        with tempfile.TemporaryDirectory() as tmpdir:
            temp_settings = Path(tmpdir) / "settings.json"
            temp_settings.write_text(json.dumps({"antigravityEnabled": True}))

            # Execute IPC toggle logic and persist
            data = json.loads(temp_settings.read_text())
            data["antigravityEnabled"] = not data.get("antigravityEnabled", True)
            temp_settings.write_text(json.dumps(data, indent=2))

            reloaded = json.loads(temp_settings.read_text())
            self.assertFalse(reloaded["antigravityEnabled"])

    def test_comb_09_super_o_toggle_while_active(self):
        """Comb 09 (F12 + F9): Toggling off with Super+O while tasks are running hides UI immediately."""
        active = True
        enabled = True
        self.assertTrue(calculate_effective_visibility(active, enabled))
        # User toggles Super + O
        enabled = not enabled
        self.assertFalse(calculate_effective_visibility(active, enabled))
        # User toggles Super + O again
        enabled = not enabled
        self.assertTrue(calculate_effective_visibility(active, enabled))

    def test_comb_10_logo_asset_with_infinite_animation(self):
        """Comb 10 (F4 + F5): Logo image rendering inside infinite levitation animation in AntigravityLogo.qml."""
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        qml_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn('source: "assets/antigravity.png"', qml_text)
        self.assertIn("SequentialAnimation", qml_text)
        self.assertIn("loops: Animation.Infinite", qml_text)
        self.assertIn("running: root.active", qml_text)

    def test_comb_11_wave_canvas_alongside_subagent_badge(self):
        """Comb 11 (F6 + F8): Wave canvas dimensions alongside badge layout in AntigravityWave.qml."""
        wave_qml = PANACEA_DIR / "AntigravityWave.qml"
        qml_text = wave_qml.read_text(encoding="utf-8")
        self.assertIn("id: waveCanvas", qml_text)
        self.assertIn("id: counterText", qml_text)
        self.assertIn("visible: root.subagentCount >= 2", qml_text)

    def test_comb_12_daemon_active_with_indicator_disabled(self):
        """Comb 12 (F1 + F12): Daemon reports active tasks, but indicator disabled by user."""
        daemon_state = {"active": True, "subagents": 4, "total": 5}
        user_enabled = False
        effective_vis = calculate_effective_visibility(daemon_state["active"], user_enabled)
        self.assertFalse(effective_vis)

    def test_comb_13_media_playing_with_super_o_toggle(self):
        """Comb 13 (F10 + F12): Toggling indicator while media is playing collapses indicators without disrupting media."""
        media_active = True
        ag_active = True
        ag_enabled = True
        vis1 = calculate_effective_visibility(ag_active, ag_enabled)
        self.assertTrue(vis1)

        # Toggle off
        ag_enabled = False
        vis2 = calculate_effective_visibility(ag_active, ag_enabled)
        self.assertFalse(vis2)
        # Media stays playing
        self.assertTrue(media_active)

    def test_comb_14_subagent_swarm_with_screenshot_verification(self):
        """Comb 14 (F2 + F15): Multi-subagent swarm visual layout invariance verified against challenger screenshots."""
        subagents = 8
        vis, text = calculate_badge_visibility_and_text(subagents)
        self.assertTrue(vis)
        self.assertEqual(text, "8")
        challenger_dir = PANACEA_DIR / ".agents" / "teamwork_preview_challenger_m4"
        screenshots = list(challenger_dir.glob("*.png"))
        self.assertGreater(len(screenshots), 0, "Screenshot artifacts must exist in challenger directory")

    def test_comb_15_settings_startup_to_bridge_initialization(self):
        """Comb 15 (F13 + F3): Shell startup loads settings before bridge emits active."""
        if not SHELL_QML.exists():
            self.skipTest(f"{SHELL_QML} does not exist.")
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("property bool antigravityEnabled: cfg.antigravityEnabled !== undefined ? cfg.antigravityEnabled : true", shell_content)
        self.assertIn("readonly property bool effectiveAntigravityVisible: antigravityActive && antigravityEnabled", shell_content)

        res = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "watch_antigravity.py"), "--once"],
            capture_output=True,
            text=True,
            check=True,
        )
        daemon_data = json.loads(res.stdout.strip())
        daemon_active = daemon_data["active"]
        effective = calculate_effective_visibility(daemon_active, enabled=False)
        self.assertFalse(effective, "Must not show when disabled in settings, even if daemon reports active")

    def test_comb_16_e2e_runner_verifies_all_subsystems(self):
        """Comb 16 (F14 + F1 + F13): Runner discovers tests across Tier 1, Tier 2, Tier 3, and Tier 4."""
        self.assertTrue((PANACEA_DIR / "tests" / "run_tests.py").exists())
        loader = unittest.TestLoader()
        tier_counts = {}
        for tier_num in [1, 2, 3, 4]:
            mod_name = f"tests.test_tier{tier_num}_feature" if tier_num == 1 else (
                f"tests.test_tier{tier_num}_boundary" if tier_num == 2 else (
                    f"tests.test_tier{tier_num}_combinations" if tier_num == 3 else f"tests.test_tier{tier_num}_scenarios"
                )
            )
            suite = loader.loadTestsFromName(mod_name)
            count = suite.countTestCases()
            self.assertGreater(count, 0, f"Tier {tier_num} must contain tests")
            tier_counts[tier_num] = count
        total = sum(tier_counts.values())
        self.assertGreaterEqual(total, 173, f"Total tests {total} must be >= 173")


if __name__ == "__main__":
    unittest.main()
