# =============================================================================
# .zshrc — Configuración principal de zsh
# Managed by dotfiles: https://github.com/josealb94/dotfiles
# =============================================================================

# -- PATH base ----------------------------------------------------------------
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Homebrew (macOS)
if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# -- Oh My Zsh ----------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
# Tema desactivado — Starship maneja el prompt
ZSH_THEME=""

# fzf-tab debe cargarse ANTES de compinit (que corre dentro de Oh My Zsh)
# zsh-completions agrega completions adicionales al fpath
if [ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src" ]; then
    fpath+=${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src
fi

plugins=(
    git
    colored-man-pages
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
    you-should-use
    fzf-tab
    direnv
)

# -- Corrección de typos en comandos ------------------------------------------
ENABLE_CORRECTION="true"

source "$ZSH/oh-my-zsh.sh"

# -- Historial compartido entre tabs/splits -----------------------------------
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
HISTSIZE=50000
SAVEHIST=50000

# -- Autocompletado mejorado --------------------------------------------------
# Case-insensitive: cd doc<Tab> encuentra Documents
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# Completar desde ambos extremos
zstyle ':completion:*' menu select
# Colores en completado
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# -- fzf-tab config (después de Oh My Zsh) -----------------------------------
# Preview en el autocompletado con tab
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath | head -50'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'tree -C $realpath | head -50'
zstyle ':fzf-tab:complete:cat:*' fzf-preview 'bat -n --color=always $realpath 2>/dev/null || cat $realpath'
zstyle ':fzf-tab:complete:vim:*' fzf-preview 'bat -n --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:nvim:*' fzf-preview 'bat -n --color=always $realpath 2>/dev/null'
# Colores consistentes con Catppuccin
zstyle ':fzf-tab:*' fzf-flags --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8

# -- history-substring-search (después de Oh My Zsh) --------------------------
# Usar ↑↓ para buscar en historial por lo que ya escribiste
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# -- Go -----------------------------------------------------------------------
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$PATH:$GOBIN"

# -- Android SDK (cross-platform) ---------------------------------------------
if [ -d "$HOME/Library/Android/sdk" ]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
elif [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
fi

if [ -n "$ANDROID_HOME" ]; then
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="$PATH:$ANDROID_HOME/emulator"
    export PATH="$PATH:$ANDROID_HOME/platform-tools"
    export PATH="$PATH:$ANDROID_HOME/tools"
    export PATH="$PATH:$ANDROID_HOME/tools/bin"
fi

# -- Flutter ------------------------------------------------------------------
if [ -d "$HOME/development/flutter/bin" ]; then
    export PATH="$PATH:$HOME/development/flutter/bin"
fi

# -- Ruby Gems ----------------------------------------------------------------
export GEM_HOME="$HOME/.gem"
export GEM_PATH="$HOME/.gem"

# -- asdf (version manager: nodejs, golang, ruby, rust, java, ...) -----------
# asdf v0.16+ (rewrite en Go): solo requiere shims en PATH
if [ -d "$HOME/.asdf/shims" ]; then
    export PATH="$HOME/.asdf/shims:$PATH"
fi
# asdf < v0.16: source del script
if [ -f "$HOME/.asdf/asdf.sh" ]; then
    . "$HOME/.asdf/asdf.sh"
    if [ -d "${ASDF_DIR}/completions" ]; then
        fpath=(${ASDF_DIR}/completions $fpath)
    fi
fi
# Completions para zsh
autoload -Uz compinit && compinit

# -- fzf ----------------------------------------------------------------------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.fzf_config ] && source ~/.fzf_config

# -- zoxide (cd inteligente — aprende tus directorios frecuentes) -------------
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# -- eza (ls moderno con iconos y git status) ---------------------------------
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --level=2 --icons --group-directories-first'
fi

# -- bat (cat mejorado con syntax highlighting) -------------------------------
if command -v bat >/dev/null 2>&1; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    alias cat='bat --paging=never'
fi

# -- Antigravity IDE ----------------------------------------------------------
if [ -d "$HOME/.antigravity" ]; then
    export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

# -- VS Code CLI --------------------------------------------------------------
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
    export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# -- Claude Code apuntando a Ollama local ------------------------------------
# Permite usar Claude Code con modelos locales de Ollama (sin enviar a la nube)
# Requiere: Ollama instalado y corriendo en localhost:11434
claude-local() {
    local model="${1:-qwen3:8b}"
    shift 2>/dev/null
    ANTHROPIC_BASE_URL="http://localhost:11434" \
    ANTHROPIC_AUTH_TOKEN="ollama" \
    ANTHROPIC_API_KEY="" \
    claude --model "$model" "$@"
}

# Variantes por tipo de modelo
claude-general() { claude-local "qwen3:8b"           "$@"; }  # General
claude-coder()   { claude-local "qwen2.5-coder:14b"  "$@"; }  # Código
claude-doc()     { claude-local "gemma3:12b"         "$@"; }  # Documentación (Google)
claude-big()     { claude-local "qwen3:30b"          "$@"; }  # Modelo grande

# -- Aliases ------------------------------------------------------------------
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# -- Configuración privada (secrets, SSH hosts, etc.) -------------------------
export DOTFILES_PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/dotfiles-private}"
if [ -d "$DOTFILES_PRIVATE_DIR" ]; then
    for f in "$DOTFILES_PRIVATE_DIR"/.zsh_*; do
        [ -f "$f" ] && source "$f"
    done
fi

# -- Starship prompt (debe ir al final) --------------------------------------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# -- opencode -----------------------------------------------------------------
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
