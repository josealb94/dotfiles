# =============================================================================
# .zshenv — Variables de entorno cargadas antes de .zshrc
# Se ejecuta en TODA sesión zsh (interactiva y no interactiva)
# Solo poner aquí lo estrictamente necesario
# =============================================================================

# Cargo/Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
