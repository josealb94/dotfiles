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
kv "Ctrl+Shift+P  →  L"       "Copiar línea (trim espacios laterales)"
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

section "HERDR" "multiplexor de agentes — prefijo ctrl+b (apretás, soltás, tecla)"
kv "prefix+?"                 "Ver atajos ACTIVOS (fuente de verdad)"
kv "prefix+q"                 "Desadjuntarse — todo sigue corriendo"
kv "prefix+s"                 "Ajustes (theme·indicators·sound·toasts·integrations)"
kv "prefix+b"                 "Mostrar/ocultar sidebar"
echo
note "── Panes ──"
kv "prefix+v"                 "Split vertical (derecha)"
kv "prefix+minus"             "Split horizontal (abajo)"
kv "prefix+h / j / k / l"     "Foco izquierda / abajo / arriba / derecha"
kv "prefix+tab"               "Ciclar al siguiente pane"
kv "prefix+z"                 "Zoom pane (pantalla completa)"
kv "prefix+r"                 "Modo redimensionar"
kv "prefix+e"                 "Editar el scrollback"
kv "prefix+x"                 "Cerrar pane"
echo
note "── Tabs ──"
kv "prefix+c"                 "Nueva tab"
kv "prefix+1..9"              "Ir a tab N"
kv "prefix+p / prefix+n"      "Tab anterior / siguiente"
kv "prefix+shift+x"           "Cerrar tab"
echo
note "── CERRAR vs DESADJUNTARSE ──"
kv "prefix+q"                 "DESADJUNTARSE — no cierra nada, todo sigue vivo"
kv "prefix+x"                 "Cerrar PANE — mata el proceso de adentro"
kv "prefix+shift+x"           "Cerrar TAB"
kv "prefix+shift+d"           "Cerrar WORKSPACE (pide confirmación)"
kv "herdr server stop"        "Apagar TODO — mata el servidor y sus procesos"
echo
note "Con agentes largos casi siempre querés prefix+q, no prefix+x."
note "Cerrar kitty con Cmd+Q equivale a desadjuntarse: el servidor sigue vivo."
echo
note "── Varios dispositivos a la vez ──"
kv "iPhone + iPad + laptop"   "Pueden estar adjuntos SIMULTÁNEAMENTE"
kv "cada cliente"             "Tiene su propio foco y su propio tamaño"
echo
note "Herdr NO encoge al cliente más chico como tmux: cada uno usa su geometría."
note "Conectar el iPad no desconecta el teléfono — nadie pierde su sesión."
note "Verificado: 2 clientes del iPhone adjuntos y el área siguió en 257x65."
echo
note "El único riesgo: dos clientes en el MISMO pane → las teclas se intercalan."
note "    Solución: un dispositivo por workspace (ctrl+shift+1..9)."
note "mosh deja su proceso vivo al cerrar la app (~25 MB por cliente):"
note "    salí con prefix+q para no acumular procesos huérfanos."
echo
note "── Nombrar y buscar ──"
kv "prefix+shift+w"           "Renombrar WORKSPACE"
kv "prefix+shift+t"           "Renombrar tab"
kv "prefix+shift+p"           "Renombrar pane"
kv "prefix+g"                 "Ir a... (buscador por nombre)"
kv "prefix+w"                 "Selector de workspaces"
echo
note "Nombrá con shift+w y encontrá con prefix+g — más rápido que recordar números"
echo
note "── Workspaces y worktrees ──"
kv "prefix+shift+n"           "Nuevo workspace"
kv "prefix+shift+g"           "Nuevo worktree (crea rama + workspace)"
kv "prefix+shift+d"           "Cerrar workspace"
echo
note "── Navegación vim-style (config propia) ──"
kv "prefix+shift+h / +l"      "Workspace anterior / siguiente"
kv "prefix+shift+k / +j"      "Agente anterior / siguiente"
kv "prefix+space"             "Volver al pane anterior (alt-tab)"
kv "ctrl+shift+alt+arrows"    "Redimensionar sin modo resize"
echo
note "── Índices DIRECTOS (sin prefijo) ──"
kv "ctrl+1..9"                "Ir a tab N"
kv "ctrl+shift+1..9"          "Ir a workspace N"
kv "ctrl+alt+1..9"            "Enfocar agente N"
echo
note "Elegidos tras verificar que NO chocan con kitty en macOS ni en Linux."
note "alt+1..9 se descartó: en Linux kitty ya lo usa para ir a tab."
echo
note "Con foco en el sidebar NO se usa prefijo:  ↑ ↓ mueven workspace · h j k l mueven pane"
note "Choca con tmux (mismo ctrl+b) — no anidarlos. Con kitty (Cmd+*) no hay conflicto."
note "Referencia completa en el vault: dev-tools/keybindings/herdr.md"

section "HERDR — CLI" "para scriptear y para lanzar con otra configuración"
note "── Lanzar ──"
kv "herdr"                    "Lanzar o reatachar la sesión por defecto"
kv "herdr --session <nombre>" "Sesión persistente con nombre propio"
kv "herdr --remote <ssh>"     "Atachar a un Herdr remoto por SSH"
kv "herdr machine add <host>" "Guardar una máquina SSH"
kv "herdr --machine <l> <cmd>" "Correr un comando en esa máquina"
echo
note "── Diagnóstico ──"
kv "herdr status"             "Estado de cliente y servidor"
kv "herdr config check"       "Validar config.toml"
kv "herdr server reload-config" "Recargar config SIN reiniciar"
kv "herdr server stop"        "Matar el servidor"
kv "herdr config reset-keys"  "Respaldar y borrar keybindings propios"
kv "HERDR_LOG=herdr=debug"    "Prefijo para arranque con log verboso"
echo
note "── Workspaces, worktrees y panes ──"
kv "workspace create --label X" "Crear workspace (acepta --cwd, --env, --focus)"
kv "workspace rename <id> <X>" "Renombrar (los ids salen de 'workspace list')"
kv "worktree create --branch X" "Crear worktree + abrirlo como workspace"
kv "pane run / send-text"     "Ejecutar o escribir en un pane"
kv "pane wait-output"         "Esperar a que un pane imprima algo"
echo
note "Logs en ~/.config/herdr/ · config en ~/.config/herdr/config.toml (symlink al repo)"
note "Referencia completa en el vault: dev-tools/keybindings/herdr.md"

section "NOTAS"
note "copy_on_select=clipboard — seleccionar con mouse ya copia (no hace falta Cmd+C)"
note "Sequential keymaps (\`>\`): solté la primera, presiono la segunda."
note "    Ej: Ctrl+Shift+P,  SUELTO,  presiono U  →  copia URL"
note "macOS con teclado ES: Option DERECHA tipea @ (Opt+Q), #, {, ["
note "                      la IZQUIERDA sigue siendo Alt para shortcuts"

echo
} | less -R
