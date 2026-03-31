# Dotfiles

Configuración portable de herramientas de desarrollo. Cross-platform (macOS + Linux), modular, con instalador interactivo.

## Quick start

```bash
# Clonar
git clone git@github.com:josealb94/dotfiles.git ~/dotfiles

# Ejecutar
cd ~/dotfiles && chmod +x install.sh && ./install.sh
```

El instalador detecta tu OS, muestra un menú interactivo y te guía paso a paso.

## Módulos disponibles

| Módulo | Descripción | Estado |
|---|---|---|
| **Ghostty** | Terminal GPU — install, config, Nerd Font | ✅ |
| **Zsh** | Oh My Zsh + Spaceship + plugins + asdf | ✅ |
| **Git** | Aliases, config portabilizada | 🔲 |
| **fzf** | Búsqueda en terminal | 🔲 |

### Ejecutar un módulo específico

```bash
./install.sh ghostty    # Solo Ghostty
./install.sh zsh        # Solo Zsh
```

## Estructura

```
dotfiles/
├── install.sh                    # Punto de entrada interactivo
├── dotfiles.conf.example         # Config local (path al repo privado)
├── scripts/
│   ├── utils.sh                  # OS detection, colores, stow, fonts
│   └── modules/
│       ├── ghostty.sh            # Módulo Ghostty
│       └── zsh.sh                # Módulo Zsh
├── ghostty/                      # Paquete Stow → ~/.config/ghostty/
│   └── .config/ghostty/config
└── zsh/                          # Paquete Stow → ~/.zshrc, ~/.zshenv, etc.
    ├── .zshrc
    ├── .zshenv
    └── .zsh_aliases
```

Cada carpeta de primer nivel (excepto `scripts/`) es un **paquete [GNU Stow](https://www.gnu.org/software/stow/)**. Su estructura interna replica `~/`, y stow crea symlinks automáticamente.

## Cómo funciona

```
~/dotfiles/zsh/.zshrc  ──stow──>  ~/.zshrc (symlink)
~/dotfiles/ghostty/.config/ghostty/config  ──stow──>  ~/.config/ghostty/config (symlink)
```

Editás el archivo en el repo, el symlink lo refleja al instante. Solo necesitás commitear y pushear.

## Plataformas soportadas

| OS | Package manager | Testeado |
|---|---|---|
| macOS (ARM) | Homebrew | ✅ |
| macOS (Intel) | Homebrew | — |
| Ubuntu / Debian | apt | — |
| Kali / Parrot | apt | — |
| Arch / Manjaro | pacman | — |
| Fedora | dnf | — |

## Configuración privada

Para secrets, API keys y SSH hosts, usá un repo privado separado:

```bash
# 1. Crear config local
cp dotfiles.conf.example dotfiles.conf

# 2. Editar la ruta al repo privado
# DOTFILES_PRIVATE_DIR="$HOME/dotfiles-private"
```

El `.zshrc` sourcea automáticamente cualquier archivo `.zsh_*` dentro de `$DOTFILES_PRIVATE_DIR`:

```bash
# ~/dotfiles-private/.zsh_secrets
export GITHUB_TOKEN="ghp_..."
export OPENAI_API_KEY="sk-..."

# ~/dotfiles-private/.zsh_hosts
alias server-prod='ssh user@10.0.0.1'
```

## Agregar un módulo nuevo

1. Crear el paquete stow:

```bash
mkdir -p ~/dotfiles/mi-herramienta/.config/mi-herramienta
# Poner config files replicando la estructura de ~/
```

2. Crear el script del módulo en `scripts/modules/mi-herramienta.sh` con la función `mi_herramienta_main`.

3. Registrarlo en `install.sh`:

```bash
MODULE_LIST=(
    ...
    "mi-herramienta|Mi Herramienta|ready"
)
```

## Dependencias

- [GNU Stow](https://www.gnu.org/software/stow/) — el instalador lo instala automáticamente si no lo tenés
- [Git](https://git-scm.com/)
- Un package manager: Homebrew (macOS), apt, pacman, o dnf (Linux)
