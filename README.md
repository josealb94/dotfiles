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
| **Git** | Aliases, config portabilizada, gitignore global, lazygit | ✅ |
| **fzf** | Búsqueda fuzzy + fd, bat, ripgrep | ✅ |

### Ejecutar un módulo específico

```bash
./install.sh ghostty    # Solo Ghostty
./install.sh zsh        # Solo Zsh
./install.sh git        # Solo Git
./install.sh fzf        # Solo fzf
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
│       ├── zsh.sh                # Módulo Zsh
│       ├── git.sh                # Módulo Git
│       └── fzf.sh                # Módulo fzf
├── ghostty/                      # Paquete Stow → ~/.config/ghostty/
│   └── .config/ghostty/config
├── zsh/                          # Paquete Stow → ~/.zshrc, ~/.zshenv, etc.
│   ├── .zshrc
│   ├── .zshenv
│   └── .zsh_aliases
├── git/                          # Paquete Stow → ~/.gitconfig, etc.
│   ├── .gitconfig
│   └── .gitignore_global
└── fzf/                          # Paquete Stow → ~/.fzf_config
    └── .fzf_config
```

Cada carpeta de primer nivel (excepto `scripts/`) es un **paquete [GNU Stow](https://www.gnu.org/software/stow/)**. Su estructura interna replica `~/`, y stow crea symlinks automáticamente.

## Cómo funciona

```
~/dotfiles/zsh/.zshrc  ──stow──>  ~/.zshrc (symlink)
~/dotfiles/ghostty/.config/ghostty/config  ──stow──>  ~/.config/ghostty/config (symlink)
```

Editás el archivo en el repo, el symlink lo refleja al instante. Solo necesitás commitear y pushear.

---

## Referencia rápida

### Ghostty — Keybindings

| Acción | Atajo |
|---|---|
| Split vertical | `Cmd+D` |
| Split horizontal | `Cmd+Shift+D` |
| Zoom split | `Cmd+Shift+Enter` |
| Navegar splits | `Cmd+Alt+←↑↓→` |
| Redimensionar splits | `Cmd+Ctrl+←↑↓→` |
| Nueva tab | `Cmd+T` |
| Cerrar tab/split | `Cmd+W` |
| Recargar config | `Cmd+Shift+,` |
| Abrir config | `Cmd+,` |

### fzf — Keybindings de terminal

| Atajo | Acción |
|---|---|
| `Ctrl+T` | Buscar archivo e insertar path en la línea actual |
| `Ctrl+R` | Buscar en el historial de comandos |
| `Alt+C` | Buscar directorio y hacer `cd` (requiere `macos-option-as-alt`) |
| `Ctrl+/` | Toggle del panel de preview (dentro de fzf) |
| `Ctrl+U/D` | Scroll en el panel de preview |

### fzf — Funciones custom

| Comando | Descripción |
|---|---|
| `fe` | Buscar archivo y abrirlo en el editor |
| `fcd` | Buscar directorio y hacer `cd` |
| `frg <texto>` | Buscar contenido en archivos con ripgrep → abrir en editor en la línea exacta |
| `fbr` | Seleccionar branch de git interactivamente y hacer checkout |
| `fproject [dir]` | Seleccionar proyecto y hacer `cd` (default: `~/projects`) |

### fzf — Tab completion mejorada

fzf mejora el autocompletado nativo de zsh. Escribí un comando y presioná `Tab`:

```bash
cd **<Tab>        # Busca directorios con fzf + preview de tree
vim **<Tab>       # Busca archivos con fzf + preview de bat
ssh **<Tab>       # Busca hosts con fzf + preview de dig
export **<Tab>    # Busca variables de entorno con fzf + preview de valor
kill **<Tab>      # Busca procesos con fzf
```

### lazygit

TUI interactiva para Git. Se instala/actualiza desde el módulo git.

```bash
lazygit    # Abrir en el repo actual
```

| Atajo (dentro de lazygit) | Acción |
|---|---|
| `Space` | Stage/unstage archivo |
| `c` | Commit |
| `p` | Push |
| `P` | Pull |
| `b` | Branches |
| `s` | Stash |
| `[` / `]` | Navegar entre paneles |
| `?` | Ver todos los keybindings |
| `q` | Salir |

### Git — Aliases

| Alias | Comando completo | Descripción |
|---|---|---|
| `git lg` | `log --all --graph --decorate --oneline` | Log compacto con grafo |
| `git lga` | `log --graph --abbrev-commit --decorate --format=...` | Log detallado con colores |
| `git last` | `log -1 --stat` | Último commit con archivos cambiados |
| `git s` | `status -s -b` | Status corto con branch |
| `git br` | `branch --sort=-committerdate --format=...` | Branches ordenadas por fecha |
| `git cleanup` | `branch --merged main \| ... \| xargs git branch -d` | Eliminar branches mergeadas |
| `git d` | `diff` | Diff |
| `git ds` | `diff --staged` | Diff de staged |
| `git dw` | `diff --word-diff` | Diff palabra por palabra |
| `git co` | `checkout` | Checkout |
| `git cm` | `commit -m` | Commit con mensaje |
| `git ca` | `commit --amend --no-edit` | Amend sin cambiar mensaje |
| `git unstage` | `restore --staged` | Quitar del staging |
| `git undo` | `reset --soft HEAD~1` | Deshacer último commit (mantiene cambios) |

### Git — Defaults configurados

| Setting | Valor | Descripción |
|---|---|---|
| `pull.rebase` | `true` | Pull con rebase en vez de merge |
| `push.autoSetupRemote` | `true` | Push auto-configura tracking del branch remoto |
| `fetch.prune` | `true` | Fetch limpia branches remotas eliminadas |
| `merge.conflictstyle` | `diff3` | Muestra base común en conflictos de merge |
| `rerere.enabled` | `true` | Recuerda resoluciones de conflictos anteriores |
| `url.ssh://git@github.com/` | `insteadOf https://github.com/` | Fuerza SSH para GitHub |

### tmux — Claude Code worktrees en background

tmux permite ejecutar tareas de Claude Code en background con worktrees aislados:

```bash
# Lanzar tarea en background
claude --worktree mi-tarea --tmux "implementa autenticación con JWT"

# Ver/interactuar con la tarea
tmux attach -t mi-tarea     # o: ta mi-tarea

# Volver a tu terminal (Claude sigue trabajando)
Ctrl+B, luego D

# Ver sesiones activas
tmux ls                     # o: tls

# Cerrar sesión terminada
tmux kill-session -t nombre # o: tk nombre
```

### Zsh — Aliases generales

| Alias | Descripción |
|---|---|
| `gitlog` | `git log --all --graph --decorate --oneline` |
| `git-stats` | Muestra contribuidores por número de commits |
| `lg` | Abre lazygit |
| `dotfiles` | `cd ~/dotfiles && ls -la` |
| `reload` | `source ~/.zshrc` |
| `ll` | Lista detallada con iconos y git status (eza) |
| `lt` | Vista de árbol 2 niveles (eza) |
| `..` / `...` / `....` | Subir 1, 2, 3 niveles |
| `tls` | `tmux ls` — listar sesiones |
| `ta <nombre>` | `tmux attach -t` — conectar a sesión |
| `tk <nombre>` | `tmux kill-session -t` — cerrar sesión |
| `ports` | Mostrar puertos en uso |
| `psg <nombre>` | Buscar proceso por nombre |

---

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

- [GNU Stow](https://www.gnu.org/software/stow/) — el instalador lo instala automáticamente
- [Git](https://git-scm.com/)
- Un package manager: Homebrew (macOS), apt, pacman, o dnf (Linux)
