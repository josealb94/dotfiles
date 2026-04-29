#!/usr/bin/env bash
# =============================================================================
# apps.sh — Módulo de instalación de apps de escritorio via Homebrew Cask
# =============================================================================

# Formato: "cask_name|Nombre visible|Categoría"
APP_LIST=(
    # -- Desarrollo --
    "visual-studio-code|Visual Studio Code|Desarrollo"
    "cursor|Cursor|Desarrollo"
    "zed|Zed|Desarrollo"
    "sublime-text|Sublime Text|Desarrollo"
    "docker|Docker Desktop|Desarrollo"
    "postman|Postman|Desarrollo"
    # -- IA --
    "claude|Claude|IA"
    "chatgpt|ChatGPT|IA"
    "ollama-app|Ollama|IA"
    "opencode-desktop|OpenCode|IA"
    # -- Productividad --
    "raycast|Raycast|Productividad"
    "obsidian|Obsidian|Productividad"
    "notion|Notion|Productividad"
    "slack|Slack|Productividad"
    # -- Git --
    "comet|Comet|Git"
    # -- Browsers --
    "arc|Arc|Browser"
    "google-chrome|Google Chrome|Browser"
    "brave-browser|Brave|Browser"
    # -- Media --
    "spotify|Spotify|Media"
)

# Resultados del proceso
APPS_INSTALLED=()
APPS_SKIPPED=()
APPS_FAILED=()
APPS_ALREADY=()

apps_is_installed() {
    local cask_name="$1"

    # Primero verificar en brew
    if brew list --cask "$cask_name" >/dev/null 2>&1; then
        return 0
    fi

    # Fallback: buscar en /Applications/ por nombre de app
    local app_name
    case "$cask_name" in
        visual-studio-code) app_name="Visual Studio Code" ;;
        sublime-text)       app_name="Sublime Text" ;;
        google-chrome)      app_name="Google Chrome" ;;
        brave-browser)      app_name="Brave Browser" ;;
        docker)             app_name="Docker" ;;
        *)                  app_name=$(echo "$cask_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1') ;;
    esac

    [ -d "/Applications/${app_name}.app" ]
}

APPS_UPDATED=()

apps_install_one() {
    local cask_name="$1"
    local display_name="$2"

    if apps_is_installed "$cask_name"; then
        # Verificar si hay actualización disponible via brew
        if brew list --cask "$cask_name" >/dev/null 2>&1; then
            local outdated
            outdated=$(brew outdated --cask "$cask_name" 2>/dev/null)
            if [ -n "$outdated" ]; then
                print_warning "$display_name tiene actualización disponible"
                if confirm "¿Actualizar $display_name?"; then
                    local output
                    output=$(brew upgrade --cask "$cask_name" 2>&1)
                    if [ $? -eq 0 ]; then
                        APPS_UPDATED+=("$display_name")
                        print_success "$display_name actualizado"
                    else
                        print_error "$display_name no se pudo actualizar"
                    fi
                    return 0
                fi
            fi
        fi
        APPS_ALREADY+=("$display_name")
        return 0
    fi

    print_step "Instalando ${display_name}..."
    local output
    output=$(brew install --cask "$cask_name" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        APPS_INSTALLED+=("$display_name")
        print_success "$display_name instalado"
    else
        # Limpiar instalación fallida
        brew uninstall --cask "$cask_name" >/dev/null 2>&1
        APPS_FAILED+=("$display_name|$output")
        print_error "$display_name falló"
    fi
}

apps_show_menu() {
    local current_category=""
    local i=1

    for entry in "${APP_LIST[@]}"; do
        local cask_name display_name category
        cask_name=$(echo "$entry" | cut -d'|' -f1)
        display_name=$(echo "$entry" | cut -d'|' -f2)
        category=$(echo "$entry" | cut -d'|' -f3)

        # Header de categoría
        if [ "$category" != "$current_category" ]; then
            current_category="$category"
            echo ""
            echo -e "    ${BOLD}── ${category} ──${NC}"
        fi

        # Indicar si ya está instalada
        if apps_is_installed "$cask_name"; then
            echo -e "    ${DIM}${i}) ${display_name}  [instalada]${NC}"
        else
            echo -e "    ${BOLD}${i}${NC}) ${display_name}"
        fi
        i=$((i + 1))
    done
}

apps_parse_selection() {
    local input="$1"
    local max="$2"
    local selected=()

    # Soportar: "1 3 5", "1,3,5", "1-5", "all", "a"
    if [ "$input" = "all" ] || [ "$input" = "a" ]; then
        for i in $(seq 1 "$max"); do
            selected+=("$i")
        done
    else
        # Reemplazar comas por espacios
        input=$(echo "$input" | tr ',' ' ')

        for token in $input; do
            if echo "$token" | grep -q '-'; then
                # Rango: 1-5
                local start end
                start=$(echo "$token" | cut -d'-' -f1)
                end=$(echo "$token" | cut -d'-' -f2)
                for i in $(seq "$start" "$end"); do
                    selected+=("$i")
                done
            else
                selected+=("$token")
            fi
        done
    fi

    echo "${selected[@]}"
}

apps_show_report() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║          Reporte de instalación          ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ${#APPS_INSTALLED[@]} -gt 0 ]; then
        print_section "Instaladas (${#APPS_INSTALLED[@]})"
        for app in "${APPS_INSTALLED[@]}"; do
            print_success "$app"
        done
    fi

    if [ ${#APPS_UPDATED[@]} -gt 0 ]; then
        echo ""
        print_section "Actualizadas (${#APPS_UPDATED[@]})"
        for app in "${APPS_UPDATED[@]}"; do
            print_success "$app"
        done
    fi

    if [ ${#APPS_ALREADY[@]} -gt 0 ]; then
        echo ""
        print_section "Ya instaladas (${#APPS_ALREADY[@]})"
        for app in "${APPS_ALREADY[@]}"; do
            print_info "$app"
        done
    fi

    if [ ${#APPS_SKIPPED[@]} -gt 0 ]; then
        echo ""
        print_section "Saltadas (${#APPS_SKIPPED[@]})"
        for app in "${APPS_SKIPPED[@]}"; do
            print_info "$app"
        done
    fi

    if [ ${#APPS_FAILED[@]} -gt 0 ]; then
        echo ""
        print_section "Fallidas (${#APPS_FAILED[@]}) — requieren instalación manual"
        for entry in "${APPS_FAILED[@]}"; do
            local app_name error_msg
            app_name=$(echo "$entry" | cut -d'|' -f1)
            error_msg=$(echo "$entry" | cut -d'|' -f2-)
            print_error "$app_name"
            echo -e "${DIM}    $(echo "$error_msg" | tail -1)${NC}"
        done
    fi

    echo ""
}

apps_check_brew() {
    if ! command_exists brew; then
        print_error "Homebrew no está instalado"
        print_info "Instálalo desde: https://brew.sh"
        return 1
    fi
    return 0
}

apps_main() {
    echo ""
    print_section "Apps de escritorio"
    echo ""

    # Verificar Homebrew
    if ! apps_check_brew; then
        return 1
    fi

    # Mostrar menú
    apps_show_menu

    echo ""
    echo -e "    ${BOLD}a${NC}) Instalar todas"
    echo -e "    ${BOLD}0${NC}) Saltar"
    echo ""
    print_info "Selecciona por número, rango o combinación: ${BOLD}1 3 5${NC}${CYAN}, ${BOLD}1-5${NC}${CYAN}, ${BOLD}1,3,7-10${NC}${CYAN}, ${BOLD}a${NC}${CYAN} (todas)"
    echo ""
    local choice
    print_prompt "Apps a instalar"
    read -r choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        print_info "Saltando instalación de apps"
        return 0
    fi

    local total=${#APP_LIST[@]}
    local selected
    selected=$(apps_parse_selection "$choice" "$total")

    echo ""
    print_section "Instalando apps seleccionadas"
    echo ""

    for idx in $selected; do
        local array_idx=$((idx - 1))
        if [ $array_idx -ge 0 ] && [ $array_idx -lt $total ]; then
            local entry="${APP_LIST[$array_idx]}"
            local cask_name display_name
            cask_name=$(echo "$entry" | cut -d'|' -f1)
            display_name=$(echo "$entry" | cut -d'|' -f2)
            apps_install_one "$cask_name" "$display_name"
        fi
    done

    # Reporte final
    apps_show_report
}
