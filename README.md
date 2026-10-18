<div align="center">

# 🌌 Panacea Shell — Edición Perfeccionada `V:NOVZ`

**El entorno de interfaz unificado, Notch Dinámico e Isla Inteligente para Wayland & Hyprland**

[![Versión](https://img.shields.io/badge/Versi%C3%B3n-V%3ANOVZ%20(1.0.14)-8A2BE2?style=for-the-badge&logo=rocket)](https://github.com/nov4z/Panacea_shell)
[![Wayland](https://img.shields.io/badge/Display-Wayland-00599C?style=for-the-badge&logo=wayland&logoColor=white)](https://wayland.freedesktop.org/)
[![Hyprland](https://img.shields.io/badge/Window%20Manager-Hyprland-00C7B7?style=for-the-badge&logo=archlinux&logoColor=white)](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Engine-Quickshell%20(Qt6%2FQML)-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me/)
[![Python](https://img.shields.io/badge/Audio%20%26%20Daemons-Python%203-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org/)
[![Licencia](https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge)](LICENSE)

<br/>

> [!NOTE]
> ### 📢 Declaración de Modificación y Autoría
> Este repositorio es una **modificación y perfeccionamiento integral** del proyecto base *Panacea Shell*, refactorizado, extendido y mantenido por **NovZ ([@nov4z](https://github.com/nov4z))**.
> 
> Esta edición **`V:NOVZ`** introduce cinemática a 60 FPS sin tirones, estética estricta **Dark Unibody**, visor **SpicyLyrics** con predicción de márgenes sin salto de palabras, corrección de esquinas redondeadas en el Centro de Control `Super + Z`, integración reactiva con **Antigravity AI**, motor acústico desacoplado con reverberación independiente y solución definitiva al bug de volumen de Spotify en PipeWire.

</div>

---

## 📸 Galería Visual

<div align="center">

### 1. Dynamic Notch & Barra de Estado (Modo Dark Unibody)
*Cápsula fluida integrada al centro superior de la pantalla, con onda acústica de frecuencia reactiva y badges dinámicos.*

![Notch Dark Unibody](screenshots/notch_dark_unibody.png)

<br/>

### 2. Cápsula Musical Expandida & SpicyLyrics (`Super + M`)
*Despliegue a 60 FPS con sincronización temporal (~120 ms de anticipación) y predicción de envolvente para que ninguna palabra se quiebre de línea al escalar.*

![SpicyLyrics Sincronizado](screenshots/spicylyrics_sync.png)

<br/>

### 3. Centro de Control Unificado (`Super + Z`)
*Chasis unibody pulido (`#141218`) con esquinas redondeadas continuas, sliders hápticos, carátulas HD y selección rápida de dispositivos.*

![Super + Z Control Center](screenshots/super_z_controls.png)

<br/>

### 4. Estudio de Personalización del Notch
*Ajustes geométricos en tiempo real (anchos, radios, márgenes, padding y estilos visuales) con previsualización fiel 1:1.*

![Notch Settings Studio](screenshots/notch_settings_studio.png)

<br/>

### 5. Estudio Acústico de Sonido (`sound_engine.py`)
*Configuración independiente de Espaciado Estéreo (Spatial Stereo Width) y Cola de Reverb (Room Decay Reverb) con packs de sonido hápticos.*

![Acoustic Sound Studio](screenshots/acoustic_sound_studio.png)

</div>

---

## ✨ Características Destacadas de la Versión `NOVZ`

### 🎵 1. SpicyLyrics con Predicción de Márgenes Acústica
- **Cero salto de palabras ("efecto punto seguido")**: El motor de layout precalcula el ancho de línea considerando la escala expandida de la frase activa. Las frases nunca sufren saltos de renglón abruptos al cambiar de tamaño durante el canto.
- **Anticipación acústica de ~120 ms**: El avance de texto y el destello luminoso se sincronizan con exactitud milimétrica al compás de la voz del cantante.
- **Visualizador armónico**: Desvanecimiento suave del canvas de ondas de fondo mientras las letras están activas para máxima legibilidad.

### 🖤 2. Estricto Lenguaje Visual Dark Unibody
- **Chasis oscuro unibody**: Eliminación total de fondos blancos planos (`#ffffff`). La interfaz se mantiene en un elegante chasis oscuro satinado (`Qt.rgba(0.08, 0.08, 0.09, 0.98)` / `#141218`).
- **Esquinas redondeadas perfectas**: Se erradicó el recuadro cuadrado residual detrás de la tarjeta multimedia en `ControlsView.qml`.
- **Modo Blanco y Negro Radiante**: Si la portada activa posee baja saturación cromática, las ondas del notch se renderizan en blanco puro radiante (`#ffffff`) para un contraste cinematográfico.

### 🤖 3. Antigravity AI Live Engine
- **Detección reactiva de tareas y subagentes**: Daemon ligero en Python (`scripts/watch_antigravity.py`) que monitorea SQLite WAL en tiempo real (<0.05% CPU).
- **Indicador dinámico levitante**: Logo vectorial fluido en la barra superior junto a una ola armónica y contador de subagentes.
- **Atajo instantáneo `Super + O`**: Alterna la visualización del monitor de agentes sobre la marcha.

### 🎛️ 4. Estudio de Sonido Acústico Desacoplado
- **Espaciado Estéreo y Reverberación 100% independientes**: El ancho estéreo y el decaimiento de sala se procesan por separado en `sound_engine.py`, evitando saturaciones de audio.
- **Librería de soundpacks completos**: Incluye packs hápticos `default`, `bubble`, `cyber`, `material`, `nothing`, `retro` y `zen`.

### 🔊 5. Estabilidad de Volumen PipeWire / Spotify
- **Solución integral al bug del 13%**: Incluye la configuración optimizada para `pipewire-pulse` que impide que Spotify u otras aplicaciones multimedia restablezcan su volumen al 13% al cambiar de canción.

---

## 🚀 Instalación Rápida

### Método 1: Instalador Automático de Un Solo Comando

Ejecuta el siguiente comando en tu terminal para iniciar el asistente interactivo:

```bash
curl -sSL https://raw.githubusercontent.com/nov4z/Panacea_shell/main/install.sh | bash
```

> [!TIP]
> Si deseas una instalación desatendida sin confirmaciones manuales, agrega el parámetro `-y`:
> ```bash
> curl -sSL https://raw.githubusercontent.com/nov4z/Panacea_shell/main/install.sh | bash -s -- -y
> ```

---

### Método 2: Instalación Manual mediante Git

1. **Clona el repositorio:**
   ```bash
   git clone https://github.com/nov4z/Panacea_shell.git
   cd Panacea_shell
   ```

2. **Ejecuta el instalador:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

El instalador se encargará de:
1. Comprobar e instalar dependencias del sistema vía `pacman`/`yay`/`paru`.
2. Crear un respaldo timestamped de cualquier configuración previa en `~/.config/panacea.backup_<fecha>`.
3. Desplegar los componentes QML, scripts, temas y soundpacks en `~/.config/panacea/`.
4. Asignar permisos ejecutables a todos los scripts auxiliares.
5. Aplicar la regla de estabilidad de volumen para Spotify en `pipewire-pulse`.
6. Configurar el arranque automático en tu archivo de configuración de Hyprland (`exec-once = qs -c ~/.config/panacea`).

---

## ⌨️ Atajos de Teclado (Keybindings)

| Combinación de Teclas | Acción | Descripción |
| :--- | :--- | :--- |
| <kbd>SUPER</kbd> + <kbd>M</kbd> | **Cápsula Musical / Dynamic Island** | Expande el reproductor con onda acústica y letras sincronizadas (SpicyLyrics). |
| <kbd>SUPER</kbd> + <kbd>Z</kbd> | **Centro de Control Unibody** | Abre el panel general de volumen, brillo, estado de red y toggles rápidos. |
| <kbd>SUPER</kbd> + <kbd>O</kbd> | **Alternar Antigravity AI** | Muestra u oculta el indicador reactivo de tareas de inteligencia artificial en la barra. |
| <kbd>SUPER</kbd> + <kbd>I</kbd> | **Ajustes de Notch & Audio** | Abre el estudio de personalización visual y el banco de sonido acústico. |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | **Lanzador de Aplicaciones** | Despliega el launcher flotante de aplicaciones. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | **Menú Rápido Wi-Fi** | Lista interactiva de redes inalámbricas para conexión inmediata. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> | **Menú Rápido Bluetooth** | Administrador de emparejamiento y conexión de auriculares y dispositivos. |
| <kbd>SUPER</kbd> + <kbd>N</kbd> | **Alternar Ocultamiento** | Oculta o muestra el Notch manualmente. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | **Captura de Pantalla** | Selector de área para captura de pantalla rápida. |

---

## 📡 Control por Terminal (IPC Quickshell)

Puedes interactuar con Panacea Shell desde cualquier terminal o script en tiempo real:

```bash
# Alternar reproductor y letras
qs -c ~/.config/panacea ipc call pill music
qs -c ~/.config/panacea ipc call pill toggleLyrics

# Abrir el Centro de Control
qs -c ~/.config/panacea ipc call pill controls

# Alternar visualizador de Antigravity AI
qs -c ~/.config/panacea ipc call pill toggleAntigravity

# Abrir menús de conectividad
qs -c ~/.config/panacea ipc call pill wifi
qs -c ~/.config/panacea ipc call pill bluetooth
```

---

## 📦 Requisitos del Sistema

- **Sistema Operativo**: Linux (Arch Linux, CachyOS, Fedora, Ubuntu o cualquier distribución con soporte Wayland).
- **Compositor Wayland**: Hyprland (recomendado) o compositores compatibles con LayerShell.
- **Shell Engine**: `quickshell` (o `quickshell-git`).
- **Librerías Qt6**: `qt6-declarative`, `qt6-multimedia`, `qt6-svg`, `qt6-5compat`, `qt6-wayland`.
- **Audio & Media**: `pipewire`, `wireplumber`, `pipewire-pulse`, `playerctl`, `cava`.
- **Python**: Python >= 3.10 con `numpy` y `scipy`.
- **Tipografía**: `ttf-jetbrains-mono-nerd` y `noto-fonts-emoji`.

---

## 🗂️ Estructura del Proyecto

```text
Panacea_shell/
├── shell.qml                     # Contenedor central, Notch Dinámico e IpcHandler
├── ControlsView.qml              # Centro de Control Super + Z Dark Unibody
├── IslandMusicView.qml           # Cápsula musical expandible Super + M
├── SpicyLyricsView.qml           # Visor cinemático de letras en tiempo real
├── SetCustomNotch.qml            # Estudio de personalización y vista previa de Notch
├── SetSounds.qml                 # Estudio de audio, efectos y reverberación
├── SettingsView.qml              # Hub central de configuración
├── sound_engine.py               # Motor acústico en tiempo real (ancho + reverb)
├── Themes.js                     # Paletas de color dinámicas y tokens de diseño
├── Translations.qml              # Soporte multi-idioma (Español / Inglés)
├── install.sh                    # Asistente de instalación automatizado
├── uninstall.sh                  # Script de desinstalación y restauración
├── settings.json.example         # Plantilla predeterminada de configuración
├── assets/                       # Iconos vectoriales, logotipos y gráficos
├── scripts/                      # Daemons y scripts de sistema (brillo, red, IA)
├── screenshots/                  # Galería de capturas de pantalla de la interfaz
├── sounds/                       # Soundpacks acústicos completos
└── tests/                        # Suite de pruebas automatizadas E2E
```

---

## 🔄 Desinstalación o Restauración

Si en algún momento deseas desinstalar la interfaz o volver a una copia previa:

```bash
./uninstall.sh
```

El script detectará automáticamente los respaldos previos creados durante la instalación y te permitirá restaurarlos con un solo clic.

---

## 📄 Licencia

Este proyecto se distribuye bajo la licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

<div align="center">
  <sub>Desarrollado y optimizado con dedicación por <b>NovZ</b> (nov4z) • 2026</sub>
</div>
