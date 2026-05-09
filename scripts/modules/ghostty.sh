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

    # IMPORTANTE: dariogriffo solo publica `ghostty` para amd64. En arm64
    # solo trae 13 paquetes auxiliares y NO incluye ghostty. Detectamos la
    # arquitectura para no ofrecer un repo que va a fallar.
    local arch
    arch=$(uname -m)
    local dariogriffo_available=false
    if [ "$arch" = "x86_64" ] && { [ "$OS_ID" = "kali" ] || [ "$OS_ID" = "debian" ]; }; then
        dariogriffo_available=true
    fi

    echo -e "  Opciones disponibles para tu sistema (${OS_ID}/${arch}):"
    echo ""

    local opt=1
    if $dariogriffo_available; then
        echo -e "    ${BOLD}${opt}. APT repo comunitario${NC} (dariogriffo/ghostty-debian)"
        echo -e "       ${DIM}Update via apt. Soporta Bookworm/Trixie/Sid amd64.${NC}"
        echo ""
        opt=$((opt + 1))
    elif [ "$arch" != "x86_64" ]; then
        print_info "Tu arquitectura (${arch}) NO está soportada por el APT repo de dariogriffo"
        print_info "(solo publican amd64). Saltamos esa opción."
        echo ""
    fi

    if [ "$OS_ID" = "ubuntu" ]; then
        echo -e "    ${BOLD}${opt}. Script comunitario Ubuntu${NC} (mkasberg/ghostty-ubuntu)"
        echo -e "       ${DIM}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)\"${NC}"
        echo ""
        opt=$((opt + 1))
    fi

    echo -e "    ${BOLD}${opt}. AppImage${NC} (pkgforge-dev/ghostty-appimage)"
    echo -e "       ${DIM}Soporta x86_64 y aarch64. Binario portable, cero impacto en sistema.${NC}"
    opt=$((opt + 1))
    echo ""
    echo -e "    ${BOLD}${opt}. Snap${NC} — sudo snap install ghostty --classic"
    echo -e "       ${DIM}(requiere snapd: sudo apt install snapd)${NC}"
    opt=$((opt + 1))
    echo ""
    echo -e "    ${BOLD}${opt}. Source${NC} — requiere Zig ≥ 0.13"
    echo -e "       ${DIM}https://ghostty.org/docs/install/build${NC}"
    echo ""
    print_info "Documentación: https://ghostty.org/docs/install/binary#debian"
    echo ""

    # Recomendación según arquitectura
    if $dariogriffo_available; then
        if confirm "¿Configurar APT repo comunitario (recomendado para amd64) e instalar?"; then
            ghostty_install_dariogriffo_repo
            return $?
        fi
    fi

    if confirm "¿Descargar AppImage en ~/.local/bin/ (recomendado para arm64, también funciona en amd64)?"; then
        ghostty_install_appimage
        return $?
    fi

    echo ""
    print_info "Instalá Ghostty con tu método preferido y luego volvé a correr:"
    echo -e "       ${DIM}./install.sh ghostty${NC}"
    print_info "para aplicar la configuración (config-linux con tus keybinds)."
    return 1
}

ghostty_install_appimage() {
    # AppImage comunitario de pkgforge-dev (linkeado desde la doc oficial).
    # Soporta x86_64 y aarch64.
    local arch
    case "$(uname -m)" in
        x86_64)         arch="x86_64" ;;
        aarch64|arm64)  arch="aarch64" ;;
        *)
            print_error "Arquitectura $(uname -m) no soportada por el AppImage"
            return 1
            ;;
    esac

    print_step "Buscando última release en pkgforge-dev/ghostty-appimage..."
    local url
    url=$(curl -fsSL "https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest" 2>/dev/null \
          | grep "browser_download_url.*Ghostty-.*-${arch}\.AppImage\"" \
          | head -1 | cut -d'"' -f4)

    if [ -z "$url" ]; then
        print_error "No se encontró AppImage para ${arch} en la última release"
        print_info "Revisá: https://github.com/pkgforge-dev/ghostty-appimage/releases"
        return 1
    fi

    local filename
    filename=$(basename "$url")
    print_step "Descargando ${filename}..."

    mkdir -p "$HOME/.local/bin"
    if ! curl -fsSL --progress-bar -o "$HOME/.local/bin/ghostty.AppImage" "$url"; then
        print_error "Error descargando el AppImage"
        return 1
    fi

    chmod +x "$HOME/.local/bin/ghostty.AppImage"
    ln -sf "$HOME/.local/bin/ghostty.AppImage" "$HOME/.local/bin/ghostty"
    print_success "Ghostty instalado en ~/.local/bin/ghostty (symlink al AppImage)"

    # Verificar que ~/.local/bin esté en PATH
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *)
            print_warning "~/.local/bin no está en tu PATH actual"
            print_info "Asegurate de tener el .zshrc del repo aplicado (lo agrega automáticamente)"
            ;;
    esac

    # AppImages necesitan FUSE para mountarse. En Kali rolling reciente
    # libfuse2 puede no estar instalado por default.
    if ! ldconfig -p 2>/dev/null | grep -q "libfuse.so.2"; then
        echo ""
        print_warning "AppImage requiere libfuse2 para ejecutarse"
        if confirm "¿Instalar libfuse2 ahora?"; then
            sudo apt-get install -y libfuse2 || sudo apt-get install -y libfuse2t64
        fi
    fi

    # Crear .desktop entry para que aparezca en el menú de Xfce
    local desktop_file="$HOME/.local/share/applications/ghostty.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Ghostty
Comment=Fast, native terminal emulator
Exec=$HOME/.local/bin/ghostty
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
StartupNotify=true
EOF
    print_success "Desktop entry creado en ~/.local/share/applications/ghostty.desktop"
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
            # Detectar método de instalación y updatear según corresponda
            if dpkg -l ghostty 2>/dev/null | grep -q "^ii"; then
                print_step "Detectado ghostty via apt — actualizando..."
                sudo apt-get update && sudo apt-get install -y --only-upgrade ghostty
                print_success "Ghostty actualizado via apt"
            elif [ -f "$HOME/.local/bin/ghostty.AppImage" ]; then
                print_step "Detectado AppImage — re-descargando última release..."
                ghostty_install_appimage
            else
                print_info "Actualización depende del método de instalación que usaste:"
                echo -e "    ${DIM}Snap:   sudo snap refresh ghostty${NC}"
                echo -e "    ${DIM}Source: git pull && rebuild${NC}"
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
