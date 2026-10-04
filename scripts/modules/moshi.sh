#!/usr/bin/env bash
# =============================================================================
# moshi.sh — moshi-hook: eventos de agentes hacia la app Moshi del celular
# =============================================================================
# La app Moshi (iOS/Android) es un terminal móvil para agentes. Este módulo
# instala el hook del lado del host, que es lo que habilita aprobaciones,
# diffs, Chat View y notificaciones push.
#
# INSTALACIÓN Y EMPAREJAMIENTO ESTÁN SEPARADOS a propósito:
#   - instalar no pide nada y corre desatendido
#   - emparejar es un paso aparte, cuando tengas el celular a mano
#
# El token es un bootstrap de UN SOLO USO: `moshi-hook pair` lo canjea por
# credenciales que en macOS viven en el Keychain. No es un secreto de ejecución,
# así que no hace falta persistirlo en ningún lado.
#
# Para corridas desatendidas se admite MOSHI_PAIR_TOKEN (convención de este
# módulo, no del CLI). Ver moshi_pair() para los reparos.
#
# Docs: https://getmoshi.app/docs/hooks
# =============================================================================

moshi_get_version() {
    command_exists moshi-hook || return 1
    moshi-hook version 2>/dev/null | head -1
}

# ¿Ya está emparejado? Evita volver a pedir el token en cada corrida.
# Devuelve 0 = emparejado · 1 = no emparejado · 2 = indeterminado
#
# El esquema de `status --json` no está documentado públicamente, así que esto es
# best-effort: busca varias claves plausibles y, si no reconoce ninguna, lo dice
# en vez de afirmar que no está emparejado.
moshi_is_paired() {
    command_exists moshi-hook || return 2

    local out
    out=$(moshi-hook status --json 2>/dev/null) || return 2
    [ -n "$out" ] || return 2

    if echo "$out" | grep -qiE '"(paired|is_paired|pairing)"[[:space:]]*:[[:space:]]*(true|"paired")'; then
        return 0
    fi
    if echo "$out" | grep -qiE '"(paired|is_paired|pairing)"[[:space:]]*:[[:space:]]*(false|null|"unpaired")'; then
        return 1
    fi
    return 2
}

# -- mosh: el transporte que sobrevive al cambio de red ------------------------
# `moshi-hook doctor` lo revisa como prerequisito, y es lo que permite que la
# sesión aguante pasar de WiFi a datos sin cortarse (SSH solo, no).
# Se necesita `mosh-server` en el host; el cliente lo trae la app.
# ET (Eternal Terminal) es la otra opción que soporta Moshi, pero mosh alcanza
# y está en todos los gestores de paquetes.
moshi_ensure_mosh() {
    if command_exists mosh-server; then
        return 0
    fi

    print_step "Instalando mosh (transporte resistente a cambios de red)..."
    case "$PKG_MANAGER" in
        brew)        brew install mosh ;;
        apt)         install_apt_tool mosh-server mosh ;;
        pacman)      sudo pacman -S --noconfirm mosh ;;
        dnf)         sudo dnf install -y mosh ;;
        *)
            print_warning "PKG_MANAGER no soportado para mosh: ${PKG_MANAGER}"
            print_info "Sin mosh, Moshi funciona por SSH pero la sesión se corta al cambiar de red"
            return 1
            ;;
    esac

    if command_exists mosh-server; then
        print_success "mosh instalado ($(mosh-server --version 2>&1 | head -1))"
    else
        print_warning "mosh no quedó en el PATH — revisá la instalación"
        return 1
    fi
}

moshi_install_bin() {
    moshi_ensure_mosh || true   # no bloquea: SSH solo también sirve
    print_step "Instalando moshi-hook..."
    # Evita la configuración interactiva de primer arranque
    export MOSHI_HOOK_SKIP_FIRST_RUN=1
    case "$PKG_MANAGER" in
        brew)
            brew tap rjyo/moshi
            brew trust rjyo/moshi
            brew install moshi-hook
            ;;
        apt|pacman|dnf)
            curl -fsSL https://getmoshi.app/install.sh | sh
            ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            print_info "Instalación manual: https://getmoshi.app/docs/hooks"
            return 1
            ;;
    esac
}

moshi_update() {
    print_step "Actualizando moshi-hook..."
    if [ "$PKG_MANAGER" = "brew" ]; then
        brew upgrade moshi-hook
    else
        curl -fsSL https://getmoshi.app/install.sh | sh
    fi
}

# -- Emparejamiento -----------------------------------------------------------
# El CLI solo acepta el token como flag `--token`: no hay variable de entorno
# oficial. Por eso el token queda visible en la lista de procesos mientras corre,
# se pase como se pase. MOSHI_PAIR_TOKEN existe acá para corridas desatendidas,
# NO porque sea más seguro:
#   - termina igual en --token, así que sigue apareciendo en `ps`
#   - las env vars se heredan a procesos hijos y en Linux se leen en /proc
#   - el token es de un solo uso: guardarlo es peor que teclearlo
# Nunca ponerlo en este repo ni en un rc del shell.
moshi_pair() {
    echo ""
    print_section "Emparejar con la app"
    echo ""

    local token
    if [ -n "${MOSHI_PAIR_TOKEN:-}" ]; then
        print_info "Usando MOSHI_PAIR_TOKEN del entorno (modo desatendido)"
        token="$MOSHI_PAIR_TOKEN"
    else
        print_info "Abrí Moshi en el celular: Settings → Integrations (la doc web lo llama Hooks)"
        print_warning "El token NO se guarda en este repo; se canjea por credenciales locales"
        echo ""
        print_prompt "Token de emparejamiento (no se muestra al teclear)"
        read -rs token
        echo ""
    fi

    if [ -z "$token" ]; then
        print_error "Token vacío — emparejamiento cancelado"
        return 1
    fi

    local pair_args=(pair --token "$token")
    # En Linux headless no hay Keychain: almacenamiento en archivo
    [ "$OS" != "macos" ] && pair_args+=(--store file)

    if moshi-hook "${pair_args[@]}"; then
        unset token
        print_success "Emparejado"
        [ "$OS" = "macos" ] && print_info "Credenciales guardadas en el Keychain"
        return 0
    fi

    unset token
    print_error "Falló el emparejamiento"
    print_info "Revisá que el token no haya expirado y generá uno nuevo en la app"
    return 1
}

# Ojo: `moshi-hook install` escribe en configuraciones de agentes —
# ~/.claude/settings.json, ~/.codex/config.toml y .opencode/plugins/moshi-hooks.ts —
# dejando intactos los hooks propios. Si alguno de esos archivos está gestionado por
# Stow desde este repo, revisá el diff después.
# Avisa solo si alguno de esos archivos es un symlink a este repo, en cuyo caso
# la escritura del hook caería dentro del repositorio.
moshi_warn_managed_configs() {
    local f managed=()
    for f in "$HOME/.claude/settings.json" "$HOME/.claude" \
             "$HOME/.codex/config.toml" "$HOME/.codex" "$HOME/.config/opencode"; do
        if [ -L "$f" ] && readlink "$f" | grep -q "$DOTFILES_DIR"; then
            managed+=("$f")
        fi
    done

    if [ ${#managed[@]} -gt 0 ]; then
        print_warning "Estos archivos son symlinks a este repo y el hook los va a modificar:"
        for f in "${managed[@]}"; do echo -e "${DIM}    ${f}${NC}"; done
        print_info "Revisá 'git status' y 'git diff' después de este paso"
    else
        print_info "Escribe en ~/.claude/settings.json y ~/.codex/config.toml (no gestionados por Stow)"
    fi
}

moshi_enable_service() {
    print_step "Registrando el hook..."
    moshi_warn_managed_configs
    moshi-hook install || { print_error "Falló 'moshi-hook install'"; return 1; }

    if [ "$PKG_MANAGER" = "brew" ]; then
        brew services start moshi-hook \
            && print_success "Servicio iniciado (arranca con el sistema)"
    else
        print_info "Iniciá el daemon con: moshi-hook serve"
    fi
}

moshi_status() {
    if ! command_exists moshi-hook; then
        print_warning "moshi-hook no está instalado"
        return 1
    fi
    if moshi_is_paired; then
        print_success "Emparejado con la app"
    else
        print_warning "Instalado pero sin emparejar"
    fi
    moshi-hook status 2>/dev/null | head -10 | while read -r line; do
        echo -e "${DIM}    ${line}${NC}"
    done
}

moshi_doctor() {
    command_exists moshi-hook || { print_warning "moshi-hook no está instalado"; return 1; }
    print_step "Diagnóstico..."
    moshi-hook doctor
}

moshi_show_next_steps() {
    echo ""
    print_section "Qué habilita"
    echo ""
    echo -e "${DIM}    Bandeja de aprobaciones${NC}   el agente pide permiso a tu teléfono"
    echo -e "${DIM}    Notificaciones push${NC}       te avisa cuando termina o se bloquea"
    echo -e "${DIM}    Chat View y diff viewer${NC}   revisar la conversación y los cambios"
    echo -e "${DIM}    Live Activity / Watch${NC}     estado sin abrir la app"
    echo ""
    print_info "La app se instala desde el App Store o Google Play (el plan gratis alcanza)"
    print_info "Requiere llegar al host: ./install.sh tailscale"
    print_info "Runbook: docs/setup-herdr-moshi-tailscale.md"
}

# -- Entry point --------------------------------------------------------------

moshi_main() {
    echo ""
    print_section "Agentes — Moshi (hook del host)"
    echo ""

    local version
    version=$(moshi_get_version)

    if [ -n "$version" ]; then
        print_success "moshi-hook instalado (${version})"
        command_exists mosh-server \
            || print_warning "Falta mosh — usá la opción ${BOLD}m${NC}${YELLOW} (sin él la sesión se corta al cambiar de red)"
        moshi_is_paired
        case $? in
            0) print_success "Ya emparejado — no hace falta el token" ;;
            1) print_warning "Sin emparejar — usá la opción p" ;;
            2) print_info  "Estado de emparejamiento indeterminado (revisá con 'e' o 'd')" ;;
        esac
        echo ""
        echo -e "    ${BOLD}u${NC}) Actualizar"
        echo -e "    ${BOLD}m${NC}) Instalar mosh (sesiones que sobreviven el cambio de red)"
        echo -e "    ${BOLD}p${NC}) Emparejar / re-emparejar con la app"
        echo -e "    ${BOLD}e${NC}) Ver estado"
        echo -e "    ${BOLD}d${NC}) Diagnóstico (doctor)"
        echo -e "    ${BOLD}s${NC}) Saltar"
        echo ""
        local action
        print_prompt "Opción"
        read -r action

        case "$action" in
            u|U) moshi_update ;;
            m|M) moshi_ensure_mosh ;;
            p|P) moshi_pair && moshi_enable_service ;;
            e|E) moshi_status ;;
            d|D) moshi_doctor ;;
            s|S) print_info "Saltando Moshi"; return 0 ;;
            *)   print_error "Opción no válida"; return 1 ;;
        esac
    else
        print_warning "moshi-hook no está instalado"
        if confirm "¿Instalar moshi-hook?"; then
            moshi_install_bin || { print_error "Falló la instalación"; return 1; }
            command_exists moshi-hook || { print_error "moshi-hook no quedó en el PATH"; return 1; }
            print_success "moshi-hook instalado ($(moshi_get_version))"
            echo ""

            if [ -n "${MOSHI_PAIR_TOKEN:-}" ]; then
                # Modo desatendido: una sola corrida deja todo listo
                moshi_pair && moshi_enable_service
            else
                print_info "Instalación lista. El emparejamiento es un paso aparte:"
                print_info "  ./install.sh moshi  →  opción ${BOLD}p${NC}${CYAN}  (con el celular a mano)"
                print_info "Desatendido: MOSHI_PAIR_TOKEN=<token> ./install.sh moshi"
            fi
        else
            return 0
        fi
    fi

    moshi_show_next_steps
}
