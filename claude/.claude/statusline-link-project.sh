#!/usr/bin/env bash
# ~/.claude/statusline-link-project.sh
# Encadena el status line propio con el que define un proyecto (ej. AI-DLC).
#
# Claude Code ejecuta un solo statusLine y el de .claude/settings.json del
# proyecto le gana al de usuario. Este script escribe en
# .claude/settings.local.json del repo (más prioridad, no se commitea) un
# statusLine que muestra el propio y, debajo, el del proyecto.
#
# Uso (dentro del repo, o pasando la ruta):
#   bash ~/.claude/statusline-link-project.sh [dir]
#   bash ~/.claude/statusline-link-project.sh --remove [dir]

set -eu

STATUSLINE='{"type":"command","command":"bash ~/.claude/statusline-command.sh --extra-from-project","refreshInterval":10}'

remove=""
if [ "${1:-}" = "--remove" ]; then
    remove=1
    shift
fi

dir="${1:-$PWD}"
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || (cd "$dir" && pwd))
project_settings="$root/.claude/settings.json"
local_settings="$root/.claude/settings.local.json"

command -v jq >/dev/null 2>&1 || { echo "✖ Falta jq"; exit 1; }

# Escribe $1 (JSON ya generado) en settings.local.json de forma atómica,
# conservando los permisos del archivo original
write_local() {
    local tmp
    tmp=$(mktemp "${local_settings}.XXXXXX")
    cp -p "$local_settings" "$tmp"
    printf '%s\n' "$1" > "$tmp"
    mv "$tmp" "$local_settings"
}

if [ -n "$remove" ]; then
    if [ -f "$local_settings" ] && jq -e 'has("statusLine")' "$local_settings" >/dev/null 2>&1; then
        new=$(jq 'del(.statusLine)' "$local_settings")
        write_local "$new"
        echo "✔ statusLine quitado de $local_settings (vuelve a mandar el del proyecto)"
    else
        echo "ℹ $local_settings no tiene statusLine; nada que quitar"
    fi
    exit 0
fi

project_cmd=""
if [ -f "$project_settings" ]; then
    project_cmd=$(jq -r '.statusLine.command // empty' "$project_settings" 2>/dev/null || true)
fi
if [ -z "$project_cmd" ]; then
    echo "ℹ $root no define statusLine propio: ya se usa el de usuario, no hace falta enlazar"
    exit 0
fi
echo "ℹ Status line del proyecto: $project_cmd"

mkdir -p "$root/.claude"
[ -f "$local_settings" ] || echo '{}' > "$local_settings"
if ! jq empty "$local_settings" 2>/dev/null; then
    echo "✖ $local_settings no es JSON válido; no se modifica"
    exit 1
fi

if [ "$(jq --argjson sl "$STATUSLINE" '.statusLine == $sl' "$local_settings")" = "true" ]; then
    echo "✔ Ya estaba enlazado"
else
    new=$(jq --argjson sl "$STATUSLINE" '.statusLine = $sl' "$local_settings")
    write_local "$new"
    echo "✔ statusLine escrito en $local_settings"
fi

# settings.local.json no debe subirse al repo del equipo. Si git no lo ignora,
# se agrega a .git/info/exclude (local, no toca el .gitignore compartido).
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$root" check-ignore -q .claude/settings.local.json; then
        echo "✔ git ignora .claude/settings.local.json"
    else
        exclude=$(git -C "$root" rev-parse --git-path info/exclude)
        case "$exclude" in /*) ;; *) exclude="$root/$exclude" ;; esac
        mkdir -p "$(dirname "$exclude")"
        echo ".claude/settings.local.json" >> "$exclude"
        echo "✔ .claude/settings.local.json agregado a .git/info/exclude"
    fi
    if git -C "$root" ls-files --error-unmatch .claude/settings.local.json >/dev/null 2>&1; then
        echo "⚠ .claude/settings.local.json ya está commiteado en el repo: el cambio se vería en git status"
    fi
fi

echo "ℹ Se aplica en el próximo refresh del status line (o reiniciá Claude Code)"
