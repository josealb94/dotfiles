#!/usr/bin/env bash
# =============================================================================
# fzf.sh — Módulo de instalación y configuración de fzf + herramientas
# =============================================================================

# Herramientas que fzf usa para previews y búsquedas (binarios reales).
# install_tool sabe traducir cada uno al paquete correcto por OS.
FZF_DEPS="fd bat tree rg"

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
        if command_exists "$dep"; then
            local ver
            ver=$("$dep" --version 2>/dev/null | head -1)
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
        # install_tool conoce las particularidades por OS:
        #   fd  → apt: paquete fd-find, binario fdfind (symlink en ~/.local/bin)
        #   bat → apt: paquete bat,     binario batcat  (symlink en ~/.local/bin)
        #   rg  → todos: paquete ripgrep, binario rg
        install_tool "$dep" || print_error "Falló instalación de ${dep}"
    done
    print_success "Dependencias procesadas"
}

fzf_setup_shell_integration() {
    # Detectar dónde viven key-bindings.zsh y completion.zsh según el origen.
    # Cada distro/package manager los pone en una ruta distinta — no asumimos
    # que existe el script `install` de upstream (no viene en apt/pacman/dnf).
    local key_bindings=""
    local completion=""
    local source_label=""

    case "$PKG_MANAGER" in
        brew)
            local prefix
            prefix="$(brew --prefix fzf 2>/dev/null)"
            if [ -n "$prefix" ]; then
                key_bindings="$prefix/shell/key-bindings.zsh"
                completion="$prefix/shell/completion.zsh"
                source_label="brew"
            fi
            ;;
        apt)
            # Debian/Ubuntu/Kali/Parrot: archivos como documentación
            key_bindings="/usr/share/doc/fzf/examples/key-bindings.zsh"
            completion="/usr/share/doc/fzf/examples/completion.zsh"
            source_label="apt"
            ;;
        pacman)
            key_bindings="/usr/share/fzf/key-bindings.zsh"
            completion="/usr/share/fzf/completion.zsh"
            source_label="pacman"
            ;;
        dnf)
            key_bindings="/usr/share/fzf/shell/key-bindings.zsh"
            completion="/usr/share/fzf/shell/completion.zsh"
            source_label="dnf"
            ;;
    esac

    # Fallback: instalación manual via git clone (~/.fzf/shell/)
    if [ ! -f "$key_bindings" ] && [ -d "$HOME/.fzf/shell" ]; then
        key_bindings="$HOME/.fzf/shell/key-bindings.zsh"
        completion="$HOME/.fzf/shell/completion.zsh"
        source_label="git"
    fi

    if [ ! -f "$key_bindings" ] || [ ! -f "$completion" ]; then
        if [ -f "$HOME/.fzf.zsh" ]; then
            print_success "Shell integration ya existe (~/.fzf.zsh)"
            return 0
        fi
        print_warning "No se encontraron archivos de integración de fzf"
        print_info "Buscado en: ${key_bindings:-(ruta no detectada)}"
        print_info "fzf seguirá funcionando pero sin keybindings (CTRL-T, CTRL-R, ALT-C)"
        return 1
    fi

    # Backup si hay un .fzf.zsh real (no symlink, no auto-generado por nosotros)
    if [ -f "$HOME/.fzf.zsh" ] && [ ! -L "$HOME/.fzf.zsh" ] && \
       ! head -1 "$HOME/.fzf.zsh" 2>/dev/null | grep -q "Generado por dotfiles"; then
        cp "$HOME/.fzf.zsh" "$HOME/.fzf.zsh.backup.$(date +%Y%m%d)"
        print_info "Backup de .fzf.zsh anterior → ~/.fzf.zsh.backup.$(date +%Y%m%d)"
    fi

    print_step "Generando ~/.fzf.zsh (${source_label})..."
    cat > "$HOME/.fzf.zsh" <<EOF
# ~/.fzf.zsh — Generado por dotfiles (origen: ${source_label})
# fzf shell integration: keybindings (CTRL-T, CTRL-R, ALT-C) y completion

# Auto-completion (solo en shells interactivas)
[[ \$- == *i* ]] && source "${completion}" 2>/dev/null

# Key bindings
source "${key_bindings}"
EOF
    print_success "Shell integration configurada (~/.fzf.zsh → ${source_label})"
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
