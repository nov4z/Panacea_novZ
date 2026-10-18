#!/bin/bash
# Extrae o genera la paleta Material Design 3 (Material You) con matugen
# Modos soportados:
#   wallpaper [ruta_opcional]
#   music [ruta_carátula_opcional]
#   manual <color_hex>

MODE="${1:-wallpaper}"
ARG="$2"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/panacea"
mkdir -p "$CACHE_DIR"
OUT="$CACHE_DIR/matugen.json"

if ! command -v matugen >/dev/null 2>&1; then
    exit 0
fi

get_wallpaper() {
    local wall="$1"
    if [ -z "$wall" ]; then
        local state="$HOME/.config/hypr/wallpaper.conf"
        wall=$(grep -m1 '^\$wallpaper' "$state" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//')
    fi
    wall="${wall/#\~/$HOME}"
    if [[ "$wall" =~ \.(mp4|mkv|webm|mov|avi)$ ]] && [ -f "$wall" ]; then
        local thumb="/tmp/matugen_live_thumb.jpg"
        ffmpeg -y -loglevel error -ss 00:00:02 -i "$wall" -frames:v 1 "$thumb" 2>/dev/null
        [ -f "$thumb" ] && wall="$thumb"
    fi
    echo "$wall"
}

is_monochrome_hex() {
    local h="${1#\#}"
    if [ ${#h} -ne 6 ]; then return 1; fi
    local r=$((16#${h:0:2}))
    local g=$((16#${h:2:2}))
    local b=$((16#${h:4:2}))
    local max=$r
    (( g > max )) && max=$g
    (( b > max )) && max=$b
    local min=$r
    (( g < min )) && min=$g
    (( b < min )) && min=$b
    if (( max - min <= 18 )); then
        return 0
    fi
    return 1
}

case "$MODE" in
    manual)
        HEX="${ARG:-#e08096}"
        [[ "$HEX" =~ ^# ]] || HEX="#$HEX"
        matugen color hex "$HEX" --json hex -m dark --dry-run > "$OUT.tmp" 2>/dev/null
        ;;

    music)
        INPUT="$ARG"
        INPUT="${INPUT#file://}"
        CLEAN_HEX="${INPUT#\#}"
        if [ ${#CLEAN_HEX} -eq 8 ]; then
            CLEAN_HEX="${CLEAN_HEX:2:6}"
        fi

        if [[ "$CLEAN_HEX" =~ ^[0-9a-fA-F]{6}$ ]]; then
            if is_monochrome_hex "$CLEAN_HEX"; then
                matugen color hex "#$CLEAN_HEX" -t scheme-monochrome --json hex -m dark --dry-run > "$OUT.tmp" 2>/dev/null
            else
                matugen color hex "#$CLEAN_HEX" --json hex -m dark --dry-run > "$OUT.tmp" 2>/dev/null
            fi
        elif [ -n "$INPUT" ] && [ -f "$INPUT" ]; then
            # Extraer color con art_color.py para consistencia idéntica con el notch
            SCRIPT_DIR="$(dirname "$0")"
            EXTRACTED="$("$SCRIPT_DIR/art_color.py" "$INPUT" 2>/dev/null | grep -m1 '^#')"
            EXTRACTED="${EXTRACTED#\#}"
            if [ ${#EXTRACTED} -eq 8 ]; then EXTRACTED="${EXTRACTED:2:6}"; fi
            if [[ "$EXTRACTED" =~ ^[0-9a-fA-F]{6}$ ]]; then
                if is_monochrome_hex "$EXTRACTED"; then
                    matugen color hex "#$EXTRACTED" -t scheme-monochrome --json hex -m dark --dry-run > "$OUT.tmp" 2>/dev/null
                else
                    matugen color hex "#$EXTRACTED" --json hex -m dark --dry-run > "$OUT.tmp" 2>/dev/null
                fi
            else
                matugen image "$INPUT" --json hex -m dark --source-color-index 0 --dry-run > "$OUT.tmp" 2>/dev/null
            fi
        else
            # Fallback a fondo de pantalla si no hay música o carátula disponible
            WALL=$(get_wallpaper "")
            if [ -f "$WALL" ]; then
                matugen image "$WALL" --json hex -m dark --source-color-index 0 --dry-run > "$OUT.tmp" 2>/dev/null
                if [ ! -s "$OUT.tmp" ] || ! grep -q '"colors"' "$OUT.tmp" 2>/dev/null; then
                    matugen image "$WALL" --json hex -m dark --source-color-index 0 --dry-run > "$OUT.tmp" 2>/dev/null
                fi
            fi
        fi
        ;;

    wallpaper|*)
        WALL=$(get_wallpaper "$ARG")
        if [ -f "$WALL" ]; then
            matugen image "$WALL" --json hex -m dark --source-color-index 0 --dry-run > "$OUT.tmp" 2>/dev/null
            if [ ! -s "$OUT.tmp" ] || ! grep -q '"colors"' "$OUT.tmp" 2>/dev/null; then
                matugen image "$WALL" --json hex -m dark --dry-run > "$OUT.tmp" 2>/dev/null
            fi
        fi
        ;;
esac

# Asegurar que el JSON sea válido y contenga colors antes de sobrescribir
if [ -s "$OUT.tmp" ] && grep -q '"colors"' "$OUT.tmp" 2>/dev/null; then
    mv -f "$OUT.tmp" "$OUT"
    SCRIPT_DIR="$(dirname "$0")"
    if [ -f "$SCRIPT_DIR/sync_terminal_colors.py" ]; then
        python3 "$SCRIPT_DIR/sync_terminal_colors.py"
    fi
fi


