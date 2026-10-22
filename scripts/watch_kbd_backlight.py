#!/usr/bin/env python3
import time
import os
import sys
import fcntl
import signal

# Bloqueo de instancia única: solo 1 watcher puede existir en el sistema
LOCK_FILE = "/tmp/panacea_watch_kbd.lock"
try:
    lock_fd = open(LOCK_FILE, "w")
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except (IOError, OSError):
    sys.exit(0)

# Autodestrucción si el proceso padre (qs) termina
try:
    import ctypes
    libc = ctypes.CDLL("libc.so.6")
    # PR_SET_PDEATHSIG = 1, SIGTERM = 15
    libc.prctl(1, signal.SIGTERM)
except Exception:
    pass

import glob

def get_sysfs_path():
    candidates = [
        "/sys/class/leds/platform::kbd_backlight/brightness",
        "/sys/class/leds/*kbd_backlight*/brightness",
        "/sys/class/leds/*::kbd_backlight/brightness",
        "/sys/class/leds/*keyboard*/brightness",
    ]
    for pattern in candidates:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    return "/sys/class/leds/platform::kbd_backlight/brightness"

SYSFS = get_sysfs_path()

def read_level():
    try:
        with open(SYSFS, "r") as f:
            raw = f.read().strip()
            if raw.isdigit():
                return int(raw)
    except Exception:
        pass
    return None

def main():
    last_level = read_level()
    parent_pid = os.getppid()

    while True:
        # Si el padre murió y fuimos adoptados por init (PID 1), salir
        if os.getppid() != parent_pid or os.getppid() == 1:
            break

        try:
            curr = read_level()
            if curr is not None and last_level is not None and curr != last_level:
                print(str(curr), flush=True)
                last_level = curr
            elif last_level is None and curr is not None:
                last_level = curr
        except Exception:
            pass
        time.sleep(0.12)

if __name__ == "__main__":
    main()
