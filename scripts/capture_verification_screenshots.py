#!/usr/bin/env python3
"""Live Wayland Visual Verification Script.

Captures live screenshots using grim and crops of the notch/capsule area for:
1. Super + Z (ControlsView) with lyrics closed.
2. Super + Z (ControlsView) with lyrics expanded (smooth 60 FPS transition, lower menus intact).
3. Super + Z (ControlsView) with lyrics collapsed again.
4. Super + M (IslandMusicView) default music player with new lyrics button.
5. Super + M (IslandMusicView) with lyrics viewer active (unibody layout, synchronized lyrics).
"""

import os
import sys
import time
import subprocess
from pathlib import Path

PANACEA_DIR = Path(os.environ.get('PANACEA_DIR', Path(__file__).resolve().parent.parent))
OUTPUT_DIR = Path(os.environ.get('OUTPUT_DIR', PANACEA_DIR / 'screenshots'))
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def ipc_call(method: str):
    cmd = ['quickshell', '-p', str(PANACEA_DIR), 'ipc', 'call', 'pill', method]
    subprocess.run(cmd, check=True)

def capture(name: str, crop_geometry: str = '750x850+585+0'):
    full_path = OUTPUT_DIR / f"{name}_full.png"
    crop_path = OUTPUT_DIR / f"{name}_crop.png"
    # Capture full screen
    subprocess.run(['grim', str(full_path)], check=True)
    # Crop central area where notch and expanded panel reside
    subprocess.run(['magick', str(full_path), '-crop', crop_geometry, '+repage', str(crop_path)], check=True)
    print(f"Captured: {name} -> {crop_path}")

def main():
    print("Starting visual verification...")

    # Step 0: Ensure we start in collapsed state
    try:
        ipc_call('smartClose')
    except Exception:
        pass
    time.sleep(0.4)

    # Step 1: Open Super + Z (ControlsView)
    print("1. Opening Super + Z (ControlsView)...")
    ipc_call('openControls')
    time.sleep(0.6) # allow 340ms entrance animation to settle
    capture('01_super_z_controls_closed_lyrics')

    # Step 2: Toggle lyrics in Super + Z
    print("2. Expanding lyrics in Super + Z...")
    ipc_call('toggleLyrics')
    time.sleep(0.6) # allow 340ms expansion animation to complete
    capture('02_super_z_controls_expanded_lyrics')

    # Step 3: Collapse lyrics in Super + Z
    print("3. Collapsing lyrics in Super + Z...")
    ipc_call('toggleLyrics')
    time.sleep(0.6) # allow 280ms collapse animation to complete
    capture('03_super_z_controls_collapsed_lyrics')

    # Close controls
    ipc_call('controls')
    time.sleep(0.4)

    # Step 4: Open Super + M (IslandMusicView)
    print("4. Opening Super + M (IslandMusicView)...")
    ipc_call('music')
    time.sleep(0.6)
    capture('04_super_m_island_music_default', crop_geometry='600x500+660+0')

    # Step 5: Toggle lyrics in Super + M
    print("5. Expanding lyrics in Super + M...")
    ipc_call('toggleLyrics')
    time.sleep(0.8) # allow expansion and lyrics fetch/render
    capture('05_super_m_island_music_lyrics_active', crop_geometry='600x700+660+0')

    # Step 6: Collapse lyrics in Super + M
    print("6. Collapsing lyrics in Super + M...")
    ipc_call('toggleLyrics')
    time.sleep(0.6)
    capture('06_super_m_island_music_lyrics_collapsed', crop_geometry='600x500+660+0')

    # Close music island
    ipc_call('music')
    time.sleep(0.4)

    print("All verification screenshots successfully captured!")

if __name__ == '__main__':
    main()
