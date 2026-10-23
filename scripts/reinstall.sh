#!/usr/bin/env bash
# ==============================================================================
#  Panacea Shell — Reinstalación Limpia desde 0 (V:NOVZ)
#  scripts/reinstall.sh
# ==============================================================================
#
#  Uso:
#    reinstall.sh apply        — Ejecución desasistida (invocada por QML/automatización)
#    reinstall.sh [opciones]   — Ejecución manual interactiva
#
#  Opciones:
#    -y, --yes, --unattended   Omitir confirmación de terminal
#    --dry-run                 Simular sin borrar ni alterar el sistema
#    --no-restart              No reiniciar quickshell.service al finalizar
#    --branch <branch>         Rama git a clonar (defecto: main)
#    --repo <repo>             Repositorio GitHub (defecto: nov4z/Panacea_novZ)
#    --git <url>               URL remota de git
#    --config-dir <dir>        Directorio de destino de configuración (~/.config/panacea)
#    --cache-dir <dir>         Directorio de caché (~/.cache/panacea)
# ==============================================================================
set -u

DRY="${PANACEA_DRYRUN:-0}"
NO_RESTART="${PANACEA_NO_RESTART:-0}"
REPO="${PANACEA_REPO:-nov4z/Panacea_novZ}"
BRANCH="${PANACEA_BRANCH:-main}"
GIT_URL="${PANACEA_GIT:-https://github.com/$REPO.git}"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
INSTALL_DIR="${PANACEA_CONFIG_DIR:-$CONF/panacea}"
CACHE_DIR="${PANACEA_CACHE_DIR:-$CACHE/panacea}"

UNATTENDED=0
FROM_MENU="${PANACEA_FROM_MENU:-0}"

while [ $# -gt 0 ]; do
    case "$1" in
        apply|-y|--yes|--unattended)
            UNATTENDED=1
            shift
            ;;
        --from-menu)
            FROM_MENU=1
            shift
            ;;
        --dry-run)
            DRY=1
            shift
            ;;
        --no-restart)
            NO_RESTART=1
            shift
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            GIT_URL="https://github.com/$REPO.git"
            shift 2
            ;;
        --git)
            GIT_URL="$2"
            shift 2
            ;;
        --config-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Uso: reinstall.sh [apply|-y|--yes|--dry-run|--no-restart|--repo <repo>|--branch <branch>|--git <url>|--config-dir <dir>|--cache-dir <dir>]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$UNATTENDED" -ne 1 ]; then
    echo "======================================================================"
    echo "  ADVERTENCIA DE REINSTALACIÓN LIMPIA — PANACEA SHELL V:NOVZ"
    echo "======================================================================"
    echo "Se reinstalará Panacea_novZ desde cero (rama: $BRANCH, repo: $REPO)."
    echo "SE PERDERÁN TODAS LAS CONFIGURACIONES LOCALES Y SE LIMPIARÁ LA CACHÉ."
    echo ""
    read -r -p "¿Estás completamente seguro de continuar? [s/N]: " confirm
    case "$confirm" in
        [sS][iI]|[sS]|[yY][eE][sS]|[yY]) ;;
        *) echo "Operación cancelada."; exit 0 ;;
    esac
fi

record_status() {
    local st="$1"
    local err="${2:-}"
    if [ "$FROM_MENU" = "1" ]; then
        local ts
        ts="$(date +%s 2>/dev/null || echo 0)"
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
        mkdir -p "$INSTALL_DIR" 2>/dev/null || true
        printf '{"status":"%s","error":"%s","from_menu":true,"timestamp":%s}\n' "$st" "$err" "$ts" > "$CACHE_DIR/reinstall_status.json" 2>/dev/null || true
        printf '{"status":"%s","error":"%s","from_menu":true,"timestamp":%s}\n' "$st" "$err" "$ts" > "$INSTALL_DIR/.reinstall_state" 2>/dev/null || true
    fi
}

# 1. Descarga / Clonación limpia
echo "step=download"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/panacea_reinstall_stage_XXXXXX")"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! command -v git >/dev/null 2>&1; then
    record_status "failed" "nogit"
    echo "error=nogit"
    echo "status=failed"
    exit 1
fi

if [ "$DRY" = "1" ]; then
    echo "info=dry_run_download_simulated"
    mkdir -p "$TMP_DIR/src"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [ -f "$SCRIPT_DIR/../install.sh" ]; then
        cp -a "$SCRIPT_DIR/.."/* "$TMP_DIR/src/" 2>/dev/null || true
    fi
else
    if ! git clone --depth 1 --branch "$BRANCH" "$GIT_URL" "$TMP_DIR/src" >/dev/null 2>&1; then
        if ! git clone --depth 1 "$GIT_URL" "$TMP_DIR/src" >/dev/null 2>&1; then
            record_status "failed" "download"
            echo "error=download"
            echo "status=failed"
            exit 1
        fi
    fi
fi

if [ ! -f "$TMP_DIR/src/install.sh" ]; then
    record_status "failed" "download"
    echo "error=download"
    echo "status=failed"
    exit 1
fi

# 2. Limpieza profunda de caché y configuración previa
echo "step=clean"
if [ "$DRY" = "1" ]; then
    echo "info=dry_run_clean_simulated"
else
    # Limpiar caché de panacea y archivos temporales, excluyendo el staging dir
    rm -rf "$CACHE_DIR"
    find /tmp -maxdepth 1 \( -name "panacea*" -o -name "spicylyrics*" -o -name "cava*" \) -not -path "$TMP_DIR*" -exec rm -rf {} + 2>/dev/null || true
    if [ "$CACHE_DIR" = "$CACHE/panacea" ]; then
        rm -rf "$CACHE/quickshell/qmlcache" "$CACHE/quickshell/qtpipelinecache"* "$CACHE/quickshell/qtshadercache"* 2>/dev/null || true
    fi

    # Si existe una instalación previa, realizar respaldo de seguridad antes de eliminar
    if [ -d "$INSTALL_DIR" ]; then
        BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        BACKUP_PATH="${INSTALL_DIR}.reinstall_backup_${BACKUP_TIMESTAMP}"
        cp -a "$INSTALL_DIR" "$BACKUP_PATH" 2>/dev/null || true
        # Eliminación completa para instalación 100% limpia desde cero
        rm -rf "$INSTALL_DIR"
    fi
fi

# 3. Ejecución de instalación limpia
echo "step=install"
if [ "$DRY" = "1" ]; then
    echo "info=dry_run_install_simulated"
else
    chmod +x "$TMP_DIR/src/install.sh" 2>/dev/null || true
    # Ejecutamos el instalador oficial con la ruta de instalación configurada
    target_parent="$(dirname "$INSTALL_DIR")"
    if ! (cd "$TMP_DIR/src" && env XDG_CONFIG_HOME="$target_parent" PANACEA_INSTALL_DIR="$INSTALL_DIR" bash ./install.sh --yes --skip-deps --no-restart --no-backup >/dev/null 2>&1); then
        if [ -n "${BACKUP_PATH:-}" ] && [ -d "$BACKUP_PATH" ]; then
            rm -rf "$INSTALL_DIR"
            cp -a "$BACKUP_PATH" "$INSTALL_DIR" 2>/dev/null || true
        fi
        record_status "failed" "install"
        echo "error=install"
        echo "status=failed"
        exit 1
    fi

    # Verificar integridad de la nueva instalación
    if [ ! -f "$INSTALL_DIR/qml/shell.qml" ] || [ ! -f "$INSTALL_DIR/settings.json" ]; then
        if [ -n "${BACKUP_PATH:-}" ] && [ -d "$BACKUP_PATH" ]; then
            rm -rf "$INSTALL_DIR"
            cp -a "$BACKUP_PATH" "$INSTALL_DIR" 2>/dev/null || true
        fi
        record_status "failed" "integrity"
        echo "error=install"
        echo "status=failed"
        exit 1
    fi
fi

# 4. Reinicio de Quickshell (desacoplado)
record_status "success" ""
echo "step=restart"
echo "status=done"

if [ "$DRY" = "1" ] || [ "$NO_RESTART" = "1" ]; then
    exit 0
fi

# Reiniciar quickshell.service de forma desacoplada garantizando exactamente 1 proceso
setsid sh -c '
    sleep 1
    if systemctl --user is-active --quiet quickshell.service 2>/dev/null || systemctl --user is-enabled --quiet quickshell.service 2>/dev/null; then
        systemctl --user restart quickshell.service 2>/dev/null || true
    fi
    sleep 1
    if ! pgrep -x qs >/dev/null 2>&1; then
        pkill -x qs 2>/dev/null || true
        sleep 1
        nohup env QSG_RENDER_LOOP=threaded qs -c "'"$INSTALL_DIR"'" </dev/null >/dev/null 2>&1 & disown
    fi
' >/dev/null 2>&1 &

exit 0
