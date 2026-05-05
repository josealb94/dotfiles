#!/usr/bin/env bash
# =============================================================================
# opencode.sh — Configuración de OpenCode con Ollama local
# =============================================================================

OPENCODE_MODELS=(
    "qwen3:8b"
    "qwen2.5-coder:14b"
    "gemma3:12b"
    "qwen3:30b"
)

opencode_check_app() {
    if [ -d "/Applications/OpenCode.app" ] || command_exists opencode; then
        print_success "OpenCode instalado"
        return 0
    fi
    print_warning "OpenCode no está instalado"
    print_info "Instala OpenCode desde el módulo apps: ./install.sh apps"
    return 1
}

opencode_check_ollama() {
    if ! command_exists ollama; then
        print_warning "Ollama no está instalado"
        print_info "Instala Ollama desde el módulo apps: ./install.sh apps"
        return 1
    fi
    print_success "Ollama instalado"

    # Verificar si está corriendo
    if curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
        print_success "Ollama corriendo en localhost:11434"
        return 0
    else
        print_warning "Ollama no está corriendo"
        print_info "Inicialo desde la app de Ollama o con: ollama serve"
        return 1
    fi
}

opencode_check_models() {
    echo ""
    print_section "Modelos de Ollama"
    echo ""

    if ! command_exists ollama; then
        return 1
    fi

    local installed_models
    installed_models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

    local missing=()
    for model in "${OPENCODE_MODELS[@]}"; do
        if echo "$installed_models" | grep -qx "$model"; then
            print_success "$model"
        else
            print_warning "$model — no descargado"
            missing+=("$model")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        print_info "Modelos faltantes: ${#missing[@]}"
        if confirm "¿Descargar modelos faltantes ahora?"; then
            for model in "${missing[@]}"; do
                print_step "Descargando $model..."
                if ollama pull "$model"; then
                    print_success "$model descargado"
                else
                    print_error "$model falló al descargar"
                fi
            done
        else
            print_info "Para descargar manualmente:"
            for model in "${missing[@]}"; do
                echo -e "${DIM}    ollama pull $model${NC}"
            done
        fi
    fi
}

opencode_configure() {
    echo ""
    print_section "Aplicar configuración"
    echo ""
    print_info "Se aplicará:"
    echo -e "${DIM}    ~/.config/opencode/opencode.json — provider Ollama y modelos${NC}"
    echo -e "${DIM}    ~/.local/share/opencode/auth.json — auth placeholder para Ollama${NC}"
    echo ""

    if confirm "¿Aplicar configuración de OpenCode?"; then
        apply_stow "opencode" || return 1
        print_success "Configuración aplicada"
        print_info "Reinicia OpenCode para que detecte los modelos"
    else
        print_info "Saltando aplicación de config"
    fi
}

opencode_main() {
    echo ""
    print_section "OpenCode + Ollama"
    echo ""

    # 1. Verificar OpenCode
    opencode_check_app

    # 2. Verificar Ollama
    opencode_check_ollama

    # 3. Verificar/descargar modelos
    opencode_check_models

    # 4. Aplicar config
    opencode_configure

    echo ""
    print_success "Módulo OpenCode completado"
}
