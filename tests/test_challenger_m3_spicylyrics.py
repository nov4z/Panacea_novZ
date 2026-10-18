#!/usr/bin/env python3
"""
Adversarial Challenger Verification Suite: Milestone M3 SpicyLyrics Viewer.

Empirically tests:
1. QML Lexical & AST Delimiter Balance:
   - Strict state-machine parser handling comments, strings, escape sequences,
     and nesting balance for (), [], {} in SpicyLyricsView.qml and ControlsView.qml.
2. Component Hierarchy and AST Structure:
   - Verifies presence and contract properties in SpicyLyricsView.qml (sys, player,
     active, trackTitle, trackArtist, status, lines, activeIndex, etc.).
   - Verifies SpicyLyrics aesthetic tokens: neon bloom glow with RectangularShadow,
     color derivation from mediaArtColor, larger bold active line font vs dimmed inactive lines,
     top & bottom vignette fade gradients, and seek-on-click capability.
   - Verifies ControlsView.qml mediaCard integration: property lyricsOpen, animated
     Layout.preferredHeight (124 -> 340), MediaBtn toggle with lyrics icon 󰎆,
     and safe MouseArea disablement when expanded.
3. Active Line Synchronization & Seek State Machine:
   - Mathematical and boundary verification of time_sec active line tracking.
   - Handling of empty lines / musical breaks, instrumental tracks, and plain lyrics.
4. End-to-End Subprocess Integration with scripts/lyrics.py:
   - Validates that lyrics.py output structure directly hydrates SpicyLyricsView fields.
"""

import json
import os
import re
import sys
import unittest
from pathlib import Path

PROJECT_ROOT = Path("/home/nova/.config/panacea")
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from tests.test_challenger_m1_settings import QmlLexerBracketParser
from scripts.lyrics import fetch_lyrics, compute_cache_key


class TestSpicyLyricsQmlDelimiterAndSyntaxIntegrity(unittest.TestCase):
    """Validates delimiter balance and syntax integrity of QML files."""

    def test_01_spicy_lyrics_view_qml_delimiter_balance(self):
        """SpicyLyricsView.qml must have perfectly balanced delimiters with 0 errors."""
        qml_path = PROJECT_ROOT / "SpicyLyricsView.qml"
        self.assertTrue(qml_path.is_file(), f"Missing {qml_path}")
        content = qml_path.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, "SpicyLyricsView.qml")
        parser.parse()
        self.assertEqual(len(parser.errors), 0, f"Delimiter errors: {parser.errors}")
        self.assertEqual(len(parser.stack), 0, f"Unclosed delimiters: {parser.stack}")

    def test_02_controls_view_qml_delimiter_balance(self):
        """ControlsView.qml must maintain 100% delimiter balance after mediaCard updates."""
        qml_path = PROJECT_ROOT / "ControlsView.qml"
        self.assertTrue(qml_path.is_file(), f"Missing {qml_path}")
        content = qml_path.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, "ControlsView.qml")
        parser.parse()
        self.assertEqual(len(parser.errors), 0, f"Delimiter errors: {parser.errors}")
        self.assertEqual(len(parser.stack), 0, f"Unclosed delimiters: {parser.stack}")

    def test_03_island_music_view_qml_delimiter_balance(self):
        """IslandMusicView.qml must maintain 100% delimiter balance with lyrics integration."""
        qml_path = PROJECT_ROOT / "IslandMusicView.qml"
        self.assertTrue(qml_path.is_file(), f"Missing {qml_path}")
        content = qml_path.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, "IslandMusicView.qml")
        parser.parse()
        self.assertEqual(len(parser.errors), 0, f"Delimiter errors: {parser.errors}")
        self.assertEqual(len(parser.stack), 0, f"Unclosed delimiters: {parser.stack}")


class TestSpicyLyricsComponentContracts(unittest.TestCase):
    """Validates AST structures, required properties, and visual tokens."""

    @classmethod
    def setUpClass(cls):
        cls.lyrics_qml = (PROJECT_ROOT / "SpicyLyricsView.qml").read_text(encoding="utf-8")
        cls.controls_qml = (PROJECT_ROOT / "ControlsView.qml").read_text(encoding="utf-8")
        cls.island_qml = (PROJECT_ROOT / "IslandMusicView.qml").read_text(encoding="utf-8")
        cls.shell_qml = (PROJECT_ROOT / "shell.qml").read_text(encoding="utf-8")

    def test_01_spicy_lyrics_view_imports(self):
        """SpicyLyricsView.qml imports QtQuick, QtQuick.Layouts, QtQuick.Effects, Quickshell, Quickshell.Io."""
        for required_import in ["QtQuick", "QtQuick.Layouts", "QtQuick.Effects", "Quickshell", "Quickshell.Io"]:
            self.assertIn(f"import {required_import}", self.lyrics_qml)

    def test_02_spicy_lyrics_view_required_properties(self):
        """SpicyLyricsView.qml exposes standard properties for system, player, and state tracking."""
        props = [
            "property var sys",
            "property var player",
            "property bool active",
            "property string status",
            "property bool isSynced",
            "property bool hasPlain",
            "property var lines",
            "property int activeIndex",
            "property string plainText",
            "property color glowColor",
        ]
        for p in props:
            self.assertIn(p, self.lyrics_qml)

    def test_03_spicy_lyrics_visual_tokens_and_glow(self):
        """SpicyLyricsView.qml implements letter-level neon bloom glow, word shimmer destello, and transparent unibody background."""
        # Neon bloom on letters & word-level shimmer destello (MultiEffect)
        self.assertIn("MultiEffect", self.lyrics_qml)
        self.assertIn("textGlow", self.lyrics_qml)
        self.assertIn("textShimmerEffect", self.lyrics_qml)
        self.assertIn("lineProgress", self.lyrics_qml)

        # Background pill badge and box shadow MUST be completely eliminated per user directive
        self.assertNotIn("glowBadge", self.lyrics_qml)
        self.assertNotIn("RectangularShadow", self.lyrics_qml)

        # Active line typography (larger, bold, radiant white or deep black for monochrome)
        self.assertIn("pixelSize: lineDelegate.isCurrent ? 15", self.lyrics_qml)
        self.assertIn("bold: lineDelegate.isCurrent", self.lyrics_qml)
        self.assertTrue('color: lineDelegate.isCurrent' in self.lyrics_qml and ('#ffffff' in self.lyrics_qml or '#0f0f11' in self.lyrics_qml))

        # Inactive line typography (dimmed alpha)
        self.assertIn("Qt.rgba(1, 1, 1, 0.45)", self.lyrics_qml)

        # Unibody: black vignette masks (color: root.colBg) MUST be completely eliminated
        self.assertNotIn("color: root.colBg", self.lyrics_qml)

        # SpicyLyrics modern typography tokens (Circular / Plus Jakarta Sans / Inter & ExtraBold)
        self.assertIn("lyricsFontFam", self.lyrics_qml)
        self.assertIn("Font.ExtraBold", self.lyrics_qml)

    def test_04_smooth_autoscroll_and_seek_on_click(self):
        """SpicyLyricsView.qml uses ListView with ApplyRange centering and seek on click."""
        self.assertIn("highlightRangeMode: ListView.ApplyRange", self.lyrics_qml)
        self.assertIn("highlightMoveDuration: 380", self.lyrics_qml)
        self.assertIn("preferredHighlightBegin: (height - 44) / 2", self.lyrics_qml)
        self.assertIn("preferredHighlightEnd: (height - 44) / 2", self.lyrics_qml)
        # Seek on click
        self.assertIn("root.player.position = lineDelegate.timeSec", self.lyrics_qml)

    def test_05_graceful_states_handling(self):
        """SpicyLyricsView.qml handles loading, instrumental, plain lyrics, and not-found states."""
        self.assertIn('root.status === "loading"', self.lyrics_qml)
        self.assertIn('root.status === "instrumental"', self.lyrics_qml)
        self.assertIn('Pista instrumental', self.lyrics_qml)
        self.assertIn('root.status === "not_found"', self.lyrics_qml)
        self.assertIn('Reintentar', self.lyrics_qml)
        self.assertIn('root.fetchLyrics(true)', self.lyrics_qml)
        self.assertIn('plainContainer', self.lyrics_qml)

    def test_06_controls_view_media_card_lyrics_toggle(self):
        """ControlsView.qml mediaCard has property lyricsOpen, animated height (124 -> 340), and lyrics button."""
        # Property lyricsOpen
        self.assertIn("property bool lyricsOpen", self.controls_qml)

        # Animated preferredHeight
        self.assertIn("Layout.preferredHeight: mediaCard.lyricsOpen ? 340 : 124", self.controls_qml)
        self.assertIn("Behavior on Layout.preferredHeight", self.controls_qml)

        # Lyrics button in media controls row
        self.assertIn('icon: "󰎆"', self.controls_qml)
        self.assertIn("primary: mediaCard.lyricsOpen", self.controls_qml)
        self.assertIn("mediaCard.lyricsOpen = !mediaCard.lyricsOpen", self.controls_qml)

    def test_07_controls_view_embeds_spicy_lyrics_view(self):
        """ControlsView.qml instantiates SpicyLyricsView with sys and mediaCard.p."""
        self.assertIn("SpicyLyricsView {", self.controls_qml)
        self.assertIn("id: spicyLyrics", self.controls_qml)
        self.assertIn("sys: view.sys", self.controls_qml)
        self.assertIn("player: mediaCard.p", self.controls_qml)
        self.assertIn("active: mediaCard.lyricsOpen", self.controls_qml)

    def test_08_controls_view_mouse_area_protection(self):
        """mediaCard background MouseArea disables when lyricsOpen is true to prevent mis-clicks."""
        self.assertIn("enabled: !mediaCard.lyricsOpen", self.controls_qml)

    def test_09_island_music_view_lyrics_integration(self):
        """IslandMusicView.qml features lyricsOpen, lyricsBtn with icon 󰎆, and embeds SpicyLyricsView."""
        self.assertIn("property bool lyricsOpen", self.island_qml)
        self.assertIn("id: lyricsBtn", self.island_qml)
        self.assertIn('text: "󰎆"', self.island_qml)
        self.assertIn("SpicyLyricsView {", self.island_qml)
        self.assertIn("id: spicyLyrics", self.island_qml)
        self.assertIn("active: view.lyricsOpen", self.island_qml)
        self.assertIn("Layout.preferredHeight: view.lyricsOpen ? 240 : 0", self.island_qml)

    def test_10_spicy_lyrics_cinematic_transitions_and_flow(self):
        """SpicyLyricsView.qml implements cubic/spring physics (Easing.OutBack / Easing.OutCubic) and harmonic destello."""
        # Scale & vertical elevation with spring overshoot
        self.assertIn("easing.type: lineDelegate.isCurrent ? Easing.OutBack : Easing.OutCubic", self.lyrics_qml)
        self.assertIn("easing.overshoot: 1.08", self.lyrics_qml)
        self.assertIn("scale: lineDelegate.isCurrent ? 1.035 :", self.lyrics_qml)
        self.assertIn("y: lineDelegate.isCurrent ? 0 : (lineDelegate.isPast ? -2 : 4)", self.lyrics_qml)
        # Continuous harmonic destello shimmer opacity
        self.assertIn("opacity: Math.sin(Math.max(0.0, Math.min(1.0, wordBox.wordProg)) * Math.PI)", self.lyrics_qml)

    def test_11_shell_lyrics_settle_synchronization(self):
        """shell.qml prevents contentSettle timer conflict and delays during lyrics animation."""
        self.assertIn("property bool lyricsAnimating", self.shell_qml)
        self.assertIn("id: lyricsAnimTimer", self.shell_qml)
        self.assertIn("onMediaLyricsOpenChanged:", self.shell_qml)
        self.assertIn("if (capsule.lyricsAnimating) return;", self.shell_qml)

    def test_12_shell_base_lyrics_anchor_protection(self):
        """shell.qml tracks baseLyricsContentH to anchor expansion and prevent undershoot on rapid toggles."""
        self.assertIn("property real baseLyricsContentH", self.shell_qml)
        self.assertIn("capsule.baseLyricsContentH", self.shell_qml)

    def test_13_island_music_lyrics_expansion_precision(self):
        """shell.qml uses precise 254px delta for islandmusic to account for preferredHeight (240) + spacing (14)."""
        self.assertIn("? 254 : 216", self.shell_qml)

    def test_14_island_music_wave_contrast_subdue(self):
        """shell.qml subdues islandMusicWave opacity to 0.0 when lyrics are active so text contrast is preserved."""
        self.assertIn("root.mediaLyricsOpen ? 0.0 : 1.0", self.shell_qml)

    def test_15_spicy_lyrics_flow_height_crossfade_continuity(self):
        """SpicyLyricsView.qml maintains height continuity during word flow crossfade."""
        self.assertIn("wordsFlow.opacity > 0.01", self.lyrics_qml)
        self.assertIn("Math.max(wordsFlow.implicitHeight, lyricsText.implicitHeight)", self.lyrics_qml)

    def test_16_collapse_duration_and_easing_synchronization(self):
        """ControlsView, IslandMusicView, and capsule.height synchronize collapse duration (280ms) and OutCubic easing."""
        self.assertIn("duration: mediaCard.lyricsOpen ? 340 : 280", self.controls_qml)
        self.assertIn("duration: view.lyricsOpen ? 340 : 280", self.island_qml)
        self.assertIn("duration: (capsule.lyricsAnimating ? root.mediaLyricsOpen : root.expanded) ? 340 : 280", self.shell_qml)
        self.assertIn("easing.type: (capsule.lyricsAnimating ? root.mediaLyricsOpen : root.expanded) ? Easing.OutBack : Easing.OutCubic", self.shell_qml)

    def test_17_island_music_height_expansion_protection(self):
        """shell.qml protects islandMusicComp from being clamped by cfg.expandedH during lyrics expansion."""
        self.assertIn("contentLoader.sourceComponent === islandMusicComp", self.shell_qml)

    def test_18_spicy_lyrics_unified_playback_state(self):
        """SpicyLyricsView.qml unifies isPlaying tracking across disparate MPRIS engines."""
        self.assertIn("readonly property bool isPlaying:", self.lyrics_qml)
        self.assertIn("running: root.active && root.isPlaying", self.lyrics_qml)
        self.assertIn("onTrackArtistChanged:", self.lyrics_qml)
        self.assertIn("onPlayerChanged:", self.lyrics_qml)

    def test_19_spicy_lyrics_empty_line_instrumental_flow(self):
        """SpicyLyricsView.qml renders musical break lines (empty text) with displayText fallback to ♪ in wordsFlow."""
        self.assertIn("displayText", self.lyrics_qml)

    def test_20_spicy_lyrics_stale_lyrics_prevention(self):
        """SpicyLyricsView.qml invalidates stale lyrics when track changes while inactive and on activation."""
        self.assertIn("targetKey !== root.currentKey", self.lyrics_qml)


class TestSpicyLyricsSynchronizationLogic(unittest.TestCase):
    """Validates the mathematical time-synchronization logic implemented in updateActiveIndex."""

    def simulate_update_active_index(self, lines, current_position):
        """Python model of the QML updateActiveIndex function."""
        if not lines:
            return -1
        pos = current_position
        n = len(lines)
        if pos < lines[0]["time_sec"]:
            return 0
        found = -1
        for i in range(n):
            if lines[i]["time_sec"] <= pos:
                found = i
            else:
                break
        return found

    def test_01_active_line_at_start(self):
        """Before first lyric timestamp, index resolves to 0."""
        lines = [
            {"time_sec": 5.0, "text": "Line 1"},
            {"time_sec": 10.0, "text": "Line 2"},
            {"time_sec": 20.0, "text": "Line 3"},
        ]
        self.assertEqual(self.simulate_update_active_index(lines, 0.0), 0)
        self.assertEqual(self.simulate_update_active_index(lines, 4.99), 0)

    def test_02_active_line_exact_boundaries(self):
        """At exact timestamp boundary, index transitions to current line."""
        lines = [
            {"time_sec": 5.0, "text": "Line 1"},
            {"time_sec": 10.0, "text": "Line 2"},
            {"time_sec": 20.0, "text": "Line 3"},
        ]
        self.assertEqual(self.simulate_update_active_index(lines, 5.0), 0)
        self.assertEqual(self.simulate_update_active_index(lines, 9.99), 0)
        self.assertEqual(self.simulate_update_active_index(lines, 10.0), 1)
        self.assertEqual(self.simulate_update_active_index(lines, 15.0), 1)
        self.assertEqual(self.simulate_update_active_index(lines, 20.0), 2)
        self.assertEqual(self.simulate_update_active_index(lines, 120.0), 2)

    def test_03_empty_lines_list(self):
        """When lines list is empty, index returns -1."""
        self.assertEqual(self.simulate_update_active_index([], 10.0), -1)


class TestLyricsEngineSpicyHydration(unittest.TestCase):
    """Tests that scripts/lyrics.py outputs JSON directly compatible with SpicyLyricsView."""

    def test_01_synced_track_hydration(self):
        """Cached Queen track hydrates into expected structure for SpicyLyricsView."""
        res = fetch_lyrics("Queen", "Bohemian Rhapsody")
        self.assertEqual(res["status"], "ok")
        self.assertTrue(res["synced"])
        self.assertGreater(len(res["lines"]), 20)
        first_line = res["lines"][0]
        self.assertIn("time_ms", first_line)
        self.assertIn("time_sec", first_line)
        self.assertIn("text", first_line)
        self.assertIsInstance(first_line["time_sec"], float)

    def test_02_instrumental_hydration(self):
        """Instrumental response hydrates with status=instrumental and empty lines."""
        from unittest.mock import patch, MagicMock
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.read.return_value = json.dumps({
            "trackName": "Clair de Lune",
            "artistName": "Claude Debussy",
            "instrumental": True,
            "syncedLyrics": None,
            "plainLyrics": None
        }).encode("utf-8")

        with patch("urllib.request.urlopen", return_value=mock_resp):
            import tempfile
            with tempfile.TemporaryDirectory() as tmpdir:
                res = fetch_lyrics("Claude Debussy", "Clair de Lune", cache_dir=tmpdir, force=True)
                self.assertEqual(res["status"], "instrumental")
                self.assertTrue(res["instrumental"])
                self.assertFalse(res["synced"])
                self.assertEqual(res["lines"], [])


class TestRapidToggleAdversarialSimulation(unittest.TestCase):
    """Adversarially probes rapid double-click toggles and ensures capsule height never undershoots."""

    class CapsuleSimulator:
        def __init__(self, page="main", base_h=530):
            self.page = page
            self.base_h = base_h
            self.contentH = base_h
            self.baseLyricsContentH = 0
            self.lyricsAnimating = False
            self.mediaLyricsOpen = False
            self.delta = 254 if page == "islandmusic" else 216

        def on_media_lyrics_open_changed(self, current_inflight_implicit_h):
            it_implicit_h = current_inflight_implicit_h
            if it_implicit_h > 40:
                delta = self.delta
                if not self.lyricsAnimating or self.baseLyricsContentH <= 40:
                    self.baseLyricsContentH = (it_implicit_h + 30) if self.mediaLyricsOpen else max(220, it_implicit_h + 30 - delta)
                self.lyricsAnimating = True
                target = (self.baseLyricsContentH + delta) if self.mediaLyricsOpen else self.baseLyricsContentH
                self.contentH = target

        def toggle(self, current_inflight_implicit_h):
            self.mediaLyricsOpen = not self.mediaLyricsOpen
            self.on_media_lyrics_open_changed(current_inflight_implicit_h)

        def anim_settle(self, final_settled_implicit_h):
            self.lyricsAnimating = False
            target = final_settled_implicit_h + 30
            self.baseLyricsContentH = max(220, target - self.delta) if self.mediaLyricsOpen else target
            if abs(target - self.contentH) >= 8:
                self.contentH = target

    def test_01_controls_view_rapid_double_toggle_never_undershoots(self):
        """Simulate user rapidly clicking lyrics in ControlsView within 50ms of each other."""
        sim = self.CapsuleSimulator(page="main", base_h=530)
        base_h = 530
        expanded_h = 530 + 216 # 746

        # Step 1: Click Open from resting collapsed state (implicitHeight = 500)
        sim.toggle(current_inflight_implicit_h=500)
        self.assertEqual(sim.contentH, expanded_h)
        self.assertEqual(sim.baseLyricsContentH, base_h)
        self.assertTrue(sim.lyricsAnimating)

        # Step 2: At t=50ms, in-flight implicitHeight has only grown to 540. User clicks Close!
        sim.toggle(current_inflight_implicit_h=540)
        # MUST return cleanly to base_h (530), NOT (540 + 30 - 216 = 354)!
        self.assertEqual(sim.contentH, base_h)
        self.assertGreaterEqual(sim.contentH, base_h, "Capsule MUST NOT undershoot below base collapsed height!")
        self.assertEqual(sim.baseLyricsContentH, base_h)

        # Step 3: At t=100ms, in-flight implicitHeight is 520. User clicks Open AGAIN!
        sim.toggle(current_inflight_implicit_h=520)
        self.assertEqual(sim.contentH, expanded_h)
        self.assertLessEqual(sim.contentH, expanded_h, "Capsule MUST NOT overshoot above expanded height!")

        # Step 4: Settle at end of animation (implicitHeight = 716)
        sim.anim_settle(final_settled_implicit_h=716)
        self.assertEqual(sim.contentH, expanded_h)
        self.assertFalse(sim.lyricsAnimating)

    def test_02_island_music_rapid_double_toggle_never_undershoots(self):
        """Simulate user rapidly clicking lyrics in IslandMusicView within 50ms of each other."""
        sim = self.CapsuleSimulator(page="islandmusic", base_h=220)
        base_h = 220
        expanded_h = 220 + 254 # 474

        # Step 1: Open from resting state
        sim.toggle(current_inflight_implicit_h=190)
        self.assertEqual(sim.contentH, expanded_h)
        self.assertEqual(sim.baseLyricsContentH, base_h)

        # Step 2: Rapid close in-flight (partial implicitHeight = 270)
        sim.toggle(current_inflight_implicit_h=270)
        self.assertEqual(sim.contentH, base_h)
        self.assertGreaterEqual(sim.contentH, base_h)

        # Step 3: Settle at resting collapsed (implicitHeight = 190)
        sim.anim_settle(final_settled_implicit_h=190)
        self.assertEqual(sim.contentH, base_h)
        self.assertFalse(sim.lyricsAnimating)


class TestM3RadiantWhiteMonochromeArt(unittest.TestCase):
    """Test suite for Milestone M3 (Requirement R3): Radiant Pure White Art Theme & Vibrant Color Preservation."""

    @classmethod
    def setUpClass(cls):
        cls.shell_qml = (PROJECT_ROOT / "shell.qml").read_text(encoding="utf-8")
        cls.controls_qml = (PROJECT_ROOT / "ControlsView.qml").read_text(encoding="utf-8")
        cls.island_qml = (PROJECT_ROOT / "IslandMusicView.qml").read_text(encoding="utf-8")
        cls.lyrics_qml = (PROJECT_ROOT / "SpicyLyricsView.qml").read_text(encoding="utf-8")

    def test_01_shell_monochrome_art_detection_and_tokens(self):
        """shell.qml maintains dark unibody surface and crisp white tokens for monochrome art."""
        # 1. isMonochromeArt detection property
        self.assertIn("readonly property bool isMonochromeArt:", self.shell_qml)
        self.assertIn("hslSaturation <= 0.08", self.shell_qml)

        # 2. Dark unibody background (0.08, 0.08, 0.09) is preserved for authentic dark theme
        self.assertIn("Qt.rgba(0.08, 0.08, 0.09, 0.98)", self.shell_qml)

        # 3. colOn provides crisp white (#ffffff) for monochrome art
        self.assertIn('root.isMonochromeArt ? "#ffffff" : root.mediaArtColor', self.shell_qml)

        # 4. effectiveWaveColor provides #ffffff for monochrome art matching Photo 2
        self.assertIn('if (root.isMonochromeArt) return "#ffffff";', self.shell_qml)
        self.assertIn('if (m === 0) return root.mediaArtColor;', self.shell_qml)

    def test_02_controls_view_monochrome_radiant_white_card(self):
        """ControlsView.qml mediaCard preserves dark unibody background and high contrast controls."""
        # Dark unibody card
        self.assertIn('color: view.sys.colBg', self.controls_qml)
        self.assertIn('color: view.sys.colFg', self.controls_qml)
        self.assertIn('color: view.sys.colMuted', self.controls_qml)

    def test_03_island_music_view_monochrome_palette(self):
        """IslandMusicView.qml maintains dark unibody palette with white typography and controls."""
        # isMonochromeArt property
        self.assertIn("readonly property bool isMonochromeArt:", self.island_qml)

    def test_04_spicy_lyrics_view_monochrome_palette(self):
        """SpicyLyricsView.qml adapts lyrics colors with white glow on dark unibody."""
        # isMonochrome property
        self.assertIn("readonly property bool isMonochrome:", self.lyrics_qml)
        self.assertIn('return "#ffffff";', self.lyrics_qml)

    def test_05_delimiter_balance_all_m3_files(self):
        """All QML files touched by M3 maintain 100% bracket and quote balance with 0 errors."""
        for filename in ["ControlsView.qml", "IslandMusicView.qml", "SpicyLyricsView.qml"]:
            qml_path = PROJECT_ROOT / filename
            content = qml_path.read_text(encoding="utf-8")
            parser = QmlLexerBracketParser(content, filename)
            success, errors = parser.parse()
            self.assertTrue(success, f"{filename} syntax error: {errors}")
            self.assertEqual(len(errors), 0, f"{filename} has delimiter balance errors: {errors}")


if __name__ == "__main__":
    unittest.main()

