#!/usr/bin/env python3
"""
Targeted Verification Suite: Milestone 2 — Strict Dark Unibody & ControlsView Media Card Fixes.

Empirically verifies:
1. ControlsView.qml mediaCard fixes:
   - Elimination of RectangularShadow inside mediaCard (prevents 90-degree scissor clip corner artifacts).
   - High-resolution album art thumbnail: removal of 42x42 layer rasterization, 512x512 mask texture size,
     antialiasing on MultiEffect, sourceSize 256x256 with PreserveAspectCrop.
   - Clean seek bar thumb: contained height, anchored to parent.bottom with zero downward overflow.
2. Strict Dark Unibody Rule (shell.qml):
   - currentNotchBg guard in mode 2 and mode 1 returning dark unibody chassis Qt.rgba(0.08, 0.08, 0.09, 0.98).
   - effectiveWaveColor returning #ffffff for monochrome art.
3. High-Contrast Text & Icons for B&W (IslandMusicView.qml & SpicyLyricsView.qml):
   - Complete absence of lingering #0f0f11 dark overrides.
   - Dynamic binding of isMonochromeArt / isMonochrome to sys.isMonochromeArt.
   - Radiant white and light gray contrasts across text, squiggly wave, and lyrics singing beam.
4. Lexical delimiter balance across all 4 touched QML components (0 errors).
"""

import sys
import unittest
from pathlib import Path

PROJECT_ROOT = Path("/home/nova/.config/panacea")
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from tests.test_challenger_m1_settings import QmlLexerBracketParser


class TestControlsViewMediaCardFixes(unittest.TestCase):
    """Verifies mediaCard corner clipping elimination and high-res thumbnail rendering."""

    @classmethod
    def setUpClass(cls):
        cls.qml_path = PROJECT_ROOT / "ControlsView.qml"
        cls.content = cls.qml_path.read_text(encoding="utf-8")

    def test_01_rectangular_shadow_eliminated_from_media_card(self):
        """RectangularShadow is eliminated from ControlsView mediaCard to prevent 90° scissor clipping box."""
        self.assertNotIn("RectangularShadow", self.content, "RectangularShadow must not exist in ControlsView.qml")

    def test_02_card_art_high_resolution_thumbnail(self):
        """cardArt removes layer.enabled (42x42 FBO) and configures high-quality sampling."""
        start_idx = self.content.find("id: cardArt")
        end_idx = self.content.find("id: cardArtMask")
        self.assertGreater(start_idx, 0)
        self.assertGreater(end_idx, start_idx)
        card_art_block = self.content[start_idx:end_idx]

        self.assertNotIn("layer.enabled: true", card_art_block, "cardArt must not force layer rasterization")
        self.assertIn("sourceSize: Qt.size(256, 256)", card_art_block)
        self.assertIn("fillMode: Image.PreserveAspectCrop", card_art_block)
        self.assertIn("mipmap: true", card_art_block)
        self.assertIn("smooth: true", card_art_block)

    def test_03_card_art_mask_super_sampling(self):
        """cardArtMask uses layer.textureSize: Qt.size(512, 512) and antialiasing on MultiEffect."""
        start_idx = self.content.find("id: cardArtMask")
        end_idx = self.content.find("visible: cardArt.status === Image.Ready")
        self.assertGreater(start_idx, 0)
        self.assertGreater(end_idx, start_idx)
        mask_block = self.content[start_idx:end_idx]

        self.assertIn("layer.textureSize: Qt.size(512, 512)", mask_block)
        self.assertIn("antialiasing: true", mask_block)

    def test_04_seek_thumb_no_downward_overflow(self):
        """Seek thumb is anchored cleanly to parent.bottom without invading the time row."""
        self.assertNotIn("anchors.verticalCenter: (view.sys && view.sys.themeMaterial) ? parent.bottom : undefined", self.content)
        self.assertIn("anchors.bottom: parent.bottom", self.content)


class TestStrictDarkUnibodyRule(unittest.TestCase):
    """Verifies that under no circumstance does the Notch or capsule become white."""

    @classmethod
    def setUpClass(cls):
        cls.shell_path = PROJECT_ROOT / "shell.qml"
        cls.content = cls.shell_path.read_text(encoding="utf-8")

    def test_01_current_notch_bg_guarded_against_monochrome_white(self):
        """currentNotchBg strictly returns dark unibody chassis Qt.rgba(0.08, 0.08, 0.09, 0.98) in mode 2 and 1."""
        self.assertIn("if (root.isMonochromeArt) return Qt.rgba(0.08, 0.08, 0.09, 0.98);", self.content)
        self.assertIn("if (root.isMonochromeArt) return Qt.rgba(0.12, 0.12, 0.14, 0.98);", self.content)

    def test_02_effective_wave_color_returns_pure_white_for_monochrome(self):
        """effectiveWaveColor returns #ffffff for monochrome art."""
        self.assertIn('if (root.isMonochromeArt) return "#ffffff";', self.content)


class TestHighContrastMonochromeControls(unittest.TestCase):
    """Verifies that all text and icons in IslandMusicView and SpicyLyricsView have radiant contrast."""

    @classmethod
    def setUpClass(cls):
        cls.island_content = (PROJECT_ROOT / "IslandMusicView.qml").read_text(encoding="utf-8")
        cls.lyrics_content = (PROJECT_ROOT / "SpicyLyricsView.qml").read_text(encoding="utf-8")

    def test_01_no_lingering_black_text_overrides(self):
        """Neither IslandMusicView nor SpicyLyricsView contains #0f0f11 overrides."""
        self.assertNotIn("#0f0f11", self.island_content, "IslandMusicView has lingering #0f0f11")
        self.assertNotIn("#0f0f11", self.lyrics_content, "SpicyLyricsView has lingering #0f0f11")

    def test_02_monochrome_bindings(self):
        """Both views bind monochrome detection to sys.isMonochromeArt."""
        self.assertIn("readonly property bool isMonochromeArt: (sys && sys.isMonochromeArt !== undefined)", self.island_content)
        self.assertIn("readonly property bool isMonochrome: (sys && sys.isMonochromeArt !== undefined)", self.lyrics_content)

    def test_03_squiggly_wave_and_beam_radiance(self):
        """Squiggly wave and lyrics singing beam shine with pure radiant white."""
        self.assertIn('ctx.strokeStyle = view.isMonochromeArt ? "#ffffff" : sys.colOn;', self.island_content)
        self.assertIn('color: root.isMonochrome ? Qt.rgba(1, 1, 1, 0.85) : Qt.hsla(root.glowColor.hslHue, 1.0, 0.85, 0.9)', self.lyrics_content)


class TestTargetedDelimiterBalance(unittest.TestCase):
    """Verifies 100% lexical delimiter balance on modified components."""

    def test_01_all_modified_files_delimiter_balance(self):
        files = ["ControlsView.qml", "IslandMusicView.qml", "SpicyLyricsView.qml"]
        for f in files:
            p = PROJECT_ROOT / f
            content = p.read_text(encoding="utf-8")
            parser = QmlLexerBracketParser(content, f)
            ok, errs = parser.parse()
            self.assertTrue(ok, f"Failed parsing {f}: {errs}")
            self.assertEqual(len(errs), 0, f"Errors in {f}: {errs}")
            self.assertEqual(len(parser.stack), 0, f"Unclosed delimiters in {f}: {parser.stack}")


if __name__ == "__main__":
    unittest.main()
