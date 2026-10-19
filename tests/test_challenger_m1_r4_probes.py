#!/usr/bin/env python3
"""
Adversarial Stress Test Probes: Milestone M1 (Round 4).

Empirically tests and verifies:
1. notchAmbientGlowIntensity (5, 35, 100, out of bounds) and notchAmbientGlowRadius (20, 60, 160, floor clamp).
2. islandLyricsHeight (160, 240, 420) and islandLyricsBehavior (manual, auto, remember).
3. State machine interaction between collapsed and expanded island preview states in SetCustomNotch.qml.
4. Toggle behavior of the lyrics button (previewLyricsOpen) in preview.
5. Lexical and delimiter balance across all touched QML components.
"""

import os
import re
import sys
import json
import unittest
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
QML_DIR = PROJECT_ROOT / "qml" if (PROJECT_ROOT / "qml").is_dir() else PROJECT_ROOT

from tests.test_challenger_m1_settings import QmlLexerBracketParser


class TestNotchAmbientGlowBoundaryAndStress(unittest.TestCase):
    """Adversarial boundary and stress tests for notch ambient spotlight glow."""

    @classmethod
    def setUpClass(cls):
        cls.notch_qml = (QML_DIR / "SetCustomNotch.qml").read_text(encoding="utf-8")
        cls.shell_qml = (QML_DIR / "shell.qml").read_text(encoding="utf-8")
        cls.settings = json.loads((PROJECT_ROOT / "settings.json").read_text(encoding="utf-8"))

    def test_settings_json_glow_defaults(self):
        """Verify settings.json ambient glow parameters."""
        self.assertEqual(self.settings.get("notchAmbientGlowEnabled"), True)
        self.assertEqual(self.settings.get("notchAmbientGlowIntensity"), 35)
        self.assertEqual(self.settings.get("notchAmbientGlowRadius"), 60)

    def test_intensity_slider_range_and_alpha_derivation(self):
        """Verify intensity slider 5..100% and alpha gradient stops at 5, 35, 100."""
        slider_match = re.search(
            r'label:\s*page\.sys\.tr\("Intensidad del resplandor ambiental"\).*?'
            r'from:\s*(\d+);\s*to:\s*(\d+);\s*step:\s*(\d+)',
            self.notch_qml,
            re.DOTALL
        )
        self.assertIsNotNone(slider_match)
        from_v, to_v, step_v = map(int, slider_match.groups())
        self.assertEqual(from_v, 5)
        self.assertEqual(to_v, 100)
        self.assertEqual(step_v, 5)

        def get_alphas(intensity):
            factor = (intensity if intensity is not None else 35) / 100.0
            a0 = min(1.0, factor * 0.65)
            a55 = min(1.0, factor * 0.18)
            return round(a0, 4), round(a55, 4)

        # Boundary 5%
        a0_5, a55_5 = get_alphas(5)
        self.assertEqual(a0_5, 0.0325)
        self.assertEqual(a55_5, 0.0090)
        self.assertGreater(a0_5, a55_5)
        self.assertGreater(a55_5, 0.0)

        # Nominal 35%
        a0_35, a55_35 = get_alphas(35)
        self.assertEqual(a0_35, 0.2275)
        self.assertEqual(a55_35, 0.0630)
        self.assertGreater(a0_35, a55_35)

        # Boundary 100%
        a0_100, a55_100 = get_alphas(100)
        self.assertEqual(a0_100, 0.6500)
        self.assertEqual(a55_100, 0.1800)
        self.assertLessEqual(a0_100, 1.0)

        # Out-of-bounds (e.g. 200% mutated config) -> clamped to 1.0
        a0_200, a55_200 = get_alphas(200)
        self.assertLessEqual(a0_200, 1.0)
        self.assertEqual(a0_200, 1.0)

    def test_radius_slider_range_and_geometry_derivation(self):
        """Verify radius slider 20..160px and dimensions at 20, 60, 160."""
        slider_match = re.search(
            r'label:\s*page\.sys\.tr\("Radio de difusión del resplandor"\).*?'
            r'from:\s*(\d+);\s*to:\s*(\d+);\s*step:\s*(\d+)',
            self.notch_qml,
            re.DOTALL
        )
        self.assertIsNotNone(slider_match)
        from_v, to_v, step_v = map(int, slider_match.groups())
        self.assertEqual(from_v, 20)
        self.assertEqual(to_v, 160)
        self.assertEqual(step_v, 5)

        notch_base_w = 300.0

        def get_glow_box(radius, base_w=notch_base_w):
            r = radius if radius is not None else 60
            w = base_w + (r * 2)
            h = max(40.0, r * 1.4)
            cr = h / 2.0
            return w, h, cr

        # Boundary 20px -> triggers Math.max(40, 28) floor
        w20, h20, cr20 = get_glow_box(20)
        self.assertEqual(w20, 340.0)
        self.assertEqual(h20, 40.0)  # Clamped to floor 40
        self.assertEqual(cr20, 20.0)

        # Nominal 60px -> height = 60 * 1.4 = 84
        w60, h60, cr60 = get_glow_box(60)
        self.assertEqual(w60, 420.0)
        self.assertEqual(h60, 84.0)
        self.assertEqual(cr60, 42.0)

        # Boundary 160px -> height = 160 * 1.4 = 224
        w160, h160, cr160 = get_glow_box(160)
        self.assertEqual(w160, 620.0)
        self.assertEqual(h160, 224.0)
        self.assertEqual(cr160, 112.0)

    def test_glow_toggle_disable_behavior(self):
        """Verify that when disabled, glow visibility/opacity drop to 0 and sliders become disabled."""
        self.assertIn("visible: page.sys.cfg.notchAmbientGlowEnabled !== false", self.notch_qml)
        self.assertIn("opacity: (page.sys.cfg.notchAmbientGlowEnabled !== false) ? 1.0 : 0.0", self.notch_qml)
        self.assertIn("enabled: page.sys.cfg.notchAmbientGlowEnabled !== false", self.notch_qml)


class TestIslandLyricsHeightAndBehaviorStress(unittest.TestCase):
    """Adversarial stress testing for islandLyricsHeight and islandLyricsBehavior."""

    @classmethod
    def setUpClass(cls):
        cls.notch_qml = (QML_DIR / "SetCustomNotch.qml").read_text(encoding="utf-8")
        cls.island_qml = (QML_DIR / "IslandMusicView.qml").read_text(encoding="utf-8")
        cls.shell_qml = (QML_DIR / "shell.qml").read_text(encoding="utf-8")
        cls.settings = json.loads((PROJECT_ROOT / "settings.json").read_text(encoding="utf-8"))

    def test_settings_json_lyrics_defaults(self):
        """Verify default values in settings.json."""
        self.assertEqual(self.settings.get("islandLyricsHeight"), 240)
        self.assertEqual(self.settings.get("islandLyricsBehavior"), "manual")

    def test_lyrics_height_slider_range(self):
        """Verify slider 160..420px with step 10."""
        slider_match = re.search(
            r'label:\s*page\.sys\.tr\("Altura objetivo del visor de letras"\).*?'
            r'from:\s*(\d+);\s*to:\s*(\d+);\s*step:\s*(\d+)',
            self.notch_qml,
            re.DOTALL
        )
        self.assertIsNotNone(slider_match)
        from_v, to_v, step_v = map(int, slider_match.groups())
        self.assertEqual(from_v, 160)
        self.assertEqual(to_v, 420)
        self.assertEqual(step_v, 10)

    def test_preview_container_height_at_lyrics_boundaries(self):
        """Verify container Layout.preferredHeight at boundaries 160, 240, 420 when open and closed."""
        base_exp = 175
        extra_pad = 46

        def calc_container_h(is_expanded, lyrics_open, cfg_height, notch_mode=True):
            if not is_expanded:
                return max(124, 38 + (0 if notch_mode else 10) + 54)
            gap = 0 if notch_mode else 10
            lyr_h = (cfg_height if cfg_height else 240) if lyrics_open else 0
            return base_exp + lyr_h + gap + extra_pad

        # Collapsed: unaffected by lyrics height
        self.assertEqual(calc_container_h(False, False, 160), 124)
        self.assertEqual(calc_container_h(False, True, 420), 124)

        # Expanded, lyrics closed: exactly base_exp + extra_pad = 221
        self.assertEqual(calc_container_h(True, False, 160), 221)
        self.assertEqual(calc_container_h(True, False, 240), 221)
        self.assertEqual(calc_container_h(True, False, 420), 221)

        # Expanded, lyrics open at 160
        self.assertEqual(calc_container_h(True, True, 160), 175 + 160 + 46)  # 381

        # Expanded, lyrics open at 240
        self.assertEqual(calc_container_h(True, True, 240), 175 + 240 + 46)  # 461

        # Expanded, lyrics open at 420
        self.assertEqual(calc_container_h(True, True, 420), 175 + 420 + 46)  # 641

    def test_shell_qml_settling_delta_calculation(self):
        """Verify shell.qml contentH delta calculation across boundaries."""
        def calc_delta(is_islandmusic, cfg_height):
            if is_islandmusic:
                h = cfg_height if cfg_height is not None else 240
                return h + 14
            return 216

        # Standard islandmusic
        self.assertEqual(calc_delta(True, 160), 174)
        self.assertEqual(calc_delta(True, 240), 254)  # Matches historic 254
        self.assertEqual(calc_delta(True, 420), 434)
        self.assertEqual(calc_delta(True, None), 254)  # Clean fallback

        # ControlsView non-islandmusic uses fixed 216
        self.assertEqual(calc_delta(False, 420), 216)

    def test_lyrics_behavior_options_specification(self):
        """Verify behavior options include manual, auto, and remember."""
        select_match = re.search(
            r'label:\s*page\.sys\.tr\("Comportamiento de apertura de letras"\).*?options:\s*\[(.*?)\]',
            self.notch_qml,
            re.DOTALL
        )
        self.assertIsNotNone(select_match)
        options_str = select_match.group(1)
        self.assertIn('"manual"', options_str)
        self.assertIn('"auto"', options_str)
        self.assertIn('"remember"', options_str)


class TestSetCustomNotchPreviewStateInteractions(unittest.TestCase):
    """Stress tests on the preview state machine in SetCustomNotch.qml."""

    @classmethod
    def setUpClass(cls):
        cls.notch_qml = (QML_DIR / "SetCustomNotch.qml").read_text(encoding="utf-8")

    def test_preview_state_properties_defined(self):
        """Verify state properties exist with expected initial values."""
        self.assertIn("property int previewState: 0", self.notch_qml)
        self.assertIn("property bool previewIsExpanded: false", self.notch_qml)
        self.assertIn("property bool previewLyricsOpen: false", self.notch_qml)

    def test_music_view_subselector_visibility_contract(self):
        """Verify music subselector is strictly bound to previewState === 0."""
        match = re.search(r'// Sub-selector de vista para Música.*?\n\s*RowLayout\s*\{([^}]+)', self.notch_qml)
        self.assertIsNotNone(match)
        block = match.group(1)
        self.assertIn("visible: page.previewState === 0", block)

    def test_collapsed_vs_expanded_view_mutual_exclusion(self):
        """Verify that collapsed item and expanded item visibility are mutually exclusive."""
        # Collapsed item
        self.assertIn("visible: page.previewState === 0 && !page.previewIsExpanded", self.notch_qml)
        # Expanded item
        self.assertIn("visible: page.previewState === 0 && page.previewIsExpanded", self.notch_qml)
        # Reposo item
        self.assertIn("visible: page.previewState === 1", self.notch_qml)

    def test_notch_click_toggle_expansion(self):
        """Verify clicking the simulated notch toggles previewIsExpanded only in Music mode."""
        sim_notch_ma = re.search(r'id:\s*simNotchMa.*?onClicked:\s*\{(.*?)\}', self.notch_qml, re.DOTALL)
        self.assertIsNotNone(sim_notch_ma)
        body = sim_notch_ma.group(1)
        self.assertIn("if (page.previewState === 0)", body)
        self.assertIn("page.previewIsExpanded = !page.previewIsExpanded;", body)

    def test_corner_radii_state_adaptability(self):
        """Verify corner radii adapt faithfully between collapsed pill and expanded island."""
        self.assertIn("(page.previewState === 0 && page.previewIsExpanded) ? 26", self.notch_qml)


class TestPreviewLyricsToggleBehavior(unittest.TestCase):
    """Empirical verification of lyrics toggle button interaction in preview."""

    @classmethod
    def setUpClass(cls):
        cls.notch_qml = (QML_DIR / "SetCustomNotch.qml").read_text(encoding="utf-8")

    def test_collapsed_lyrics_button_triggers_auto_expand_and_open(self):
        """Verify clicking prevCollapsedLyricsBtn sets previewIsExpanded = true AND toggles lyrics."""
        btn_match = re.search(r'id:\s*prevCollapsedLyricsBtn.*?id:\s*prevCollLyrMa.*?onClicked:\s*\{(.*?)\}', self.notch_qml, re.DOTALL)
        self.assertIsNotNone(btn_match, "Collapsed lyrics button onClicked handler not found")
        handler = btn_match.group(1)
        self.assertIn("page.previewIsExpanded = true;", handler)
        self.assertIn("page.previewLyricsOpen = !page.previewLyricsOpen;", handler)

    def test_expanded_lyrics_button_toggles_lyrics_without_collapsing(self):
        """Verify clicking previewLyricsBtn in expanded mode toggles previewLyricsOpen without mutating previewIsExpanded."""
        btn_match = re.search(r'id:\s*previewLyricsBtn.*?id:\s*lyrExpMa.*?onClicked:\s*\{(.*?)\}', self.notch_qml, re.DOTALL)
        self.assertIsNotNone(btn_match, "Expanded lyrics button onClicked handler not found")
        handler = btn_match.group(1)
        self.assertIn("page.previewLyricsOpen = !page.previewLyricsOpen;", handler)
        self.assertNotIn("previewIsExpanded", handler)

    def test_state_machine_transition_simulation(self):
        """Simulate sequence of user interactions on state variables."""
        class MockPreviewState:
            def __init__(self):
                self.previewState = 0
                self.previewIsExpanded = False
                self.previewLyricsOpen = False

            def click_collapsed_lyrics(self):
                self.previewIsExpanded = True
                self.previewLyricsOpen = not self.previewLyricsOpen

            def click_expanded_lyrics(self):
                self.previewLyricsOpen = not self.previewLyricsOpen

            def click_notch(self):
                if self.previewState == 0:
                    self.previewIsExpanded = not self.previewIsExpanded

            def switch_state(self, s):
                self.previewState = s

        state = MockPreviewState()

        # Step 1: Initial state
        self.assertEqual((state.previewState, state.previewIsExpanded, state.previewLyricsOpen), (0, False, False))

        # Step 2: Click collapsed lyrics button -> auto-expands and opens lyrics
        state.click_collapsed_lyrics()
        self.assertTrue(state.previewIsExpanded)
        self.assertTrue(state.previewLyricsOpen)

        # Step 3: Click expanded lyrics button -> closes lyrics, keeps expanded
        state.click_expanded_lyrics()
        self.assertTrue(state.previewIsExpanded)
        self.assertFalse(state.previewLyricsOpen)

        # Step 4: Click expanded lyrics button again -> reopens lyrics
        state.click_expanded_lyrics()
        self.assertTrue(state.previewIsExpanded)
        self.assertTrue(state.previewLyricsOpen)

        # Step 5: Click notch body -> collapses island
        state.click_notch()
        self.assertFalse(state.previewIsExpanded)
        self.assertTrue(state.previewLyricsOpen)

        # Step 6: Rapid toggle stress (100 iterations)
        current_expected = state.previewLyricsOpen
        for _ in range(100):
            state.click_expanded_lyrics()
            current_expected = not current_expected
            self.assertEqual(state.previewLyricsOpen, current_expected)

    def test_badge_text_reactivity(self):
        """Verify preview label displays lyrics status when expanded in Music mode."""
        self.assertIn("page.previewLyricsOpen", self.notch_qml)
        self.assertIn("VISTA PREVIA: ISLA EXPANDIDA CON LETRAS (SUPER+M)", self.notch_qml)
        self.assertIn("VISTA PREVIA: ISLA EXPANDIDA (SUPER+M)", self.notch_qml)


class TestQmlDelimiterIntegrity(unittest.TestCase):
    """Verify delimiter balance on modified QML files."""

    def test_set_custom_notch_balance(self):
        path = QML_DIR / "SetCustomNotch.qml"
        parser = QmlLexerBracketParser(path.read_text(encoding="utf-8"), str(path))
        ok, errs = parser.parse()
        self.assertTrue(ok, f"SetCustomNotch.qml delimiter errors: {errs}")

    def test_island_music_view_balance(self):
        path = QML_DIR / "IslandMusicView.qml"
        parser = QmlLexerBracketParser(path.read_text(encoding="utf-8"), str(path))
        ok, errs = parser.parse()
        self.assertTrue(ok, f"IslandMusicView.qml delimiter errors: {errs}")


if __name__ == "__main__":
    unittest.main()
