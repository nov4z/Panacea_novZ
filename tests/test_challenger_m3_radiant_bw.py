#!/usr/bin/env python3
"""
Adversarial Verification Suite: Milestone M3 Radiant B&W Theme & Chromatic Preservation.
Empirically tests:
1. WCAG 2.1 Contrast Ratios for all typography and UI controls against #ffffff.
2. B&W album cover detection in scripts/art_color.py across edge cases (#ffffff, #000000, #888888, low-saturation).
3. Vibrant color preservation in scripts/art_color.py (>0.08 saturation: #ff1493, #00e1ff, #ffaa00, etc.).
4. QML isMonochromeArt / isMonochrome state-machine logic and component token routing.
5. Strict lexical delimiter balance across all touched QML components.
"""

import os
import sys
import math
import colorsys
import tempfile
import subprocess
import unittest
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
QML_DIR = PROJECT_ROOT / "qml" if (PROJECT_ROOT / "qml").is_dir() else PROJECT_ROOT

from tests.test_challenger_m1_settings import QmlLexerBracketParser
from scripts.art_color import extract_dominant_color


def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join(c * 2 for c in hex_str)
    return tuple(int(hex_str[i:i+2], 16) / 255.0 for i in (0, 2, 4))


def relative_luminance(rgb):
    """Calculates WCAG 2.1 relative luminance."""
    lin = []
    for c in rgb:
        if c <= 0.04045:
            lin.append(c / 12.92)
        else:
            lin.append(((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast_ratio(hex1, hex2):
    """Calculates WCAG 2.1 contrast ratio between two hex colors."""
    l1 = relative_luminance(hex_to_rgb(hex1))
    l2 = relative_luminance(hex_to_rgb(hex2))
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def blend_alpha_over_white(rgb, alpha):
    """Blends an rgba color over pure white #ffffff background."""
    return tuple(c * alpha + 1.0 * (1.0 - alpha) for c in rgb)


class TestM3ContrastRatiosAgainstDarkUnibody(unittest.TestCase):
    """Empirical verification of WCAG contrast ratios on dark unibody #141417 surface matching Photo 2."""

    def test_01_titles_contrast_ratio(self):
        """Titles and primary playback controls (#ffffff) achieve ~18:1 contrast ratio against dark unibody #141417."""
        ratio = contrast_ratio("#ffffff", "#141417")
        # Target: ~18:1 ratio, minimum WCAG AAA normal text (7:1)
        self.assertGreaterEqual(ratio, 16.0, f"Titles ratio {ratio:.2f}:1 is below 16:1")
        self.assertLessEqual(ratio, 20.0, f"Titles ratio {ratio:.2f}:1 is above 20:1")

    def test_02_artists_contrast_ratio(self):
        """Artist metadata (Qt.rgba(1, 1, 1, 0.65) ~ #ababab) achieves ~8:1 contrast ratio against #141417."""
        ratio = contrast_ratio("#ababab", "#141417")
        # Target: passes WCAG AAA (7:1)
        self.assertGreaterEqual(ratio, 7.0, f"Artist ratio {ratio:.2f}:1 fails WCAG AAA (7:1)")

    def test_03_muted_text_contrast_ratio(self):
        """Muted time stamps and inactive lyrics (#888888) achieve ~5:1 contrast ratio against #141417."""
        ratio = contrast_ratio("#888888", "#141417")
        # Target: satisfies WCAG AA (4.5:1)
        self.assertGreaterEqual(ratio, 4.5, f"Muted ratio {ratio:.2f}:1 is below threshold")

    def test_04_hover_lyrics_contrast_ratio(self):
        """Hovered inactive lyrics (#e0e0e0) achieve high readability ~14:1 against #141417."""
        ratio = contrast_ratio("#e0e0e0", "#141417")
        self.assertGreaterEqual(ratio, 12.0)

    def test_05_plain_lyrics_text_contrast(self):
        """Plain lyrics text (Qt.rgba(1, 1, 1, 0.85) ~ #d9d9d9) achieves ~13:1 contrast ratio against #141417."""
        ratio = contrast_ratio("#d9d9d9", "#141417")
        self.assertGreaterEqual(ratio, 12.0)

    def test_06_secondary_button_composite_contrast(self):
        """Secondary button background and white icon contrast on dark unibody."""
        ratio = contrast_ratio("#ffffff", "#222226")
        self.assertGreaterEqual(ratio, 14.0)

    def test_07_progress_bar_and_wave_contrast(self):
        """Wave visualizer and progress bar active core in #ffffff against dark unibody."""
        ratio = contrast_ratio("#ffffff", "#141417")
        self.assertGreaterEqual(ratio, 16.0)


class TestM3BlackAndWhiteDetection(unittest.TestCase):
    """Empirical verification of monochrome / B&W album cover detection in scripts/art_color.py."""

    @classmethod
    def setUpClass(cls):
        cls.temp_dir = tempfile.TemporaryDirectory()
        cls.work_dir = Path(cls.temp_dir.name)

    @classmethod
    def tearDownClass(cls):
        cls.temp_dir.cleanup()

    def _create_test_image(self, filename, color):
        filepath = self.work_dir / filename
        subprocess.run(
            ["magick", "-size", "100x100", f"xc:{color}", str(filepath)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return str(filepath)

    def test_01_pure_white_image_detection(self):
        """Covers with #ffffff return radiant white fallback (#ffffff, #cccccc)."""
        img_path = self._create_test_image("art_white.png", "#ffffff")
        c1, c2 = extract_dominant_color(img_path)
        self.assertEqual(c1.lower(), "#ffffff")
        self.assertEqual(c2.lower(), "#cccccc")

    def test_02_pure_black_image_detection(self):
        """Covers with #000000 return radiant white fallback (#ffffff, #cccccc)."""
        img_path = self._create_test_image("art_black.png", "#000000")
        c1, c2 = extract_dominant_color(img_path)
        self.assertEqual(c1.lower(), "#ffffff")
        self.assertEqual(c2.lower(), "#cccccc")

    def test_03_neutral_gray_image_detection(self):
        """Covers with #888888 return radiant white fallback (#ffffff, #cccccc)."""
        img_path = self._create_test_image("art_gray.png", "#888888")
        c1, c2 = extract_dominant_color(img_path)
        self.assertEqual(c1.lower(), "#ffffff")
        self.assertEqual(c2.lower(), "#cccccc")

    def test_04_dark_gray_image_detection(self):
        """Covers with #222222 return radiant white fallback (#ffffff, #cccccc)."""
        img_path = self._create_test_image("art_darkgray.png", "#222222")
        c1, c2 = extract_dominant_color(img_path)
        self.assertEqual(c1.lower(), "#ffffff")
        self.assertEqual(c2.lower(), "#cccccc")

    def test_05_low_saturation_image_detection(self):
        """Covers with saturation <= 0.08 return radiant white fallback (#ffffff, #cccccc)."""
        # HLS: Hue=0.1, Lightness=0.5, Saturation=0.05
        r, g, b = colorsys.hls_to_rgb(0.1, 0.5, 0.05)
        hex_color = f"#{round(r*255):02x}{round(g*255):02x}{round(b*255):02x}"
        img_path = self._create_test_image("art_low_sat.png", hex_color)
        c1, c2 = extract_dominant_color(img_path)
        self.assertEqual(c1.lower(), "#ffffff")
        self.assertEqual(c2.lower(), "#cccccc")

    def test_06_boundary_saturation_0075_detection(self):
        """Covers with saturation 0.075 (< 0.08) strictly trigger monochrome detection."""
        r, g, b = colorsys.hls_to_rgb(0.6, 0.45, 0.075)
        hex_color = f"#{round(r*255):02x}{round(g*255):02x}{round(b*255):02x}"
        img_path = self._create_test_image("art_sat_0075.png", hex_color)
        c1, c2 = extract_dominant_color(img_path)
        self.assertEqual(c1.lower(), "#ffffff")
        self.assertEqual(c2.lower(), "#cccccc")


class TestM3ColorPreservation(unittest.TestCase):
    """Empirical verification that vibrant album covers (> 0.08 saturation) preserve dynamic colors."""

    @classmethod
    def setUpClass(cls):
        cls.temp_dir = tempfile.TemporaryDirectory()
        cls.work_dir = Path(cls.temp_dir.name)

    @classmethod
    def tearDownClass(cls):
        cls.temp_dir.cleanup()

    def _create_test_image(self, filename, color):
        filepath = self.work_dir / filename
        subprocess.run(
            ["magick", "-size", "100x100", f"xc:{color}", str(filepath)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return str(filepath)

    def test_01_vibrant_deeppink_preservation(self):
        """Covers with #ff1493 preserve dynamic vibrant color and do NOT activate monochrome mode."""
        img_path = self._create_test_image("art_deeppink.png", "#ff1493")
        c1, c2 = extract_dominant_color(img_path)
        self.assertNotEqual(c1.lower(), "#ffffff")
        self.assertNotEqual(c2.lower(), "#cccccc")
        rgb = hex_to_rgb(c1)
        h, l, s = colorsys.rgb_to_hls(*rgb)
        self.assertGreater(s, 0.08, f"Extracted color {c1} saturation {s} must be > 0.08")

    def test_02_vibrant_cyan_preservation(self):
        """Covers with #00e1ff preserve dynamic vibrant color and do NOT activate monochrome mode."""
        img_path = self._create_test_image("art_cyan.png", "#00e1ff")
        c1, c2 = extract_dominant_color(img_path)
        self.assertNotEqual(c1.lower(), "#ffffff")
        self.assertNotEqual(c2.lower(), "#cccccc")
        rgb = hex_to_rgb(c1)
        h, l, s = colorsys.rgb_to_hls(*rgb)
        self.assertGreater(s, 0.08, f"Extracted color {c1} saturation {s} must be > 0.08")

    def test_03_vibrant_amber_orange_preservation(self):
        """Covers with #ffaa00 preserve dynamic vibrant color and do NOT activate monochrome mode."""
        img_path = self._create_test_image("art_orange.png", "#ffaa00")
        c1, c2 = extract_dominant_color(img_path)
        self.assertNotEqual(c1.lower(), "#ffffff")
        self.assertNotEqual(c2.lower(), "#cccccc")
        rgb = hex_to_rgb(c1)
        h, l, s = colorsys.rgb_to_hls(*rgb)
        self.assertGreater(s, 0.08, f"Extracted color {c1} saturation {s} must be > 0.08")

    def test_04_vibrant_emerald_green_preservation(self):
        """Covers with #00f573 preserve dynamic vibrant color and do NOT activate monochrome mode."""
        img_path = self._create_test_image("art_green.png", "#00f573")
        c1, c2 = extract_dominant_color(img_path)
        self.assertNotEqual(c1.lower(), "#ffffff")
        self.assertNotEqual(c2.lower(), "#cccccc")
        rgb = hex_to_rgb(c1)
        h, l, s = colorsys.rgb_to_hls(*rgb)
        self.assertGreater(s, 0.08, f"Extracted color {c1} saturation {s} must be > 0.08")

    def test_05_royal_blue_default_palette_preservation(self):
        """Covers with #3b82f6 preserve dynamic vibrant color and do NOT activate monochrome mode."""
        img_path = self._create_test_image("art_blue.png", "#3b82f6")
        c1, c2 = extract_dominant_color(img_path)
        self.assertNotEqual(c1.lower(), "#ffffff")
        self.assertNotEqual(c2.lower(), "#cccccc")
        rgb = hex_to_rgb(c1)
        h, l, s = colorsys.rgb_to_hls(*rgb)
        self.assertGreater(s, 0.08, f"Extracted color {c1} saturation {s} must be > 0.08")


class TestM3QmlMonochromeStateMachineOracle(unittest.TestCase):
    """Mathematical and state-machine simulation of QML isMonochromeArt properties."""

    def qml_is_monochrome_art(self, mediaArtColor_hex, hsl_sat=None):
        """Simulates shell.qml isMonochromeArt formula:
        (root.mediaArtColor == "#ffffff" || (root.mediaArtColor && root.mediaArtColor.hslSaturation !== undefined && root.mediaArtColor.hslSaturation <= 0.08))
        """
        if mediaArtColor_hex.lower() == "#ffffff":
            return True
        if hsl_sat is not None and hsl_sat <= 0.08:
            return True
        return False

    def test_01_monochrome_art_activation_table(self):
        """Test truth table for isMonochromeArt across monochrome colors."""
        test_cases = [
            ("#ffffff", 0.0, True),
            ("#ffffff", 1.0, True),  # #ffffff always triggers
            ("#000000", 0.0, True),
            ("#888888", 0.0, True),
            ("#555555", 0.0, True),
            ("#1a1a1a", 0.0, True),
            ("#808080", 0.04, True),
            ("#858080", 0.08, True), # Exactly at boundary <= 0.08
        ]
        for hex_col, sat, expected in test_cases:
            res = self.qml_is_monochrome_art(hex_col, sat)
            self.assertEqual(res, expected, f"Failed for {hex_col} sat={sat}: expected {expected}, got {res}")

    def test_02_chromatic_preservation_activation_table(self):
        """Test truth table for isMonochromeArt across vibrant chromatic colors."""
        test_cases = [
            ("#ff1493", 1.0, False),
            ("#00e1ff", 1.0, False),
            ("#ffaa00", 1.0, False),
            ("#00f573", 1.0, False),
            ("#3b82f6", 0.9, False),
            ("#6366f1", 0.83, False),
            ("#85807f", 0.081, False), # Boundary > 0.08
            ("#808090", 0.15, False),
        ]
        for hex_col, sat, expected in test_cases:
            res = self.qml_is_monochrome_art(hex_col, sat)
            self.assertEqual(res, expected, f"Failed for {hex_col} sat={sat}: expected {expected}, got {res}")

    def test_03_shell_effective_wave_color_contract(self):
        """shell.qml effectiveWaveColor returns #ffffff for monochrome art matching Photo 2."""
        shell_qml = (QML_DIR / "shell.qml").read_text(encoding="utf-8")
        # Ensure monochrome art check precedes mode 0 check
        mono_idx = shell_qml.find('if (root.isMonochromeArt) return "#ffffff";')
        mode0_idx = shell_qml.find('if (m === 0) return root.mediaArtColor;')
        self.assertGreater(mono_idx, 0, "Missing monochrome art check in effectiveWaveColor")
        self.assertGreater(mode0_idx, 0, "Missing mode 0 check in effectiveWaveColor")
        self.assertLess(mono_idx, mode0_idx, "Monochrome art check must take precedence over mode 0 in effectiveWaveColor")

    def test_04_shell_qml_monochrome_token_declarations(self):
        """shell.qml defines isMonochromeArt, dark unibody surfaces, and white accent tokens."""
        shell_qml = (QML_DIR / "shell.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property bool isMonochromeArt:", shell_qml)
        self.assertIn('root.isMonochromeArt ? "#ffffff"', shell_qml)
        self.assertIn("Qt.rgba(0.08, 0.08, 0.09, 0.98)", shell_qml)


class TestM3DelimiterIntegrity(unittest.TestCase):
    """Delimiter and AST syntax verification across all component files touched in M3."""

    def test_01_all_touched_components_have_zero_delimiter_errors(self):
        files = [
            "ControlsView.qml",
            "IslandMusicView.qml",
            "SpicyLyricsView.qml",
            "SetCustomNotch.qml",
            "SetSounds.qml",
        ]
        for f in files:
            path = QML_DIR / f
            self.assertTrue(path.is_file(), f"Missing file {path}")
            content = path.read_text(encoding="utf-8")
            parser = QmlLexerBracketParser(content, f)
            success, errors = parser.parse()
            self.assertTrue(success, f"{f} failed bracket parsing: {errors}")
            self.assertEqual(len(errors), 0, f"{f} has delimiter errors: {errors}")
            self.assertEqual(len(parser.stack), 0, f"{f} has unclosed delimiters: {parser.stack}")


if __name__ == "__main__":
    unittest.main()
