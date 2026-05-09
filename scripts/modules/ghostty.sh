#!/usr/bin/env bash
# =============================================================================
# ghostty.sh — Módulo de instalación y configuración de Ghostty
# =============================================================================

ghostty_get_version() {
    local version=""
    case "$OS" in
        macos)
            if [ -d "/Applications/Ghostty.app" ]; then
                version=$(/Applications/Ghostty.app/Contents/MacOS/ghostty --version 2>/dev/null | head -1 | awk '{print $2}')
            fi
            ;;
        linux)
            # Cualquier install que ponga `ghostty` en PATH (Snap, source build, etc.)
            if command_exists ghostty; then
                version=$(ghostty --version 2>/dev/null | head -1 | awk '{print $2}')
            # Flatpak: el binario no queda en PATH, hay que invocar via flatpak run
            elif command_exists flatpak && flatpak info com.mitchellh.ghostty >/dev/null 2>&1; then
                version=$(flatpak run com.mitchellh.ghostty --version 2>/dev/null | head -1 | awk '{print $2}')
            fi
            ;;
    esac
    echo "$version"
}

ghostty_install() {
    print_step "Instalando Ghostty..."
    case "$PKG_MANAGER" in
        brew)
            brew install --cask ghostty
            ;;
        pacman)
            sudo pacman -S --noconfirm ghostty
            ;;
        apt)
            print_warning "Ghostty no publica paquete oficial en apt"
            echo ""
            echo -e "  Opciones recomendadas para Debian/Kali:"
            echo ""
            echo -e "    ${BOLD}1. Snap${NC} (más rápido si snapd está disponible):"
            echo -e "       ${DIM}sudo apt install snapd${NC}"
            echo -e "       ${DIM}sudo snap install ghostty --classic${NC}"
            echo ""
            echo -e "    ${BOLD}2. Flatpak${NC} (alternativa contenedorizada):"
            echo -e "       ${DIM}sudo apt install flatpak${NC}"
            echo -e "       ${DIM}flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo${NC}"
            echo -e "       ${DIM}flatpak install flathub com.mitchellh.ghostty${NC}"
            echo ""
            echo -e "    ${BOLD}3. Compilar desde source${NC} (requiere Zig ≥ 0.13):"
            echo -e "       ${DIM}https://ghostty.org/docs/install/build${NC}"
            echo ""
            print_info "Documentación oficial: https://ghostty.org/docs/install/binary"
            echo ""
            print_info "Después de instalar Ghostty manualmente, volvé a correr:"
            echo -e "       ${DIM}./install.sh ghostty${NC}"
            print_info "y solo se aplicará la configuración (config-linux con tus keybinds)."
            return 1
            ;;
        dnf)
            print_info "Verificando COPR para Ghostty..."
            if sudo dnf copr enable -y pgdev/ghostty 2>/dev/null; then
                sudo dnf install -y ghostty
            else
                print_warning "COPR no disponible, visita https://ghostty.org/docs/install"
                return 1
            fi
            ;;
        *)
            print_error "No hay método de instalación automática para tu sistema"
            print_info "Visita: https://ghostty.org/docs/install"
            return 1
            ;;
    esac
}

ghostty_update() {
    print_step "Actualizando Ghostty..."
    case "$PKG_MANAGER" in
        brew)
            local output
            output=$(brew upgrade --cask ghostty 2>&1)
            if echo "$output" | grep -q "already installed"; then
                print_info "Ya tienes la última versión"
            else
                print_success "Ghostty actualizado"
            fi
            ;;
        pacman)
            sudo pacman -Syu --noconfirm ghostty
            print_success "Ghostty actualizado"
            ;;
        apt)
            print_info "Actualización depende del método de instalación que usaste:"
            echo -e "    ${DIM}Snap:    sudo snap refresh ghostty${NC}"
            echo -e "    ${DIM}Flatpak: flatpak update com.mitchellh.ghostty${NC}"
            echo -e "    ${DIM}Source:  re-pull y rebuild${NC}"
            ;;
        dnf)
            sudo dnf upgrade -y ghostty
            print_success "Ghostty actualizado"
            ;;
        *)
            print_warning "Actualización automática no disponible para ${PKG_MANAGER}"
            ;;
    esac
}

ghostty_configure() {
    # Aplicar config via stow
    apply_stow "ghostty" || return 1

    # Crear symlink config.local apuntando al override OS-específico.
    # config base referencia `config-file = ?config.local` — solo se carga
    # el set de keybinds válido para el OS actual.
    local xdg_dir="$HOME/.config/ghostty"
    local config_local="$xdg_dir/config.local"
    local target=""

    case "$OS" in
        macos)  target="config-macos" ;;
        linux)  target="config-linux" ;;
    esac

    if [ -n "$target" ] && [ -f "$xdg_dir/$target" ]; then
        ln -sf "$target" "$config_local"
        print_success "Override OS aplicado: config.local → ${target}"
    else
        print_warning "No se encontró ${target} en ${xdg_dir}"
    fi

    # En macOS, crear symlink desde Application Support → XDG config
    if [ "$OS" = "macos" ]; then
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

            # Symlink: macOS path → XDG path (ambos apuntan al mismo archivo)
            ln -sf "$xdg_config" "$macos_config"
            print_success "Symlink: Application Support → ~/.config/ghostty/config"
        fi
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
