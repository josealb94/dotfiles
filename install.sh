#!/usr/bin/env bash
# =============================================================================
# install.sh — Instalador interactivo de dotfiles
#
# Uso:
#   ./install.sh              Menú interactivo
#   ./install.sh ghostty      Instalar/configurar módulo específico
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Cargar utilidades
# shellcheck source=scripts/utils.sh
source "$DOTFILES_DIR/scripts/utils.sh"

# Cargar configuración del usuario si existe
DOTFILES_CONF="$DOTFILES_DIR/dotfiles.conf"
if [ -f "$DOTFILES_CONF" ]; then
    # shellcheck source=/dev/null
    source "$DOTFILES_CONF"
fi

# Valores por defecto (pueden ser sobreescritos por dotfiles.conf)
DOTFILES_PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/dotfiles-private}"

# -- Módulos disponibles ------------------------------------------------------
declare_modules() {
    # Formato: nombre|descripción|estado
    # estado: ready, coming
    MODULE_LIST=(
        "ghostty|Terminal (Ghostty)|ready"
        "zsh|Shell (Zsh + Oh My Zsh)|ready"
        "git|Git (aliases, config)|coming"
        "fzf|fzf (búsqueda en terminal)|coming"
    )
}

run_module() {
    local module_name="$1"
    local module_file="$DOTFILES_DIR/scripts/modules/${module_name}.sh"

    if [ ! -f "$module_file" ]; then
        print_error "Módulo '${module_name}' no encontrado"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$module_file"
    "${module_name}_main"
}

# -- Menú principal -----------------------------------------------------------
show_menu() {
    echo ""
    print_section "Selecciona una herramienta para configurar"
    echo ""

    local i=1
    for entry in "${MODULE_LIST[@]}"; do
        local name desc status
        name=$(echo "$entry" | cut -d'|' -f1)
        desc=$(echo "$entry" | cut -d'|' -f2)
        status=$(echo "$entry" | cut -d'|' -f3)

        if [ "$status" = "ready" ]; then
            echo -e "    ${BOLD}${i}${NC}) ${desc}"
        else
            echo -e "    ${DIM}${i}) ${desc}  [próximamente]${NC}"
        fi
        i=$((i + 1))
    done

    echo ""
    echo -e "    ${BOLD}a${NC}) Instalar todo (solo módulos disponibles)"
    echo -e "    ${BOLD}0${NC}) Salir"
    echo ""
}

run_all() {
    for entry in "${MODULE_LIST[@]}"; do
        local name status
        name=$(echo "$entry" | cut -d'|' -f1)
        status=$(echo "$entry" | cut -d'|' -f3)

        if [ "$status" = "ready" ]; then
            run_module "$name"
        fi
    done
}

main() {
    print_header
    detect_os

    # Si se pasó un módulo como argumento, ejecutar directamente
    if [ $# -gt 0 ]; then
        run_module "$1"
        return
    fi

    declare_modules

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
            a|A)
                run_all
                ;;
            *)
                # Validar que sea un número dentro del rango
                if echo "$choice" | grep -qE '^[0-9]+$'; then
                    local idx=$((choice - 1))
                    if [ $idx -ge 0 ] && [ $idx -lt ${#MODULE_LIST[@]} ]; then
                        local entry="${MODULE_LIST[$idx]}"
                        local name status
                        name=$(echo "$entry" | cut -d'|' -f1)
                        status=$(echo "$entry" | cut -d'|' -f3)

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
