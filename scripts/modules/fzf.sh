#!/usr/bin/env bash
# =============================================================================
# fzf.sh — Módulo de instalación y configuración de fzf + herramientas
# =============================================================================

# Herramientas que fzf usa para previews y búsquedas
FZF_DEPS="fd bat tree ripgrep"

fzf_check_installed() {
    if command_exists fzf; then
        local version
        version=$(fzf --version 2>/dev/null | awk '{print $1}')
        print_success "fzf instalado (v${version})"
        return 0
    fi
    return 1
}

fzf_install() {
    print_step "Instalando fzf..."
    case "$PKG_MANAGER" in
        brew)   brew install fzf ;;
        apt)    sudo apt-get update && sudo apt-get install -y fzf ;;
        pacman) sudo pacman -S --noconfirm fzf ;;
        dnf)    sudo dnf install -y fzf ;;
        *)      print_error "Instala fzf manualmente: https://github.com/junegunn/fzf"; return 1 ;;
    esac
}

fzf_update() {
    print_step "Actualizando fzf..."
    case "$PKG_MANAGER" in
        brew)   brew upgrade fzf 2>&1 | tail -1 ;;
        apt)    sudo apt-get update && sudo apt-get upgrade -y fzf ;;
        pacman) sudo pacman -Syu --noconfirm fzf ;;
        dnf)    sudo dnf upgrade -y fzf ;;
    esac
}

fzf_check_deps() {
    echo ""
    print_section "Dependencias de fzf"
    echo ""

    local missing=""

    for dep in $FZF_DEPS; do
        local cmd_name="$dep"
        # ripgrep se instala como rg
        if [ "$dep" = "ripgrep" ]; then
            cmd_name="rg"
        fi

        if command_exists "$cmd_name"; then
            local ver
            ver=$("$cmd_name" --version 2>/dev/null | head -1)
            print_success "${dep} ($ver)"
        else
            print_warning "${dep} no instalado"
            missing="$missing $dep"
        fi
    done

    if [ -n "$missing" ]; then
        echo ""
        if confirm "¿Instalar dependencias faltantes?${missing}"; then
            fzf_install_deps "$missing"
        fi
    fi
}

fzf_install_deps() {
    local deps="$1"
    for dep in $deps; do
        print_step "Instalando ${dep}..."
        case "$PKG_MANAGER" in
            brew)   brew install "$dep" ;;
            apt)    sudo apt-get install -y "$dep" ;;
            pacman) sudo pacman -S --noconfirm "$dep" ;;
            dnf)    sudo dnf install -y "$dep" ;;
        esac
    done
    print_success "Dependencias instaladas"
}

fzf_setup_shell_integration() {
    # Regenerar ~/.fzf.zsh con la versión actual de fzf
    local fzf_base=""

    case "$PKG_MANAGER" in
        brew)
            fzf_base="$(brew --prefix)/opt/fzf"
            ;;
        *)
            # Buscar instalación de fzf
            if [ -d "$HOME/.fzf" ]; then
                fzf_base="$HOME/.fzf"
            elif [ -d "/usr/share/fzf" ]; then
                fzf_base="/usr/share/fzf"
            fi
            ;;
    esac

    if [ -n "$fzf_base" ] && [ -f "$fzf_base/install" ]; then
        print_step "Configurando shell integration de fzf..."
        "$fzf_base/install" --key-bindings --completion --no-update-rc --no-bash --no-fish 2>/dev/null
        print_success "Shell integration configurada (~/.fzf.zsh)"
    elif [ -f "$HOME/.fzf.zsh" ]; then
        print_success "Shell integration ya existe (~/.fzf.zsh)"
    else
        print_warning "No se pudo configurar shell integration automáticamente"
        print_info "fzf seguirá funcionando pero sin keybindings (CTRL-T, CTRL-R, ALT-C)"
    fi
}

fzf_configure() {
    apply_stow "fzf"
}

fzf_show_security_fixes() {
    echo ""
    print_section "Correcciones de seguridad"
    echo ""
    echo -e "${DIM}    ✔ eval en preview de export/unset → reemplazado por printenv${NC}"
    echo -e "${DIM}    ✔ find como default command → reemplazado por fd (respeta .gitignore)${NC}"
    echo -e "${DIM}    ✔ ls | fzf | xargs en aliases → reemplazado por funciones seguras${NC}"
    echo ""
}

fzf_main() {
    echo ""
    print_section "fzf — Fuzzy finder"
    echo ""

    # 1. Verificar instalación
    local is_installed=false
    if fzf_check_installed; then
        is_installed=true

        # Verificar si es versión vieja
        local version
        version=$(fzf --version 2>/dev/null | awk '{print $1}' | tr -d '.')
        # 0.28.0 → 0280, queremos al menos 0.40.0 → 0400
        if [ "${version:-0}" -lt "0400" ] 2>/dev/null; then
            print_warning "Versión desactualizada — se recomienda 0.40+"
            if confirm "¿Actualizar fzf?"; then
                fzf_update
            fi
        fi
    else
        if confirm "¿Instalar fzf?"; then
            fzf_install || return 1
        else
            return 1
        fi
    fi

    # 2. Dependencias
    fzf_check_deps

    # 3. Shell integration
    echo ""
    print_section "Shell integration"
    echo ""
    fzf_setup_shell_integration

    # 4. Mostrar fixes de seguridad
    fzf_show_security_fixes

    # 5. Aplicar configuración
    echo ""
    print_section "Aplicar configuración"
    echo ""
    print_info "Se aplicará:"
    echo -e "${DIM}    .fzf_config — opts, keybinds, previews, funciones (fe, fcd, frg, fbr, fproject)${NC}"
    echo ""

    if confirm "¿Aplicar configuración de fzf?"; then
        fzf_configure
    else
        print_info "Puedes aplicarla después: stow -d ~/dotfiles -t ~ fzf"
        return 0
    fi

    echo ""
    print_success "Módulo fzf configurado"
    print_info "Funciones disponibles: ${BOLD}fe${NC}${CYAN} (editar), ${BOLD}fcd${NC}${CYAN} (cd), ${BOLD}frg${NC}${CYAN} (buscar contenido), ${BOLD}fbr${NC}${CYAN} (git branch), ${BOLD}fproject${NC}${CYAN} (proyectos)"
    print_info "Ejecuta ${BOLD}source ~/.zshrc${NC}${CYAN} o abre nueva terminal${NC}"
}
