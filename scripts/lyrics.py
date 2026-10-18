#!/usr/bin/env python3
"""Panacea Lyrics Engine & Local Cache (LRCLIB backend).

Fetches synchronized (LRC) and plain lyrics using LRCLIB API:
- Multi-tier query strategy:
  1. Exact GET (/api/get?artist_name=...&track_name=...&album_name=...&duration=...)
  2. Cleaned title GET (strip remasters, feat., etc.)
  3. Search fallback (/api/search?q=...)
  4. Instrumental, plain lyrics fallback, and not-found states
- Robust LRC parser supporting [mm:ss.xx], [mm:ss.xxx], [mm:ss], multi-tag lines, [offset:X]
- Fast collision-resistant local cache in ~/.cache/panacea/lyrics/
- Atomic single-line JSON emission to stdout for Quickshell SplitParser
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "Panacea/1.0 (https://github.com/panacea)"
REQUEST_TIMEOUT = 3.5
LRCLIB_BASE_URL = "https://lrclib.net"


def clean_track_title(title: str) -> str:
    """Clean common metadata noise from track title for fallback lookup."""
    if not title:
        return ""
    t = title
    # Remove bracketed metadata: [Official Video], [HD], etc.
    t = re.sub(r'\[[^\]]*\]', '', t)
    # Remove parentheses containing remaster, live, edit, version, deluxe, feat, etc.
    t = re.sub(
        r'\s*\((?:(?:\d{4}\s*)?remaster(?:ed)?(?:\s*version)?|live.*?|mono|stereo|bonus\s*track|single\s*version|album\s*version|radio\s*edit|deluxe.*?|feat(?:\.|\s).*?|ft(?:\.|\s).*?)\)',
        '',
        t,
        flags=re.I,
    )
    # Remove dash suffixes: - Remastered ..., - 2020 Remaster, - Live ..., - Radio Edit, etc.
    t = re.sub(
        r'\s*-\s*(?:(?:\d{4}\s*)?remaster(?:ed)?(?:\s*version)?|live.*?|mono|stereo|bonus\s*track|single\s*version|album\s*version|radio\s*edit|deluxe.*?|feat(?:\.|\s).*?|ft(?:\.|\s).*?).*$',
        '',
        t,
        flags=re.I,
    )
    # Remove standalone "feat. ..." or "ft. ..." at end
    t = re.sub(r'\s*(?:feat|ft)\.?\s+.*$', '', t, flags=re.I)
    # Clean whitespace and trailing punctuation
    t = re.sub(r'[\s\-:._]+$', '', t).strip()
    return t if t else title.strip()


def compute_cache_key(artist: str, title: str) -> str:
    """Generate deterministic filesystem-safe filename with SHA-256 hash."""
    art = (artist or "").strip().lower()
    tit = (title or "").strip().lower()
    digest = hashlib.sha256(f"{art}||{tit}".encode("utf-8")).hexdigest()[:16]
    slug = re.sub(r'[^a-zA-Z0-9]+', '_', f"{art}_{tit}").strip('_')[:32]
    if not slug:
        slug = "track"
    return f"{slug}_{digest}.json"


def parse_lrc(lrc_text: str) -> list:
    """Parse standard or extended LRC lyrics into sorted list of line dicts.

    Output format per line:
    {"time_ms": int, "time_sec": float, "text": str}

    Supports:
    - [mm:ss.xx] (centiseconds)
    - [mm:ss.xxx] (milliseconds)
    - [mm:ss] (seconds only)
    - [m:ss.xx] (1-3 digit minutes)
    - Multi-tag lines: [00:10.00][00:20.00] Line text
    - [offset:X] (global offset in milliseconds)
    - Discards metadata tags ([ar:], [ti:], etc.)
    """
    if not lrc_text:
        return []

    # Check for global offset tag: [offset:+500] or [offset:-300]
    offset_ms = 0
    offset_match = re.search(r'\[offset:\s*([+-]?\d+)\s*\]', lrc_text, re.I)
    if offset_match:
        try:
            offset_ms = int(offset_match.group(1))
        except ValueError:
            offset_ms = 0

    tag_regex = re.compile(r'\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]')
    lines = []

    for raw_line in lrc_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        # Skip offset lines
        if re.match(r'\[offset:\s*[+-]?\d+\s*\]', line, re.I):
            continue
        # Skip metadata tags like [ar:Artist], [ti:Title], [length:03:45]
        if re.match(r'\[[a-zA-Z]+:', line) and not tag_regex.search(line):
            continue

        matches = list(tag_regex.finditer(line))
        if not matches:
            continue

        text = line[matches[-1].end():].strip()

        for m in matches:
            m_min = int(m.group(1))
            m_sec = int(m.group(2))
            m_frac = m.group(3)

            if m_frac:
                if len(m_frac) == 1:
                    frac_ms = int(m_frac) * 100
                elif len(m_frac) == 2:
                    frac_ms = int(m_frac) * 10
                else:
                    frac_ms = int(m_frac[:3].ljust(3, '0'))
            else:
                frac_ms = 0

            total_ms = (m_min * 60 + m_sec) * 1000 + frac_ms + offset_ms
            time_ms = max(0, total_ms)
            time_sec = round(time_ms / 1000.0, 3)

            lines.append({
                "time_ms": time_ms,
                "time_sec": time_sec,
                "text": text,
            })

    # Sort strictly by timestamp
    lines.sort(key=lambda x: (x["time_ms"], x["time_sec"]))
    return lines


def save_to_cache(cache_dir: str, artist: str, title: str, payload: dict) -> None:
    """Save pre-parsed payload to filesystem cache atomically."""
    try:
        os.makedirs(cache_dir, exist_ok=True)
        key = compute_cache_key(artist, title)
        target_path = os.path.join(cache_dir, key)
        tmp_path = target_path + f".tmp.{os.getpid()}"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, target_path)
    except Exception:
        pass


def load_from_cache(cache_dir: str, artist: str, title: str) -> dict | None:
    """Load cached pre-parsed payload from disk if present."""
    try:
        key = compute_cache_key(artist, title)
        target_path = os.path.join(cache_dir, key)
        if os.path.isfile(target_path):
            with open(target_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict) and "status" in data:
                    data_copy = dict(data)
                    data_copy["cached"] = True
                    return data_copy
    except Exception:
        pass
    return None


def query_lrclib_get(
    artist: str,
    title: str,
    album: str = "",
    duration: float = 0.0,
    timeout: float = REQUEST_TIMEOUT,
) -> dict | None:
    """Query /api/get endpoint. Returns track dict on 200, None on 404."""
    params = {"artist_name": artist, "track_name": title}
    if album:
        params["album_name"] = album
    if duration and duration > 0:
        params["duration"] = int(round(duration))

    url = f"{LRCLIB_BASE_URL}/api/get?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status == 200:
                return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    return None


def query_lrclib_search(
    query_str: str,
    timeout: float = REQUEST_TIMEOUT,
) -> list | None:
    """Query /api/search endpoint. Returns candidate dicts list or None."""
    url = f"{LRCLIB_BASE_URL}/api/search?" + urllib.parse.urlencode({"q": query_str})
    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                if isinstance(data, list):
                    return data
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    return None


def fetch_lyrics(
    artist: str,
    title: str,
    album: str = "",
    duration: float = 0.0,
    cache_dir: str = None,
    force: bool = False,
) -> dict:
    """Fetch lyrics using multi-tier strategy with caching."""
    artist = (artist or "").strip()
    title = (title or "").strip()
    album = (album or "").strip()

    if not title:
        return {
            "status": "error",
            "track": "",
            "artist": artist,
            "album": album,
            "duration": duration,
            "instrumental": False,
            "synced": False,
            "has_plain": False,
            "lines": [],
            "plain_lyrics": None,
            "raw_lrc": None,
            "cached": False,
            "cached_at": int(time.time()),
            "source": "lrclib",
            "message": "Se requiere al menos el título de la pista",
        }

    # Cache lookup
    if cache_dir and not force:
        cached_data = load_from_cache(cache_dir, artist, title)
        if cached_data is not None:
            return cached_data

    raw_item = None
    network_error_msg = None

    try:
        # Stage 1: Exact query with artist, track, album, duration
        raw_item = query_lrclib_get(artist, title, album, duration)

        # Stage 2: Cleaned title query if Stage 1 didn't find anything
        if not raw_item:
            clean_t = clean_track_title(title)
            # If title had extra tags or album/duration might have restricted match:
            if clean_t and (clean_t != title or album or duration > 0):
                raw_item = query_lrclib_get(artist, clean_t)
            # Also try original title without album/duration if clean_t didn't differ but album/duration was passed
            if not raw_item and (album or duration > 0):
                raw_item = query_lrclib_get(artist, title)

        # Stage 3: Search fallback
        if not raw_item:
            clean_t = clean_track_title(title)
            search_query = f"{artist} {clean_t or title}".strip()
            search_results = query_lrclib_search(search_query)
            if search_results:
                # Prioritize: 1. syncedLyrics, 2. plainLyrics, 3. instrumental
                for cand in search_results:
                    if cand.get("syncedLyrics"):
                        raw_item = cand
                        break
                if not raw_item:
                    for cand in search_results:
                        if cand.get("plainLyrics"):
                            raw_item = cand
                            break
                if not raw_item:
                    for cand in search_results:
                        if cand.get("instrumental"):
                            raw_item = cand
                            break
                if not raw_item and search_results:
                    raw_item = search_results[0]
    except urllib.error.HTTPError as e:
        network_error_msg = f"HTTP {e.code}"
    except urllib.error.URLError as e:
        network_error_msg = f"Fallo de conexión ({getattr(e, 'reason', e)})"
    except Exception as e:
        network_error_msg = str(e)

    # Stage 4: Process outcome and assemble payload
    now_ts = int(time.time())

    if network_error_msg:
        return {
            "status": "error",
            "track": title,
            "artist": artist,
            "album": album,
            "duration": duration,
            "instrumental": False,
            "synced": False,
            "has_plain": False,
            "lines": [],
            "plain_lyrics": None,
            "raw_lrc": None,
            "cached": False,
            "cached_at": now_ts,
            "source": "lrclib",
            "message": f"Error al consultar LRCLIB: {network_error_msg}",
        }

    if not raw_item:
        result = {
            "status": "not_found",
            "track": title,
            "artist": artist,
            "album": album,
            "duration": duration,
            "instrumental": False,
            "synced": False,
            "has_plain": False,
            "lines": [],
            "plain_lyrics": None,
            "raw_lrc": None,
            "cached": False,
            "cached_at": now_ts,
            "source": "lrclib",
            "message": "Letras no disponibles para esta pista",
        }
    elif raw_item.get("instrumental"):
        result = {
            "status": "instrumental",
            "track": title,
            "artist": artist,
            "album": raw_item.get("albumName") or album,
            "duration": float(raw_item.get("duration") or duration or 0.0),
            "instrumental": True,
            "synced": False,
            "has_plain": False,
            "lines": [],
            "plain_lyrics": None,
            "raw_lrc": None,
            "cached": False,
            "cached_at": now_ts,
            "source": "lrclib",
            "message": "Pista instrumental",
        }
    else:
        synced_lrc = raw_item.get("syncedLyrics")
        plain_lrc = raw_item.get("plainLyrics")
        matched_album = raw_item.get("albumName") or album
        matched_duration = float(raw_item.get("duration") or duration or 0.0)

        if synced_lrc and synced_lrc.strip():
            parsed_lines = parse_lrc(synced_lrc)
            result = {
                "status": "ok",
                "track": title,
                "artist": artist,
                "album": matched_album,
                "duration": matched_duration,
                "instrumental": False,
                "synced": True,
                "has_plain": bool(plain_lrc and plain_lrc.strip()),
                "lines": parsed_lines,
                "plain_lyrics": plain_lrc,
                "raw_lrc": synced_lrc,
                "cached": False,
                "cached_at": now_ts,
                "source": "lrclib",
                "message": None,
            }
        elif plain_lrc and plain_lrc.strip():
            parsed_lines = [
                {"time_ms": -1, "time_sec": -1.0, "text": l.strip()}
                for l in plain_lrc.splitlines() if l.strip()
            ]
            result = {
                "status": "ok",
                "track": title,
                "artist": artist,
                "album": matched_album,
                "duration": matched_duration,
                "instrumental": False,
                "synced": False,
                "has_plain": True,
                "lines": parsed_lines,
                "plain_lyrics": plain_lrc,
                "raw_lrc": None,
                "cached": False,
                "cached_at": now_ts,
                "source": "lrclib",
                "message": None,
            }
        else:
            result = {
                "status": "not_found",
                "track": title,
                "artist": artist,
                "album": matched_album,
                "duration": matched_duration,
                "instrumental": False,
                "synced": False,
                "has_plain": False,
                "lines": [],
                "plain_lyrics": None,
                "raw_lrc": None,
                "cached": False,
                "cached_at": now_ts,
                "source": "lrclib",
                "message": "Letras no disponibles para esta pista",
            }

    # Save to disk cache for valid states (ok, instrumental, not_found)
    if cache_dir and result["status"] in ("ok", "instrumental", "not_found"):
        save_to_cache(cache_dir, artist, title, result)

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Panacea LRCLIB lyrics fetcher & caching engine",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--artist", "-a", type=str, default=None, help="Artist name")
    parser.add_argument("--title", "-t", "--track", type=str, default=None, help="Track/Song title")
    parser.add_argument("--album", type=str, default="", help="Album name")
    parser.add_argument("--duration", "-d", type=float, default=0.0, help="Track duration in seconds")
    parser.add_argument("--force", "-f", action="store_true", help="Force bypass cache and refetch")
    parser.add_argument("--cache-dir", type=str, default=None, help="Custom cache directory")
    parser.add_argument("positional", nargs="*", help="Positional args: artist title [album] [duration]")

    args = parser.parse_args()

    # Resolve artist, title, album, duration from flags or positional arguments
    artist = args.artist
    title = args.title
    album = args.album or ""
    duration = args.duration or 0.0

    pos = list(args.positional or [])
    if not artist and not title:
        if len(pos) >= 1:
            artist = pos.pop(0)
        if len(pos) >= 1:
            title = pos.pop(0)
        if not album and len(pos) >= 1:
            album = pos.pop(0)
        if not duration and len(pos) >= 1:
            try:
                duration = float(pos.pop(0))
            except ValueError:
                pass
    elif not artist and title:
        if len(pos) >= 1:
            artist = pos.pop(0)
        if not album and len(pos) >= 1:
            album = pos.pop(0)
        if not duration and len(pos) >= 1:
            try:
                duration = float(pos.pop(0))
            except ValueError:
                pass
    elif artist and not title:
        if len(pos) >= 1:
            title = pos.pop(0)
        if not album and len(pos) >= 1:
            album = pos.pop(0)
        if not duration and len(pos) >= 1:
            try:
                duration = float(pos.pop(0))
            except ValueError:
                pass

    artist = (artist or "").strip()
    title = (title or "").strip()
    album = (album or "").strip()

    cache_dir = args.cache_dir
    if not cache_dir:
        cache_dir = os.path.expanduser("~/.cache/panacea/lyrics")

    if not title:
        payload = {
            "status": "error",
            "track": "",
            "artist": artist,
            "album": album,
            "duration": duration,
            "instrumental": False,
            "synced": False,
            "has_plain": False,
            "lines": [],
            "plain_lyrics": None,
            "raw_lrc": None,
            "cached": False,
            "cached_at": int(time.time()),
            "source": "lrclib",
            "message": "Se requiere al menos el título de la pista",
        }
        print(json.dumps(payload, ensure_ascii=False))
        sys.stdout.flush()
        return

    payload = fetch_lyrics(
        artist=artist,
        title=title,
        album=album,
        duration=duration,
        cache_dir=cache_dir,
        force=args.force,
    )

    print(json.dumps(payload, ensure_ascii=False))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
