#!/usr/bin/env python3
import time
import os
import sys
import fcntl
import signal

# Bloqueo de instancia única: solo 1 watcher puede existir en el sistema
LOCK_FILE = "/tmp/panacea_watch_power.lock"
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

import subprocess

SYSFS = "/sys/firmware/acpi/platform_profile"

MAP = {
    "low-power": "power-saver",
    "power-saver": "power-saver",
    "balanced": "balanced",
    "performance": "performance",
    "max-power": "performance",
    "custom": "balanced",
}

def read_profile():
    try:
        if os.path.exists(SYSFS):
            with open(SYSFS, "r") as f:
                raw = f.read().strip()
                return MAP.get(raw, raw)
        else:
            # Universal fallback for generic PCs without ACPI platform_profile
            cmd = "busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null"
            out = subprocess.check_output(cmd, shell=True, text=True, timeout=1).strip()
            if out.startswith('s '):
                out = out[2:].strip('"')
            return MAP.get(out, out)
    except Exception:
        return ""

def main():
    last_profile = read_profile()
    parent_pid = os.getppid()

    while True:
        # Si el padre murió y fuimos adoptados por init (PID 1), salir
        if os.getppid() != parent_pid or os.getppid() == 1:
            break

        try:
            curr = read_profile()
            if curr and curr != last_profile:
                if last_profile:
                    print(curr, flush=True)
                last_profile = curr
        except Exception:
            pass
        time.sleep(0.20)

if __name__ == "__main__":
    main()
