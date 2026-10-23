# Setup — Status line de Claude Code

Cómo dejar el status line funcionando en una PC que no lo tiene (personal o del trabajo),
y cómo hacer que conviva con el status line de proyectos que traen el suyo, como AI-DLC.

```
~/.claude/settings.json            → statusLine propio (todos los repos)
<repo>/.claude/settings.json       → statusLine del proyecto (ej. AI-DLC) — le gana al de usuario
<repo>/.claude/settings.local.json → statusLine propio + el del proyecto debajo — le gana a los dos
```

Claude Code ejecuta **un solo** `statusLine`: el del archivo de mayor prioridad
(local > proyecto > usuario). No los combina. Por eso, en un repo con AI-DLC hay que
enlazarlos explícitamente (paso 4).

Datos verificados en la [documentación oficial](https://code.claude.com/docs/en/statusline)
al **2026-10-23**.

---

## Prerrequisitos

- Claude Code instalado y con sesión iniciada
- `git` y `jq` (el módulo ofrece instalarlos)
- Una Nerd Font en la terminal (los módulos `ghostty` y `kitty` la instalan); sin ella los
  íconos se ven como cuadrados
- Acceso a este repo de dotfiles

---

## Paso 1 — Clonar los dotfiles

```bash
git clone git@github.com:josealb94/dotfiles.git ~/dotfiles
```

> En la PC del trabajo, si no tenés la llave SSH de tu cuenta personal, cloná por HTTPS:
> `git clone https://github.com/josealb94/dotfiles.git ~/dotfiles`. Para usar el status
> line solo hace falta leer el repo.

---

## Paso 2 — Instalar el módulo

```bash
cd ~/dotfiles && ./install.sh claude_statusline
```

El módulo:

1. Verifica `jq` y `git`, y ofrece instalarlos.
2. Enlaza con Stow `~/.claude/statusline-command.sh` y `~/.claude/statusline-link-project.sh`
   al repo.
3. Escribe **solo** la clave `statusLine` en `~/.claude/settings.json` (con backup
   `settings.json.bak.<fecha>`). El resto del archivo queda igual.

Si la PC ya tenía un `~/.claude/statusline-command.sh` propio, Stow avisa del conflicto.
Para conservar el viejo, movelo antes de responder:

```bash
mv ~/.claude/statusline-command.sh ~/.claude/statusline-command.sh.bak
./install.sh claude_statusline
```

---

## Paso 3 — Verificar

Abrí Claude Code en cualquier repo **sin** status line propio y mandá un mensaje. Deberías
ver dos líneas (o más, si la ventana es angosta):

```
󰉋 carpeta │ 󰘬 rama !1
󰚩 Opus · high │ 󰍛 ██░░░░░░ 21% 42k/200k │  caché 58m │ 󰔟 5h 12% ↻3h10m
```

Prueba rápida sin abrir Claude Code:

```bash
echo '{"cwd":"'"$PWD"'","model":{"display_name":"Opus"}}' | bash ~/.claude/statusline-command.sh
```

---

## Paso 4 — Repos con AI-DLC (o cualquier status line propio)

En cada repo que define su propio `statusLine`:

```bash
cd ~/ruta/al/repo
bash ~/.claude/statusline-link-project.sh
```

El script:

1. Lee el `statusLine` del proyecto (`.claude/settings.json`). Si no hay, no hace nada.
2. Escribe en `.claude/settings.local.json` un `statusLine` con
   `--extra-from-project`: muestra tus líneas y, debajo, la salida del status line del
   proyecto. Las demás claves del archivo (permisos, etc.) se conservan.
3. Se asegura de que git ignore `settings.local.json`. Si el `.gitignore` del repo no lo
   cubre, lo agrega a `.git/info/exclude`, que es local: **no modifica nada del equipo**.

Resultado:

```
󰉋 ca-backoffice │ 󰘬 release/migration-to-ai-dlc-v2
󰚩 Opus · high │ 󰍛 ███░░░░░ 38% 76k/200k │  caché 41m
<barra de AI-DLC>
```

Como el comando del proyecto se lee en cada ejecución, si AI-DLC cambia su comando en una
versión nueva no hay que volver a enlazar.

### Varios repos de una vez

El script sale sin cambios en los repos que no definen `statusLine`, así que se puede
correr sobre una carpeta entera:

```bash
for d in ~/work/*/; do
    [ -f "$d/.claude/settings.json" ] && bash ~/.claude/statusline-link-project.sh "$d"
done
```

### Cuándo hay que repetirlo

`settings.local.json` no se versiona: hay que correr el script de nuevo **en cada clon
nuevo** de un repo con AI-DLC, y en cada PC.

---

## Actualizar

```bash
cd ~/dotfiles && git pull
```

Los archivos son symlinks: los cambios al script se ven en el próximo refresh. Si una
actualización agrega archivos nuevos al paquete `claude/`, volvé a correr
`./install.sh claude_statusline` para enlazarlos.

---

## Deshacer

```bash
# En un repo: volver a mostrar solo el status line del proyecto
bash ~/.claude/statusline-link-project.sh --remove

# En la PC: quitar los symlinks
stow -D -d ~/dotfiles -t ~ claude
```

Después, quitá la clave `statusLine` de `~/.claude/settings.json` (o restaurá el backup
`settings.json.bak.<fecha>`).

---

## Problemas comunes

| Síntoma | Causa probable |
|---|---|
| No aparece ninguna línea | Falta `jq`, o `statusLine` no quedó en `settings.json`: `jq .statusLine ~/.claude/settings.json` |
| Íconos como cuadrados o `?` | La terminal no usa una Nerd Font |
| En un repo con AI-DLC solo se ve la barra de AI-DLC | Falta enlazar ese repo (paso 4) |
| Se ven mis líneas pero no la de AI-DLC | El comando del proyecto falla en ese shell: probá `aidlc engine statusline` a mano desde el repo y revisá que `aidlc` esté en el `PATH` |
| `settings.local.json` aparece en `git status` | El archivo ya estaba commiteado en el repo; el script lo avisa. Hablalo con el equipo antes de tocarlo |
| El estado de git tarda unos segundos en cambiar | Es la caché de 5 s; además el status line se refresca cada 10 s |
