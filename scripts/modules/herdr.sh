#!/usr/bin/env bash
# =============================================================================
# herdr.sh — Multiplexor de agentes de coding (persistencia + multi-máquina)
# =============================================================================
# Terminales persistentes para agentes, estado working/blocked/idle y varias
# máquinas en una sola vista por SSH. Docs: https://herdr.dev/docs
# =============================================================================

herdr_get_version() {
    command_exists herdr || return 1
    herdr --version 2>/dev/null | head -1 | awk '{print $NF}'
}

herdr_install() {
    print_step "Instalando Herdr..."
    case "$PKG_MANAGER" in
        brew)
            brew install herdr
            ;;
        apt|pacman|dnf)
            curl -fsSL https://herdr.dev/install.sh | sh
            ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            print_info "Instalación manual: https://herdr.dev/docs/installation"
            return 1
            ;;
    esac
}

herdr_update() {
    print_step "Actualizando Herdr..."
    if [ "$PKG_MANAGER" = "brew" ]; then
        brew upgrade herdr
    else
        curl -fsSL https://herdr.dev/install.sh | sh
    fi
}

herdr_configure() {
    apply_stow "herdr"
}

# -- Chequeos de entorno ------------------------------------------------------

herdr_check_tailscale() {
    if ! command_exists tailscale; then
        print_warning "Tailscale no está instalado"
        print_info "Sin él no hay acceso remoto: ./install.sh tailscale"
        return 1
    fi
    if tailscale status >/dev/null 2>&1; then
        print_success "Tailscale conectado (acceso remoto disponible)"
        return 0
    fi
    print_warning "Tailscale instalado pero no conectado"
    print_info "Conectalo con: tailscale up"
    return 1
}

herdr_check_conflicts() {
    if [ -n "${TMUX:-}" ]; then
        print_warning "Estás dentro de tmux: comparte el prefijo ctrl+b"
        print_info "No anidar Herdr dentro de tmux — salí de tmux antes de usarlo"
        return 1
    fi
    print_success "Fuera de tmux (sin choque de prefijo)"
    return 0
}

herdr_check_agents() {
    local found=()
    local agent
    for agent in claude codex opencode pi; do
        command_exists "$agent" && found+=("$agent")
    done

    if [ ${#found[@]} -eq 0 ]; then
        print_warning "No se detectó ningún agente de coding en el PATH"
        print_info "Herdr no sirve de nada sin agentes: instalá al menos uno"
        return 1
    fi
    print_success "Agentes detectados: ${found[*]}"
    return 0
}

herdr_show_next_steps() {
    echo ""
    print_section "Cómo usarlo"
    echo ""
    echo -e "${DIM}    herdr${NC}                      arranca y adjunta (otra vez, reattacha)"
    echo -e "${DIM}    claude${NC}                     dentro de un pane — Herdr lo detecta solo"
    echo -e "${DIM}    herdr machine add <host>${NC}   suma otra máquina por SSH"
    echo ""
    echo -e "${DIM}    prefix = ctrl+b${NC}            prefix+? muestra todos los atajos"
    echo -e "${DIM}    prefix+v / prefix+minus${NC}    split derecha / abajo"
    echo -e "${DIM}    prefix+c / prefix+n / +p${NC}   nueva tab / siguiente / anterior"
    echo -e "${DIM}    prefix+q${NC}                   desadjuntar (el servidor sigue vivo)"
    echo ""
    print_info "Runbook completo: docs/setup-herdr-moshi-tailscale.md"
}

# -- Entry point --------------------------------------------------------------

herdr_main() {
    echo ""
    print_section "Agentes — Herdr"
    echo ""

    local version
    version=$(herdr_get_version)

    if [ -n "$version" ]; then
        print_success "Herdr instalado (${version})"
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
            u|U) herdr_update ;;
            c|C) herdr_configure ;;
            b|B) herdr_update; herdr_configure ;;
            s|S) print_info "Saltando Herdr"; return 0 ;;
            *)   print_error "Opción no válida"; return 1 ;;
        esac
    else
        print_warning "Herdr no está instalado"
        if confirm "¿Instalar Herdr?"; then
            if herdr_install && command_exists herdr; then
                print_success "Herdr instalado ($(herdr_get_version))"
                herdr_configure
            else
                print_error "Falló la instalación de Herdr"
                return 1
            fi
        else
            return 0
        fi
    fi

    echo ""
    print_section "Entorno"
    echo ""
    herdr_check_agents
    herdr_check_tailscale
    herdr_check_conflicts

    herdr_show_next_steps
}
