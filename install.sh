#!/usr/bin/env bash
# =============================================================================
# install.sh — Instalador interactivo de dotfiles
#
# Uso:
#   ./install.sh                  Menú interactivo
#   ./install.sh ghostty          Instalar/configurar un módulo específico
#   ./install.sh --selective      Selección con checkboxes (whiptail)
#   ./install.sh --defaults       Instalar solo los módulos default=on del SO actual
#   ./install.sh --all            Instalar TODO lo disponible para tu SO (con confirmación)
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/utils.sh
source "$DOTFILES_DIR/scripts/utils.sh"

# Cargar apps.sh siempre (provee apps_install_one + apps_show_report
# usados cuando un entry tiene kind=cask). Solo define funciones, no
# ejecuta nada al sourcear.
# shellcheck source=scripts/modules/apps.sh
source "$DOTFILES_DIR/scripts/modules/apps.sh"

# Cargar configuración del usuario si existe
DOTFILES_CONF="$DOTFILES_DIR/dotfiles.conf"
if [ -f "$DOTFILES_CONF" ]; then
    # shellcheck source=/dev/null
    source "$DOTFILES_CONF"
fi

# Valores por defecto (pueden ser sobreescritos por dotfiles.conf)
DOTFILES_PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/dotfiles-private}"

# -- Módulos disponibles ------------------------------------------------------
# Formato: nombre|descripción|estado|os|default|kind|categoría
#   estado:    ready | coming
#   os:        macos | linux | both
#   default:   on    | off
#   kind:      module (scripts/modules/<name>.sh) | cask (brew install --cask)
#   categoría: para agrupar en el selector
#
# IMPORTANTE: el orden del manifiesto define el orden de aparición en el
# selector. Mantener agrupados por categoría.
declare_modules() {
    MODULE_LIST=(
        # -- Esenciales — CLI básico -----------------------------------------
        "zsh|Zsh + Oh My Zsh|ready|both|on|module|Esenciales"
        "git|Git (aliases, config)|ready|both|on|module|Esenciales"
        "fzf|fzf (búsqueda en terminal)|ready|both|on|module|Esenciales"
        "nvim|Neovim + LazyVim|ready|both|on|module|Esenciales"

        # -- Terminales ------------------------------------------------------
        "ghostty|Ghostty|ready|macos|on|module|Terminales"
        "kitty|Kitty|ready|linux|off|module|Terminales"

        # -- Tiling WM (Linux X11) -------------------------------------------
        "bspwm|bspwm + sxhkd (tiling WM)|ready|linux|off|module|Tiling WM"
        "polybar|Polybar (status bar)|ready|linux|off|module|Tiling WM"
        "picom|Picom (compositor)|ready|linux|off|module|Tiling WM"
        "rofi|Rofi (app launcher)|ready|linux|off|module|Tiling WM"

        # -- Editores e IDEs -------------------------------------------------
        "visual-studio-code|Visual Studio Code|ready|macos|off|cask|Editores"
        "cursor|Cursor|ready|macos|off|cask|Editores"
        "zed|Zed|ready|macos|off|cask|Editores"
        "sublime-text|Sublime Text|ready|macos|off|cask|Editores"
        "docker|Docker Desktop|ready|macos|off|cask|Editores"
        "postman|Postman|ready|macos|off|cask|Editores"

        # -- IA --------------------------------------------------------------
        "claude|Claude (desktop)|ready|macos|on|cask|IA"
        "CUSTOM_claude_code|Claude Code (CLI)|ready|macos|on|cask|IA"
        "chatgpt|ChatGPT|ready|macos|off|cask|IA"
        "ollama-app|Ollama (app)|ready|macos|off|cask|IA"
        "opencode-desktop|OpenCode (desktop)|ready|macos|off|cask|IA"
        "opencode|OpenCode + Ollama (CLI local)|ready|both|off|module|IA"

        # -- Productividad ---------------------------------------------------
        "raycast|Raycast|ready|macos|off|cask|Productividad"
        "obsidian|Obsidian|ready|macos|on|cask|Productividad"
        "notion|Notion|ready|macos|off|cask|Productividad"
        "slack|Slack|ready|macos|off|cask|Productividad"
        "comet|Comet|ready|macos|off|cask|Productividad"

        # -- Navegadores -----------------------------------------------------
        "arc|Arc|ready|macos|off|cask|Navegadores"
        "google-chrome|Google Chrome|ready|macos|off|cask|Navegadores"
        "brave-browser|Brave|ready|macos|off|cask|Navegadores"

        # -- Multimedia ------------------------------------------------------
        "spotify|Spotify|ready|macos|off|cask|Multimedia"
    )
}

# Lee un campo de un entry "nombre|desc|estado|os|default|kind|categoría"
module_field() {
    local entry="$1" field="$2"
    case "$field" in
        name)     echo "$entry" | cut -d'|' -f1 ;;
        desc)     echo "$entry" | cut -d'|' -f2 ;;
        status)   echo "$entry" | cut -d'|' -f3 ;;
        os)       echo "$entry" | cut -d'|' -f4 ;;
        default)  echo "$entry" | cut -d'|' -f5 ;;
        kind)     echo "$entry" | cut -d'|' -f6 ;;
        category) echo "$entry" | cut -d'|' -f7 ;;
    esac
}

# Filtra MODULE_LIST a los entries aplicables al OS detectado (uno por línea)
modules_for_os() {
    local entry os
    for entry in "${MODULE_LIST[@]}"; do
        os=$(module_field "$entry" os)
        if [ "$os" = "both" ] || [ "$os" = "$OS" ]; then
            echo "$entry"
        fi
    done
}

# Busca un entry por nombre. Devuelve la línea o vacío si no existe.
find_module_entry() {
    local target="$1" entry name
    for entry in "${MODULE_LIST[@]}"; do
        name=$(module_field "$entry" name)
        if [ "$name" = "$target" ]; then
            echo "$entry"
            return 0
        fi
    done
    return 1
}

# -- Dispatcher poliforme module/cask ----------------------------------------
# Dispatcha por kind. Si el nombre no está en el manifiesto, asume kind=module
# (mantiene compatibilidad con `./install.sh apps` u otros scripts manuales).
APPS_BREW_CHECKED=0

run_module() {
    local name="$1"
    local entry kind desc

    entry=$(find_module_entry "$name") || true
    if [ -n "$entry" ]; then
        kind=$(module_field "$entry" kind)
        desc=$(module_field "$entry" desc)
    fi

    case "${kind:-module}" in
        cask)
            # Verificar brew una sola vez por sesión
            if [ "$APPS_BREW_CHECKED" = "0" ]; then
                if ! apps_check_brew; then
                    return 1
                fi
                APPS_BREW_CHECKED=1
            fi
            apps_install_one "$name" "$desc"
            ;;
        module)
            local module_file="$DOTFILES_DIR/scripts/modules/${name}.sh"
            if [ ! -f "$module_file" ]; then
                print_error "Módulo '${name}' no encontrado"
                return 1
            fi
            # shellcheck source=/dev/null
            source "$module_file"
            "${name}_main"
            ;;
        *)
            print_error "Tipo de módulo desconocido: ${kind}"
            return 1
            ;;
    esac
}

# Ejecuta apps_show_report si la ronda actual instaló al menos un cask
maybe_show_apps_report() {
    local processed_any_cask="$1"
    if [ "$processed_any_cask" = "1" ]; then
        apps_show_report
    fi
}

# -- Selección con checkboxes ------------------------------------------------
SELECTED_MODULES=()

select_modules() {
    SELECTED_MODULES=()
    ensure_tui

    local available
    readarray -t available < <(modules_for_os)

    if [ ${#available[@]} -eq 0 ]; then
        print_warning "No hay módulos disponibles para ${OS}"
        return 1
    fi

    if [ "$TUI_BACKEND" = "whiptail" ]; then
        select_modules_tui "${available[@]}"
    else
        select_modules_fallback "${available[@]}"
    fi
}

select_modules_tui() {
    local entries=("$@")
    local args=()
    local entry name desc status default category flag tagged_desc

    for entry in "${entries[@]}"; do
        name=$(module_field "$entry" name)
        desc=$(module_field "$entry" desc)
        status=$(module_field "$entry" status)
        default=$(module_field "$entry" default)
        category=$(module_field "$entry" category)

        tagged_desc="[${category}] ${desc}"

        if [ "$status" != "ready" ]; then
            tagged_desc="${tagged_desc} [próximamente]"
            flag="OFF"
        elif [ "$default" = "on" ]; then
            flag="ON"
        else
            flag="OFF"
        fi
        args+=("$name" "$tagged_desc" "$flag")
    done

    local choices
    choices=$(whiptail --title "Dotfiles — Selección de módulos (${OS})" \
        --checklist "Espacio = marcar/desmarcar    Tab = botones    Esc = cancelar    Enter = confirmar" \
        24 90 16 \
        "${args[@]}" \
        3>&1 1>&2 2>&3)
    local rc=$?
    if [ $rc -ne 0 ]; then
        print_warning "Selección cancelada"
        return 1
    fi

    local choice
    for choice in $choices; do
        choice=${choice//\"/}
        SELECTED_MODULES+=("$choice")
    done
}

select_modules_fallback() {
    local entries=("$@")
    local total=${#entries[@]}
    local checked=()
    local i entry name desc status default category prev_category

    # Estado inicial según defaults
    for ((i=0; i<total; i++)); do
        entry="${entries[$i]}"
        status=$(module_field "$entry" status)
        default=$(module_field "$entry" default)
        if [ "$status" = "ready" ] && [ "$default" = "on" ]; then
            checked[$i]=1
        else
            checked[$i]=0
        fi
    done

    while true; do
        echo ""
        print_section "Módulos disponibles para ${OS} (defaults marcados)"
        echo ""
        prev_category=""
        for ((i=0; i<total; i++)); do
            entry="${entries[$i]}"
            desc=$(module_field "$entry" desc)
            status=$(module_field "$entry" status)
            category=$(module_field "$entry" category)

            # Header de categoría cuando cambia
            if [ "$category" != "$prev_category" ]; then
                echo ""
                echo -e "  ${BOLD}── ${category} ──${NC}"
                prev_category="$category"
            fi

            local mark
            if [ "${checked[$i]}" = "1" ]; then mark="[x]"; else mark="[ ]"; fi
            local idx=$((i + 1))
            if [ "$status" = "ready" ]; then
                echo -e "    ${BOLD}${idx})${NC} ${mark} ${desc}"
            else
                echo -e "    ${DIM}${idx}) ${mark} ${desc} [próximamente]${NC}"
            fi
        done
        echo ""
        echo "    a) marcar todos    n) ninguno    Enter) instalar    q) cancelar"
        echo ""
        local input
        print_prompt "Números a alternar (separados por espacio)"
        read -r input

        case "$input" in
            "")
                break
                ;;
            q|Q)
                print_warning "Selección cancelada"
                return 1
                ;;
            a|A)
                for ((i=0; i<total; i++)); do
                    status=$(module_field "${entries[$i]}" status)
                    [ "$status" = "ready" ] && checked[$i]=1
                done
                ;;
            n|N)
                for ((i=0; i<total; i++)); do checked[$i]=0; done
                ;;
            *)
                local n
                for n in $input; do
                    if echo "$n" | grep -qE '^[0-9]+$'; then
                        local idx=$((n - 1))
                        if [ $idx -ge 0 ] && [ $idx -lt $total ]; then
                            status=$(module_field "${entries[$idx]}" status)
                            if [ "$status" != "ready" ]; then
                                print_warning "Módulo ${n} no está disponible aún"
                                continue
                            fi
                            if [ "${checked[$idx]}" = "1" ]; then
                                checked[$idx]=0
                            else
                                checked[$idx]=1
                            fi
                        else
                            print_error "Número fuera de rango: ${n}"
                        fi
                    else
                        print_error "Entrada no válida: ${n}"
                    fi
                done
                ;;
        esac
    done

    for ((i=0; i<total; i++)); do
        if [ "${checked[$i]}" = "1" ]; then
            name=$(module_field "${entries[$i]}" name)
            SELECTED_MODULES+=("$name")
        fi
    done
}

run_selected_modules() {
    if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        print_warning "No se seleccionó ningún módulo"
        return 0
    fi
    echo ""
    print_info "Módulos a instalar (${#SELECTED_MODULES[@]}): ${SELECTED_MODULES[*]}"
    echo ""

    local m entry kind processed_any_cask=0
    for m in "${SELECTED_MODULES[@]}"; do
        entry=$(find_module_entry "$m") || true
        if [ -n "$entry" ]; then
            kind=$(module_field "$entry" kind)
            [ "$kind" = "cask" ] && processed_any_cask=1
        fi
        run_module "$m"
    done

    maybe_show_apps_report "$processed_any_cask"
}

# -- Menú principal -----------------------------------------------------------
show_menu() {
    echo ""
    print_section "Selecciona una herramienta para configurar (${OS})"
    echo ""

    local available entry desc status category prev_category=""
    readarray -t available < <(modules_for_os)
    local i=1

    for entry in "${available[@]}"; do
        desc=$(module_field "$entry" desc)
        status=$(module_field "$entry" status)
        category=$(module_field "$entry" category)

        if [ "$category" != "$prev_category" ]; then
            echo ""
            echo -e "  ${BOLD}── ${category} ──${NC}"
            prev_category="$category"
        fi

        if [ "$status" = "ready" ]; then
            echo -e "    ${BOLD}${i}${NC}) ${desc}"
        else
            echo -e "    ${DIM}${i}) ${desc}  [próximamente]${NC}"
        fi
        i=$((i + 1))
    done

    echo ""
    echo -e "    ${BOLD}s${NC}) Instalación selectiva (elegir varios con checkboxes)"
    echo -e "    ${BOLD}d${NC}) Instalar defaults (módulos recomendados para ${OS})"
    echo -e "    ${BOLD}a${NC}) Instalar todo (módulos disponibles para ${OS})"
    echo -e "    ${BOLD}0${NC}) Salir"
    echo ""
}

# Construye un resumen agrupado por categoría a partir de los entries listos
# Imprime un bloque visualmente alineado, una línea por categoría:
#   Esenciales: zsh, git, fzf, nvim
#   Terminales: ghostty
#   ...
print_summary_by_category() {
    local entry name status category prev_category="" current_items=""

    while IFS= read -r entry; do
        status=$(module_field "$entry" status)
        [ "$status" != "ready" ] && continue
        name=$(module_field "$entry" name)
        category=$(module_field "$entry" category)

        if [ "$category" != "$prev_category" ]; then
            if [ -n "$prev_category" ]; then
                printf "    %-15s %s\n" "${prev_category}:" "${current_items}"
            fi
            prev_category="$category"
            current_items="$name"
        else
            current_items="${current_items}, ${name}"
        fi
    done < <(modules_for_os)

    [ -n "$prev_category" ] && printf "    %-15s %s\n" "${prev_category}:" "${current_items}"
}

# Cuenta los módulos ready disponibles para el OS actual
count_available_modules() {
    local entry status total=0
    while IFS= read -r entry; do
        status=$(module_field "$entry" status)
        [ "$status" = "ready" ] && total=$((total + 1))
    done < <(modules_for_os)
    echo "$total"
}

run_all() {
    local total
    total=$(count_available_modules)

    echo ""
    print_warning "Vas a instalar TODO lo disponible para ${OS} (${total} ítems):"
    echo ""
    print_summary_by_category
    echo ""

    if ! confirm "¿Confirmar instalación de todos?"; then
        print_info "Cancelado"
        return 0
    fi

    SELECTED_MODULES=()
    local entry name status
    while IFS= read -r entry; do
        status=$(module_field "$entry" status)
        [ "$status" != "ready" ] && continue
        name=$(module_field "$entry" name)
        SELECTED_MODULES+=("$name")
    done < <(modules_for_os)

    run_selected_modules
}

run_defaults() {
    SELECTED_MODULES=()
    local entry name status default
    while IFS= read -r entry; do
        name=$(module_field "$entry" name)
        status=$(module_field "$entry" status)
        default=$(module_field "$entry" default)
        if [ "$status" = "ready" ] && [ "$default" = "on" ]; then
            SELECTED_MODULES+=("$name")
        fi
    done < <(modules_for_os)
    run_selected_modules
}

main() {
    print_header
    detect_os
    declare_modules

    # Procesar flags / argumento posicional (antes del menú)
    case "${1:-}" in
        --selective)
            select_modules && run_selected_modules
            return
            ;;
        --defaults)
            run_defaults
            return
            ;;
        --all)
            run_all
            return
            ;;
        "")
            # caer al menú interactivo
            ;;
        *)
            run_module "$1"
            return
            ;;
    esac

    # Menú interactivo
    while true; do
        show_menu
        local choice
        print_prompt "Opción"
        read -r choice

        case "$choice" in
            [0qQ])
                echo ""
                print_success "¡Hasta luego!"
                echo ""
                exit 0
                ;;
            s|S)
                select_modules && run_selected_modules
                ;;
            d|D)
                run_defaults
                ;;
            a|A)
                run_all
                ;;
            *)
                if echo "$choice" | grep -qE '^[0-9]+$'; then
                    local available
                    readarray -t available < <(modules_for_os)
                    local idx=$((choice - 1))
                    if [ $idx -ge 0 ] && [ $idx -lt ${#available[@]} ]; then
                        local entry="${available[$idx]}"
                        local name status
                        name=$(module_field "$entry" name)
                        status=$(module_field "$entry" status)
                        if [ "$status" = "ready" ]; then
                            run_module "$name"
                        else
                            print_warning "Este módulo aún no está disponible"
                        fi
                    else
                        print_error "Opción fuera de rango"
                    fi
                else
                    print_error "Opción no válida"
                fi
                ;;
        esac
    done
}

main "$@"
