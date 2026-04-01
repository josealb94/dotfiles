#!/usr/bin/env bash
# =============================================================================
# nvim.sh — Módulo de instalación y configuración de Neovim + LazyVim
# =============================================================================

NVIM_MIN_VERSION="0.9.4"

nvim_get_version() {
    if command_exists nvim; then
        nvim --version 2>/dev/null | head -1 | sed 's/NVIM v//'
    fi
}

nvim_version_ok() {
    local current="$1"
    local required="$2"

    # Comparar versiones numéricamente
    local cur_major cur_minor cur_patch
    cur_major=$(echo "$current" | cut -d. -f1)
    cur_minor=$(echo "$current" | cut -d. -f2)
    cur_patch=$(echo "$current" | cut -d. -f3)

    local req_major req_minor req_patch
    req_major=$(echo "$required" | cut -d. -f1)
    req_minor=$(echo "$required" | cut -d. -f2)
    req_patch=$(echo "$required" | cut -d. -f3)

    if [ "$cur_major" -gt "$req_major" ] 2>/dev/null; then return 0; fi
    if [ "$cur_major" -lt "$req_major" ] 2>/dev/null; then return 1; fi
    if [ "$cur_minor" -gt "$req_minor" ] 2>/dev/null; then return 0; fi
    if [ "$cur_minor" -lt "$req_minor" ] 2>/dev/null; then return 1; fi
    if [ "${cur_patch:-0}" -ge "${req_patch:-0}" ] 2>/dev/null; then return 0; fi
    return 1
}

nvim_check_installed() {
    local version
    version=$(nvim_get_version)
    if [ -n "$version" ]; then
        if nvim_version_ok "$version" "$NVIM_MIN_VERSION"; then
            print_success "Neovim instalado (v${version})"
            return 0
        else
            print_warning "Neovim v${version} instalado — LazyVim requiere v${NVIM_MIN_VERSION}+"
            return 1
        fi
    fi
    return 1
}

nvim_install() {
    print_step "Instalando Neovim..."
    case "$PKG_MANAGER" in
        brew)   brew install neovim ;;
        apt)
            # apt suele tener versiones viejas, usar PPA o AppImage
            print_info "Instalando desde PPA para obtener versión reciente..."
            sudo apt-get update
            sudo apt-get install -y software-properties-common
            sudo add-apt-repository -y ppa:neovim-ppa/unstable
            sudo apt-get update
            sudo apt-get install -y neovim
            ;;
        pacman) sudo pacman -S --noconfirm neovim ;;
        dnf)    sudo dnf install -y neovim ;;
        *)      print_error "Instala Neovim manualmente: https://neovim.io"; return 1 ;;
    esac
    print_success "Neovim instalado"
}

nvim_update() {
    print_step "Actualizando Neovim..."
    case "$PKG_MANAGER" in
        brew)   brew upgrade neovim 2>&1 | tail -3 ;;
        apt)    sudo apt-get update && sudo apt-get upgrade -y neovim ;;
        pacman) sudo pacman -Syu --noconfirm neovim ;;
        dnf)    sudo dnf upgrade -y neovim ;;
    esac
    local version
    version=$(nvim_get_version)
    print_success "Neovim actualizado (v${version})"
}

# -- Backup y limpieza -------------------------------------------------------

nvim_backup_configs() {
    local date_suffix
    date_suffix=$(date +%Y%m%d)

    echo ""
    print_section "Backup de configuraciones existentes"
    echo ""

    local backed_up=false

    # Neovim config
    if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
        mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.${date_suffix}"
        print_info "~/.config/nvim/ → nvim.bak.${date_suffix}"
        backed_up=true
    fi

    # Neovim data (plugins, cache)
    if [ -d "$HOME/.local/share/nvim" ]; then
        mv "$HOME/.local/share/nvim" "$HOME/.local/share/nvim.bak.${date_suffix}"
        print_info "~/.local/share/nvim/ → nvim.bak.${date_suffix}"
        backed_up=true
    fi

    # Neovim state
    if [ -d "$HOME/.local/state/nvim" ]; then
        mv "$HOME/.local/state/nvim" "$HOME/.local/state/nvim.bak.${date_suffix}"
        print_info "~/.local/state/nvim/ → nvim.bak.${date_suffix}"
        backed_up=true
    fi

    # Neovim cache
    if [ -d "$HOME/.cache/nvim" ]; then
        mv "$HOME/.cache/nvim" "$HOME/.cache/nvim.bak.${date_suffix}"
        print_info "~/.cache/nvim/ → nvim.bak.${date_suffix}"
        backed_up=true
    fi

    # Vim config viejo
    if [ -d "$HOME/.vim" ]; then
        mv "$HOME/.vim" "$HOME/.vim.bak.${date_suffix}"
        print_info "~/.vim/ → .vim.bak.${date_suffix}"
        backed_up=true
    fi
    if [ -f "$HOME/.config/.vimrc" ]; then
        mv "$HOME/.config/.vimrc" "$HOME/.config/.vimrc.bak.${date_suffix}"
        print_info "~/.config/.vimrc → .vimrc.bak.${date_suffix}"
        backed_up=true
    fi

    if [ "$backed_up" = false ]; then
        print_info "No hay configuraciones anteriores para respaldar"
    else
        print_success "Backups creados"
    fi
}

nvim_clean_lunarvim() {
    if [ -f "$HOME/.local/bin/lvim" ] || [ -d "$HOME/.config/lvim" ] || [ -d "$HOME/.local/share/lunarvim" ]; then
        echo ""
        print_section "LunarVim detectado"
        echo ""
        print_info "LunarVim será reemplazado por LazyVim"

        if confirm "¿Eliminar LunarVim?"; then
            rm -f "$HOME/.local/bin/lvim"
            rm -rf "$HOME/.config/lvim"
            rm -rf "$HOME/.local/share/lunarvim"
            print_success "LunarVim eliminado"
        else
            print_info "LunarVim no eliminado — puede causar conflictos con LazyVim"
        fi
    fi
}

# -- Instalación de LazyVim ---------------------------------------------------

nvim_configure() {
    apply_stow "nvim" || return 1
    print_success "LazyVim configurado en ~/.config/nvim/"
}

# -- Dependencias para LSP servers --------------------------------------------

nvim_check_deps() {
    echo ""
    print_section "Dependencias para LSP servers"
    echo ""

    local missing=""

    # npm (para typescript LSP, prettier, eslint)
    if command_exists node; then
        print_success "Node.js $(node --version) (necesario para TypeScript LSP)"
    else
        print_warning "Node.js no encontrado — TypeScript LSP no funcionará"
        missing="$missing node"
    fi

    # go (para gopls)
    if command_exists go; then
        print_success "Go $(go version | awk '{print $3}')"
    else
        print_warning "Go no encontrado — Go LSP no funcionará"
        missing="$missing go"
    fi

    # cargo (para rust-analyzer)
    if command_exists cargo; then
        print_success "Cargo $(cargo --version | awk '{print $2}')"
    else
        print_warning "Cargo no encontrado — Rust LSP no funcionará"
        missing="$missing cargo"
    fi

    # python (para pyright)
    if command_exists python3; then
        print_success "Python $(python3 --version | awk '{print $2}')"
    else
        print_warning "Python no encontrado — Python LSP no funcionará"
        missing="$missing python"
    fi

    if [ -n "$missing" ]; then
        echo ""
        print_info "Los LSP servers faltantes se pueden instalar después"
        print_info "Mason (dentro de nvim) los instalará automáticamente cuando estén disponibles"
    fi
}

# -- Punto de entrada ---------------------------------------------------------

nvim_main() {
    echo ""
    print_section "Neovim + LazyVim"
    echo ""

    # 1. Verificar/instalar Neovim
    if ! nvim_check_installed; then
        local version
        version=$(nvim_get_version)
        if [ -n "$version" ]; then
            # Versión vieja instalada
            if confirm "¿Actualizar Neovim?"; then
                nvim_update
            else
                print_error "LazyVim requiere Neovim v${NVIM_MIN_VERSION}+"
                return 1
            fi
        else
            # No instalado
            if confirm "¿Instalar Neovim?"; then
                nvim_install || return 1
            else
                return 1
            fi
        fi
    fi

    # 2. Limpiar LunarVim
    nvim_clean_lunarvim

    # 3. Backup de configs existentes
    nvim_backup_configs

    # 4. Verificar dependencias para LSP
    nvim_check_deps

    # 5. Instalar LazyVim
    echo ""
    print_section "Instalar LazyVim"
    echo ""
    print_info "Se configurará LazyVim con soporte para:"
    echo -e "${DIM}    TypeScript/JavaScript/React, Python, Go, Rust${NC}"
    echo -e "${DIM}    JSON, YAML, Docker, Tailwind, Markdown${NC}"
    echo -e "${DIM}    Prettier, ESLint, tema Catppuccin Mocha${NC}"
    echo ""

    if confirm "¿Instalar LazyVim?"; then
        nvim_configure || return 1
    else
        print_info "Puedes instalarlo después: stow -d ~/dotfiles -t ~ nvim"
        return 0
    fi

    echo ""
    print_success "LazyVim instalado"
    echo ""
    print_info "Primer inicio: ejecuta ${BOLD}nvim${NC}${CYAN} en la terminal"
    print_info "LazyVim descargará e instalará todos los plugins automáticamente (~1-2 min)"
    print_info "Los LSP servers se instalarán via Mason al abrir archivos del lenguaje"
    echo ""
    print_info "Keybindings: presiona ${BOLD}Space${NC}${CYAN} para ver el menú principal"
}
