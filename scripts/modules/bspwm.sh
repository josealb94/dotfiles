#!/usr/bin/env bash
# =============================================================================
# bspwm.sh — Módulo de instalación de bspwm + sxhkd (tiling WM)
#
# bspwm es el window manager; sxhkd es su daemon de keybindings.
# Son un combo — no tiene sentido instalar uno sin el otro: bspwm no tiene
# bindings propios y depende 100% de sxhkd para los atajos.
#
# Por ahora solo instalación — la configuración se agrega después.
# =============================================================================

bspwm_require_linux() {
    if [ "$OS" != "linux" ]; then
        print_warning "bspwm + sxhkd solo soportado en Linux (X11)"
        return 1
    fi
}

bspwm_get_version() {
    if command_exists bspwm; then
        bspwm -v 2>/dev/null
    fi
}

sxhkd_get_version() {
    if command_exists sxhkd; then
        sxhkd -v 2>/dev/null | awk '{print $2}'
    fi
}

bspwm_install() {
    print_step "Instalando bspwm + sxhkd via ${PKG_MANAGER}..."
    case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y bspwm sxhkd ;;
        pacman) sudo pacman -S --noconfirm bspwm sxhkd ;;
        dnf)    sudo dnf install -y bspwm sxhkd ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            return 1
            ;;
    esac
}

bspwm_main() {
    echo ""
    print_section "Tiling WM — bspwm + sxhkd"
    echo ""

    bspwm_require_linux || return 0

    local bspwm_v sxhkd_v
    bspwm_v=$(bspwm_get_version)
    sxhkd_v=$(sxhkd_get_version)

    if [ -n "$bspwm_v" ] && [ -n "$sxhkd_v" ]; then
        print_success "bspwm (v${bspwm_v}) y sxhkd (v${sxhkd_v}) ya instalados"
        return 0
    fi

    if [ -z "$bspwm_v" ]; then print_warning "bspwm no está instalado"; fi
    if [ -z "$sxhkd_v" ]; then print_warning "sxhkd no está instalado"; fi

    if confirm "¿Instalar bspwm + sxhkd?"; then
        if bspwm_install && command_exists bspwm && command_exists sxhkd; then
            print_success "bspwm + sxhkd instalados"
            echo ""
            print_info "Para usar bspwm necesitás una sesión X11 dedicada"
            print_info "Eso lo configuramos cuando armemos la config (xsession entry)"
        else
            print_error "Falló la instalación"
            return 1
        fi
    fi
}
