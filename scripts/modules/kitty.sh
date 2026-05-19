#!/usr/bin/env bash
# =============================================================================
# kitty.sh — Módulo de instalación y configuración de Kitty (macOS + Linux)
#
# La configuración se parte en base + override OS-específico:
#   kitty/.config/kitty/kitty.conf         → base compartida
#   kitty/.config/kitty/kitty.conf-linux   → keybinds alt-based + bspwm hints
#   kitty/.config/kitty/kitty.conf-macos   → keybinds cmd-based + macOS opts
# kitty_configure crea ~/.config/kitty/kitty.conf.local apuntando al variant.
# =============================================================================

kitty_get_version() {
    if command_exists kitty; then
        kitty --version 2>/dev/null | awk '{print $2}'
    fi
}

kitty_install() {
    print_step "Instalando kitty..."
    case "$OS" in
        macos)
            brew install --cask kitty
            ;;
        linux)
            case "$PKG_MANAGER" in
                apt)    sudo apt-get install -y kitty ;;
                pacman) sudo pacman -S --noconfirm kitty ;;
                dnf)    sudo dnf install -y kitty ;;
                *)
                    print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
                    return 1
                    ;;
            esac
            ;;
        *)
            print_error "OS no soportado: ${OS}"
            return 1
            ;;
    esac
}

kitty_update() {
    print_step "Actualizando kitty..."
    case "$OS" in
        macos)
            local output
            output=$(brew upgrade --cask kitty 2>&1)
            if echo "$output" | grep -q "already installed"; then
                print_info "Ya tienes la última versión"
            else
                print_success "Kitty actualizado"
            fi
            ;;
        linux)
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
            ;;
    esac
}

kitty_configure() {
    apply_stow "kitty" || return 1

    # Crear symlink kitty.conf.local → kitty.conf-{macos,linux}.
    # kitty.conf base referencia `include kitty.conf.local` — el variant
    # del OS aporta keybinds y opciones específicas de plataforma.
    local xdg_dir="$HOME/.config/kitty"
    local config_local="$xdg_dir/kitty.conf.local"
    local target=""
    case "$OS" in
        macos) target="kitty.conf-macos" ;;
        linux) target="kitty.conf-linux" ;;
    esac

    if [ -n "$target" ] && [ -f "$xdg_dir/$target" ]; then
        ln -sf "$target" "$config_local"
        print_success "Override ${OS} aplicado: kitty.conf.local → ${target}"
    else
        print_warning "No se encontró ${target} en ${xdg_dir}"
    fi

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
