#!/usr/bin/env bash
# =============================================================================
# claude_statusline.sh — Status line de Claude Code
#
# Aplica el paquete Stow `claude` (~/.claude/statusline-command.sh) y registra
# la clave `statusLine` en ~/.claude/settings.json con jq.
#
# settings.json NO se gestiona con Stow: tiene configuración personal por
# máquina (autoMode, hooks, plugins con rutas absolutas) y Claude Code lo
# reescribe solo. Acá solo se toca la clave statusLine; el resto queda igual.
# =============================================================================

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
# refreshInterval: re-ejecuta el script cada N segundos aunque la sesión esté
# inactiva (ej. esperando subagentes en background), para que git, caché y
# rate limits no queden desactualizados.
CLAUDE_STATUSLINE='{"type":"command","command":"bash ~/.claude/statusline-command.sh","refreshInterval":10}'

claude_statusline_check_deps() {
    local dep ok=0
    for dep in jq git; do
        if command_exists "$dep"; then
            print_success "$dep instalado"
        elif confirm "¿Instalar $dep? (requerido por el status line)"; then
            if install_tool "$dep"; then
                print_success "$dep instalado"
            else
                ok=1
            fi
        else
            print_warning "$dep no está instalado"
            ok=1
        fi
    done
    return $ok
}

claude_statusline_apply_script() {
    # Crear ~/.claude antes del stow: si no existe, stow "pliega" el directorio
    # entero en un symlink al repo y Claude Code escribiría todo dentro del repo.
    mkdir -p "$CLAUDE_DIR"
    apply_stow "claude"
}

claude_statusline_apply_settings() {
    if [ ! -f "$CLAUDE_SETTINGS" ]; then
        echo '{}' > "$CLAUDE_SETTINGS"
    fi

    if ! jq empty "$CLAUDE_SETTINGS" 2>/dev/null; then
        print_error "$CLAUDE_SETTINGS no es JSON válido; no se modifica"
        return 1
    fi

    if [ "$(jq --argjson sl "$CLAUDE_STATUSLINE" '.statusLine == $sl' "$CLAUDE_SETTINGS")" = "true" ]; then
        print_success "statusLine ya configurado en settings.json"
        return 0
    fi

    local current
    current=$(jq -c '.statusLine // empty' "$CLAUDE_SETTINGS")
    if [ -n "$current" ]; then
        print_info "statusLine actual:"
        echo -e "${DIM}    ${current}${NC}"
    fi
    print_info "statusLine nuevo:"
    echo -e "${DIM}    ${CLAUDE_STATUSLINE}${NC}"

    if ! confirm "¿Actualizar statusLine en ~/.claude/settings.json?"; then
        print_info "Saltando settings.json"
        return 0
    fi

    local backup tmp
    backup="${CLAUDE_SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CLAUDE_SETTINGS" "$backup"
    # Escritura atómica: temporal en el mismo directorio + mv.
    # cp -p para que el temporal conserve los permisos del original.
    tmp=$(mktemp "${CLAUDE_SETTINGS}.XXXXXX") || return 1
    cp -p "$CLAUDE_SETTINGS" "$tmp"
    if jq --argjson sl "$CLAUDE_STATUSLINE" '.statusLine = $sl' "$CLAUDE_SETTINGS" > "$tmp"; then
        mv "$tmp" "$CLAUDE_SETTINGS"
        print_success "statusLine actualizado (backup: ${backup})"
    else
        rm -f "$tmp"
        print_error "Falló la escritura de settings.json"
        return 1
    fi
}

claude_statusline_main() {
    echo ""
    print_section "Claude Code — status line"
    echo ""

    if ! command_exists claude; then
        print_warning "Claude Code no está instalado"
        print_info "Se aplica igual; instalalo desde el módulo apps o con el cask CUSTOM_claude_code"
    fi

    claude_statusline_check_deps || print_warning "Sin jq/git el status line se verá incompleto"
    claude_statusline_apply_script || return 1
    claude_statusline_apply_settings || return 1

    echo ""
    print_success "Módulo Claude Code completado"
    print_info "El status line se actualiza en la próxima interacción con Claude Code"
    print_info "Repos con status line propio (ej. AI-DLC): bash ~/.claude/statusline-link-project.sh"
    print_info "Guía completa: docs/setup-claude-statusline.md"
}
