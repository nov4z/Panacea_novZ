#!/usr/bin/env python3
"""
sync_terminal_colors.py
Synchronizes Kitty terminal (and console tools: Fish, Fastfetch, Cava, Peaclock, Alacritty)
in real-time with the active Panacea / Material You / music color theme.
"""

import sys
import os
import glob
import json
import colorsys
import subprocess

HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(HOME, ".cache", "panacea")
MATUGEN_JSON = os.path.join(CACHE_DIR, "matugen.json")
PANACEA_SETTINGS = os.path.join(HOME, ".config", "panacea", "settings.json")

KITTY_CONF_DIR = os.path.join(HOME, ".config", "kitty")
KITTY_THEME_FILE = os.path.join(KITTY_CONF_DIR, "dank-theme.conf")
KITTY_TABS_FILE = os.path.join(KITTY_CONF_DIR, "dank-tabs.conf")
ALACRITTY_THEME_FILE = os.path.join(HOME, ".config", "alacritty", "dank-theme.toml")
FASTFETCH_CONFIG = os.path.join(HOME, ".config", "fastfetch", "config.jsonc")
FISH_COLORS_FILE = os.path.join(HOME, ".config", "fish", "conf.d", "dms_colors.fish")
CAVA_CONFIG = os.path.join(HOME, ".config", "cava", "config")
PEACLOCK_CONFIG = os.path.join(HOME, ".config", "peaclock", "config")


def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    if len(h) < 6:
        h = h.ljust(6, "0")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(
        max(0, min(255, int(r * 255 + 0.5))),
        max(0, min(255, int(g * 255 + 0.5))),
        max(0, min(255, int(b * 255 + 0.5)))
    )


def hsl_to_hex(h_deg, s, l):
    r, g, b = colorsys.hls_to_rgb(h_deg / 360.0, l, s)
    return rgb_to_hex(r, g, b)


def atomic_write(filepath, content):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    tmp_path = filepath + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp_path, filepath)


def get_current_theme_id():
    if len(sys.argv) > 1 and sys.argv[1] in ("default", "nothing", "material3", "material"):
        return sys.argv[1]
    if os.path.isfile(PANACEA_SETTINGS):
        try:
            with open(PANACEA_SETTINGS, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("themeId", "material3")
        except Exception:
            pass
    return "material3"


def load_palette(theme_id):
    if theme_id == "nothing":
        # Nothing monochrome styling
        return {
            "bg": "#000000",
            "surface": "#0c0c0c",
            "surface_container": "#181818",
            "fg": "#ffffff",
            "fg_muted": "#aaaaaa",
            "primary": "#ffffff",
            "on_primary": "#000000",
            "secondary": "#d71921",
            "secondary_container": "#2a1517",
            "on_secondary_container": "#ffb4ab",
            "tertiary": "#888888",
            "error": "#d71921",
            "outline": "#555555",
            "c0": "#000000",
            "c1": "#d71921",
            "c2": "#ffffff",
            "c3": "#cccccc",
            "c4": "#ffffff",
            "c5": "#d71921",
            "c6": "#aaaaaa",
            "c7": "#ffffff",
            "c8": "#444444",
            "c9": "#ff4d58",
            "c10": "#ffffff",
            "c11": "#dddddd",
            "c12": "#ffffff",
            "c13": "#ff4d58",
            "c14": "#cccccc",
            "c15": "#ffffff",
        }

    if theme_id == "default":
        # Panacea Default theme (Pure black + Blue accent)
        return {
            "bg": "#000000",
            "surface": "#0a0a0c",
            "surface_container": "#16181d",
            "fg": "#ffffff",
            "fg_muted": "#94a3b8",
            "primary": "#3b82f6",
            "on_primary": "#001e4a",
            "secondary": "#60a5fa",
            "secondary_container": "#1e3a8a",
            "on_secondary_container": "#dbeafe",
            "tertiary": "#38bdf8",
            "error": "#ef4444",
            "outline": "#475569",
            "c0": "#000000",
            "c1": "#ef4444",
            "c2": "#22c55e",
            "c3": "#eab308",
            "c4": "#3b82f6",
            "c5": "#a855f7",
            "c6": "#06b6d4",
            "c7": "#f8fafc",
            "c8": "#475569",
            "c9": "#f87171",
            "c10": "#4ade80",
            "c11": "#facc15",
            "c12": "#60a5fa",
            "c13": "#c084fc",
            "c14": "#22d3ee",
            "c15": "#ffffff",
        }

    # Material 3 dynamic theme
    colors = {}
    if os.path.isfile(MATUGEN_JSON):
        try:
            with open(MATUGEN_JSON, "r", encoding="utf-8") as f:
                data = json.load(f)
                colors = data.get("colors", {})
        except Exception:
            pass

    def get_token(name, fallback):
        val = colors.get(name, {})
        if isinstance(val, dict):
            c = val.get("dark", {}).get("color") or val.get("default", {}).get("color")
            if c and c.startswith("#"):
                return c
        elif isinstance(val, str) and val.startswith("#"):
            return val
        return fallback

    primary = get_token("primary", "#a3c9ff")
    on_primary = get_token("on_primary", "#00315c")
    bg = get_token("surface_container_lowest", get_token("background", "#0e141c"))
    surface = get_token("surface", "#111318")
    surface_container = get_token("surface_container", "#1a1c22")
    fg = get_token("on_surface", "#dee2ee")
    fg_muted = get_token("on_surface_variant", "#c1c7d2")
    secondary = get_token("secondary", "#bcc5eb")
    secondary_container = get_token("secondary_container", "#3c4665")
    on_secondary_container = get_token("on_secondary_container", "#dbe1ff")
    tertiary = get_token("tertiary", "#c4c1f9")
    error = get_token("error", "#ffb4ab")
    outline = get_token("outline", "#8b919c")

    # Analyze primary color hue to harmonize ANSI colors
    pr, pg, pb = hex_to_rgb(primary)
    ph, pl, ps = colorsys.rgb_to_hls(pr, pg, pb)
    ph_deg = ph * 360.0

    # Harmonized ANSI colors with high readability
    c0 = bg
    c1 = error if error else hsl_to_hex(355, 0.85, 0.70)
    c2 = hsl_to_hex(135, 0.80, 0.72)
    c3 = hsl_to_hex(48, 0.88, 0.74)
    c4 = hsl_to_hex(215, 0.85, 0.75)
    c5 = hsl_to_hex(295, 0.80, 0.72)
    c6 = hsl_to_hex(180, 0.80, 0.75)
    c7 = fg_muted
    c8 = outline

    # Inject primary into matching color slot for beautiful accent cohesion
    if 260 <= ph_deg <= 345:      # Pink / Purple / Magenta
        c5 = primary
    elif 190 <= ph_deg < 260:     # Blue / Teal
        c4 = primary
    elif 160 <= ph_deg < 190:     # Cyan
        c6 = primary
    elif 85 <= ph_deg < 160:      # Green
        c2 = primary
    elif 35 <= ph_deg < 85:       # Yellow / Amber / Orange
        c3 = primary
    elif ph_deg < 35 or ph_deg > 345: # Red / Coral
        c1 = primary

    # Bright variants (lightness ~82-88%)
    c9 = hsl_to_hex(355, 0.90, 0.82)
    c10 = hsl_to_hex(135, 0.88, 0.82)
    c11 = hsl_to_hex(48, 0.92, 0.84)
    c12 = primary if (190 <= ph_deg < 260) else hsl_to_hex(215, 0.90, 0.84)
    c13 = primary if (260 <= ph_deg <= 345) else hsl_to_hex(295, 0.88, 0.84)
    c14 = hsl_to_hex(180, 0.88, 0.84)
    c15 = "#ffffff"

    return {
        "bg": bg,
        "surface": surface,
        "surface_container": surface_container,
        "fg": fg,
        "fg_muted": fg_muted,
        "primary": primary,
        "on_primary": on_primary,
        "secondary": secondary,
        "secondary_container": secondary_container,
        "on_secondary_container": on_secondary_container,
        "tertiary": tertiary,
        "error": error,
        "outline": outline,
        "c0": c0, "c1": c1, "c2": c2, "c3": c3,
        "c4": c4, "c5": c5, "c6": c6, "c7": c7,
        "c8": c8, "c9": c9, "c10": c10, "c11": c11,
        "c12": c12, "c13": c13, "c14": c14, "c15": c15,
    }


def update_kitty(p):
    # 1. Update dank-theme.conf
    theme_content = f"""cursor {p['primary']}
cursor_text_color {p['on_primary']}

foreground            {p['fg']}
background            {p['bg']}
selection_foreground  {p['on_secondary_container']}
selection_background  {p['secondary_container']}
url_color             {p['primary']}

color0   {p['c0']}
color1   {p['c1']}
color2   {p['c2']}
color3   {p['c3']}
color4   {p['c4']}
color5   {p['c5']}
color6   {p['c6']}
color7   {p['c7']}
color8   {p['c8']}
color9   {p['c9']}
color10  {p['c10']}
color11  {p['c11']}
color12  {p['c12']}
color13  {p['c13']}
color14  {p['c14']}
color15  {p['c15']}
"""
    atomic_write(KITTY_THEME_FILE, theme_content)

    # 2. Update dank-tabs.conf
    tabs_content = f"""tab_bar_edge            top
tab_bar_style           powerline
tab_powerline_style     slanted
tab_bar_align           left
tab_bar_min_tabs        2
tab_bar_margin_width    0.0
tab_bar_margin_height   2.5 1.5
tab_bar_margin_color    {p['bg']}

tab_bar_background              {p['bg']}

active_tab_foreground           {p['on_primary']}
active_tab_background           {p['primary']}
active_tab_font_style           bold

inactive_tab_foreground         {p['fg_muted']}
inactive_tab_background         {p['surface_container']}
inactive_tab_font_style         normal

tab_activity_symbol             " ● "

tab_title_template              "{{fmt.fg.red}}{{bell_symbol}}{{activity_symbol}}{{fmt.fg.tab}}{{title[:30]}}{{title[30:] and '…'}} [{{index}}]"
active_tab_title_template       "{{fmt.fg.red}}{{bell_symbol}}{{activity_symbol}}{{fmt.fg.tab}}{{title[:30]}}{{title[30:] and '…'}} [{{index}}]"
"""
    atomic_write(KITTY_TABS_FILE, tabs_content)

    # 3. Broadcast OSC sequences to all active /dev/pts/* terminals
    osc = (
        f"\033]10;{p['fg']}\007"
        f"\033]11;{p['bg']}\007"
        f"\033]12;{p['primary']}\007"
        f"\033]17;{p['secondary_container']}\007"
        f"\033]19;{p['on_secondary_container']}\007"
    )
    for i in range(16):
        osc += f"\033]4;{i};{p[f'c{i}']}\007"

    for pty in glob.glob("/dev/pts/[0-9]*"):
        try:
            if os.access(pty, os.W_OK):
                with open(pty, "wb", buffering=0) as f:
                    f.write(osc.encode("utf-8"))
        except Exception:
            pass

    # 4. Touch kitty.conf and send SIGUSR1 to reload configuration
    kitty_conf = os.path.join(KITTY_CONF_DIR, "kitty.conf")
    if os.path.exists(kitty_conf):
        try:
            os.utime(kitty_conf, None)
        except Exception:
            pass

    subprocess.run(["killall", "-SIGUSR1", "kitty"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def update_alacritty(p):
    alacritty_dir = os.path.dirname(ALACRITTY_THEME_FILE)
    if not os.path.isdir(alacritty_dir):
        return

    content = f"""[colors.primary]
background = '{p['bg']}'
foreground = '{p['fg']}'

[colors.selection]
text = '{p['fg']}'
background = '{p['secondary_container']}'

[colors.cursor]
text = '{p['bg']}'
cursor = '{p['primary']}'

[colors.normal]
black   = '{p['c0']}'
red     = '{p['c1']}'
green   = '{p['c2']}'
yellow  = '{p['c3']}'
blue    = '{p['c4']}'
magenta = '{p['c5']}'
cyan    = '{p['c6']}'
white   = '{p['c7']}'

[colors.bright]
black   = '{p['c8']}'
red     = '{p['c9']}'
green   = '{p['c10']}'
yellow  = '{p['c11']}'
blue    = '{p['c12']}'
magenta = '{p['c13']}'
cyan    = '{p['c14']}'
white   = '{p['c15']}'
"""
    atomic_write(ALACRITTY_THEME_FILE, content)


def update_fastfetch(p):
    c_prim = p['primary'].lstrip('#')
    c_muted = p['outline'].lstrip('#')

    content = f"""{{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "logo": {{
    "source": "Arch",
    "color": {{
      "1": "#{c_prim}",
      "2": "#{c_prim}"
    }},
    "padding": {{
      "top": 1,
      "left": 1,
      "right": 2
    }}
  }},
  "display": {{
    "color": {{
      "keys": "#{c_prim}",
      "title": "#{c_prim}",
      "separator": "#{c_muted}"
    }},
    "separator": " 󰁔 "
  }},
  "modules": [
    {{
      "type": "title",
      "format": "{{user-name}}󰊠{{host-name}}"
    }},
    "separator",
    {{
      "type": "os",
      "key": "OS"
    }},
    {{
      "type": "host",
      "key": "Host"
    }},
    {{
      "type": "kernel",
      "key": "Kernel"
    }},
    {{
      "type": "uptime",
      "key": "Uptime"
    }},
    {{
      "type": "packages",
      "key": "Packages",
      "format": "{{all}}"
    }},
    {{
      "type": "shell",
      "key": "Shell"
    }},
    {{
      "type": "display",
      "key": "Display"
    }},
    {{
      "type": "de",
      "key": "DE"
    }},
    {{
      "type": "wm",
      "key": "WM"
    }},
    {{
      "type": "theme",
      "key": "Theme"
    }},
    {{
      "type": "icons",
      "key": "Icons"
    }},
    {{
      "type": "font",
      "key": "Font"
    }},
    {{
      "type": "cursor",
      "key": "Cursor"
    }},
    {{
      "type": "terminal",
      "key": "Terminal"
    }},
    {{
      "type": "terminalfont",
      "key": "Term Font"
    }},
    {{
      "type": "cpu",
      "key": "CPU",
      "format": "{{1}}"
    }},
    {{
      "type": "gpu",
      "key": "GPU",
      "format": "{{2}}"
    }},
    {{
      "type": "memory",
      "key": "Memory"
    }},
    {{
      "type": "swap",
      "key": "Swap"
    }},
    {{
      "type": "disk",
      "key": "Disk"
    }},
    {{
      "type": "localip",
      "key": "Local IP"
    }},
    {{
      "type": "battery",
      "key": "Battery"
    }},
    {{
      "type": "locale",
      "key": "Locale"
    }},
    "break",
    {{
      "type": "colors",
      "symbol": "circle"
    }}
  ]
}}
"""
    atomic_write(FASTFETCH_CONFIG, content)


def update_fish(p):
    c_prim = p['primary'].lstrip('#')
    c_sec = p['secondary'].lstrip('#')
    c_tert = p['tertiary'].lstrip('#')
    c_fg = p['fg'].lstrip('#')
    c_err = p['error'].lstrip('#')
    c_muted = p['outline'].lstrip('#')
    c_sel = p['secondary_container'].lstrip('#')
    c_quote = p['c2'].lstrip('#')

    content = f"""# Material You Colors for Fish Shell — Panacea Shell auto-sync
set -g fish_color_normal normal
set -g fish_color_command {c_prim}
set -g fish_color_keyword {c_tert}
set -g fish_color_quote {c_quote}
set -g fish_color_redirection {c_sec}
set -g fish_color_end {c_tert}
set -g fish_color_error {c_err}
set -g fish_color_param {c_fg}
set -g fish_color_comment {c_muted}
set -g fish_color_selection --background={c_sel}
set -g fish_color_search_match --background={c_sel}
set -g fish_color_operator {c_prim}
set -g fish_color_escape {c_sec}
set -g fish_color_autosuggestion {c_muted}
set -g fish_color_cwd {c_prim}
set -g fish_color_user {c_tert}
set -g fish_color_host {c_prim}
set -g fish_color_host_remote {c_sec}
set -g fish_color_status {c_err}
set -g fish_pager_color_progress {c_muted}
set -g fish_pager_color_prefix {c_prim} --bold --underline
set -g fish_pager_color_completion {c_fg}
set -g fish_pager_color_description {c_muted}
set -g fish_pager_color_selected_background --background={c_sel}
"""
    atomic_write(FISH_COLORS_FILE, content)

    # Universal vars
    cmd = (
        f"set -U fish_color_command {c_prim}; "
        f"set -U fish_color_keyword {c_tert}; "
        f"set -U fish_color_quote {c_quote}; "
        f"set -U fish_color_redirection {c_sec}; "
        f"set -U fish_color_end {c_tert}; "
        f"set -U fish_color_error {c_err}; "
        f"set -U fish_color_param {c_fg}; "
        f"set -U fish_color_comment {c_muted}; "
        f"set -U fish_color_operator {c_prim}; "
        f"set -U fish_color_escape {c_sec}; "
        f"set -U fish_color_autosuggestion {c_muted}; "
        f"set -U fish_color_cwd {c_prim}; "
        f"set -U fish_color_user {c_tert}; "
        f"set -U fish_color_host {c_prim}; "
        f"set -U fish_color_status {c_err}"
    )
    subprocess.Popen(["fish", "-c", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def update_cava(p):
    content = f"""[general]
mode = normal
framerate = 60
autosens = 1
sensitivity = 100
bars = 0
lower_cutoff_freq = 50
higher_cutoff_freq = 10000

[output]
method = ncurses
orientation = bottom

[color]
gradient = 1
gradient_count = 6
gradient_color_1 = '{p['secondary_container']}'
gradient_color_2 = '{p['primary']}'
gradient_color_3 = '{p['secondary']}'
gradient_color_4 = '{p['tertiary']}'
gradient_color_5 = '{p['c14']}'
gradient_color_6 = '{p['c15']}'

[smoothing]
monstercat = 0
waves = 0
noise_reduction = 77
"""
    atomic_write(CAVA_CONFIG, content)


def update_peaclock(p):
    content = f"""# Peaclock config - Panacea auto-sync
mode clock
set hour-24 on
set date on
set seconds on
set auto-size on
set auto-ratio on
style active-bg {p['primary']}
style active-fg {p['primary']}
style colon-bg {p['tertiary']}
style colon-fg {p['tertiary']}
style inactive-bg clear
style inactive-fg clear
style date {p['outline']}
style text {p['fg']}
style background clear
"""
    atomic_write(PEACLOCK_CONFIG, content)


def main():
    theme_id = get_current_theme_id()
    palette = load_palette(theme_id)

    update_kitty(palette)
    update_alacritty(palette)
    update_fastfetch(palette)
    update_fish(palette)
    update_cava(palette)
    update_peaclock(palette)


if __name__ == "__main__":
    main()
