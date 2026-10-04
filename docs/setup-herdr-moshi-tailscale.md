# Setup — Herdr + Moshi + Tailscale

Agentes de coding persistentes en el Mac Mini, con estado visible, alcanzables desde el
portátil y el iPhone por red privada, y con notificaciones push cuando un agente espera.

```
iPhone (Moshi) ─┐
                ├─ Tailscale ─→ Mac Mini ─→ Herdr ─→ agentes en panes
MacBook (SSH) ──┘                            ↑
                                        moshi-hook
                                  (aprobaciones, diffs, push)
```

Datos verificados en documentación oficial al **2026-10-03**.

---

## Prerrequisitos

- Mac Mini encendido y accesible (es el host)
- Agentes ya instalados y autenticados en el host (Claude Code, Codex, OpenCode…)
- Cuenta de Tailscale (plan Personal: gratis, 6 usuarios, dispositivos ilimitados)

> Hacerlo en el **Mac Mini**, no en la máquina de trabajo.

---

## Paso 1 — Tailscale

Prerrequisito de todo. Sin esto no hay acceso remoto.

1. Instalar Tailscale en **Mac Mini**, **portátil** e **iPhone**, con la misma cuenta.
2. Activar **MagicDNS** en la consola de administración.

### Endurecerlo antes de seguir (10 min)

| Ajuste | Por qué |
|---|---|
| **Definir ACLs** | El default es **red plana**: todos los dispositivos se alcanzan entre sí |
| **Device approval** | Aprobar cada dispositivo nuevo antes de que entre |
| **Key expiry** | Activado (default: 180 días) |
| **2FA** en el proveedor de identidad | La cuenta es el nuevo perímetro |
| **Funnel: NO habilitar** | Única función que publica un servicio **en internet** |

### Verificación

```bash
ping mac-mini                    # nombre de MagicDNS
ssh tu-usuario@mac-mini
```

No continuar hasta que el SSH entre.

---

## Paso 2 — SSH endurecido en el host

En `/etc/ssh/sshd_config` del Mac Mini:

```
PasswordAuthentication no
PermitRootLogin no
```

```bash
ssh-copy-id tu-usuario@mac-mini
sudo launchctl kickstart -k system/com.openssh.sshd    # recargar sshd en macOS
```

> **No activar Tailscale SSH.** Secuestra el puerto 22 con autenticación gestionada por
> Tailscale y rompe la autenticación por clave que Moshi necesita. Lo que se quiere es
> *SSH sobre Tailscale*: el `sshd` normal del sistema viajando por el túnel.

---

## Paso 3 — Herdr en el host

```bash
brew install herdr
# alternativas:
#   curl -fsSL https://herdr.dev/install.sh | sh
#   mise use -g herdr
```

Arrancar y adjuntarse (no es una app que se mantiene abierta: es un servidor en background):

```bash
herdr          # arranca y adjunta; ejecutarlo otra vez reattacha
```

Correr un agente dentro de un pane — Herdr lo detecta automáticamente:

```bash
claude         # o codex, opencode, pi…
```

El sidebar muestra el estado: `working`, `blocked`, `done`, `idle`.

### Atajos (prefijo `ctrl+b`)

| Acción | Atajo |
|---|---|
| Split a la derecha | `prefix+v` |
| Split abajo | `prefix+minus` |
| Nueva tab | `prefix+c` |
| Tab siguiente / anterior | `prefix+n` / `prefix+p` |
| Navegar workspaces | `prefix+w` |
| Nuevo workspace | `prefix+shift+n` |
| Desadjuntar | `prefix+q` |
| Ver todos los atajos | `prefix+?` |

También es mouse-native: clic en panes, tabs, workspaces y agentes.

### Conflictos de teclas

- **Con kitty: ninguno.** Los atajos de kitty viven en `Cmd+*` (más algunos defaults en
  `Ctrl+Shift+*`); los de Herdr son todos `ctrl+b` + tecla. La intersección es vacía, y en
  macOS kitty captura `Cmd+*` antes de que llegue a la aplicación.
- **Con tmux: sí.** Mismo prefijo por defecto. **No anidar Herdr dentro de tmux.**
- **Con vim:** `Ctrl+B` es página-arriba y lo consume el prefijo. No aplica si la revisión
  de código va por VS Code.
- **Con el shell:** se pierde `backward-char` (`Ctrl+B`) dentro de Herdr. Las flechas cubren.
- **Terminal integrada de VS Code:** por defecto las teclas se pasan al terminal, así que
  `ctrl+b` llega a Herdr; lo que se pierde es el toggle del sidebar mientras el foco esté
  en la terminal.

### Agregar la segunda máquina

```bash
herdr machine add portatil
```

Sus workspaces y agentes aparecen junto a los locales en la misma vista.

---

## Paso 4 — Moshi en el iPhone

1. Instalar **Moshi** desde el App Store. El plan gratis trae terminal completo, sesiones
   ilimitadas, push y dictado en el dispositivo.
2. Agregar la conexión usando el **nombre de MagicDNS** del host (o su IP del tailnet),
   con usuario y autenticación por clave.
3. Conectar: debería aparecer la sesión de Herdr tal como se dejó.

### El camino corto: Easy Pair con QR

En vez de configurar la conexión a mano, `moshi-hook` muestra un QR que la app escanea
y deja el acceso SSH listo, con su propia clave:

```bash
# Pinear el nombre de MagicDNS evita la pantalla de selección de dirección
# y hace que funcione desde cualquier red, no solo desde la WiFi local.
moshi-hook host setup --host <hostname>.<tailnet>.ts.net
```

Esto **también sirve para volver a mostrar el QR** cuando se agrega otro dispositivo
(un iPad, por ejemplo): cada corrida crea un emparejamiento nuevo con su propia clave
en `~/.ssh/authorized_keys`, sin tocar los anteriores.

| Comando | Para qué |
|---|---|
| `moshi-hook host setup` | Mostrar el QR y emparejar un dispositivo |
| `moshi-hook host list` | Ver los emparejamientos y su estado |
| `moshi-hook host revoke` | Cortar el acceso de un dispositivo perdido o en desuso |
| `moshi-hook host enable-ssh` | Activar Remote Login en el host |

> ⚠️ **Orden con el endurecimiento del Paso 2.** Si ya se aplicó
> `PasswordAuthentication no`, emparejar un dispositivo nuevo puede fallar según cómo
> haga el bootstrap de su clave. Emparejar primero, endurecer después.

> ⛔ **Un host solo se comparte entre dispositivos con Pro.** En el plan gratis no hay
> cuenta, así que cada instalación de la app es una identidad anónima propia y el host
> queda atado al **primer** dispositivo que lo empareja. Un segundo dispositivo falla con
> *"ya está emparejado con otra cuenta de Moshi"*. No es un error de configuración:
> `shared hosts` figura entre las características de Pro ("up to 3 devices", con
> *shared hosts* y *unified push*). **No** correr `moshi-hook unpair` para "arreglarlo":
> libera el host, pero entonces lo pierde el dispositivo original.
>
> Salida gratis para el segundo dispositivo: un cliente SSH normal sobre Tailscale
> (**Blink Shell** soporta mosh, así que conserva la persistencia de red) apuntando al
> host y corriendo `herdr` ahí. Se pierden bandeja de aprobaciones, Chat View, visor de
> diffs y push; el terminal con los workspaces y los agentes queda completo.

### Verificación

Dejar un agente trabajando, cerrar la terminal del escritorio, abrir Moshi en el teléfono.
Si el agente sigue ahí trabajando, el set funciona.

---

## Paso 5 — `moshi-hook` en el host (opcional, pero es lo que lo vuelve útil)

Token desde la app: **Settings → Integrations** (así lo nombra `moshi-hook pair --help`;
la doc web todavía dice *Hooks* — si no aparece en una, buscar en la otra).

```bash
brew tap rjyo/moshi
brew trust rjyo/moshi
brew install moshi-hook
moshi-hook pair --token <token de la app Moshi>
moshi-hook install
brew services start moshi-hook
```

Linux / WSL:

```bash
curl -fsSL https://getmoshi.app/install.sh | sh
moshi-hook pair --token <token>
moshi-hook install
moshi-hook serve
```

Habilita: eventos a la bandeja (aprobaciones, fin de tarea, ejecución de herramientas),
aprobaciones de ida y vuelta desde el teléfono, Live Activity y Apple Watch, Chat View,
diff viewer, browser preview y detección de multiplexor para tmux/Zellij.

> La doc del hook menciona detección en tiempo real para **tmux y Zellij**; Herdr figura
> como multiplexor soportado en la introducción de Moshi pero no en esa línea. Si la
> integración fina con Herdr no responde como se espera, revisar esto primero.

---

## Integración con este repo de dotfiles

**Ya está implementado.** Ambos módulos aparecen en el menú de `./install.sh`:

| Entrada en el selector | Categoría | Módulo |
|---|---|---|
| `Tailscale (red mesh privada)` | **Red** | `scripts/modules/tailscale.sh` |
| `Herdr (multiplexor de agentes)` | **IA** | `scripts/modules/herdr.sh` |

La categoría **Red** aparece justo antes de **IA** en el selector, para que se vea que
Tailscale es prerrequisito del flujo de agentes.

Uso directo sin pasar por el menú:

```bash
./install.sh tailscale
./install.sh herdr
```

### Qué hace el módulo de Tailscale

- Instala según el OS: en macOS el cask **`tailscale-app`** (GUI, con el CLI dentro del
  bundle); en Linux el instalador oficial `curl -fsSL https://tailscale.com/install.sh | sh`.
- **Detecta el caso de macOS en que la app está pero el CLI no está en el PATH** y ofrece
  crear el symlink a `/usr/local/bin/tailscale`.
- Submenú cuando ya está instalado: `u` actualizar · `e` ver estado del tailnet ·
  `h` checklist de endurecimiento · `s` saltar.
- El checklist recuerda ACLs, device approval, key expiry, 2FA y MagicDNS, y advierte de
  **no habilitar Funnel** ni **Tailscale SSH**.

### Qué hace el módulo de Herdr

- Instala con `brew install herdr` (es formula, no cask) o con su script en Linux.
- Submenú cuando ya está instalado: `u` · `c` configurar · `b` ambos · `s` saltar.
- Aplica el paquete Stow con `apply_stow "herdr"`.
- **Chequea el entorno** después de configurar:
  - agentes detectados en el PATH (`claude`, `codex`, `opencode`, `pi`) — avisa si no hay
    ninguno, porque Herdr sin agentes no sirve de nada;
  - si Tailscale está instalado y conectado;
  - **si estás dentro de `$TMUX`**, porque comparten el prefijo `ctrl+b`.
- Imprime un resumen de comandos y atajos al terminar.

### Paquete Stow

```
herdr/
└── .config/
    └── herdr/
        └── config.toml
```

El `config.toml` deja el prefijo por defecto (`ctrl+b`) y documenta en comentarios los
conflictos conocidos y cómo cambiarlo. Para revertir: `stow -D herdr`.

### Qué va al repo privado

Nada de esto debe quedar en el repo público:

| Dato | Dónde |
|---|---|
| **Token de emparejamiento de `moshi-hook`** | Repo privado o keychain. Es una credencial |
| **Hosts SSH** (nombres de MagicDNS, usuarios) | Repo privado (`dotfiles-private`) |
| Claves SSH | Nunca en un repo |

---

## Cómo deshacerlo

```bash
brew services stop moshi-hook && brew uninstall moshi-hook
brew uninstall herdr
stow -D herdr            # quitar los symlinks del paquete
# Tailscale: desinstalar el cliente y quitar los dispositivos desde la consola
```

---

## Orden de prueba sugerido

Cada paso aporta valor por sí solo, así que se puede parar en cualquiera.

| Hasta el paso | Qué ya hay | Si acá no se usa… |
|---|---|---|
| **1–2** | Acceso privado y seguro a las máquinas | Tailscale sirve igual para otras cosas |
| **4** | Gestión desde el celular, con SSH plano o tmux | **Ahorrarse Herdr**: no hace falta |
| **3** | Persistencia, estado y multi-máquina | — |
| **5** | Aprobaciones y diffs desde el teléfono | Es lo que justificaría Moshi Pro |

**Recomendado:** hacer 1, 2 y 4 primero, sin Herdr. Moshi funciona con tmux o shells
sueltos, así que se valida *"¿de verdad gestiono agentes desde el teléfono?"* antes de
tocar la configuración de terminal.

---

## Referencias

- Herdr: <https://herdr.dev/docs/installation> · <https://herdr.dev/docs/quick-start/>
- Moshi: <https://getmoshi.app/docs/hooks> · <https://getmoshi.app/docs/tailscale> · <https://getmoshi.app/pricing>
- Tailscale: <https://tailscale.com/kb/1018/acls> · <https://tailscale.com/kb/1223/funnel>
