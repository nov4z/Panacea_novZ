#!/usr/bin/env python3
import sys
import os
import re
import urllib.request
import urllib.parse
import hashlib
import subprocess
import colorsys

CACHE_DIR = os.path.expanduser("~/.cache/panacea/art_cache")

def compute_cache_key(src, local_path):
    if local_path and os.path.exists(local_path):
        try:
            stat = os.stat(local_path)
            raw = f"{local_path}_{stat.st_size}_{stat.st_mtime}"
            return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
        except Exception:
            pass
    return hashlib.sha256(src.encode("utf-8")).hexdigest()[:16]

def get_image_local_path(src):
    if not src:
        return None
    src = src.strip()
    if src.startswith("file://"):
        p = urllib.request.url2pathname(src[7:])
        return p if os.path.exists(p) else None
    if src.startswith("http://") or src.startswith("https://"):
        os.makedirs(CACHE_DIR, exist_ok=True)
        url_hash = hashlib.sha256(src.encode("utf-8")).hexdigest()[:16]
        cached_file = os.path.join(CACHE_DIR, f"{url_hash}.jpg")
        if os.path.exists(cached_file) and os.path.getsize(cached_file) > 0:
            return cached_file

        # Intentar descargar en alta resolución (b273)
        hires_src = re.sub(r"ab67616d0000[0-9a-f]{4}", "ab67616d0000b273", src)
        for target_url in [hires_src, src] if hires_src != src else [src]:
            try:
                req = urllib.request.Request(
                    target_url,
                    headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"}
                )
                with urllib.request.urlopen(req, timeout=2.5) as resp:
                    data = resp.read()
                    if data:
                        with open(cached_file, "wb") as f:
                            f.write(data)
                        return cached_file
            except Exception:
                continue
        return None
    if os.path.exists(src):
        return src
    return None

def extract_dominant_color(img_path):
    fallback = ("#3b82f6", "#6366f1")
    if not img_path or not os.path.exists(img_path):
        return fallback

    try:
        cmd = [
            "magick", img_path,
            "-resize", "64x64!",
            "-depth", "8",
            "rgb:-"
        ]
        raw = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
    except Exception:
        return fallback

    buckets = {}
    total = 0
    chromatic = 0
    max_sat = 0.0

    for i in range(0, len(raw), 3):
        r, g, b = raw[i], raw[i+1], raw[i+2]
        max_c, min_c = max(r, g, b), min(r, g, b)
        if max_c < 18 or min_c > 242:
            continue
        total += 1
        if max_c - min_c < 14:
            continue

        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        if s > max_sat:
            max_sat = s
        if s >= 0.16:
            chromatic += 1

        key = ((r & 0xF0) << 4) | (g & 0xF0) | (b >> 4)
        if key not in buckets:
            buckets[key] = [0, 0, 0, 0]
        bkt = buckets[key]
        bkt[0] += r
        bkt[1] += g
        bkt[2] += b
        bkt[3] += 1

    # Portadas en blanco y negro / monocromáticas
    if total == 0 or (chromatic / max(1, total) < 0.015) or max_sat < 0.08:
        return "#ffffff", "#cccccc"

    candidates = []
    for key, bkt in buckets.items():
        cnt = bkt[3]
        if cnt < max(2, total * 0.005):
            continue
        r = round(bkt[0] / cnt)
        g = round(bkt[1] / cnt)
        b = round(bkt[2] / cnt)
        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        if s < 0.16 or l < 0.12:
            continue

        # Detección precisa de tonos de piel humana (rostros reales)
        is_skin = (0.045 <= h <= 0.125) and (0.18 <= s <= 0.48) and (0.25 <= l <= 0.78)

        pop_score = cnt ** 0.5
        sat_score = s ** 1.3
        light_score = max(0.15, 1.0 - abs(l - 0.52) * 1.3)
        score = pop_score * (0.25 + sat_score * 2.2) * light_score

        candidates.append({
            "r": r, "g": g, "b": b,
            "h": h, "s": s, "l": l,
            "cnt": cnt, "score": score,
            "is_skin": is_skin
        })

    if not candidates:
        return "#ffffff", "#cccccc"

    # Si hay acentos vivos que no sean tonos piel (gafas moradas, ropa, letras, fondos):
    has_non_skin = any(not c["is_skin"] and c["s"] >= 0.25 for c in candidates)
    if has_non_skin:
        for c in candidates:
            if c["is_skin"]:
                c["score"] *= 0.10
            elif c["s"] >= 0.40:
                c["score"] *= (1.0 + (c["s"] ** 1.4) * 2.0)

    candidates.sort(key=lambda x: x["score"], reverse=True)
    vib = candidates[0]

    target_l = max(0.52, min(0.72, vib["l"]))
    target_s = max(0.50, min(1.0, vib["s"]))
    r1, g1, b1 = colorsys.hls_to_rgb(vib["h"], target_l, target_s)
    c1 = f"#{round(r1 * 255):02x}{round(g1 * 255):02x}{round(b1 * 255):02x}"

    c2 = None
    for cand in candidates[1:]:
        diff = abs(cand["h"] - vib["h"])
        if diff > 0.5:
            diff = 1.0 - diff
        if 0.015 <= diff <= 0.08:
            s2 = max(0.45, min(1.0, cand["s"] * 1.3))
            l2 = max(0.38, min(0.56, cand["l"]))
            r2, g2, b2 = colorsys.hls_to_rgb(cand["h"], l2, s2)
            c2 = f"#{round(r2 * 255):02x}{round(g2 * 255):02x}{round(b2 * 255):02x}"
            break

    if not c2:
        h2 = (vib["h"] + 0.035) % 1.0
        l2 = max(0.36, min(0.54, target_l * 0.90))
        s2 = max(0.48, min(1.0, target_s * 0.95))
        r2, g2, b2 = colorsys.hls_to_rgb(h2, l2, s2)
        c2 = f"#{round(r2 * 255):02x}{round(g2 * 255):02x}{round(b2 * 255):02x}"

    return c1, c2

def main():
    if len(sys.argv) < 2:
        print("#ffffff")
        print("#888888")
        sys.stdout.flush()
        return

    raw_src = sys.argv[1].strip()
    if not raw_src:
        print("#ffffff")
        print("#888888")
        sys.stdout.flush()
        return

    os.makedirs(CACHE_DIR, exist_ok=True)
    local_candidate = None
    if raw_src.startswith("file://"):
        local_candidate = urllib.request.url2pathname(raw_src[7:])

    cache_key = compute_cache_key(raw_src, local_candidate)
    color_cache_file = os.path.join(CACHE_DIR, f"{cache_key}.color")

    # 1. Chequeo ultra-rápido de caché de color (<1ms)
    if os.path.exists(color_cache_file):
        try:
            with open(color_cache_file, "r") as f:
                lines = [l.strip() for l in f if l.strip()]
            if len(lines) >= 2:
                path = get_image_local_path(raw_src)
                if path and os.path.exists(path):
                    print(path)
                print(lines[0])
                print(lines[1])
                sys.stdout.flush()
                return
        except Exception:
            pass

    # 2. Descarga / resolución de ruta local
    path = get_image_local_path(raw_src)
    if path and os.path.exists(path):
        print(path)
        sys.stdout.flush()

    # 3. Extracción de color
    c1, c2 = extract_dominant_color(path)

    # 4. Guardar en caché persistente
    try:
        with open(color_cache_file, "w") as f:
            f.write(f"{c1}\n{c2}\n")
    except Exception:
        pass

    print(c1)
    print(c2)
    sys.stdout.flush()

if __name__ == "__main__":
    main()
