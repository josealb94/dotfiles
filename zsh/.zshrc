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
ZSH_THEME="spaceship"

plugins=(
    git
    colored-man-pages
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

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
if [ -f "$HOME/.asdf/asdf.sh" ]; then
    . "$HOME/.asdf/asdf.sh"
    # Completions
    if [ -d "${ASDF_DIR}/completions" ]; then
        fpath=(${ASDF_DIR}/completions $fpath)
    fi
    autoload -Uz compinit && compinit
fi

# -- fzf ----------------------------------------------------------------------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.fzf_config ] && source ~/.fzf_config

# -- Antigravity IDE ----------------------------------------------------------
if [ -d "$HOME/.antigravity" ]; then
    export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

# -- VS Code CLI --------------------------------------------------------------
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
    export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# -- Aliases ------------------------------------------------------------------
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# -- Configuración privada (secrets, SSH hosts, etc.) -------------------------
# Ruta configurable via dotfiles.conf → DOTFILES_PRIVATE_DIR
export DOTFILES_PRIVATE_DIR="${DOTFILES_PRIVATE_DIR:-$HOME/dotfiles-private}"
if [ -d "$DOTFILES_PRIVATE_DIR" ]; then
    for f in "$DOTFILES_PRIVATE_DIR"/.zsh_*; do
        [ -f "$f" ] && source "$f"
    done
fi
