#!/usr/bin/env bash
# =============================================================================
# ghostty.sh — Módulo de instalación y configuración de Ghostty (macOS)
#
# Ghostty es macOS-only en este dotfiles. La rama Linux fue removida porque
# no había una opción de instalación estable en arm64 al momento de probar.
# =============================================================================

ghostty_require_macos() {
    if [ "$OS" != "macos" ]; then
        print_warning "Ghostty solo está soportado en macOS en este dotfiles"
        print_info "En Linux usar otro emulador (WezTerm, Kitty, Alacritty, etc.)"
        return 1
    fi
}

ghostty_get_version() {
    local version=""
    if [ -d "/Applications/Ghostty.app" ]; then
        version=$(/Applications/Ghostty.app/Contents/MacOS/ghostty --version 2>/dev/null | head -1 | awk '{print $2}')
    fi
    echo "$version"
}

ghostty_install() {
    print_step "Instalando Ghostty..."
    brew install --cask ghostty
}

ghostty_update() {
    print_step "Actualizando Ghostty..."
    local output
    output=$(brew upgrade --cask ghostty 2>&1)
    if echo "$output" | grep -q "already installed"; then
        print_info "Ya tienes la última versión"
    else
        print_success "Ghostty actualizado"
    fi
}

ghostty_configure() {
    # Aplicar config via stow
    apply_stow "ghostty" || return 1

    # Crear symlink config.local → config-macos.
    # config base referencia `config-file = ?config.local` — se cargan los
    # keybinds + opciones macOS-específicas (cmd, macos-option-as-alt, etc.)
    local xdg_dir="$HOME/.config/ghostty"
    local config_local="$xdg_dir/config.local"
    local target="config-macos"

    if [ -f "$xdg_dir/$target" ]; then
        ln -sf "$target" "$config_local"
        print_success "Override macOS aplicado: config.local → ${target}"
    else
        print_warning "No se encontró ${target} en ${xdg_dir}"
    fi

    # Symlink Application Support → XDG config (Ghostty en macOS lee de ambos)
    local macos_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
    local xdg_config="$xdg_dir/config"
    local macos_config="$macos_dir/config"

    if [ -f "$xdg_config" ]; then
        mkdir -p "$macos_dir"

        # Limpiar config vacío auto-generado por Ghostty
        if [ -f "$macos_dir/config.ghostty" ]; then
            rm -f "$macos_dir/config.ghostty"
        fi

        # Backup si existe un config real (no symlink)
        if [ -f "$macos_config" ] && [ ! -L "$macos_config" ]; then
            mv "$macos_config" "${macos_config}.bak"
            print_info "Config anterior respaldado en ${macos_config}.bak"
        fi

        ln -sf "$xdg_config" "$macos_config"
        print_success "Symlink: Application Support → ~/.config/ghostty/config"
    fi

    # Verificar la fuente configurada en el config de Ghostty
    local ghostty_config="$DOTFILES_DIR/ghostty/.config/ghostty/config"
    local configured_font
    configured_font=$(grep "^font-family" "$ghostty_config" | head -1 | sed 's/font-family *= *//')

    if [ -n "$configured_font" ] && ! check_font "$configured_font"; then
        echo ""
        print_warning "Fuente '${configured_font}' no encontrada"
        print_info "Es la fuente configurada en tu config de Ghostty"
        if confirm "¿Instalar ${configured_font}?"; then
            install_nerd_font
        else
            print_info "Puedes instalarla después: brew install --cask font-jetbrains-mono-nerd-font"
            print_info "Ghostty usará su fuente integrada como fallback"
        fi
    fi
}

ghostty_main() {
    echo ""
    print_section "Terminal — Ghostty"
    echo ""

    ghostty_require_macos || return 0

    local version
    version=$(ghostty_get_version)

    if [ -n "$version" ]; then
        print_success "Ghostty instalado (v${version})"
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
            u|U) ghostty_update ;;
            c|C) ghostty_configure ;;
            b|B) ghostty_update; ghostty_configure ;;
            s|S) print_info "Saltando Ghostty" ;;
            *)   print_error "Opción no válida" ;;
        esac
    else
        print_warning "Ghostty no está instalado"
        if confirm "¿Instalar Ghostty?"; then
            if ghostty_install; then
                ghostty_configure
            fi
        fi
    fi
}
