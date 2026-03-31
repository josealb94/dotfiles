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
            if command_exists ghostty; then
                version=$(ghostty --version 2>/dev/null | head -1 | awk '{print $2}')
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
            print_warning "Ghostty no tiene paquete oficial en apt"
            echo ""
            echo -e "  Opciones de instalación manual:"
            echo -e "    ${DIM}1. Descargar .deb desde GitHub releases${NC}"
            echo -e "    ${DIM}2. Compilar desde código fuente (requiere Zig >= 0.13)${NC}"
            echo -e "    ${DIM}3. Usar el AppImage${NC}"
            echo ""
            print_info "Guía: https://ghostty.org/docs/install/binary"
            echo ""
            if confirm "¿Intentar instalar desde .deb (GitHub releases)?"; then
                ghostty_install_deb
            else
                return 1
            fi
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

ghostty_install_deb() {
    local tmp_dir
    tmp_dir=$(mktemp -d)

    print_step "Buscando última versión en GitHub..."
    local latest_url
    latest_url=$(curl -fsSL "https://api.github.com/repos/ghostty-org/ghostty/releases/latest" 2>/dev/null \
        | grep "browser_download_url.*\.deb" \
        | grep "$(dpkg --print-architecture 2>/dev/null || echo 'amd64')" \
        | head -1 \
        | cut -d'"' -f4)

    if [ -z "$latest_url" ]; then
        print_error "No se encontró .deb en las releases de GitHub"
        print_info "Es posible que Ghostty no publique .deb — revisa https://ghostty.org/docs/install"
        rm -rf "$tmp_dir"
        return 1
    fi

    print_step "Descargando $latest_url..."
    if curl -fsSL "$latest_url" -o "$tmp_dir/ghostty.deb"; then
        sudo dpkg -i "$tmp_dir/ghostty.deb"
        sudo apt-get install -f -y 2>/dev/null
        print_success "Ghostty instalado desde .deb"
    else
        print_error "Error descargando el paquete"
        rm -rf "$tmp_dir"
        return 1
    fi
    rm -rf "$tmp_dir"
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
            print_warning "Para actualizar en apt, re-ejecuta la instalación"
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

    # En macOS, crear symlink desde Application Support → XDG config
    if [ "$OS" = "macos" ]; then
        local macos_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
        local xdg_config="$HOME/.config/ghostty/config"
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
