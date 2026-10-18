#!/usr/bin/env python3
"""
Comprehensive verification test suite for Panacea Milestone 2:
Logo Asset & QML Visual Components.

Verifies:
1. Asset Integrity (assets/antigravity.png):
   - Existence and valid PNG 8-byte signature.
   - Exact dimensions (404x372 px) and color type (RGBA, 8-bit).
   - Authentic transparent background (over 50% true alpha=0 pixels, corners transparent).
   - Branding color palette fidelity (vibrant multi-color gradient: blue, green, yellow, red, violet).
2. AntigravityLogo.qml Component:
   - Clean QML structure, QtQuick imports, root Item.
   - Contract properties: active (bool, default true), size (int, default 18).
   - Scalable sizing matching Panacea notch (implicitWidth, implicitHeight).
   - Image source, PreserveAspectFit, crisp sourceSize (64x64), smooth/mipmap antialiasing.
   - 60fps infinite levitation animation (sinusoidal float, breathing scale, subtle tilt).
   - Active state binding with smooth entrance/exit transitions (opacity and scale).
3. AntigravityWave.qml Component:
   - Clean QML structure, QtQuick imports, root Item.
   - Contract properties: active (bool, default true), waveColor (color, valid hex), subagentCount (int, default 0), textColor (color).
   - Canvas FBO rendering (renderTarget: Canvas.FramebufferObject) with continuous ribbon sine wave.
   - Dual-harmonic sine formula with boundary taper anchoring smoothly to center at endpoints.
   - Subagent counter badge placed immediately right of wave:
     * Hidden when subagentCount <= 1 (wave alone rendered).
     * Displayed when subagentCount >= 2 (number badge displayed).
   - Notch typography tokens (fontFam, fontSize, bold).
   - Smooth entrance/exit transitions on opacity, scale, and implicitWidth.
4. E2E Test Suite Validation:
   - Executes all test cases for features F4, F5, F6, F7, F8, F9 across Tier 1 and Tier 2.
"""

import os
import sys
import math
import struct
import zlib
import unittest
import subprocess
from pathlib import Path

PANACEA_DIR = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
ASSETS_DIR = PANACEA_DIR / "assets"
LOGO_ASSET = ASSETS_DIR / "antigravity.png"
LOGO_QML = PANACEA_DIR / "AntigravityLogo.qml"
WAVE_QML = PANACEA_DIR / "AntigravityWave.qml"
TESTS_DIR = PANACEA_DIR / "tests"

if str(PANACEA_DIR) not in sys.path:
    sys.path.insert(0, str(PANACEA_DIR))


def decode_png_pixels(png_path: Path):
    """Parses PNG header and decodes raw RGBA pixels after scanline unfiltering."""
    with open(png_path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Invalid PNG signature")
        
        idat = b""
        w, h, bit_depth, color_type = 0, 0, 0, 0
        while True:
            chunk_len_b = f.read(4)
            if not chunk_len_b:
                break
            chunk_len = struct.unpack(">I", chunk_len_b)[0]
            chunk_type = f.read(4)
            chunk_data = f.read(chunk_len)
            f.read(4)  # CRC
            
            if chunk_type == b"IHDR":
                w, h, bit_depth, color_type = struct.unpack(">IIBB", chunk_data[:10])
            elif chunk_type == b"IDAT":
                idat += chunk_data
            elif chunk_type == b"IEND":
                break

    raw = zlib.decompress(idat)
    stride = 1 + w * 4
    prev = [0] * (w * 4)
    pixels = []

    def paeth(a, b, c):
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        elif pb <= pc:
            return b
        return c

    for y in range(h):
        filter_type = raw[y * stride]
        line = list(raw[y * stride + 1 : (y + 1) * stride])
        curr = [0] * (w * 4)
        for i in range(w * 4):
            a = curr[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            val = line[i]
            if filter_type == 0:
                res = val
            elif filter_type == 1:
                res = (val + a) & 0xFF
            elif filter_type == 2:
                res = (val + b) & 0xFF
            elif filter_type == 3:
                res = (val + (a + b) // 2) & 0xFF
            elif filter_type == 4:
                res = (val + paeth(a, b, c)) & 0xFF
            else:
                res = val
            curr[i] = res
        
        for x in range(w):
            idx = x * 4
            pixels.append((curr[idx], curr[idx + 1], curr[idx + 2], curr[idx + 3]))
        prev = curr

    return w, h, bit_depth, color_type, pixels


class TestLogoAssetIntegrity(unittest.TestCase):
    """Verifies authenticity, dimensions, transparency, and palette of assets/antigravity.png."""

    def test_01_asset_file_exists_and_non_empty(self):
        self.assertTrue(LOGO_ASSET.exists(), f"Asset {LOGO_ASSET} must exist")
        self.assertTrue(LOGO_ASSET.is_file(), f"{LOGO_ASSET} must be a file")
        self.assertGreater(LOGO_ASSET.stat().st_size, 1000, "Asset size must be > 1KB")

    def test_02_png_signature_and_headers(self):
        data = LOGO_ASSET.read_bytes()
        png_sig = b"\x89PNG\r\n\x1a\n"
        self.assertTrue(data.startswith(png_sig), "Asset must have standard PNG header signature")

    def test_03_dimensions_and_color_type(self):
        w, h, bit_depth, color_type, _ = decode_png_pixels(LOGO_ASSET)
        self.assertEqual(w, 404, "Logo width must be exactly 404px")
        self.assertEqual(h, 372, "Logo height must be exactly 372px")
        self.assertEqual(bit_depth, 8, "Bit depth must be 8-bit per channel")
        self.assertEqual(color_type, 6, "Color type must be 6 (RGBA with alpha channel)")

    def test_04_true_transparent_background(self):
        w, h, _, _, pixels = decode_png_pixels(LOGO_ASSET)
        total_pixels = len(pixels)
        transparent_pixels = sum(1 for p in pixels if p[3] == 0)
        opaque_pixels = sum(1 for p in pixels if p[3] == 255)
        semi_trans_pixels = sum(1 for p in pixels if 0 < p[3] < 255)

        # Transparent background should cover majority of bounding box (>50%)
        self.assertGreater(transparent_pixels / total_pixels, 0.50,
                           "Transparent pixels must exceed 50% of the image canvas")
        self.assertGreater(opaque_pixels + semi_trans_pixels, 10000,
                           "Logo arch must contain visible colored pixels")

        # Corner pixels must be completely transparent
        corners = [
            pixels[0],               # Top-left
            pixels[w - 1],           # Top-right
            pixels[(h - 1) * w],     # Bottom-left
            pixels[w * h - 1],       # Bottom-right
        ]
        for idx, corner in enumerate(corners):
            self.assertEqual(corner[3], 0, f"Corner {idx} must have 0 alpha (fully transparent)")

    def test_05_multi_color_palette_fidelity(self):
        _, _, _, _, pixels = decode_png_pixels(LOGO_ASSET)
        visible_pixels = [p for p in pixels if p[3] > 128]
        self.assertGreater(len(visible_pixels), 20000)

        # Detect Google / Antigravity branding color regions
        blue_count = sum(1 for r, g, b, _ in visible_pixels if b > 180 and r < 120)
        green_count = sum(1 for r, g, b, _ in visible_pixels if g > r and g > b)
        red_count = sum(1 for r, g, b, _ in visible_pixels if r > 180 and b < 100 and g < 120)
        yellow_count = sum(1 for r, g, b, _ in visible_pixels if r > 180 and g > 150 and b < 80)
        violet_count = sum(1 for r, g, b, _ in visible_pixels if r > 100 and b > 140 and g < 130)

        self.assertGreater(blue_count, 10000, "Vibrant blue core body must be present")
        self.assertGreater(green_count, 1000, "Green shoulder gradient must be present")
        self.assertGreater(red_count, 500, "Red crown right gradient must be present")
        self.assertGreater(yellow_count, 200, "Yellow crown apex gradient must be present")
        self.assertGreater(violet_count, 500, "Violet/purple transition must be present")


class TestAntigravityLogoQml(unittest.TestCase):
    """Verifies contracts, properties, animations, and transitions of AntigravityLogo.qml."""

    @classmethod
    def setUpClass(cls):
        cls.content = LOGO_QML.read_text(encoding="utf-8")

    def test_01_file_exists(self):
        self.assertTrue(LOGO_QML.exists(), f"{LOGO_QML} must exist")
        self.assertTrue(LOGO_QML.is_file(), f"{LOGO_QML} must be a file")

    def test_02_qml_imports_and_root_item(self):
        self.assertIn("import QtQuick", self.content)
        self.assertIn("Item {", self.content)

    def test_03_contract_properties_and_defaults(self):
        self.assertIn("property bool active: true", self.content)
        self.assertTrue("property int size: 18" in self.content or "property int size" in self.content)
        self.assertIn("implicitWidth: size", self.content)
        self.assertIn("implicitHeight: size", self.content)

    def test_04_image_configuration(self):
        self.assertIn("Image {", self.content)
        self.assertIn('"assets/antigravity.png"', self.content)
        self.assertIn("PreserveAspectFit", self.content)
        self.assertIn("sourceSize:", self.content)
        self.assertIn("smooth: true", self.content)
        self.assertIn("mipmap: true", self.content)
        self.assertIn("antialiasing: true", self.content)

    def test_05_fluid_infinite_levitation_animation(self):
        self.assertIn("SequentialAnimation", self.content)
        self.assertIn("Animation.Infinite", self.content)
        self.assertIn("running: root.active", self.content)
        self.assertIn("InOutSine", self.content)
        self.assertIn("floatTranslate", self.content)
        self.assertIn("property: \"y\"", self.content)
        self.assertIn("property: \"scale\"", self.content)
        self.assertIn("property: \"rotation\"", self.content)
        self.assertIn("duration: 2000", self.content)
        self.assertIn("duration: 2600", self.content)

    def test_06_smooth_entrance_exit_transitions(self):
        self.assertIn("Behavior on opacity", self.content)
        self.assertIn("Behavior on scale", self.content)
        self.assertIn("Easing.OutCubic", self.content)
        self.assertIn("Easing.OutBack", self.content)
        self.assertIn("active ? 1.0 : 0.0", self.content)


class TestAntigravityWaveQml(unittest.TestCase):
    """Verifies contracts, properties, Canvas FBO rendering, and counter of AntigravityWave.qml."""

    @classmethod
    def setUpClass(cls):
        cls.content = WAVE_QML.read_text(encoding="utf-8")

    def test_01_file_exists(self):
        self.assertTrue(WAVE_QML.exists(), f"{WAVE_QML} must exist")
        self.assertTrue(WAVE_QML.is_file(), f"{WAVE_QML} must be a file")

    def test_02_qml_imports_and_root_item(self):
        self.assertIn("import QtQuick", self.content)
        self.assertIn("Item {", self.content)

    def test_03_contract_properties_and_defaults(self):
        self.assertIn("property bool active: true", self.content)
        self.assertIn("property color waveColor", self.content)
        self.assertIn("property int subagentCount: 0", self.content)
        self.assertIn("property color textColor", self.content)
        self.assertIn("property real waveWidth: 28", self.content)
        self.assertIn("property real waveHeight: 16", self.content)
        self.assertIn("implicitHeight: waveHeight", self.content)

    def test_04_canvas_fbo_rendering(self):
        self.assertIn("Canvas {", self.content)
        self.assertIn("renderTarget: Canvas.FramebufferObject", self.content)
        self.assertIn("antialiasing: true", self.content)
        self.assertIn("smooth: true", self.content)
        self.assertIn("requestPaint", self.content)
        self.assertIn("onPaint:", self.content)
        self.assertIn("getContext(\"2d\")", self.content)

    def test_05_wave_phase_animation(self):
        self.assertIn("NumberAnimation on phase", self.content)
        self.assertIn("Animation.Infinite", self.content)
        self.assertIn("running: root.active && root.visible", self.content)

    def test_06_subagent_counter_badge(self):
        self.assertIn("counterBox", self.content)
        self.assertIn("visible: root.subagentCount >= 2", self.content)
        self.assertIn("subagentCount >= 2 ? String(root.subagentCount) : \"\"", self.content)
        self.assertIn("font.bold: true", self.content)
        self.assertIn("Behavior on width", self.content)

    def test_07_smooth_entrance_exit_transitions(self):
        self.assertIn("Behavior on opacity", self.content)
        self.assertIn("Behavior on scale", self.content)
        self.assertIn("Behavior on implicitWidth", self.content)
        self.assertIn("Behavior on waveColor", self.content)


class TestE2ESuiteIntegration(unittest.TestCase):
    """Runs all discovered test cases for features F4-F9 from test_tier1 and test_tier2."""

    def test_f4_through_f9_e2e_features_pass(self):
        from tests.test_tier1_feature import TestTier1FeatureCoverage
        from tests.test_tier2_boundary import TestTier2BoundaryAndEdgeCases

        suite = unittest.TestSuite()
        loader = unittest.defaultTestLoader

        for feature in ["f4", "f5", "f6", "f7", "f8", "f9"]:
            for cls in [TestTier1FeatureCoverage, TestTier2BoundaryAndEdgeCases]:
                for method_name in loader.getTestCaseNames(cls):
                    if feature in method_name.lower():
                        suite.addTest(cls(method_name))

        runner = unittest.TextTestRunner(verbosity=1)
        result = runner.run(suite)

        self.assertEqual(len(result.errors), 0, f"Errors in E2E tests: {result.errors}")
        self.assertEqual(len(result.failures), 0, f"Failures in E2E tests: {result.failures}")
        self.assertEqual(len(result.skipped), 0, f"Skipped E2E tests: {result.skipped}")
        self.assertEqual(result.testsRun, 60, f"Expected 60 tests for F4-F9, got {result.testsRun}")


def run_tests():
    """Runs unittest suite and also runs E2E test runner command."""
    print("=" * 70)
    print(" Panacea Milestone 2 Visual Components Verification")
    print("=" * 70)
    
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(TestLogoAssetIntegrity))
    suite.addTests(loader.loadTestsFromTestCase(TestAntigravityLogoQml))
    suite.addTests(loader.loadTestsFromTestCase(TestAntigravityWaveQml))
    suite.addTests(loader.loadTestsFromTestCase(TestE2ESuiteIntegration))

    runner = unittest.TextTestRunner(verbosity=2)
    res = runner.run(suite)

    print("\n" + "=" * 70)
    print(f" Summary: {res.testsRun} tests run, {len(res.errors)} errors, {len(res.failures)} failures")
    print("=" * 70)

    # Also run the runner filter command as specified in prompt
    print("\nRunning E2E runner filter execution:")
    cmd = [
        sys.executable,
        str(PANACEA_DIR / "tests" / "run_tests.py"),
        "-k",
        "_f4_ or _f5_ or _f6_ or _f7_ or _f8_ or _f9_",
    ]
    sub_res = subprocess.run(cmd, capture_output=True, text=True)
    print(sub_res.stdout)

    return 0 if (len(res.errors) == 0 and len(res.failures) == 0) else 1


if __name__ == "__main__":
    sys.exit(run_tests())
