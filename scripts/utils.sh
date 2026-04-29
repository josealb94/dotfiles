#!/usr/bin/env bash
# =============================================================================
# utils.sh — Funciones utilitarias para el instalador de dotfiles
# =============================================================================

# -- Homebrew PATH (bash no lo tiene por defecto en macOS) --------------------
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# -- Colores ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -- Variables globales (se llenan con detect_os) -----------------------------
OS=""
OS_ID=""
ARCH=""
PKG_MANAGER=""

# -- Detección de sistema operativo -------------------------------------------
detect_os() {
    ARCH="$(uname -m)"
    case "$(uname -s)" in
        Darwin)
            OS="macos"
            PKG_MANAGER="brew"
            ;;
        Linux)
            OS="linux"
            if [ -f /etc/os-release ]; then
                OS_ID=$(. /etc/os-release && echo "$ID")
                case "$OS_ID" in
                    ubuntu|debian|kali|parrot|linuxmint|pop)
                        PKG_MANAGER="apt"
                        ;;
                    arch|manjaro|endeavouros)
                        PKG_MANAGER="pacman"
                        ;;
                    fedora)
                        PKG_MANAGER="dnf"
                        ;;
                esac
            fi
            ;;
        *)
            OS="unknown"
            ;;
    esac

    print_info "Sistema: ${BOLD}${OS}${NC}${CYAN} (${OS_ID:-native}) — ${ARCH}${NC}"
    print_info "Gestor de paquetes: ${BOLD}${PKG_MANAGER}${NC}"
}

# -- Funciones de impresión ---------------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║          ⚙  Dotfiles Installer          ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

print_section()  { echo -e "${BLUE}${BOLD}▸ $1${NC}"; }
print_success()  { echo -e "${GREEN}  ✔ $1${NC}"; }
print_error()    { echo -e "${RED}  ✖ $1${NC}"; }
print_warning()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
print_info()     { echo -e "${CYAN}  ℹ $1${NC}"; }
print_step()     { echo -e "${DIM}  → $1${NC}"; }

print_prompt() {
    echo -ne "${MAGENTA}  ❯ ${1}: ${NC}"
}

# -- Helpers ------------------------------------------------------------------
confirm() {
    local message="${1:-¿Continuar?}"
    local response
    echo -ne "${YELLOW}  $message [s/N]: ${NC}"
    read -r response
    case "$response" in
        [sS]|[sS][iI]) return 0 ;;
        *) return 1 ;;
    esac
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# -- GNU Stow ----------------------------------------------------------------
ensure_stow() {
    if command_exists stow; then
        return 0
    fi

    print_warning "GNU Stow no está instalado (requerido para aplicar configuraciones)"
    if confirm "¿Instalar GNU Stow?"; then
        case "$PKG_MANAGER" in
            brew)   brew install stow ;;
            apt)    sudo apt-get update && sudo apt-get install -y stow ;;
            pacman) sudo pacman -S --noconfirm stow ;;
            dnf)    sudo dnf install -y stow ;;
            *)
                print_error "No se pudo instalar stow automáticamente"
                print_info "Instálalo manualmente y vuelve a ejecutar el script"
                return 1
                ;;
        esac
        print_success "GNU Stow instalado"
    else
        print_error "Stow es necesario para continuar"
        return 1
    fi
}

apply_stow() {
    local package="$1"
    local stow_dir="${2:-$DOTFILES_DIR}"
    local target="${3:-$HOME}"

    ensure_stow || return 1

    print_step "Aplicando configuración de ${BOLD}${package}${NC}${DIM}...${NC}"

    # Verificar que el paquete existe
    if [ ! -d "$stow_dir/$package" ]; then
        print_error "Paquete '$package' no encontrado en $stow_dir"
        return 1
    fi

    # Intentar stow; si hay conflicto, preguntar si hacer backup
    local stow_output
    stow_output=$(stow -d "$stow_dir" -t "$target" "$package" 2>&1)
    local stow_exit=$?

    if [ $stow_exit -ne 0 ]; then
        if echo "$stow_output" | grep -q "existing target"; then
            print_warning "Hay archivos existentes que entran en conflicto"
            echo "$stow_output" | grep "existing target" | while read -r line; do
                echo -e "${DIM}    $line${NC}"
            done
            if confirm "¿Hacer backup y reemplazar?"; then
                # Adoptar archivos existentes y luego re-stow
                stow -d "$stow_dir" -t "$target" --adopt "$package" 2>/dev/null
                # Restaurar los archivos del repo (adopt modifica los del repo)
                (cd "$stow_dir" && git checkout -- "$package/" 2>/dev/null || true)
                print_success "Configuración de ${package} aplicada (backup adoptado)"
            else
                print_info "Saltando configuración de ${package}"
                return 1
            fi
        else
            print_error "Error aplicando stow: $stow_output"
            return 1
        fi
    else
        print_success "Configuración de ${package} aplicada"
    fi
}

# -- Nerd Fonts ---------------------------------------------------------------
# Verifica si una fuente específica está instalada.
# Uso: check_font "JetBrainsMono Nerd Font"
# Sin argumento: verifica si hay cualquier Nerd Font
check_font() {
    local font_name="${1:-}"
    local search_term

    if [ -n "$font_name" ]; then
        search_term="$font_name"
    else
        search_term="Nerd"
    fi

    case "$OS" in
        macos)
            find ~/Library/Fonts /Library/Fonts \
                -iname "*$(echo "$search_term" | sed 's/ /*/g')*" \
                -print -quit 2>/dev/null | grep -q .
            ;;
        linux)
            fc-list 2>/dev/null | grep -qi "$search_term"
            ;;
        *)
            return 1
            ;;
    esac
}

install_nerd_font() {
    local font_name="JetBrainsMono"
    print_step "Instalando ${font_name} Nerd Font..."

    case "$PKG_MANAGER" in
        brew)
            brew install --cask font-jetbrains-mono-nerd-font
            ;;
        *)
            # Descarga directa desde GitHub
            local tmp_dir
            tmp_dir=$(mktemp -d)
            local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.tar.xz"
            print_step "Descargando desde GitHub..."
            if curl -fsSL "$url" -o "$tmp_dir/${font_name}.tar.xz"; then
                local font_dir
                if [ "$OS" = "linux" ]; then
                    font_dir="$HOME/.local/share/fonts"
                else
                    font_dir="$HOME/Library/Fonts"
                fi
                mkdir -p "$font_dir"
                tar -xf "$tmp_dir/${font_name}.tar.xz" -C "$font_dir"
                if [ "$OS" = "linux" ]; then
                    fc-cache -fv >/dev/null 2>&1
                fi
                print_success "${font_name} Nerd Font instalada"
            else
                print_error "No se pudo descargar la fuente"
                print_info "Descárgala manualmente: https://www.nerdfonts.com/font-downloads"
            fi
            rm -rf "$tmp_dir"
            ;;
    esac
}
