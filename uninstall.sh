#!/usr/bin/env bash
# ==============================================================================
#  Panacea Shell — Edición Perfeccionada V:NOVZ
#  Uninstaller & Backup Restore Script
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/panacea"
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"

UNATTENDED=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes|--unattended) UNATTENDED=true ;;
    esac
done

echo -e "${RED}${BOLD}Desinstalador de Panacea Shell V:NOVZ${NC}\n"

if [ "$UNATTENDED" != true ]; then
    read -r -p "¿Estás seguro de que deseas desinstalar Panacea Shell? [s/N]: " confirm
    case "$confirm" in
        [sS][iI]|[sS]|[yY][eE][sS]|[yY]) ;;
        *) echo "Operación cancelada."; exit 0 ;;
    esac
fi

# Detener Quickshell si está ejecutando panacea
if pgrep -f "qs -c .*panacea" >/dev/null 2>&1; then
    echo -e "${YELLOW}Deteniendo Quickshell...${NC}"
    pkill -f "qs -c .*panacea" || true
fi

# Buscar respaldos disponibles
backups=($(find "$CONFIG_BASE" -maxdepth 1 -type d -name "panacea.backup*" | sort -r))

if [ ${#backups[@]} -gt 0 ] && [ "$UNATTENDED" != true ]; then
    echo -e "\n${CYAN}Se encontraron respaldos previos:${NC}"
    for i in "${!backups[@]}"; do
        echo "  [$i] ${backups[$i]}"
    done
    echo "  [n] No restaurar ningún respaldo (eliminar completamente)"

    read -r -p "Selecciona una opción para restaurar: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "${#backups[@]}" ]; then
        selected="${backups[$choice]}"
        echo -e "${GREEN}Restaurando respaldo $selected en $INSTALL_DIR...${NC}"
        rm -rf "$INSTALL_DIR"
        mv "$selected" "$INSTALL_DIR"
        echo -e "${GREEN}Respaldo restaurado con éxito.${NC}"
        exit 0
    fi
fi

echo -e "${YELLOW}Eliminando $INSTALL_DIR...${NC}"
rm -rf "$INSTALL_DIR"
echo -e "${GREEN}Panacea Shell ha sido desinstalado correctamente.${NC}"
