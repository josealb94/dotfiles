#!/usr/bin/env bash
# =============================================================================
# tailscale.sh — Red mesh privada sobre WireGuard
# =============================================================================
# Conecta tus máquinas como si fueran una LAN, sin abrir puertos en el router.
# Plan Personal gratis: 6 usuarios, dispositivos ilimitados.
# Docs: https://tailscale.com/kb
# =============================================================================

TAILSCALE_APP_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

tailscale_get_version() {
    command_exists tailscale || return 1
    tailscale version 2>/dev/null | head -1
}

tailscale_install() {
    print_step "Instalando Tailscale..."
    case "$PKG_MANAGER" in
        brew)
            # GUI de macOS (incluye el CLI dentro del bundle)
            brew install --cask tailscale-app
            ;;
        apt|pacman|dnf)
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
        *)
            print_error "PKG_MANAGER no soportado: ${PKG_MANAGER}"
            print_info "Instalación manual: https://tailscale.com/download"
            return 1
            ;;
    esac
}

tailscale_update() {
    print_step "Actualizando Tailscale..."
    if [ "$PKG_MANAGER" = "brew" ]; then
        brew upgrade --cask tailscale-app
    else
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
}

# Elige un directorio de bin que REALMENTE esté en el PATH del usuario.
# En Apple Silicon /usr/local/bin suele existir pero no estar en el PATH, así que
# no sirve de destino aunque /etc/paths lo liste.
tailscale_pick_bin_dir() {
    local d
    for d in "$(brew --prefix 2>/dev/null)/bin" /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
        [ -d "$d" ] || continue
        case ":$PATH:" in *":$d:"*) echo "$d"; return 0 ;; esac
    done
    return 1
}

# En macOS el CLI vive dentro del .app y no queda en el PATH
tailscale_link_cli() {
    [ "$OS" = "macos" ] || return 0
    command_exists tailscale && return 0

    if [ ! -x "$TAILSCALE_APP_CLI" ]; then
        print_warning "No se encontró el CLI dentro de Tailscale.app"
        return 1
    fi

    local bindir
    if ! bindir=$(tailscale_pick_bin_dir); then
        print_warning "No se encontró un directorio del PATH donde enlazar"
        print_info "Usalo con la ruta completa: ${TAILSCALE_APP_CLI}"
        return 1
    fi

    local target="${bindir}/tailscale"
    local sudo_cmd=""
    [ -w "$bindir" ] || sudo_cmd="sudo"

    print_info "El CLI de Tailscale no está en el PATH"
    print_info "Se crea un wrapper, no un symlink (ver nota abajo)"
    if confirm "¿Crear wrapper en ${target}?${sudo_cmd:+ (pide sudo)}"; then
        # IMPORTANTE: tiene que ser un wrapper que haga exec con la RUTA REAL.
        # Un symlink hace que argv[0] sea "tailscale" y el binario Swift falla con
        #   "Fatal error: The current bundleIdentifier is unknown to the registry"
        # porque resuelve su bundle a partir de la ruta del ejecutable.
        $sudo_cmd rm -f "$target"
        printf '#!/bin/sh\nexec "%s" "$@"\n' "$TAILSCALE_APP_CLI" | $sudo_cmd tee "$target" >/dev/null \
            && $sudo_cmd chmod +x "$target" \
            && print_success "CLI disponible como 'tailscale'" \
            || { print_error "No se pudo crear el wrapper"; return 1; }
    else
        print_info "Podés usarlo como: ${TAILSCALE_APP_CLI}"
    fi
}

tailscale_status() {
    if ! command_exists tailscale; then
        print_warning "CLI no disponible — no se puede consultar el estado"
        return 1
    fi

    if tailscale status >/dev/null 2>&1; then
        print_success "Conectado al tailnet"
        tailscale status 2>/dev/null | head -8 | while read -r line; do
            echo -e "${DIM}    ${line}${NC}"
        done
        return 0
    fi

    print_warning "Instalado pero sin conectar"
    print_info "Conectalo con: tailscale up"
    return 1
}

tailscale_show_hardening() {
    echo ""
    print_section "Endurecerlo (10 min en la consola de administración)"
    echo ""
    echo -e "${DIM}    ACLs${NC}              el default es red plana: todos se alcanzan entre sí"
    echo -e "${DIM}    Device approval${NC}   aprobar cada dispositivo nuevo antes de que entre"
    echo -e "${DIM}    Key expiry${NC}        activado (default: 180 días)"
    echo -e "${DIM}    2FA${NC}               en el proveedor de identidad del login"
    echo -e "${DIM}    MagicDNS${NC}          para usar nombres en vez de IPs"
    echo ""
    print_warning "NO habilitar Funnel: es la única función que publica un servicio en internet"
    print_warning "NO activar Tailscale SSH: rompe la autenticación por clave que usa Moshi"
    echo ""
    print_info "Consola: https://login.tailscale.com/admin"
    print_info "Runbook completo: docs/setup-herdr-moshi-tailscale.md"
}

# -- Entry point --------------------------------------------------------------

tailscale_main() {
    echo ""
    print_section "Red — Tailscale"
    echo ""

    local version
    version=$(tailscale_get_version)

    # En macOS puede estar la app pero no el CLI en el PATH
    if [ -z "$version" ] && [ "$OS" = "macos" ] && [ -x "$TAILSCALE_APP_CLI" ]; then
        print_success "Tailscale.app instalado"
        tailscale_link_cli
        version=$(tailscale_get_version)
    fi

    if [ -n "$version" ]; then
        print_success "Tailscale instalado (${version})"
        echo ""
        echo -e "    ${BOLD}u${NC}) Actualizar"
        echo -e "    ${BOLD}e${NC}) Ver estado del tailnet"
        echo -e "    ${BOLD}h${NC}) Ver checklist de endurecimiento"
        echo -e "    ${BOLD}s${NC}) Saltar"
        echo ""
        local action
        print_prompt "Opción"
        read -r action

        case "$action" in
            u|U) tailscale_update ;;
            e|E) tailscale_status ;;
            h|H) tailscale_show_hardening ;;
            s|S) print_info "Saltando Tailscale"; return 0 ;;
            *)   print_error "Opción no válida"; return 1 ;;
        esac
    else
        print_warning "Tailscale no está instalado"
        if confirm "¿Instalar Tailscale?"; then
            if tailscale_install; then
                tailscale_link_cli
                print_success "Tailscale instalado"
                echo ""
                print_info "Siguiente paso: abrir la app (o 'tailscale up') e iniciar sesión"
                tailscale_show_hardening
            else
                print_error "Falló la instalación de Tailscale"
                return 1
            fi
        fi
    fi
}
