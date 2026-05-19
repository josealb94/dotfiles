#!/usr/bin/env bash
# =============================================================================
# kitty.sh — Módulo de instalación y configuración de Kitty (Linux)
#
# Solo Linux. En macOS preferimos Ghostty.
# =============================================================================

kitty_require_linux() {
    if [ "$OS" != "linux" ]; then
        print_warning "Este módulo está pensado para Linux"
        print_info "En macOS instalá kitty con: brew install --cask kitty"
        return 1
    fi
}

kitty_get_version() {
    if command_exists kitty; then
        kitty --version 2>/dev/null | awk '{print $2}'
    fi
}

kitty_install() {
    print_step "Instalando kitty via ${PKG_MANAGER}..."
    case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y kitty ;;
        pacman) sudo pacman -S --noconfirm kitty ;;
        dnf)    sudo dnf install -y kitty ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            return 1
            ;;
    esac
}

kitty_update() {
    print_step "Actualizando kitty via ${PKG_MANAGER}..."
    case "$PKG_MANAGER" in
        apt)    sudo apt-get update && sudo apt-get install -y --only-upgrade kitty ;;
        pacman) sudo pacman -Syu --noconfirm kitty ;;
        dnf)    sudo dnf upgrade -y kitty ;;
        *)
            print_warning "Actualización automática no disponible para ${PKG_MANAGER}"
            return 1
            ;;
    esac
    print_success "Kitty actualizado (v$(kitty_get_version))"
}

kitty_configure() {
    apply_stow "kitty" || return 1

    # Verificar la fuente configurada en kitty.conf
    local kitty_config="$DOTFILES_DIR/kitty/.config/kitty/kitty.conf"
    local configured_font
    configured_font=$(grep "^font_family" "$kitty_config" | head -1 | awk '{$1=""; sub(/^ +/, ""); print}')

    if [ -n "$configured_font" ] && ! check_font "$configured_font"; then
        echo ""
        print_warning "Fuente '${configured_font}' no encontrada"
        print_info "Es la fuente configurada en tu kitty.conf"
        if confirm "¿Instalar ${configured_font}?"; then
            install_nerd_font
        else
            print_info "Kitty usará su fuente integrada como fallback"
        fi
    fi
}

kitty_main() {
    echo ""
    print_section "Terminal — Kitty"
    echo ""

    kitty_require_linux || return 0

    local version
    version=$(kitty_get_version)

    if [ -n "$version" ]; then
        print_success "Kitty instalado (v${version})"
        echo ""
        echo -e "    ${BOLD}u${NC}) Actualizar"
        echo -e "    ${BOLD}c${NC}) Aplicar/actualizar configuración"
        echo -e "    ${BOLD}b${NC}) Ambos (actualizar + configurar)"
        echo -e "    ${BOLD}s${NC}) Saltar"
        echo ""
        local action
        print_prompt "Opción"
        read -r action

        case "$action" in
            u|U) kitty_update ;;
            c|C) kitty_configure ;;
            b|B) kitty_update; kitty_configure ;;
            s|S) print_info "Saltando Kitty" ;;
            *)   print_error "Opción no válida" ;;
        esac
    else
        print_warning "Kitty no está instalado"
        if confirm "¿Instalar kitty?"; then
            if kitty_install && command_exists kitty; then
                print_success "Kitty instalado (v$(kitty_get_version))"
                kitty_configure
            else
                print_error "Falló la instalación de kitty"
                return 1
            fi
        fi
    fi
}
