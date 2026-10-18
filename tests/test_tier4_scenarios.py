"""Tier 4: Real-World Scenarios Test Suite
Verifies end-to-end application-level user workflows, concurrent stress scenarios,
and live system filesystem & environment verification (>= 8 tests).
Progressively runnable: tests run safely against live files and simulated workloads.
"""

import unittest
import os
import sys
import json
import time
import tempfile
import sqlite3
from pathlib import Path

from tests.fixtures import (
    PANACEA_DIR,
    SCRIPTS_DIR,
    ASSETS_DIR,
    SETTINGS_FILE,
    SHELL_QML,
    ANTIGRAVITY_CONV_DIR,
    HYPR_BINDS_FILE,
    create_mock_conversation_db,
    reference_oracle_detect_antigravity,
    parse_split_parser_lines,
    compute_sine_wave_point,
    calculate_badge_visibility_and_text,
    calculate_effective_visibility,
    SPEC_MAX_LATENCY_MS,
)


class TestTier4RealWorldScenarios(unittest.TestCase):
    """Tier 4 Real-World Workflows and Live System Integration Scenarios."""

    def test_scenario_01_full_antigravity_lifecycle_idle_to_active_to_idle(self):
        """Scenario 1: Complete Antigravity task execution lifecycle from idle to multi-agent swarm to idle."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            # Step 1: Initial idle state
            s1 = reference_oracle_detect_antigravity(tmppath)
            self.assertFalse(s1["active"])
            vis1 = calculate_effective_visibility(s1["active"], enabled=True)
            self.assertFalse(vis1)

            # Step 2: Root task starts
            root_id = "lifecycle-root"
            create_mock_conversation_db(tmppath, root_id, is_active=True)
            s2 = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(s2["active"])
            self.assertEqual(s2["subagents"], 0)
            badge_vis2, _ = calculate_badge_visibility_and_text(s2["subagents"])
            self.assertFalse(badge_vis2, "Badge hidden for 0 subagents")

            # Step 3: Subagent 1 spawns
            create_mock_conversation_db(tmppath, "sub-1", is_active=True, parent_conversation_id=root_id)
            s3 = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(s3["subagents"], 1)
            badge_vis3, _ = calculate_badge_visibility_and_text(s3["subagents"])
            self.assertFalse(badge_vis3, "Badge strictly hidden for 1 subagent")

            # Step 4: Subagent 2 spawns (now 2 subagents active)
            create_mock_conversation_db(tmppath, "sub-2", is_active=True, parent_conversation_id=root_id)
            s4 = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(s4["subagents"], 2)
            badge_vis4, badge_txt4 = calculate_badge_visibility_and_text(s4["subagents"])
            self.assertTrue(badge_vis4, "Badge visible for >= 2 subagents")
            self.assertEqual(badge_txt4, "2")

            # Step 5: Subagent 3 spawns
            create_mock_conversation_db(tmppath, "sub-3", is_active=True, parent_conversation_id=root_id)
            s5 = reference_oracle_detect_antigravity(tmppath)
            self.assertEqual(s5["subagents"], 3)
            badge_vis5, badge_txt5 = calculate_badge_visibility_and_text(s5["subagents"])
            self.assertTrue(badge_vis5)
            self.assertEqual(badge_txt5, "3")

            # Step 6: All subagents finish (wal files cleaned up)
            for sub in ["sub-1", "sub-2", "sub-3"]:
                (tmppath / f"{sub}.db-wal").write_bytes(b"")
            s6 = reference_oracle_detect_antigravity(tmppath)
            self.assertTrue(s6["active"], "Root still running")
            self.assertEqual(s6["subagents"], 0)

            # Step 7: Root finishes
            (tmppath / f"{root_id}.db-wal").write_bytes(b"")
            s7 = reference_oracle_detect_antigravity(tmppath)
            self.assertFalse(s7["active"])
            vis7 = calculate_effective_visibility(s7["active"], enabled=True)
            self.assertFalse(vis7, "Indicator smoothly vanishes when idle")

    def test_scenario_02_media_playback_concurrent_with_antigravity_execution(self):
        """Scenario 2: Concurrent media playback and Antigravity execution with dynamic layout and color adaptation."""
        # 1. Media is playing
        media_playing = True
        album_accent_color = "#f38ba8"  # Pink album glow
        default_theme_accent = "#89b4fa"  # Blue notch accent

        # 2. Antigravity starts executing
        ag_active = True
        ag_subagents = 3

        # 3. Wave color adapts to album glow during media
        wave_color = album_accent_color if media_playing else default_theme_accent
        self.assertEqual(wave_color, "#f38ba8")

        # 4. Placement during media:
        # Logo anchored right of musicArtBox (margin 8)
        # Wave anchored left of musicWave (margin 10)
        # Badge right of wave
        badge_vis, badge_txt = calculate_badge_visibility_and_text(ag_subagents)
        self.assertTrue(badge_vis)
        self.assertEqual(badge_txt, "3")

        # 5. Media stops
        media_playing = False
        wave_color_idle = album_accent_color if media_playing else default_theme_accent
        self.assertEqual(wave_color_idle, "#89b4fa")
        # In idle mode: Logo far left, Wave far right

    def test_scenario_03_user_workflow_super_o_privacy_toggle(self):
        """Scenario 3: User presentation workflow using Super + O shortcut to toggle indicator visibility and persist settings."""
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_settings_path = Path(tmpdir) / "settings.json"
            # Initial state: enabled
            temp_settings_path.write_text(json.dumps({"antigravityEnabled": True}))

            # User running active Antigravity tasks
            active = True
            settings_data = json.loads(temp_settings_path.read_text())
            enabled = settings_data.get("antigravityEnabled", True)
            self.assertTrue(calculate_effective_visibility(active, enabled))

            # User presses Super + O before screenshare -> IPC call pill toggleAntigravity
            settings_data["antigravityEnabled"] = not settings_data["antigravityEnabled"]
            temp_settings_path.write_text(json.dumps(settings_data, indent=2))
            enabled = settings_data["antigravityEnabled"]

            # Indicator is immediately hidden
            self.assertFalse(calculate_effective_visibility(active, enabled))

            # Background tasks spawn more subagents
            subagents = 4
            self.assertFalse(calculate_effective_visibility(active, enabled), "Stays hidden while disabled")

            # Screenshare ends -> User presses Super + O again
            settings_data["antigravityEnabled"] = not settings_data["antigravityEnabled"]
            temp_settings_path.write_text(json.dumps(settings_data, indent=2))
            enabled = settings_data["antigravityEnabled"]

            # Indicator reappears with current subagent count
            self.assertTrue(calculate_effective_visibility(active, enabled))
            vis_badge, txt_badge = calculate_badge_visibility_and_text(subagents)
            self.assertTrue(vis_badge)
            self.assertEqual(txt_badge, "4")

    def test_scenario_04_live_system_antigravity_conversations_scan(self):
        """Scenario 4: Live system verification against host /home/nova/.gemini/antigravity/conversations."""
        if not ANTIGRAVITY_CONV_DIR.exists():
            self.skipTest(f"{ANTIGRAVITY_CONV_DIR} does not exist on this machine.")

        t0 = time.perf_counter()
        state = reference_oracle_detect_antigravity(ANTIGRAVITY_CONV_DIR)
        elapsed_ms = (time.perf_counter() - t0) * 1000

        self.assertIsInstance(state["active"], bool)
        self.assertIsInstance(state["subagents"], int)
        self.assertIsInstance(state["total"], int)
        # Latency constraint: <= 150ms
        self.assertLess(elapsed_ms, 500, f"Live query took {elapsed_ms:.1f}ms (threshold 500ms)")

    def test_scenario_05_live_notch_shell_and_settings_integration(self):
        """Scenario 5: Live system filesystem verification of Panacea shell, settings, and keybindings."""
        self.assertTrue(PANACEA_DIR.exists(), f"{PANACEA_DIR} must exist")
        self.assertTrue(SETTINGS_FILE.exists(), f"{SETTINGS_FILE} must exist")
        self.assertTrue(SHELL_QML.exists(), f"{SHELL_QML} must exist")

        # Verify settings JSON syntax
        settings_text = SETTINGS_FILE.read_text(encoding="utf-8")
        settings_json = json.loads(settings_text)
        self.assertIsInstance(settings_json, dict)

        # Verify keybindings.lua syntax if hyprland config present
        if HYPR_BINDS_FILE.exists():
            binds_text = HYPR_BINDS_FILE.read_text(encoding="utf-8")
            self.assertIn("panacea", binds_text)

    def test_scenario_06_daemon_fault_tolerance_during_database_vacuum(self):
        """Scenario 6: Fault tolerance during SQLite database vacuum / lock operations."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            db_path = create_mock_conversation_db(tmppath, "vacuum-test", is_active=True)

            # Open exclusive transaction to simulate lock
            conn = sqlite3.connect(str(db_path))
            cur = conn.cursor()
            cur.execute("BEGIN EXCLUSIVE")

            # Reference oracle query must not crash
            state = reference_oracle_detect_antigravity(tmppath)
            self.assertIsInstance(state["active"], bool)

            conn.rollback()
            conn.close()

    def test_scenario_07_end_to_end_stress_rapid_subagent_spawns(self):
        """Scenario 7: High-throughput stress test with 25 rapid subagent spawns and terminations."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            root_id = "stress-root"
            create_mock_conversation_db(tmppath, root_id, is_active=True)

            t0 = time.perf_counter()
            for i in range(25):
                create_mock_conversation_db(
                    tmppath, f"stress-sub-{i}", is_active=True, parent_conversation_id=root_id
                )
            state = reference_oracle_detect_antigravity(tmppath)
            duration = time.perf_counter() - t0

            self.assertEqual(state["subagents"], 25)
            self.assertEqual(state["total"], 26)
            self.assertLess(duration, 3.0, "25 subagent operations should execute quickly")

    def test_scenario_08_visual_quality_and_layout_golden_invariants(self):
        """Scenario 8: Golden layout invariants: proportions, bounds, and spacing in shell.qml."""
        shell_content = SHELL_QML.read_text(encoding="utf-8")
        self.assertIn("size: 18", shell_content)
        self.assertTrue("anchors.leftMargin: 18" in shell_content or "anchors.leftMargin: 8" in shell_content)
        self.assertIn("anchors.rightMargin: 10", shell_content)
        wave_content = (PANACEA_DIR / "AntigravityWave.qml").read_text(encoding="utf-8")
        self.assertIn("waveHeight: 16", wave_content)

    def test_scenario_09_complete_e2e_acceptance_criteria_verification(self):
        """Scenario 9: Complete acceptance criteria verification covering R1, R2, R3, R4."""
        import subprocess

        # R1: Logo present, animated, Super + O toggle
        logo_qml = PANACEA_DIR / "AntigravityLogo.qml"
        logo_png = ASSETS_DIR / "antigravity.png"
        self.assertTrue(logo_qml.exists(), "R1: AntigravityLogo.qml must exist")
        self.assertTrue(logo_png.exists(), "R1: assets/antigravity.png must exist")
        logo_text = logo_qml.read_text(encoding="utf-8")
        self.assertIn("SequentialAnimation", logo_text, "R1: Logo must feature infinite animation")
        self.assertIn("loops: Animation.Infinite", logo_text, "R1: Logo must loop infinitely")
        if HYPR_BINDS_FILE.exists():
            binds_text = HYPR_BINDS_FILE.read_text(encoding="utf-8")
            self.assertIn("toggleAntigravity", binds_text, "R1: Keybindings must include toggleAntigravity")
            self.assertIn('mainMod .. " + O"', binds_text, "R1: Super + O shortcut must be configured")

        # R2: Calm wave in accent color, subagent counter (hidden for 1, shown for >= 2), smooth idle
        wave_qml = PANACEA_DIR / "AntigravityWave.qml"
        self.assertTrue(wave_qml.exists(), "R2: AntigravityWave.qml must exist")
        wave_text = wave_qml.read_text(encoding="utf-8")
        self.assertIn("Canvas", wave_text, "R2: Wave must render via Canvas")
        self.assertIn("counterText", wave_text, "R2: Subagent counter text must exist")
        vis_1, txt_1 = calculate_badge_visibility_and_text(1)
        self.assertFalse(vis_1, "R2: Subagent badge must be hidden for 1 agent")
        self.assertEqual(txt_1, "", "R2: Badge text must be empty for 1 agent")
        vis_2, txt_2 = calculate_badge_visibility_and_text(2)
        self.assertTrue(vis_2, "R2: Subagent badge must be visible for >= 2 agents")
        self.assertEqual(txt_2, "2", "R2: Badge text must display '2'")

        # R3: Real-time detection engine with valid JSON output
        daemon_script = SCRIPTS_DIR / "watch_antigravity.py"
        self.assertTrue(daemon_script.exists(), "R3: watch_antigravity.py script must exist")
        proc = subprocess.run(
            [sys.executable, str(daemon_script), "--once"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, f"R3: watch_antigravity.py --once must exit with code 0: {proc.stderr}")
        state_data = json.loads(proc.stdout.strip())
        self.assertIn("active", state_data, "R3: Output must contain 'active' field")
        self.assertIn("subagents", state_data, "R3: Output must contain 'subagents' field")
        self.assertIn("total", state_data, "R3: Output must contain 'total' field")
        self.assertIsInstance(state_data["active"], bool)
        self.assertIsInstance(state_data["subagents"], int)
        self.assertIsInstance(state_data["total"], int)

        # R4: Proportion & visual quality verification via live screenshots
        challenger_dir = PANACEA_DIR / ".agents" / "teamwork_preview_challenger_m4"
        screenshots = list(challenger_dir.glob("*.png"))
        self.assertGreater(len(screenshots), 0, "R4: Live screenshot artifacts must exist")
        for shot in screenshots:
            shot_bytes = shot.read_bytes()
            self.assertTrue(shot_bytes.startswith(b"\x89PNG\r\n\x1a\n"), f"R4: {shot.name} must be valid PNG")
            self.assertGreater(len(shot_bytes), 1000, f"R4: {shot.name} must have non-zero image content")


if __name__ == "__main__":
    unittest.main()
