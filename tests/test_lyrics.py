#!/usr/bin/env python3
"""Comprehensive test suite for Panacea lyrics engine (scripts/lyrics.py).

Covers:
- LRC parser (standard centiseconds, milliseconds, single-digit, no fraction, multi-tag, offsets)
- Metadata tag stripping and title sanitization
- Cache key generation, collision resistance, atomic write/load, latency benchmarks
- Multi-tier LRCLIB fetching strategy (exact, cleaned title, search fallback, plain, instrumental, 404)
- Error handling, network failures, cache bypass with --force
- CLI invocation via flags, positional arguments, and atomic single-line JSON emission
"""

import io
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import MagicMock, patch

# Ensure project root is in sys.path
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


def make_mock_response(status=200, data=None):
    """Helper creating a mock response context manager for urllib.request.urlopen."""
    mock = MagicMock()
    mock.status = status
    if data is not None:
        if isinstance(data, (dict, list)):
            content = json.dumps(data).encode("utf-8")
        elif isinstance(data, str):
            content = data.encode("utf-8")
        else:
            content = data
        mock.read.return_value = content
    else:
        mock.read.return_value = b""
    mock.__enter__.return_value = mock
    return mock


def make_mock_404():
    """Helper creating a mock HTTPError(404) without Python 3.14 ResourceWarning."""
    fp = io.BytesIO(b'{"statusCode":404}')
    err = urllib.error.HTTPError("https://lrclib.net", 404, "Not Found", {}, fp)
    err.close()
    return err


class TestLrcParser(unittest.TestCase):
    """Unit tests for the LRC timestamp parser."""

    def test_01_parse_standard_lrc(self):
        """Parse standard centisecond timestamps [mm:ss.xx]."""
        lrc = "[00:15.50] Hello world\n[01:02.12] Second line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["time_ms"], 15500)
        self.assertEqual(res[0]["time_sec"], 15.5)
        self.assertEqual(res[0]["text"], "Hello world")
        self.assertEqual(res[1]["time_ms"], 62120)
        self.assertEqual(res[1]["time_sec"], 62.12)
        self.assertEqual(res[1]["text"], "Second line")

    def test_02_parse_millisecond_fractions(self):
        """Parse 3-digit millisecond timestamps [mm:ss.xxx]."""
        lrc = "[01:02.125] High precision timestamp"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 62125)
        self.assertEqual(res[0]["time_sec"], 62.125)
        self.assertEqual(res[0]["text"], "High precision timestamp")

    def test_03_parse_single_digit_fraction(self):
        """Parse 1-digit decimal timestamps [mm:ss.x]."""
        lrc = "[00:10.5] Single digit fraction"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 10500)
        self.assertEqual(res[0]["time_sec"], 10.5)

    def test_04_parse_no_fraction(self):
        """Parse timestamps without decimal fraction [mm:ss]."""
        lrc = "[02:30] Integer seconds only"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 150000)
        self.assertEqual(res[0]["time_sec"], 150.0)

    def test_05_multi_tag_single_line(self):
        """Parse lines with multiple timestamps into discrete ordered entries."""
        lrc = "[00:10.00][00:20.00] Repeated refrain"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["time_ms"], 10000)
        self.assertEqual(res[0]["time_sec"], 10.0)
        self.assertEqual(res[0]["text"], "Repeated refrain")
        self.assertEqual(res[1]["time_ms"], 20000)
        self.assertEqual(res[1]["time_sec"], 20.0)
        self.assertEqual(res[1]["text"], "Repeated refrain")

    def test_06_triple_tag_single_line(self):
        """Parse lines with three timestamps."""
        lrc = "[00:05.00][00:15.00][00:25.00] Hook line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 3)
        self.assertEqual([r["time_ms"] for r in res], [5000, 15000, 25000])
        self.assertEqual(res[2]["text"], "Hook line")

    def test_07_global_offset_positive(self):
        """Positive [offset:X] shifts all timestamps later."""
        lrc = "[offset:500]\n[00:10.00] Offset line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["time_ms"], 10500)
        self.assertEqual(res[0]["time_sec"], 10.5)

    def test_08_global_offset_negative(self):
        """Negative [offset:-X] shifts timestamps earlier, clamped at 0."""
        lrc = "[offset:-1000]\n[00:00.50] Early line\n[00:05.00] Later line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["time_ms"], 0)
        self.assertEqual(res[0]["time_sec"], 0.0)
        self.assertEqual(res[1]["time_ms"], 4000)
        self.assertEqual(res[1]["time_sec"], 4.0)

    def test_09_discard_metadata_tags(self):
        """ID3/LRC metadata tags like [ar:], [ti:], [length:] are ignored."""
        lrc = "[ar:Coldplay]\n[ti:Yellow]\n[al:Parachutes]\n[length:04:27]\n[00:10.00] First real line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["text"], "First real line")

    def test_10_empty_or_none_lrc(self):
        """Empty or None input safely returns empty list."""
        self.assertEqual(parse_lrc(""), [])
        self.assertEqual(parse_lrc(None), [])
        self.assertEqual(parse_lrc("   \n\n  "), [])

    def test_11_out_of_order_timestamps(self):
        """Lines appearing out of temporal order are sorted chronologically."""
        lrc = "[00:30.00] Line two\n[00:10.00] Line one\n[00:50.00] Line three"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 3)
        self.assertEqual([r["time_sec"] for r in res], [10.0, 30.0, 50.0])
        self.assertEqual([r["text"] for r in res], ["Line one", "Line two", "Line three"])

    def test_12_extended_minutes(self):
        """Support track times longer than 99 minutes."""
        lrc = "[105:20.50] Long track line"
        res = parse_lrc(lrc)
        self.assertEqual(len(res), 1)
        expected_ms = (105 * 60 + 20) * 1000 + 500
        self.assertEqual(res[0]["time_ms"], expected_ms)


class TestCleanTrackTitle(unittest.TestCase):
    """Unit tests for cleaning noisy track titles."""

    def test_01_clean_remastered_dash(self):
        self.assertEqual(clean_track_title("Yellow - Remastered 2011"), "Yellow")
        self.assertEqual(clean_track_title("In The End - 2020 Remaster"), "In The End")
        self.assertEqual(clean_track_title("Comfortably Numb - Remastered"), "Comfortably Numb")

    def test_02_clean_remastered_parens(self):
        self.assertEqual(clean_track_title("Yellow (2011 Remaster)"), "Yellow")
        self.assertEqual(clean_track_title("Song (Remastered Version)"), "Song")
        self.assertEqual(clean_track_title("Song (Remaster)"), "Song")

    def test_03_clean_live_versions(self):
        self.assertEqual(clean_track_title("Numb - Live in Texas"), "Numb")
        self.assertEqual(clean_track_title("Song (Live at Wembley)"), "Song")
        self.assertEqual(clean_track_title("Song - Live"), "Song")

    def test_04_clean_features(self):
        self.assertEqual(clean_track_title("Starboy (feat. Daft Punk)"), "Starboy")
        self.assertEqual(clean_track_title("Starboy (ft. Daft Punk)"), "Starboy")
        self.assertEqual(clean_track_title("Starboy feat. Daft Punk"), "Starboy")
        self.assertEqual(clean_track_title("Starboy ft. Daft Punk"), "Starboy")

    def test_05_clean_bracket_metadata(self):
        self.assertEqual(clean_track_title("Track [Official Video]"), "Track")
        self.assertEqual(clean_track_title("Track [Official Music Video]"), "Track")
        self.assertEqual(clean_track_title("Song [HD]"), "Song")
        self.assertEqual(clean_track_title("Song [Lyric Video]"), "Song")

    def test_06_clean_deluxe_bonus_radio(self):
        self.assertEqual(clean_track_title("Song - Radio Edit"), "Song")
        self.assertEqual(clean_track_title("Song - Single Version"), "Song")
        self.assertEqual(clean_track_title("Song - Deluxe Edition"), "Song")
        self.assertEqual(clean_track_title("Song - Bonus Track"), "Song")

    def test_07_preserve_clean_title(self):
        self.assertEqual(clean_track_title("Yellow"), "Yellow")
        self.assertEqual(clean_track_title("Hotel California"), "Hotel California")
        self.assertEqual(clean_track_title("Clair de Lune"), "Clair de Lune")

    def test_08_empty_or_none_title(self):
        self.assertEqual(clean_track_title(""), "")
        self.assertEqual(clean_track_title(None), "")


class TestCacheEngine(unittest.TestCase):
    """Unit tests for the local cache storage in ~/.cache/panacea/lyrics/."""

    def test_01_cache_key_deterministic(self):
        k1 = compute_cache_key("Coldplay", "Yellow")
        k2 = compute_cache_key(" coldplay ", "YELLOW ")
        self.assertEqual(k1, k2)
        self.assertTrue(k1.endswith(".json"))
        self.assertTrue(k1.startswith("coldplay_yellow_"))

    def test_02_cache_key_special_characters(self):
        k = compute_cache_key("AC/DC", "T.N.T. (Live!)")
        self.assertTrue(k.endswith(".json"))
        # Ensure only alphanumeric and underscores in the slug
        slug_part = k.rsplit("_", 1)[0]
        self.assertTrue(all(c.isalnum() or c == '_' for c in slug_part))

    def test_03_cache_save_and_load(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            payload = {
                "status": "ok",
                "track": "Yellow",
                "artist": "Coldplay",
                "album": "Parachutes",
                "duration": 267.0,
                "instrumental": False,
                "synced": True,
                "has_plain": True,
                "lines": [{"time_ms": 1000, "time_sec": 1.0, "text": "Hi"}],
                "plain_lyrics": "Hi",
                "raw_lrc": "[00:01.00] Hi",
                "cached": False,
                "cached_at": 1728000000,
                "source": "lrclib",
                "message": None,
            }
            save_to_cache(tmpdir, "Coldplay", "Yellow", payload)
            loaded = load_from_cache(tmpdir, "Coldplay", "Yellow")
            self.assertIsNotNone(loaded)
            self.assertEqual(loaded["status"], "ok")
            self.assertEqual(loaded["track"], "Yellow")
            self.assertTrue(loaded["cached"])

    def test_04_cache_hit_latency(self):
        """Cache hit must load in < 5ms."""
        with tempfile.TemporaryDirectory() as tmpdir:
            payload = {
                "status": "ok",
                "track": "SpeedTest",
                "artist": "Benchmark",
                "lines": [{"time_ms": i * 1000, "time_sec": float(i), "text": f"Line {i}"} for i in range(100)],
                "cached": False,
            }
            save_to_cache(tmpdir, "Benchmark", "SpeedTest", payload)
            start = time.perf_counter()
            loaded = load_from_cache(tmpdir, "Benchmark", "SpeedTest")
            elapsed = time.perf_counter() - start
            self.assertIsNotNone(loaded)
            self.assertLess(elapsed, 0.005, f"Cache read took {elapsed*1000:.2f}ms (>5ms threshold)")

    def test_05_cache_corrupt_file_recovery(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            key = compute_cache_key("Corrupt", "Track")
            filepath = os.path.join(tmpdir, key)
            with open(filepath, "w") as f:
                f.write("{ invalid json corrupted ...")
            loaded = load_from_cache(tmpdir, "Corrupt", "Track")
            self.assertIsNone(loaded)


class TestFetchLyricsStrategy(unittest.TestCase):
    """Unit tests for the multi-tier LRCLIB fetching strategy using mocks."""

    @patch("urllib.request.urlopen")
    def test_01_exact_match_stage1(self, mock_urlopen):
        """Stage 1: Exact match with synced lyrics."""
        mock_resp = make_mock_response(
            status=200,
            data={
                "id": 100,
                "trackName": "Yellow",
                "artistName": "Coldplay",
                "albumName": "Parachutes",
                "duration": 267.0,
                "instrumental": False,
                "syncedLyrics": "[00:10.00] Look at the stars\n[00:15.00] Look how they shine",
                "plainLyrics": "Look at the stars\nLook how they shine",
            },
        )
        mock_urlopen.return_value = mock_resp

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("Coldplay", "Yellow", cache_dir=tmpdir)
            self.assertEqual(res["status"], "ok")
            self.assertTrue(res["synced"])
            self.assertTrue(res["has_plain"])
            self.assertEqual(len(res["lines"]), 2)
            self.assertEqual(res["lines"][0]["text"], "Look at the stars")
            self.assertEqual(res["lines"][0]["time_ms"], 10000)
            self.assertFalse(res["cached"])

            # Subsequent call returns cached version
            res_cached = fetch_lyrics("Coldplay", "Yellow", cache_dir=tmpdir)
            self.assertTrue(res_cached["cached"])

    @patch("urllib.request.urlopen")
    def test_02_stage2_cleaned_title_fallback(self, mock_urlopen):
        """Stage 2: Exact query returns 404, cleaned title succeeds."""
        err_404 = make_mock_404()
        
        mock_success = make_mock_response(
            status=200,
            data={
                "id": 200,
                "trackName": "Yellow",
                "artistName": "Coldplay",
                "syncedLyrics": "[00:05.00] Look at the stars",
                "plainLyrics": "Look at the stars",
                "instrumental": False,
            },
        )

        mock_urlopen.side_effect = [err_404, mock_success]

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("Coldplay", "Yellow - Remastered 2011", cache_dir=tmpdir)
            self.assertEqual(res["status"], "ok")
            self.assertEqual(len(res["lines"]), 1)
            self.assertEqual(res["lines"][0]["text"], "Look at the stars")

    @patch("urllib.request.urlopen")
    def test_03_stage3_search_fallback_synced(self, mock_urlopen):
        """Stage 3: Both Stage 1 and 2 return 404, Stage 3 search query succeeds."""
        err_404 = make_mock_404()
        
        mock_search_resp = make_mock_response(
            status=200,
            data=[
                {
                    "id": 301,
                    "trackName": "Yellow (Acoustic)",
                    "artistName": "Coldplay",
                    "syncedLyrics": "[00:12.00] Look at the stars acoustic",
                    "plainLyrics": "Look at the stars acoustic",
                    "instrumental": False,
                }
            ],
        )

        mock_urlopen.side_effect = [err_404, mock_search_resp]

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("Coldplay", "Yellow", cache_dir=tmpdir)
            self.assertEqual(res["status"], "ok")
            self.assertTrue(res["synced"])
            self.assertEqual(res["lines"][0]["text"], "Look at the stars acoustic")

    @patch("urllib.request.urlopen")
    def test_04_stage4_plain_lyrics_only(self, mock_urlopen):
        """Stage 4: Song has plain lyrics only (no syncedLyrics)."""
        mock_resp = make_mock_response(
            status=200,
            data={
                "id": 401,
                "trackName": "Indie Song",
                "artistName": "Indie Band",
                "syncedLyrics": None,
                "plainLyrics": "First verse\nSecond verse\nThird verse",
                "instrumental": False,
            },
        )
        mock_urlopen.return_value = mock_resp

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("Indie Band", "Indie Song", cache_dir=tmpdir)
            self.assertEqual(res["status"], "ok")
            self.assertFalse(res["synced"])
            self.assertTrue(res["has_plain"])
            self.assertEqual(len(res["lines"]), 3)
            # Unsynced lines have time_ms: -1, time_sec: -1.0
            self.assertEqual(res["lines"][0]["time_ms"], -1)
            self.assertEqual(res["lines"][0]["time_sec"], -1.0)
            self.assertEqual(res["lines"][0]["text"], "First verse")

    @patch("urllib.request.urlopen")
    def test_05_stage4_instrumental(self, mock_urlopen):
        """Stage 4: Track marked as instrumental: true."""
        mock_resp = make_mock_response(
            status=200,
            data={
                "id": 501,
                "trackName": "Clair de Lune",
                "artistName": "Claude Debussy",
                "instrumental": True,
                "syncedLyrics": None,
                "plainLyrics": None,
            },
        )
        mock_urlopen.return_value = mock_resp

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("Claude Debussy", "Clair de Lune", cache_dir=tmpdir)
            self.assertEqual(res["status"], "instrumental")
            self.assertTrue(res["instrumental"])
            self.assertEqual(res["message"], "Pista instrumental")
            self.assertEqual(res["lines"], [])

    @patch("urllib.request.urlopen")
    def test_06_stage4_not_found(self, mock_urlopen):
        """Stage 4: Track not found across all stages."""
        err_404 = make_mock_404()
        mock_search_empty = make_mock_response(status=200, data=[])

        mock_urlopen.side_effect = [err_404, mock_search_empty]

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("UnknownArtist", "UnknownSong", cache_dir=tmpdir)
            self.assertEqual(res["status"], "not_found")
            self.assertEqual(res["message"], "Letras no disponibles para esta pista")
            self.assertEqual(res["lines"], [])

    @patch("urllib.request.urlopen")
    def test_07_network_error_no_cache(self, mock_urlopen):
        """Network error (e.g. connection refused) returns status: error and does not write cache."""
        mock_urlopen.side_effect = urllib.error.URLError("Connection refused")

        with tempfile.TemporaryDirectory() as tmpdir:
            res = fetch_lyrics("Coldplay", "Yellow", cache_dir=tmpdir)
            self.assertEqual(res["status"], "error")
            self.assertIn("Fallo de conexión", res["message"])
            # Ensure no cache was created
            key = compute_cache_key("Coldplay", "Yellow")
            self.assertFalse(os.path.exists(os.path.join(tmpdir, key)))

    def test_08_empty_title_error(self):
        """Calling fetch_lyrics with empty title returns status: error."""
        res = fetch_lyrics("Coldplay", "")
        self.assertEqual(res["status"], "error")
        self.assertIn("Se requiere al menos el título", res["message"])

    @patch("urllib.request.urlopen")
    def test_09_force_bypasses_cache(self, mock_urlopen):
        """Passing force=True bypasses existing cache and executes network fetch."""
        mock_resp = make_mock_response(
            status=200,
            data={
                "id": 601,
                "trackName": "Yellow",
                "artistName": "Coldplay",
                "syncedLyrics": "[00:10.00] Fresh network lyrics",
                "plainLyrics": "Fresh network lyrics",
                "instrumental": False,
            },
        )
        mock_urlopen.return_value = mock_resp

        with tempfile.TemporaryDirectory() as tmpdir:
            # Pre-populate cache with old data
            old_payload = {
                "status": "ok",
                "track": "Yellow",
                "artist": "Coldplay",
                "lines": [{"time_ms": 1000, "time_sec": 1.0, "text": "Old cached lyrics"}],
                "cached": False,
            }
            save_to_cache(tmpdir, "Coldplay", "Yellow", old_payload)

            # Normal fetch returns old cached data
            res_cached = fetch_lyrics("Coldplay", "Yellow", cache_dir=tmpdir, force=False)
            self.assertEqual(res_cached["lines"][0]["text"], "Old cached lyrics")
            self.assertTrue(res_cached["cached"])

            # Force fetch re-queries network and overwrites
            res_forced = fetch_lyrics("Coldplay", "Yellow", cache_dir=tmpdir, force=True)
            self.assertEqual(res_forced["lines"][0]["text"], "Fresh network lyrics")
            self.assertFalse(res_forced["cached"])


class TestLyricsCli(unittest.TestCase):
    """Subprocess integration tests for scripts/lyrics.py CLI."""

    CLI_SCRIPT = str(PROJECT_ROOT / "scripts" / "lyrics.py")

    def test_01_script_is_executable(self):
        """Verify scripts/lyrics.py has executable mode."""
        self.assertTrue(os.access(self.CLI_SCRIPT, os.X_OK))

    def test_02_cli_flags_invocation(self):
        """Invoke CLI using --artist and --title flags."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Pre-populate cache for offline and sub-second execution
            payload = {
                "status": "ok",
                "track": "Yellow",
                "artist": "Coldplay",
                "album": "Parachutes",
                "duration": 267.0,
                "instrumental": False,
                "synced": True,
                "has_plain": True,
                "lines": [{"time_ms": 1000, "time_sec": 1.0, "text": "Look at the stars"}],
                "plain_lyrics": "Look at the stars",
                "raw_lrc": "[00:01.00] Look at the stars",
                "cached": False,
                "cached_at": int(time.time()),
                "source": "lrclib",
                "message": None,
            }
            save_to_cache(tmpdir, "Coldplay", "Yellow", payload)

            cmd = [
                sys.executable,
                self.CLI_SCRIPT,
                "--artist", "Coldplay",
                "--title", "Yellow",
                "--cache-dir", tmpdir,
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            self.assertEqual(res.returncode, 0)
            data = json.loads(res.stdout.strip())
            self.assertEqual(data["status"], "ok")
            self.assertEqual(data["track"], "Yellow")
            self.assertEqual(data["artist"], "Coldplay")
            self.assertTrue(data["cached"])

    def test_03_cli_positional_invocation(self):
        """Invoke CLI using positional arguments: python3 lyrics.py artist title."""
        with tempfile.TemporaryDirectory() as tmpdir:
            payload = {
                "status": "ok",
                "track": "Yellow",
                "artist": "Coldplay",
                "album": "Parachutes",
                "duration": 267.0,
                "instrumental": False,
                "synced": True,
                "has_plain": True,
                "lines": [{"time_ms": 1000, "time_sec": 1.0, "text": "Look at the stars"}],
                "plain_lyrics": "Look at the stars",
                "raw_lrc": "[00:01.00] Look at the stars",
                "cached": False,
                "cached_at": int(time.time()),
                "source": "lrclib",
                "message": None,
            }
            save_to_cache(tmpdir, "Coldplay", "Yellow", payload)

            cmd = [
                sys.executable,
                self.CLI_SCRIPT,
                "Coldplay",
                "Yellow",
                "--cache-dir", tmpdir,
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            self.assertEqual(res.returncode, 0)
            data = json.loads(res.stdout.strip())
            self.assertEqual(data["track"], "Yellow")
            self.assertEqual(data["artist"], "Coldplay")
            self.assertTrue(data["cached"])

    def test_04_cli_atomic_single_line_stdout(self):
        """Verify stdout contains strictly 1 newline-terminated line with valid JSON."""
        with tempfile.TemporaryDirectory() as tmpdir:
            payload = {
                "status": "instrumental",
                "track": "Clair de Lune",
                "artist": "Claude Debussy",
                "album": "Works",
                "duration": 216.0,
                "instrumental": True,
                "synced": False,
                "has_plain": False,
                "lines": [],
                "plain_lyrics": None,
                "raw_lrc": None,
                "cached": False,
                "cached_at": int(time.time()),
                "source": "lrclib",
                "message": "Pista instrumental",
            }
            save_to_cache(tmpdir, "Claude Debussy", "Clair de Lune", payload)

            cmd = [
                sys.executable,
                self.CLI_SCRIPT,
                "Claude Debussy",
                "Clair de Lune",
                "--cache-dir", tmpdir,
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            self.assertEqual(res.returncode, 0)
            lines = res.stdout.splitlines()
            self.assertEqual(len(lines), 1, "stdout must contain exactly one clean JSON line for SplitParser")
            data = json.loads(lines[0])
            self.assertEqual(data["status"], "instrumental")

    def test_05_cli_missing_args(self):
        """Invoking without required args outputs error JSON."""
        cmd = [sys.executable, self.CLI_SCRIPT]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout.strip())
        self.assertEqual(data["status"], "error")


if __name__ == "__main__":
    unittest.main()
