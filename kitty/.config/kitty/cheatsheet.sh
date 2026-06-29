#!/usr/bin/env bash
# =============================================================================
# Kitty cheatsheet — overlay con todos los bindings, estilo manpage.
# Invocado por: ctrl+shift+slash desde kitty.conf.
# Renderiza directamente a less -R; ningún tool externo más allá de less.
# Paleta Catppuccin Mocha (consistente con el tema de kitty y Starship).
# =============================================================================

# -- Paleta -------------------------------------------------------------------
mauve=$'\e[38;2;203;166;247m'
teal=$'\e[38;2;148;226;213m'
yellow=$'\e[38;2;249;226;175m'
peach=$'\e[38;2;250;179;135m'
green=$'\e[38;2;166;227;161m'
lavender=$'\e[38;2;180;190;254m'
red=$'\e[38;2;243;139;168m'
text=$'\e[38;2;205;214;244m'
subtext=$'\e[38;2;166;173;200m'
overlay=$'\e[38;2;108;112;134m'
bold=$'\e[1m'
dim=$'\e[2m'
reset=$'\e[0m'

# -- Helpers ------------------------------------------------------------------
title() {
    printf '\n  %s%sKITTY%s  %s·  cheatsheet%s\n' \
        "$bold" "$mauve" "$reset" "$subtext" "$reset"
    printf '  %s%s%s\n\n' "$overlay" "──────────────────────────────────────────────────────────────────" "$reset"
    printf '  %sBuscar: %s/palabra%s · Siguiente: %sn%s · Inicio: %sg%s · Final: %sG%s · Salir: %sq%s\n\n' \
        "$subtext" "$yellow" "$subtext" "$yellow" "$subtext" "$yellow" "$subtext" "$yellow" "$subtext" "$red" "$reset"
}

section() {
    printf '\n%s▌ %s%s%s\n' "$mauve" "$bold" "$1" "$reset"
    [ -n "$2" ] && printf '  %s%s%s\n' "$dim" "$2" "$reset"
    echo
}

# kv "Ctrl+Shift+E" "Abrir URL en browser"
kv() {
    printf '  %s%-28s%s  %s%s%s\n' "$yellow" "$1" "$reset" "$text" "$2" "$reset"
}

# Header de tabla 3 columnas
os_header() {
    printf '  %s%-28s  %-22s  %-22s%s\n' "$dim" "" "macOS" "Linux" "$reset"
}

# os_row "Split vertical" "Cmd+D" "Alt+D"
os_row() {
    printf '  %s%-28s%s  %s%-22s%s  %s%-22s%s\n' \
        "$text" "$1" "$reset" \
        "$yellow" "$2" "$reset" \
        "$yellow" "$3" "$reset"
}

note() {
    printf '  %s%s%s\n' "$dim" "$1" "$reset"
}

# -- Contenido (pipeado a less -R) -------------------------------------------
{
title

section "HINTS" "selección sin mouse — apretás, soltás, apretás la segunda letra"
kv "Ctrl+Shift+E"             "Abrir URL en browser"
kv "Ctrl+Shift+P  →  U"       "Copiar URL"
kv "Ctrl+Shift+P  →  P"       "Copiar path"
kv "Ctrl+Shift+P  →  L"       "Copiar línea entera"
kv "Ctrl+Shift+P  →  W"       "Copiar palabra"
kv "Ctrl+Shift+P  →  H"       "Copiar hash (commit/sha)"
kv "Ctrl+Shift+P  →  N"       "Copiar file:line"
kv "Ctrl+Shift+P  →  F"       "Copiar hyperlink (OSC 8)"
echo
note "Esc                         Cancelar overlay"
note "Solo opera sobre texto VISIBLE — para scrollback usar Ctrl+Shift+H"

section "SPLITS"
os_header
os_row "Split vertical"          "Cmd+D"              "Alt+D"
os_row "Split horizontal"        "Cmd+Shift+D"        "Alt+Shift+D"
os_row "Zoom split (stack)"      "Cmd+Shift+Enter"    "Alt+Shift+Enter"
os_row "Nav arriba"              "Cmd+Alt+↑"          "Alt+Super+↑"
os_row "Nav abajo"               "Cmd+Alt+↓"          "Alt+Super+↓"
os_row "Nav izquierda"           "Cmd+Alt+←"          "Alt+Super+←"
os_row "Nav derecha"             "Cmd+Alt+→"          "Alt+Super+→"
os_row "Split anterior"          "Cmd+["              "Alt+["
os_row "Split siguiente"         "Cmd+]"              "Alt+]"
os_row "Saltar por número"       "Cmd+Shift+Space"    "Alt+Shift+Space"
os_row "Resize ↑/↓/←/→"          "Cmd+Ctrl+arrows"    "Alt+Ctrl+arrows"
os_row "Igualar splits"          "Cmd+Ctrl+="         "Alt+Ctrl+="
os_row "Cerrar split"            "Cmd+W"              "Alt+W"

section "TABS"
os_header
os_row "Nueva tab (cwd)"         "Cmd+T"              "Alt+T"
os_row "Renombrar tab"           "Cmd+Shift+I"        "Alt+Shift+I"
os_row "Ir a tab 1..9"           "Cmd+1..9"           "Alt+1..9"
os_row "Tab anterior"            "Ctrl+Shift+["       "Ctrl+Shift+["
os_row "Tab siguiente"           "Ctrl+Shift+]"       "Ctrl+Shift+]"

section "VENTANA / CONFIG"
os_header
os_row "Recargar config"         "Cmd+Shift+R"        "Alt+Shift+R"
os_row "Editar config"           "Cmd+Shift+E"        "Alt+Shift+E"
os_row "Mostrar este cheatsheet" "Ctrl+Shift+/ / F1"  "Ctrl+Shift+/ / F1"
echo
note "Opacity multi-step:  Ctrl+Shift+A  →  m (más) / l (menos) / 1 (100%) / d (default)"

section "SCROLLBACK / BÚSQUEDA"
kv "Ctrl+Shift+F"             "Buscar en scrollback"
kv "Ctrl+Shift+H"             "Abrir scrollback en pager (less)"
kv "Ctrl+Shift+G"             "Repetir última búsqueda"

section "FUENTE / VISUAL"
kv "Ctrl+Shift+="             "Aumentar tamaño de fuente"
kv "Ctrl+Shift+-"             "Reducir tamaño de fuente"
kv "Ctrl+Shift+0"             "Reset tamaño de fuente"
kv "Ctrl+Shift+U"             "Unicode picker (kitten)"
kv "Ctrl+Shift+F11"           "Toggle fullscreen"

section "CLIPBOARD"
os_header
os_row "Copiar"                  "Cmd+C"              "Ctrl+Shift+C"
os_row "Pegar"                   "Cmd+V"              "Ctrl+Shift+V"

section "NOTAS"
note "copy_on_select=clipboard — seleccionar con mouse ya copia (no hace falta Cmd+C)"
note "Sequential keymaps (\`>\`): solté la primera, presiono la segunda."
note "    Ej: Ctrl+Shift+P,  SUELTO,  presiono U  →  copia URL"
note "macOS con teclado ES: Option DERECHA tipea @ (Opt+Q), #, {, ["
note "                      la IZQUIERDA sigue siendo Alt para shortcuts"

echo
} | less -R
