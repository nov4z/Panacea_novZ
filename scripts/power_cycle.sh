#!/bin/bash
# Cicla los perfiles de energía entre:
#   power-saver (Modo Ahorro / Tranquilo)
#   balanced    (Modo Equilibrado)
#   performance (Modo Rendimiento)

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
NEXT=$("$SCRIPT_DIR/power.sh" cycle)

# Si quickshell está corriendo, notificar vía IPC para respuesta instantánea (además del monitor D-Bus)
if command -v qs >/dev/null 2>&1; then
    qs -c ~/.config/panacea ipc call pill onProfileSwitched "$NEXT" >/dev/null 2>&1 &
fi

echo "$NEXT"
