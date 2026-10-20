#!/usr/bin/env bash
# ==============================================================================
#  Panacea Shell — Edición Perfeccionada V:NOVZ
#  Dynamic Notch & Unified Desktop Shell for Wayland / Hyprland (Quickshell)
#  Installer & Setup Script
# ==============================================================================

set -e

# --- Terminal Styling ---
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Paths & Directories ---
INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/panacea"
BACKUP_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/panacea.backup"
SCRIPT_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPEWIRE_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire-pulse.conf.d"
HYPR_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

UNATTENDED=false
SKIP_DEPS=false

for arg in "$@"; do
    case "$arg" in
        -y|--yes|--unattended) UNATTENDED=true ;;
        --skip-deps) SKIP_DEPS=true ;;
        -h|--help)
            echo "Uso: ./install.sh [OPCIONES]"
            echo "Opciones:"
            echo "  -y, --yes          Modo automático (sin confirmaciones interactivas)"
            echo "  --skip-deps        Omitir instalación de dependencias del sistema"
            echo "  -h, --help         Mostrar esta ayuda"
            exit 0
            ;;
    esac
done

print_banner() {
    clear 2>/dev/null || true
    echo -e "${PURPLE}${BOLD}"
    cat << "BANNER"
  ____                                      ____  _          _ _ 
 |  _ \ __ _ _ __   __ _  ___ ___  __ _   / ___|| |__   ___| | |
 | |_) / _` | '_ \ / _` |/ __/ _ \/ _` |  \___ \| '_ \ / _ \ | |
 |  __/ (_| | | | | (_| | (_|  __/ (_| |   ___) | | | |  __/ | |
 |_|   \__,_|_| |_|\__,_|\___\___|\__,_|  |____/|_| |_|\___|_|_|
                V E R S I Ó N :  N O V Z
BANNER
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}  Dynamic Notch & Control Center Suite for Wayland / Hyprland${NC}"
    echo -e "${DIM}  Modificación de Panacea (por EnsixD: https://github.com/EnsixD/Panacea) por NovZ${NC}\n"
}

log_info()    { echo -e "  ${BLUE}${BOLD}ℹ${NC}  $1"; }
log_success() { echo -e "  ${GREEN}${BOLD}✔${NC}  $1"; }
log_warn()    { echo -e "  ${YELLOW}${BOLD}⚠${NC}  $1"; }
log_error()   { echo -e "  ${RED}${BOLD}✖${NC}  $1"; }
log_step()    { echo -e "\n${BOLD}${CYAN}[$1]${NC} ${BOLD}$2${NC}"; }

confirm() {
    if [ "$UNATTENDED" = true ]; then return 0; fi
    local prompt="$1"
    local default="$2"
    local response
    if [ "$default" = "Y" ]; then
        prompt="$prompt [S/n]: "
    else
        prompt="$prompt [s/N]: "
    fi
    read -r -p "$prompt" response
    response="${response:-$default}"
    case "$response" in
        [sS][iI]|[sS]|[yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# --- 1. Verificación de Entorno ---
check_environment() {
    log_step "1/6" "Comprobando entorno de ejecución..."

    if [ "$EUID" -eq 0 ]; then
        log_warn "Se recomienda ejecutar este script como usuario normal (no root)."
        if ! confirm "¿Deseas continuar como root?" "N"; then
            exit 1
        fi
    fi

    # Verificar si estamos en sesión Wayland
    if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        log_success "Sesión Wayland detectada ($WAYLAND_DISPLAY)."
    else
        log_warn "No se detectó sesión Wayland activa. Panacea Shell está optimizado para Wayland/Hyprland."
    fi
}

# --- 2. Dependencias del Sistema ---
install_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        log_info "Omitiendo instalación de dependencias (--skip-deps)."
        return 0
    fi

    log_step "2/6" "Verificando dependencias del sistema..."

    local arch_deps=(
        "quickshell"
        "qt6-declarative"
        "qt6-multimedia"
        "qt6-svg"
        "qt6-5compat"
        "qt6-wayland"
        "python"
        "python-scipy"
        "python-numpy"
        "playerctl"
        "pipewire"
        "wireplumber"
        "pipewire-pulse"
        "cava"
        "wl-clipboard"
        "grim"
        "slurp"
        "jq"
        "libnotify"
        "ttf-jetbrains-mono-nerd"
    )

    if command -v pacman >/dev/null 2>&1; then
        log_info "Sistema basado en Arch Linux detectado."
        
        local AUR_HELPER=""
        if command -v yay >/dev/null 2>&1; then
            AUR_HELPER="yay"
        elif command -v paru >/dev/null 2>&1; then
            AUR_HELPER="paru"
        fi

        local missing_pkgs=()
        for pkg in "${arch_deps[@]}"; do
            if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
                missing_pkgs+=("$pkg")
            fi
        done

        if [ ${#missing_pkgs[@]} -eq 0 ]; then
            log_success "Todas las dependencias esenciales están instaladas."
        else
            log_warn "Paquetes faltantes detectados: ${missing_pkgs[*]}"
            if confirm "¿Deseas instalar los paquetes faltantes ahora?" "Y"; then
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --needed "${missing_pkgs[@]}"
                else
                    sudo pacman -S --needed "${missing_pkgs[@]}"
                fi
                log_success "Dependencias instaladas correctamente."
            else
                log_warn "Continuando sin instalar paquetes del sistema."
            fi
        fi
    else
        log_info "Gestor de paquetes no Arch detectado. Asegúrate de tener Quickshell, Qt6 y Python instalados."
    fi
}

# --- 3. Respaldo de Configuración Previa ---
backup_existing() {
    log_step "3/6" "Preparando directorio de destino..."

    if [ -d "$INSTALL_DIR" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local target_backup="${BACKUP_BASE}_${timestamp}"
        log_warn "Se detectó una instalación existente en $INSTALL_DIR"
        log_info "Creando respaldo de seguridad en: $target_backup"
        cp -r "$INSTALL_DIR" "$target_backup"
        log_success "Respaldo completado con éxito."
    fi

    mkdir -p "$INSTALL_DIR"
}

# --- 4. Instalación de Archivos y Permisos ---
deploy_files() {
    log_step "4/6" "Instalando Panacea Shell V:NOVZ..."

    log_info "Copiando componentes de interfaz, scripts, sonidos y temas..."
    
    # Copiar recursivamente ignorando metadatos git o backups
    rsync -a --exclude='.git' \
             --exclude='.gitignore' \
             --exclude='install.sh' \
             --exclude='uninstall.sh' \
             --exclude='.agents' \
             --exclude='backups' \
             --exclude='__pycache__' \
             --exclude='*.pyc' \
             --exclude='sounds/tmp' \
             "$SCRIPT_SRC_DIR/" "$INSTALL_DIR/"

    # Si no existe settings.json, inicializar desde ejemplo
    if [ ! -f "$INSTALL_DIR/settings.json" ]; then
        if [ -f "$INSTALL_DIR/settings.json.example" ]; then
            cp "$INSTALL_DIR/settings.json.example" "$INSTALL_DIR/settings.json"
            log_success "Inicializado settings.json predeterminado."
        fi
    fi

    log_info "Configurando permisos de ejecución..."
    chmod +x "$INSTALL_DIR"/scripts/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/scripts/*.py 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/sound_engine.py 2>/dev/null || true
    chmod +x "$INSTALL_DIR"/generate_*.py 2>/dev/null || true

    # Compatibilidad transparente para arranque con 'qs -c ~/.config/panacea' y 'qs -c ~/.config/panacea/qml'
    if [ -d "$INSTALL_DIR/qml" ]; then
        log_info "Vinculando componentes QML para compatibilidad de arranque..."
        for f in "$INSTALL_DIR/qml/"*.qml "$INSTALL_DIR/qml/Themes.js"; do
            [ -f "$f" ] && ln -sf "qml/$(basename "$f")" "$INSTALL_DIR/$(basename "$f")"
        done
        ln -sfn ../assets "$INSTALL_DIR/qml/assets" 2>/dev/null || true
        ln -sfn ../scripts "$INSTALL_DIR/qml/scripts" 2>/dev/null || true
        ln -sfn ../sounds "$INSTALL_DIR/qml/sounds" 2>/dev/null || true
    fi

    if [ -x "$INSTALL_DIR/scripts/geninput.sh" ]; then
        "$INSTALL_DIR/scripts/geninput.sh" >/dev/null 2>&1 || true
    fi

    log_success "Archivos desplegados y permisos configurados en $INSTALL_DIR"
}

# --- 5. Optimización Acústica PipeWire (Spotify Fix) ---
setup_pipewire_fix() {
    log_step "5/6" "Configuración acústica y fix de volumen PipeWire..."

    local conf_file="$PIPEWIRE_CONF_DIR/10-no-stream-restore.conf"
    if [ -f "$conf_file" ]; then
        log_success "El fix de volumen para PipeWire ya se encuentra activo."
    else
        log_info "Solución al problema de volumen en Spotify/PipeWire:"
        log_info "Evita que el volumen se baje automáticamente al 13% en los cambios de pista."
        if confirm "¿Deseas aplicar la optimización acústica de PipeWire?" "Y"; then
            mkdir -p "$PIPEWIRE_CONF_DIR"
            cat << 'PWEOF' > "$conf_file"
pulse.properties = {
    pulse.cmd.stream-restore = false
}
PWEOF
            log_success "Configuración guardada en $conf_file."
            if systemctl --user is-active --quiet pipewire-pulse.service 2>/dev/null; then
                systemctl --user restart pipewire-pulse.service
                log_success "Servicio pipewire-pulse reiniciado exitosamente."
            fi
        fi
    fi
}

# --- 6. Integración con Hyprland ---
setup_hyprland() {
    log_step "6/6" "Integración con Hyprland..."

    if [ -f "$HYPR_CONF" ]; then
        if grep -q "panacea" "$HYPR_CONF" || grep -q "qs -c .*panacea" "$HYPR_CONF"; then
            log_success "Hyprland ya contiene referencias a Panacea Shell."
        else
            log_info "Para autoiniciar Panacea Shell con tu sesión de Hyprland, añade:"
            echo -e "${YELLOW}  exec-once = qs -c $INSTALL_DIR${NC}"
            if confirm "¿Deseas que este script añada la línea de autoinicio a tu hyprland.conf?" "Y"; then
                echo -e "\n# Panacea Shell V:NOVZ Autostart\nexec-once = qs -c $INSTALL_DIR" >> "$HYPR_CONF"
                log_success "Añadido exec-once a $HYPR_CONF."
            fi
        fi
    else
        log_info "No se encontró $HYPR_CONF. Puedes iniciarlo manualmente con:"
        echo -e "${YELLOW}  qs -c $INSTALL_DIR &${NC}"
    fi

    # Verificar si Quickshell está corriendo actualmente para recargar
    if pgrep -x qs >/dev/null 2>&1 || systemctl --user is-active --quiet quickshell.service 2>/dev/null; then
        if confirm "¿Deseas reiniciar Quickshell ahora para cargar la nueva versión?" "Y"; then
            if systemctl --user is-active --quiet quickshell.service 2>/dev/null; then
                systemctl --user restart quickshell.service
            else
                pkill -x qs || true
                sleep 1
                nohup qs -c "$INSTALL_DIR" >/dev/null 2>&1 &
            fi
            log_success "Quickshell recargado con Panacea Shell V:NOVZ."
        fi
    fi
}

# --- Resumen Final ---
print_summary() {
    echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}      ¡INSTALACIÓN DE PANACEA SHELL V:NOVZ COMPLETADA CON ÉXITO!      ${NC}"
    echo -e "${GREEN}${BOLD}======================================================================${NC}\n"

    echo -e "${BOLD}Ruta de instalación:${NC} ${CYAN}$INSTALL_DIR${NC}"
    echo -e "${BOLD}Versión instalada:${NC}   ${PURPLE}1.0.14-novz (V:NOVZ)${NC}"

    echo -e "\n${BOLD}${CYAN}Atajos de teclado recomendados (Hyprland):${NC}"
    echo -e "  ${BOLD}SUPER + M${NC}          Cápsula Musical & Notch Dinámico (Letras sincronizadas)"
    echo -e "  ${BOLD}SUPER + Z${NC}          Centro de Control Unibody (Volumen, Brillo, Toggles)"
    echo -e "  ${BOLD}SUPER + I${NC}          Ajustes del Notch & Estudio de Sonido Acústico"
    echo -e "  ${BOLD}SUPER + Space${NC}      Lanzador de aplicaciones"
    echo -e "  ${BOLD}SUPER + SHIFT + W${NC}  Menú rápido de Wi-Fi"
    echo -e "  ${BOLD}SUPER + SHIFT + B${NC}  Menú rápido de Bluetooth"

    echo -e "\n${BOLD}${CYAN}Control directo por terminal:${NC}"
    echo -e "  ${DIM}qs -c $INSTALL_DIR ipc call pill <comando>${NC}"
    echo -e "  Ejemplos: ${DIM}music | controls | toggleLyrics | wifi | bluetooth${NC}\n"

    echo -e "${DIM}Para desinstalar o restaurar respaldos, ejecuta ./uninstall.sh${NC}\n"
}

main() {
    print_banner
    check_environment
    install_dependencies
    backup_existing
    deploy_files
    setup_pipewire_fix
    setup_hyprland
    print_summary
}

main "$@"
