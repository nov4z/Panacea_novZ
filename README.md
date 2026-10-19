<div align="center">

# 🌌 Panacea_novZ

**Suite de interfaz de escritorio, Notch Dinámico y Centro de Control para Wayland & Hyprland**  
*Bifurcación, optimización y rediseño profundo del proyecto original [Panacea](https://github.com/EnsixD/Panacea) creado por [EnsixD](https://github.com/EnsixD)*

[![Arch Linux](https://img.shields.io/badge/ARCH%20LINUX-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Ubuntu](https://img.shields.io/badge/UBUNTU-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Debian](https://img.shields.io/badge/DEBIAN-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://debian.org/)
[![Fedora](https://img.shields.io/badge/FEDORA-294172?style=for-the-badge&logo=fedora&logoColor=white)](https://getfedora.org/)
<br/>
[![Hyprland](https://img.shields.io/badge/HYPRLAND-00C7B7?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org/)
[![Niri](https://img.shields.io/badge/NIRI-BETA-7852FF?style=for-the-badge&labelColor=444444)](https://github.com/YaLTeR/niri)
[![Quickshell](https://img.shields.io/badge/QUICKSHELL-777777?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me/)
[![Fish](https://img.shields.io/badge/FISH-000000?style=for-the-badge&logo=fish&logoColor=white)](https://fishshell.com/)
[![MIT](https://img.shields.io/badge/MIT-2B78FF?style=for-the-badge)](LICENSE)
<br/>
[![Repositorio Original](https://img.shields.io/badge/Repositorio%20Original-EnsixD%2FPanacea-blue?style=for-the-badge&logo=github)](https://github.com/EnsixD/Panacea)

<br/>

> [!IMPORTANT]
> ### 📢 Reconocimiento, Atribución & "Vibecoding"
> **Quiero dejar expresamente claro que este proyecto NO es una creación aislada desde cero por mí (NovZ).**
> 
> Este repositorio es una versión perfeccionada, expandida y adaptada del proyecto original **[Panacea](https://github.com/EnsixD/Panacea)**, cuyo creador y autor conceptual original es **[EnsixD](https://github.com/EnsixD)**. Todo el mérito por la concepción arquitectónica de la barra y el concepto inicial le pertenece a él.
> 
> Todas las optimizaciones visuales, el motor acústico desacoplado, el sistema dinámico de letras sincronizadas, el rediseño Dark Unibody y las correcciones de estabilidad fueron **completamente vibecodeados por NovZ** (*vibecoding / vibecodeado por NovZ*), llevando la experiencia a un estándar cinematográfico, fluido y libre de asperezas.

> [!NOTE]
> **🌐 Idioma de la interfaz**: Por ahora, todos los menús, paneles de configuración y módulos nuevos que no forman parte del Panacea original están disponibles actualmente **únicamente en español**.

</div>

---

## 📸 Galería Visual

<div align="center">

### 🎬 Demostración en Vivo (Tour Completo de la Suite)
*Recorrido fluido en tiempo real: Isla Dinámica contraída → Cápsula Musical con SpicyLyrics sincronizado → Centro de Control Unibody (`Super + Z`) → Menú Rápido Wi-Fi → Estudio Completo de Configuración (`Super + I`) explorando Notch e Isla Dinámica, Estudio de Sonido Acústico y Apariencia.*

![Panacea_novZ Live Demo](screenshots/demo.gif)

<br/>

### 1. Notch Dinámico & Barra de Estado (Modo Dark Unibody)
*Notch dinámico e isla interactiva inspirada en la dinámica visual de la isla flotante (tipo iPhone), integrada al centro superior de la pantalla con onda acústica reactiva a la música en tiempo real.*

![Notch Dark Unibody](screenshots/notch_dark_unibody.png)

<br/>

### 2. Cápsula Musical Expandida & SpicyLyrics (`Super + M`)
*Despliegue a 60 FPS con sincronización temporal (~50 ms de anticipación) y predicción acústica de márgenes para que ninguna palabra se quiebre de renglón al agrandarse la fuente en tiempo real.*

![SpicyLyrics Sincronizado](screenshots/spicylyrics_sync.png)

<br/>

### 3. Centro de Control Unificado (`Super + Z`)
*Chasis unibody pulido (`#141218`) con esquinas redondeadas continuas, sliders hápticos, carátulas HD y selección rápida de dispositivos sin bordes residuales.*

![Super + Z Control Center](screenshots/super_z_controls.png)

<br/>

### 4. Estudio de Personalización del Notch
*Ajustes en vivo de geometría (anchos, radios, márgenes, padding, resplandor ambiental) con simulación interactiva 1:1 en tiempo real.*

![Notch Settings Studio](screenshots/notch_settings_studio.png)

<br/>

### 5. Estudio Acústico de Sonido Sintetizado (`sound_engine.py`)
*Configuración matemáticamente desacoplada de Ancho Estéreo (Spatial Stereo Width) y Cola de Reverb (Room Decay Reverb) con packs hápticos.*

![Acoustic Sound Studio](screenshots/acoustic_sound_studio.png)

</div>

---

## 🔍 Comparativa Detallada: ¿Qué se añadió en comparación al original de EnsixD?

A continuación se detalla punto por punto el compendio de novedades, refactorizaciones y correcciones vibecodeadas en **Panacea_novZ** frente a la versión original de EnsixD:

### 1. 🏝️ Notch Dinámico e Isla Interactiva (inspirada en la dinámica visual de la isla flotante tipo iPhone)
- **Chasis Dark Unibody Continuo**: En el original existían recuadros de borde y fondos planos que producían desajustes visuales. En `Panacea_novZ` la cápsula utiliza un acabado unibody negro satinado continuo (`#141218`), con curvas hiperelípticas suaves.
- **Resplandor Ambiental Reactivo (*Ambient Glow*)**: Sistema de halo y difusión de luz atmosférica configurable en intensidad (5% a 100%) y radio de dispersión (20px a 160px) que rodea el notch al compás de la música.
- **Hover Peek Inteligente**: Capacidad de pasar el ratón por encima del notch contraído para ver de inmediato el título y glifo de la ventana actualmente activa.
- **Aviso Háptico de Portapapeles (*Clipboard Flash*)**: Destello dinámico en la cápsula cada vez que se copia un elemento al buffer del sistema.
- **Aura Reactiva de Audio (*Audio Ripple*)**: Pulsaciones suaves detrás del notch en reproducción activa sin interferir con la barra de tareas.
- **Indicador Dinámico de Batería con Modos de Carga**: Animación de rayo fluido al conectar la fuente de poder y cambio dinámico de colorimetría por estado de carga.

### 2. 🎤 SpicyLyrics: Motor de Letras Sincronizadas en Tiempo Real
- **Eliminación Total del "Efecto Punto Seguido"**: En implementaciones estándar de letras sincronizadas, al expandir tipográficamente la frase que está sonando, la última palabra salta de renglón de manera tosca. En `Panacea_novZ`, el motor precalcula márgenes y saltos de línea con predicción elástica, logrando que el texto fluya de forma 100% natural.
- **Anticipación Acústica Milimétrica (~50 ms)**: Adelanto de fotograma acústico calibrado para que el resplandor de la frase coincida exactamente con el golpe de voz del cantante.
- **Detección Dinámica de Tempo & Alineación Métrica (BPM Sync)**: Botón interactivo integrado en la cabecera de las letras sincronizadas que analiza armónicamente la cadencia de la canción, calculando el BPM y alineando los versos con el pulso rítmico (*downbeat*), junto con controles de micro-ajuste fino (±10 ms).
- **Backend LRCLIB Robusto**: Estrategia de búsqueda de 4 niveles (coincidencia estricta, limpieza de remasters/feat, búsqueda difusa y fallback para piezas puramente instrumentales).
- **Caché Local Persistente y Atómico**: Almacenamiento local en `~/.cache/panacea/lyrics/` con hashes SHA-256 de alta velocidad, permitiendo lectura instantánea sin latencia de red.
- **Desvanecimiento de Canvas**: Las ondas acústicas de fondo atenúan suavemente su opacidad al abrirse la vista de letras para garantizar contraste y legibilidad absoluta.

### 3. 🎵 Cápsula Musical Expandida (`Super + M`)
- **Modo Blanco y Negro Radiante**: Cuando la portada del álbum en reproducción carece de saturación de color (carátulas en escala de grises o minimalistas), el visualizador de ondas conmuta automáticamente a blanco puro radiante (`#ffffff`), evitando tonalidades opacas y manteniendo una estética premium.
- **Transiciones de Altura Suaves**: La cápsula se redimensiona dinámicamente según se encuentre en modo control estándar o modo SpicyLyrics sin solapamientos de contenido.

### 4. 🎛️ Centro de Control Unificado Perfeccionado (`Super + Z`)
- **Erradicación de Artefactos de Esquina**: Se eliminó de raíz el recuadro cuadrado residual que se dibujaba detrás de la tarjeta multimedia en esquinas redondeadas.
- **Sliders Hápticos Continuos**: Deslizadores táctiles con física fluida para volumen maestro y brillo de pantalla.
- **Selector Rápido de Dispositivos PipeWire**: Interfaz directa para conmutar entre altavoces, auriculares inalámbricos y salidas auxiliares con un solo clic.

### 5. 🔊 Estudio de Sonido Acústico Sintetizado (`sound_engine.py`)
- **Desacoplamiento Matemático Estricto**: El motor acústico en Python fue completamente reescrito para independizar el *Spatial Stereo Width* (ancho estéreo vía efecto Haas / Mid-Side) de la *Cola de Reverb* (Room Decay Reverb). Variar el ancho estéreo no altera la duración del buffer, y variar el reverb no distorsiona el balance de canales.
- **Síntesis Procedural a 48 kHz / 16-Bit**: Generación en tiempo real de tonos armónicos (`marimba`, `glass`, `fm`, `bit`, `bubble`) y pops hápticos de retroalimentación sin depender de archivos de audio de baja calidad.
- **Librería de 7 Soundpacks Integrados**: Incluye `custom`, `nothing`, `material`, `zen`, `cyber`, `retro` y `bubble`.

### 6. 🛠️ Corrección de Bugs del Sistema & Portabilidad
- **Solución al Bug de Caída de Volumen al 13% en Spotify**: Regla de configuración específica para `pipewire-pulse` que elimina la frustrante bajada de volumen automática que Spotify sufría en Linux al cambiar de canción.
- **Cero Rutas Fijas (Hardcoding)**: Todos los componentes usan rutas relativas dinámicas y respetan la especificación XDG (`$XDG_CONFIG_HOME`, `$XDG_CACHE_HOME`).
- **Instalador y Desinstalador Limpios**: Scripts [`install.sh`](install.sh) y [`uninstall.sh`](uninstall.sh) con soporte para respaldos automáticos fechados (*timestamped backups*).

---

## 🚀 Instalación Rápida

### Opción 1: Asistente Interactivo de Un Solo Comando

Ejecuta el siguiente comando en tu terminal:

```bash
curl -sSL https://raw.githubusercontent.com/nov4z/Panacea_novZ/main/install.sh | bash
```

> [!TIP]
> Si prefieres una instalación automática desatendida sin confirmaciones:
> ```bash
> curl -sSL https://raw.githubusercontent.com/nov4z/Panacea_novZ/main/install.sh | bash -s -- -y
> ```

---

### Opción 2: Instalación Manual mediante Git

1. **Clona el repositorio:**
   ```bash
   git clone https://github.com/nov4z/Panacea_novZ.git
   cd Panacea_novZ
   ```

2. **Ejecuta el instalador:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

El instalador se encargará de:
1. Comprobar e instalar dependencias del sistema vía `pacman`/`yay`/`paru`.
2. Crear un respaldo fechado de cualquier configuración previa en `~/.config/panacea.backup_<fecha>`.
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
| <kbd>SUPER</kbd> + <kbd>I</kbd> | **Ajustes de Notch & Audio** | Abre el estudio de personalización visual y el banco de sonido acústico. |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | **Lanzador de Aplicaciones** | Despliega el launcher flotante de aplicaciones. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | **Menú Rápido Wi-Fi** | Lista interactiva de redes inalámbricas para conexión inmediata. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> | **Menú Rápido Bluetooth** | Administrador de emparejamiento y conexión de auriculares y dispositivos. |
| <kbd>SUPER</kbd> + <kbd>N</kbd> | **Alternar Ocultamiento** | Oculta o muestra el Notch manualmente. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | **Captura de Pantalla** | Selector de área para captura de pantalla rápida. |

---

## 📡 Control por Terminal (IPC Quickshell)

Puedes interactuar con Panacea_novZ desde cualquier terminal o script en tiempo real:

```bash
# Alternar reproductor y letras
qs -c ~/.config/panacea ipc call pill music
qs -c ~/.config/panacea ipc call pill toggleLyrics

# Abrir el Centro de Control
qs -c ~/.config/panacea ipc call pill controls

# Desplegar menús rápidos de red
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
Panacea_novZ/
├── qml/                          # Componentes QML, Notch Dinámico, Controles e Interfaz
│   ├── shell.qml                 # Contenedor central, Notch Dinámico e IpcHandler
│   ├── ControlsView.qml          # Centro de Control Super + Z Dark Unibody
│   ├── IslandMusicView.qml       # Cápsula musical expandible Super + M
│   ├── SpicyLyricsView.qml       # Visor cinemático de letras en tiempo real
│   ├── SetCustomNotch.qml        # Estudio de personalización y vista previa de Notch
│   ├── SetSounds.qml             # Estudio de audio, efectos y reverberación
│   ├── SettingsView.qml          # Hub central de configuración
│   ├── Themes.js                 # Paletas de color dinámicas y tokens de diseño
│   └── Translations.qml          # Soporte multi-idioma (Español / Inglés)
├── assets/                       # Iconos vectoriales y gráficos de interfaz
├── scripts/                      # Daemons y scripts auxiliares (brillo, red, letras)
├── screenshots/                  # Galería visual y demos grabadas en alta resolución
├── sounds/                       # Soundpacks acústicos completos
├── tests/                        # Suite de pruebas de integridad automatizadas
├── install.sh                    # Asistente de instalación automatizado
├── uninstall.sh                  # Script de desinstalación y restauración
├── sound_engine.py               # Motor acústico en tiempo real (ancho + reverb)
├── settings.json.example         # Plantilla predeterminada de configuración
└── LICENSE                       # Licencia MIT de software libre
```

---

## 🔄 Desinstalación o Restauración

Si deseas desinstalar la interfaz o regresar a una copia de seguridad anterior:

```bash
./uninstall.sh
```

El script detectará los respaldos generados previamente durante la instalación y te permitirá restaurarlos limpiamente.

---

## ⚖️ Verificación Legal de Licencia

> [!NOTE]
> Este proyecto es 100% legal y seguro de distribuir. El repositorio base [EnsixD/Panacea](https://github.com/EnsixD/Panacea) está publicado bajo la **Licencia MIT**, la cual autoriza abiertamente el uso, modificación y redistribución de código abierto siempre que se conserve el copyright original, condición que se cumple estrictamente conservando la atribución a EnsixD (2026) e incorporando a NovZ (2026).

---

## 📄 Créditos, Atribuciones y Recursos

Quiero dar el debido crédito y agradecer de corazón a las personas y proyectos que hacen posible esta experiencia:

- **Proyecto Original**: Todo el reconocimiento y respeto a **[EnsixD](https://github.com/EnsixD)** por concebir la idea y crear la base de **[Panacea](https://github.com/EnsixD/Panacea)**. Yo tomé su excelente trabajo como punto de partida y me dediqué a vibecodearlo, rediseñarlo y pulirlo a fondo para llevarlo al siguiente nivel.
- **Modificación y Vibecoding**: NovZ ([@nov4z](https://github.com/nov4z)) — arquitectura visual Dark Unibody, motor acústico procedural desacoplado, sincronización y predicción cinemática de SpicyLyrics, optimizaciones de rendimiento y estabilidad en Wayland/Hyprland.
- **Licencia de Código**: Publicado bajo licencia abierta **MIT**, en total respeto y apego a los términos del software libre original. Revisa el archivo [LICENSE](LICENSE) para más información.

<br/>

### 🎨 Fondos de Pantalla (Wallpapers)

> Ninguno de los fondos de pantalla incluidos en este repositorio es de mi autoría — cada uno pertenece íntegramente a su autor original, y los empaqueté aquí únicamente para que una instalación limpia tenga algo hermoso que mostrar de inmediato. Si eres el autor de alguno y quieres que sea retirado, abre un issue y lo quitaré sin ningún problema.

- **[matteogini/dotfiles](https://github.com/matteogini/dotfiles)** — `ember_stripes.jpg` y `misty_peaks.jpg`; la personalización (*rice*) original de la cual nació este setup.
- **[HyDE](https://github.com/HyDE-Project/HyDE)** — `spring_bloom.jpg`, de su tema Graphite Mono; de aquí se derivó la paleta en `hypr/palette.conf`.
- **[ilyamiro/shell-wallpapers](https://github.com/ilyamiro/shell-wallpapers)** — la colección de fondos empaquetada en la carpeta `wallpapers/`.

### 🎥 Wallpapers en Video / Live

La reproducción de fondos de video dinámicos se gestiona mediante **[mpvpaper](https://github.com/GhostNaN/mpvpaper)** (no incluye videos pesados preinstalados para mantener la descarga ligera). Puedes colocar tus propios videos en formato `.mp4`, `.webm`, `.mkv` o `.mov` dentro de `~/.config/hypr/wallpaper/live/`, o conseguirlos bajo sus propios términos en comunidades como [DesktopHut](https://www.desktophut.com/), [Wallper](https://wallper.co/), [TuxPapers](https://tuxpapers.com/) o [Papyrus](https://papyrus.co/).

### 🔤 Tipografía, Iconografía y Gráficos

- **Tipografía de la Interfaz**: **[JetBrains Mono Nerd Font](https://www.jetbrains.com/lp/mono/)** (licencia SIL OFL), junto a **[Material Design Icons](https://materialdesignicons.com/)** para cada glifo de los paneles.
- **Logos y Assets**: Los gráficos `assets/logo*.png` fueron dibujados para este proyecto y comparten la misma licencia del código.

### ⚙️ Sobre Hombros de Gigantes (Tecnologías Base)

Esta suite fue construida sobre el trabajo de fantásticos proyectos de la comunidad:  
[Hyprland](https://hyprland.org/) · [Quickshell](https://quickshell.outfoxxed.me/) · [cava](https://github.com/karlstav/cava) · [cliphist](https://github.com/sentriz/cliphist) · [hyprpaper](https://github.com/hyprwm/hyprpaper) / [hyprsunset](https://github.com/hyprwm/hyprsunset) · [wf-recorder](https://github.com/ammen99/wf-recorder) · [fish](https://fishshell.com/)

---

<div align="center">
  <sub>Basado con admiración en el trabajo original de <b><a href="https://github.com/EnsixD/Panacea">EnsixD</a></b> • Edición vibecodeada por NovZ</sub>
</div>
