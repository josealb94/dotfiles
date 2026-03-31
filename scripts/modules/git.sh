#!/usr/bin/env bash
# =============================================================================
# git.sh — Módulo de instalación y configuración de Git
# =============================================================================

git_check_installed() {
    if command_exists git; then
        local version
        version=$(git --version | awk '{print $3}')
        print_success "Git instalado (v${version})"
        return 0
    fi
    return 1
}

git_install() {
    print_step "Instalando Git..."
    case "$PKG_MANAGER" in
        brew)   brew install git ;;
        apt)    sudo apt-get update && sudo apt-get install -y git ;;
        pacman) sudo pacman -S --noconfirm git ;;
        dnf)    sudo dnf install -y git ;;
        *)      print_error "Instala Git manualmente"; return 1 ;;
    esac
    print_success "Git instalado"
}

git_check_lfs() {
    if command_exists git-lfs; then
        print_success "Git LFS instalado"
        return 0
    fi
    return 1
}

git_install_lfs() {
    print_step "Instalando Git LFS..."
    case "$PKG_MANAGER" in
        brew)   brew install git-lfs ;;
        apt)    sudo apt-get install -y git-lfs ;;
        pacman) sudo pacman -S --noconfirm git-lfs ;;
        dnf)    sudo dnf install -y git-lfs ;;
        *)      print_error "Instala Git LFS manualmente"; return 1 ;;
    esac
    git lfs install --skip-repo >/dev/null 2>&1
    print_success "Git LFS instalado y configurado"
}

git_show_current_config() {
    echo ""
    print_section "Configuración actual"
    echo ""

    local name email
    name=$(git config --global user.name 2>/dev/null || echo "no configurado")
    email=$(git config --global user.email 2>/dev/null || echo "no configurado")

    print_info "Nombre: ${BOLD}${name}${NC}"
    print_info "Email:  ${BOLD}${email}${NC}"

    # Verificar paths hardcodeados
    local excludes template
    excludes=$(git config --global core.excludesfile 2>/dev/null || echo "")
    template=$(git config --global commit.template 2>/dev/null || echo "")

    if echo "$excludes" | grep -q "/Users/\|/home/"; then
        print_warning "excludesfile tiene path absoluto: $excludes"
    fi
    if [ -n "$template" ] && echo "$template" | grep -q "/Users/\|/home/"; then
        print_warning "commit.template tiene path absoluto: $template"
    fi
}

git_configure() {
    # Backup
    if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
        cp "$HOME/.gitconfig" "$HOME/.gitconfig.backup.$(date +%Y%m%d)"
        print_info "Backup: ~/.gitconfig.backup.$(date +%Y%m%d)"
    fi
    if [ -f "$HOME/.gitignore_global" ] && [ ! -L "$HOME/.gitignore_global" ]; then
        cp "$HOME/.gitignore_global" "$HOME/.gitignore_global.backup.$(date +%Y%m%d)"
        print_info "Backup: ~/.gitignore_global.backup.$(date +%Y%m%d)"
    fi

    apply_stow "git"
}

git_setup_local_config() {
    echo ""
    print_section "Configuración local (overrides por máquina)"
    echo ""

    if [ -f "$HOME/.gitconfig.local" ]; then
        print_success "~/.gitconfig.local ya existe"
        local local_email
        local_email=$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || echo "")
        if [ -n "$local_email" ]; then
            print_info "Email local: ${BOLD}${local_email}${NC}"
        fi
    else
        print_info "~/.gitconfig.local no existe"
        print_info "Usa este archivo para overrides por máquina (email corporativo, signing key, etc.)"
        echo ""
        if confirm "¿Configurar email diferente para esta máquina?"; then
            local new_email
            print_prompt "Email"
            read -r new_email
            if [ -n "$new_email" ]; then
                echo "[user]" > "$HOME/.gitconfig.local"
                echo "	email = $new_email" >> "$HOME/.gitconfig.local"
                print_success "~/.gitconfig.local creado con email: $new_email"
                print_info "Este archivo no se versiona — es específico de esta máquina"
            fi
        fi
    fi
}

git_main() {
    echo ""
    print_section "Git"
    echo ""

    # 1. Verificar instalación
    if ! git_check_installed; then
        if confirm "¿Instalar Git?"; then
            git_install || return 1
        else
            return 1
        fi
    fi

    # 2. Git LFS
    if ! git_check_lfs; then
        if confirm "¿Instalar Git LFS?"; then
            git_install_lfs
        fi
    fi

    # 3. Mostrar config actual
    git_show_current_config

    # 4. Aplicar configuración
    echo ""
    print_section "Aplicar configuración"
    echo ""
    print_info "Se aplicará:"
    echo -e "${DIM}    .gitconfig        — aliases, defaults, url rewrite${NC}"
    echo -e "${DIM}    .gitignore_global — ignores globales (DS_Store, node_modules, etc.)${NC}"
    echo ""

    if confirm "¿Aplicar nueva configuración de Git? (se hará backup de la actual)"; then
        git_configure
    else
        print_info "Puedes aplicarla después: stow -d ~/dotfiles -t ~ git"
        return 0
    fi

    # 5. Config local
    git_setup_local_config

    echo ""
    print_success "Módulo Git configurado"
}
