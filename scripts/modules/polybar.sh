#!/usr/bin/env bash
# =============================================================================
# polybar.sh — Módulo de instalación de Polybar (status bar)
#
# Por ahora solo instalación — la configuración se agrega después.
# =============================================================================

polybar_require_linux() {
    if [ "$OS" != "linux" ]; then
        print_warning "Polybar solo soportado en Linux (X11)"
        return 1
    fi
}

polybar_get_version() {
    if command_exists polybar; then
        polybar --version 2>/dev/null | head -1 | awk '{print $2}'
    fi
}

polybar_install() {
    print_step "Instalando polybar via ${PKG_MANAGER}..."
    case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y polybar ;;
        pacman) sudo pacman -S --noconfirm polybar ;;
        dnf)    sudo dnf install -y polybar ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            return 1
            ;;
    esac
}

polybar_main() {
    echo ""
    print_section "Status bar — Polybar"
    echo ""

    polybar_require_linux || return 0

    local version
    version=$(polybar_get_version)

    if [ -n "$version" ]; then
        print_success "Polybar ya instalado (v${version})"
        return 0
    fi

    print_warning "Polybar no está instalado"
    if confirm "¿Instalar polybar?"; then
        if polybar_install && command_exists polybar; then
            print_success "Polybar instalado (v$(polybar_get_version))"
        else
            print_error "Falló la instalación de polybar"
            return 1
        fi
    fi
}
