#!/usr/bin/env bash
# =============================================================================
# zsh.sh — Módulo de instalación y configuración de Zsh + Oh My Zsh
# =============================================================================

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# -- Verificaciones -----------------------------------------------------------

zsh_ensure_installed() {
    if command_exists zsh; then
        return 0
    fi

    print_warning "zsh no está instalado"
    if ! confirm "¿Instalar zsh?"; then
        print_error "zsh es requerido para este módulo"
        return 1
    fi

    print_step "Instalando zsh..."
    case "$PKG_MANAGER" in
        brew)   brew install zsh ;;
        apt)    sudo apt-get update && sudo apt-get install -y zsh ;;
        pacman) sudo pacman -S --noconfirm zsh ;;
        dnf)    sudo dnf install -y zsh ;;
        *)
            print_error "No se pudo instalar zsh automáticamente para ${PKG_MANAGER}"
            return 1
            ;;
    esac

    if command_exists zsh; then
        print_success "zsh instalado ($(zsh --version | awk '{print $2}'))"
    else
        print_error "Falló la instalación de zsh"
        return 1
    fi
}

zsh_check_default_shell() {
    # Verificar primero que zsh esté instalado
    zsh_ensure_installed || return 1

    local current_shell
    current_shell=$(basename "$SHELL")
    if [ "$current_shell" != "zsh" ]; then
        print_warning "Tu shell por defecto es ${BOLD}${current_shell}${NC}${YELLOW}, no zsh"
        if confirm "¿Cambiar shell por defecto a zsh?"; then
            local zsh_path
            zsh_path="$(command -v zsh)"

            # Asegurar que zsh está en /etc/shells (necesario en Linux)
            if [ -f /etc/shells ] && ! grep -qx "$zsh_path" /etc/shells; then
                print_step "Agregando $zsh_path a /etc/shells..."
                echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
            fi

            chsh -s "$zsh_path"
            print_success "Shell cambiado a zsh (requiere re-login)"
        fi
    else
        print_success "Shell por defecto: zsh"
    fi
}

zsh_check_omz() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_success "Oh My Zsh instalado"
        return 0
    fi
    return 1
}

zsh_install_omz() {
    print_step "Instalando Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    print_success "Oh My Zsh instalado"
}

# -- Plugins ------------------------------------------------------------------

zsh_check_plugin() {
    local plugin_name="$1"
    [ -d "$ZSH_CUSTOM_DIR/plugins/$plugin_name" ]
}

zsh_install_plugin() {
    local plugin_name="$1"
    local repo_url="$2"

    if zsh_check_plugin "$plugin_name"; then
        print_success "Plugin: $plugin_name"
        return 0
    fi

    print_step "Instalando plugin: $plugin_name..."
    git clone --depth=1 "$repo_url" "$ZSH_CUSTOM_DIR/plugins/$plugin_name" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_success "Plugin: $plugin_name instalado"
    else
        print_error "Error instalando plugin: $plugin_name"
        return 1
    fi
}

zsh_install_plugins() {
    print_section "Plugins"
    echo ""
    zsh_install_plugin "zsh-autosuggestions" \
        "https://github.com/zsh-users/zsh-autosuggestions.git"
    zsh_install_plugin "zsh-syntax-highlighting" \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git"
    zsh_install_plugin "zsh-completions" \
        "https://github.com/zsh-users/zsh-completions.git"
    zsh_install_plugin "zsh-history-substring-search" \
        "https://github.com/zsh-users/zsh-history-substring-search.git"
    zsh_install_plugin "you-should-use" \
        "https://github.com/MichaelAquilina/zsh-you-should-use.git"
    zsh_install_plugin "fzf-tab" \
        "https://github.com/Aloxaf/fzf-tab.git"
}

# -- Herramientas CLI ---------------------------------------------------------

zsh_check_cli_tools() {
    echo ""
    print_section "Herramientas CLI de productividad"
    echo ""

    local missing=""

    if command_exists tmux; then
        print_success "tmux (sesiones background para Claude Code worktrees)"
    else
        missing="$missing tmux"
    fi

    if command_exists zoxide; then
        print_success "zoxide (cd inteligente)"
    else
        missing="$missing zoxide"
    fi

    if command_exists eza; then
        print_success "eza (ls moderno con iconos y git)"
    else
        missing="$missing eza"
    fi

    if command_exists direnv; then
        print_success "direnv (env vars por directorio)"
    else
        missing="$missing direnv"
    fi

    if [ -n "$missing" ]; then
        echo ""
        if confirm "¿Instalar herramientas faltantes?${missing}"; then
            for tool in $missing; do
                print_step "Instalando ${tool}..."
                # install_tool conoce los casos especiales: eza no está en apt
                # de Kali/Debian → baja binario de GitHub
                install_tool "$tool"
            done
            print_success "Herramientas instaladas"
        fi
    fi
}

# -- Tema ---------------------------------------------------------------------

zsh_check_spaceship() {
    [ -d "$ZSH_CUSTOM_DIR/themes/spaceship-prompt" ] || \
    [ -f "$ZSH_CUSTOM_DIR/themes/spaceship.zsh-theme" ]
}

zsh_check_starship() {
    if command_exists starship; then
        local version
        version=$(starship --version 2>/dev/null | head -1 | awk '{print $2}')
        print_success "Starship instalado (v${version})"
        return 0
    fi
    return 1
}

zsh_install_starship() {
    print_step "Instalando Starship..."
    case "$PKG_MANAGER" in
        brew)   brew install starship ;;
        pacman) sudo pacman -S --noconfirm starship ;;
        apt)
            curl -sS https://starship.rs/install.sh | sh -s -- --yes
            ;;
        dnf)    sudo dnf install -y starship ;;
        *)
            curl -sS https://starship.rs/install.sh | sh -s -- --yes
            ;;
    esac
    print_success "Starship instalado"
}

zsh_configure_starship() {
    apply_stow "starship" || return 1
    print_success "Configuración de Starship aplicada"
}

# -- asdf ---------------------------------------------------------------------

zsh_check_asdf() {
    if [ -f "$HOME/.asdf/asdf.sh" ] || command_exists asdf; then
        local version
        version=$(asdf --version 2>/dev/null | head -1)
        print_success "asdf instalado ($version)"
        return 0
    fi
    return 1
}

zsh_install_asdf() {
    print_step "Instalando asdf..."
    case "$PKG_MANAGER" in
        brew)
            brew install asdf
            ;;
        *)
            git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1 2>/dev/null
            ;;
    esac
    print_success "asdf instalado"
}

zsh_setup_asdf_nodejs() {
    if ! asdf plugin list 2>/dev/null | grep -q "^nodejs$"; then
        print_step "Agregando plugin nodejs a asdf..."
        asdf plugin add nodejs
        print_success "Plugin nodejs agregado a asdf"
    else
        print_success "asdf plugin: nodejs"
    fi

    # Verificar si hay una versión de Node.js instalada
    if ! asdf current nodejs >/dev/null 2>&1; then
        print_warning "No hay versión de Node.js configurada en asdf"
        if confirm "¿Instalar Node.js LTS via asdf?"; then
            asdf install nodejs latest
            # asdf v0.16+ usa "set -u", asdf < v0.16 usa "global"
            if asdf set -u nodejs latest 2>/dev/null; then
                print_success "Node.js instalado y configurado via asdf"
            elif asdf global nodejs latest 2>/dev/null; then
                print_success "Node.js instalado y configurado via asdf"
            else
                print_warning "Node.js instalado pero falló al configurarlo como default"
            fi
        fi
    else
        local node_version
        node_version=$(asdf current nodejs 2>/dev/null | awk '{print $2}')
        print_success "Node.js: v${node_version} (via asdf)"
    fi
}

zsh_check_nvm() {
    if [ -d "$HOME/.nvm" ]; then
        echo ""
        print_warning "nvm detectado en ~/.nvm"
        print_info "Ya tienes Node.js via asdf — nvm es redundante"
        print_info "Para eliminarlo:"
        echo -e "${DIM}    rm -rf ~/.nvm${NC}"
        print_info "El .zshrc nuevo ya no carga nvm"
        echo ""
    fi
}

# -- Configuración ------------------------------------------------------------

zsh_configure() {
    # Backup del .zshrc actual antes de stow
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d)"
        print_info "Backup de .zshrc actual → ~/.zshrc.backup.$(date +%Y%m%d)"
    fi
    if [ -f "$HOME/.zshenv" ] && [ ! -L "$HOME/.zshenv" ]; then
        cp "$HOME/.zshenv" "$HOME/.zshenv.backup.$(date +%Y%m%d)"
        print_info "Backup de .zshenv actual → ~/.zshenv.backup.$(date +%Y%m%d)"
    fi

    apply_stow "zsh"
}

# -- Punto de entrada ---------------------------------------------------------

zsh_main() {
    echo ""
    print_section "Shell — Zsh + Oh My Zsh"
    echo ""

    # 1. Verificar shell por defecto
    zsh_check_default_shell

    # 2. Oh My Zsh
    echo ""
    print_section "Oh My Zsh"
    echo ""
    if ! zsh_check_omz; then
        if confirm "¿Instalar Oh My Zsh?"; then
            zsh_install_omz
        else
            print_error "Oh My Zsh es requerido para esta configuración"
            return 1
        fi
    fi

    # 3. Plugins
    echo ""
    zsh_install_plugins

    # 4. Prompt (Starship)
    echo ""
    print_section "Prompt (Starship)"
    echo ""
    if ! zsh_check_starship; then
        if confirm "¿Instalar Starship?"; then
            zsh_install_starship
        fi
    fi
    zsh_configure_starship

    # 5. asdf
    echo ""
    print_section "asdf (version manager)"
    echo ""
    if ! zsh_check_asdf; then
        if confirm "¿Instalar asdf?"; then
            zsh_install_asdf
        fi
    fi
    # Configurar Node.js via asdf
    zsh_setup_asdf_nodejs

    # 6. Herramientas CLI
    zsh_check_cli_tools

    # 7. Detectar nvm residual
    zsh_check_nvm

    # 8. Aplicar configuración
    echo ""
    print_section "Aplicar configuración"
    echo ""
    if confirm "¿Aplicar nuevo .zshrc, .zshenv y .zsh_aliases? (se hará backup del actual)"; then
        zsh_configure
    else
        print_info "Saltando aplicación de config"
        print_info "Puedes aplicarla manualmente: stow -d ~/dotfiles -t ~ zsh"
        return 0
    fi

    echo ""
    print_success "Módulo zsh configurado"
    print_info "Ejecuta ${BOLD}source ~/.zshrc${NC}${CYAN} o abre una nueva terminal para aplicar${NC}"
}
