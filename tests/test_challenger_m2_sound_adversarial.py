#!/usr/bin/env python3
"""
Adversarial Stress Test Suite: Milestone M2 (Round 5).
Empirical verification of mathematical decoupling and audio fidelity in sound_engine.py.

Verification of Core Invariants:
1. Does changing spatial change the buffer duration or decay envelope? (It should NOT - 0% tail length change).
2. When spatial == 0.0, is channel L exactly equal to channel R?
3. When spatial > 0.0, do L and R differ as expected from Haas / Mid-Side processing?
4. Does changing reverb affect channel balance? (It should NOT - balance invariant across reverb).
5. Are generated WAV files valid 2-channel stereo 48kHz 16-bit PCM?
6. Boundary conditions and stress bursts (empty inputs, extreme gains, rapid calls).
"""

import os
import math
import wave
import struct
import shutil
import tempfile
import subprocess
import unittest
from pathlib import Path

PROJECT_ROOT = Path("/home/nova/.config/panacea")
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


class TestMathematicalDecouplingSpatialVsReverb(unittest.TestCase):
    """Rigorous empirical verification of mathematical decoupling."""

    def test_spatial_variation_zero_tail_length_change(self):
        """Altering spatial from 0.0 to 1.0 must cause exactly 0% change in buffer length."""
        test_durations = [30.0, 75.0, 150.0, 300.0]
        test_reverbs = [0.0, 0.15, 0.35, 0.80]

        for dur in test_durations:
            for rev in test_reverbs:
                baseline_len = None
                for sp in [0.0, 0.05, 0.25, 0.50, 0.75, 0.95, 1.0]:
                    samples = synth_tone(NOTES["C6"], dur, spatial=sp, reverb=rev, channels=2)
                    if baseline_len is None:
                        baseline_len = len(samples)
                    else:
                        tail_delta = abs(len(samples) - baseline_len)
                        self.assertEqual(
                            tail_delta, 0,
                            f"Spatial {sp} changed buffer length by {tail_delta} samples (dur={dur}, rev={rev})"
                        )

    def test_spatial_variation_preserves_mid_channel_decay_envelope(self):
        """The Mid channel (L + R) / 2 must remain mathematically invariant across spatial settings."""
        dur = 120.0
        rev = 0.40
        mono_baseline = synth_tone(NOTES["A5"], dur, spatial=0.0, reverb=rev, channels=2)
        base_mid = mono_baseline[0::2]  # When spatial==0, L == R == Mid

        for sp in [0.2, 0.5, 0.8, 1.0]:
            stereo = synth_tone(NOTES["A5"], dur, spatial=sp, reverb=rev, channels=2)
            left = stereo[0::2]
            right = stereo[1::2]
            self.assertEqual(len(left), len(base_mid))

            # Mid = (L + R) / 2 (subject only to int quantization error <= 1 LSB)
            max_dev = 0
            for i in range(len(base_mid)):
                recovered_mid = (left[i] + right[i]) // 2
                dev = abs(recovered_mid - base_mid[i])
                if dev > max_dev:
                    max_dev = dev
            self.assertLessEqual(max_dev, 2, f"Spatial {sp} corrupted the mid-channel decay envelope (max dev={max_dev})")

    def test_spatial_zero_is_exact_phantom_mono_across_all_styles(self):
        """For spatial == 0.0, L[i] MUST EQUAL R[i] with zero tolerance (100% phantom mono)."""
        styles = ["marimba", "glass", "fm", "bit", "bubble"]
        for st in styles:
            for rev in [0.0, 0.25, 0.75]:
                samples = synth_tone(NOTES["E6"], 80.0, style=st, spatial=0.0, reverb=rev, channels=2)
                left = samples[0::2]
                right = samples[1::2]
                self.assertEqual(left, right, f"Style '{st}' produced L != R when spatial == 0.0 (reverb={rev})")

    def test_spatial_zero_pop_is_exact_phantom_mono(self):
        """synth_pop with spatial == 0.0 must be 100% phantom mono."""
        samples = synth_pop(1200.0, 350.0, 60.0, spatial=0.0, reverb=0.3, channels=2)
        left = samples[0::2]
        right = samples[1::2]
        self.assertEqual(left, right, "synth_pop produced L != R when spatial == 0.0")

    def test_spatial_positive_stereo_dispersion_and_haas(self):
        """When spatial > 0.0, L and R differ as expected from Haas / Mid-Side processing."""
        dur = 100.0
        rev = 0.2

        for sp in [0.1, 0.3, 0.5, 0.7, 1.0]:
            samples = synth_tone(NOTES["C6"], dur, spatial=sp, reverb=rev, channels=2)
            left = samples[0::2]
            right = samples[1::2]
            # Verify L and R differ
            self.assertNotEqual(left, right, f"Left and Right are identical at spatial={sp}")

            diff_frames = sum(1 for l, r in zip(left, right) if l != r)
            diff_ratio = diff_frames / len(left)
            self.assertGreater(
                diff_ratio, 0.70,
                f"Expected >70% divergent frames at spatial={sp}, got {diff_ratio:.2%}"
            )

            # Side energy must be positive
            side_energy = sum((l - r) ** 2 for l, r in zip(left, right))
            self.assertGreater(side_energy, 0, f"Side energy must be > 0 at spatial={sp}")

    def test_reverb_variation_does_not_affect_channel_balance(self):
        """Changing reverb must NOT alter the channel balance."""
        # 1. At spatial=0.0: balance is strictly 1.0 (0.00 dB tilt) across ALL reverb values
        for rev in [0.0, 0.1, 0.3, 0.6, 0.9]:
            samples = synth_tone(NOTES["G5"], 70.0, spatial=0.0, reverb=rev, channels=2)
            left = samples[0::2]
            right = samples[1::2]
            e_left = sum(x * x for x in left)
            e_right = sum(x * x for x in right)
            self.assertEqual(e_left, e_right, f"Reverb {rev} altered channel balance at spatial=0.0")

        # 2. At spatial > 0.0: changing reverb must not shift the stereo balance
        # Verify across multiple notes that changing reverb from 0.0 to 0.8 alters the L/R ratio by < 0.5 dB
        for note in ["G5", "C6", "A6"]:
            base_ratio_db = None
            for rev in [0.0, 0.2, 0.5, 0.8]:
                samples = synth_tone(NOTES[note], 120.0, spatial=0.6, reverb=rev, channels=2)
                left = samples[0::2]
                right = samples[1::2]
                rms_left = math.sqrt(sum(x * x for x in left) / len(left))
                rms_right = math.sqrt(sum(x * x for x in right) / len(right))
                ratio_db = 20.0 * math.log10(rms_left / max(1e-6, rms_right))

                if base_ratio_db is None:
                    base_ratio_db = ratio_db
                else:
                    shift = abs(ratio_db - base_ratio_db)
                    self.assertLess(
                        shift, 0.5,
                        f"Reverb {rev} caused balance drift of {shift:.3f} dB for note {note}"
                    )


class TestAudioFormatCompliance(unittest.TestCase):
    """Empirical verification of 2-channel stereo 48kHz 16-bit PCM WAV compliance."""

    def test_wav_file_binary_structure(self):
        """Check raw WAV headers, chunk sizes, and PCM parameters."""
        temp_dir = tempfile.mkdtemp()
        try:
            samples = synth_tone(NOTES["C6"], 50.0, channels=2)
            save_wav(temp_dir, "test_format.wav", samples, channels=2)
            wav_path = os.path.join(temp_dir, "test_format.wav")

            # Validate with wave module
            with wave.open(wav_path, "rb") as w:
                self.assertEqual(w.getnchannels(), 2, "Must be 2 channels")
                self.assertEqual(w.getsampwidth(), 2, "Must be 16-bit (2 bytes)")
                self.assertEqual(w.getframerate(), 48000, "Must be 48000 Hz")
                self.assertEqual(w.getcomptype(), "NONE", "Must be uncompressed PCM")
                self.assertEqual(w.getnframes(), len(samples) // 2)

            # Direct byte-level header check
            with open(wav_path, "rb") as f:
                header = f.read(44)
                riff = header[0:4]
                wave_sig = header[8:12]
                fmt_sig = header[12:16]
                audio_format = struct.unpack("<H", header[20:22])[0]
                num_channels = struct.unpack("<H", header[22:24])[0]
                sample_rate = struct.unpack("<I", header[24:28])[0]
                byte_rate = struct.unpack("<I", header[28:32])[0]
                block_align = struct.unpack("<H", header[32:34])[0]
                bits_per_sample = struct.unpack("<H", header[34:36])[0]

                self.assertEqual(riff, b"RIFF")
                self.assertEqual(wave_sig, b"WAVE")
                self.assertEqual(fmt_sig, b"fmt ")
                self.assertEqual(audio_format, 1, "AudioFormat 1 is PCM")
                self.assertEqual(num_channels, 2)
                self.assertEqual(sample_rate, 48000)
                self.assertEqual(bits_per_sample, 16)
                self.assertEqual(block_align, 4, "Block align must be channels * bits/8 = 4")
                self.assertEqual(byte_rate, 48000 * 4, "Byte rate must be sample_rate * block_align = 192000")
        finally:
            shutil.rmtree(temp_dir)

    def test_full_pack_all_23_sounds_valid_stereo(self):
        """Generate a full pack and inspect all 23 generated WAV files."""
        temp_dir = tempfile.mkdtemp()
        try:
            generate_pack(temp_dir, style="glass", spatial=0.7, reverb=0.25, channels=2)
            wav_files = [f for f in os.listdir(temp_dir) if f.endswith(".wav")]
            self.assertGreaterEqual(len(wav_files), 23, "Expected at least 23 sound files in pack")

            for wf in wav_files:
                fpath = os.path.join(temp_dir, wf)
                with wave.open(fpath, "rb") as w:
                    self.assertEqual(w.getnchannels(), 2, f"{wf} is not 2 channels")
                    self.assertEqual(w.getframerate(), 48000, f"{wf} is not 48000 Hz")
                    self.assertEqual(w.getsampwidth(), 2, f"{wf} is not 16-bit PCM")
                    self.assertGreater(w.getnframes(), 0, f"{wf} has 0 frames")
        finally:
            shutil.rmtree(temp_dir)


class TestAdversarialStressAndEdgeCases(unittest.TestCase):
    """Stress tests and boundary condition mining."""

    def test_dsp_empty_input(self):
        """apply_audio_dsp must handle empty input without crashing."""
        out = apply_audio_dsp([], spatial=0.5, reverb=0.2, channels=2)
        self.assertEqual(out, [])

    def test_make_silence_zero_duration(self):
        """make_silence with 0 duration must return empty list."""
        out = make_silence(0, channels=2)
        self.assertEqual(out, [])

    def test_extreme_gain_clipping_bounds(self):
        """High gain or heavy warmth must never produce int16 overflow (> 32767 or < -32768)."""
        samples = synth_tone(NOTES["C6"], 100.0, gain=2.5, warmth=1.0, spatial=1.0, reverb=0.5, channels=2)
        self.assertTrue(all(isinstance(x, int) for x in samples))
        self.assertTrue(all(-32768 <= x <= 32767 for x in samples))

    def test_extreme_spatial_clamping(self):
        """Extreme spatial values (e.g. 2.0 or -0.5) must not crash and stay bounded."""
        samples_high = synth_tone(NOTES["E6"], 60.0, spatial=2.0, reverb=0.2, channels=2)
        self.assertTrue(all(-32768 <= x <= 32767 for x in samples_high))

        samples_low = synth_tone(NOTES["E6"], 60.0, spatial=-0.5, reverb=0.2, channels=2)
        self.assertTrue(all(-32768 <= x <= 32767 for x in samples_low))

    def test_extreme_pitch_shifts(self):
        """Pitch shifts at limits (-12 and +12 semitones) must synthesize cleanly."""
        s_low = synth_tone(NOTES["C5"], 50.0, pitch=-12.0, channels=2)
        s_high = synth_tone(NOTES["G7"], 50.0, pitch=12.0, channels=2)
        self.assertGreater(len(s_low), 0)
        self.assertGreater(len(s_high), 0)
        self.assertTrue(all(-32768 <= x <= 32767 for x in s_low))
        self.assertTrue(all(-32768 <= x <= 32767 for x in s_high))

    def test_rapid_preview_generation_burst(self):
        """Rapid continuous calls to preview CLI argument handling must succeed."""
        for i in range(5):
            proc = subprocess.run(
                [
                    "python3",
                    str(PROJECT_ROOT / "sound_engine.py"),
                    "preview",
                    "--spatial", f"{0.1 * i:.1f}",
                    "--reverb", f"{0.15 * i:.2f}",
                ],
                capture_output=True,
                text=True,
                cwd=str(PROJECT_ROOT),
            )
            self.assertEqual(proc.returncode, 0, f"Burst {i} failed: {proc.stderr}")


if __name__ == "__main__":
    unittest.main()
