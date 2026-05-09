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
            ghostty_install_apt
            return $?
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

# -- Instalación en apt (Debian/Kali/Ubuntu) ---------------------------------
# Ghostty no publica paquete oficial en apt. Mostramos las opciones reales
# y, en Debian/Kali, ofrecemos automatizar el repo comunitario de Dario Griffo
# que es la opción más cercana a un paquete nativo (recomendada por la doc
# oficial: https://ghostty.org/docs/install/binary#debian).
ghostty_install_apt() {
    print_warning "Ghostty no publica paquete oficial en apt"
    echo ""
    echo -e "  Opciones disponibles:"
    echo ""

    if [ "$OS_ID" = "kali" ] || [ "$OS_ID" = "debian" ]; then
        echo -e "    ${BOLD}1. APT repo comunitario${NC} (dariogriffo/ghostty-debian)"
        echo -e "       ${DIM}Update via apt como cualquier paquete. Soporta Bookworm/Trixie/Sid.${NC}"
        echo -e "       ${DIM}Es la opción más \"nativa\" para Debian/Kali.${NC}"
        echo ""
    elif [ "$OS_ID" = "ubuntu" ]; then
        echo -e "    ${BOLD}1. Script comunitario para Ubuntu${NC} (mkasberg/ghostty-ubuntu)"
        echo -e "       ${DIM}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)\"${NC}"
        echo ""
    fi

    echo -e "    ${BOLD}2. Snap${NC}     — sudo snap install ghostty --classic"
    echo -e "       ${DIM}(requiere snapd: sudo apt install snapd)${NC}"
    echo ""
    echo -e "    ${BOLD}3. AppImage${NC} — binario portable, no toca el sistema"
    echo -e "       ${DIM}https://github.com/ghostty-org/ghostty/releases${NC}"
    echo ""
    echo -e "    ${BOLD}4. Source${NC}   — requiere Zig ≥ 0.13"
    echo -e "       ${DIM}https://ghostty.org/docs/install/build${NC}"
    echo ""
    print_info "Documentación: https://ghostty.org/docs/install/binary#debian"
    echo ""

    # Solo automatizamos el repo comunitario para Debian/Kali (los codenames
    # de Ubuntu no son soportados por dariogriffo).
    if [ "$OS_ID" = "kali" ] || [ "$OS_ID" = "debian" ]; then
        if confirm "¿Configurar el APT repo comunitario (opción 1) e instalar?"; then
            ghostty_install_dariogriffo_repo
            return $?
        fi
    fi

    echo ""
    print_info "Instalá Ghostty con tu método preferido y luego volvé a correr:"
    echo -e "       ${DIM}./install.sh ghostty${NC}"
    print_info "para aplicar la configuración (config-linux con tus keybinds)."
    return 1
}

ghostty_install_dariogriffo_repo() {
    # El repo soporta bookworm/trixie/sid. Kali rolling no tiene un codename
    # propio en el repo → usar 'sid' (Kali tracks Debian unstable/testing).
    local codename
    case "$OS_ID" in
        kali)
            codename="sid"
            print_info "Kali rolling: usando codename '${codename}' del repo comunitario"
            ;;
        debian)
            if command_exists lsb_release; then
                codename=$(lsb_release -sc 2>/dev/null)
            fi
            if [ -z "$codename" ] && [ -f /etc/os-release ]; then
                codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
            fi
            if [ -z "$codename" ]; then
                print_error "No se pudo detectar el codename de Debian"
                return 1
            fi
            ;;
        *)
            print_error "Repo comunitario solo soportado en Debian/Kali (OS_ID=${OS_ID})"
            return 1
            ;;
    esac

    print_step "Agregando clave GPG de debian.griffo.io..."
    if ! curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
        | sudo gpg --dearmor -o /usr/share/keyrings/debian.griffo.io.gpg; then
        print_error "Falló la descarga/import de la clave GPG"
        return 1
    fi

    print_step "Agregando repo a /etc/apt/sources.list.d/ (codename: ${codename})..."
    echo "deb [signed-by=/usr/share/keyrings/debian.griffo.io.gpg] https://debian.griffo.io/apt ${codename} main" \
        | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list >/dev/null

    print_step "Actualizando apt..."
    if ! sudo apt-get update; then
        print_error "Falló apt-get update — revisá la salida arriba"
        return 1
    fi

    print_step "Instalando ghostty..."
    if sudo apt-get install -y ghostty; then
        print_success "Ghostty instalado via repo comunitario"
        return 0
    else
        print_error "Falló la instalación de ghostty"
        print_info "Si el problema es el codename, probá manualmente con bookworm o trixie"
        return 1
    fi
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
            # Si está instalado via el repo comunitario, podemos updatear via apt
            if dpkg -l ghostty 2>/dev/null | grep -q "^ii"; then
                print_step "Detectado ghostty via apt — actualizando..."
                sudo apt-get update && sudo apt-get install -y --only-upgrade ghostty
                print_success "Ghostty actualizado via apt"
            else
                print_info "Actualización depende del método de instalación que usaste:"
                echo -e "    ${DIM}Snap:     sudo snap refresh ghostty${NC}"
                echo -e "    ${DIM}AppImage: re-descargar de https://github.com/ghostty-org/ghostty/releases${NC}"
                echo -e "    ${DIM}Source:   git pull && rebuild${NC}"
            fi
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
