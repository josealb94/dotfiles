#!/usr/bin/env bash
# =============================================================================
# picom.sh — Módulo de instalación de Picom (compositor X11)
#
# Por ahora solo instalación — la configuración se agrega después.
# =============================================================================

picom_require_linux() {
    if [ "$OS" != "linux" ]; then
        print_warning "Picom solo soportado en Linux (X11)"
        return 1
    fi
}

picom_get_version() {
    if command_exists picom; then
        picom --version 2>/dev/null | head -1 | awk '{print $2}'
    fi
}

picom_install() {
    print_step "Instalando picom via ${PKG_MANAGER}..."
    case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y picom ;;
        pacman) sudo pacman -S --noconfirm picom ;;
        dnf)    sudo dnf install -y picom ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            return 1
            ;;
    esac
}

picom_main() {
    echo ""
    print_section "Compositor — Picom"
    echo ""

    picom_require_linux || return 0

    local version
    version=$(picom_get_version)

    if [ -n "$version" ]; then
        print_success "Picom ya instalado (v${version})"
        return 0
    fi

    print_warning "Picom no está instalado"
    if confirm "¿Instalar picom?"; then
        if picom_install && command_exists picom; then
            print_success "Picom instalado (v$(picom_get_version))"
        else
            print_error "Falló la instalación de picom"
            return 1
        fi
    fi
}
