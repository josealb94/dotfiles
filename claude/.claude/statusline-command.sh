#!/usr/bin/env bash
# ~/.claude/statusline-command.sh
# Status line para Claude Code — Catppuccin Mocha, dos grupos.
#
#   Grupo 1 (¿qué sesión es?):  sesión │ carpeta │ git + worktree │ agente │ PR
#   Grupo 2 (¿cómo va?):        modelo · esfuerzo │ contexto │ caché │ 5h │ 7d │ líneas │ duración │ costo
#
# Cada grupo ocupa una línea si entra en el ancho de la terminal; si no, se
# parte en varias (splits, pantallas chicas).
#
# Cada segmento solo aparece si el dato viene en el JSON (los campos opcionales
# dependen de la versión de Claude Code, la cuenta y el tipo de sesión).
# Compatible con bash 3.2 (el /bin/bash de macOS).

# Uso: statusline-command.sh [--extra '<comando>' | --extra-from-project]
#   --extra '<comando>'    agrega debajo la salida de otro status line
#   --extra-from-project   igual, con el statusLine que define el proyecto en
#                          .claude/settings.json (ej. AI-DLC). Ver
#                          statusline-link-project.sh
extra_cmd=""
extra_from_project=""
case "$1" in
    --extra)              extra_cmd="$2" ;;
    --extra-from-project) extra_from_project=1 ;;
esac

input=$(cat)
now=$(date +%s)

# ---------------------------------------------------------------------------
# Lectura del JSON — una sola llamada a jq, campos separados por \x1f
# (separador no blanco: los campos vacíos no se colapsan al hacer read)
# ---------------------------------------------------------------------------
IFS=$'\x1f' read -r \
    cwd session_id session_name model effort fast_mode agent \
    used_pct ctx_tokens ctx_size \
    git_worktree wt_name wt_orig_branch \
    pr_number pr_url pr_state \
    rl_5h rl_5h_reset rl_7d rl_7d_reset \
    cache_seen cache_warm cache_expires \
    lines_added lines_removed duration_ms total_cost project_dir \
    <<< "$(printf '%s' "$input" | jq -r '[
        (.workspace.current_dir // .cwd),
        .session_id,
        .session_name,
        .model.display_name,
        .effort.level,
        (.fast_mode == true),
        .agent.name,
        .context_window.used_percentage,
        .context_window.total_input_tokens,
        .context_window.context_window_size,
        .workspace.git_worktree,
        .worktree.name,
        .worktree.original_branch,
        .pr.number,
        .pr.url,
        .pr.review_state,
        .rate_limits.five_hour.used_percentage,
        .rate_limits.five_hour.resets_at,
        .rate_limits.seven_day.used_percentage,
        .rate_limits.seven_day.resets_at,
        (.prompt_cache.caching_observed == true),
        (.prompt_cache.warm == true),
        .prompt_cache.expires_at,
        .cost.total_lines_added,
        .cost.total_lines_removed,
        .cost.total_duration_ms,
        .cost.total_cost_usd,
        .workspace.project_dir
    ] | map(if . == null then "" else tostring end | gsub("[\n\u001f]"; " ")) | join("\u001f")' 2>/dev/null)"

# Enteros para aritmética y comparaciones con [ -gt ] (descarta decimales)
for v in ctx_tokens ctx_size rl_5h_reset rl_7d_reset cache_expires \
         lines_added lines_removed duration_ms; do
    eval "$v=\${$v%%.*}"
done

# ---------------------------------------------------------------------------
# Catppuccin Mocha — colores ANSI 256
# ---------------------------------------------------------------------------
# Blue      (#89b4fa) → 111   Mauve  (#cba6f7) → 183
# Green     (#a6e3a1) →  114  Yellow (#f9e2af) → 222
# Red       (#f38ba8) → 210   Peach  (#fab387) → 215
# Subtext1  (#bac2de) → 188   Overlay0 (#6c7086) → 242
# Teal      (#94e2d5) → 116   Lavender (#b4befe) → 147
#
# Escapes reales (no "\033" literal): la línea se imprime con %s, así un
# backslash en el nombre de una rama o sesión no se interpreta.
ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
BLUE="${ESC}[38;5;111m"
MAUVE="${ESC}[38;5;183m"
GREEN="${ESC}[38;5;114m"
YELLOW="${ESC}[38;5;222m"
RED="${ESC}[38;5;210m"
PEACH="${ESC}[38;5;215m"
TEAL="${ESC}[38;5;116m"
LAVENDER="${ESC}[38;5;147m"
SUBTEXT="${ESC}[38;5;188m"
DIM="${ESC}[38;5;242m"
SEP="${DIM} │ ${RESET}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Color según umbral de porcentaje: <50 verde, <80 amarillo, resto rojo
pct_color() {
    if   [ "$1" -ge 80 ]; then printf '%s' "$RED"
    elif [ "$1" -ge 50 ]; then printf '%s' "$YELLOW"
    else                       printf '%s' "$GREEN"
    fi
}

# Segundos → "45m", "1h20m", "3d4h"
fmt_dur() {
    local s="$1"
    if   [ "$s" -lt 60 ];    then printf '<1m'
    elif [ "$s" -lt 3600 ];  then printf '%dm' $(( s / 60 ))
    elif [ "$s" -lt 86400 ]; then printf '%dh%02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
    else                          printf '%dd%dh' $(( s / 86400 )) $(( s % 86400 / 3600 ))
    fi
}

# Tokens → "850", "80k", "1M", "1.2M"
fmt_tokens() {
    local n="$1"
    if [ "$n" -ge 1000000 ]; then
        local whole=$(( n / 1000000 )) frac=$(( n % 1000000 / 100000 ))
        if [ "$frac" -eq 0 ]; then printf '%dM' "$whole"; else printf '%d.%dM' "$whole" "$frac"; fi
    elif [ "$n" -ge 1000 ]; then
        printf '%dk' $(( n / 1000 ))
    else
        printf '%d' "$n"
    fi
}

# mtime en epoch. GNU primero: en Linux `stat -f` es "file system status" y
# no falla con %m, así que probar BSD primero devolvería basura.
file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# 1. Directorio — solo la carpeta actual (basename del cwd); ~ si es $HOME
# ---------------------------------------------------------------------------
if [ -n "$cwd" ]; then
    if [ "$cwd" = "$HOME" ]; then
        short_dir="~"
    else
        short_dir=$(basename "$cwd")
    fi
else
    short_dir="?"
fi

# ---------------------------------------------------------------------------
# 2. Git branch + rich status (mirrors starship git_status indicators)
#    Symbols: !N modified  +N staged  ?N untracked  ✘N deleted
#             »N renamed   =N conflicted  ⇡N ahead  ⇣N behind
#    Un archivo puede contar en más de un indicador (ej. MM → +1 !1).
#    El resultado se cachea 5 s por sesión: con refreshInterval y varias
#    sesiones abiertas, evita correr git status en cada ejecución.
# ---------------------------------------------------------------------------
git_status_info() {
    GIT_OPTIONAL_LOCKS=0 git -C "$1" status --porcelain=v2 --branch 2>/dev/null | awk '
        /^# branch.head / { head = $3 }
        /^# branch.ab /   { ahead = substr($3, 2) + 0; behind = substr($4, 2) + 0 }
        /^[12] / {
            x = substr($2, 1, 1); y = substr($2, 2, 1)
            if (x == "R")                    renamed++
            else if (x ~ /[MATC]/)           staged++
            if (x == "D" || y == "D")        deleted++
            if (y ~ /[MT]/)                  modified++
        }
        /^u / { conflicted++ }
        /^\? / { untracked++ }
        END {
            if (head == "" || head == "(detached)") exit
            s = ""
            if (modified)   s = s "!" modified
            if (staged)     s = s "+" staged
            if (untracked)  s = s "?" untracked
            if (deleted)    s = s "✘" deleted
            if (renamed)    s = s "»" renamed
            if (conflicted) s = s "=" conflicted
            if (ahead)      s = s "⇡" ahead
            if (behind)     s = s "⇣" behind
            print head
            print s
        }'
}

branch=""
git_status_str=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    cache_file="${TMPDIR:-/tmp}"
    cache_file="${cache_file%/}/claude-statusline-${session_id:-nosession}.git"
    cached_cwd=""
    cache_mtime=$(file_mtime "$cache_file")
    if [ -n "$cache_mtime" ] && [ $(( now - cache_mtime )) -lt 5 ]; then
        { read -r cached_cwd; read -r branch; read -r git_status_str; } < "$cache_file"
    fi
    if [ "$cached_cwd" != "$cwd" ]; then
        { read -r branch; read -r git_status_str; } < <(git_status_info "$cwd")
        printf '%s\n%s\n%s\n' "$cwd" "$branch" "$git_status_str" > "$cache_file" 2>/dev/null
    fi
fi

git_segment=""
if [ -n "$branch" ]; then
    git_segment="󰘬 ${branch}"
    [ -n "$git_status_str" ] && git_segment="${git_segment} ${git_status_str}"
    # Sesión de worktree de Claude Code (EnterWorktree / --worktree): nombre + rama de origen.
    # Si no, cualquier worktree enlazado de git (git worktree add).
    if [ -n "$wt_name" ]; then
        git_segment="${git_segment} ⎇ ${wt_name}"
        [ -n "$wt_orig_branch" ] && git_segment="${git_segment} ← ${wt_orig_branch}"
    elif [ -n "$git_worktree" ]; then
        git_segment="${git_segment} [${git_worktree}]"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Agente (--agent) y PR de la rama actual (clicable con OSC 8)
# ---------------------------------------------------------------------------
agent_segment=""
[ -n "$agent" ] && agent_segment=" ${agent}"

pr_segment=""
if [ -n "$pr_number" ]; then
    case "$pr_state" in
        approved)          pr_mark=" ${GREEN}✓" ;;
        changes_requested) pr_mark=" ${RED}✗" ;;
        pending)           pr_mark=" ${YELLOW}•" ;;
        draft)             pr_mark=" ${DIM}draft" ;;
        *)                 pr_mark="" ;;
    esac
    pr_text="#${pr_number}"
    if [ -n "$pr_url" ]; then
        pr_text="${ESC}]8;;${pr_url}${ESC}\\${pr_text}${ESC}]8;;${ESC}\\"
    fi
    pr_segment=" ${pr_text}${pr_mark}"
fi

# ---------------------------------------------------------------------------
# 4. Modelo + esfuerzo + fast mode
# ---------------------------------------------------------------------------
model_segment=""
if [ -n "$model" ]; then
    model_segment="󰚩 ${model}"
    [ -n "$effort" ] && model_segment="${model_segment}${DIM} · ${RESET}${SUBTEXT}${effort}"
    [ "$fast_mode" = "true" ] && model_segment="${model_segment} ${PEACH}fast"
fi

# ---------------------------------------------------------------------------
# 5. Barra de contexto + porcentaje + tokens absolutos
# ---------------------------------------------------------------------------
ctx_segment=""
if [ -n "$used_pct" ]; then
    used_int=$(printf "%.0f" "$used_pct")
    bar_color=$(pct_color "$used_int")

    # Barra de 8 bloques
    filled=$(( used_int * 8 / 100 ))
    [ "$filled" -gt 8 ] && filled=8
    bar=""
    i=0
    while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
    while [ $i -lt 8 ];       do bar="${bar}░"; i=$(( i + 1 )); done

    ctx_segment="${bar_color}󰍛 ${bar} ${used_int}%"
    if [ -n "$ctx_tokens" ] && [ -n "$ctx_size" ]; then
        ctx_segment="${ctx_segment}${DIM} $(fmt_tokens "$ctx_tokens")/$(fmt_tokens "$ctx_size")"
    fi
fi

# ---------------------------------------------------------------------------
# 6. Rate limits de suscripción Claude Pro/Max + tiempo hasta el reinicio
#    Los campos .rate_limits.* solo aparecen en cuentas de Claude.ai (OAuth)
#    y solo después de la primera respuesta de la sesión.
# ---------------------------------------------------------------------------
_rl_segment() {
    local pct="$1" reset="$2" icon="$3"
    [ -z "$pct" ] && return
    local pct_int
    pct_int=$(printf "%.0f" "$pct")
    printf '%s%s %d%%' "$(pct_color "$pct_int")" "$icon" "$pct_int"
    if [ -n "$reset" ] && [ "$reset" -gt "$now" ]; then
        printf '%s ↻%s' "$DIM" "$(fmt_dur $(( reset - now )))"
    fi
}

rl_5h_segment=$(_rl_segment "$rl_5h" "$rl_5h_reset" "󰔟 5h")
rl_7d_segment=$(_rl_segment "$rl_7d" "$rl_7d_reset" "󰸗 7d")

# ---------------------------------------------------------------------------
# 7. Prompt cache — caliente (con minutos restantes) o fría.
#    Fría = el próximo mensaje re-procesa todo el contexto.
# ---------------------------------------------------------------------------
cache_segment=""
if [ "$cache_seen" = "true" ]; then
    if [ "$cache_warm" = "true" ] && [ -n "$cache_expires" ] && [ "$cache_expires" -gt "$now" ]; then
        cache_segment="${TEAL} caché $(fmt_dur $(( cache_expires - now )))"
    else
        cache_segment="${DIM} caché fría"
    fi
fi

# ---------------------------------------------------------------------------
# 8. Líneas cambiadas, duración y costo estimado
#    El costo es a precio de lista: con Pro/Max no es lo que pagás, va atenuado.
# ---------------------------------------------------------------------------
lines_segment=""
if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ]; then
    lines_segment="${GREEN}+${lines_added:-0} ${RED}−${lines_removed:-0}"
fi

duration_segment=""
if [ "${duration_ms:-0}" -gt 0 ]; then
    duration_segment=" $(fmt_dur $(( duration_ms / 1000 )))"
fi

cost_segment=""
if [ -n "$total_cost" ]; then
    cost_fmt=$(printf "%.2f" "$total_cost" 2>/dev/null)
    [ -n "$cost_fmt" ] && [ "$cost_fmt" != "0.00" ] && cost_segment="\$${cost_fmt}"
fi

# ---------------------------------------------------------------------------
# Ensamblar — solo los segmentos con contenido, separados por │
# ---------------------------------------------------------------------------
# Cada grupo junta sus segmentos y después se empaqueta según el ancho de la
# terminal ($COLUMNS, que Claude Code exporta): en ventanas anchas cada grupo
# ocupa una línea; en splits o pantallas chicas se parte en las que hagan falta.
segs=()

add_seg() {
    [ -n "$2" ] && segs+=("${1}${2}${RESET}")
}

# Ancho visible: sin escapes ANSI ni OSC 8, contando caracteres UTF-8
# (bytes menos bytes de continuación; no depende del locale)
visible_width() {
    printf '%s' "$1" \
        | sed $'s/\x1b\\[[0-9;]*m//g; s/\x1b\\]8;;[^\x1b]*\x1b\\\\//g' \
        | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

# Margen para el padding que agrega Claude Code alrededor del status line
max_w=""
[ -n "$COLUMNS" ] && [ "$COLUMNS" -gt 20 ] 2>/dev/null && max_w=$(( COLUMNS - 4 ))

out=()

# Empaqueta "segs" en líneas de ancho <= max_w (greedy, en orden) y vacía segs
flush_group() {
    [ ${#segs[@]} -eq 0 ] && return
    local cur="" cur_w=0 seg w

    # Atajo: si el grupo entero entra (o no hay ancho), una sola línea y una sola medición
    for seg in "${segs[@]}"; do cur="${cur:+${cur}${SEP}}${seg}"; done
    if [ -z "$max_w" ] || [ "$(visible_width "$cur")" -le "$max_w" ]; then
        out+=("$cur")
        segs=()
        return
    fi

    cur=""
    for seg in "${segs[@]}"; do
        if [ -z "$cur" ]; then
            cur="$seg"
            [ -n "$max_w" ] && cur_w=$(visible_width "$seg")
            continue
        fi
        if [ -n "$max_w" ]; then
            w=$(visible_width "$seg")
            if [ $(( cur_w + 3 + w )) -gt "$max_w" ]; then
                out+=("$cur")
                cur="$seg"
                cur_w=$w
                continue
            fi
            cur_w=$(( cur_w + 3 + w ))
        fi
        cur="${cur}${SEP}${seg}"
    done
    out+=("$cur")
    segs=()
}

# Grupo 1 — identidad de la sesión
[ -n "$session_name" ] && add_seg "${BOLD}${LAVENDER}" " ${session_name}"
add_seg "${BOLD}${BLUE}"  "󰉋 $short_dir"
add_seg "$MAUVE"          "$git_segment"
add_seg "$PEACH"          "$agent_segment"
add_seg "$MAUVE"          "$pr_segment"
flush_group

# Grupo 2 — estado y consumo. Orden = prioridad al partir: lo que se mira
# seguido (modelo, contexto, caché) queda arriba; límites y totales, abajo.
add_seg "$SUBTEXT"        "$model_segment"
add_seg ""                "$ctx_segment"      # color embebido
add_seg ""                "$cache_segment"    # color embebido
add_seg ""                "$rl_5h_segment"    # color embebido
add_seg ""                "$rl_7d_segment"    # color embebido
add_seg ""                "$lines_segment"    # color embebido
add_seg "$SUBTEXT"        "$duration_segment"
add_seg "$DIM"            "$cost_segment"
flush_group

for l in "${out[@]}"; do
    printf '%s\n' "$l"
done

# Status line extra (--extra '<comando>'): recibe el mismo JSON y su salida se
# agrega tal cual debajo. Sirve para encadenar el de una herramienta del
# proyecto (ej. AI-DLC) en vez de que uno reemplace al otro.
# Con --extra-from-project se lee del settings.json del proyecto (el que
# settings.local.json está tapando); se ignora si apunta a este mismo script.
if [ -n "$extra_from_project" ]; then
    project_settings="${project_dir:-$cwd}/.claude/settings.json"
    if [ -f "$project_settings" ]; then
        extra_cmd=$(jq -r '.statusLine.command // empty' "$project_settings" 2>/dev/null)
        case "$extra_cmd" in *statusline-command.sh*) extra_cmd="" ;; esac
    fi
fi
if [ -n "$extra_cmd" ]; then
    printf '%s' "$input" | sh -c "$extra_cmd" 2>/dev/null
fi
