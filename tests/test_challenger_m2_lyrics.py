#!/usr/bin/env python3
"""Adversarial stress-testing suite for Panacea lyrics engine (scripts/lyrics.py).

Written by Challenger Subagent (teamwork_preview_challenger) for Milestone M2.
Tests extreme edge cases, adversarial inputs, fuzz-like malformations,
Unicode handling, timestamp boundary conditions, and CLI contract safety.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

PROJECT_ROOT = Path("/home/nova/.config/panacea")
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.lyrics import (
    clean_track_title,
    compute_cache_key,
    fetch_lyrics,
    load_from_cache,
    parse_lrc,
    save_to_cache,
)

CLI_SCRIPT = str(PROJECT_ROOT / "scripts" / "lyrics.py")


class TestUnusualTimestamps(unittest.TestCase):
    """Stress testing unusual, boundary, and non-standard timestamps."""

    def test_01_max_minutes_centiseconds_99_59_99(self):
        """Timestamp [99:59.99] -> 5,999,990 ms (5999.99 s)."""
        lrc = "[99:59.99] End of century"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 5999990)
        self.assertEqual(res[0]["time_sec"], 5999.99)
        self.assertEqual(res[0]["text"], "End of century")

    def test_02_zero_timestamp_00_00_00(self):
        """Timestamp [00:00.00] -> 0 ms (0.0 s)."""
        lrc = "[00:00.00] Song intro start"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 0)
        self.assertEqual(res[0]["time_sec"], 0.0)
        self.assertEqual(res[0]["text"], "Song intro start")

    def test_03_no_fraction_01_23(self):
        """Timestamp [01:23] -> 83,000 ms (83.0 s)."""
        lrc = "[01:23] Integer seconds only"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 83000)
        self.assertEqual(res[0]["time_sec"], 83.0)
        self.assertEqual(res[0]["text"], "Integer seconds only")

    def test_04_single_digit_fraction_02_34_5(self):
        """Timestamp [02:34.5] -> 154,500 ms (154.5 s)."""
        lrc = "[02:34.5] Single digit fraction (tenth of sec)"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 154500)
        self.assertEqual(res[0]["time_sec"], 154.5)
        self.assertEqual(res[0]["text"], "Single digit fraction (tenth of sec)")

    def test_05_three_digit_milliseconds_03_45_678(self):
        """Timestamp [03:45.678] -> 225,678 ms (225.678 s)."""
        lrc = "[03:45.678] Millisecond precision fraction"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 225678)
        self.assertEqual(res[0]["time_sec"], 225.678)
        self.assertEqual(res[0]["text"], "Millisecond precision fraction")

    def test_06_single_digit_minutes(self):
        """Timestamp [1:05.20] with single digit minute -> 65,200 ms."""
        lrc = "[1:05.20] Single digit minute"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 65200)
        self.assertEqual(res[0]["time_sec"], 65.2)

    def test_07_three_digit_extended_minutes(self):
        """Timestamp [120:00.00] (2 hour mix) -> 7,200,000 ms."""
        lrc = "[120:00.00] Two hours into DJ set"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 7200000)
        self.assertEqual(res[0]["time_sec"], 7200.0)


class TestMultiTagsOnSingleLine(unittest.TestCase):
    """Stress testing multiple LRC tags on a single line."""

    def test_01_two_tags_ordered(self):
        """Parse [00:10.00][00:20.00] Chorus line."""
        lrc = "[00:10.00][00:20.00] Chorus line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["time_ms"], 10000)
        self.assertEqual(res[1]["time_ms"], 20000)
        self.assertEqual(res[0]["text"], "Chorus line")
        self.assertEqual(res[1]["text"], "Chorus line")

    def test_02_three_tags_ordered(self):
        """Parse [00:05.00][00:15.00][00:25.00] Repeated hook."""
        lrc = "[00:05.00][00:15.00][00:25.00] Repeated hook"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 3)
        self.assertEqual([r["time_ms"] for r in res], [5000, 15000, 25000])
        self.assertEqual(res[2]["text"], "Repeated hook")

    def test_03_five_tags_stress(self):
        """Parse line with five consecutive tags."""
        lrc = "[00:01.00][00:02.00][00:03.00][00:04.00][00:05.00] Staccato beat"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 5)
        self.assertEqual([r["time_ms"] for r in res], [1000, 2000, 3000, 4000, 5000])
        for r in res:
            self.assertEqual(r["text"], "Staccato beat")

    def test_04_out_of_order_tags_on_same_line(self):
        """Tags appearing out of order on single line are sorted chronologically."""
        lrc = "[00:30.00][00:10.00][00:20.00] Permuted tags"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 3)
        self.assertEqual([r["time_ms"] for r in res], [10000, 20000, 30000])

    def test_05_tags_with_spaces_between(self):
        """Multiple tags separated by whitespace."""
        lrc = "[00:10.00]   [00:20.00] Spaced tags"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual([r["time_ms"] for r in res], [10000, 20000])
        self.assertEqual(res[0]["text"], "Spaced tags")
        self.assertEqual(res[1]["text"], "Spaced tags")

    def test_06_multiple_tags_empty_text(self):
        """Multiple tags with no lyric text at end of line."""
        lrc = "[00:10.00][00:20.00]"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["text"], "")
        self.assertEqual(res[1]["text"], "")


class TestOffsets(unittest.TestCase):
    """Stress testing global offset tags [offset:+500], [offset:-2000]."""

    def test_01_positive_offset_500(self):
        """Positive offset [offset:+500] shifts timestamps forward by 500 ms."""
        lrc = "[offset:+500]\n[00:10.00] Forward shifted line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 10500)
        self.assertEqual(res[0]["time_sec"], 10.5)

    def test_02_negative_offset_2000(self):
        """Negative offset [offset:-2000] shifts timestamps backward by 2000 ms."""
        lrc = "[offset:-2000]\n[00:05.00] Backward shifted line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 3000)
        self.assertEqual(res[0]["time_sec"], 3.0)

    def test_03_negative_offset_clamps_at_zero(self):
        """Negative offset greater than timestamp clamps time_ms to 0."""
        lrc = "[offset:-2000]\n[00:01.00] Clamped line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 0)
        self.assertEqual(res[0]["time_sec"], 0.0)

    def test_04_offset_with_internal_whitespace(self):
        """Offset tag with internal whitespace [offset:   +500   ]."""
        lrc = "[offset:   +500   ]\n[00:02.00] Whitespace offset line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 2500)

    def test_05_offset_at_bottom_of_file(self):
        """Offset tag placed at the end of the file applies globally."""
        lrc = "[00:10.00] Line one\n[00:20.00] Line two\n[offset:+1000]"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["time_ms"], 11000)
        self.assertEqual(res[1]["time_ms"], 21000)

    def test_06_offset_line_not_in_lyrics(self):
        """Offset tag line itself is stripped and never emitted as a lyric line."""
        lrc = "[offset:500]\n[00:01.00] Real line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Real line")

    def test_07_invalid_offset_ignored_cleanly(self):
        """Malformed offset [offset:invalid] is skipped without crashing."""
        lrc = "[offset:invalid]\n[00:10.00] Real line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 10000)


class TestUnicodeAndBlankLines(unittest.TestCase):
    """Stress testing blank strings, empty lines, and non-ASCII Unicode."""

    def test_01_empty_inputs(self):
        """Various empty and whitespace-only inputs return empty list."""
        self.assertEqual(parse_lrc(""), [])
        self.assertEqual(parse_lrc(None), [])
        self.assertEqual(parse_lrc("   \n\t  \r\n  "), [])

    def test_02_interspersed_blank_lines(self):
        """Multiple consecutive empty lines between lyric lines are ignored."""
        lrc = "\n\n[00:01.00] First\n\n\n\n[00:02.00] Second\n\n"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["text"], "First")
        self.assertEqual(res[1]["text"], "Second")

    def test_03_emojis_in_lyrics(self):
        """Preserve emojis, symbols, and musical notation."""
        lrc = "[00:05.00] 🎶 High energy party! 🔥🎉 🚀"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "🎶 High energy party! 🔥🎉 🚀")

    def test_04_cjk_characters(self):
        """Japanese, Chinese, and Korean text preservation."""
        lrc = (
            "[00:01.00] 乾杯！世界平和のために 🌸\n"
            "[00:02.00] 夜に駆ける (YOASOBI)\n"
            "[00:03.00] 一闪一闪亮晶晶\n"
            "[00:04.00] 안녕하세요 세계"
        )
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 4)
        self.assertEqual(res[0]["text"], "乾杯！世界平和のために 🌸")
        self.assertEqual(res[1]["text"], "夜に駆ける (YOASOBI)")
        self.assertEqual(res[2]["text"], "一闪一闪亮晶晶")
        self.assertEqual(res[3]["text"], "안녕하세요 세계")

    def test_05_accents_and_diacritics(self):
        """Spanish, French, German, and Portuguese accented characters."""
        lrc = (
            "[00:01.00] Canción española: ¡Olé! Señor, corazón y pingüino\n"
            "[00:02.00] Ça va très bien, naïve fiancée à Noël\n"
            "[00:03.00] Über den Wolken: Äpfel, Öl und Süßigkeiten\n"
            "[00:04.00] Não há problema, coração são"
        )
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 4)
        self.assertEqual(res[0]["text"], "Canción española: ¡Olé! Señor, corazón y pingüino")
        self.assertEqual(res[1]["text"], "Ça va très bien, naïve fiancée à Noël")
        self.assertEqual(res[2]["text"], "Über den Wolken: Äpfel, Öl und Süßigkeiten")
        self.assertEqual(res[3]["text"], "Não há problema, coração são")

    def test_06_cyrillic_and_rtl(self):
        """Russian Cyrillic, Hebrew, and Arabic text preservation."""
        lrc = (
            "[00:01.00] Привет мир\n"
            "[00:02.00] שלום עולם\n"
            "[00:03.00] مرحباً بالعالم"
        )
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 3)
        self.assertEqual(res[0]["text"], "Привет мир")
        self.assertEqual(res[1]["text"], "שלום עולם")
        self.assertEqual(res[2]["text"], "مرحباً بالعالم")

    def test_07_timestamp_with_whitespace_lyric(self):
        """Timestamp followed only by spaces results in empty text."""
        lrc = "[00:10.00]    "
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "")


class TestMalformedLrcTags(unittest.TestCase):
    """Stress testing malformed tags, brackets, and corrupted files."""

    def test_01_unclosed_brackets(self):
        """Lines with unclosed brackets are ignored safely."""
        lrc = "[01:23.45 unclosed bracket without end\n[00:10.00] Valid line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Valid line")

    def test_02_unopened_brackets(self):
        """Lines with unopened brackets are ignored safely."""
        lrc = "unopened bracket 01:23.45]\n[00:10.00] Valid line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Valid line")

    def test_03_non_numeric_timestamps(self):
        """Non-numeric timestamps like [aa:bb.cc] are skipped."""
        lrc = "[aa:bb.cc] Fake timestamp\n[00:10.00] Valid line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Valid line")

    def test_04_four_digit_minute_skipped(self):
        """Four-digit minutes [9999:00.00] are skipped."""
        lrc = "[9999:00.00] Way too long\n[00:10.00] Valid line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Valid line")

    def test_05_missing_components(self):
        """Malformed missing minutes or seconds."""
        lrc = "[:23.45] Missing min\n[01:.45] Missing sec\n[] Empty\n[:] Colon\n[00:10.00] Valid"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Valid")

    def test_06_performance_annotations_ignored(self):
        """Standalone performance tags like [Intro], [Chorus], [Guitar Solo] are ignored."""
        lrc = "[Intro]\n[Verse 1]\n[Chorus]\n[Guitar Solo]\n[00:10.00] Real lyrics"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Real lyrics")

    def test_07_metadata_tags_stripped(self):
        """Standard ID3 / LRC metadata tags are stripped cleanly."""
        lrc = (
            "[ar:Artist Name]\n"
            "[ti:Track Title]\n"
            "[al:Album Name]\n"
            "[by:Creator]\n"
            "[length:03:45]\n"
            "[00:05.00] Real lyrics line"
        )
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "Real lyrics line")

    def test_08_brackets_inside_lyric_text_preserved(self):
        """Brackets appearing inside the actual lyric text are preserved."""
        lrc = "[00:10.00] [Chorus] Singing in the rain [Outro]"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "[Chorus] Singing in the rain [Outro]")


class TestThroughputAndStress(unittest.TestCase):
    """Performance and high-volume stress testing."""

    def test_01_throughput_5000_lines(self):
        """Parser must process 5,000 lines in < 100ms."""
        lines = [f"[{i//60:02d}:{i%60:02d}.{i%100:02d}] Lyric line {i}" for i in range(5000)]
        big_lrc = "\n".join(lines)
        start = time.perf_counter()
        res = parse_lrc(big_lrc)
        elapsed = time.perf_counter() - start
        self.assertEqual(len(res), 5000)
        self.assertLess(elapsed, 0.10, f"5000 lines took {elapsed*1000:.2f}ms (>100ms)")


class TestCliAdversarial(unittest.TestCase):
    """CLI robustness under adversarial inputs."""

    def test_01_missing_required_title(self):
        """Missing title argument returns valid error JSON without crash."""
        cmd = [sys.executable, CLI_SCRIPT, "--artist", "Coldplay"]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
        self.assertEqual(res.returncode, 0)
        lines = res.stdout.splitlines()
        self.assertEqual(len(lines), 1, "Must emit exactly 1 line of JSON for SplitParser")
        data = json.loads(lines[0])
        self.assertEqual(data["status"], "error")
        self.assertIn("título", data["message"])

    def test_02_unicode_arguments(self):
        """Unicode track title and artist handled cleanly via CLI."""
        with tempfile.TemporaryDirectory() as tmpdir:
            payload = {
                "status": "ok",
                "track": "アイドル",
                "artist": "YOASOBI",
                "album": "THE BOOK 3",
                "duration": 213.0,
                "instrumental": False,
                "synced": True,
                "has_plain": True,
                "lines": [{"time_ms": 1000, "time_sec": 1.0, "text": "誰もが目を奪われていく"}],
                "plain_lyrics": "誰もが目を奪われていく",
                "raw_lrc": "[00:01.00] 誰もが目を奪われていく",
                "cached": False,
                "cached_at": int(time.time()),
                "source": "lrclib",
                "message": None,
            }
            save_to_cache(tmpdir, "YOASOBI", "アイドル", payload)

            cmd = [
                sys.executable,
                CLI_SCRIPT,
                "--artist", "YOASOBI",
                "--title", "アイドル",
                "--cache-dir", tmpdir,
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            self.assertEqual(res.returncode, 0)
            lines = res.stdout.splitlines()
            self.assertEqual(len(lines), 1)
            data = json.loads(lines[0])
            self.assertEqual(data["track"], "アイドル")
            self.assertEqual(data["artist"], "YOASOBI")
            self.assertEqual(data["lines"][0]["text"], "誰もが目を奪われていく")




class TestCleanTrackTitleAdversarial(unittest.TestCase):
    """Stress testing clean_track_title with edge cases and metadata noise."""

    def test_01_remaster_dash_and_parens(self):
        self.assertEqual(clean_track_title("Song - 2021 Remaster"), "Song")
        self.assertEqual(clean_track_title("Song (2011 Remaster)"), "Song")
        self.assertEqual(clean_track_title("Song (Remastered Version)"), "Song")
        self.assertEqual(clean_track_title("Song (Remaster)"), "Song")

    def test_02_live_and_features(self):
        self.assertEqual(clean_track_title("Song - Live in Tokyo"), "Song")
        self.assertEqual(clean_track_title("Song (Live at Wembley)"), "Song")
        self.assertEqual(clean_track_title("Song feat. Guest Artist"), "Song")
        self.assertEqual(clean_track_title("Song (ft. Guest Artist)"), "Song")

    def test_03_brackets_and_edits(self):
        self.assertEqual(clean_track_title("Song [Official Music Video 4K]"), "Song")
        self.assertEqual(clean_track_title("Song - Radio Edit"), "Song")
        self.assertEqual(clean_track_title("Song - Deluxe Edition"), "Song")

    def test_04_unicode_clean(self):
        self.assertEqual(clean_track_title("夜に駆ける (2020 Remaster)"), "夜に駆ける")
        self.assertEqual(clean_track_title("Canción (feat. Amigo)"), "Canción")

    def test_05_fallback_when_title_is_only_tag(self):
        """When title is solely a tag (e.g. '(Remastered)'), fallback retains original."""
        self.assertEqual(clean_track_title("(Remastered)"), "(Remastered)")
        self.assertEqual(clean_track_title("[Official Video]"), "[Official Video]")

    def test_06_empty_or_none(self):
        self.assertEqual(clean_track_title(""), "")
        self.assertEqual(clean_track_title(None), "")
        self.assertEqual(clean_track_title("   "), "")


class TestCacheKeyAdversarial(unittest.TestCase):
    """Stress testing cache key generation against traversal, collisions, and Unicode."""

    def test_01_path_traversal_prevention(self):
        """Ensure path traversal characters are eliminated from the filename."""
        key = compute_cache_key("../../etc", "passwd")
        self.assertNotIn("/", key)
        self.assertNotIn("\\", key)
        self.assertNotIn("..", key)
        self.assertTrue(key.endswith(".json"))

    def test_02_null_bytes_and_illegal_chars(self):
        """Null bytes and special punctuation are converted to safe underscores."""
        key = compute_cache_key("art\x00ist", "tit/le:*?\"<>|")
        self.assertNotIn("\x00", key)
        self.assertNotIn("/", key)
        self.assertTrue(all(c.isalnum() or c in ("_", ".") for c in key))

    def test_03_empty_artist_and_title(self):
        """Completely empty input produces safe 'track_<digest>.json'."""
        key = compute_cache_key("", "")
        self.assertTrue(key.startswith("track_"))
        self.assertTrue(key.endswith(".json"))

    def test_04_cjk_only_keys_differentiate_by_hash(self):
        """Non-ASCII tracks produce distinct filenames via SHA-256 digest."""
        k1 = compute_cache_key("初音ミク", "千本桜")
        k2 = compute_cache_key("初音ミク", "メルト")
        self.assertNotEqual(k1, k2)
        self.assertTrue(k1.startswith("track_"))
        self.assertTrue(k2.startswith("track_"))

    def test_05_case_insensitivity_and_whitespace(self):
        """Cache keys are case-insensitive and ignore leading/trailing whitespace."""
        k1 = compute_cache_key("  ColdPlay  ", "  YELLOW  ")
        k2 = compute_cache_key("coldplay", "yellow")
        self.assertEqual(k1, k2)


if __name__ == '__main__':
    unittest.main()
