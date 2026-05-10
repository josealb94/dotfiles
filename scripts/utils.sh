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

# -- ~/.local/bin en PATH (donde caen symlinks de install_apt_tool) ----------
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

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

# -- Instalación de CLI tools (cross-platform) -------------------------------
# Maneja los casos donde el nombre del paquete o del binario difiere por OS.
# Conocidos:
#   fd   → apt: paquete fd-find, binario fdfind  → symlink a ~/.local/bin/fd
#   bat  → apt: paquete bat,     binario batcat  → symlink a ~/.local/bin/bat
#   eza  → apt: no está en repos, descargar binario musl de GitHub releases
#   rg   → todos: paquete ripgrep, binario rg

install_apt_tool() {
    # install_apt_tool <bin_esperado> <paquete_apt> [bin_instalado]
    # Si bin_instalado != bin_esperado, crea symlink en ~/.local/bin/
    local bin="$1"
    local apt_pkg="$2"
    local apt_bin="${3:-$bin}"

    sudo apt-get install -y "$apt_pkg" || return 1

    if [ "$apt_bin" != "$bin" ]; then
        if command_exists "$apt_bin"; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v "$apt_bin")" "$HOME/.local/bin/$bin"
            print_info "Symlink: ~/.local/bin/${bin} → ${apt_bin}"
        else
            print_warning "Paquete ${apt_pkg} instalado pero ${apt_bin} no encontrado"
            return 1
        fi
    fi
}

install_eza_from_github() {
    print_step "eza no está en apt — descargando desde GitHub releases..."

    local arch
    case "$(uname -m)" in
        x86_64)         arch="x86_64-unknown-linux-musl" ;;
        aarch64|arm64)  arch="aarch64-unknown-linux-musl" ;;
        *)
            print_error "Arquitectura $(uname -m) no soportada para eza"
            return 1
            ;;
    esac

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local url="https://github.com/eza-community/eza/releases/latest/download/eza_${arch}.tar.gz"

    if curl -fsSL "$url" -o "$tmp_dir/eza.tar.gz"; then
        tar -xzf "$tmp_dir/eza.tar.gz" -C "$tmp_dir" 2>/dev/null
        if [ -f "$tmp_dir/eza" ]; then
            mkdir -p "$HOME/.local/bin"
            mv "$tmp_dir/eza" "$HOME/.local/bin/eza"
            chmod +x "$HOME/.local/bin/eza"
            print_success "eza instalado en ~/.local/bin/eza"
        else
            print_error "El tarball no contiene el binario eza esperado"
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        print_error "No se pudo descargar eza desde GitHub"
        print_info "URL: $url"
        rm -rf "$tmp_dir"
        return 1
    fi
    rm -rf "$tmp_dir"
}

# -- TUI (whiptail) -----------------------------------------------------------
# Valida que whiptail esté disponible para los menús con checkboxes.
# Si no está, ofrece instalarlo. Si el usuario rechaza o falla, deja
# TUI_BACKEND=fallback para que el selector use prompt numerado.
TUI_BACKEND=""

# Paleta de colores para whiptail (NEWT_COLORS).
# Fondo negro + acentos cyan/magenta para alto contraste.
DOTFILES_NEWT_COLORS='
root=white,black
window=white,black
border=brightcyan,black
title=brightmagenta,black
textbox=white,black
listbox=white,black
actlistbox=black,brightcyan
actsellistbox=black,brightcyan
checkbox=brightgreen,black
actcheckbox=black,brightgreen
emptyscale=,gray
fullscale=,brightcyan
button=black,brightcyan
compactbutton=white,black
actbutton=black,brightmagenta
roottext=lightgray,black
helpline=brightcyan,black
disabledentry=gray,black
'

ensure_tui() {
    if command_exists whiptail; then
        TUI_BACKEND="whiptail"
        export NEWT_COLORS="$DOTFILES_NEWT_COLORS"
        return 0
    fi

    print_warning "whiptail no está instalado (necesario para selección con checkboxes)"
    print_info "Sin whiptail caeremos a un selector numerado en texto plano."

    if ! confirm "¿Instalar whiptail?"; then
        TUI_BACKEND="fallback"
        return 0
    fi

    case "$PKG_MANAGER" in
        brew)   brew install newt ;;
        apt)    sudo apt-get update && sudo apt-get install -y whiptail ;;
        pacman) sudo pacman -S --noconfirm libnewt ;;
        dnf)    sudo dnf install -y newt ;;
        *)
            print_error "PKG_MANAGER no soportado para auto-instalar whiptail"
            TUI_BACKEND="fallback"
            return 0
            ;;
    esac

    # Limpia caché de PATH del shell por si el binario recién instalado
    # no es visto inmediatamente por command -v
    hash -r 2>/dev/null || true

    if command_exists whiptail; then
        TUI_BACKEND="whiptail"
        export NEWT_COLORS="$DOTFILES_NEWT_COLORS"
        print_success "whiptail instalado"
    else
        print_warning "whiptail no quedó disponible, usando selector de texto"
        TUI_BACKEND="fallback"
    fi
}

install_tool() {
    # install_tool <binario>
    # Sabe traducir nombre de binario → paquete correcto por OS.
    local bin="$1"

    if command_exists "$bin"; then
        return 0
    fi

    case "$bin" in
        rg)
            case "$PKG_MANAGER" in
                brew)   brew install ripgrep ;;
                apt)    sudo apt-get install -y ripgrep ;;
                pacman) sudo pacman -S --noconfirm ripgrep ;;
                dnf)    sudo dnf install -y ripgrep ;;
                *) print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"; return 1 ;;
            esac
            ;;
        fd)
            case "$PKG_MANAGER" in
                brew)   brew install fd ;;
                apt)    install_apt_tool fd fd-find fdfind ;;
                pacman) sudo pacman -S --noconfirm fd ;;
                dnf)    sudo dnf install -y fd-find ;;
                *) print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"; return 1 ;;
            esac
            ;;
        bat)
            case "$PKG_MANAGER" in
                brew)   brew install bat ;;
                apt)    install_apt_tool bat bat batcat ;;
                pacman) sudo pacman -S --noconfirm bat ;;
                dnf)    sudo dnf install -y bat ;;
                *) print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"; return 1 ;;
            esac
            ;;
        eza)
            case "$PKG_MANAGER" in
                brew)   brew install eza ;;
                apt)    install_eza_from_github ;;
                pacman) sudo pacman -S --noconfirm eza ;;
                dnf)    sudo dnf install -y eza 2>/dev/null || install_eza_from_github ;;
                *) print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"; return 1 ;;
            esac
            ;;
        *)
            # Genérico: paquete y binario tienen el mismo nombre
            case "$PKG_MANAGER" in
                brew)   brew install "$bin" ;;
                apt)    sudo apt-get install -y "$bin" ;;
                pacman) sudo pacman -S --noconfirm "$bin" ;;
                dnf)    sudo dnf install -y "$bin" ;;
                *) print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"; return 1 ;;
            esac
            ;;
    esac

    if command_exists "$bin"; then
        return 0
    else
        print_error "Falló la instalación de ${bin}"
        return 1
    fi
}
