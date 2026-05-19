#!/usr/bin/env bash
# =============================================================================
# rofi.sh — Módulo de instalación de Rofi (app launcher)
#
# Por ahora solo instalación — la configuración se agrega después.
# =============================================================================

rofi_require_linux() {
    if [ "$OS" != "linux" ]; then
        print_warning "Rofi pensado para Linux (X11)"
        return 1
    fi
}

rofi_get_version() {
    if command_exists rofi; then
        rofi -version 2>/dev/null | head -1 | awk '{print $NF}'
    fi
}

rofi_install() {
    print_step "Instalando rofi via ${PKG_MANAGER}..."
    case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y rofi ;;
        pacman) sudo pacman -S --noconfirm rofi ;;
        dnf)    sudo dnf install -y rofi ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            return 1
            ;;
    esac
}

rofi_main() {
    echo ""
    print_section "App launcher — Rofi"
    echo ""

    rofi_require_linux || return 0

    local version
    version=$(rofi_get_version)

    if [ -n "$version" ]; then
        print_success "Rofi ya instalado (v${version})"
        return 0
    fi

    print_warning "Rofi no está instalado"
    if confirm "¿Instalar rofi?"; then
        if rofi_install && command_exists rofi; then
            print_success "Rofi instalado (v$(rofi_get_version))"
        else
            print_error "Falló la instalación de rofi"
            return 1
        fi
    fi
}
