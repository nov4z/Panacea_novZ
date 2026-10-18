#!/usr/bin/env python3
"""
Unit and Integration Tests for Panacea Sound Engine & Sound Studio Decoupling.
Milestone M2 (Requirement R2: Desacoplamiento y Mejora en el Estudio de Sonido).

Validates:
1. CLI interface and parameter flags (--spatial, --spatial-width, --reverb).
2. 2-channel stereo WAV file generation (channels=2, 16-bit PCM, 48000 Hz).
3. DSP Decoupling:
   - Stereo Spatial Width (Haas effect + Mid/Side): spatial=0.0 is pure phantom mono (L == R),
     while spatial=1.0 generates wide lateral soundstage (L != R), without altering tail length.
   - Acoustic Reverb Tail: reverb=0.0 has zero tail extension, while reverb=0.8 extends
     the buffer with decaying room reflections without altering stereo balance.
4. Synthesis Styles and Components:
   - All oscillator styles (marimba, glass, fm, bit, bubble).
   - Tactile pop synthesis (synth_pop) and silence padding (make_silence).
   - Antigravity AI acoustic signatures (aero, quantum, orbit).
5. QML and Settings Contracts:
   - settings.json, shell.qml, and SetSounds.qml parameter bindings.
   - QML bracket and delimiter balance in SetSounds.qml.
"""

import os
import re
import sys
import json
import wave
import shutil
import tempfile
import subprocess
import unittest
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import sound_engine
from sound_engine import (
    SAMPLE_RATE,
    NOTES,
    make_silence,
    apply_audio_dsp,
    synth_tone,
    synth_pop,
    save_wav,
    generate_pack,
    generate_antigravity,
)
from tests.test_challenger_m1_settings import QmlLexerBracketParser


class TestSoundEngineCLI(unittest.TestCase):
    """Verifies sound_engine.py command line interface and execution."""

    def test_cli_flags_present(self):
        """Verify --spatial, --spatial-width, and --reverb CLI flags are present in help."""
        proc = subprocess.run(
            ["python3", str(PROJECT_ROOT / "sound_engine.py"), "--help"],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
        )
        self.assertEqual(proc.returncode, 0)
        self.assertIn("--spatial", proc.stdout)
        self.assertIn("--spatial-width", proc.stdout)
        self.assertIn("--reverb", proc.stdout)

    def test_cli_list_action(self):
        """Verify sound_engine.py list prints available sound pack directories."""
        proc = subprocess.run(
            ["python3", str(PROJECT_ROOT / "sound_engine.py"), "list"],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
        )
        self.assertEqual(proc.returncode, 0)
        output = proc.stdout.strip()
        self.assertIn("material", output)
        self.assertIn("zen", output)

    def test_cli_preview_generates_stereo_wav(self):
        """Verify preview action synthesizes a 2-channel 48kHz WAV file."""
        preview_path = "/tmp/panacea_sound_preview.wav"
        if os.path.exists(preview_path):
            os.remove(preview_path)

        proc = subprocess.run(
            [
                "python3",
                str(PROJECT_ROOT / "sound_engine.py"),
                "preview",
                "--spatial", "0.75",
                "--reverb", "0.25",
            ],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
        )
        self.assertEqual(proc.returncode, 0, f"Preview failed: {proc.stderr}")
        self.assertTrue(os.path.exists(preview_path), "Preview WAV file was not created")

        with wave.open(preview_path, "rb") as w:
            self.assertEqual(w.getnchannels(), 2, "Preview must be 2-channel stereo")
            self.assertEqual(w.getframerate(), 48000, "Sample rate must be 48000 Hz")
            self.assertEqual(w.getsampwidth(), 2, "Sample width must be 2 bytes (16-bit PCM)")
            self.assertGreater(w.getnframes(), 0, "WAV must contain frames")

    def test_cli_generate_custom_pack_stereo(self):
        """Verify generate action produces 2-channel stereo WAV files in target pack directory."""
        test_pack_name = "test_unit_m2_pack"
        pack_dir = PROJECT_ROOT / "sounds" / test_pack_name
        if pack_dir.exists():
            shutil.rmtree(pack_dir)

        try:
            proc = subprocess.run(
                [
                    "python3",
                    str(PROJECT_ROOT / "sound_engine.py"),
                    "generate",
                    "--pack", test_pack_name,
                    "--spatial", "0.6",
                    "--reverb", "0.2",
                ],
                capture_output=True,
                text=True,
                cwd=str(PROJECT_ROOT),
            )
            self.assertEqual(proc.returncode, 0, f"Generate failed: {proc.stderr}")
            self.assertTrue(pack_dir.exists(), "Pack directory was not created")

            test_files = ["connect.wav", "island_pop.wav", "notif_antigravity_aero.wav"]
            for fname in test_files:
                fpath = pack_dir / fname
                self.assertTrue(fpath.exists(), f"Expected sound file {fname} not found")
                with wave.open(str(fpath), "rb") as w:
                    self.assertEqual(w.getnchannels(), 2, f"{fname} must be 2-channel stereo")
                    self.assertEqual(w.getframerate(), 48000)
                    self.assertEqual(w.getsampwidth(), 2)
        finally:
            if pack_dir.exists():
                shutil.rmtree(pack_dir)


class TestStereoDecouplingDSP(unittest.TestCase):
    """Mathematical and empirical tests validating decoupling of Spatial Width from Reverb Tail."""

    def test_spatial_zero_is_exact_phantom_mono(self):
        """When spatial == 0.0, Left and Right channels must be mathematically identical."""
        samples = synth_tone(NOTES["C6"], 80.0, spatial=0.0, reverb=0.3, channels=2)
        self.assertEqual(len(samples) % 2, 0, "Stereo samples must be even in length")
        left = samples[0::2]
        right = samples[1::2]
        self.assertEqual(left, right, "Left and Right channels must be identical when spatial == 0.0")

    def test_spatial_one_produces_distinct_stereo_channels(self):
        """When spatial == 1.0, Left and Right channels must differ significantly."""
        samples = synth_tone(NOTES["C6"], 80.0, spatial=1.0, reverb=0.3, channels=2)
        self.assertEqual(len(samples) % 2, 0)
        left = samples[0::2]
        right = samples[1::2]
        self.assertNotEqual(left, right, "Left and Right channels must differ when spatial == 1.0")
        diff_count = sum(1 for l, r in zip(left, right) if l != r)
        diff_ratio = diff_count / len(left)
        self.assertGreater(diff_ratio, 0.70, "At least 70% of stereo frames must differ at full spatial width")

    def test_spatial_does_not_affect_buffer_duration_or_tail_length(self):
        """Varying spatial from 0.0 to 1.0 must not alter the buffer length or tail duration."""
        len_mono = len(synth_tone(NOTES["A5"], 90.0, spatial=0.0, reverb=0.25, channels=2))
        len_mid = len(synth_tone(NOTES["A5"], 90.0, spatial=0.5, reverb=0.25, channels=2))
        len_wide = len(synth_tone(NOTES["A5"], 90.0, spatial=1.0, reverb=0.25, channels=2))
        self.assertEqual(len_mono, len_mid, "Spatial width must not alter sample count")
        self.assertEqual(len_mid, len_wide, "Spatial width must not alter sample count")

    def test_reverb_zero_has_zero_tail_extension(self):
        """When reverb == 0.0, tail extension must be 0 ms."""
        duration_ms = 100.0
        decay = 1.0
        samples_dry = synth_tone(NOTES["C6"], duration_ms, decay=decay, reverb=0.0, spatial=0.5, channels=2)
        expected_raw_samples = int(SAMPLE_RATE * (duration_ms * decay / 1000.0))
        expected_stereo_samples = 2 * expected_raw_samples
        self.assertEqual(len(samples_dry), expected_stereo_samples, "Dry note must have 0 tail extension")

    def test_reverb_positive_extends_buffer_accurately(self):
        """When reverb > 0, tail extension must equal 2 * round(SAMPLE_RATE * 0.35 * reverb)."""
        duration_ms = 80.0
        samples_dry = synth_tone(NOTES["E6"], duration_ms, reverb=0.0, spatial=0.5, channels=2)
        reverb_val = 0.60
        samples_wet = synth_tone(NOTES["E6"], duration_ms, reverb=reverb_val, spatial=0.5, channels=2)

        expected_tail = 2 * int(round(SAMPLE_RATE * 0.35 * reverb_val))
        actual_tail = len(samples_wet) - len(samples_dry)
        self.assertEqual(actual_tail, expected_tail, f"Reverb tail length mismatch: {actual_tail} vs {expected_tail}")

    def test_reverb_does_not_alter_phantom_mono_balance(self):
        """When spatial == 0.0, reverb tail reflections must remain strictly phantom mono."""
        samples = synth_tone(NOTES["G5"], 70.0, spatial=0.0, reverb=0.75, channels=2)
        left = samples[0::2]
        right = samples[1::2]
        self.assertEqual(left, right, "Reverb reflections must remain phantom mono when spatial == 0.0")

    def test_reverb_tail_decays_naturally(self):
        """Verify that audio energy decays smoothly over the reverb tail."""
        samples = synth_tone(NOTES["C6"], 50.0, decay=0.5, spatial=0.5, reverb=0.8, channels=2)
        # Compute RMS in early tail vs late tail
        tail_start = int(len(samples) * 0.6)
        early_tail = samples[tail_start : tail_start + 1000]
        late_tail = samples[-1000:]
        rms_early = (sum(x * x for x in early_tail) / len(early_tail)) ** 0.5
        rms_late = (sum(x * x for x in late_tail) / len(late_tail)) ** 0.5
        self.assertGreater(rms_early, rms_late, "Reverb tail energy must decay over time")


class TestSynthesisStylesAndComponents(unittest.TestCase):
    """Tests all oscillator styles, pop synthesis, and Antigravity signatures."""

    def test_all_oscillator_styles(self):
        """Verify marimba, glass, fm, bit, bubble styles synthesize without error."""
        styles = ["marimba", "glass", "fm", "bit", "bubble"]
        for st in styles:
            samples = synth_tone(NOTES["C6"], 60.0, style=st, spatial=0.5, reverb=0.2, channels=2)
            self.assertGreater(len(samples), 0, f"Style {st} produced empty samples")
            # Verify 16-bit range bounds [-32767, 32767]
            self.assertTrue(all(-32768 <= x <= 32767 for x in samples), f"Style {st} produced out of bound samples")

    def test_synth_pop_tactile(self):
        """Verify tactile pop synthesis generates 2-channel stereo bounded samples."""
        samples = synth_pop(1150.0, 420.0, 75.0, spatial=0.5, reverb=0.15, channels=2)
        self.assertGreater(len(samples), 0)
        self.assertEqual(len(samples) % 2, 0)
        self.assertTrue(all(-32768 <= x <= 32767 for x in samples))

    def test_make_silence_stereo(self):
        """Verify make_silence returns exact number of zero samples for stereo."""
        duration_ms = 25.0
        silence = make_silence(duration_ms, channels=2)
        expected_len = 2 * int(SAMPLE_RATE * (duration_ms / 1000.0))
        self.assertEqual(len(silence), expected_len)
        self.assertTrue(all(x == 0 for x in silence))

    def test_generate_antigravity_files(self):
        """Verify generate_antigravity creates aero, quantum, and orbit audio files."""
        temp_dir = tempfile.mkdtemp()
        try:
            generate_antigravity(temp_dir, channels=2, spatial=0.5, reverb=0.2)
            expected_files = [
                "notif_antigravity_aero.wav",
                "notif_antigravity.wav",
                "notif_antigravity_studio.wav",
                "notif_antigravity_quantum.wav",
                "notif_antigravity_orbit.wav",
            ]
            for ef in expected_files:
                fpath = os.path.join(temp_dir, ef)
                self.assertTrue(os.path.exists(fpath), f"File {ef} was not generated")
                with wave.open(fpath, "rb") as w:
                    self.assertEqual(w.getnchannels(), 2)
                    self.assertEqual(w.getframerate(), 48000)
        finally:
            shutil.rmtree(temp_dir)


class TestQMLAndSettingsContracts(unittest.TestCase):
    """Verifies that settings.json, shell.qml, and SetSounds.qml satisfy all architectural contracts."""

    def test_settings_json_has_sound_custom_spatial_width(self):
        """settings.json must contain soundCustomSpatialWidth."""
        settings_path = PROJECT_ROOT / "settings.json"
        data = json.loads(settings_path.read_text(encoding="utf-8"))
        self.assertIn("soundCustomSpatialWidth", data)
        self.assertIn("soundCustomReverb", data)
        self.assertIsInstance(data["soundCustomSpatialWidth"], (int, float))
        self.assertGreaterEqual(data["soundCustomSpatialWidth"], 0.0)
        self.assertLessEqual(data["soundCustomSpatialWidth"], 1.0)

    def test_shell_qml_contains_sound_custom_spatial_width(self):
        """shell.qml must declare soundCustomSpatialWidth in JsonAdapter and defaultCfg."""
        content = (PROJECT_ROOT / "shell.qml").read_text(encoding="utf-8")
        self.assertIn("property real   soundCustomSpatialWidth", content)
        self.assertIn("soundCustomSpatialWidth: 0.50", content)

    def test_setsounds_qml_independent_sliders(self):
        """SetSounds.qml Block C must contain two independent SetSlider components."""
        content = (PROJECT_ROOT / "SetSounds.qml").read_text(encoding="utf-8")
        self.assertIn("page.sys.cfg.soundCustomSpatialWidth", content)
        self.assertIn("page.sys.cfg.soundCustomReverb", content)
        self.assertIn("Espacialidad Estéreo (Apertura y difusión lateral)", content)
        self.assertIn("Cola de Reverb Acústica (Reflexiones de sala y caída)", content)

    def test_setsounds_qml_passes_spatial_and_reverb_cli_flags(self):
        """runPreview, generateCustomPack, and compileAntigravitySound must pass --spatial and --reverb."""
        content = (PROJECT_ROOT / "SetSounds.qml").read_text(encoding="utf-8")
        # Ensure --spatial and --reverb appear in commands
        spatial_count = content.count('"--spatial", spatial.toFixed(2)')
        reverb_count = content.count('"--reverb", reverb.toFixed(2)')
        self.assertGreaterEqual(spatial_count, 3, "Expected --spatial in runPreview, generate, and antigravity")
        self.assertGreaterEqual(reverb_count, 3, "Expected --reverb in runPreview, generate, and antigravity")

    def test_setsounds_qml_bracket_balance(self):
        """SetSounds.qml must have 100% balanced brackets and quotes with 0 parser errors."""
        content = (PROJECT_ROOT / "SetSounds.qml").read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, "SetSounds.qml")
        parser.parse()
        self.assertEqual(len(parser.errors), 0, f"Delimiter errors in SetSounds.qml: {parser.errors}")


if __name__ == "__main__":
    unittest.main()
