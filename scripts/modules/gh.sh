#!/usr/bin/env bash
# =============================================================================
# gh.sh — Módulo de instalación de GitHub CLI
# =============================================================================

gh_check_installed() {
    if command_exists gh; then
        local version
        version=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
        print_success "GitHub CLI instalado (v${version})"
        return 0
    fi
    return 1
}

gh_install_apt() {
    # apt en Debian/Kali no siempre tiene la última versión — usar repo oficial
    print_step "Configurando repo oficial de GitHub CLI..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt update
    sudo apt install -y gh
}

gh_install_dnf() {
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
}

gh_install() {
    print_step "Instalando GitHub CLI..."
    case "$PKG_MANAGER" in
        brew)   brew install gh ;;
        apt)    gh_install_apt ;;
        pacman) sudo pacman -S --noconfirm github-cli ;;
        dnf)    gh_install_dnf ;;
        *)
            print_error "No hay método automático para ${PKG_MANAGER}"
            print_info "Instalación manual: https://cli.github.com/"
            return 1
            ;;
    esac

    if command_exists gh; then
        print_success "GitHub CLI instalado ($(gh --version | head -1 | awk '{print $3}'))"
    else
        print_error "Falló la instalación de gh"
        return 1
    fi
}

# -- Autenticación ------------------------------------------------------------

gh_check_auth() {
    if gh auth status >/dev/null 2>&1; then
        local user
        user=$(gh api user --jq '.login' 2>/dev/null || echo "")
        if [ -n "$user" ]; then
            print_success "gh autenticado como ${BOLD}${user}${NC}"
        else
            print_success "gh autenticado"
        fi
        return 0
    fi
    return 1
}

gh_auth_login() {
    print_step "Iniciando autenticación con GitHub..."
    print_info "Se abrirá el browser para completar el login"
    # --web fuerza flow de browser, --git-protocol https evita configurar SSH
    # (vos ya manejás SSH aparte con tus host aliases)
    gh auth login --web --git-protocol https
}

# -- Extensiones útiles -------------------------------------------------------

gh_offer_extensions() {
    echo ""
    print_info "Extensiones populares de gh (opcional):"
    echo -e "${DIM}    gh-dash        — TUI con dashboard de PRs e issues${NC}"
    echo -e "${DIM}    gh-copilot     — sugerencias de comandos (requiere Copilot)${NC}"
    echo ""
    if confirm "¿Instalar gh-dash?"; then
        gh extension install dlvhdr/gh-dash && print_success "gh-dash instalado"
    fi
}

# -- Punto de entrada ---------------------------------------------------------

gh_main() {
    echo ""
    print_section "GitHub CLI (gh)"
    echo ""

    # 1. Instalación
    if ! gh_check_installed; then
        if confirm "¿Instalar GitHub CLI?"; then
            gh_install || return 1
        else
            return 0
        fi
    fi

    # 2. Autenticación
    echo ""
    if ! gh_check_auth; then
        print_warning "gh no está autenticado"
        if confirm "¿Autenticar ahora con GitHub?"; then
            gh_auth_login
        else
            print_info "Podés autenticar después con: ${BOLD}gh auth login${NC}"
        fi
    fi

    # 3. Extensiones
    gh_offer_extensions

    echo ""
    print_success "Módulo GitHub CLI configurado"
}
