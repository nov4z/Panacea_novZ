<div align="center">

# 🌌 Panacea_novZ — Edición Perfeccionada `V:NOVZ`

**Suite de interfaz de escritorio, Notch Dinámico y Centro de Control para Wayland & Hyprland**  
*Bifurcación, optimización y rediseño profundo del proyecto original [Panacea](https://github.com/EnsixD/Panacea) creado por [EnsixD](https://github.com/EnsixD)*

[![Repositorio Original](https://img.shields.io/badge/Repositorio%20Original-EnsixD%2FPanacea-blue?style=for-the-badge&logo=github)](https://github.com/EnsixD/Panacea)
[![Versión](https://img.shields.io/badge/Versi%C3%B3n-V%3ANOVZ%20(1.0.14)-8A2BE2?style=for-the-badge&logo=rocket)](https://github.com/nov4z/Panacea_novZ)
[![Wayland](https://img.shields.io/badge/Display-Wayland-00599C?style=for-the-badge&logo=wayland&logoColor=white)](https://wayland.freedesktop.org/)
[![Hyprland](https://img.shields.io/badge/Window%20Manager-Hyprland-00C7B7?style=for-the-badge&logo=archlinux&logoColor=white)](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Engine-Quickshell%20(Qt6%2FQML)-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me/)
[![Python](https://img.shields.io/badge/Audio%20%26%20Daemons-Python%203-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org/)
[![Tests](https://img.shields.io/badge/Tests-229%20Passed-brightgreen?style=for-the-badge&logo=checkmarx)](tests/)
[![Licencia](https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge)](LICENSE)

<br/>

> [!IMPORTANT]
> ### 📢 Reconocimiento, Atribución & "Vibecoding"
> **Quiero dejar expresamente claro que este proyecto NO es una creación aislada desde cero por mí (NovZ).**
> 
> Este repositorio es una versión perfeccionada, expandida y adaptada del proyecto original **[Panacea](https://github.com/EnsixD/Panacea)**, cuyo creador y autor conceptual original es **[EnsixD](https://github.com/EnsixD)**. Todo el mérito por la concepción arquitectónica de la barra y el concepto inicial le pertenece a él.
> 
> Todas las optimizaciones visuales, el motor acústico desacoplado, el sistema dinámico de letras sincronizadas, el rediseño Dark Unibody y las correcciones de estabilidad fueron **completamente vibecodeados por NovZ** (*vibecoding / vibecodeado por NovZ*), llevando la experiencia a un estándar cinematográfico, fluido y libre de asperezas.

</div>

---

## 📸 Galería Visual

<div align="center">

### 1. Notch Dinámico & Barra de Estado (Modo Dark Unibody)
*Notch dinámico e isla interactiva inspirada en la dinámica visual de la isla flotante (tipo iPhone), integrada al centro superior de la pantalla con onda acústica reactiva a la música en tiempo real.*

![Notch Dark Unibody](screenshots/notch_dark_unibody.png)

<br/>

### 2. Cápsula Musical Expandida & SpicyLyrics (`Super + M`)
*Despliegue a 60 FPS con sincronización temporal (~120 ms de anticipación) y predicción acústica de márgenes para que ninguna palabra se quiebre de renglón al agrandarse la fuente en tiempo real.*

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

## ⚖️ Verificación Legal de Licencia para Distribución

> [!NOTE]
> ### 🛡️ ¿Se puede subir y distribuir este proyecto sin problemas legales?
> **SÍ, 100% SEGURO Y VERIFICADO.**
> 
> 1. **Licencia Original MIT**: El repositorio base [EnsixD/Panacea](https://github.com/EnsixD/Panacea) está publicado bajo la **Licencia MIT**, una de las licencias de software libre y código abierto más permisivas que existen.
> 2. **Términos de la Licencia MIT**: La licencia permite expresamente:
>    - Usar, copiar, modificar, fusionar, publicar, distribuir, sublicenciar y/o vender copias del software.
>    - La **única condición obligatoria** es conservar el aviso de copyright original y el texto de la licencia en todas las copias o porciones sustanciales del software.
> 3. **Cumplimiento en `Panacea_novZ`**:
>    - El archivo [`LICENSE`](LICENSE) conserva íntegramente el copyright original de **EnsixD (2026)** y agrega el copyright de **NovZ (2026)** por las modificaciones añadidas.
>    - El `README.md`, los encabezados y la documentación atribuyen con claridad y orgullo la autoría original a EnsixD.
>    - No se utilizan marcas registradas ajenas ni terminología comercial propietaria (utilizando descripciones funcionales como *"Notch dinámico e isla interactiva inspirada en la dinámica visual de la isla flotante (tipo iPhone)"*).
>
> Por ende, la publicación de este fork en GitHub cumple estrictamente con el marco legal internacional y los estándares del código abierto.

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
- **Anticipación Acústica Milimétrica (~120 ms)**: Adelanto de fotograma acústico calibrado para que el resplandor de la frase coincida exactamente con el golpe de voz del cantante.
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
- **Suite de Pruebas Automatizadas de 229 Tests**: Cobertura exhaustiva en `tests/run_tests.py` que comprueba sintaxis QML, balance de delimitadores, motor acústico y contratos de configuración.

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

El instalador:
1. Verifica e instala automáticamente dependencias necesarias vía `pacman`/`yay`/`paru`.
2. Genera un respaldo timestamped de cualquier configuración previa en `~/.config/panacea.backup_<fecha>`.
3. Despliega los archivos en `~/.config/panacea/`.
4. Asigna permisos ejecutables a todos los scripts auxiliares en `scripts/`.
5. Aplica la corrección de volumen para Spotify en PipeWire.
6. Configura el inicio automático en Hyprland (`exec-once = qs -c ~/.config/panacea`).

---

## ⌨️ Atajos de Teclado (Keybindings)

| Combinación | Acción | Descripción |
| :--- | :--- | :--- |
| <kbd>SUPER</kbd> + <kbd>M</kbd> | **Cápsula Musical & SpicyLyrics** | Expande la isla con reproductor dinámico y visor de letras sincronizadas. |
| <kbd>SUPER</kbd> + <kbd>Z</kbd> | **Centro de Control Unibody** | Despliega el panel general de volumen, brillo, red y toggles rápidos. |
| <kbd>SUPER</kbd> + <kbd>I</kbd> | **Ajustes de Notch & Audio** | Abre el estudio de configuración visual y el banco de sonido acústico. |
| <kbd>SUPER</kbd> + <kbd>Space</kbd> | **Lanzador de Aplicaciones** | Abre el launcher flotante de aplicaciones. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | **Menú Rápido Wi-Fi** | Selector interactivo de redes inalámbricas disponibles. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> | **Menú Rápido Bluetooth** | Administrador de conexión de auriculares y dispositivos periféricos. |
| <kbd>SUPER</kbd> + <kbd>N</kbd> | **Alternar Visibilidad** | Oculta o muestra manualmente el Notch superior. |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | **Captura de Pantalla** | Selector de área para captura de pantalla inmediata. |

---

## 📡 Control por Terminal (IPC Quickshell)

Puedes interactuar con Panacea_novZ desde cualquier terminal o script en tiempo real:

```bash
# Alternar reproductor y letras sincronizadas
qs -c ~/.config/panacea ipc call pill music
qs -c ~/.config/panacea ipc call pill toggleLyrics

# Desplegar el Centro de Control
qs -c ~/.config/panacea ipc call pill controls

# Desplegar menús rápidos de red
qs -c ~/.config/panacea ipc call pill wifi
qs -c ~/.config/panacea ipc call pill bluetooth
```

---

## 🧪 Verificación & Suite de Pruebas

Panacea_novZ incluye una batería de pruebas automatizadas que verifican la integridad estructural, el motor de sonido y las opciones visuales:

```bash
python3 tests/run_tests.py
```

Resultado de la verificación:
```text
======================================================================
 Panacea_novZ Comprehensive Test Suite Runner
======================================================================
Target: Tiers [1, 2, 3, 4, 5, 6, 7, 8, 9]
  Tier 1: 19 tests (Motor de sonido base)
  Tier 2: 14 tests (Desacoplamiento estéreo y reverberación)
  Tier 3: 39 tests (Parser y motor de letras LRCLIB)
  Tier 4: 35 tests (Sincronización SpicyLyrics y animación de cápsula)
  Tier 5: 20 tests (Configuración, AST y búsqueda en ajustes)
  Tier 6: 20 tests (Resplandor ambiental y límites de sliders)
  Tier 7: 10 tests (Dark unibody y geometría de controles)
  Tier 8: 49 tests (Manejo de tiempos y estados de reproducción)
  Tier 9: 23 tests (Detección de modo blanco y negro radiante)
Total Discovered: 229 tests
----------------------------------------------------------------------
Ran 229 tests in 8.456s
OK (SUCCESS - 229 Passed, 0 Failed, 0 Errors)
```

---

## 🗂️ Estructura del Proyecto

```text
Panacea_novZ/
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
├── assets/                       # Iconos vectoriales y gráficos de interfaz
├── scripts/                      # Daemons y scripts auxiliares (brillo, red, letras)
├── screenshots/                  # Galería de capturas de pantalla de alta resolución
├── sounds/                       # Soundpacks acústicos completos
└── tests/                        # Suite de pruebas automatizadas (229 tests)
```

---

## 🔄 Desinstalación o Restauración

Si deseas desinstalar la interfaz o regresar a una copia de seguridad anterior:

```bash
./uninstall.sh
```

El script detectará los respaldos generados previamente durante la instalación y te permitirá restaurarlos limpiamente.

---

## 📄 Créditos y Licencia

- **Proyecto Original**: [Panacea](https://github.com/EnsixD/Panacea) desarrollado por [EnsixD](https://github.com/EnsixD).
- **Modificación, vibecoding y perfeccionamiento V:NOVZ**: NovZ ([@nov4z](https://github.com/nov4z)).
- Distribuido bajo licencia **MIT** en estricto cumplimiento y honor a los términos del software libre original. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

<div align="center">
  <sub>Basado con admiración en el trabajo original de <b><a href="https://github.com/EnsixD/Panacea">EnsixD</a></b> • Edición <b>V:NOVZ</b> vibecodeada por NovZ</sub>
</div>
