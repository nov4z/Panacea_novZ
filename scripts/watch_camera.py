#!/usr/bin/env python3
import time
import os
import sys
import fcntl
import signal
import glob
import select
import socket
import struct

# V4L2 ioctl constants
VIDIOC_G_CTRL = 0xc008561b
VIDIOC_SUBSCRIBE_EVENT = 0x4020565a
VIDIOC_DQEVENT = 0x80885659
V4L2_EVENT_CTRL = 3
V4L2_CID_PRIVACY = 0x009a0910
V4L2_EVENT_SUB_FL_SEND_INITIAL = 1

# Bloqueo de instancia única: solo 1 watcher de cámara activo a la vez
LOCK_FILE = "/tmp/panacea_watch_camera.lock"
try:
    lock_fd = open(LOCK_FILE, "w")
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except (IOError, OSError):
    sys.exit(0)

# Autodestrucción limpia si el proceso padre (qs) termina
try:
    import ctypes
    libc = ctypes.CDLL("libc.so.6")
    # PR_SET_PDEATHSIG = 1, SIGTERM = 15
    libc.prctl(1, signal.SIGTERM)
except Exception:
    pass


def get_v4l2_privacy(dev_path):
    """Consulta directa del control V4L2_CID_PRIVACY en el dispositivo de video."""
    try:
        fd = os.open(dev_path, os.O_RDWR | os.O_NONBLOCK)
        try:
            buf = struct.pack("ii", V4L2_CID_PRIVACY, 0)
            res = fcntl.ioctl(fd, VIDIOC_G_CTRL, buf)
            _, val = struct.unpack("ii", res)
            return val
        finally:
            os.close(fd)
    except Exception:
        return None


LENOVO_CAM_POWER_PATHS = [
    "/sys/bus/platform/devices/VPC2004:00/camera_power",
    "/sys/devices/pci0000:00/0000:00:1f.0/PNP0C09:00/VPC2004:00/camera_power",
]

def get_lenovo_camera_power():
    """Consulta el estado del interruptor de cámara de Lenovo ideapad_acpi."""
    for path in LENOVO_CAM_POWER_PATHS:
        try:
            with open(path, "r") as f:
                val = f.read().strip()
                if val == "0":
                    return False  # Apagada / bloqueada
                elif val == "1":
                    return True   # Encendida / desbloqueada
        except Exception:
            pass
    return None


def is_camera_blocked():
    """
    Retorna True si la cámara está bloqueada físicamente o deshabilitada.
    Retorna False si la cámara está disponible y desbloqueada.
    """
    vdevs = sorted(glob.glob("/dev/video*"))
    if not vdevs:
        # No hay ningún dispositivo de video en el sistema
        return True

    # 1. Comprobar control de privacidad V4L2 (usado por switches físicos tipo Lenovo LOQ / e-shutter)
    for vdev in vdevs:
        val = get_v4l2_privacy(vdev)
        if val is not None:
            # 1 = Privacidad activa / cámara bloqueada por botón físico
            # 0 = Privacidad desactivada / cámara abierta
            return (val == 1)

    # 2. Comprobar sysfs ideapad_acpi camera_power
    pwr = get_lenovo_camera_power()
    if pwr is not None:
        return not pwr

    # Si hay /dev/video* y no hay indicador de bloqueo, está desbloqueada
    return False


def setup_v4l2_subscriber():
    """Intenta abrir /dev/video0 y suscribirse a eventos de cambio de privacidad."""
    for vdev in sorted(glob.glob("/dev/video*")):
        try:
            fd = os.open(vdev, os.O_RDWR | os.O_NONBLOCK)
            sub = struct.pack("IIIIIIII", V4L2_EVENT_CTRL, V4L2_CID_PRIVACY, V4L2_EVENT_SUB_FL_SEND_INITIAL, 0, 0, 0, 0, 0)
            fcntl.ioctl(fd, VIDIOC_SUBSCRIBE_EVENT, sub)
            return fd
        except Exception:
            try:
                os.close(fd)
            except Exception:
                pass
    return None


def main():
    parent_pid = os.getppid()

    # Netlink socket para escuchar eventos de kernel en tiempo real (plug/unplug)
    nl_sock = None
    try:
        nl_sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, 15)  # NETLINK_KOBJECT_UEVENT
        nl_sock.bind((0, 1))
        nl_sock.setblocking(False)
    except Exception:
        nl_sock = None

    v4l_fd = setup_v4l2_subscriber()

    # Estado inicial: True si está bloqueada, False si está desbloqueada
    last_blocked = is_camera_blocked()

    while True:
        # Si el padre murió o fuimos adoptados por init, salir
        if os.getppid() != parent_pid or os.getppid() == 1:
            break

        read_fds = [nl_sock] if nl_sock else []
        # En Linux V4L2, los eventos se entregan por POLLPRI (exceptfds), NO por POLLIN (readfds)
        except_fds = [v4l_fd] if v4l_fd is not None else []

        try:
            r, _, x = select.select(read_fds, [], except_fds, 0.35)
        except Exception:
            r, x = [], []
            time.sleep(0.35)

        for fd in r:
            if nl_sock and fd == nl_sock:
                try:
                    while True:
                        data = nl_sock.recv(4096)
                        if not data:
                            break
                except (BlockingIOError, OSError):
                    pass

        for fd in x:
            if v4l_fd is not None and fd == v4l_fd:
                try:
                    while True:
                        buf = bytearray(136)
                        fcntl.ioctl(v4l_fd, VIDIOC_DQEVENT, buf)
                except Exception:
                    pass

        # Si el v4l_fd se cerró o no existía, intentar re-suscribir
        if v4l_fd is None and glob.glob("/dev/video*"):
            v4l_fd = setup_v4l2_subscriber()

        try:
            curr_blocked = is_camera_blocked()
            if curr_blocked != last_blocked:
                if curr_blocked:
                    print("blocked", flush=True)
                else:
                    print("unblocked", flush=True)
                last_blocked = curr_blocked
        except Exception:
            pass

    if v4l_fd is not None:
        try:
            os.close(v4l_fd)
        except Exception:
            pass


if __name__ == "__main__":
    main()
