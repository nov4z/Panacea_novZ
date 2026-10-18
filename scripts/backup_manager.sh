#!/usr/bin/env bash
# Backup Manager for Panacea Shell
set -euo pipefail

BACKUP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/panacea/backups"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/panacea/settings.json"

mkdir -p "$BACKUP_DIR"

# Ensure baseline exists
if [ ! -f "$BACKUP_DIR/baseline_current.json" ] && [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_DIR/baseline_current.json"
fi

cmd="${1:-list}"

case "$cmd" in
    list)
        python3 - <<PYEOF
import os, json, time

backup_dir = "$BACKUP_DIR"
results = []

if os.path.isdir(backup_dir):
    files = sorted(os.listdir(backup_dir), reverse=True)
    for f in files:
        if not f.endswith('.json'):
            continue
        full_path = os.path.join(backup_dir, f)
        st = os.stat(full_path)
        is_baseline = (f == 'baseline_current.json')
        mod_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(st.st_mtime))
        size_kb = round(st.st_size / 1024.0, 1)

        if is_baseline:
            label = "Punto de Restauración Original"
            desc = "Estado exacto guardado antes del rediseño"
        elif f.startswith("backup_"):
            parts = f.replace(".json", "").split("_")
            if len(parts) >= 3:
                tag = " ".join(parts[3:]) if len(parts) > 3 else "Automático"
                label = f"Copia {parts[1][:4]}-{parts[1][4:6]}-{parts[1][6:8]} {parts[2][:2]}:{parts[2][2:4]}:{parts[2][4:6]}"
                desc = f"Etiqueta: {tag}" if len(parts) > 3 else "Instantánea de configuración"
            else:
                label = f
                desc = "Copia de seguridad"
        else:
            label = f
            desc = "Archivo de copia de seguridad"

        results.append({
            "file": f,
            "label": label,
            "desc": desc,
            "date": mod_time,
            "size": f"{size_kb} KB",
            "isBaseline": is_baseline
        })

baseline_items = [x for x in results if x["isBaseline"]]
other_items = [x for x in results if not x["isBaseline"]]
other_items.sort(key=lambda x: x["date"], reverse=True)
final_list = baseline_items + other_items

print(json.dumps(final_list))
PYEOF
        ;;

    create)
        label="${2:-manual}"
        clean_label=$(echo "$label" | tr -cd '[:alnum:]_-')
        ts=$(date +%Y%m%d_%H%M%S)
        if [ -n "$clean_label" ]; then
            dest_file="$BACKUP_DIR/backup_${ts}_${clean_label}.json"
        else
            dest_file="$BACKUP_DIR/backup_${ts}.json"
        fi
        cp "$CONFIG_FILE" "$dest_file"
        echo "{\"status\": \"ok\", \"file\": \"$(basename "$dest_file")\"}"
        ;;

    restore)
        target="${2:-}"
        if [ -z "$target" ]; then
            echo "{\"status\": \"error\", \"message\": \"Falta nombre de archivo\"}"
            exit 1
        fi
        target_path="$BACKUP_DIR/$target"
        if [ ! -f "$target_path" ]; then
            echo "{\"status\": \"error\", \"message\": \"Archivo no encontrado\"}"
            exit 1
        fi
        if ! jq empty "$target_path" 2>/dev/null; then
            echo "{\"status\": \"error\", \"message\": \"El archivo de copia está corrupto o no es JSON válido\"}"
            exit 1
        fi
        cp "$CONFIG_FILE" "$BACKUP_DIR/backup_pre_restore_$(date +%Y%m%d_%H%M%S).json" 2>/dev/null || true
        cp "$target_path" "$CONFIG_FILE"
        echo "{\"status\": \"ok\", \"file\": \"$target\"}"
        ;;

    delete)
        target="${2:-}"
        if [ -z "$target" ] || [ "$target" = "baseline_current.json" ]; then
            echo "{\"status\": \"error\", \"message\": \"No se puede eliminar la copia base\"}"
            exit 1
        fi
        target_path="$BACKUP_DIR/$target"
        if [ -f "$target_path" ]; then
            rm -f "$target_path"
            echo "{\"status\": \"ok\"}"
        else
            echo "{\"status\": \"error\", \"message\": \"Archivo no existe\"}"
        fi
        ;;

    export)
        cat "$CONFIG_FILE"
        ;;

    import)
        tmp_file=$(mktemp)
        cat > "$tmp_file"
        if jq empty "$tmp_file" 2>/dev/null; then
            cp "$CONFIG_FILE" "$BACKUP_DIR/backup_pre_import_$(date +%Y%m%d_%H%M%S).json" 2>/dev/null || true
            cp "$tmp_file" "$CONFIG_FILE"
            rm -f "$tmp_file"
            echo "{\"status\": \"ok\"}"
        else
            rm -f "$tmp_file"
            echo "{\"status\": \"error\", \"message\": \"JSON inválido\"}"
            exit 1
        fi
        ;;

    *)
        echo "Uso: $0 {list|create [label]|restore <file>|delete <file>|export|import}"
        exit 1
        ;;
esac
