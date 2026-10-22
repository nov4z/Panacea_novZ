#!/bin/bash
# Профили питания через power-profiles-daemon.
#
#   get          -> power-saver | balanced | performance
#   set PROFILE  -> переключить профиль
#
# Штатный powerprofilesctl в этой системе не работает: ему нужен
# python-gobject, которого нет. Демон при этом активен, поэтому
# разговариваем с ним напрямую по D-Bus через busctl (входит в systemd).
# Переключение разрешено пользователю активной сессии, sudo не нужно.

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"

case "$1" in
    get)
        out=$(busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null | sed 's/^s //; s/"//g')
        if [ -z "$out" ] && command -v powerprofilesctl >/dev/null 2>&1; then
            out=$(powerprofilesctl get 2>/dev/null)
        fi
        echo "${out:-balanced}"
        ;;
    set)
        [ -z "$2" ] && exit 1
        if ! busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$2" 2>/dev/null; then
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set "$2" 2>/dev/null
            fi
        fi
        ;;
    cycle)
        curr=$(busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null | sed 's/^s //; s/"//g')
        if [ -z "$curr" ] && command -v powerprofilesctl >/dev/null 2>&1; then
            curr=$(powerprofilesctl get 2>/dev/null)
        fi
        case "$curr" in
            power-saver) next="balanced" ;;
            balanced)    next="performance" ;;
            performance) next="power-saver" ;;
            *)           next="balanced" ;;
        esac
        if ! busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$next" 2>/dev/null; then
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set "$next" 2>/dev/null
            fi
        fi
        echo "$next"
        ;;
    *)
        echo "usage: power.sh get | set <power-saver|balanced|performance> | cycle" >&2
        exit 1
        ;;
esac
