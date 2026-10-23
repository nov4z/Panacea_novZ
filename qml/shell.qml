import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit
import Quickshell.Services.Pam
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "Themes.js" as Themes

// Одна пилюля на всё.
//
// Свёрнутая: день недели, время, заряд.
// Играет музыка/видео -> пилюля превращается в медиа-капсулу
//   (обложка + название + живой эквалайзер).
// Наведение -> плавно раскрывается: без музыки — Wi-Fi и Bluetooth,
//   с музыкой — плеер. Курсор ушёл -> сворачивается обратно.
// Super+A -> лаунчер приложений в той же пилюле.
ShellRoot {

PanelWindow {
    id: root

    // ------------------------------------------------- сохраняемые настройки
    // Живут в ~/.config/panacea/settings.json и правятся по Super+I.
    // Файл читается на старте и перечитывается при внешнем изменении.
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/panacea/settings.json"
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property string fontFam: "JetBrainsMono Nerd Font"
            property int    fontSize: 15
            property int    iconSize: 17
            property string colFg:    "#ffffff"
            property real   mutedAlpha: 0.45
            property string colOn:    "#3b82f6"
            property string colBattWarn: "#ff9f0a"
            property string colBattCrit: "#ff453a"
            property string colCharge:   "#30D158"
            property string colPowerSaver: "#22c55e"
            property string colPowerBalanced: "#3b82f6"
            property string colPowerPerf: "#ff453a"
            property string colBt: "#0ea5e9"
            property string colWifi: "#3b82f6"
            property string colVox: "#60a5fa"
            property string colRec: "#ff453a"
            property bool   forceCustomColors: false
            property int    pillH:  38
            // где живёт остров: top | bottom | left | right
            property string pillPos: "top"
            // Автоскрытие: остров уезжает за кромку и не занимает место под
            // себя, окна получают весь экран. Возвращается наведением на
            // узкую полоску у самого края.
            property bool   pillAutoHide: false
            // Режим оверлея: остров парит поверх окон без резервирования полосы
            property bool   pillOverlay: true
            // Остров виден при раскрытии (панель открывается отдельной плавающей карточкой)
            property bool   pillKeepVisible: false
            // Закрывать оверлей Panacea по Super+Q (иначе убивать фоновое окно)
            property bool   closePanaceaFirst: true

            // Настройки мониторов из вкладки Display, JSON вида
            // {"eDP-1":{w,h,rr,scale,transform,vrr,pos}}. Hyprland их не
            // запоминает: hyprctl правит живое состояние, и после перезагрузки
            // конфига или перезахода экран возвращается к своему конфигу.
            property string monOverrides: ""
            // На каком экране живёт остров. "auto" — на том, где сейчас
            // фокус: остров переезжает за человеком. Иначе имя выхода
            // ("eDP-1", "DP-2") — остров прибит к нему намертво.
            property string pillScreen: "auto"

            // ---------------------------------------------- Bar & Island
            // Режим выреза: остров примыкает вплотную к кромке экрана и
            // растекается по ней вогнутыми уголками. Выключенный — остров
            // становится прямоугольной капсулой с отступом от кромки.
            property bool   notchMode: true
            // радиус вогнутого уголка примыкания
            property int    notchFlare: 12
            // ширина свёрнутого острова и высота развёрнутой панели
            property int    collapsedW: 260
            property int    expandedH: 620
            // отступ капсулы от кромки, когда режим выреза выключен
            property int    islandGap: 12
            // скругление капсулы вне режима выреза (0 — по половине высоты)
            property int    islandRadius: 0
            property int    notchSectionGap: 10
            property int    notchBatteryGap: 8
            property int    notchClockPad: 0
            property int    notchWeatherPad: 0
            property bool   notchFluidCorners: true
            property bool   lowBatteryAlert: true
            property int    lowBatteryThreshold: 20
            property int    lowBatteryCritThreshold: 15
            property bool   batt80Alert: true
            property bool   fullBatteryAlert: true
            property bool   chargeSound: true
            property bool   battAlertSound: true
            property bool   chargeRipple: true
            property bool   braveDodgeEnabled: true
            property int    braveReturnDelay: 1000
            property int    musicCenterMode: 3
            property int    musicArtSize: 26
            property int    musicWaveSens: 100
            property bool   musicWaveEnabled: true
            property int    musicCoverRadius: 7
            property string batt80Text: "Carga al 80%"
            property string battFullText: "Carga completa"
            property string battWarnText: "Batería baja"
            property string battCritText: "Batería crítica"
            property string chargeText: "Cargando"
            property int    musicWaveColorMode: 0
            property int    musicWavePos: 0
            property int    musicArtReaction: 1
            property int    musicArtReactionIntensity: 50
            property bool   musicCoverRipple: true
            property int    musicCoverRippleShape: 0
            property int    musicCoverRippleSens: 100
            property int    musicCoverRippleFreq: 0
            property int    musicCoverRipplePersistence: 100
            property bool   musicCoverBounce: true
            property int    musicRightWaveSens: 100
            property int    musicRightWaveFreq: 0
            property int    musicRightWavePersistence: 100

            // ---------------------------------------------- Clock & Date
            property bool   clockSeconds: false
            property bool   clockWeekday: true
            // "auto" — регион и часовой пояс берутся у системы
            property string clockTz: "auto"
            property string clockDateFmt: "d MMMM"

            // ---------------------------------------------- Appearance
            // Тема палитры, независимая от обоев. "default" — то, что стоит
            // сейчас; остальные перечислены в root.themes.
            property string themeId: "default"
            // текстовый шрифт и шрифт заголовков
            property string fontBody: "JetBrainsMono Nerd Font"
            property string fontDisplay: "JetBrainsMono Nerd Font"
            // шаг отступов и малый радиус — из них считается вся геометрия
            property int    spacingUnit: 8
            property int    smallRadius: 10

            // ---------------------------------------------- Motion
            // Полный отказ от анимаций: все длительности считаются нулевыми.
            property bool   reduceMotion: false
            property int    animMove: 230      // размер и положение, мс
            property int    animFade: 200      // прозрачность и цвет, мс
            property int    animHover: 150     // отклик на наведение, мс
            property int    animBounce: 79     // перелёт осциллятора, %

            // ---------------------------------------------- Micro-animaciones & Detalles
            property bool   animPowerIcons: true    // Iconos interactivos en el menú de apagado
            property bool   animTileRotate: true    // Rotación en botón de 3 puntos (󰇙)
            property bool   animTileHover: true     // Micro-escala y brillo en tarjetas del Centro de Control
            property bool   animSlidersGlow: true   // Brillo dinámico en pistas de volumen y brillo
            property bool   animMenuSlide: true     // Desplazamiento lateral suave (+2px/+3px) en listas
            property bool   animChevronSlide: true  // Deslizamiento del indicador chevron (󰅂)
            property bool   animCardLift: true      // Micro-elevación táctil en hover de tarjetas
            property bool   animStatusPulse: true   // Respiración y parpadeo en indicadores de estado
            property string soundPack: "auto"       // auto (según tema), nothing, material, zen, cyber, retro, bubble, custom
            property string soundPackForNothing: "nothing"
            property string soundPackForMaterial: "material"
            property string soundPackForDefault: "nothing"
            property real   soundCustomDepth: 0.6
            property real   soundCustomAttack: 0.5
            property real   soundCustomDecay: 1.0
            property real   soundCustomBright: 0.5
            property string soundCustomStyle: "marimba"
            property real   soundCustomPitch: 0.0     // -12 a +12 semitonos
            property real   soundCustomWarmth: 0.2    // 0.0 a 1.0 saturación analógica
            property real   soundCustomSpatialWidth: 0.50 // 0.0 a 1.0 espacialidad estéreo
            property real   soundCustomReverb: 0.15   // 0.0 a 1.0 espacialidad
            property real   soundCustomVibrato: 0.0   // 0.0 a 1.0 modulación
            property real   soundCustomCutoff: 1.0    // 0.2 a 1.0 filtro paso bajo
            property real   soundCustomGain: 1.0      // 0.5 a 1.5 ganancia de salida
            property bool   notchClipboardFlash: true
            property bool   notchAudioRipple: true
            property bool   notchActiveWindowHover: true
            property bool   notchAmbientGlowEnabled: true
            property int    notchAmbientGlowIntensity: 35
            property int    notchAmbientGlowRadius: 60
            property int    islandLyricsHeight: 240
            property string islandLyricsBehavior: "manual"

            // ---------------------------------------------- Notifications
            property bool   notifDnd: false
            property int    notifTimeout: 5000       // обычные, мс
            property int    notifCritTimeout: 0      // 0 — висят до ответа
            property bool   notifPreview: true       // текст в свёрнутом виде

            // ---------------------------------------------- Lock Screen
            property int    lockBlur: 32
            property string lockHint: ""

            // ---------------------------------------------- Control Center
            // Порядок плиток быстрых настроек, заданный человеком.
            // Пустая строка — заводская раскладка из root.ccDefault.
            property string ccLayout: ""
            property string ccSizes: ""
            // разрешено ли переносить остров мышью прямо на экране
            property bool   pillDrag: false
            property int    panelW: 540
            property int    launcherMaxRows: 6
            property bool   launcherCalc: true
            property bool   launcherRecent: true
            property bool   launcherCategories: true
            property bool   ccGlowSliders: true
            property bool   ccShowBatteryWave: true
            property string lang: "es"        // "es" | "en" | "ru", por defecto español
            property bool   clock12: false    // 12-часовой формат с AM/PM
            // запись экрана
            property int    recFps: 60
            property string recDir: "~/Videos"
            property bool   recSysAudio: false   // звук системы
            property bool   recMic: false        // микрофон
            property string recMicDevice: ""     // "" = микрофон по умолчанию
            // менеджер паролей: предлагать сохранять пароли из буфера обмена
            property bool   vaultCapture: true
            // проводник отдельным окном Hyprland, а не страницей пилюли
            property bool   filesWindow: false
            // Показывать файлы с точки. По умолчанию да: в домашнем каталоге
            // почти всё, за чем в него заходят, начинается именно с неё —
            // .config, .local, .ssh.
            property bool   filesHidden: true
            // Как проводник раскладывает содержимое: "list" — строки с
            // мелкими значками, размером и датой; "grid" — плитки покрупнее,
            // когда важнее узнать файл в лицо, чем прочитать про него цифры.
            // Переключатель стоит рядом с поиском, выбор запоминается.
            property string filesMode: "list"

            // Цифровая интенсивность, шкала как в панели NVIDIA: 50 — как
            // есть, 100 — максимум. На Wayland ручка из nvidia-settings не
            // работает вовсе, поэтому цвет правит шейдер компоновщика.
            property int    vibrance: 50

            // ------------------------------------------------------- мышь
            // Скорость указателя в понимании libinput: -1 — самая медленная,
            // 0 — как есть, 1 — самая быстрая. Это не «умножение на два», а
            // сдвиг кривой, поэтому шаг мелкий.
            property real   mouseSens: 0
            // Прямой ввод: libinput перестаёт разгонять указатель за резкое
            // движение, и одно и то же расстояние по столу всегда даёт одно
            // и то же расстояние по экрану. То, ради чего в играх выключают
            // «повышенную точность установки указателя».
            property bool   mouseRaw: false
            property string keyboardLayouts: "us,ru"
            property string keyboardVariants: ","
            property string keyboardOptions: "grp:alt_shift_toggle"

            // Включённые функции. При установке дотфайлов целиком доступно всё
            // (по умолчанию true); установщик острова выключает то, что человек
            // не отметил, и тогда соответствующей кнопки/страницы в пилюле нет,
            // а служба (демон уведомлений, агент polkit) не регистрируется —
            // чтобы не спорить с уже установленными в системе.
            property bool   featLauncher: true
            property bool   featPlayer: true
            property bool   featWifi: true
            property bool   featBluetooth: true
            property bool   featClipboard: true
            property bool   featNotifications: true
            property bool   featCalendar: true
            property bool   featThemes: true
            property bool   featRecord: true
            property bool   featFiles: true
            property bool   featMedia: true
            property bool   featVault: true
            property bool   featLock: true
            property bool   featAudio: true
            property bool   featPowerProfiles: true
            property bool   featOsd: true
            property bool   featPowermenu: true
            property bool   featPolkit: true
            property bool   hasSeenWelcome: false

            // ---------------------------------------------- macOS Dock
            property bool   dockEnabled: true
            property bool   dockAutoHide: false
            property bool   dockMagnify: true
            property bool   dockShowRunning: true
            property int    dockIconSize: 34
            property real   dockZoom: 1.22
            property string dockApps: "brave-origin.desktop,kitty.desktop,com.spotify.Client.desktop,thunar.desktop,panacea:settings"

            // ---------------------------------------------- Weather & Widgets
            // Ключ и город пусты по умолчанию: без них виджет погоды просто
            // не показывается. Ключ чужой, бесплатный и выдаётся на почту —
            // подставить сюда что-то своё нельзя.
            property string weatherKey: ""
            property string weatherCity: ""
            property string weatherUnits: "metric"   // metric | imperial
            // Погода в свёрнутом острове. Включена: место она занимает
            // небольшое, а смотрят на остров чаще, чем на рабочий стол,
            // который закрыт окнами.
            property bool   weatherOnIsland: true
            // Настольные виджеты. Выключены по умолчанию: они рисуются
            // поверх обоев и меняют вид рабочего стола, а такое включают
            // сами, а не обнаруживают после обновления.
            property bool   featWidgets: false
            property string widgetClockMode: "analog"
            property string widgetRightMode: "weather"
            property string widgetProgressMode: "day"
            property bool   systemLoadOnIsland: false
            // JSON string: {"Turkish":"TR","Russian":"RU"}
            property string keyboardLayoutMap: ""
            // ---------------------------------------------- Material You Colors
            property string m3ColorMode: "wallpaper"   // "wallpaper" | "music" | "manual"
            property string m3ManualColor: "#e08096"

            // Прозрачность терминала. Живёт здесь, а правится в foot.ini:
            // сам foot настройки оболочки не читает.
            property real   termAlpha: 0.90

            // сочетания; пересобираются в lua/binds_data.lua
            property string bind_pillDock: "SUPER + A"
            property string bind_pillLauncher: "SUPER + Space"
            property string bind_pillControls: "SUPER + Z"
            property string bind_pillSettings: "SUPER + I"
            property string bind_pillShortcuts: "SUPER + apostrophe"
            property string bind_overview: "SUPER + Tab"
            property string bind_pillWifi: "SUPER + SHIFT + W"
            property string bind_pillBt: "SUPER + SHIFT + B"
            property string bind_pillClip: "SUPER + V"
            property string bind_pillPower: "CTRL + ALT + delete"
            property string bind_pillNotif: "SUPER + SHIFT + N"
            property string bind_pillRecord: "SUPER + P"
            property string bind_terminal: "SUPER + T"
            property string bind_terminalAlt: "SUPER + Return"
            property string bind_closeWindow: "SUPER + Q"
            property string bind_browser: "SUPER + F"
            property string bind_fullscreen: "SUPER + SHIFT + F"
            property string bind_exitHypr: "SUPER + SHIFT + M"
            property string bind_themeSwitch: "SUPER + SHIFT + T"
            property string bind_floatToggle: "SUPER + W"
            property string bind_pillVault: "SUPER + SHIFT + P"
            // Голос в текст (voxtype): зажми правый Alt — говоришь, отпустил —
            // вставилось. Обрабатывается парой press/release в keybindings.lua.
            property string bind_voxDictate: ""
            property string bind_floatCenter: "SUPER + SHIFT + Space"
            property string bind_fileManager: "SUPER + E"
            property string bind_fileManagerTui: "SUPER + SHIFT + E"
            property string bind_toggleSplit: "SUPER + J"
            property string bind_notes: "SUPER + O"
            property string bind_screenshot: "SUPER + SHIFT + S"
            property string bind_screenOff: "SUPER + SHIFT + F12"
            property string bind_packWorkspaces: "SUPER + SHIFT + A"
            property string bind_emptyWorkspace: "SUPER + Space"
            property string bind_specialWorkspace: "SUPER + S"
            property string bind_workspace1: "SUPER + 1"
            property string bind_workspace2: "SUPER + 2"
            property string bind_workspace3: "SUPER + 3"
            property string bind_workspace4: "SUPER + 4"
            property string bind_workspace5: "SUPER + 5"
            property string bind_workspace6: "SUPER + 6"
            property string bind_workspace7: "SUPER + 7"
            property string bind_workspace8: "SUPER + 8"
            property string bind_workspace9: "SUPER + 9"
            property string bind_workspace10: "SUPER + 0"
            property string bind_moveWorkspace1: "SUPER + SHIFT + 1"
            property string bind_moveWorkspace2: "SUPER + SHIFT + 2"
            property string bind_moveWorkspace3: "SUPER + SHIFT + 3"
            property string bind_moveWorkspace4: "SUPER + SHIFT + 4"
            property string bind_moveWorkspace5: "SUPER + SHIFT + 5"
            property string bind_moveWorkspace6: "SUPER + SHIFT + 6"
            property string bind_moveWorkspace7: "SUPER + SHIFT + 7"
            property string bind_moveWorkspace8: "SUPER + SHIFT + 8"
            property string bind_moveWorkspace9: "SUPER + SHIFT + 9"
            property string bind_moveWorkspace10: "SUPER + SHIFT + 0"
            property string bind_lockScreen: "SUPER + L"
            property string bind_closeMouse: "mouse:277"
            property string bind_focusLeft: "SUPER + left"
            property string bind_focusRight: "SUPER + right"
            property string bind_focusUp: "SUPER + up"
            property string bind_focusDown: "SUPER + down"
            property string bind_moveLeft: "SUPER + SHIFT + left"
            property string bind_moveRight: "SUPER + SHIFT + right"
            property string bind_moveUp: "SUPER + SHIFT + up"
            property string bind_moveDown: "SUPER + SHIFT + down"
            property string bind_resizeRight: "ALT + right"
            property string bind_resizeLeft: "ALT + left"
            property string bind_resizeUp: "ALT + up"
            property string bind_resizeDown: "ALT + down"
            property string bind_workspaceNext: "SUPER + mouse_down"
            property string bind_workspacePrevious: "SUPER + mouse_up"
            property string bind_dragWindow: "SUPER + mouse:272"
            property string bind_resizeWindowMouse: "SUPER + mouse:273"
            property string bind_micMute: "XF86AudioMicMute"
            property string bind_volumeUp: "XF86AudioRaiseVolume"
            property string bind_volumeDown: "XF86AudioLowerVolume"
            property string bind_volumeMute: "XF86AudioMute"
            property string bind_brightnessUp: "XF86MonBrightnessUp"
            property string bind_brightnessDown: "XF86MonBrightnessDown"
            property string bind_mediaNextAlt: "SUPER + XF86AudioRaiseVolume"
            property string bind_mediaPreviousAlt: "SUPER + XF86AudioLowerVolume"
            property string bind_mediaNext: "XF86AudioNext"
            property string bind_mediaPause: "XF86AudioPause"
            property string bind_mediaPlay: "XF86AudioPlay"
            property string bind_mediaPrevious: "XF86AudioPrev"
            property string bind_lidOn: "switch:on:Lid Switch"
            property string bind_lidOff: "switch:off:Lid Switch"
            property string bind_powerCycle: "SUPER + ALT + P"
            property string bind_pillHide: "SUPER + H"
            property string bind_pillRotateCenter: "SUPER + SHIFT + H"
            property string bind_pillToggleNotch: "SUPER + N"
            property string bind_pillMusic: "SUPER + M"
        }
    }
    // Заводские сочетания. Держим одним списком, чтобы «Сбросить»
    // возвращал ровно те значения, что заданы по умолчанию.
    readonly property var defaultBinds: ({
        pillDock:     "SUPER + A",
        pillLauncher: "SUPER + Space",
        pillControls: "SUPER + Z",
        pillSettings: "SUPER + I",
        pillShortcuts: "SUPER + apostrophe",
        overview:     "SUPER + Tab",
        pillWifi:     "SUPER + SHIFT + W",
        pillBt:       "SUPER + SHIFT + B",
        pillClip:     "SUPER + V",
        pillPower:    "CTRL + ALT + delete",
        pillNotif:    "SUPER + SHIFT + N",
        pillRecord:   "SUPER + P",
        terminal:       "SUPER + T",
        terminalAlt:    "SUPER + Return",
        closeWindow:    "SUPER + Q",
        browser:        "SUPER + F",
        fullscreen:     "SUPER + SHIFT + F",
        exitHypr:       "SUPER + SHIFT + M",
        themeSwitch:    "SUPER + SHIFT + T",
        floatToggle:    "SUPER + W",
        pillVault:      "SUPER + SHIFT + P",
        voxDictate:     "",
        floatCenter:    "SUPER + SHIFT + Space",
        fileManager:    "SUPER + E",
        fileManagerTui: "SUPER + SHIFT + E",
        toggleSplit:    "SUPER + J",
        notes:          "SUPER + O",
        screenshot:     "SUPER + SHIFT + S",
        screenOff:      "SUPER + SHIFT + F12",
        packWorkspaces: "SUPER + SHIFT + A",
        emptyWorkspace: "SUPER + Space",
        specialWorkspace: "SUPER + S",
        lockScreen:     "SUPER + L",
        workspace1: "SUPER + 1",
        workspace2: "SUPER + 2",
        workspace3: "SUPER + 3",
        workspace4: "SUPER + 4",
        workspace5: "SUPER + 5",
        workspace6: "SUPER + 6",
        workspace7: "SUPER + 7",
        workspace8: "SUPER + 8",
        workspace9: "SUPER + 9",
        workspace10: "SUPER + 0",
        moveWorkspace1: "SUPER + SHIFT + 1",
        moveWorkspace2: "SUPER + SHIFT + 2",
        moveWorkspace3: "SUPER + SHIFT + 3",
        moveWorkspace4: "SUPER + SHIFT + 4",
        moveWorkspace5: "SUPER + SHIFT + 5",
        moveWorkspace6: "SUPER + SHIFT + 6",
        moveWorkspace7: "SUPER + SHIFT + 7",
        moveWorkspace8: "SUPER + SHIFT + 8",
        moveWorkspace9: "SUPER + SHIFT + 9",
        moveWorkspace10: "SUPER + SHIFT + 0",
        closeMouse: "mouse:277",
        focusLeft: "SUPER + left",
        focusRight: "SUPER + right",
        focusUp: "SUPER + up",
        focusDown: "SUPER + down",
        moveLeft: "SUPER + SHIFT + left",
        moveRight: "SUPER + SHIFT + right",
        moveUp: "SUPER + SHIFT + up",
        moveDown: "SUPER + SHIFT + down",
        resizeRight: "ALT + right",
        resizeLeft: "ALT + left",
        resizeUp: "ALT + up",
        resizeDown: "ALT + down",
        workspaceNext: "SUPER + mouse_down",
        workspacePrevious: "SUPER + mouse_up",
        dragWindow: "SUPER + mouse:272",
        resizeWindowMouse: "SUPER + mouse:273",
        micMute: "XF86AudioMicMute",
        volumeUp: "XF86AudioRaiseVolume",
        volumeDown: "XF86AudioLowerVolume",
        volumeMute: "XF86AudioMute",
        brightnessUp: "XF86MonBrightnessUp",
        brightnessDown: "XF86MonBrightnessDown",
        mediaNextAlt: "SUPER + XF86AudioRaiseVolume",
        mediaPreviousAlt: "SUPER + XF86AudioLowerVolume",
        mediaNext: "XF86AudioNext",
        mediaPause: "XF86AudioPause",
        mediaPlay: "XF86AudioPlay",
        mediaPrevious: "XF86AudioPrev",
        lidOn: "switch:on:Lid Switch",
        lidOff: "switch:off:Lid Switch",
        pillHide: "SUPER + H",
        pillRotateCenter: "SUPER + SHIFT + H",
        pillToggleNotch: "SUPER + N",
        pillMusic: "SUPER + M",
        powerCycle: "SUPER + ALT + P"
    })

    readonly property var cfg: cfgFile.adapter
    Binding { target: Compositor; property: "keyboardLayoutMap"; value: root.cfg.keyboardLayoutMap }
    function saveCfgNow() { cfgFile.writeAdapter(); }

    // Заводские значения всего, что правится в окне настроек. Сочетания
    // клавиш сюда не входят: у них свой список и своя кнопка сброса.
    readonly property var defaultCfg: ({
        fontFam: "JetBrainsMono Nerd Font", fontBody: "JetBrainsMono Nerd Font",
        fontDisplay: "JetBrainsMono Nerd Font", fontSize: 15, iconSize: 17,
        colFg: "#ffffff", colOn: "#3b82f6", mutedAlpha: 0.45, themeId: "default",
        spacingUnit: 8, smallRadius: 10,
        pillH: 38, pillPos: "top", pillScreen: "auto", pillAutoHide: false, pillOverlay: true,
        pillKeepVisible: false, closePanaceaFirst: true,
        pillDrag: false, panelW: 540,
        monOverrides: "",
        notchMode: true, notchFlare: 12, collapsedW: 260, expandedH: 620,
        islandGap: 12, islandRadius: 0,
        reduceMotion: false, animMove: 230, animFade: 200, animHover: 150, animBounce: 0,
        animPowerIcons: true, animTileRotate: true, animTileHover: true,
        animSlidersGlow: true, animMenuSlide: true, animChevronSlide: true,
        animCardLift: true, animStatusPulse: true,
        clock12: false, clockSeconds: false, clockWeekday: true,
        clockTz: "auto", clockDateFmt: "d MMMM",
        notifDnd: false, notifTimeout: 5000, notifCritTimeout: 0, notifPreview: true,
        lockBlur: 32, lockHint: "",
        ccLayout: "", ccSizes: "", filesWindow: false, filesHidden: true, filesMode: "list",
        launcherMaxRows: 6, launcherCalc: true, launcherRecent: true, launcherCategories: true,
        ccGlowSliders: true, ccShowBatteryWave: true,
        vaultCapture: true,
        vibrance: 50, mouseSens: 0, mouseRaw: false,
        keyboardLayouts: "us,ru", keyboardVariants: ",", keyboardOptions: "grp:alt_shift_toggle",
        recFps: 60, recDir: "~/Videos", recSysAudio: false, recMic: false, recMicDevice: "",
        weatherKey: "", weatherCity: "", weatherUnits: "metric",
        weatherOnIsland: true, systemLoadOnIsland: false, keyboardLayoutMap: "", featWidgets: false,
        widgetClockMode: "analog", widgetRightMode: "weather", widgetProgressMode: "day", termAlpha: 0.90,
        braveReturnDelay: 1000, notchSectionGap: 10, notchBatteryGap: 8, notchClockPad: 0,
        musicArtSize: 26, musicWaveSens: 100, musicCoverRadius: 7,
        musicCoverBounce: true, musicCoverRipple: true, musicCoverRippleShape: 0,
        musicCoverRippleSens: 100, musicCoverRippleFreq: 0, musicCoverRipplePersistence: 100,
        musicArtReactionIntensity: 50, musicRightWaveSens: 100,
        musicRightWaveFreq: 0, musicRightWavePersistence: 100,
        musicWaveColorMode: 0, musicWavePos: 0, musicWaveEnabled: true,
        musicCenterMode: 3, notchFluidCorners: true, notchMusicBgMode: 0,
        batt80Alert: true, batt80Text: "Carga al 80%",
        fullBatteryAlert: true, battFullText: "Carga completa",
        lowBatteryAlert: true, lowBatteryThreshold: 20, battWarnText: "Batería baja",
        lowBatteryCritThreshold: 15, battCritText: "Batería crítica",
        colCharge: "#30D158", colBattWarn: "#ff9f0a", colBattCrit: "#ff453a",
        colPowerSaver: "#22c55e", colPowerBalanced: "#3b82f6", colPowerPerf: "#ff453a",
        colBt: "#0ea5e9", colWifi: "#3b82f6", colVox: "#60a5fa", colRec: "#ff453a",
        chargeText: "Cargando", chargeRipple: true, chargeSound: true, battAlertSound: true,
        islandPopSound: true, uiSounds: true, kbdLightSound: true, kbdLightToast: true,
        cameraSound: true, cameraToast: true,
        volumeSoundTick: true, powerProfileSound: true, soundPack: "auto",
        soundPackForNothing: "nothing", soundPackForMaterial: "material", soundPackForDefault: "nothing",
        soundCustomDepth: 0.6, soundCustomAttack: 0.5, soundCustomDecay: 1.0, soundCustomBright: 0.5, soundCustomStyle: "marimba",
        soundCustomPitch: 0.0, soundCustomWarmth: 0.2, soundCustomSpatialWidth: 0.50, soundCustomReverb: 0.15, soundCustomVibrato: 0.0, soundCustomCutoff: 1.0, soundCustomGain: 1.0,
        notchClipboardFlash: true, notchAudioRipple: true, notchActiveWindowHover: true,
        notchAmbientGlowEnabled: true, notchAmbientGlowIntensity: 35, notchAmbientGlowRadius: 60,
        islandLyricsHeight: 240, islandLyricsBehavior: "manual"
    })

    function activeSoundPack() {
        if (root.cfg && root.cfg.soundPack && root.cfg.soundPack !== "auto") return root.cfg.soundPack;
        if (root.themeMaterial) return (root.cfg && root.cfg.soundPackForMaterial) || "material";
        if (root.themeNothing) return (root.cfg && root.cfg.soundPackForNothing) || "nothing";
        return (root.cfg && root.cfg.soundPackForDefault) || "nothing";
    }

    Process { id: pSound }
    function playSound(name, packOverride) {
        if (root.cfg.uiSounds === false && !packOverride) return;
        if (name && (name.indexOf("/") === 0 || name.indexOf("~") === 0)) {
            pSound.command = ["sh", "-c", "if command -v pw-play >/dev/null 2>&1; then pw-play \"$1\" & elif command -v paplay >/dev/null 2>&1; then paplay \"$1\" & fi", "_", name];
            pSound.running = false;
            pSound.running = true;
            return;
        }
        var pack = packOverride || root.activeSoundPack();
        var baseDir = Quickshell.env("HOME") + "/.config/panacea/sounds/";
        var p = baseDir + pack + "/" + name + ".wav";
        pSound.command = ["sh", "-c", "f=\"$1\"; [ -f \"$f\" ] || f=\"$2\"\"$3.wav\"; if command -v pw-play >/dev/null 2>&1; then pw-play \"$f\" & elif command -v paplay >/dev/null 2>&1; then paplay \"$f\" & fi", "_", p, baseDir, name];
        pSound.running = false;
        pSound.running = true;
    }

    function resetCfg() {
        for (var k in root.defaultCfg) cfg[k] = root.defaultCfg[k];
        root.saveCfg();
    }

    // ------------------------------------------------------- экраны
    // Одна точка, через которую вкладка Display разговаривает с Hyprland,
    // и она же — память об этом разговоре.
    //
    // hyprctl keyword отвергается новым (не-legacy) парсером конфига и при
    // этом выходит с нулевым кодом, поэтому раньше настройки монитора молча
    // никуда не уезжали. Идём через hyprctl eval и hl.monitor{}, а keyword
    // оставляем запасным путём для старых конфигов.
    Process { id: pMon; property string args: ""; command: ["sh", "-c", pMon.args] }

    function monCmd(n, o) {
        var mode = o.w + "x" + o.h + "@" + Number(o.rr).toFixed(2);
        var lua = "hl.monitor({ output=\"" + n + "\", mode=\"" + mode
                + "\", position=\"" + o.pos + "\", scale=" + Number(o.scale).toFixed(6)
                + ", transform=" + o.transform + ", vrr=" + (o.vrr ? 1 : 0) + " })";
        var legacy = n + "," + mode + "," + o.pos + "," + Number(o.scale).toFixed(6)
                   + ",transform," + o.transform + ",vrr," + (o.vrr ? 1 : 0);
        return "out=$(hyprctl eval '" + lua + "' 2>&1); case \"$out\" in ok*) ;; *) "
             + "hyprctl keyword monitor '" + legacy + "' ;; esac";
    }

    function monMap() {
        try { return JSON.parse(root.cfg.monOverrides || "{}") || ({}); }
        catch (e) { return ({}); }
    }

    function monApply(n, o) {
        pMon.args = root.monCmd(n, o);
        pMon.running = false;
        pMon.running = true;
        var all = root.monMap();
        all[n] = o;
        root.cfg.monOverrides = JSON.stringify(all);
        root.saveCfg();
        // Компоновщику режим нужен ещё до нашего запуска: Qt привязывает
        // таймер анимаций к частоте обновления, когда создаёт первое окно, а
        // мы к тому моменту только стартуем. Пересобираем его конфиг, чтобы в
        // следующий раз монитор поднялся сразу на своей частоте.
        genMonTimer.restart();
    }

    Process { id: pGenMon }
    Timer {
        id: genMonTimer
        interval: 400
        onTriggered: {
            pGenMon.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/genmonitors.sh"];
            pGenMon.running = false;
            pGenMon.running = true;
        }
    }

    // Накатить запомненное заново: на старте оболочки и после каждой
    // перезагрузки конфига компоновщика — она сбрасывает живые настройки.
    function monReplay() {
        var all = root.monMap(), parts = [];
        for (var n in all) parts.push(root.monCmd(n, all[n]));
        if (!parts.length) return;
        pMon.args = parts.join("; ");
        pMon.running = false;
        pMon.running = true;
    }

    // ------------------------------------------- цифровая интенсивность
    // Считает и применяет отдельный скрипт: там же лежит сам шейдер и знание
    // о том, как разговаривать с компоновщиком. Здесь только запоминаем.
    Process { id: pVibrance }

    // Ползунок шлёт значение на каждое движение мыши, а каждый вызов — это
    // пересборка шейдера и перечитывание его компоновщиком. Без сдерживания
    // они идут внахлёст, и Hyprland ловит файл на середине записи. Число в
    // окне меняется сразу, к компоновщику уходит только то, на чём ручка
    // остановилась.
    Timer {
        id: vibranceFlush
        interval: 160
        onTriggered: {
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
            root.saveCfg();
        }
    }

    function applyVibrance(pct) {
        root.cfg.vibrance = Math.max(0, Math.min(100, Math.round(pct)));
        vibranceFlush.restart();
    }

    // ----------------------------------------------------------- мышь
    // Через hyprctl eval по той же причине, что и настройки мониторов:
    // keyword не-legacy парсер молча отвергает, выходя с нулевым кодом.
    Process { id: pInput; property string args: ""; command: ["sh", "-c", pInput.args] }
    Process {
        id: pGenInput
        command: [root.scriptDir + "/geninput.sh"]
        stderr: StdioCollector {
            onStreamFinished: {
                var message = String(text).trim();
                if (message.length) root.keyboardInputError = message;
            }
        }
    }
    property bool keyboardInputPending: false
    property string keyboardInputError: ""
    function applyKeyboardLayouts(layouts, variants, options) {
        var l = String(layouts).replace(/\s+/g, "");
        var v = String(variants).replace(/\s+/g, "");
        var o = String(options).replace(/\s+/g, "");
        if (!/^[A-Za-z0-9_,+-]+$/.test(l) || l[0] === "," || l[l.length - 1] === "," || l.indexOf(",,") >= 0
                || !/^[A-Za-z0-9_,+-]*$/.test(v) || !/^[A-Za-z0-9_,:+-]*$/.test(o)) {
            root.keyboardInputError = root.tr("Некорректные коды раскладок или параметры переключения");
            return false;
        }
        var count = l.split(",").length;
        if (/^,*$/.test(v)) v = Array(count).join(",");
        if (v.split(",").length !== count) {
            root.keyboardInputError = root.tr("Число вариантов должно совпадать с числом раскладок");
            return false;
        }
        root.keyboardInputError = "";
        root.cfg.keyboardLayouts = l;
        root.cfg.keyboardVariants = v;
        root.cfg.keyboardOptions = o;
        root.keyboardInputPending = true;
        root.saveCfg();
        return true;
    }
    function applyInput() {
        var lua = "hl.config({ input = { sensitivity = "
                + Number(root.cfg.mouseSens).toFixed(3)
                + ", accel_profile = \"" + (root.cfg.mouseRaw ? "flat" : "adaptive") + "\""
                + " } })";
        var legacy = "hyprctl keyword input:sensitivity "
                   + Number(root.cfg.mouseSens).toFixed(3)
                   + "; hyprctl keyword input:accel_profile "
                   + (root.cfg.mouseRaw ? "flat" : "adaptive");
        pInput.args = "out=$(hyprctl eval '" + lua + "' 2>&1); "
                    + "case \"$out\" in ok*) ;; *) " + legacy + " ;; esac";
        pInput.running = false;
        pInput.running = true;
        root.saveCfg();
    }

    // Настройки ввода и цвета живут в компоновщике, а он их не помнит: любой
    // hyprctl reload — и всё вернулось к тому, что записано в конфиге. Своё
    // накатываем заново вместе с настройками мониторов, одним таймером —
    // см. monReplayTimer, он же срабатывает и на старте оболочки.

    // ------------------------------------------------- проводная сеть
    // Кабель воткнут — значок сети должен быть проводной, а не Wi-Fi: связь
    // идёт по нему, и рисовать антенну поверх работающего кабеля неверно.
    //
    // Смотрим в sysfs, а не спрашиваем NetworkManager: в системе может стоять
    // iwd с systemd-networkd, и тогда NM просто нет. Ядро же знает про
    // несущую на интерфейсе всегда, кто бы сетью ни управлял.
    //
    //   type == 1  — Ethernet (ARPHRD_ETHER);
    //   carrier    — есть ли линк прямо сейчас, то есть воткнут ли кабель;
    //   wireless/  — каталог есть только у беспроводных, их пропускаем.
    //
    // Мосты, докер, туннели и виртуальные пары отсеиваем по имени: у них
    // тоже type 1 и своя несущая, но интернетом они не являются.
    property string wiredName: ""
    readonly property bool wiredOn: root.wiredName.length > 0

    Process {
        id: pWired
        command: ["sh", "-c",
            "for d in /sys/class/net/*; do " +
            "n=${d##*/}; " +
            "[ -d \"$d/wireless\" ] && continue; " +
            "case $n in lo|docker*|veth*|br-*|virbr*|tun*|tap*|wg*|zt*|tailscale*) continue ;; esac; " +
            "[ \"$(cat $d/type 2>/dev/null)\" = 1 ] || continue; " +
            "[ \"$(cat $d/carrier 2>/dev/null)\" = 1 ] && { echo $n; exit 0; }; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                root.wiredName = lines.length ? lines[lines.length - 1].trim() : "";
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { pWired.running = false; pWired.running = true; }
    }

    // семейства моноширинных шрифтов для выпадающего списка настроек
    property var fontList: ["JetBrainsMono Nerd Font"]
    Process {
        id: pFonts
        command: ["sh", "-c",
            "fc-list :spacing=100 family | tr ',' '\\n' | sed 's/^ *//' | sort -u | grep -v '^$'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim().split("\n").filter(x => x.length);
                if (a.length) root.fontList = a;
            }
        }
    }

    function saveCfg() { cfgFile.writeAdapter(); }

    property bool dockVisible: true
    property bool dockForced: false
    function toggleDock() {
        if (root.cfg.dockAutoHide) {
            root.dockForced = !root.dockForced;
        } else {
            root.dockVisible = !root.dockVisible;
        }
    }

    // Russian is the source text. English and Turkish are bundled in Translations.qml;
    // all other system locales fall back to English until a translation is added.
    readonly property Translations i18n: Translations {}

    property int langChangeSeq: 0
    readonly property string localeId: { var _s = root.langChangeSeq; return String((root.cfg && root.cfg.lang) || "es"); }
    readonly property string languageCode: localeId.split(/[_-]/)[0].toLowerCase()
    readonly property bool isEn: languageCode === "en"
    readonly property bool isTr: languageCode === "tr"
    readonly property bool isEs: languageCode === "es" || (!isEn && languageCode !== "ru" && !isTr)
    function tr(k) {
        if (!k) return "";
        var _seq = root.langChangeSeq;
        if (root.languageCode === "ru") {
            if (i18n.ru && i18n.ru[k] !== undefined) return i18n.ru[k];
            return k;
        }
        if (root.languageCode === "es" || root.isEs) {
            if (i18n.es && i18n.es[k] !== undefined) return i18n.es[k];
            if (i18n.en && i18n.en[k] !== undefined) return i18n.en[k];
            return k;
        }
        if (root.languageCode === "tr" && i18n.tr && i18n.tr[k] !== undefined) return i18n.tr[k];
        if (i18n.en && i18n.en[k] !== undefined) return i18n.en[k];
        return k;
    }

    // -------------------------------------------------- язык экрана входа
    // Greeter работает от пользователя sddm и наши настройки прочитать не
    // может: ~/ закрыт. Дублируем выбранный язык в общий каталог тем же
    // QML-фрагментом, что и акцент темы, — иначе экран входа продолжал бы
    // говорить по-русски после переключения системы на английский.
    // Каталог заводит установщик; если его нет, молча ничего не делаем.
    Process {
        id: pGreeterLocale
        command: ["sh", "-c",
            "d=/var/lib/panacea; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject { property string lang: \"%s\" }\\n' " +
            "\"$1\" > \"$d/locale.qml\" && chmod 644 \"$d/locale.qml\"",
            "_", root.cfg.lang]
    }
    // Палитра для экрана входа — тем же способом и в тот же каталог.
    //
    // Раньше её писал hypr/scripts/palette.sh из $accent_color, а это
    // палитра терминалов и редакторов, к теме оболочки отношения не имеющая.
    // Совпадение было случайным: на чёрно-белой теме экран входа встречал
    // терракотовым кружком аватара и таким же кружком загрузки.
    //
    // Пишем не один акцент, а всю четвёрку: у Nothing своя не только
    // выделяющая краска, но и текст с фоном.
    Process {
        id: pGreeterTheme
        command: ["sh", "-c",
            "d=/var/lib/panacea; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject {\\n" +
            "  property color value: \"%s\"\\n" +
            "  property color fg: \"%s\"\\n" +
            "  property color muted: \"%s\"\\n" +
            "  property color bg: \"%s\"\\n}\\n' " +
            "\"$1\" \"$2\" \"$3\" \"$4\" > \"$d/accent.qml\" " +
            "&& chmod 644 \"$d/accent.qml\"",
            "_",
            String(root.colOn), String(root.colFg),
            String(root.colMuted), String(root.colBg)]
    }
    // Прозрачность терминала — правилом компоновщика, а не alpha в foot.ini.
    //
    // Сам foot читает свой конфиг только при запуске: ползунок не менял бы
    // ничего в уже открытых окнах, а именно там его и двигают, глядя на
    // терминал. Правило Hyprland применяется сразу и ко всем окнам разом.
    //
    // Пишем и применяем: файл нужен, чтобы значение пережило перезагрузку —
    // windowrules.lua подхватывает его при старте, — а eval, чтобы увидеть
    // результат сейчас, не дожидаясь следующего входа в систему.
    Process {
        id: pTermAlpha
        command: ["sh", "-c",
            "d=\"$HOME/.config/hypr/lua\"; mkdir -p \"$d\" || exit 0; " +
            "printf 'return { opacity = %s }\\n' \"$1\" > \"$d/term_data.lua\"; " +
            "hyprctl eval \"hl.window_rule({ name = 'panacea-term-opacity', " +
            "match = { class = '^(kitty|footclient|foot)$' }, opacity = $1 })\" >/dev/null 2>&1",
            "_", root.cfg.termAlpha.toFixed(2)]
    }
    // Сдерживаем, как и запись яркости по шине: ползунок шлёт значение на
    // каждое движение мыши, а каждое — это запуск hyprctl. Наперегонки они
    // спорят за один и тот же вызов, и компоновщик показывает баннер с
    // ошибкой. Пишем, когда рука остановилась.
    Timer {
        id: termAlphaFlush
        interval: 180
        onTriggered: {
            pTermAlpha.running = false;
            pTermAlpha.running = true;
        }
    }
    function applyTermAlpha() { termAlphaFlush.restart(); }

    // Перезапуск сервера терминала.
    //
    // Нужен там, где правило компоновщика бессильно: своя alpha у foot,
    // цвета, шрифт — всё это сервер читает один раз при старте и раздаёт
    // клиентам. Просто убить его нельзя: автозапуск отрабатывает один раз за
    // сеанс и заново не поднимет, а без сервера терминал перестанет
    // открываться вовсе. Поэтому убиваем и тут же поднимаем сами.
    //
    // Открытые окна при этом закроются — они и есть клиенты умершего
    // сервера. Об этом сказано на кнопке.
    Process {
        id: pTermRestart
        command: ["sh", "-c",
            "pkill -x foot >/dev/null 2>&1; sleep 0.4; " +
            "setsid -f foot --server >/dev/null 2>&1"]
    }
    // Запуск команды, переживающей закрытие панели.
    //
    // Process, объявленный внутри страницы, умирает вместе с ней: меню
    // питания закрывает панель сразу после запуска, и страница уничтожается
    // в тот же миг. Быстрым командам вроде systemctl хватало мгновения
    // отделиться, а блокировке — нет: её скрипт сперва готовит фон из обоев,
    // и Process убивали раньше, чем дело доходило до самого экрана. Со
    // стороны это выглядело как неработающая кнопка.
    //
    // Здесь процесс живёт в корне оболочки, который не уничтожается никогда,
    // так что торопиться ему некуда.
    Process { id: pDetached }
    function runDetached(cmd) {
        // Через компоновщик, а не своим Process.
        //
        // Даже отвязанный setsid потомок не переживал закрытия панели:
        // блокировка успевала дойти до запуска экрана — это видно по следу в
        // lock.log, — и тут же умирала, не оставив ни строчки в stderr и ни
        // своего файла журнала. Так выглядит убитый процесс, а не упавший.
        //
        // Hyprland запускает программы своим потомком — тем же способом,
        // каким их открывают горячие клавиши, — и оболочка ему в этом не
        // родитель. Дальше процесс живёт сам по себе.
        //
        // Одинарные кавычки внутри команды экранируем: путь их не содержит,
        // но команда приходит извне, и молча испорченная строка хуже явной.
        if (Compositor.isNiri) {
            Compositor.exec(cmd);
            return;
        }
        if (Hyprland.usingLua) {
            var safe = String(cmd).replace(/'/g, "\\'");
            Hyprland.dispatch("hl.dsp.exec_cmd('" + safe + "')");
        } else {
            Hyprland.dispatch("exec " + String(cmd));
        }
    }

    function restartTerminalServer() {
        pTermRestart.running = false;
        pTermRestart.running = true;
    }

    // Фон терминала под тему.
    //
    // На Nothing он совпадает с карточками виджетов — тем же тёмно-серым,
    // чтобы терминал читался частью набора, а не чужим окном. На остальных
    // темах файл пустой, и цвет остаётся тот, что задаёт общая палитра: она
    // правится руками и о темах оболочки не знает.
    //
    // Пишем в свой файл, а не в тот, что генерирует palette.sh: у одного
    // файла не бывает двух хозяев без спора. foot.ini подключает оба, наш
    // вторым — побеждает подключённый позже.
    readonly property string termBg: "171717"
    Process {
        id: pTermTheme
        command: ["sh", "-c",
            "f=\"$HOME/.config/foot/panacea-theme\"; mkdir -p \"$(dirname \"$f\")\" || exit 0; " +
            "if [ -n \"$1\" ]; then " +
            "printf '[colors-dark]\\nbackground=%s\\n' \"$1\" > \"$f\"; " +
            "else : > \"$f\"; fi",
            "_", root.themeNothing ? root.termBg : ""]
    }
    function syncTermTheme() {
        pTermTheme.running = false;
        pTermTheme.running = true;
    }

    function syncGreeterTheme() {
        pGreeterTheme.running = false;
        pGreeterTheme.running = true;
    }
    onThemeChanged: {
        root.syncGreeterTheme();
        root.syncTermTheme();
    }

    // ------------------------------------------------------------ язык
    // Язык оболочки меняется мгновенно — это её собственный словарь. Язык
    // остального (приложений, меню, системных сообщений) живёт в LANG и
    // требует root, поэтому идёт через pkexec: агент polkit у оболочки свой,
    // окно с паролем нарисует она сама.
    //
    // Часы при этом остаются 24-часовыми при любом языке: за формат отвечает
    // отдельная переменная, и скрипт её не трогает.
    property string sysLang: "en"
    property bool   sysLangPending: false
    function canonicalLocale(value) {
        if (value === "en") return "en_US";
        if (value === "ru") return "ru_RU";
        if (value === "tr") return "tr_TR";
        if (value === "es") return "es_ES";
        return String(value || "");
    }
    readonly property bool systemLocaleMatches: canonicalLocale(root.sysLang) === canonicalLocale(root.cfg.lang)

    Process {
        id: pLocaleGet
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/locale.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim().split("\n").pop().trim();
                if (s.length) root.sysLang = s;
            }
        }
    }

    Process {
        id: pLocaleSet
        onExited: {
            root.sysLangPending = false;
            pLocaleGet.running = false;
            pLocaleGet.running = true;
        }
    }

    Process { id: pUserLocaleSync }

    function setLang(code) {
        if (root.cfg.lang === code) return;
        // Оболочка переключается сразу, не дожидаясь пароля: её словарь
        // системного языка не касается, и ждать здесь нечего.
        root.cfg.lang = code;
        root.saveCfg();
        root.langChangeSeq++;

        // Sincronizar el entorno de la sesión de usuario y aplicaciones en tiempo real
        var loc = canonicalLocale(code) + ".UTF-8";
        pUserLocaleSync.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config\" && " +
            "printf 'LANG=%s\\nLC_TIME=%s\\n' \"" + loc + "\" \"" + loc + "\" > \"$HOME/.config/locale.conf\" && " +
            "systemctl --user set-environment LANG=\"" + loc + "\" LC_TIME=\"" + loc + "\" 2>/dev/null || true; " +
            "dbus-update-activation-environment --systemd LANG=\"" + loc + "\" LC_TIME=\"" + loc + "\" 2>/dev/null || true"
        ];
        if (pUserLocaleSync.running) pUserLocaleSync.running = false;
        pUserLocaleSync.running = true;

        root.sysLangPending = true;
        pLocaleSet.command = ["pkexec", Quickshell.env("HOME") + "/.config/panacea/scripts/locale.sh", "set", code];
        pLocaleSet.running = false;
        pLocaleSet.running = true;
    }

    Process { id: pTerminalThemeSync }

    function setTheme(id) {
        root.cfg.themeId = id;
        root.saveCfg();
        if (id === "material3" || id === "material") {
            root.updateMatugenTheme();
        } else {
            pTerminalThemeSync.command = ["python3", root.scriptDir + "/sync_terminal_colors.py", id];
            if (pTerminalThemeSync.running) pTerminalThemeSync.running = false;
            pTerminalThemeSync.running = true;
        }
    }


    function syncGreeterLocale() {
        pGreeterLocale.running = false;
        pGreeterLocale.running = true;
    }
    // Один обработчик на сигнал: QML второго не допускает, поэтому всё, что
    // должно случиться на смене языка, собрано здесь.
    //
    // Погоду переспрашиваем потому, что описание словами приходит от сервиса
    // уже переведённым — язык передаётся в запросе. Свои подписи оболочка
    // переключает сразу, а это одно осталось бы на прежнем языке до
    // следующего опроса, то есть до четверти часа.
    onLocaleIdChanged: {
        root.langChangeSeq++;
        root.syncGreeterLocale();
        if (root.cfg.featWidgets || root.cfg.weatherOnIsland) root.refreshWeather();
    }
    onIsEnChanged: {
        root.syncGreeterLocale();
        if (root.cfg.featWidgets || root.cfg.weatherOnIsland) root.refreshWeather();
    }
    onIsEsChanged: {
        root.syncGreeterLocale();
        if (root.cfg.featWidgets || root.cfg.weatherOnIsland) root.refreshWeather();
    }

    // Видимость вогнутых уголков острова.
    //
    // Гаснут они сразу, а появляются с задержкой на время движения капсулы.
    // Уголки — отдельные элементы, привязанные к её краям, и при возврате из
    // настроек они проявлялись мгновенно, ещё когда капсула ехала на место:
    // со стороны выглядело, будто две наклейки слетаются к острову с разных
    // сторон. Пока он едет, их просто нет, и приезжает он целым.
    readonly property bool cornersWanted:
        !(root.settingsMode || root.wallsOpen || root.pillHidden || root.manualHidden || root.braveDodgeActive)
    property bool cornersOn: false
    Timer {
        id: cornerReveal
        interval: root.animMs + 40
        onTriggered: root.cornersOn = true
    }
    onCornersWantedChanged: {
        if (root.cornersWanted) {
            cornerReveal.restart();
        } else {
            cornerReveal.stop();
            root.cornersOn = false;
        }
    }

    // ------------------------------------ перезагрузка в другую систему
    // Процесс живёт ЗДЕСЬ, в корне, а не в лаунчере, откуда его вызывают.
    //
    // Лаунчер закрывается сразу после выбора, и через animMs + 40 мс страница
    // сбрасывается на главную — вид уничтожается, а вместе с ним и всё, что в
    // нём объявлено. Process, заведённый внутри лаунчера, умирал за четверть
    // секунды, тогда как pkexec к этому моменту только успевал нарисовать окно
    // с паролем. Снаружи это выглядело ровно как «нажал и ничего не
    // произошло»: ни ошибки, ни окна, ни перезагрузки.
    //
    // setsid здесь не годится, хотя и пережил бы закрытие панели: он уводит
    // процесс в новый сеанс, а polkit по сеансу и решает, чьё это право. Корень
    // оболочки живёт столько же, сколько сама оболочка, и этого достаточно.
    Process {
        id: pBootOs
        stderr: StdioCollector {
            onStreamFinished: {
                var t = String(text).trim();
                if (t.length === 0) return;
                // Тихо падать этой команде нельзя: человек ждёт перезагрузки и
                // по отсутствию окна не отличит отказ polkit от того, что
                // нажатие вовсе не дошло.
                console.warn("bootos:", t);
                pBootOsSay.command = ["notify-send", "-u", "critical",
                                      root.tr("Не удалось перезагрузиться"), t];
                pBootOsSay.running = false;
                pBootOsSay.running = true;
            }
        }
    }
    Process { id: pBootOsSay }

    // ------------------------------------ открыть файл выбранной программой
    // Живёт здесь по той же причине, что и перезагрузка в другую систему:
    // проводник закрывается сразу после выбора, и Process, объявленный внутри
    // него, умирал вместе с видом — раньше, чем успевал запустить программу.
    // Снаружи это выглядело как «выбрал программу, проводник закрылся, ничего
    // не открылось».
    Process { id: pOpenWith }
    function openFileWith(path, desktopFile) {
        if (!path) return;
        var s = root.scriptDir + "/files.sh";
        pOpenWith.command = desktopFile && desktopFile.length
            ? ["sh", "-c", s + ' open "$1" "$2"', "_", String(path), String(desktopFile)]
            : ["sh", "-c", s + ' open "$1"', "_", String(path)];
        pOpenWith.running = false;
        pOpenWith.running = true;
    }

    function bootIntoSystem(id) {
        if (!id) return;
        pBootOs.command = ["pkexec", root.scriptDir + "/bootos.sh", "boot", String(id)];
        pBootOs.running = false;
        pBootOs.running = true;
    }

    // Номер версии оболочки: его правит автор при выпуске, а хеш коммита
    // рядом говорит, из какого состояния репозитория собрана сборка.
    readonly property string version: "1.0.14-novz"

    // ------------------------------------------------------------ обновление
    // Установленную версию помечает установщик (~/.config/panacea/.version),
    // а update.sh сверяет её с концом ветки на GitHub. Хеш коммита меняется от
    // любой правки — и от новых файлов, и от изменений в старых, и от удалений,
    // поэтому одного сравнения хватает, чтобы поймать всё сразу.
    property string updStatus: ""      // "" | current | behind | unknown | offline
    property string updSubject: ""     // заголовок последнего коммита
    property string updLatest: ""      // хеш на GitHub
    property string updCurrent: ""     // хеш, с которого ставили
    property bool   updBusy: false
    property string updStep: ""
    property string updError: ""      // код ошибки от update.sh, не текст
    // о какой версии уже сообщали: одно уведомление на выпуск, а не на проверку
    property string updNotified: ""

    readonly property bool updateAvailable: updStatus === "behind"

    // update.sh печатает код, а не фразу: иначе текст ошибки приходил бы на
    // языке скрипта и не слушался выбранного языка интерфейса.
    readonly property string updErrorText: {
        switch (root.updError) {
        case "":         return "";
        case "nogit":    return root.tr("Не установлен git");
        case "offline":  return root.tr("Нет связи с GitHub");
        case "download": return root.updIsReinstall ? root.tr("Не удалось скачать Panacea_novZ") : root.tr("Не удалось скачать обновление");
        case "clean":    return root.tr("Ошибка очистки конфигурации");
        case "install":  return root.tr("Установщик завершился с ошибкой");
        default:         return root.updIsReinstall ? root.tr("Сбой переустановки") : root.tr("Обновление не удалось");
        }
    }

    // Идёт ли сейчас проверка. Отдельно от updBusy: обновление длится минуты и
    // показывается в острове, а проверка — секунду-другую и живёт только в
    // окне настроек. Без этого флага нажатие на «Проверить» не отвечало ничем:
    // ответ приходил, когда человек уже решил, что кнопка сломана, — и если
    // версия оказывалась прежней, не менялось вообще ничего.
    property bool updChecking: false

    function checkUpdate() {
        if (root.updBusy || root.updChecking) return;
        root.updChecking = true;
        root.updError = "";
        root.updIsReinstall = false;
        pUpdCheck.running = false;
        pUpdCheck.running = true;
    }

    property bool   updIsReinstall: false

    function applyUpdate() {
        if (root.updBusy) return;
        root.updBusy = true;
        root.updIsReinstall = false;
        root.updError = "";
        root.updStep = "download";
        root.updCreepAt = 0;
        // Обновление идёт минуты и переживает закрытие настроек: показываем
        // его в острове, иначе о нём знало бы только открытое окно.
        root.beginBusy(root.tr("Обновление…"), "󰚰", root.updStepPercent);
        pUpdApply.running = true;
    }

    function applyReinstall() {
        if (root.updBusy) return;
        root.updBusy = true;
        root.updIsReinstall = true;
        root.updError = "";
        root.updStep = "download";
        root.updCreepAt = 0;
        root.beginBusy(root.tr("Переустановка…"), "󰑓", root.updStepPercent);
        pReinstallApply.running = true;
    }

    // Проценты у обновления считаются по этапам, которые печатает update.sh:
    // байтов и файлов оно не считает, а этапы известны наперёд.
    //
    // Веса, а не равные доли. Этапы длятся по-разному: скачивание идёт
    // секунды, а сохранение настроек и отметка версии — доли секунды. При
    // равных долях полоса замирала на первой седьмой, а потом за миг
    // проскакивала остальные шесть — то есть скакала вместо того, чтобы
    // заполняться. Числа взяты из замеров: клон около трёх секунд,
    // установщик около одной, остальное — мгновения.
    readonly property var updSteps: [
        { id: "download",   w: 30 },
        { id: "clean",      w: 5  },
        { id: "selfupdate", w: 2  },
        { id: "backup",     w: 3  },
        { id: "install",    w: 12 },
        { id: "greeter",    w: 2  },
        { id: "restore",    w: 3  },
        { id: "restart",    w: 2  },
        { id: "done",       w: 0  }
    ]
    readonly property real updWeightTotal: {
        var t = 0;
        for (var i = 0; i < root.updSteps.length; i++) t += root.updSteps[i].w;
        return t > 0 ? t : 1;
    }
    function updStepIndex(id) {
        for (var i = 0; i < root.updSteps.length; i++)
            if (root.updSteps[i].id === id) return i;
        return -1;
    }
    // Доля начатого этапа — то, что накоплено до него. Внутри самого этапа
    // полосу двигает updCreep: сколько именно прошло, скрипт не знает.
    readonly property int updStepPercent: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k < i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }
    // Сколько отдать текущему этапу целиком: до этой границы его и подползаем.
    readonly property int updStepCeil: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k <= i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }

    // Полоса ползёт и внутри этапа, не дожидаясь следующего.
    //
    // Самый долгий шаг — скачивание, и его длительность зависит от связи:
    // ни git, ни установщик о ходе работы не сообщают. Стоящая полоса на
    // медленной сети читается как зависшее обновление. Поэтому она движется
    // сама, замедляясь у границы этапа и никогда её не переступая: дойти до
    // конца раньше настоящего конца было бы обманом.
    // Своя дробная доля, а не busyProgress: тот целый, и приращение меньше
    // единицы в нём терялось бы — полоса застревала бы у самой границы, куда
    // подползает всё медленнее.
    property real updCreepAt: 0

    Timer {
        id: updCreep
        interval: 220
        repeat: true
        running: root.updBusy && root.updStep !== "done"
        onTriggered: {
            var to = root.updStepCeil;
            if (root.updCreepAt >= to) return;
            // шаг тем меньше, чем ближе граница
            var left = to - root.updCreepAt;
            root.updCreepAt = Math.min(to, root.updCreepAt + Math.max(0.25, left * 0.06));
            root.busyProgress = Math.round(root.updCreepAt);
        }
    }
    onUpdStepChanged: {
        if (!root.updBusy) return;
        // Назад полоса не ходит: этап мог начаться раньше, чем подполз
        // предыдущий, и откат читался бы как сбой.
        if (root.updStepPercent > root.updCreepAt)
            root.updCreepAt = root.updStepPercent;
        if (root.updStep === "done") root.updCreepAt = 100;
        root.busyProgress = Math.round(root.updCreepAt);
    }

    function updParse(text, done) {
        var lines = String(text).trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var kv = lines[i].split("=");
            if (kv.length < 2) continue;
            var k = kv[0].trim(), v = lines[i].slice(kv[0].length + 1).trim();
            if (k === "status")       root.updStatus = v;
            else if (k === "subject") root.updSubject = v;
            else if (k === "latest")  root.updLatest = v;
            else if (k === "current") root.updCurrent = v;
            else if (k === "step")    root.updStep = v;
            else if (k === "error")   root.updError = v;
            else if (k === "missing")  root.missingDeps = v;
            else if (k === "obsolete") root.obsoleteDeps = v;
            else if (k === "version") root.updCurrent = v;
        }
        if (!done) return;
        // Уведомление показываем один раз на версию: проверка идёт по таймеру,
        // и каждые шесть часов напоминать об одном и том же — навязчиво.
        if (root.updStatus === "behind" && root.updLatest !== root.updNotified) {
            root.updNotified = root.updLatest;
            pUpdNotify.running = true;
        }
    }

    Process {
        id: pUpdCheck
        command: [root.scriptDir + "/update.sh", "check"]
        stdout: StdioCollector { onStreamFinished: root.updParse(text, true) }
        // Снимаем флаг по выходу процесса, а не по концу вывода: скрипт может
        // упасть, ничего не напечатав, и тогда крутилка осталась бы навсегда.
        onExited: root.updChecking = false
    }

    Process {
        id: pUpdApply
        command: [root.scriptDir + "/update.sh", "apply"]
        // Построчно, а не StdioCollector.
        //
        // StdioCollector копит весь вывод и отдаёт его одним куском, когда
        // поток закроется, то есть когда обновление уже кончилось. Строки
        // step= приезжали все разом и в самом конце — полоса честно стояла на
        // нуле всё обновление, а потом оболочка просто перезапускалась. Ход
        // работы, показанный после её окончания, — это не ход работы.
        //
        // SplitParser отдаёт каждую строку сразу, как скрипт её напечатал.
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.updParse(data, false)
        }
        onExited: code => {
            root.updBusy = false;
            root.updIsReinstall = false;
            root.endBusy();
            if (code !== 0 && root.updError.length === 0)
                root.updError = "failed";
            if (code === 0) { root.updStatus = "current"; root.updStep = "done"; }
        }
    }

    Process {
        id: pReinstallApply
        command: [root.scriptDir + "/reinstall.sh", "apply", "--from-menu"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.updParse(data, false)
        }
        onExited: code => {
            root.updBusy = false;
            root.endBusy();
            if (code !== 0) {
                if (root.updError.length === 0)
                    root.updError = "failed";
                root.updIsReinstall = false;
                reinstallStateFile.reload();
                reinstallCacheFile.reload();
            } else {
                root.updStatus = "current";
                root.updStep = "done";
            }
        }
    }

    // Обычное уведомление рабочего стола: его увидят, даже когда окно настроек
    // закрыто, а поймает его собственная служба уведомлений оболочки.
    // -p заставляет notify-send напечатать номер уведомления. Он нужен,
    // чтобы потом узнать своё же уведомление в общей ленте: сравнивать текст
    // нельзя — он переводится, и на другом языке проверка молча перестала бы
    // совпадать.
    property int updNotifId: -1
    Process {
        id: pUpdNotify
        command: ["notify-send", "-p", "-a", "Panacea", "-i",
                  ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/panacea/assets/logo-128.png"),
                  root.tr("Доступно обновление Panacea"), root.updSubject]
        stdout: StdioCollector {
            onStreamFinished: root.updNotifId = parseInt(String(text).trim()) || -1
        }
    }

    // ----------------------------------------------------- «что нового»
    // update.sh кладёт список изменений в .whatsnew. Оболочка после
    // перезапуска показывает его один раз и файл стирает.
    property var whatsNew: []
    readonly property bool whatsNewOpen: whatsNew.length > 0

    FileView {
        id: whatsNewFile
        path: Quickshell.env("HOME") + "/.config/panacea/.whatsnew"
        watchChanges: true
        // Файла почти всегда нет, и это не ошибка: он появляется только
        // после обновления. Без этого лог засорялся при каждом запуске.
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(whatsNewFile.text()).trim();
            root.whatsNew = t.length ? t.split("\n").filter(x => x.trim().length) : [];
        }
        onLoadFailed: root.whatsNew = []
    }

    // Слежение цепляется к существующему файлу, а .whatsnew появляется уже
    // после запуска оболочки, если обновлялись без перезапуска. Поэтому
    // первые полминуты перечитываем сами.
    Timer {
        interval: 3000
        running: root.whatsNew.length === 0
        repeat: true
        triggeredOnStart: true
        property int tries: 0
        onTriggered: {
            whatsNewFile.reload();
            if (++tries > 10) running = false;
        }
    }

    // Пакеты, которых не хватает после обновления. Ставим не мы: обновление
    // идёт с --no-deps, а хватать пакеты через sudo из-под кнопки в настройках
    // — не то, чего от него ждут. Поэтому просто называем их на том же экране.
    property string missingDeps: ""

    // Простое копирование в буфер. Пароли идут своим путём — им нужен
    // --sensitive-data и очистка по таймеру, см. vaultCopy().
    Process { id: pCopyText }
    function copyText(t) {
        pCopyText.running = false;
        pCopyText.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", String(t)];
        pCopyText.running = true;
    }

    FileView {
        id: missingDepsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.missingdeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.missingDeps = String(missingDepsFile.text()).trim()
        onLoadFailed: root.missingDeps = ""
    }

    // Обратная сторона: что оболочка ставила раньше и больше не использует.
    // Удалять сами не будем — это пакеты в системе человека, а не наши.
    property string obsoleteDeps: ""
    FileView {
        id: obsoleteDepsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.obsoletedeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.obsoleteDeps = String(obsoleteDepsFile.text()).trim()
        onLoadFailed: root.obsoleteDeps = ""
    }

    function dismissWhatsNew() {
        root.whatsNew = [];
        root.missingDeps = "";
        root.obsoleteDeps = "";
        if (!root.cfg.hasSeenWelcome) {
            root.cfg.hasSeenWelcome = true;
            root.saveCfg();
        }
        pWhatsNewClear.running = true;
    }
    Process {
        id: pWhatsNewClear
        command: ["sh", "-c",
                  "rm -f \"$1/.whatsnew\" \"$1/.missingdeps\" \"$1/.obsoletedeps\"", "_",
                  Quickshell.env("HOME") + "/.config/panacea"]
    }

    // ----------------------------------------------------- Bienvenida y Primera Ejecución
    property bool welcomeOpen: false
    property string reinstallStatusMsg: ""
    property bool   reinstallStatusIsError: false
    property bool   reinstallStateHandled: false

    function openWelcome() {
        if (arguments.length > 0 && typeof arguments[0] === "string") {
            root.reinstallStatusMsg = arguments[0];
            root.reinstallStatusIsError = (arguments[1] === true);
        } else {
            root.reinstallStatusMsg = "";
            root.reinstallStatusIsError = false;
        }
        root.welcomeOpen = true;
    }

    function dismissWelcome() {
        root.welcomeOpen = false;
        root.reinstallStatusMsg = "";
        root.reinstallStatusIsError = false;
        if (!root.cfg.hasSeenWelcome) {
            root.cfg.hasSeenWelcome = true;
            root.saveCfg();
        }
    }

    // Comprobación de estado de reinstalación desde el menú (~/.cache o ~/.config)
    FileView {
        id: reinstallStateFile
        path: Quickshell.env("HOME") + "/.config/panacea/.reinstall_state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(reinstallStateFile.text()).trim();
            if (t.length > 0) root.handleReinstallState(t);
        }
    }

    FileView {
        id: reinstallCacheFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/panacea/reinstall_status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(reinstallCacheFile.text()).trim();
            if (t.length > 0) root.handleReinstallState(t);
        }
    }

    Timer {
        id: reinstallCheckTimer
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        property int checks: 0
        onTriggered: {
            if (root.reinstallStateHandled) {
                running = false;
                return;
            }
            reinstallStateFile.reload();
            reinstallCacheFile.reload();
            if (++checks >= 10) running = false;
        }
    }

    Process {
        id: pReinstallStateClear
        command: ["sh", "-c",
                  "rm -f \"$1/.reinstall_state\" \"$2/panacea/reinstall_status.json\" \"$2/reinstall_status.json\"", "_",
                  Quickshell.env("HOME") + "/.config/panacea",
                  Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")]
    }

    Process {
        id: notifyReinstallProcess
        property string title: ""
        property string msg: ""
        property string urgency: "normal"
        command: ["notify-send", "-u", urgency, "-a", "Panacea", "-i",
                  ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/panacea/assets/logo-128.png"),
                  title, msg]
    }

    function handleReinstallState(jsonStr) {
        if (root.updIsReinstall) return;
        if (root.reinstallStateHandled) return;
        try {
            var obj = JSON.parse(jsonStr);
            if (!obj || !obj.status) return;
            root.reinstallStateHandled = true;
            pReinstallStateClear.running = true;

            if (obj.status === "success" || obj.status === "ok") {
                var sMsg = root.tr("¡Panacea novZ se reinstaló correctamente desde cero de forma limpia!");
                root.playSound("voice_done");
                notifyReinstallProcess.urgency = "normal";
                notifyReinstallProcess.title = "Panacea novZ";
                notifyReinstallProcess.msg = sMsg;
                notifyReinstallProcess.running = true;
                root.openWelcome(sMsg, false);
            } else if (obj.status === "failed") {
                var fMsg = root.tr("La reinstalación no pudo completarse y se restauró el estado previo.");
                root.playSound("lowbatt");
                notifyReinstallProcess.urgency = "critical";
                notifyReinstallProcess.title = "Panacea novZ";
                notifyReinstallProcess.msg = fMsg;
                notifyReinstallProcess.running = true;
                root.reinstallStatusMsg = "";
                root.reinstallStatusIsError = false;
            }
        } catch(e) {}
    }

    // Temporizador de primera instalación: si no ha visto la bienvenida, mostrarla
    Timer {
        id: firstRunWelcomeTimer
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            if (!root.cfg.hasSeenWelcome && !root.whatsNewOpen) {
                root.openWelcome();
            }
        }
    }

    // Первая проверка не на старте: при входе в систему сеть ещё поднимается,
    // и запрос почти наверняка не прошёл бы.
    Timer { interval: 45000; running: true; onTriggered: root.checkUpdate() }
    Timer { interval: 6 * 3600 * 1000; running: true; repeat: true; onTriggered: root.checkUpdate() }

    readonly property string scriptDir:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/panacea/scripts"

    // capture.sh off зовёт этот IPC, чтобы панель сняла режим захвата
    signal cancelCaptureRequested()

    // Какая вкладка настроек откроется: 0 — пилюля, 2 — экран, 3 — клавиши.
    property int settingsTab: 0
    // Открыть настройки на разделе по имени, а не по номеру: номера зависят
    // от порядка в списке разделов, и новый раздел посередине молча уводил бы
    // не туда. Пустая строка — раздел не задан.
    property string settingsSection: ""
    function openSettingsAt(sectionId) {
        root.settingsSection = sectionId;
        if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
    }

    // Пересобрать binds_data.lua и перечитать конфиг Hyprland
    Process { id: pGenBinds }
    // Скрипт читает settings.json, а запись файла асинхронная: если запускать
    // его сразу после saveCfg(), он успевал прочитать ещё старое сочетание —
    // и «Применить» не меняло ничего. Ждём сигнала о завершении записи.
    property bool bindsPending: false
    function applyBinds() {
        root.bindsPending = true;
        saveCfg();
        bindsFallback.restart();
    }
    function runGenBinds() {
        if (!root.bindsPending) return;
        root.bindsPending = false;
        bindsFallback.stop();
        pGenBinds.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/genbinds.sh"];
        pGenBinds.running = true;
    }
    // страховка, если сигнала о записи почему-то не будет
    Timer { id: bindsFallback; interval: 700; onTriggered: root.runGenBinds() }

    // Сочетания живут в settings.json, но Hyprland читает только производный
    // от него binds_data.lua. Файл лежит внутри ~/.config/hypr, который
    // установщик заменяет целиком, — и пропадал вместе с ним. Настройки при
    // этом оставались на месте, поэтому со стороны это выглядело так, будто
    // сочетания «не сохраняются»: окно Super+/ показывает своё, а нажатия
    // работают заводские. Собираем файл заново, если его нет.
    Process {
        id: pBindsHeal
        running: true
        command: ["sh", "-c",
            "[ -f \"$HOME/.config/hypr/lua/binds_data.lua\" ] "
            + "|| \"$HOME/.config/panacea/scripts/genbinds.sh\""]
    }
    Connections {
        target: cfgFile
        function onSaved() {
            root.runGenBinds();
            if (root.keyboardInputPending) {
                root.keyboardInputPending = false;
                pGenInput.running = false;
                pGenInput.running = true;
            }
        }
    }

    // ---------------------------------------------------------------- палитра
    // Темы не зависят от обоев: цвет всей оболочки задаёт выбранная тема, а
    // не картинка на столе. Тема «default» — то, что было раньше: фон чёрный,
    // а текст и акцент берутся из настроек, поэтому вручную выбранные цвета
    // никуда не деваются.
    readonly property var themes: Themes.list
    function themeOf(id) { return Themes.of(id); }
    readonly property var theme: themeOf(cfg.themeId)
    readonly property bool themeCustom: cfg.themeId === "default"
    // Единственный флаг на весь облик Nothing. Проверять cfg.themeId по строке
    // в двух десятках мест значило бы искать их все при переименовании темы.
    readonly property bool themeNothing: cfg.themeId === "nothing"
    // Флаг темы Material Design 3 (Material You)
    readonly property bool themeMaterial: cfg.themeId === "material3" || cfg.themeId === "material"
    readonly property string m3ColorMode: cfg.m3ColorMode || "wallpaper"
    readonly property string m3ManualColor: cfg.m3ManualColor || "#e08096"
    onThemeMaterialChanged: if (root.themeMaterial) root.updateMatugenTheme()
    onM3ColorModeChanged: if (root.themeMaterial) root.updateMatugenTheme()
    onM3ManualColorChanged: if (root.themeMaterial && root.m3ColorMode === "manual") root.updateMatugenTheme()

    FileView {
        id: matugenFile
        path: Quickshell.env("HOME") + "/.cache/panacea/matugen.json"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            matugenLoadTimer.restart();
        }
        onLoaded: root.loadMatugenColors()
    }

    Timer {
        id: matugenLoadTimer
        interval: 120
        repeat: false
        onTriggered: root.loadMatugenColors()
    }

    property var matugenColors: null

    function loadMatugenColors() {
        try {
            var raw = matugenFile.text();
            if (raw && raw.length > 20) {
                var j = JSON.parse(raw);
                if (j && j.colors) {
                    root.matugenColors = j.colors;
                    return;
                }
            }
        } catch(e) {}
    }

    property color mediaArtColor: "#3b82f6"
    property color mediaArtColor2: "#6366f1"
    Behavior on mediaArtColor  { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on mediaArtColor2 { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }

    readonly property bool isMonochromeArt: (root.mediaArtColor == "#ffffff" || (root.mediaArtColor && root.mediaArtColor.hslSaturation !== undefined && root.mediaArtColor.hslSaturation <= 0.08))

    // Material 3 Semantic Design Tokens (apoyados dinámicamente por matugen / Material You y sincronizados con música)
    readonly property color colM3Surface: (themeMaterial && musicIslandActive && root.mediaArtColor)
        ? (root.mediaArtColor.hslSaturation && root.mediaArtColor.hslSaturation > 0.08
           ? Qt.hsla(root.mediaArtColor.hslHue, Math.min(root.mediaArtColor.hslSaturation * 0.42, 0.32), 0.075, 0.98)
           : Qt.rgba(0.08, 0.08, 0.09, 0.98))
        : ((themeMaterial && matugenColors && matugenColors.surface && matugenColors.surface.dark)
           ? matugenColors.surface.dark.color : "#141218")

    readonly property color colM3SurfaceContainer: (themeMaterial && musicIslandActive && root.mediaArtColor)
        ? (root.mediaArtColor.hslSaturation && root.mediaArtColor.hslSaturation > 0.08
           ? Qt.hsla(root.mediaArtColor.hslHue, Math.min(root.mediaArtColor.hslSaturation * 0.38, 0.26), 0.125, 0.98)
           : Qt.rgba(0.12, 0.12, 0.14, 0.98))
        : ((themeMaterial && matugenColors && matugenColors.surface_container && matugenColors.surface_container.dark)
           ? matugenColors.surface_container.dark.color : "#211f26")

    readonly property color colM3SurfaceContainerHigh: (themeMaterial && musicIslandActive && root.mediaArtColor)
        ? (root.mediaArtColor.hslSaturation && root.mediaArtColor.hslSaturation > 0.08
           ? Qt.hsla(root.mediaArtColor.hslHue, Math.min(root.mediaArtColor.hslSaturation * 0.32, 0.20), 0.175, 0.98)
           : Qt.rgba(0.16, 0.16, 0.18, 0.98))
        : ((themeMaterial && matugenColors && matugenColors.surface_container_high && matugenColors.surface_container_high.dark)
           ? matugenColors.surface_container_high.dark.color : "#2b2930")

    readonly property color colM3OnPrimary: (themeMaterial && musicIslandActive && root.mediaArtColor)
        ? fgOn(root.mediaArtColor)
        : ((themeMaterial && matugenColors && matugenColors.on_primary && matugenColors.on_primary.dark)
           ? matugenColors.on_primary.dark.color : "#381e72")

    readonly property color colM3PrimaryContainer: (themeMaterial && musicIslandActive && root.mediaArtColor)
        ? Qt.rgba(root.mediaArtColor.r, root.mediaArtColor.g, root.mediaArtColor.b, 0.28)
        : ((themeMaterial && matugenColors && matugenColors.primary_container && matugenColors.primary_container.dark)
           ? matugenColors.primary_container.dark.color : (themeMaterial ? Qt.rgba(colOn.r, colOn.g, colOn.b, 0.28) : "#4f378b"))

    readonly property color colM3OnPrimaryContainer: (themeMaterial && musicIslandActive && root.mediaArtColor)
        ? root.mediaArtColor
        : ((themeMaterial && matugenColors && matugenColors.on_primary_container && matugenColors.on_primary_container.dark)
           ? matugenColors.on_primary_container.dark.color : (themeMaterial ? colOn : "#eaddff"))

    // Размер точки в числах Nothing. Считается от размера шрифта, а не задан
    // числом: человек двигает ползунок кегля в настройках, и точечные часы
    // должны расти вместе с остальными подписями, иначе остров расползается.
    //
    // Три ступени — высота цифры в пикселях, тем же числом, каким меряют
    // обычный текст. Считаются от кегля со сдвигом, а не долей от него:
    // рядом с цифрой всегда стоит подпись, и разница между ними должна
    // оставаться одинаковой, а не растягиваться вместе с ползунком.
    readonly property real dotHBig:   root.fontSize + 10   // часы в панели
    readonly property real dotHClock: root.fontSize - 1    // часы в острове
    readonly property real dotHSmall: root.fontSize - 3    // числа при значках
    readonly property real dotHTiny:  root.fontSize - 5    // сводка нагрузки

    // Цвет надписи поверх заливки акцентом. На светлом акценте белым по
    // белому не видно ничего — а на теме Nothing акцент именно белый.
    // Яркость по Rec. 709: зелёный глаз видит куда лучше синего, и среднее
    // арифметическое трёх каналов ошибается как раз на жёлтом и голубом.
    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.colBg : "#ffffff";
    }

    readonly property color colBg: {
        if (themeMaterial) {
            if (musicIslandActive && root.mediaArtColor) {
                var w = root.mediaArtColor;
                if (w.hslSaturation && w.hslSaturation > 0.08) {
                    return Qt.hsla(w.hslHue, Math.min(w.hslSaturation * 0.42, 0.32), 0.075, 0.98);
                }
                return Qt.rgba(0.08, 0.08, 0.09, 0.98);
            }
            if (matugenColors && matugenColors.surface && matugenColors.surface.dark) {
                return matugenColors.surface.dark.color;
            }
            return "#141218";
        }
        return (cfg && cfg.forceCustomColors && cfg.colBg) ? cfg.colBg : (theme ? theme.bg : "#000000");
    }

    readonly property color currentNotchBg: {
        if (root.themeMaterial && root.musicIslandActive) {
            var mode = root.cfg.notchMusicBgMode !== undefined ? root.cfg.notchMusicBgMode : 0;
            if (mode === 2) {
                // REGLA ESTRICTA R5: Bajo ninguna circunstancia el fondo es blanco plano
                if (root.isMonochromeArt) return Qt.rgba(0.08, 0.08, 0.09, 0.98);
                return root.effectiveWaveColor;
            }
            if (mode === 1) {
                if (root.isMonochromeArt) return Qt.rgba(0.12, 0.12, 0.14, 0.98);
                var w = root.effectiveWaveColor;
                return Qt.rgba(w.r * 0.28, w.g * 0.28, w.b * 0.28, 0.98);
            }
            // Modo 0: Tinte dinámico de portada armónico
            if (root.mediaArtColor) {
                var w0 = root.mediaArtColor;
                if (w0.hslSaturation && w0.hslSaturation > 0.08) {
                    return Qt.hsla(w0.hslHue, Math.min(w0.hslSaturation * 0.42, 0.32), 0.075, 0.98);
                }
            }
            return Qt.rgba(0.08, 0.08, 0.09, 0.98);
        }
        return root.colBg;
    }
    // у «default» или при включённом forceCustomColors цвета берутся из настроек
    readonly property color colFg:     (cfg && cfg.forceCustomColors && cfg.colFg)
                                       ? cfg.colFg
                                       : ((themeMaterial && matugenColors && matugenColors.on_surface && matugenColors.on_surface.dark)
                                          ? matugenColors.on_surface.dark.color
                                          : (themeCustom ? cfg.colFg : (theme ? theme.fg : "#ffffff")))
    readonly property color colMuted:  Qt.rgba(colFg.r, colFg.g, colFg.b, cfg.mutedAlpha)
    readonly property color colLine:   Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colHover:  Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colOn:     (cfg && cfg.forceCustomColors && cfg.colOn)
                                       ? cfg.colOn
                                       : ((themeMaterial && musicIslandActive && root.mediaArtColor)
                                          ? (root.isMonochromeArt ? "#ffffff" : root.mediaArtColor)
                                          : ((themeMaterial && matugenColors && matugenColors.primary && matugenColors.primary.dark)
                                             ? matugenColors.primary.dark.color
                                             : (themeCustom ? cfg.colOn : (theme ? theme.on : "#ffffff"))))
    readonly property color colOk:     theme.ok
    readonly property color colCrit:   (cfg && cfg.forceCustomColors && cfg.colBattCrit)
                                       ? cfg.colBattCrit
                                       : ((themeMaterial && matugenColors && matugenColors.error)
                                          ? matugenColors.error.dark.color
                                          : theme.crit)
    readonly property color colBattWarn: cfg.colBattWarn ? cfg.colBattWarn : "#ff9f0a"
    readonly property color colBattCrit: cfg.colBattCrit ? cfg.colBattCrit : "#ff453a"
    readonly property color colCharge:   cfg.colCharge   ? cfg.colCharge   : "#30D158"
    property color colPowerSaver: (cfg && cfg.colPowerSaver) ? cfg.colPowerSaver : "#1d65ff"
    property color colPowerBalanced: (cfg && cfg.colPowerBalanced) ? cfg.colPowerBalanced : "#ffffff"
    property color colPowerPerf: (cfg && cfg.colPowerPerf) ? cfg.colPowerPerf : "#ff453a"
    property color colBt: (cfg && cfg.colBt) ? cfg.colBt : (root.themeNothing ? root.colOn : "#0ea5e9")
    property color colWifi: (cfg && cfg.colWifi) ? cfg.colWifi : root.colOn
    property color colVox: (cfg && cfg.colVox) ? cfg.colVox : (root.themeNothing ? root.colCrit : "#60a5fa")
    property color colRec: (cfg && cfg.colRec) ? cfg.colRec : root.colCrit

    readonly property color powerProfileColor: {
        var p = (root.powerProfile || "balanced").toLowerCase();
        if (p === "power-saver" || p === "low-power") return root.colPowerSaver;
        if (p === "performance" || p === "max-power") return root.colPowerPerf;
        return root.colPowerBalanced;
    }

    function setPowerColor(mode, hex) {
        if (!hex || typeof hex !== "string") return;
        var m = (mode || "").toLowerCase();
        if (m === "power-saver" || m === "saver" || m === "low-power") {
            root.colPowerSaver = hex;
            if (root.cfg) root.cfg.colPowerSaver = hex;
        } else if (m === "balanced" || m === "balance") {
            root.colPowerBalanced = hex;
            if (root.cfg) root.cfg.colPowerBalanced = hex;
        } else if (m === "performance" || m === "perf" || m === "max-power") {
            root.colPowerPerf = hex;
            if (root.cfg) root.cfg.colPowerPerf = hex;
        }
        root.saveCfg();
    }

    readonly property color effectiveWaveColor: {
        var m = root.cfg.musicWaveColorMode !== undefined ? root.cfg.musicWaveColorMode : 0;
        if (root.isMonochromeArt) return "#ffffff";
        if (m === 0) return root.mediaArtColor;
        if (m === 1) return root.colOn;
        return root.colFg;
    }

    // Цвета состояний, которых в палитре темы нет. На теме Nothing цветного
    // выделения не бывает вовсе: смысл там несёт яркость, а не оттенок, и
    // одинокое зелёное или синее пятно среди чёрно-белого выглядит чужим.
    // Красный — единственное исключение, он значит «внимание», а не
    // украшение, и живёт в палитре как colCrit.
    //
    // tint() для тех цветов, под которые заводить строку в палитре не за
    // чем: они встречаются в одном-двух местах и означают ровно себя.
    function tint(c) { return root.themeNothing ? root.colFg : c; }
    // янтарный «на паузе» и «осторожно» — он встречается часто
    readonly property color colWarn: root.tint("#fbbf24")
    readonly property string fontFam:  cfg.fontFam
    // текстовый шрифт и шрифт заголовков; пустое значение — общий fontFam
    readonly property string fontBody:    cfg.fontBody || cfg.fontFam
    readonly property string fontDisplay: cfg.fontDisplay || cfg.fontFam
    readonly property int fontSize:    cfg.fontSize
    readonly property int iconSize:    cfg.iconSize
    // шаг отступов и малый радиус: из них считается геометрия карточек
    readonly property int unit:        cfg.spacingUnit
    readonly property int radiusS:     cfg.smallRadius

    // ---------------------------------------------------------------- метрики
    readonly property int pillH: cfg.pillH      // высота свёрнутой пилюли

    // Где висит остров. Раскрытие всегда идёт к центру экрана: сверху —
    // вниз, снизу — вверх, слева — вправо, справа — влево. Это выходит само
    // собой, потому что капсула прижата к своей кромке и растёт от неё.
    readonly property string pillPos: {
        var p = String(cfg.pillPos || "top");
        return (p === "bottom" || p === "left" || p === "right") ? p : "top";
    }
    readonly property bool pillAtTop:    pillPos === "top"
    readonly property bool pillAtBottom: pillPos === "bottom"
    readonly property bool pillAtLeft:   pillPos === "left"
    readonly property bool pillAtRight:  pillPos === "right"
    // у боковых положений капсула стоит по центру высоты, а не у кромки экрана
    readonly property bool pillSide: pillAtLeft || pillAtRight

    // ------------------------------------------------- перенос острова мышью
    // Тумблер в настройках; тянут за полосу над часами в раскрытых быстрых
    // настройках. У кромки остров цепляется к её центру, в пустоте —
    // возвращается на место: цепляться там не за что.
    property bool  pillDragging: false
    property real  dragDX: 0            // смещение от родного места, px
    property real  dragDY: 0
    // кромка, к которой прицепится остров, если отпустить сейчас
    property string dragEdge: ""

    // Кромку выбираем по тому, к какой ближе центр капсулы, и только если он
    // уже в её полосе — четверть экрана. Иначе отпускать некуда.
    function edgeAt(cx, cy) {
        var w = root.width, h = root.height;
        var dTop = cy, dBottom = h - cy, dLeft = cx, dRight = w - cx;
        var m = Math.min(dTop, dBottom, dLeft, dRight);
        if (m > Math.min(w, h) * 0.25) return "";
        if (m === dTop)    return "top";
        if (m === dBottom) return "bottom";
        if (m === dLeft)   return "left";
        return "right";
    }

    function dropPill() {
        var edge = root.dragEdge;
        root.pillDragging = false;
        root.dragEdge = "";
        // смещение снимаем с анимацией: остров едет либо к новой кромке,
        // либо обратно на своё место
        root.dragDX = 0;
        root.dragDY = 0;
        if (edge.length && edge !== root.pillPos) {
            cfg.pillPos = edge;
            root.saveCfg();
        }
        // Сворачиваемся и не раскрываемся, пока курсор не уйдёт и не вернётся.
        // У новой кромки раскладка страницы другая, и раскрытая панель
        // переезжала вместе с островом, разъезжаясь на ходу. Так остров сначала
        // спокойно встаёт на место, а панель открывается уже наведением.
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    // Где именно сейчас стоит капсула. Нужно карусели обоев: она начинает
    // разворот ровно из острова, поэтому ей нужны его координаты.
    property real pillRectX: 0
    property real pillRectY: 0
    property real pillRectW: 0
    property real pillRectH: 0
    readonly property int panelW: cfg.panelW    // ширина раскрытой панели
    readonly property int gap: 5                // зазор между пилюлей и окнами
    // радиус примыкания к кромке; вне режима выреза примыкать нечему
    readonly property int cornerR: cfg.notchMode ? cfg.notchFlare : 0

    // Единая кривая: панель «перетекает», а не прыгает.
    // Длительности задаёт вкладка Motion. «Reduce motion» обнуляет их все
    // разом: движение исчезает, а не ускоряется.
    readonly property bool noMotion: cfg.reduceMotion
    readonly property int animMs:   noMotion ? 0 : cfg.animMove
    readonly property int animFade: noMotion ? 0 : cfg.animFade
    readonly property int animHover: noMotion ? 0 : cfg.animHover
    // перелёт осциллятора в долях: 79 % → 0.79 сверх цели
    readonly property real animBounce: noMotion ? 0 : cfg.animBounce / 100
    // перелёт для кривых OutBack: 100 % ползунка — это заметный, но ещё не
    // резиновый отскок, поэтому доля умножается, а не берётся как есть
    readonly property real easeOvershoot: animBounce * 1.7
    readonly property int animFast: Math.round(animMs * 0.52)
    // изменение содержимого (список приложений, новая сеть) — коротко и резко
    readonly property int animQuick: Math.round(animMs * 0.48)

    // true только пока идёт раскрытие/схлопывание или смена страницы.
    // Нужно, чтобы рост списка не ехал по длинной кривой раскрытия.
    property bool morphing: false
    onExpandedChanged: {
        morphing = true;
        morphTimer.restart();
        if (expanded) {
            root.refreshLoad();
            if (root.cfg.uiSounds !== false) {
                if (root.page === "settings") {
                    root.playSound("settings_open");
                } else if (root.cfg.islandPopSound !== false && root.page !== "main" && root.page !== "launcher" && root.page !== "islandmusic") {
                    // Silenciar apertura de Super+M (islandmusic), Super+Z (main) y Super+Space (launcher)
                    root.playSound("island_pop");
                }
            }
        } else {
            // Sonido al cerrar el menú de ajustes Super + I (no interrumpir si se disparó toast de teclado)
            if (root.page === "settings" && root.cfg.uiSounds !== false && !root.kbdLightToastShown) {
                root.playSound("settings_close");
            }
            // панель закрылась — показываем карточки, накопившиеся за это время
            toastPump.restart();
        }
    }
    onPageChanged: {
        morphing = true;
        morphTimer.restart();
        if (root.expanded && root.page === "settings" && root.cfg.uiSounds !== false) {
            root.playSound("settings_open");
        }
    }
    // Держим дольше самой анимации: высота страницы приходит с задержкой
    // в кадр-другой, и без запаса второй шаг ехал бы по «быстрой» кривой.
    Timer { id: morphTimer; interval: root.animMs + 140; onTriggered: root.morphing = false }

    // ------------------------------------------------------------ состояние UI
    property bool expanded: false
    // "main" | "wifi" | "bt" | "battery" | "launcher"
    // main    — плитки Wi-Fi / Bluetooth / звук, трек и запись
    // battery — режимы питания и состояние заряда
    // Отдельной страницы плеера нет: играющий трек с кнопками и полосами
    // живёт карточкой на главной, там же, где всё остальное.
    property string page: "main"
    // что показывает медиаплеер (страница "media")
    property string mediaPath: ""
    // высота полотна плеера: большую часть экрана, но не впритык
    readonly property int mediaStageH: Math.round((screen ? screen.height : 1080) * 0.58)
    // Плеер живёт в Loader и снаружи по id не виден, поэтому режим кропа
    // держим здесь: кнопка и горячая клавиша дёргают один и тот же флаг.
    property bool mediaCrop: false
    function mediaCropToggle() { root.mediaCrop = !root.mediaCrop; }

    // ---------------------------------------------------- добавление обоев
    // «+» на странице обоев открывает проводник в режиме выбора: следующая
    // выбранная картинка не откроется в плеере, а уедет на страницу обоев,
    // где её просят назвать и сохранить.
    property bool   wallpaperPickMode: false
    property string wallpaperPick: ""       // путь выбранной, ждёт имени
    function startWallpaperPick() {
        wallsOpen = false;
        wallpaperPickMode = true;
        togglePage("files");
    }
    function finishWallpaperPick(path) {
        wallpaperPickMode = false;
        collapse();
        wallpaperPick = path;
        openWalls();
    }
    function cancelWallpaperPick() { wallpaperPick = ""; }

    function openMedia(path) {
        if (!cfg.featMedia) return;
        root.mediaCrop = false;
        root.mediaPath = path;
        pageResetTimer.stop();
        root.page = "media";
        root.expanded = true;
        root.holdOpen = true;
    }

    // ------------------------------------------------ полноэкранные окна
    // Пилюля живёт в слое Overlay и по умолчанию рисуется поверх всего.
    // Пока активное окно развёрнуто на весь экран, прячем её целиком:
    // сочетания клавиш при этом работают — по ним панель раскрывается
    // и окно снова показывается.
    property bool fullscreenActive: Compositor.isNiri ? Compositor.isFullscreen : false
    property bool braveOnScreen: false
    property bool braveDodgeActive: false
    property bool manualHidden: false
    property string activeWindowClass: ""
    property string activeWindowTitle: ""

    function activeWindowGlyph(cls) {
        var c = (cls || "").toLowerCase();
        if (c.indexOf("brave") >= 0 || c.indexOf("chrom") >= 0 || c.indexOf("firefox") >= 0) return "󰖟";
        if (c.indexOf("ai") >= 0 || c.indexOf("chat") >= 0) return "󰚩";
        if (c.indexOf("kitty") >= 0 || c.indexOf("foot") >= 0 || c.indexOf("term") >= 0) return "󰆍";
        if (c.indexOf("code") >= 0 || c.indexOf("cursor") >= 0) return "󰨞";
        if (c.indexOf("spotify") >= 0) return "󰓇";
        if (c.indexOf("thunar") >= 0 || c.indexOf("files") >= 0 || c.indexOf("nautilus") >= 0) return "󰉋";
        return "󰘚";
    }

    function formatAppTitle(cls, title) {
        var c = (cls || "").trim();
        if (!c.length) return "Escritorio";
        var name = c.charAt(0).toUpperCase() + c.slice(1);
        if (name.length > 18) name = name.slice(0, 17) + "…";
        return name;
    }

    Timer {
        id: braveReturnTimer
        interval: root.cfg.braveReturnDelay !== undefined ? root.cfg.braveReturnDelay : 1000
        repeat: false
        onTriggered: {
            root.braveDodgeActive = false;
            braveDodgePollTimer.stop();
        }
    }

    Process {
        id: pWindowProbe
        running: !Compositor.isNiri
        command: ["python3", "-c",
            "import json, subprocess\n" +
            "try:\n" +
            "  ws = json.loads(subprocess.check_output(['hyprctl','activeworkspace','-j'])).get('id',1)\n" +
            "  clients = json.loads(subprocess.check_output(['hyprctl','clients','-j']))\n" +
            "  brave = any('brave' in (c.get('class','') or '').lower() and c.get('workspace',{}).get('id')==ws and not c.get('hidden',False) for c in clients)\n" +
            "  act = json.loads(subprocess.check_output(['hyprctl','activewindow','-j']))\n" +
            "  fs = act.get('fullscreen',0) > 0\n" +
            "  c_name = act.get('initialClass','') or act.get('class','') or ''\n" +
            "  c_title = act.get('title','') or ''\n" +
            "  print(f'{1 if fs else 0} {1 if brave else 0} {c_name}:::{c_title}')\n" +
            "except Exception:\n" +
            "  print('0 0 :::')\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!Compositor.isNiri) {
                    var raw = text.trim();
                    var sepIdx = raw.indexOf(":::");
                    var winTitle = "";
                    if (sepIdx >= 0) {
                        winTitle = raw.substring(sepIdx + 3).trim();
                        raw = raw.substring(0, sepIdx).trim();
                    }
                    var parts = raw.split(" ");
                    if (parts.length >= 2) {
                        root.fullscreenActive = (parseInt(parts[0]) > 0);
                        root.braveOnScreen = (parseInt(parts[1]) > 0);
                        root.activeWindowClass = parts.length >= 3 ? parts.slice(2).join(" ") : "";
                        root.activeWindowTitle = winTitle;
                        if (!root.braveOnScreen && root.braveDodgeActive) {
                            braveReturnTimer.stop();
                            root.braveDodgeActive = false;
                            braveDodgePollTimer.stop();
                        }
                    }
                }
            }
        }
    }
    Timer { id: fsProbe; interval: 120; onTriggered: if (!Compositor.isNiri) pWindowProbe.running = true }
    Timer {
        interval: 3000; running: !Compositor.isNiri; repeat: true; triggeredOnStart: true
        onTriggered: pWindowProbe.running = true
    }

    Process {
        id: pCursorCheck
        running: false
        command: ["hyprctl", "cursorpos"]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.split(",");
                if (parts.length === 2) {
                    var cx = parseInt(parts[0].trim());
                    var cy = parseInt(parts[1].trim());
                    var screenW = root.screen ? root.screen.width : 1920;
                    var notchW = capsule.width + 40;
                    var minX = (screenW - notchW) / 2;
                    var maxX = (screenW + notchW) / 2;
                    var outside = (cy > (root.pillH + 16) || cx < minX || cx > maxX);
                    if (outside) {
                        if (!braveReturnTimer.running) {
                            braveReturnTimer.restart();
                        }
                    } else {
                        if (braveReturnTimer.running) {
                            braveReturnTimer.stop();
                        }
                    }
                }
            }
        }
    }
    Timer {
        id: braveDodgePollTimer
        interval: 70
        repeat: true
        running: root.braveDodgeActive
        onTriggered: {
            if (!pCursorCheck.running) {
                pCursorCheck.running = true;
            }
        }
    }

    Connections {
        target: Hyprland
        enabled: !Compositor.isNiri
        function onRawEvent(event) {
            var n = String(event.name);
            if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                || n === "closewindow" || n === "openwindow" || n === "workspace"
                || n === "focusedmon")
                fsProbe.restart();
            // перезагрузка конфига Hyprland стирает всё, что мы наприменяли
            if (n === "configreloaded") monReplayTimer.restart();
        }
    }
    // Перезагрузка конфига стирает не только настройки мониторов: скорость
    // указателя, разгон и шейдер насыщенности живут там же и уезжают вместе
    // с ними. Накатываем всё своё одним заходом, иначе после любого
    // hyprctl reload мышь и цвет молча возвращались к заводским.
    Timer {
        id: monReplayTimer
        interval: 400
        onTriggered: {
            root.monReplay();
            root.applyInput();
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
        }
    }

    // Один обработчик на сигнал: QML второго не допускает, поэтому всё, что
    // должно случиться при запуске, собрано здесь.
    Component.onCompleted: {
        root.loadMatugenColors();
        root.refreshLoad();
        fsProbe.restart();
        syncGreeterLocale();
        monReplayTimer.restart();
        syncGreeterTheme();
        syncTermTheme();
        root.cornersOn = root.cornersWanted;
        // Первое заполнение списка столов: дальше его ведёт onWsRawChanged, а
        // тот срабатывает только на изменение — стартовое значение он бы
        // пропустил, и до первого переключения точек не было бы вовсе.
        root.wsList = root.wsRaw;
    }

    // ------------------------------------------------- перетаскивание файлов
    // Источник живёт прямо в окне, а не внутри страницы: панель во время
    // перетаскивания сворачивается, её содержимое уничтожается, и элемент
    // изнутри утащил бы за собой начатый drag.
    Item {
        id: fileDrag
        width: 1
        height: 1
        visible: false

        property string uri: ""

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": fileDrag.uri,
                          "text/plain": fileDrag.uri.replace("file://", "") })
    }
    Timer {
        id: fileDragStart
        interval: 90        // даём панели уехать вниз, потом начинаем drag
        onTriggered: fileDrag.Drag.active = true
    }

    // ------------------------------------------------------ обзор столов
    // Для превью нужны две вещи: геометрия окна (её знает Hyprland) и
    // wayland-хэндл (по нему ScreencopyView берёт живой кадр). Оба лежат
    // на HyprlandToplevel, поэтому собираем их в один список.
    property bool overviewOpen: false
    function openOverview() {
        if (Compositor.isNiri) {
            Compositor.refresh();
        } else {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
        root.overviewOpen = true;
    }
    function closeOverview() { root.overviewOpen = false; }

    // Переход на стол. С Lua-конфигом Hyprland разбирает строку запроса как
    // Lua-код, и привычное "workspace 2" валится синтаксической ошибкой —
    // нужен настоящий диспетчер. На обычном конфиге работает старая форма.
    function gotoWorkspace(id) {
        if (Compositor.isNiri) {
            Compositor.focusWorkspace(id);
        } else if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        } else {
            Hyprland.dispatch("workspace " + id);
        }
    }
    function toggleOverview() {
        if (root.overviewOpen) closeOverview(); else openOverview();
    }

    // ------------------------------------------------------------- клавиши
    // Список сочетаний уехал из настроек в своё окно: их правят редко и
    // подолгу, список длинный, а держать его пятой вкладкой значило каждый раз
    // растягивать окно настроек под самый большой раздел.
    property bool keysWindowOpen: false
    function toggleKeysWindow() { root.keysWindowOpen = !root.keysWindowOpen; }
    function closeKeysWindow() { root.keysWindowOpen = false; }

    // ------------------------------------------------------------------ обои
    // Карусель обоев — отдельный полноэкранный слой, как обзор столов:
    // картинку надо видеть большой, а в пилюле для этого нет места.
    property bool wallsOpen: false
    function openWalls() {
        if (!cfg.featThemes) return;
        collapse();
        root.wallsOpen = true;
        // список обновится в фоне; на экране пока прежний, а не пустота
        root.refreshWalls();
    }
    function closeWalls() { root.wallsOpen = false; }

    // Список обоев держим здесь и читаем заранее: карусель должна открываться
    // уже с картинками. Пока список жил внутри неё, первые полсекунды на
    // экране висело «обоев не найдено».
    property var wallList: []
    property bool wallListReady: false
    Process {
        id: pWallList
        command: ["sh", "-c", root.scriptDir + "/themes.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 5) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],
                        wActive: p[2] === "yes",
                        wOwn:    p[3] === "yes",
                        wPath:   p[4]
                    });
                }
                root.wallList = rows;
                root.wallListReady = true;
            }
        }
    }
    // Миниатюра текущих обоев: макет рабочего стола в настройках показывает
    // именно её, а не условный градиент — иначе по макету не поймёшь, как
    // остров будет читаться на своём фоне.
    readonly property string currentWallThumb: {
        for (var i = 0; i < wallList.length; i++) {
            if (wallList[i].wActive) return wallList[i].wThumb;
        }
        return "";
    }

    function refreshWalls() {
        pWallList.running = false;
        pWallList.running = true;
        root.refreshLiveWalls();
    }

    // ------------------------------------------------------- живые обои
    // Видео вместо картинки на фоне. Список и постеры готовит
    // hypr/scripts/live_wallpaper.sh, играет mpvpaper.
    property var liveList: []
    property bool liveListReady: false
    property string liveDir: ""

    Process {
        id: pLiveDir
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "dir"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.liveDir = text.trim() }
    }
    Process {
        id: pLiveList
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 4) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],          // постер; пусто, пока не готов
                        wActive: p[2] === "yes",
                        wOwn:    true,          // живые обои всегда свои
                        wPath:   p[3]
                    });
                }
                root.liveList = rows;
                root.liveListReady = true;
            }
        }
    }
    function refreshLiveWalls() {
        pLiveList.running = false;
        pLiveList.running = true;
    }
    // папка живых обоев в проводнике: складывать видео надо именно туда
    function openLiveFolder() {
        if (root.liveDir.length === 0) return;
        root.closeWalls();
        root.openFilesAt(root.liveDir);
    }
    Timer {
        // не на самом старте: при входе в систему и без нас есть чем заняться
        interval: 4000
        running: true
        onTriggered: root.refreshWalls()
    }
    function toggleWalls() {
        if (root.wallsOpen) closeWalls(); else openWalls();
    }

    readonly property var overviewToplevels: {
        var out = [];
        if (!root.overviewOpen) return out;
        if (Compositor.isNiri) return Compositor.toplevels;
        var all = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            if (!t) continue;
            var o = t.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (o.hidden || o.workspace === undefined) continue;
            out.push({
                wayland: t.wayland,
                geo: {
                    x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1],
                    ws: o.workspace.id, cls: String(o.initialClass || o.class || "")
                }
            });
        }
        return out;
    }

    // Кто-то из окон проводника изменил файлы — остальным пора перечитать
    // свой список: они смотрят на ту же файловую систему.
    signal filesChanged()

    // fromWindow — тащат из отдельного окна проводника: пилюлю трогать не надо
    // и ждать её уезда тоже, перетаскивание начинается сразу.
    function startFileDrag(path, fromWindow) {
        fileDrag.uri = "file://" + path;
        if (fromWindow) { fileDrag.Drag.active = true; return; }
        root.collapse();
        fileDragStart.restart();
    }

    // Высота списка в проводнике фиксирована: иначе панель прыгала на каждой
    // смене папки, подстраиваясь под число файлов.
    readonly property int filesListH: Math.round((screen ? screen.height : 1080) * 0.64)

    // последняя папка проводника — чтобы он открывался там, где закрыли
    property string filesDir: Quickshell.env("HOME")
    // Иконка трея, чьё контекстное меню сейчас открыто (страница "traymenu").
    property var trayMenuItem: null
    // пока вводят пароль или открыт лаунчер, панель не закрывается по уходу мыши
    property bool holdOpen: false
    // клавиатуру окно получает уже после загрузки страницы — возвращаем
    // фокус содержимому, иначе стрелки и Enter уходят в пустоту
    onHoldOpenChanged: if (holdOpen) refocusTimer.restart()
    Timer {
        id: refocusTimer
        interval: 60
        onTriggered: if (contentLoader.item) contentLoader.item.forceActiveFocus()
    }

    readonly property bool launcherOpen: expanded && page === "launcher"

    function collapse() {
        expanded = false;
        holdOpen = false;
        weatherDetailsOpen = false;
        pageResetTimer.restart();
    }
    Timer {
        id: pageResetTimer
        interval: root.animMs + 40
        onTriggered: if (!root.expanded) { root.page = "main"; root.trayMenuItem = null; root.musicIslandReturnPage = ""; }
    }

    // Открыть страницу закреплённо; повторный вызов той же страницы закрывает.
    // Какая функция отвечает за страницу. Пустая строка — страница всегда есть
    // (главная, календарь-из-часов и т.п. проверяются отдельно).
    function pageEnabled(name) {
        switch (name) {
            case "launcher":  return cfg.featLauncher;
            case "wifi":      return cfg.featWifi;
            case "bt":        return cfg.featBluetooth;
            case "clip":      return cfg.featClipboard;
            case "notif":     return cfg.featNotifications;
            case "cal":       return cfg.featCalendar;
            case "record":    return cfg.featRecord;
            case "files":     return cfg.featFiles;
            case "media":     return cfg.featMedia;
            case "vault":     return cfg.featVault;
            case "vaultsave": return cfg.featVault;
            case "audio":     return cfg.featAudio;
            case "power":     return cfg.featPowermenu;
            default:          return true;   // main, settings, auth
        }
    }

    // ------------------------------------------------- проводник отдельно
    // С включённой настройкой проводник перестаёт быть страницей пилюли и
    // становится обычным окном: Hyprland сам его тайлит, оно остаётся на
    // своём рабочем столе и переносится между ними как любое другое. Пилюля
    // при этом не раскрывается и остаётся в обычном виде.
    // Окон может быть сколько угодно: Super+E в оконном режиме каждый раз
    // открывает ещё одно, как любой нормальный проводник. Закрывается каждое
    // само по себе — по крестику или Esc внутри него.
    property int filesWindowSeq: 0
    ListModel { id: filesWindows }

    function openFilesWindow(startDir) {
        root.filesWindowSeq++;
        filesWindows.append({ wid: root.filesWindowSeq,
                              startDir: String(startDir || "") });
    }

    // Открыть проводник сразу в нужной папке — например в каталоге живых
    // обоев из карусели. В оконном режиме это новое окно, иначе страница
    // пилюли, которая читает каталог при загрузке.
    property string filesStartDir: ""
    function openFilesAt(path) {
        var p = String(path || "");
        if (p.length === 0) return;
        if (cfg.filesWindow) { root.openFilesWindow(p); return; }
        root.filesStartDir = p;
        if (root.page === "files" && root.expanded) root.collapse();
        root.togglePage("files");
    }
    function closeFilesWindow(wid) {
        for (var i = 0; i < filesWindows.count; i++) {
            if (filesWindows.get(i).wid !== wid) continue;
            filesWindows.remove(i);
            return;
        }
    }

    // Открыть подстраницу и закрепить панель. Раньше страница батареи,
    // сетей или устройств открывалась простым присваиванием page, панель
    // оставалась незакреплённой и захлопывалась, стоило увести курсор —
    // до списка было не дотянуться. Возврат — Esc или кнопка «назад».
    function openSub(name) {
        root.dismissAllSystemToasts();
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }

    function togglePage(name) {
        if (!pageEnabled(name)) return;   // выключено установщиком — молчим
        // проводник в оконном режиме пилюлю не трогает вовсе
        if (name === "files" && cfg.filesWindow) { openFilesWindow(); return; }
        manualHidden = false;
        if (expanded && page === name) { collapse(); return; }
        root.dismissAllSystemToasts();
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }
    function toggleMusicIsland() {
        if (expanded && page === "islandmusic") {
            collapse();
        } else {
            openMusicIsland();
        }
    }
    property string musicIslandReturnPage: ""
    function openMusicIsland(fromPage) {
        root.dismissAllSystemToasts();
        musicIslandReturnPage = fromPage || "";
        manualHidden = false;
        pageResetTimer.stop();
        page = "islandmusic";
        expanded = true;
        holdOpen = true;
    }
    function openLauncher() {
        manualHidden = false;
        if (!cfg.featLauncher) return;
        pageResetTimer.stop();
        page = "launcher";
        expanded = true;
        holdOpen = true;
    }
    function closeLauncher() { collapse(); }
    function toggleLauncher() {
        if (launcherOpen) closeLauncher(); else openLauncher();
    }

    // Агенты открываются из лаунчера, как приложение, — своей строкой в общем
    // списке. Отдельной кнопки в быстрых настройках нет намеренно: туда ходят
    // за переключателями, а это справка, к которой обращаются, когда о ней
    // вспомнили. Искать её там же, где всё остальное, — короче, чем помнить
    // ещё одно сочетание клавиш.
    // Растёт на каждое открытие: вид агентов на это подписан и перечитывает
    // цифры. Само создание вида на это не годится — пока страница не сброшена
    // на главную, повторное открытие переиспользует уже созданный.
    property int agentsEpoch: 0
    function openAgents() {
        root.agentsEpoch++;
        togglePage("agents");
    }

    // ----------------------------------------------------- стоп-кадр экрана
    // Путь к снимку всего экрана, который scripts/shot.sh показывает поверх
    // всего, пока идёт выделение области. Пусто — слоя нет.
    property string freezeShot: ""

    // Логические границы всей раскладки экранов (минимальный прямоугольник,
    // накрывающий все мониторы). По ним слой стоп-кадра растягивает снимок,
    // снятый в физическом разрешении, — чтобы на экране с масштабом он лёг
    // один в один, а не куском в углу.
    readonly property rect freezeBounds: {
        var xs = Quickshell.screens;
        if (!xs || xs.length === 0) return Qt.rect(0, 0, 0, 0);
        var minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
        for (var i = 0; i < xs.length; i++) {
            var s = xs[i];
            minx = Math.min(minx, s.x);
            miny = Math.min(miny, s.y);
            maxx = Math.max(maxx, s.x + s.width);
            maxy = Math.max(maxy, s.y + s.height);
        }
        return Qt.rect(minx, miny, maxx - minx, maxy - miny);
    }

    // Скриншот кладётся в буфер обмена, и по экрану этого не видно: рамка
    // выделения пропала — и всё. Уведомление здесь, а не в скрипте, потому
    // что текст переводится вместе с остальной оболочкой.
    Process { id: pShotSay }
    function shotCopied(path: string): void {
        // Значком берём сам снимок: уведомление показывает, что именно сняли,
        // и промах по рамке видно, не открывая файл.
        var name = String(path).split("/").pop();
        pShotSay.command = ["notify-send", "-a", "Panacea", "-i", String(path),
                            "-h", "int:transient:1",
                            root.tr("Скриншот"),
                            root.tr("В буфере обмена") + " · " + name];
        pShotSay.running = false;
        pShotSay.running = true;
        root.playSound("screenshot");
    }

    // Настройки — единственная страница, которая отрывается от верхней кромки
    // и встаёт по центру экрана: содержимого много, у верха оно было тесным.
    // Страницы, которые отрываются от верхней кромки и встают по центру:
    // содержимого много, у верха оно тесное.
    // Темы отсюда убраны: список стал узким и живёт прямо под пилюлей,
    // как сети и устройства. Отдельное окно посреди экрана для выбора обоев
    // было слишком тяжёлым жестом.
    readonly property bool settingsMode:
        expanded && (page === "settings"
                     || page === "files" || page === "media")

    // Вкладка «Клавиши» раскладывается в две колонки, поэтому окно шире:
    // вертикальный список не влезал и уезжал за нижнюю кромку экрана.
    property bool wideSettings: false
    readonly property int settingsW: {
        var want = page === "files" ? Math.round((screen ? screen.width : 1920) * 0.78)
                 : page === "media" ? Math.round((screen ? screen.width : 1920) * 0.72)
                 : (wideSettings ? 1380 : 1200);
        var lim = (screen ? screen.width : 1920) - 80;
        return Math.min(want, lim);
    }

    // ------------------------------------------------------------ смена темы
    // hyprpaper меняет обои мгновенно и без перехода. Поэтому снимок старых
    // обоев остаётся висеть поверх экрана и плавно тает — снизу к этому
    // моменту уже новые, и получается честный кроссфейд без смены бэкенда.
    property string themeFadeWall: ""
    property bool   themeFading: false

    FileView {
        id: curWallFile
        path: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (root.themeMaterial && (root.m3ColorMode === "wallpaper" || !root.m3ColorMode)) {
                root.updateMatugenTheme();
            }
        }
    }

    Process {
        id: pMatugen
        command: ["bash", Quickshell.env("HOME") + "/.config/panacea/scripts/matugen_update.sh", "wallpaper"]
        onExited: (code, status) => {
            if (code === 0) {
                matugenFile.reload();
                matugenLoadTimer.restart();
            }
        }
    }

    Timer {
        id: matugenDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (pMatugen.running) {
                pMatugen.running = false;
                matugenRestartTimer.restart();
            } else {
                pMatugen.running = true;
            }
        }
    }

    Timer {
        id: matugenRestartTimer
        interval: 40
        repeat: false
        onTriggered: {
            pMatugen.running = true;
        }
    }


    function updateMatugenTheme() {
        if (!root.themeMaterial) return;
        var mode = root.m3ColorMode || "wallpaper";
        var script = Quickshell.env("HOME") + "/.config/panacea/scripts/matugen_update.sh";
        var cmd = ["bash", script, mode];
        if (mode === "manual") {
            cmd.push(root.m3ManualColor || "#e08096");
        } else if (mode === "music") {
            var colHex = "";
            if (root.mediaArtColor) {
                var cStr = root.mediaArtColor.toString();
                if (cStr.length === 9 && cStr.startsWith("#")) {
                    colHex = "#" + cStr.slice(3);
                } else {
                    colHex = cStr;
                }
            }
            var art = root.mediaArtLocal ? String(root.mediaArtLocal).replace(/^file:\/\//, "") : "";
            cmd.push(colHex.length > 0 ? colHex : art);
        } else {
            var m = /^\$wallpaper\s*=\s*(.+)$/m.exec(curWallFile.text() || "");
            if (m && m[1]) {
                cmd.push(String(m[1]).trim());
            }
        }
        pMatugen.command = cmd;
        matugenDebounceTimer.restart();
    }

    function startThemeFade() {
        if (root.themeMaterial && (root.m3ColorMode === "wallpaper" || !root.m3ColorMode)) {
            root.updateMatugenTheme();
        }
        var m = /^\$wallpaper\s*=\s*(.+)$/m.exec(curWallFile.text() || "");
        if (!m) return;
        root.themeFadeWall = "file://" + String(m[1]).trim();
        root.themeFading = true;
    }
    function endThemeFade() { root.themeFading = false; }

    // ------------------------------------------------------------------ медиа
    // «Липкий» текущий плеер: пока выбранный плеер ещё существует, держимся
    // за него, даже когда на паузе он перестаёт быть «играющим». Иначе на
    // паузе выбор перескакивал на другой MPRIS-источник (например, вкладку
    // браузера без обложки) — и обложка/название мигали.
    // Прежний выбор держим в обычном объекте, а не в свойстве: привязка
    // player читает его и тут же сама в него пишет. Со свойством это был
    // цикл привязки — Qt ругался в лог и пересчитывал выбор на каждом кадре
    // проигрывания. Поле внутри объекта зависимости не создаёт.
    readonly property var stickyBox: ({ p: null })
    readonly property var player: {
        var list = Mpris.players ? Mpris.players.values : [];
        var playing = null, any = null, stickyAlive = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p) continue;
            if (!any) any = p;
            if (p === root.stickyBox.p) stickyAlive = p;
            if (p.isPlaying && !playing) playing = p;
        }
        // играющий побеждает; иначе прежний, если он ещё жив; иначе любой
        return playing || stickyAlive || any;
    }
    onPlayerChanged: { if (player) root.stickyBox.p = player; refreshMediaArt(); }
    readonly property bool mediaActive:
        cfg.featPlayer
        && player !== null && player !== undefined
        && String(player.trackTitle).trim().length > 0

    // Обложка мигала: на паузе/возобновлении MPRIS на миг отдаёт пустой
    // trackArtUrl, и картинка в капсуле пропадала. Запоминаем последнюю
    // непустую обложку текущего трека и показываем её, пока трек не сменился.
    property string mediaArt: ""
    property string mediaArtLocal: ""
    readonly property string effectiveMediaArt:
        mediaArtLocal.length > 0 ? mediaArtLocal : mediaArt
    property string mediaArtTrack: ""

    function refreshMediaArt() {
        if (!player) { return; }
        var title = String(player.trackTitle || "");
        var art = String(player.trackArtUrl || "");
        // Пустое название на миг проскакивает при паузе — такие «полукадры»
        // игнорируем, чтобы не сбросить обложку в ноту.
        if (title.length === 0) return;
        if (title !== root.mediaArtTrack) {
            root.mediaArtTrack = title;
            root.mediaArtLocal = "";
            if (art.length > 0 && art !== root.mediaArt) {
                root.mediaArt = art;
            } else {
                root.updateArtColor(art);
            }
        } else if (art.length > 0 && art !== root.mediaArt) {
            root.mediaArt = art;
        }
    }
    readonly property bool mediaPlaying:
        root.mediaActive && root.player && root.player.isPlaying

    property bool musicIslandActive: root.mediaPlaying
    property bool musicNotchForceNormal: false
    property bool musicNotchForceMusic: false
    property int musicCenterMode: root.cfg.musicCenterMode !== undefined ? root.cfg.musicCenterMode : 3   // 0 = clock, 1 = battery, 2 = clock+battery, 3 = full normal, 4 = none
    function rotateMusicCenter(): void {
        root.musicCenterMode = (root.musicCenterMode + 1) % 5;
        root.cfg.musicCenterMode = root.musicCenterMode;
        root.saveCfg();
    }
    function setMusicCenterMode(m: int): void {
        root.musicCenterMode = m;
        root.cfg.musicCenterMode = m;
        root.saveCfg();
    }
    property bool mediaLyricsOpen: false
    function toggleMediaLyrics(): void {
        root.mediaLyricsOpen = !root.mediaLyricsOpen;
    }
    onMediaLyricsOpenChanged: {
        var it = contentLoader.item;
        if (it && it.implicitHeight > 40) {
            var delta = (root.page === "islandmusic" || contentLoader.sourceComponent === islandMusicComp) ? ((root.cfg.islandLyricsHeight || 240) + 14) : 216; // ? 254 : 216
            if (!capsule.lyricsAnimating || capsule.baseLyricsContentH <= 40) {
                capsule.baseLyricsContentH = root.mediaLyricsOpen ? (it.implicitHeight + 30) : Math.max(220, it.implicitHeight + 30 - delta);
            }
            capsule.lyricsAnimating = true;
            lyricsAnimTimer.restart();
            contentSettle.stop();
            var target = root.mediaLyricsOpen
                ? (capsule.baseLyricsContentH + delta)
                : capsule.baseLyricsContentH;
            capsule.contentH = target;
        }
    }

    function toggleMusicNotch(): void {
        root.manualHidden = false;
        if (root.musicIslandActive) {
            root.musicNotchForceMusic = false;
            root.musicNotchForceNormal = true;
            root.musicIslandActive = false;
        } else {
            root.musicNotchForceNormal = false;
            root.musicNotchForceMusic = true;
            root.musicIslandActive = true;
        }
    }

    Timer {
        id: musicIslandDebounce
        interval: 10000
        repeat: false
        onTriggered: {
            if (!root.mediaPlaying && !root.musicNotchForceMusic) {
                root.musicIslandActive = false;
            }
        }
    }

    onMediaPlayingChanged: {
        if (mediaPlaying) {
            musicIslandDebounce.stop();
            if (!root.musicNotchForceNormal) {
                root.musicIslandActive = true;
            }
        } else {
            if (!root.musicNotchForceMusic) {
                musicIslandDebounce.restart();
            }
        }
    }

    onMediaActiveChanged: {
        if (!mediaActive) {
            root.musicNotchForceNormal = false;
            root.musicNotchForceMusic = false;
            root.musicIslandActive = false;
        }
    }

    property int artColorLineIndex: 0
    Process {
        id: pArtColor
        running: false
        stdout: SplitParser {
            onRead: line => {
                var c = line.trim();
                if (c.startsWith("#") && (c.length === 7 || c.length === 9)) {
                    if (root.artColorLineIndex === 0) {
                        root.mediaArtColor = c;
                        root.artColorLineIndex = 1;
                    } else {
                        root.mediaArtColor2 = c;
                    }
                } else if (c.startsWith("/")) {
                    root.mediaArtLocal = "file://" + c;
                }
            }
        }
        onExited: (code, status) => {
            if (code === 0 && root.themeMaterial && root.m3ColorMode === "music") {
                root.updateMatugenTheme();
            }
        }
    }
    property string artColorPendingUrl: ""
    Timer {
        id: artColorDebounce
        interval: 50
        repeat: false
        onTriggered: {
            if (!root.artColorPendingUrl) return;
            pArtColor.command = ["python3", root.scriptDir + "/art_color.py", root.artColorPendingUrl];
            if (pArtColor.running) {
                pArtColor.running = false;
                artColorRestartTimer.restart();
            } else {
                pArtColor.running = true;
            }
        }
    }
    Timer {
        id: artColorRestartTimer
        interval: 30
        repeat: false
        onTriggered: {
            pArtColor.running = true;
        }
    }
    function updateArtColor(artUrl) {
        root.artColorLineIndex = 0;
        if (!artUrl || artUrl.trim().length === 0) {
            var fallbackOn = (matugenColors && matugenColors.primary) ? matugenColors.primary.dark.color : theme.on;
            root.mediaArtColor = root.themeNothing ? root.colFg : fallbackOn;
            root.mediaArtColor2 = root.themeNothing ? root.colMuted : fallbackOn;
            root.mediaArtLocal = "";
            if (root.themeMaterial && root.m3ColorMode === "music") {
                root.updateMatugenTheme();
            }
            return;
        }
        root.artColorPendingUrl = artUrl;
        artColorDebounce.restart();
    }

    onMediaArtChanged: root.updateArtColor(root.mediaArt)
    onMediaArtColorChanged: {
        if (root.themeMaterial && root.m3ColorMode === "music") {
            root.updateMatugenTheme();
        }
    }

    // Pre-carga permanente de la carátula en el caché de pixmaps de QtQuick
    // para que cuando cualquier menú se abra (Control Center, Notch, Isla),
    // la imagen ya esté lista en memoria y nunca muestre el cuadro gris.
    Image {
        id: mediaArtGlobalPreloader
        source: root.effectiveMediaArt
        asynchronous: false
        cache: true
        visible: false
        sourceSize.width: 512
        sourceSize.height: 512
        mipmap: true
        smooth: true
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.refreshMediaArt(); }
        function onTrackTitleChanged()  { root.refreshMediaArt(); }
        function onPostTrackChanged()   { root.refreshMediaArt(); }
        // На паузе/возобновлении плеер иногда переотдаёт метаданные — заодно
        // перечитываем обложку, чтобы она не пропадала после resume.
        function onIsPlayingChanged()   { root.refreshMediaArt(); }
    }

    // ---------------------------------------------------------------- батарея
    // Батарея через UPower: свойства приходят по сигналам D-Bus, поэтому
    // иконка меняется сразу при подключении и отключении зарядки.
    // Раньше здесь был опрос /sys раз в 20 секунд — отсюда задержка.
    readonly property var battDev: {
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.ready && d.isLaptopBattery) return d;
        }
        return UPower.displayDevice;
    }

    readonly property int batteryPct:
        battDev && battDev.ready ? Math.round(battDev.percentage * 100) : 100

    readonly property bool batteryCharging:
        battDev && battDev.ready && (battDev.state === UPowerDeviceState.Charging || battDev.state === 1)

    readonly property bool acOnline: !UPower.onBattery

    // Заряжается — молния. От сети без зарядки — вилка.
    // Иначе обычная батарея с заполнением по проценту (шаг 10).
    readonly property var battIcons: [
        0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E,
        0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]

    // Только уровень, без подмены на молнию: в Quick settings молния стоит
    // отдельным значком рядом, а сама батарея должна показывать заряд.
    readonly property string batteryLevelIcon:
        String.fromCodePoint(battIcons[Math.max(0, Math.min(10, Math.round(batteryPct / 10)))])

    // Есть ли вообще батарея — на десктопе блок заряда прятать целиком.
    //
    // По списку устройств, а не по сводному displayDevice: на настольной
    // машине оно тоже «готово», просто отдаёт ноль, и остров честно рисовал
    // «0%» там, где батареи нет вовсе.
    //
    // Ищем именно системную батарею (isLaptopBattery). Тип Battery носят и
    // мышь с клавиатурой — их заряд не имеет отношения к питанию машины, и
    // показывать его в острове как заряд компьютера было бы неверно.
    readonly property bool batteryPresent: {
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.ready && d.isLaptopBattery) return true;
        }
        return false;
    }

    readonly property int battLowThreshold: 15
    property bool battLowNotified: false

    function battLowCheck() {
        if (!root.batteryPresent) return;
        if (root.acOnline || root.batteryCharging || root.batteryPct > root.battLowThreshold + 5) {
            root.battLowNotified = false;
            return;
        }
        if (root.batteryPct <= root.battLowThreshold && !root.battLowNotified) {
            root.battLowNotified = true;
        }
    }
    Connections {
        target: root
        function onBatteryPctChanged()      { root.battLowCheck(); }
        function onAcOnlineChanged()        { root.battLowCheck(); }
        function onBatteryChargingChanged() { root.battLowCheck(); }
    }

    // ------------------------------------------------------------- машина
    // Ноутбук или ПК — вопрос железа, а не настройки, поэтому спрашивать не о
    // чем: батарея, тачпад и способ управления яркостью просто есть или их
    // нет. Разбирается brightness.sh, тут только результат.
    //
    // Батарею берём у UPower (он и так подключён и сам следит за появлением
    // устройств), остальное — разовым опросом на старте: тачпад и монитор в
    // работающей системе не появляются.
    property string brightBackend: "none"   // backlight | ddc | none
    property bool   hasTouchpad: false
    property bool   ddcutilPresent: false
    readonly property bool isLaptop: root.batteryPresent
    // На ПК прячем то, что относится только к ноутбуку: заряд, профили
    // питания и настройки тачпада. Пустые разделы честнее убрать, чем
    // показывать вечные нули.
    readonly property bool showBattery: root.batteryPresent
    readonly property bool showPowerProfiles: (root.batteryPresent || (root.powerProfile && root.powerProfile.length > 0)) && root.cfg.featPowerProfiles

    Process {
        id: pMachine
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.slice(text.lastIndexOf("backend="));
                t.trim().split("\n").forEach(function (line) {
                    var p = line.split("=");
                    if (p.length !== 2) return;
                    if (p[0] === "backend")  root.brightBackend  = p[1].trim();
                    if (p[0] === "touchpad") root.hasTouchpad    = p[1].trim() === "1";
                    if (p[0] === "ddcutil")  root.ddcutilPresent = p[1].trim() === "1";
                });
                // Список экранов нужен самой панели, а не только вкладке
                // Display: дорожка яркости стоит в быстрых настройках и
                // должна быть там с первого раскрытия, а не после того, как
                // человек однажды заглянул в настройки экрана.
                root.brightRefresh(false);
            }
        }
    }

    // ---------------------------------------------------------- погода
    // Числа держим строками ровно так, как их отдал сервис: округлять и
    // подписывать — дело виджета, а здесь важно отличать «ноль градусов» от
    // «ещё не спрашивали». Пустая строка и значит «нет данных».
    property string weatherTemp: ""
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherPressure: ""
    property string weatherWind: ""
    property string weatherClouds: ""
    property string weatherCond: ""      // Clouds, Rain, Clear …
    property string weatherDesc: ""      // словами, на языке оболочки
    property string weatherIcon: ""      // код вида 04d — по нему берётся значок
    property string weatherPlace: ""     // как город назвал сам сервис
    property string weatherErr: ""       // пусто — всё в порядке
    property bool   weatherBusy: false

    readonly property bool weatherReady:
        root.weatherErr.length === 0 && root.weatherTemp.length > 0
    // Градус в обеих системах пишется одинаково; различаются они шкалой, а
    // не знаком, поэтому буква нужна только там, где её спрашивают явно.
    readonly property string weatherUnitLetter:
        root.cfg.weatherUnits === "imperial" ? "F" : "C"
    // Единица скорости ветра — она же подпись под числом в кружке, поэтому
    // переводится здесь, а не остаётся латиницей на русском интерфейсе.
    readonly property string weatherWindUnit:
        root.cfg.weatherUnits === "imperial" ? (root.languageCode === "ru" ? "миль/ч" : "mph")
                                             : (root.languageCode === "ru" ? "м/с" : root.languageCode === "tr" ? "m/sn" : "m/s")

    // Значок погоды знаком шрифта — для тем, где точечных значков нет.
    // Разбор кода тот же, что в DotIcon: первые две цифры — сама погода.
    readonly property string weatherGlyph: {
        var k = String(root.weatherIcon).slice(0, 2);
        return String.fromCodePoint(
              k === "01" ? 0xF0599                        // солнце
            : k === "02" ? 0xF0595                        // солнце за облаком
            : (k === "03" || k === "04") ? 0xF0590         // облако
            : (k === "09" || k === "10") ? 0xF0597         // дождь
            : k === "11" ? 0xF0593                        // гроза
            : k === "13" ? 0xF0598                        // снег
            : k === "50" ? 0xF0591                        // туман
                         : 0xF0590);
    }

    Process {
        id: pWeather
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherBusy = false;
                // Сборщик копит вывод всех запусков подряд: берём последнюю
                // порцию, а не начало текста.
                var txt = String(text);
                var cut = txt.lastIndexOf("temp=");
                var errCut = txt.lastIndexOf("err=");
                if (errCut > cut) cut = errCut;
                if (cut > 0) txt = txt.slice(cut);

                var got = {};
                txt.trim().split("\n").forEach(function (line) {
                    var i = line.indexOf("=");
                    if (i > 0) got[line.slice(0, i)] = line.slice(i + 1).trim();
                });

                root.weatherErr = got["err"] || "";
                if (root.weatherErr.length) return;

                root.weatherTemp     = got["temp"]     || "";
                root.weatherFeels    = got["feels"]    || "";
                root.weatherHumidity = got["humidity"] || "";
                root.weatherPressure = got["pressure"] || "";
                root.weatherWind     = got["wind"]     || "";
                root.weatherClouds   = got["clouds"]   || "";
                root.weatherCond     = got["cond"]     || "";
                root.weatherDesc     = got["desc"]     || "";
                root.weatherIcon     = got["icon"]     || "";
                root.weatherPlace    = got["city"]     || "";
            }
        }
    }

    function refreshWeather() {
        if (!root.cfg.weatherCity.length) {
            root.weatherErr = "no-city";
            return;
        }
        root.weatherBusy = true;
        pWeather.command = ["sh", "-c",
            root.scriptDir + "/weather.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), ["ru", "tr", "es"].indexOf(root.languageCode) >= 0 ? root.languageCode : "en"];
        pWeather.running = false;
        pWeather.running = true;
    }

    // Раз в четверть часа. Чаще незачем: погода столько и не меняется, а у
    // бесплатного ключа есть предел обращений в минуту, который делят между
    // собой все программы, куда его вписали.
    Timer {
        interval: 900000
        running: (root.cfg.featWidgets || root.cfg.weatherOnIsland)
                 && (root.cfg.weatherCity.length > 0 || root.cfg.weatherKey.length > 0)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    // ------------------------------------------------ детальный прогноз
    property bool weatherDetailsOpen: false
    property var  weatherForecastData: null

    Process {
        id: pWeatherForecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed && !parsed.err) {
                        root.weatherForecastData = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function openWeatherDetails() {
        root.weatherDetailsOpen = true;
        root.refreshWeatherForecast();
    }

    function refreshWeatherForecast() {
        if (!root.cfg.weatherCity.length) return;
        pWeatherForecast.command = ["sh", "-c",
            root.scriptDir + "/weather_forecast.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), ["ru", "tr", "es"].indexOf(root.languageCode) >= 0 ? root.languageCode : "en"];
        pWeatherForecast.running = false;
        pWeatherForecast.running = true;
    }

    // --------------------------------------------------------- нагрузка
    // Сводка для быстрых настроек на теме Nothing. Минус означает «измерить
    // не вышло»: строка тогда прячется, а не показывает ноль. Ноль здесь врёт
    // слишком убедительно — «видеокарта простаивает» и «датчика нет» на глаз
    // неразличимы.
    property int loadCpu:  -1
    property int loadMem:  -1
    property int loadGpu:  -1
    property int loadTempCpu: -1
    property int loadTempGpu: -1
    property int loadDisk: -1

    // Опрашиваем пока панель раскрыта или включены настольные виджеты.
    // На рабочем столе скрипт вызывается с флагом --fast без задержки сна
    // и nvidia-smi, снимая только RAM и Disk за несколько миллисекунд.
    readonly property bool loadWanted: root.expanded || root.cfg.featWidgets || root.cfg.systemLoadOnIsland

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded && root.loadWanted) {
                pLoad.running = false;
                pLoad.running = true;
            }
        }
    }

    Process {
        id: pLoad
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/sysload.sh" + ((root.expanded || root.cfg.systemLoadOnIsland) ? "" : " --fast")]
        stdout: StdioCollector {
            onStreamFinished: {
                // Сборщик копит вывод всех запусков подряд, поэтому берём
                // последнюю законченную строку, а не начало текста.
                var recs = String(text).trim().split("\n").filter(r => r.indexOf("|") >= 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].split("|");
                function num(s) {
                    s = String(s || "").trim();
                    return s.length ? (+s) : -1;
                }
                if (root.expanded || root.cfg.systemLoadOnIsland) {
                    root.loadCpu = num(a[0]);
                    root.loadMem = num(a[1]);
                    root.loadGpu = num(a[2]);
                    root.loadTempCpu = num(a[3]);
                    root.loadTempGpu = num(a[4]);
                    root.loadDisk = num(a[5]);
                } else {
                    root.loadMem = num(a[1]);
                    root.loadDisk = num(a[5]);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.loadWanted
        repeat: true
        triggeredOnStart: true
        // Перезапуск через сброс: присваивание running = true, пока процесс
        // ещё не отметился завершённым, ничего не делает, и показания
        // замирали бы на первом снимке.
        onTriggered: { pLoad.running = false; pLoad.running = true; }
    }

    function refreshLoad() {
        pLoad.running = false;
        pLoad.running = true;
    }

    // ------------------------------------------------------------- яркость
    // [{ id, name, pct }] — экраны, у которых яркость вообще управляется.
    // Пустой список на ПК означает «монитор не отвечает по DDC/CI», и вкладка
    // Display говорит об этом словами вместо мёртвого ползунка.
    property var brightList: []
    property bool brightBusy: false

    Process {
        id: pBrightList
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.trim().split("\n").forEach(function (line) {
                    var p = line.split("\t");
                    if (p.length < 3) return;
                    var pct = parseInt(p[2]);
                    if (isNaN(pct)) return;
                    out.push({ id: p[0], name: p[1], pct: pct });
                });
                root.brightList = out;
                root.brightBusy = false;
            }
        }
    }

    function brightRefresh(rescan) {
        if (root.brightBackend === "none") return;
        root.brightBusy = true;
        pBrightList.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh "
            + (rescan ? "rescan" : "list")];
        pBrightList.running = false;
        pBrightList.running = true;
    }

    // Запись по DDC идёт по I2C и занимает десятки миллисекунд, а ползунок
    // шлёт значения на каждое движение мыши. Без сдерживания шина забивается
    // очередью, монитор отстаёт от ручки и догоняет её через секунду после
    // отпускания. Копим последнее значение и отправляем не чаще, чем шина
    // успевает переварить.
    Process { id: pBrightSet }
    property string brightPendingId: ""
    property int    brightPendingPct: -1

    Timer {
        id: brightFlush
        // Ждём паузы в движении, а не шлём каждые N мс. Одна запись по DDC
        // занимает десятки миллисекунд, монитор на неё моргает подсветкой, и
        // очередь из промежуточных значений превращала протяжку ползунка в
        // мигание с отставанием. Уходит только то, на чём ручка остановилась.
        interval: 180
        repeat: false
        onTriggered: {
            if (root.brightPendingPct < 0) return;
            pBrightSet.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh set "
                + root.brightPendingId + " " + root.brightPendingPct];
            pBrightSet.running = false;
            pBrightSet.running = true;
            root.brightPendingPct = -1;
        }
    }

    function brightSet(id, pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        // Показываем сразу, не дожидаясь монитора: ползунок под рукой обязан
        // ходить без задержки, даже когда шина отвечает медленно.
        var l = root.brightList.slice();
        for (var i = 0; i < l.length; i++)
            if (l[i].id === id) l[i] = { id: id, name: l[i].name, pct: pct };
        root.brightList = l;

        root.brightPendingId = id;
        root.brightPendingPct = pct;
        brightFlush.restart();
    }

    // Подробности для страницы «Батарея»: ёмкость, износ и текущий расход.
    // Прогнозов «сколько осталось» здесь намеренно нет — UPower пересчитывает
    // их рывками, и цифра прыгала на глазах.
    readonly property real batteryHealth:
        battDev && battDev.ready ? Math.round(battDev.healthPercentage) : 0
    readonly property real batteryCapacity:
        battDev && battDev.ready ? battDev.energyCapacity : 0
    // Вт: положительная — заряд, отрицательная — разряд
    readonly property real batteryRate:
        battDev && battDev.ready ? battDev.changeRate : 0

    readonly property string batteryIcon: {
        // Заряжается — молния. От сети без зарядки — обычная батарея,
        // отличается только цветом (зелёный), без иконки розетки.
        if (batteryCharging) return String.fromCodePoint(0xF0241);
        var step = Math.max(0, Math.min(10, Math.round(batteryPct / 10)));
        return String.fromCodePoint(battIcons[step]);
    }

    // ---------------------------------------------------------------- polkit
    // Запрос пароля при установке пакетов и прочих привилегированных
    // действиях рисуется в пилюле, а не отдельным окном агента.
    property var authFlow: null
    readonly property bool authActive: authFlow !== null && !authFlow.isCompleted

    // Агент polkit — тоже в Loader: выключен установщиком, значит остров не
    // регистрируется агентом и место остаётся за уже установленным
    // (hyprpolkitagent и т.п.); polkit допускает только одного на сессию.
    Loader {
        active: root.cfg.featPolkit
        sourceComponent: PolkitAgent {
            onAuthenticationRequestStarted: {
                root.authFlow = flow;
                pageResetTimer.stop();
                root.page = "auth";
                root.expanded = true;
                root.holdOpen = true;
            }
        }
    }

    Connections {
        target: root.authFlow
        ignoreUnknownSignals: true
        function onIsCompletedChanged() {
            if (root.authFlow && root.authFlow.isCompleted) {
                root.authFlow = null;
                root.collapse();
            }
        }
    }

    // ---------------------------------------------------------------- no molestar / keep awake (eliminado)
    property bool keepAwake: false

    // ------------------------------------------------------- звук: устройства и приложения
    // Список выходов и переключение между ними.
    readonly property var audioSinks: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }
    // Список активных аудиопотоков приложений (раздельный микшер)
    readonly property var audioStreams: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isStream && n.audio) {
                var props = n.properties || {};
                var name = String(props["application.name"] || props["media.name"] || n.name || "").toLowerCase();
                if (name.indexOf("cava") < 0 && name.indexOf("quickshell") < 0) {
                    out.push(n);
                }
            }
        }
        return out;
    }
    readonly property string sinkName: {
        var n = Pipewire.defaultAudioSink;
        if (!n) return "";
        return String(n.nickname || n.description || n.name || "");
    }
    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // Прогрев кеша миниатюр обоев при старте, чтобы страница тем
    // открывалась мгновенно уже с первого раза.
    Process {
        running: true
        command: ["sh", "-c", Quickshell.env("HOME")
                  + "/.config/panacea/scripts/thumbs.sh all"]
    }

    // ------------------------------------------------------------ системный трей
    readonly property var trayItems: SystemTray.items

    // ---------------------------------------------------------- уведомления
    // Пилюля сама работает демоном уведомлений: в системе его не было вовсе,
    // и всё, что присылали программы, молча пропадало.
    // «Не беспокоить» — состояние, а не настройка: его переключает кнопка в
    // быстрых настройках, но живёт оно в файле, чтобы переживать перезапуск и
    // совпадать с тем, что показывает окно настроек.
    property bool dnd: cfg.notifDnd
    function toggleDnd() { cfg.notifDnd = !cfg.notifDnd; root.saveCfg(); }
    property var  notifCurrent: null         // то, что показывается сейчас
    ListModel { id: notifModel }             // история
    readonly property var notifications: notifModel
    // Демон уведомлений живёт в Loader: если функция выключена установщиком,
    // сервер не создаётся и остров не регистрируется как daemon — тогда
    // работает уже установленный mako/dunst без спора за шину.
    readonly property bool hasNotifications: cfg.featNotifications
    property var notifServer: notifLoader.item
    Loader {
        id: notifLoader
        active: root.cfg.featNotifications
        sourceComponent: notifServerComp
    }
    // живые уведомления, которые ещё не закрыты программой или пользователем
    readonly property var activeNotifications:
        notifServer ? notifServer.trackedNotifications : null

    // Живые объекты уведомлений по id. Нужны, чтобы нажатие открывало сам
    // повод: у мессенджеров есть действие «default», и именно оно
    // разворачивает нужный чат — угадать его снаружи невозможно.
    property var notifObjs: ({})

    Process { id: pFocusApp }
    // Переводим фокус на приложение: Hyprland сам перелистнёт на его стол,
    // а если окна нет — скрипт запустит приложение.
    function focusApp(hint) {
        var h = String(hint || "").trim();
        if (h.length === 0) return;
        pFocusApp.running = false;
        pFocusApp.command = ["sh", "-c",
            root.scriptDir + "/focusapp.sh \"$1\"", "_", h];
        pFocusApp.running = true;
    }

    // Раскрытие по наведению после клика по уведомлению только мешает: курсор
    // остаётся над пилюлей, и она тут же разворачивается в «Быстрые
    // настройки» — а там сверху часы с подписью «Календарь» и своей областью
    // нажатия, поэтому следующий же щелчок уводил в календарь.
    //
    // Поэтому взводим наведение заново только когда курсор уйдёт с пилюли:
    // по времени было ненадёжно, курсор ведь остаётся на месте.
    property bool hoverExpandArmed: true

    // Нажали на уведомление: сначала просим приложение показать повод
    // (действие «default»), потом уходим к его окну и убираем карточку.
    //
    // Принимает либо сам объект уведомления (карточка знает его напрямую),
    // либо id из истории. По id раньше промахивались: ключи в notifObjs
    // приводились к числу неодинаково, и действие «default» не вызывалось —
    // приложение не открывалось вовсе.
    function activateNotification(what) {
        var n = null;
        var id = -1;
        if (what !== null && typeof what === "object") {
            n = what;
            id = Number(what.id);
        } else {
            id = Number(what);
            n = root.notifObjs[String(id)] || null;
        }
        var hint = "";
        if (n) {
            hint = String(n.desktopEntry || "") || String(n.appName || "");
            var acts = n.actions || [];
            var used = false;
            for (var i = 0; i < acts.length; i++) {
                if (String(acts[i].identifier) === "default") {
                    acts[i].invoke(); used = true; break;
                }
            }
            // одно действие без имени — тоже почти всегда «открыть»
            if (!used && acts.length === 1) acts[0].invoke();
        }
        // Своё уведомление об обновлении ведёт не в приложение, а в настройки:
        // кнопка «Обновить» живёт там, и искать её после нажатия странно.
        if (id >= 0 && id === root.updNotifId) {
            root.updNotifId = -1;
            root.dismissToast();
            root.dropNotification(id);
            root.openSettingsAt("system");
            return;
        }

        root.focusApp(hint);
        root.dismissToast();
        if (id >= 0) root.dropNotification(id);
        // не раскрываемся под курсором после клика — до тех пор, пока курсор
        // не уйдёт с пилюли
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    readonly property bool toastActive: notifCurrent !== null && !expanded
    readonly property string notifSummary: notifCurrent ? String(notifCurrent.summary || "") : ""
    readonly property string notifBody:    notifCurrent ? String(notifCurrent.body || "") : ""
    readonly property string notifApp:     notifCurrent ? String(notifCurrent.appName || "") : ""
    readonly property string notifImage:   notifCurrent ? root.notifIconFor(notifCurrent) : ""

    // notify-send -i отдаёт ИМЯ значка из темы оформления, а не путь к файлу.
    // Image такое имя открыть не может и рисует на его месте «битую картинку»
    // в клеточку. Имена разворачиваем через тему; не нашлось — отдаём пусто,
    // и карточка нарисует свой значок колокольчика.
    function notifIconFor(n) {
        var img = String(n.image || "");
        if (img.length === 0) img = String(n.appIcon || "");
        if (img.length === 0) return "";
        // Значок из темы оформления Quickshell отдаёт как image://icon/ИМЯ,
        // и если темы в системе нет, провайдер молча возвращает клетчатую
        // заглушку со статусом Ready — поймать её по статусу нельзя. Поэтому
        // разворачиваем имя сами: iconPath со вторым true отдаёт пустую
        // строку, когда значка нет, и карточка рисует свой колокольчик.
        if (img.indexOf("image://icon/") === 0)
            return Quickshell.iconPath(img.substring(13).split("?")[0], true);
        // путь, file://, data: — отдаём как есть
        if (img.indexOf("/") >= 0 || img.indexOf(":") >= 0) return img;
        return Quickshell.iconPath(img, true);
    }
    readonly property bool   notifUrgent:
        notifCurrent ? notifCurrent.urgency === NotificationUrgency.Critical : false

    Component {
    id: notifServerComp
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;

            var app = String(n.appName || "");
            var sum = String(n.summary || "");
            var isTransient = (app === "Panacea"
                               || sum === root.tr("Скриншот")
                               || sum === "Скриншот"
                               || sum === "Screenshot"
                               || sum === "Captura de pantalla"
                               || sum.indexOf("Скриншот") >= 0
                               || sum.indexOf("Screenshot") >= 0
                               || sum.indexOf("Captura de pantalla") >= 0);
            if (n.hints && (n.hints["transient"] === true || n.hints["transient"] === 1 || n.hints["transient"] === "1")) {
                isTransient = true;
            }

            if (!isTransient) {
                notifModel.insert(0, {
                    nId: Number(n.id),
                    nSummary: String(n.summary || ""),
                    nBody: String(n.body || ""),
                    nApp: String(n.appName || ""),
                    nImage: root.notifIconFor(n),
                    nUrgent: n.urgency === NotificationUrgency.Critical,
                    nTime: Qt.formatDateTime(new Date(), "HH:mm")
                });
                while (notifModel.count > 50) notifModel.remove(notifModel.count - 1);
            }

            // Программа сама закрывает уведомление, когда оно потеряло смысл:
            // Telegram делает это, как только сообщение прочитано в самом
            // мессенджере. Раньше такая карточка всё равно висела в истории —
            // теперь она уходит вместе с поводом.
            var nid = Number(n.id);
            var objs = root.notifObjs;
            objs[String(nid)] = n;
            root.notifObjs = objs;
            n.closed.connect(function (reason) {
                var o = root.notifObjs;
                delete o[String(nid)];
                root.notifObjs = o;
                if (reason !== NotificationCloseReason.CloseRequested) return;
                root.dropNotification(nid);
            });

            // Критичные показываем даже в режиме «не беспокоить»
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;

            root.enqueueToast(n);
        }
    }
    }

    // Очередь карточек. Раньше уведомление, пришедшее пока панель раскрыта
    // или пока показывается предыдущая карточка, просто уходило в историю —
    // и человек о нём не узнавал. Теперь оно дожидается своей очереди.
    property var toastQueue: []

    function enqueueToast(n) {
        var q = root.toastQueue.slice();
        q.push({ notif: n, at: Date.now() });
        root.toastQueue = q;
        root.pumpToasts();
    }

    function pumpToasts() {
        // занято текущей карточкой или панель раскрыта — подождём
        if (root.notifCurrent !== null || root.expanded) return;
        if (root.toastQueue.length === 0) return;

        var q = root.toastQueue.slice();
        var item = q.shift();
        root.toastQueue = q;

        // протухшие (больше минуты в очереди) не показываем: они уже в истории
        if (Date.now() - item.at > 60000) { root.pumpToasts(); return; }

        var n = item.notif;
        root.notifCurrent = n;
        if (root.cfg.uiSounds !== false && root.cfg.notifSound !== false) {
            root.playSound("notification");
        }
        // Своё время приложения уважаем, но верхнюю и нижнюю границу задаёт
        // человек: важные с нулевым сроком висят до ответа.
        var crit = n.urgency === NotificationUrgency.Critical;
        var want = crit ? root.cfg.notifCritTimeout : root.cfg.notifTimeout;
        var ms = n.expireTimeout > 0 ? (n.expireTimeout < 100 ? n.expireTimeout * 1000 : n.expireTimeout) : want;
        if (!crit && want > 0 && ms > want) ms = want;
        if (crit && want === 0) ms = 0;
        toastTimer.interval = ms > 0 ? Math.max(1000, ms) : 24 * 60 * 60 * 1000;
        toastTimer.restart();
    }

    Timer { id: toastPump; interval: 260; onTriggered: root.pumpToasts() }

    Timer {
        id: toastTimer
        // если курсор на карточке — не убираем, ждём решения пользователя
        onTriggered: {
            if (capsuleHover.hovered) { toastTimer.interval = 1200; restart(); return; }
            root.dismissToast();
        }
    }
    // Крестик в истории: убираем строку и заодно говорим программе, что
    // уведомление закрыто, — иначе оно так и висит у неё «непрочитанным».
    function forgetNotification(index) {
        var e = notifModel.get(index);
        var nid = e ? Number(e.nId) : -1;
        notifModel.remove(index);
        if (nid < 0 || !notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = 0; i < live.length; i++) {
            if (live[i] && Number(live[i].id) === nid) { live[i].dismiss(); break; }
        }
        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    // Убрать уведомление из истории (и с экрана, если оно сейчас показывается)
    function dropNotification(nid) {
        for (var i = 0; i < notifModel.count; i++) {
            if (Number(notifModel.get(i).nId) === nid) { notifModel.remove(i); break; }
        }
        // и из очереди карточек, до которой оно могло не дойти
        var q = root.toastQueue.filter(function (it) {
            return !it.notif || Number(it.notif.id) !== nid;
        });
        if (q.length !== root.toastQueue.length) root.toastQueue = q;

        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    function dismissToast() {
        toastTimer.stop();
        root.notifCurrent = null;
        toastPump.restart();
    }
    function clearNotifications() {
        notifModel.clear();
        // активные тоже закрываем — иначе «Очистить» убирает лишь половину
        if (!notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = live.length - 1; i >= 0; i--) {
            if (live[i]) live[i].dismiss();
        }
    }

    // ------------------------------------------------------- менеджер паролей
    // Записи лежат в ~/.local/share/panacea/vault.enc, зашифрованные на пароле
    // пользователя. Пилюля держит расшифрованный список и сам пароль в памяти,
    // пока хранилище открыто, и забывает всё через 15 минут без обращений.
    property bool   vaultUnlocked: false
    property string vaultKey: ""            // пароль-ключ, только в памяти
    property var    vaultEntries: []        // [{id,label,login,pw,at}]
    property string vaultError: ""
    property bool   vaultBusy: false
    readonly property int vaultIdleMs: 15 * 60 * 1000

    // окно ввода пароля от хранилища держит его открытым, пока им пользуются
    Timer {
        id: vaultIdle
        interval: root.vaultIdleMs
        onTriggered: root.lockVault()
    }
    function touchVault() { if (root.vaultUnlocked) vaultIdle.restart(); }

    // Закрывается сразу, но ключ и записи держим до конца недописанного
    // сохранения: иначе правка, сделанная за секунду до блокировки, пропадала.
    property bool vaultLockPending: false
    function finishLockVault() {
        root.vaultLockPending = false;
        root.vaultKey = "";
        root.vaultEntries = [];
        if (root.cfg.uiSounds !== false) root.playSound("lock");
    }
    function lockVault() {
        vaultIdle.stop();
        root.vaultUnlocked = false;
        root.vaultError = "";
        if (root.vaultDirty || pVaultSave.running) {
            root.vaultLockPending = true;
            vaultSaveTimer.restart();
            return;
        }
        finishLockVault();
    }

    PamContext {
        id: vaultPam
        // тот же профиль, что у экрана блокировки: проверяет пароль
        // пользователя — тот, который спрашивает sudo
        config: "swaylock"
        onPamMessage: {
            if (responseRequired) respond(root.vaultKey);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.vaultLoad();
            } else {
                root.vaultKey = "";
                root.vaultBusy = false;
                root.vaultError = root.tr("Неверный пароль");
            }
        }
    }

    // Открыть хранилище: сначала PAM подтверждает пароль, затем на нём же
    // расшифровывается файл.
    function unlockVault(password) {
        if (root.vaultBusy) return;
        root.vaultError = "";
        root.vaultKey = String(password || "");
        if (root.vaultKey.length === 0) return;
        root.vaultBusy = true;
        if (!vaultPam.start()) {
            root.vaultBusy = false;
            root.vaultKey = "";
            root.vaultError = root.tr("Не удалось проверить пароль");
        }
    }

    Process {
        id: pVaultLoad
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) return;
                try { root.vaultEntries = JSON.parse(t); } catch (e) { root.vaultEntries = []; }
            }
        }
        onExited: code => {
            root.vaultBusy = false;
            if (code === 0) {
                root.vaultUnlocked = true;
                vaultIdle.restart();
                root.vaultError = "";
                if (root.cfg.uiSounds !== false) root.playSound("unlock");
            } else {
                root.vaultKey = "";
                root.vaultError = code === 2 ? root.tr("Хранилище не открылось")
                                             : root.tr("Ошибка хранилища");
            }
        }
    }
    function vaultLoad() {
        pVaultLoad.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/vault.sh load"];
        pVaultLoad.running = true;
        pVaultLoad.write(root.vaultKey + "\n");
        pVaultLoad.stdinEnabled = false;
    }

    Process {
        id: pVaultSave
        stdinEnabled: true
        onExited: code => {
            if (code !== 0) root.vaultError = root.tr("Не удалось сохранить");
            // за время записи список мог измениться ещё раз — пишем снова
            if (root.vaultDirty) vaultSaveTimer.restart();
            else if (root.vaultLockPending) root.finishLockVault();
        }
    }

    // Запись идёт через один процесс, поэтому подряд идущие правки нельзя
    // отправлять «в лоб». Раньше «Добавить все» вызывал vaultSave() на каждую
    // запись: первый вызов запускал openssl, остальные видели running === true,
    // ничего не запускали, а их write() уходил в уже закрытый stdin. На диск
    // попадала одна первая запись — отсюда «пароли не сохраняются».
    // Теперь правки копятся и уходят одним файлом.
    property bool vaultDirty: false
    Timer {
        id: vaultSaveTimer
        interval: 120
        onTriggered: root.vaultFlush()
    }
    function vaultSave() {
        if (!root.vaultUnlocked) return;
        touchVault();
        root.vaultDirty = true;
        vaultSaveTimer.restart();
    }
    function vaultFlush() {
        // Не по vaultUnlocked: закрытие хранилища ждёт именно этой записи,
        // а к тому моменту флаг уже снят.
        if (root.vaultKey.length === 0) return;
        // предыдущая запись ещё идёт — подождём и попробуем снова
        if (pVaultSave.running) { vaultSaveTimer.restart(); return; }
        root.vaultDirty = false;
        pVaultSave.stdinEnabled = true;
        pVaultSave.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/vault.sh save"];
        pVaultSave.running = true;
        pVaultSave.write(root.vaultKey + "\n" + JSON.stringify(root.vaultEntries));
        pVaultSave.stdinEnabled = false;
    }

    function vaultAdd(label, login, pw) {
        if (!root.vaultUnlocked) return;
        var a = root.vaultEntries.slice();
        a.unshift({
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 1e6),
            label: String(label || root.tr("Без названия")),
            login: String(login || ""),
            pw: String(pw || ""),
            at: Qt.formatDateTime(new Date(), "dd.MM.yyyy HH:mm")
        });
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultUpdate(id, label, login, pw) {
        var a = root.vaultEntries.slice();
        for (var i = 0; i < a.length; i++) {
            if (a[i].id !== id) continue;
            a[i] = { id: id, label: String(label), login: String(login),
                     pw: String(pw), at: a[i].at };
            break;
        }
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultRemove(id) {
        root.vaultEntries = root.vaultEntries.filter(function (e) { return e.id !== id; });
        vaultSave();
    }
    function vaultHas(pw) {
        for (var i = 0; i < root.vaultEntries.length; i++)
            if (root.vaultEntries[i].pw === pw) return true;
        return false;
    }

    // --- импорт из браузеров
    // browser_pw.py читает профили установленных браузеров и печатает
    // найденное JSON-ом. Ничего сам не сохраняет: список показывается в
    // хранилище, а переносит записи уже человек — кнопкой.
    property var    browserFound: []      // [{url, login, pw, browser}]
    property bool   browserScanning: false
    property bool   browserScanned: false // был ли хоть один поиск в этом сеансе
    property string browserError: ""

    function browserScan() {
        if (!root.vaultUnlocked || root.browserScanning) return;
        root.browserError = "";
        root.browserFound = [];
        root.browserScanning = true;
        pBrowserScan.running = true;
    }

    Process {
        id: pBrowserScan
        command: ["python3", root.scriptDir + "/browser_pw.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = [];
                try { a = JSON.parse(text); } catch (e) { a = []; }
                // Уже сохранённые не показываем: список должен состоять из
                // того, что действительно можно добавить.
                root.browserFound = a.filter(function (e) {
                    return String(e.pw || "").length > 0 && !root.vaultHas(String(e.pw));
                });
                root.browserScanning = false;
                root.browserScanned = true;
                root.touchVault();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) root.browserError = text.trim()
        }
        onExited: (code, status) => {
            root.browserScanning = false;
            root.browserScanned = true;
            if (code !== 0 && root.browserError.length === 0)
                root.browserError = root.tr("Не удалось прочитать браузеры");
        }
    }

    // Перенос одной найденной записи в хранилище.
    function browserImport(item) {
        if (!root.vaultUnlocked || !item) return;
        root.vaultAdd(String(item.url || item.browser || root.tr("Из браузера")),
                      String(item.login || ""), String(item.pw || ""));
        root.browserFound = root.browserFound.filter(function (e) {
            return !(e.pw === item.pw && e.login === item.login && e.url === item.url);
        });
    }

    function browserImportAll() {
        if (!root.vaultUnlocked) return;
        var list = root.browserFound.slice();
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (root.vaultHas(String(e.pw))) continue;
            root.vaultAdd(String(e.url || e.browser || root.tr("Из браузера")),
                          String(e.login || ""), String(e.pw || ""));
        }
        root.browserFound = [];
    }

    // --- предложение сохранить пароль
    // Подсмотреть, что человек печатает в чужом окне, нельзя (и не нужно —
    // это был бы кейлоггер). Зато пароль почти всегда проходит через буфер
    // обмена: из менеджера, из письма, из генератора. Пилюля замечает такую
    // строку и спрашивает, сохранить ли её.
    property var vaultPrompt: null           // {pw, label}

    function looksLikePassword(s) {
        if (!root.cfg.featVault || !root.cfg.vaultCapture) return false;
        if (!s || s.length < 8 || s.length > 128) return false;
        if (/\s/.test(s)) return false;
        if (/^(https?|ftp|file|magnet):/i.test(s)) return false;
        if (s.indexOf("/") === 0 || s.indexOf("~/") === 0) return false;
        if (/^[0-9]+$/.test(s)) return false;          // номера, коды, счета
        if (/^[a-z]+$/.test(s)) return false;          // просто слово
        if (/@[^@]+\.[a-z]{2,}$/i.test(s)) return false; // почта
        var classes = 0;
        if (/[a-z]/.test(s)) classes++;
        if (/[A-Z]/.test(s)) classes++;
        if (/[0-9]/.test(s)) classes++;
        if (/[^A-Za-z0-9]/.test(s)) classes++;
        return classes >= 3;
    }

    property bool clipToastShown: false
    readonly property bool clipToastActive:
        clipToastShown && !expanded && !root.btToastActive && !root.acToastActive && !root.lowBattToastActive && !root.fullBattToastActive && !root.powerProfileToastActive
    property string clipToastText: ""
    property string lastClipText: ""
    property bool clipWatchPrimed: false
    Timer {
        id: clipToastTimer
        interval: 1900
        onTriggered: root.clipToastShown = false
    }
    function showClipboardToast(txt) {
        if (root.cfg.notchClipboardFlash === false || root.expanded || root.settingsMode) return;
        clipToastText = (txt.length > 24 ? txt.slice(0, 23) + "…" : txt);
        clipToastShown = true;
        clipToastTimer.restart();
    }

    Process {
        id: pClipWatch
        running: root.cfg.featVault || (root.cfg.notchClipboardFlash !== false)
        // печатаем только первую строку: многострочный текст паролем не бывает
        command: ["sh", "-c",
            "wl-paste --type text --watch sh -c "
            + "'printf \"%s\\n\" \"$(wl-paste -n -t text 2>/dev/null | head -1)\"'"]
        stdout: SplitParser {
            onRead: line => {
                var s = String(line);
                if (!root.clipWatchPrimed) {
                    root.clipWatchPrimed = true;
                    root.lastClipText = s.trim();
                    return;
                }
                if (s.trim() === root.lastClipText) return;
                root.lastClipText = s.trim();

                if (root.looksLikePassword(s)) {
                    if (!root.cfg.featVault) return;
                    if (root.vaultUnlocked && root.vaultHas(s)) return;
                    if (root.vaultPrompt && root.vaultPrompt.pw === s) return;
                    root.vaultPrompt = { pw: s, label: "" };
                    pVaultWhere.running = true;
                    root.togglePage("vaultsave");
                    return;
                }
                if (root.cfg.notchClipboardFlash !== false && s.trim().length > 0 && !root.expanded && !root.settingsMode) {
                    root.showClipboardToast(s.trim());
                }
            }
        }
    }
    // чьё окно сейчас активно — подставим как название записи
    Process {
        id: pVaultWhere
        command: ["sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then "
            + "niri msg --json focused-window 2>/dev/null | jq -r '.app_id // \"\"'; "
            + "else hyprctl activewindow -j 2>/dev/null | jq -r '.initialClass // .class // \"\"'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim();
                if (c.length === 0 || !root.vaultPrompt) return;
                root.vaultPrompt = { pw: root.vaultPrompt.pw,
                                     label: c.charAt(0).toUpperCase() + c.slice(1) };
            }
        }
    }
    // Копируем пароль в буфер. wl-copy запускаем с --sensitive-data, чтобы
    // строка не осела в истории cliphist, и очищаем буфер через минуту.
    Process { id: pVaultCopy }
    function vaultCopy(pw) {
        touchVault();
        pVaultCopy.command = ["sh", "-c",
            "printf '%s' \"$1\" | wl-copy --sensitive-data 2>/dev/null "
            + "|| printf '%s' \"$1\" | wl-copy", "_", String(pw)];
        pVaultCopy.running = true;
        vaultClipClear.restart();
    }
    Process { id: pVaultClip; command: ["sh", "-c", "wl-copy --clear"] }
    Timer { id: vaultClipClear; interval: 60000; onTriggered: pVaultClip.running = true }

    function dismissVaultPrompt() {
        root.vaultPrompt = null;
        if (root.page === "vaultsave") root.collapse();
    }

    // ------------------------------------------------------------------ OSD
    // При изменении громкости или яркости пилюля на пару секунд превращается
    // в полоску уровня и возвращается обратно.
    property string osdKind: ""          // "vol" | "mic" | "bright"
    property real   osdValue: 0          // 0..1
    property bool   osdMuted: false
    readonly property bool osdActive: osdKind.length > 0 && !expanded

    Timer {
        id: osdTimer
        interval: 1700
        onTriggered: root.osdKind = ""
    }
    function showOsd(kind, value, muted) {
        if (!cfg.featOsd) return;
        osdKind = kind;
        osdValue = Math.max(0, Math.min(1, value));
        osdMuted = muted === true;
        osdTimer.restart();
    }

    readonly property string osdIcon: {
        if (osdKind === "bright") return String.fromCodePoint(0xF00DE);       // солнце
        if (osdKind === "mic")
            return String.fromCodePoint(osdMuted ? 0xF036D : 0xF036C);        // микрофон
        if (osdMuted || osdValue <= 0.001) return String.fromCodePoint(0xF075F);
        if (osdValue < 0.34) return String.fromCodePoint(0xF057F);
        if (osdValue < 0.67) return String.fromCodePoint(0xF0580);
        return String.fromCodePoint(0xF057E);
    }

    // --- громкость и микрофон берём из Pipewire: реагируем на любое изменение,
    //     не только на нажатие мультимедийной клавиши
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sinkAudio:
        Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var srcAudio:
        Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    property bool osdReady: false        // не показывать OSD при старте оболочки
    Timer { interval: 1500; running: true; onTriggered: root.osdReady = true }

    // Смена устройства вывода (подключились Bluetooth-наушники, воткнули
    // джек) перепривязывает sinkAudio, и onVolumeChanged срабатывает начальной
    // громкостью нового устройства — на миг всплывал OSD с полосой громкости,
    // хотя никто её не трогал. Гасим OSD на короткое окно вокруг переключения.
    property bool sinkSwitching: false
    onSinkAudioChanged: { root.sinkSwitching = true; sinkSettleTimer.restart(); }
    Timer { id: sinkSettleTimer; interval: 700; onTriggered: root.sinkSwitching = false }

    Timer { id: volSoundThrottle; interval: 80; repeat: false }
    Connections {
        target: root.sinkAudio
        enabled: root.sinkAudio !== null
        function onVolumeChanged() {
            if (root.osdReady && !root.sinkSwitching) {
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
                if (root.cfg.uiSounds !== false && root.cfg.volumeSoundTick !== false && !root.sinkAudio.muted && !volSoundThrottle.running) {
                    root.playSound("vol_tick");
                    volSoundThrottle.start();
                }
            }
        }
        function onMutedChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
    }
    Connections {
        target: root.srcAudio
        enabled: root.srcAudio !== null
        function onMutedChanged() {
            if (root.osdReady) root.showOsd("mic", root.srcAudio.volume, root.srcAudio.muted);
        }
    }

    // ------------------------------------------------------- профиль питания
    readonly property string powerScript:
        Quickshell.env("HOME") + "/.config/panacea/scripts/power.sh"

    // "power-saver" | "balanced" | "performance"
    property string powerProfile: "balanced"

    Process {
        id: pPowerGet
        command: ["sh", "-c", root.powerScript + " get"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (s.length) root.powerProfile = s;
            }
        }
    }

    // Мониторинг профилей питания через D-Bus в реальном времени (Fn+Q Lenovo / power-profiles-daemon)
    Process {
        id: pPowerMonitor
        command: ["gdbus", "monitor", "--system", "--dest", "net.hadess.PowerProfiles"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var m = line.match(/'ActiveProfile':\s*<'([^']+)'/);
                if (m && m[1]) {
                    var newProf = m[1];
                    if (root.powerProfile !== newProf) {
                        root.powerProfile = newProf;
                        root.showPowerProfileToast(newProf);
                    }
                }
            }
        }
    }

    // Мониторинг ACPI platform_profile напрямую (Fn+Q Lenovo LOQ аппаратный переключатель - моментальный отклик)
    Process {
        id: pPowerSysfsWatch
        command: ["python3", Quickshell.env("HOME") + "/.config/panacea/scripts/watch_power_profile.py"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var newProf = line.trim();
                if (newProf.length && root.powerProfile !== newProf) {
                    root.powerProfile = newProf;
                    root.showPowerProfileToast(newProf);
                    pPowerSet.command = ["busctl", "--system", "set-property",
                                         "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles",
                                         "net.hadess.PowerProfiles", "ActiveProfile", "s", newProf];
                    pPowerSet.running = false;
                    pPowerSet.running = true;
                }
            }
        }
    }

    Process {
        id: pPowerSet
        onRunningChanged: {
            if (!running) {
                pPowerGet.running = false;
                pPowerGet.running = true;
            }
        }
    }

    // Мониторинг яркости клавиатуры Lenovo LOQ (Fn+Space / 0%, 50%, 100%)
    Process {
        id: pKbdLightSysfsWatch
        command: ["python3", Quickshell.env("HOME") + "/.config/panacea/scripts/watch_kbd_backlight.py"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var val = parseInt(line.trim());
                if (!isNaN(val)) {
                    root.showKbdLightToast(val);
                }
            }
        }
    }
    Process { id: pKbdLightSet }
    Timer {
        id: camRestartTimer
        interval: 1000
        repeat: false
        onTriggered: pCameraWatch.running = true
    }
    // Мониторинг аппаратной шторки / приватности камеры (Lenovo e-shutter / v4l2)
    Process {
        id: pCameraWatch
        command: ["python3", Quickshell.env("HOME") + "/.config/panacea/scripts/watch_camera.py"]
        running: true
        onExited: (code, status) => {
            camRestartTimer.start();
        }
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (s === "blocked") {
                    root.showCameraToast(true);
                } else if (s === "unblocked") {
                    root.showCameraToast(false);
                }
            }
        }
    }

    // Режим питания меняется человеком и почти всегда через саму панель,
    // поэтому в закрытом виде его достаточно сверять раз в полминуты.
    Timer {
        interval: root.expanded ? 10000 : 30000
        running: true; repeat: true
        onTriggered: pPowerGet.running = true
    }

    // Человеческое имя текущего режима питания — для подписи плитки батареи
    readonly property string profileLabel:
        powerProfile === "power-saver" ? tr("Экономия")
      : powerProfile === "performance" ? tr("Максимум")
                                       : tr("Баланс")

    function setPowerProfile(name) {
        if (root.cfg.uiSounds !== false && root.powerProfile !== name) {
            if (name === "power-saver") root.playSound("mode_powersave");
            else if (name === "performance") root.playSound("mode_performance");
            else root.playSound("mode_balanced");
        }
        // отражаем сразу, потом подтверждаем реальным значением от демона
        root.powerProfile = name;
        pPowerSet.running = false;
        pPowerSet.command = ["sh", "-c", root.powerScript + " set \"$1\"", "_", name];
        pPowerSet.running = true;
    }

    // ------------------------------------------------------- рабочий стол
    readonly property int wsId:
        Compositor.isNiri ? Compositor.focusedWorkspace
                          : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    // Столы по порядку номеров — для точек в свёрнутом острове. Спецстолы
    // (отрицательные) пропускаем: на них не переходят подряд с остальными,
    // и точка под них сбивала бы счёт.
    readonly property var wsRaw: {
        var out = [];
        if (Compositor.isNiri) {
            var nws = Compositor.workspaces;
            for (var k = 0; k < nws.length; k++)
                if (nws[k] && nws[k].id > 0) out.push(nws[k].id);
            out.sort(function (a, b) { return a - b; });
            return out;
        }
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++)
            if (all[i] && all[i].id > 0) out.push(all[i].id);
        out.sort(function (a, b) { return a - b; });
        return out;
    }

    // Список столов держим отдельно и меняем, только когда он вправду стал
    // другим.
    //
    // Вычисление выше пересчитывается на каждое событие Hyprland — а их при
    // одном переключении приходит несколько, — и каждый раз отдаёт новый
    // массив. Repeater судит по самому объекту, а не по его содержимому, и
    // на новый массив уничтожает и создаёт заново все точки разом. Отсюда и
    // мигание при переходе на пустой стол: точка текущего успевала родиться
    // полосой и тут же исчезнуть вместе со всем рядом.
    property var wsList: []
    onWsRawChanged: {
        var a = root.wsRaw, b = root.wsList;
        if (a.length === b.length) {
            var same = true;
            for (var i = 0; i < a.length; i++)
                if (a[i] !== b[i]) { same = false; break; }
            if (same) return;
        }
        root.wsList = a;
    }

    // -------------------------------------------------- раскладка клавиатуры
    property string kbLayout: Compositor.keyboardLayout
    Process {
        id: pKbLayout
        command: ["sh", "-c",
            "hyprctl devices -j | jq -r '.keyboards[]|select(.main==true)|.active_keymap' | head -1"]
        running: !Compositor.isNiri
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (!s.length) return;
                Compositor.keyboardLayoutName = s;
            }
        }
    }
    // Hyprland шлёт activelayout при каждом переключении Alt+Shift
    Connections {
        target: Hyprland
        enabled: !Compositor.isNiri
        function onRawEvent(ev) {
            if (ev.name === "activelayout") pKbLayout.running = true;
        }
    }

    // ------------------------------------------------------------------ часы
    property string timeText: ""
    property string dayText: ""
    property string dateLong: ""
    // Секунды отдельной строкой. В timeText они появляются только если их
    // попросили во вкладке Clock & Date, а раскрытому острову на теме Nothing
    // они нужны всегда: там это мелкое число сбоку от крупных часов, а не
    // часть их. Смешивать эти два случая в одной строке нельзя.
    property string secText: ""
    // Число месяца и выходной ли он — для карточки даты на рабочем столе.
    // Держим отдельно от dateLong: тот собирается по выбранному формату и
    // числа из него уже не выковырять.
    property string dayNum: ""
    property bool   weekend: false
    // Месяц своим списком, а не через Qt.formatDateTime: тот берёт язык из
    // системной локали, а подписи оболочки идут за её собственной настройкой
    // языка — иначе на английском интерфейсе месяц оставался бы русским.
    property string monthText: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // 12-часовой формат — с AM/PM, 24-часовой — без; секунды
            // добавляются в оба, если их попросили во вкладке Clock & Date
            var sec = root.cfg.clockSeconds ? ":ss" : "";
            root.timeText = root.cfg.clock12
                ? Qt.formatDateTime(d, "h:mm" + sec + " AP")
                : Qt.formatDateTime(d, "HH:mm" + sec);
            root.secText = Qt.formatDateTime(d, "ss");
            var dateLocale = Qt.locale(root.cfg.lang === "en" ? "en_US" : root.cfg.lang === "ru" ? "ru_RU" : root.cfg.lang === "tr" ? "tr_TR" : root.cfg.lang === "es" ? "es_ES" : root.cfg.lang);
            root.dateLong = (root.cfg.clockWeekday ? d.toLocaleDateString(dateLocale, "dddd") + ", " : "")
                + d.toLocaleDateString(dateLocale, root.cfg.clockDateFmt || "d MMMM");
            root.dayText = dateLocale.dayName(d.getDay(), Locale.ShortFormat);
            root.dayNum = String(d.getDate());
            root.weekend = d.getDay() === 0 || d.getDay() === 6;
            root.monthText = dateLocale.monthName(d.getMonth(), Locale.LongFormat);
        }
    }

    // ------------------------------------------------------------------ Wi-Fi
    readonly property string wifiScript: Quickshell.env("HOME") + "/.config/panacea/scripts/wifi.sh"

    property bool wifiOn: true
    property string wifiSsid: ""
    property int wifiQuality: 0
    property bool wifiBusy: false
    property string wifiError: ""

    ListModel { id: wifiModel }
    // отдаём модель наружу: ControlsView лежит в другом файле
    readonly property var wifiNetworks: wifiModel

    Process {
        id: pWifiStatus
        command: ["sh", "-c", root.wifiScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                root.wifiOn = (p[0] === "on");
                root.wifiSsid = p[1] || "";
                root.wifiQuality = parseInt(p[2]) || 0;
            }
        }
    }
    // Присваивание running = true работающему процессу не делает ничего:
    // опрос молча пропускается, и состояние застывает до следующего раза.
    // Перезапускаем явно.
    function refreshWifiStatus() {
        pWifiStatus.running = false;
        pWifiStatus.running = true;
    }
    // Свёрнутый остров показывает только значок сети: там хватает редкого
    // опроса. Частый нужен, когда открыт список сетей.
    Timer {
        interval: root.expanded ? 4000 : 15000
        running: true; repeat: true
        onTriggered: root.refreshWifiStatus()
    }

    Process {
        id: pWifiList
        command: ["sh", "-c", root.wifiScript + " list"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 5) return;
                wifiModel.append({
                    connected: p[0] === "yes",
                    ssid: p[1],
                    security: p[2],
                    quality: parseInt(p[3]) || 0,
                    known: p[4] === "yes"
                });
            }
        }
        onRunningChanged: if (!running) root.wifiBusy = false
    }

    Process { id: pWifiScan; command: ["sh", "-c", root.wifiScript + " scan"] }
    Process {
        id: pWifiToggle
        command: ["sh", "-c", root.wifiScript + " toggle"]
        onRunningChanged: if (!running) pWifiStatus.running = true
    }
    property string wifiConnectingSsid: ""
    Process {
        id: pWifiConnect
        onRunningChanged: {
            if (running) return;
            root.wifiBusy = false;
            if (exitCode !== 0) {
                root.wifiError = root.tr("Не удалось подключиться");
                root.wifiConnectingSsid = "";
            } else {
                root.wifiError = "";
                if (root.wifiConnectingSsid.length > 0) root.wifiSsid = root.wifiConnectingSsid;
                root.page = "main";
            }
            root.refreshWifiStatus();
            // iwctl возвращается раньше, чем соединение поднялось: сразу после
            // него `iw dev link` ещё пуст, и панель показывала подключённую
            // сеть без имени. Спрашиваем ещё раз, когда связь устоялась.
            wifiSettleTimer.begin();
            root.refreshWifiList();
        }
    }

    // Связь поднимается не мгновенно и не за одинаковое время: у одной точки
    // это доли секунды, у другой — несколько. Поэтому после подключения не
    // один отложенный опрос, а несколько подряд, и прекращаются они, как
    // только имя сети появилось. Иначе панель показывала подключённую сеть
    // без имени до ближайшего общего опроса — или до ручного сканирования.
    Timer {
        id: wifiSettleTimer
        interval: 1200
        repeat: true
        property int tries: 0
        onTriggered: {
            root.refreshWifiStatus();
            if (root.wifiSsid.length || ++wifiSettleTimer.tries > 6) {
                if (root.wifiSsid.length > 0) root.wifiConnectingSsid = "";
                wifiSettleTimer.tries = 0;
                wifiSettleTimer.stop();
            }
        }
        function begin() { wifiSettleTimer.tries = 0; wifiSettleTimer.restart(); }
    }

    // Отключиться от сети и забыть её. Забывание — не то же самое, что
    // отключение: пока сеть сохранена, iwd подключится к ней сам при первой
    // возможности, и «отключился» держится ровно до следующего появления
    // этой точки в эфире.
    Process { id: pWifiDisconnect }
    function disconnectWifi() {
        pWifiDisconnect.running = false;
        pWifiDisconnect.command = ["sh", "-c", root.wifiScript + " disconnect"];
        pWifiDisconnect.running = true;
        wifiSettleTimer.begin();
    }
    Process { id: pWifiForget }
    function forgetWifi(ssid) {
        if (!ssid || !ssid.length) return;
        pWifiForget.running = false;
        pWifiForget.command = ["sh", "-c", root.wifiScript + " forget \"$1\"", "_", String(ssid)];
        pWifiForget.running = true;
        wifiSettleTimer.begin();
        wifiRescanTimer.restart();
    }

    function toggleWifi() { pWifiToggle.running = true; }
    function refreshWifiList() {
        wifiModel.clear();
        root.wifiBusy = true;
        pWifiList.running = true;
    }
    function scanWifi() {
        root.wifiBusy = true;
        pWifiScan.running = true;
        wifiRescanTimer.restart();
    }
    Timer { id: wifiRescanTimer; interval: 2600; onTriggered: root.refreshWifiList() }

    function connectWifi(ssid, password, username, security) {
        root.wifiConnectingSsid = ssid;
        root.wifiBusy = true;
        root.wifiError = "";
        pWifiConnect.command = security === "eap"
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\" \"$3\" eap", "_", ssid, password, username]
            : password && password.length
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\"", "_", ssid, password]
            : ["sh", "-c", root.wifiScript + " connect \"$1\"", "_", ssid];
        pWifiConnect.running = true;
    }

    // --------------------------------------------------------- запись экрана
    // Всё состояние держит scripts/record.sh: пилюлю можно перезапустить
    // прямо во время записи, и она подхватит её обратно.
    property bool   recActive: false
    property bool   recPaused: false
    property int    recStarted: 0        // unix-время старта
    property int    recPausedTotal: 0    // сколько секунд простояли на паузе
    property string recFile: ""
    property string recError: ""
    property int    recNow: 0            // «сейчас» для таймера, тикает раз в секунду

    readonly property int recSeconds:
        recActive ? Math.max(0, recNow - recStarted - recPausedTotal) : 0
    readonly property string recTimeText: {
        var s = recSeconds;
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        var mm = (m < 10 ? "0" : "") + m, ss = (x < 10 ? "0" : "") + x;
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
    }

    readonly property string recScript: root.scriptDir + "/record.sh"

    // ------------------------------------------------- длительная работа
    // Всё, что идёт дольше пары секунд, показывает свёрнутый остров: копирование
    // папки в несколько гигабайт, обновление оболочки, прогрев миниатюр. Раньше
    // они шли молча, и отличить работу от зависания было нельзя.
    //
    // Проценты знает не всякая работа, поэтому busyProgress < 0 означает
    // «идёт, сколько осталось — неизвестно»: там, где считать нечего, полоска
    // просто ходит из стороны в сторону.
    property string busyLabel: ""
    property int    busyProgress: -1
    // значок слева от подписи: у копирования свой, у обновления свой
    property string busyGlyph: ""

    function beginBusy(label, glyph, progress) {
        root.busyLabel = label;
        root.busyGlyph = glyph;
        root.busyProgress = progress === undefined ? -1 : progress;
    }
    function endBusy() {
        root.busyLabel = "";
        root.busyGlyph = "";
        root.busyProgress = -1;
    }

    // ------------------------------------------ длительная файловая операция
    // Процесс живёт здесь, а не в проводнике, нарочно: панель закрывают сразу
    // после того, как перетащили файлы, и вместе с ней умирал бы и Loader, и
    // копирование на середине. Теперь оно доживает до конца само, а остров
    // показывает, сколько осталось.
    property var fileOpQueue: []

    // Вторая операция, начатая пока идёт первая, раньше затирала бы команду
    // работающего процесса и молча пропадала.
    function runFileOp(args, label) {
        if (pFileOp.running) {
            var q = root.fileOpQueue.slice();
            q.push({ args: args, label: label });
            root.fileOpQueue = q;
            return;
        }
        root.beginBusy(label, "󰆏", 0);
        pFileOp.command = args;
        pFileOp.running = true;
    }

    Process {
        id: pFileOp
        stdout: SplitParser {
            onRead: line => {
                var m = /^PROGRESS (\d+)$/.exec(String(line).trim());
                if (m) root.busyProgress = parseInt(m[1], 10);
            }
        }
        onRunningChanged: {
            if (running) return;
            // все открытые проводники перечитывают списки: файл появился
            // (или исчез) не у того окна, что затеяло операцию
            root.filesChanged();
            if (root.fileOpQueue.length > 0) {
                var q = root.fileOpQueue.slice();
                var next = q.shift();
                root.fileOpQueue = q;
                root.beginBusy(next.label, "󰆏", 0);
                pFileOp.command = next.args;
                pFileOp.running = true;
                return;
            }
            root.endBusy();
        }
    }

    Process {
        id: pRecStatus
        command: ["sh", "-c", root.recScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p[0] === "idle") {
                    root.recActive = false;
                    root.recPaused = false;
                    return;
                }
                root.recActive = true;
                root.recPaused = (p[0] === "paused");
                root.recStarted = parseInt(p[2]) || 0;
                root.recPausedTotal = parseInt(p[3]) || 0;
                root.recFile = p[4] || "";
            }
        }
    }
    // Пока запись не идёт, секундная стрелка никому не нужна: таймер сам
    // переходит на редкий шаг и перестаёт будить процессор каждую секунду.
    Timer {
        interval: root.recActive ? 1000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.recNow = Math.floor(Date.now() / 1000);
            pRecStatus.running = true;
        }
    }

    Process {
        id: pRecCmd
        onRunningChanged: if (!running) pRecStatus.running = true
        stderr: SplitParser {
            onRead: line => {
                var t = line.trim();
                if (!t.length) return;
                root.recError = t === "already" ? root.tr("Запись уже идёт")
                              : t === "no-recorder" ? root.tr("wf-recorder не найден")
                              : t === "failed"  ? root.tr("Не удалось начать запись")
                                                : t;
                recErrorClear.restart();
            }
        }
    }
    Timer { id: recErrorClear; interval: 4000; onTriggered: root.recError = "" }

    // Выбор экрана для записи. Несколько мониторов (ноутбук + HDMI) — wf-recorder
    // без -o спрашивает, какой писать, и в фоне падал. Спрашиваем сами карточкой.
    property bool recPick: false
    property var  recPickMons: []
    readonly property bool recPickActive: recPick && !expanded

    function startRecord() {
        if (root.recActive) return;
        root.recError = "";
        var scr = Quickshell.screens;
        if (scr && scr.length > 1) {
            var list = [];
            for (var i = 0; i < scr.length; i++)
                list.push({ name: scr[i].name,
                            desc: String(scr[i].model || scr[i].name) });
            root.recPickMons = list;
            root.recPick = true;
            if (root.expanded) root.collapse();
            return;
        }
        root.startRecordOn(scr && scr.length ? scr[0].name : "");
    }
    function startRecordOn(output) {
        root.recPick = false;
        root.recError = "";
        pRecCmd.command = ["sh", "-c",
            root.recScript + " start \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\"", "_",
            String(root.cfg.recFps), String(root.cfg.recDir),
            root.cfg.recSysAudio ? "1" : "0",
            root.cfg.recMic ? "1" : "0",
            String(root.cfg.recMicDevice),
            String(output)];
        pRecCmd.running = true;
    }
    function cancelRecPick() { root.recPick = false; }
    // Не оставляем карточку выбора висеть вечно, если передумали.
    Timer { id: recPickTimer; interval: 8000; running: root.recPickActive
            onTriggered: root.cancelRecPick() }
    function stopRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " stop"];
        pRecCmd.running = true;
    }
    function pauseRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " pause"];
        pRecCmd.running = true;
    }
    function toggleRecord() { if (root.recActive) stopRecord(); else startRecord(); }

    // ---------------------------------------------------- голос в текст (voxtype)
    // Пока зажат правый Alt — остров показывает индикатор: «Слушаю…» во время
    // записи, «Расшифровываю…» пока voxtype печатает текст. Ведёт индикатор
    // scripts/voxtype.sh (его дёргает Hyprland на нажатие/отпускание клавиши)
    // через IPC voxListening/voxTranscribing/voxDone. Само распознавание и
    // вставку текста в активное поле делает voxtype.
    property string voxState: ""     // "" | "listening" | "transcribing"
    readonly property bool voxActive: voxState.length > 0 && !expanded

    // Страховка: если «Расшифровываю…» почему-то не закрылось (voxtype упал и
    // не прислал voxDone) — прячем сами через несколько секунд.
    Timer {
        id: voxGuard
        interval: 8000
        running: root.voxState === "transcribing"
        onTriggered: root.voxState = ""
    }

    // список микрофонов для выбора в пульте записи
    ListModel { id: micModel }
    readonly property var recMics: micModel
    Process {
        id: pRecMics
        command: ["sh", "-c", root.recScript + " mics"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 2) return;
                micModel.append({ mName: p[0], mDesc: p[1] });
            }
        }
    }
    function refreshMics() {
        micModel.clear();
        pRecMics.running = false;
        pRecMics.running = true;
    }

    Process { id: pMkRecDir }
    function openRecordDir() {
        var d = String(root.cfg.recDir);
        if (d.indexOf("~") === 0) d = Quickshell.env("HOME") + d.slice(1);
        // папки может ещё не быть: создаём, иначе проводник покажет пустоту
        pMkRecDir.command = ["sh", "-c", "mkdir -p \"$1\"", "_", d];
        pMkRecDir.running = true;
        root.filesDir = d;
        root.togglePage("files");
    }

    // -------------------------------------------------------------- Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property var btDevices: btAdapter ? btAdapter.devices : null
    readonly property var btConnectedDevice: {
        if (!btDevices) return null;
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) return list[i];
        return null;
    }
    readonly property string btConnectedName: {
        if (btConnectedDevice) return btConnectedDevice.name || root.tr("Устройство");
        return "";
    }
    readonly property string btConnectedType: {
        if (!btConnectedDevice) return "earbuds";
        var icon = String(btConnectedDevice.icon || "").toLowerCase();
        var name = String(btConnectedDevice.name || "").toLowerCase();
        if (icon === "input-mouse" || name.indexOf("mouse") >= 0 || name.indexOf("мышь") >= 0 || name.indexOf("ratón") >= 0 || name.indexOf("raton") >= 0) return "mouse";
        if (icon === "input-keyboard" || name.indexOf("keyboard") >= 0 || name.indexOf("клави") >= 0 || name.indexOf("teclado") >= 0) return "keyboard";
        if (icon === "input-gaming" || name.indexOf("controller") >= 0 || name.indexOf("gamepad") >= 0 || name.indexOf("dualsense") >= 0 || name.indexOf("xbox") >= 0 || name.indexOf("mando") >= 0) return "gamepad";
        if (icon === "phone" || name.indexOf("phone") >= 0 || name.indexOf("iphone") >= 0 || name.indexOf("android") >= 0 || name.indexOf("móvil") >= 0 || name.indexOf("movil") >= 0) return "phone";
        if (icon === "audio-speakers" || icon === "audio-speaker" || name.indexOf("speaker") >= 0 || name.indexOf("колонк") >= 0 || name.indexOf("altavoz") >= 0 || name.indexOf("parlante") >= 0) return "speaker";
        if (icon === "watch" || name.indexOf("watch") >= 0 || name.indexOf("часы") >= 0 || name.indexOf("reloj") >= 0) return "watch";
        return "earbuds";
    }
    // Заряд подключённого устройства (наушников). -1, если батарею не сообщают.
    readonly property int btConnectedBattery: {
        if (btConnectedDevice && btConnectedDevice.batteryAvailable)
            return Math.round(btConnectedDevice.battery * 100);
        return -1;
    }

    // ---- Тост «Bluetooth-устройство подключено / отключено / низкий заряд» --
    property string btToastName: ""
    property string btToastType: "earbuds"
    property bool   btToastDisconnected: false
    property bool   btToastLowBatt: false
    property bool   btToastShown: false
    readonly property bool btToastActive: btToastShown && !expanded
    property string btPrevConnected: ""
    property bool   btLowBattNotified: false

    function btLowBattCheck() {
        if (!btConnectedDevice || root.btConnectedBattery < 0) {
            root.btLowBattNotified = false;
            return;
        }
        if (root.btConnectedBattery > 25) {
            root.btLowBattNotified = false;
            return;
        }
        if (root.btConnectedBattery <= 20 && !root.btLowBattNotified && root.btConnectedName.length > 0) {
            root.btLowBattNotified = true;
            root.showBtLowBattToast(root.btConnectedName, root.btConnectedType);
        }
    }

    property bool btStartupPrimed: false
    Timer {
        id: btStartupTimer
        interval: 1400
        running: true
        onTriggered: {
            root.btStartupPrimed = true;
            if (root.btConnectedName.length > 0) {
                root.btPrevConnected = root.btConnectedName;
            }
        }
    }

    onBtConnectedBatteryChanged: root.btLowBattCheck()

    onBtConnectedNameChanged: {
        var name = root.btConnectedName;
        if (!root.btStartupPrimed) {
            root.btPrevConnected = name;
            return;
        }
        if (name.length > 0 && name !== root.btPrevConnected) {
            root.btPrevConnected = name;
            root.btLowBattNotified = false;
            root.showBtToast(name, root.btConnectedType, false);
            root.btLowBattCheck();
        } else if (name.length === 0 && root.btPrevConnected.length > 0) {
            var prev = root.btPrevConnected;
            var prevType = root.btToastType;
            root.btPrevConnected = "";
            root.btLowBattNotified = false;
            root.showBtToast(prev, prevType, true);
        }
    }

    function dismissAllSystemToasts() {
        root.clipToastShown = false;
        clipToastTimer.stop();
        root.btToastShown = false;
        btToastTimer.stop();
        root.acToastShown = false;
        acToastTimer.stop();
        root.lowBattToastShown = false;
        lowBattToastTimer.stop();
        root.fullBattToastShown = false;
        fullBattToastTimer.stop();
        root.powerProfileToastShown = false;
        powerProfileToastTimer.stop();
        root.kbdLightToastShown = false;
        kbdLightToastTimer.stop();
        root.cameraToastShown = false;
        cameraToastTimer.stop();
        root.osdKind = "";
        osdTimer.stop();
    }

    function showBtToast(name, type, isDisconnect) {
        root.dismissAllSystemToasts();
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = isDisconnect || false;
        root.btToastLowBatt = false;
        root.btToastShown = true;
        if (root.expanded) root.collapse();
        btToastTimer.interval = 2500;
        btToastTimer.restart();
        root.playSound(isDisconnect ? "disconnect" : "connect");
    }

    function showBtLowBattToast(name, type) {
        root.dismissAllSystemToasts();
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = false;
        root.btToastLowBatt = true;
        root.btToastShown = true;
        if (root.expanded) root.collapse();
        btToastTimer.interval = 3500;
        btToastTimer.restart();
        root.playSound("disconnect");
    }

    function dismissBtToast() {
        root.btToastShown = false;
        btToastTimer.stop();
    }
    Timer {
        id: btToastTimer
        interval: 2500
        onTriggered: root.dismissBtToast()
    }

    // ---- Тост «зарядка подключена» ---------------------------------------
    // При подключении блока питания к ноутбуку остров на пару секунд
    // сворачивается в такую же карточку: значок зарядки, «Заряжается» и заряд.
    // Фон карточки — плавная волна, расходящаяся из центра. Ловим переход
    // питания от сети из false в true; только на ноутбуке (на десктопе сеть
    // есть всегда). Уступает Bluetooth-тосту, если тот показывается.
    property bool acToastShown: false
    readonly property bool acToastActive:
        acToastShown && !expanded && root.isLaptop && !root.btToastActive
    property bool acPrev: root.acOnline
    property string acToastKind: "charge"

    onAcOnlineChanged: {
        if (root.acOnline && !root.acPrev && root.isLaptop) root.showAcToast();
        root.acPrev = root.acOnline;
    }
    function showAcToast(kind) {
        root.dismissAllSystemToasts();
        root.acToastKind = kind || "charge";
        root.acToastShown = true;
        if (root.expanded) root.collapse();
        acToastTimer.restart();
        if (root.cfg.chargeSound !== false && root.cfg.uiSounds !== false) {
            root.playSound("charge");
        }
    }
    function showBattLowToast() {
        // Deprecated: Low battery toast is handled exclusively by Dynamic Island showLowBattToast
    }
    function dismissAcToast() {
        root.acToastShown = false;
        acToastTimer.stop();
    }
    Timer {
        id: acToastTimer
        interval: 2800
        onTriggered: root.dismissAcToast()
    }

    // ---- Тост «низкий заряд батареи» (iPhone Dynamic Island) ------------
    property bool lowBattToastShown: false
    readonly property bool lowBattToastActive:
        lowBattToastShown && !expanded && root.isLaptop && !root.btToastActive && !root.acToastActive && !root.fullBattToastActive && !root.powerProfileToastActive
    property int lowBattLastNotifiedPct: 100
    property int lowBattAlertPct: 20

    function showLowBattToast(pct) {
        if (root.cfg.lowBatteryAlert === false) return;
        root.dismissAllSystemToasts();
        root.lowBattAlertPct = (pct !== undefined && pct !== null) ? pct : root.batteryPct;
        root.lowBattToastShown = true;
        if (root.expanded) root.collapse();
        lowBattToastTimer.restart();
        if (root.cfg.battAlertSound !== false && root.cfg.uiSounds !== false) root.playSound("lowbatt");
    }
    function dismissLowBattToast() {
        root.lowBattToastShown = false;
        lowBattToastTimer.stop();
    }
    Timer {
        id: lowBattToastTimer
        interval: 3800
        onTriggered: root.dismissLowBattToast()
    }

    // ---- Тост «полный/рекомендуемый заряд батареи» (80% / 100%) ------------
    property bool fullBattToastShown: false
    readonly property bool fullBattToastActive:
        fullBattToastShown && !expanded && !root.btToastActive && !root.acToastActive && !root.lowBattToastActive && !root.powerProfileToastActive && !root.recPickActive && !root.voxActive
    property bool fullBattNotified: false
    property bool batt80Notified: false
    property int chargeAlertPct: 100

    function showFullBattToast(pct) {
        var p = (pct !== undefined && pct !== null) ? pct : 100;
        if (p >= 100 && root.cfg.fullBatteryAlert === false) return;
        if (p < 100 && root.cfg.batt80Alert === false) return;
        root.dismissAllSystemToasts();
        root.chargeAlertPct = p;
        root.fullBattToastShown = true;
        if (root.expanded) root.collapse();
        fullBattToastTimer.restart();
        if (root.cfg.battAlertSound !== false && root.cfg.uiSounds !== false) root.playSound("batt_full");
    }
    function dismissFullBattToast() {
        root.fullBattToastShown = false;
        fullBattToastTimer.stop();
    }
    Timer {
        id: fullBattToastTimer
        interval: 3800
        onTriggered: root.dismissFullBattToast()
    }

    // ---- Тост «профиль питания» (Lenovo LOQ Fn+Q / Modo Ahorro, Equilibrado, Rendimiento) ------------
    property bool powerProfileToastShown: false
    readonly property bool powerProfileToastActive:
        powerProfileToastShown && !expanded && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive

    function showPowerProfileToast(prof) {
        root.dismissAllSystemToasts();

        if (prof && prof !== root.powerProfile) {
            root.setPowerProfile(prof);
        } else if (prof && root.cfg.uiSounds !== false && root.cfg.powerProfileSound !== false) {
            if (prof === "power-saver") root.playSound("mode_powersave");
            else if (prof === "performance") root.playSound("mode_performance");
            else root.playSound("mode_balanced");
        }
        if (root.expanded && root.page === "battery") return;
        root.powerProfileToastShown = true;
        if (root.expanded) root.collapse();
        var dur = root.cfg.powerToastDuration !== undefined ? root.cfg.powerToastDuration : 2600;
        powerProfileToastTimer.interval = Math.max(800, dur);
        powerProfileToastTimer.restart();
    }
    function dismissPowerProfileToast() {
        root.powerProfileToastShown = false;
        powerProfileToastTimer.stop();
    }
    Timer {
        id: powerProfileToastTimer
        interval: 2600
        onTriggered: root.dismissPowerProfileToast()
    }

    function cyclePowerProfile() {
        var next = "balanced";
        if (root.powerProfile === "power-saver") next = "balanced";
        else if (root.powerProfile === "balanced") next = "performance";
        else if (root.powerProfile === "performance") next = "power-saver";
        root.setPowerProfile(next);
        root.showPowerProfileToast(next);
    }

    // ---- Тост «яркость клавиатуры» (Lenovo LOQ Fn+Space / 0%, 50%, 100%) ------------
    property bool kbdLightToastShown: false
    property int kbdLightLevel: 2 // 0, 1, 2
    readonly property bool kbdLightToastActive:
        kbdLightToastShown && !expanded && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive

    function showKbdLightToast(lvl) {
        root.dismissAllSystemToasts();
        root.kbdLightLevel = lvl;
        if (root.cfg.kbdLightToast !== false) {
            root.kbdLightToastShown = true;
            if (root.expanded) root.collapse();
            var dur = root.cfg.kbdToastDuration !== undefined ? root.cfg.kbdToastDuration : 2200;
            kbdLightToastTimer.interval = Math.max(800, dur);
            kbdLightToastTimer.restart();
            if (kbdLightCapsule && kbdLightCapsule.triggerAnim) kbdLightCapsule.triggerAnim();
        }
        if (root.cfg.uiSounds !== false && root.cfg.kbdLightSound !== false) {
            if (lvl === 0) root.playSound("kbd_light_0");
            else if (lvl === 1) root.playSound("kbd_light_1");
            else root.playSound("kbd_light_2");
        }
    }
    function dismissKbdLightToast() {
        root.kbdLightToastShown = false;
        kbdLightToastTimer.stop();
    }
    Timer {
        id: kbdLightToastTimer
        interval: 2200
        onTriggered: root.dismissKbdLightToast()
    }

    // ---- Тост «камера заблокирована / разблокирована» (Hardware e-shutter / privacy switch) ------------
    property bool cameraToastShown: false
    property bool cameraBlocked: false // true = bloqueada, false = desbloqueada
    readonly property bool cameraToastActive:
        cameraToastShown && !expanded && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive

    function showCameraToast(blocked) {
        root.dismissAllSystemToasts();
        root.cameraBlocked = blocked;
        if (root.cfg.cameraToast !== false) {
            root.cameraToastShown = true;
            if (root.expanded) root.collapse();
            var dur = root.cfg.cameraToastDuration !== undefined ? root.cfg.cameraToastDuration : 2400;
            cameraToastTimer.interval = Math.max(800, dur);
            cameraToastTimer.restart();
            if (cameraCapsule && cameraCapsule.triggerAnim) cameraCapsule.triggerAnim();
        }
        if (root.cfg.uiSounds !== false && root.cfg.cameraSound !== false) {
            if (blocked) root.playSound("lock");
            else root.playSound("unlock");
        }
    }
    function dismissCameraToast() {
        root.cameraToastShown = false;
        cameraToastTimer.stop();
    }
    Timer {
        id: cameraToastTimer
        interval: 2400
        onTriggered: root.dismissCameraToast()
    }

    // --- Centralized toast overlay active flags (eliminates multi-expression re-evaluations) ---
    readonly property bool anySystemToastActive: btToastActive || acToastActive || lowBattToastActive
        || fullBattToastActive || powerProfileToastActive || kbdLightToastActive || cameraToastActive
        || clipToastActive || recPickActive || voxActive

    readonly property bool anyToastActive: anySystemToastActive || osdActive || toastActive

    function setKbdBacklight(lvl) {
        pKbdLightSet.command = ["brightnessctl", "-d", "*kbd_backlight*", "set", String(lvl)];
        pKbdLightSet.running = true;
    }
    function cycleKbdBacklight() {
        var next = (root.kbdLightLevel + 1) % 3;
        root.setKbdBacklight(next);
    }

    onBatteryPctChanged: {
        var warnThresh = root.cfg.lowBatteryThreshold !== undefined ? root.cfg.lowBatteryThreshold : 20;
        var critThresh = root.cfg.lowBatteryCritThreshold !== undefined ? root.cfg.lowBatteryCritThreshold : 15;
        if (root.isLaptop && !root.batteryCharging && !root.acOnline && root.cfg.lowBatteryAlert !== false) {
            if (batteryPct <= warnThresh && batteryPct > critThresh && lowBattLastNotifiedPct > warnThresh) {
                root.showLowBattToast(warnThresh);
                lowBattLastNotifiedPct = warnThresh;
            } else if (batteryPct <= critThresh && lowBattLastNotifiedPct > critThresh) {
                root.showLowBattToast(critThresh);
                lowBattLastNotifiedPct = critThresh;
            }
        }
        if (root.isLaptop && (root.batteryCharging || root.acOnline)) {
            if (batteryPct >= 80 && batteryPct < 90 && !root.batt80Notified && root.cfg.batt80Alert !== false) {
                root.showFullBattToast(80);
                root.batt80Notified = true;
            } else if (batteryPct >= 100 && !root.fullBattNotified && root.cfg.fullBatteryAlert !== false) {
                root.showFullBattToast(100);
                root.fullBattNotified = true;
            }
        }
        if (batteryPct > (warnThresh + 2)) {
            lowBattLastNotifiedPct = 100;
        }
        if (batteryPct < 78) {
            root.batt80Notified = false;
        }
        if (batteryPct < 98) {
            root.fullBattNotified = false;
        }
    }

    onBatteryChargingChanged: {
        if (root.batteryCharging || root.acOnline) {
            root.lowBattLastNotifiedPct = 100;
            root.dismissLowBattToast();
        } else {
            root.fullBattNotified = false;
            root.batt80Notified = false;
        }
    }

    // rfkill может держать адаптер программно заблокированным (после
    // предыдущей сессии, гибернации, ядра). Пока он заблокирован, BlueZ не даёт
    // включить питание, и плитка «щёлкала» вхолостую. Снимаем блокировку перед
    // включением. rfkill без root снимает только soft-block — этого достаточно.
    Process { id: pBtUnblock; command: ["rfkill", "unblock", "bluetooth"] }
    function toggleBt() {
        if (!btAdapter) return;
        if (!btAdapter.enabled) {
            pBtUnblock.running = true;
            btPowerOn.restart();           // дать rfkill вступить в силу
        } else {
            btAdapter.enabled = false;
        }
    }
    Timer {
        id: btPowerOn
        interval: 250
        onTriggered: if (root.btAdapter) root.btAdapter.enabled = true;
    }
    function scanBt() {
        if (!btAdapter || !btAdapter.enabled) return;
        // без pairable сопряжение нового устройства не начиналось, и наушники
        // зависали в цикле «подключилось — отвалилось»
        btAdapter.pairable = true;
        btAdapter.discovering = true;
        btScanStop.restart();
    }
    Timer { id: btScanStop; interval: 12000; onTriggered: if (root.btAdapter) root.btAdapter.discovering = false }

    // -------------------------------------------------------------------- IPC
    IpcHandler {
        target: "pill"
        // индикатор голосового ввода: зовёт voxtype.sh на разных этапах
        function voxListening(): void {
            root.voxState = "listening";
            root.playSound("voice_start");
        }
        function voxTranscribing(): void { root.voxState = "transcribing"; }
        function voxDone(): void {
            root.voxState = "";
            root.playSound("voice_done");
        }
        function voxUnavailable(): void {
            root.voxState = "";
            root.recError = root.tr("voxtype не установлен");
        }
        function launcher(): void { root.toggleLauncher(); }
        function dock(): void { root.toggleDock(); }
        function overview(): void { root.toggleOverview(); }
        function music(): void { root.toggleMusicIsland(); }
        function toggleLyrics(): void { root.toggleMediaLyrics(); }
        function rotateMusicCenter(): void { root.rotateMusicCenter(); }
        function cycleMusicCenter(): void { root.rotateMusicCenter(); }
        function setMusicCenterMode(m: int): void { root.setMusicCenterMode(m); }
        function toggleMusicNotch(): void { root.toggleMusicNotch(); }
        function toggleNotchMode(): void { root.toggleMusicNotch(); }
        function testLowBattery(pct: int): void { root.showLowBattToast(pct > 0 ? pct : 20); }
        function testChargeToast(): void { root.showAcToast(); }
        function testFullBattery(pct: int): void { root.showFullBattToast(pct > 0 ? pct : 100); }
        function cyclePowerProfile(): void { root.cyclePowerProfile(); }
        function setPowerProfile(prof: string): void {
            if (prof) {
                root.setPowerProfile(prof);
                root.showPowerProfileToast(prof);
            }
        }
        function onProfileSwitched(prof: string): void {
            if (prof) root.powerProfile = prof;
            root.showPowerProfileToast(prof);
        }
        function testPowerProfile(prof: string): void { root.showPowerProfileToast(prof || "performance"); }
        function cycleKbdLight(): void { root.cycleKbdBacklight(); }
        function setKbdLight(lvl: int): void { root.setKbdBacklight(lvl); }
        function testKbdLight(lvl: int): void { root.showKbdLightToast(lvl); }
        function cameraBlocked(): void { root.showCameraToast(true); }
        function cameraUnblocked(): void { root.showCameraToast(false); }
        function testCamera(blocked: bool): void { root.showCameraToast(blocked); }
        function restartCameraWatcher(): void {
            pCameraWatch.running = false;
            camRestartTimer.start();
        }
        function setPowerColor(mode: string, hex: string): void { root.setPowerColor(mode, hex); }
        function toggleHide(): void {
            if (root.expanded) root.collapse();
            root.manualHidden = !root.manualHidden;
        }
        // Всегда плитки Wi-Fi/Bluetooth, даже когда играет музыка
        function controls(): void { root.togglePage("main"); }
        function openControls(): void { root.openSub("main"); }
        function wifi(): void {
            if (root.expanded && root.page === "wifi") { root.collapse(); return; }
            root.togglePage("wifi");
            root.refreshWifiList(); root.scanWifi();
        }
        function bluetooth(): void {
            if (root.expanded && root.page === "bt") { root.collapse(); return; }
            root.togglePage("bt");
            root.scanBt();
        }
        function testBtToast(name: string, type: string): void {
            root.showBtToast(name || "AirPods Pro", type || "earbuds", false);
        }
        function testBtLowBatt(name: string, type: string): void {
            root.showBtLowBattToast(name || "AirPods Pro", type || "earbuds");
        }
        function battery(): void {
            root.openSub("battery");
        }
        function welcome(): void { root.openWelcome(); }
        function dismissWelcome(): void { root.dismissWelcome(); }
        function dismissWhatsNew(): void { root.dismissWhatsNew(); }
        function settings(): void { root.settingsTab = 0; root.togglePage("settings"); }
        // открыть окно настроек сразу на нужном разделе: удобно вешать на
        // сочетание клавиш и незаменимо при проверке самих настроек
        function settingsAt(tab: string): void {
            var n = parseInt(tab);
            if (isNaN(n)) {
                root.settingsSection = tab;
            } else {
                root.settingsTab = n;
            }
            if (root.page !== "settings" || !root.expanded) {
                root.openSub("settings");
            }
            if (contentLoader.item) {
                if (!isNaN(n) && contentLoader.item.go !== undefined) {
                    contentLoader.item.go(root.settingsTab);
                } else if (isNaN(n) && contentLoader.item.goToSection !== undefined) {
                    contentLoader.item.goToSection(tab);
                }
            }
        }
        function setLang(code: string): void { root.setLang(code); }
        function settingsScroll(y: string): void {
            if (root.page !== "settings" || !root.expanded) {
                root.openSub("settings");
            }
            if (contentLoader.item && contentLoader.item.scrollY !== undefined) {
                contentLoader.item.scrollY = parseFloat(y) || 0;
            }
        }
        function shortcuts(): void { root.toggleKeysWindow(); }
        function clipboard(): void { root.togglePage("clip"); }
        function powermenu(): void { root.togglePage("power"); }
        function weather(): void { root.openWeatherDetails(); }
        function smartClose(): string {
            if (!root.cfg.closePanaceaFirst) return "disabled";
            var anyOpen = root.expanded || root.overviewOpen || root.wallsOpen || root.keysWindowOpen || root.whatsNewOpen || root.welcomeOpen || root.weatherDetailsOpen;
            if (anyOpen) {
                if (root.weatherDetailsOpen) root.weatherDetailsOpen = false;
                else if (root.overviewOpen) root.closeOverview();
                else if (root.wallsOpen) root.closeWalls();
                else if (root.keysWindowOpen) root.closeKeysWindow();
                else if (root.whatsNewOpen) root.dismissWhatsNew();
                else if (root.welcomeOpen) root.dismissWelcome();
                else if (root.expanded) root.collapse();
                return "closed_overlay";
            }
            return "none";
        }
        function cancelCapture(): void { root.cancelCaptureRequested(); }
        // Стоп-кадр под выделение области, см. scripts/shot.sh
        function freeze(path: string): void { root.freezeShot = "file://" + path; }
        function unfreeze(): void { root.freezeShot = ""; }
        function shotCopied(path: string): void { root.shotCopied(path); }
        function notifications(): void { root.togglePage("notif"); }
        function audio(): void { root.togglePage("audio"); }
        function calendar(): void { root.togglePage("cal"); }
        function theme(): void { root.toggleWalls(); }
        function record(): void { root.togglePage("record"); }
        function files(): void { root.togglePage("files"); }
        // Открыть проводник сразу в нужном каталоге. Нужно, чтобы система
        // могла назначить его обработчиком inode/directory: без пути «открыть
        // папку» приводило бы всегда в один и тот же каталог.
        function filesAt(path: string): void { root.openFilesAt(path); }
        function passwords(): void { root.togglePage("vault"); }
        function agents(): void { root.openAgents(); }
        function media(path: string): void { root.openMedia(path); }
        // переключить выделение области в плеере (то же, что кнопка «Кроп»)
        function mediaCrop(): void { root.mediaCropToggle(); }
        function recordToggle(): void { root.toggleRecord(); }
        function dnd(): void { root.toggleDnd(); }
        // Яркость приходит от smart_brightness.sh: службы для неё нет.
        //
        // Помимо накладки двигаем и сам ползунок в быстрых настройках. Он
        // читает список экранов, а тот наполняется только по запросу — от
        // клавиш ноутбука список не обновлялся, и ползунок оставался там,
        // где его бросили в прошлый раз, показывая неправду.
        function brightness(pct: string): void {
            var v = parseFloat(pct);
            root.showOsd("bright", v / 100.0, false);

            var l = root.brightList.slice();
            var hit = false;
            for (var i = 0; i < l.length; i++) {
                // Клавиши правят подсветку встроенного экрана — у него в
                // списке признак «bl:», — а внешние мониторы висят на DDC, и
                // до них эти клавиши не достают.
                if (String(l[i].id).indexOf("bl:") === 0 || l.length === 1) {
                    l[i] = { id: l[i].id, name: l[i].name, pct: Math.round(v) };
                    hit = true;
                }
            }
            if (hit) root.brightList = l;
            // Список ещё не собран — соберём: без него ползунка нет вовсе.
            else if (l.length === 0) root.brightRefresh(false);
        }
        // Режим энергосбережения гасит движение и в оболочке: анимации —
        // самое дорогое, что она делает без спроса. Настройка та же, что на
        // вкладке Motion, поэтому режим её честно возвращает при выходе.
        function motion(on: string): void {
            root.cfg.reduceMotion = (on !== "on");
            root.saveCfg();
        }
        function close(): void { root.collapse(); }
    }

    // ----------------------------------------------------------------- окно
    // Экран, на котором висит остров. Слой Wayland пересоздаётся при смене,
    // поэтому вычисляем аккуратно: имя из настроек — только если такой выход
    // сейчас подключён, иначе (и в режиме "auto") идём за фокусом. Если
    // Hyprland ещё не ответил, отдаём null — Quickshell возьмёт экран сам.
    screen: root.pickScreen

    readonly property var pickScreen: {
        var want = root.cfg.pillScreen;
        if (want && want !== "auto") {
            var all = Quickshell.screens;
            for (var i = 0; i < all.length; i++)
                if (all[i].name === want) return all[i];
        }
        if (Compositor.isNiri) {
            var nm = Compositor.focusedMonitor;
            return (nm && nm.screen) ? nm.screen : null;
        }
        var fm = Hyprland.focusedMonitor;
        return (fm && fm.screen) ? fm.screen : null;
    }

    // Прижимаемся тремя кромками: свободной остаётся та, в сторону которой
    // раскрывается панель. Иначе слой занял бы весь экран и exclusiveZone
    // (место под остров) считался бы не от той кромки.
    anchors.top:    !root.pillAtBottom
    anchors.bottom: !root.pillAtTop
    anchors.left:   !root.pillAtRight
    anchors.right:  !root.pillAtLeft
    // Высота окна ПОСТОЯННА и равна экрану.
    //
    // Раньше она переключалась 560 <-> 1080 при закреплении панели, и слой
    // Wayland пересоздавался прямо посреди анимации: содержимое успевало
    // схлопнуться и разложиться заново. Именно это выглядело как рывок при
    // открытии календаря по клику на часы.
    //
    // Постоянная высота ничего не ломает: пока панель не закреплена, ввод
    // ограничен маской по капсуле, и клики проходят сквозь окно как раньше.
    implicitHeight: root.screen ? root.screen.height : 1080
    // для боковых положений свободна вертикальная кромка, и размер по ширине
    // окно тоже должно задать само
    implicitWidth: root.screen ? root.screen.width : 1920
    color: "transparent"
    // зазор между пилюлей и окнами (0 в режиме оверлея или при скрытии)
    exclusiveZone: (root.cfg.pillOverlay || root.pillHidden || (root.fullscreenActive && !root.expanded))
                   ? 0 : pillH + gap
    WlrLayershell.layer: WlrLayer.Overlay
    // Пока поверх экрана развёрнутое окно, пилюли не видно совсем.
    // Показываем её обратно, если панель раскрыли клавишами или если
    // нужно показать уровень громкости/яркости.
    visible: !root.fullscreenActive || root.expanded || root.osdActive

    Process {
        id: pCloseWin
        command: ["sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then "
            + "niri msg action close-window >/dev/null 2>&1; "
            + "else out=$(hyprctl dispatch 'hl.dsp.window.close()' 2>&1); case \"$out\" in ok*) ;; *) hyprctl dispatch killactive ;; esac; fi"]
    }
    function closeActiveWindow(): void {
        pCloseWin.running = false;
        pCloseWin.running = true;
    }

    // Закрытие раскрытой панели по Escape или Super+Q / Meta+W
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.collapse();
            event.accepted = true;
            return;
        }
        if ((event.key === Qt.Key_Q || event.key === Qt.Key_W) && (event.modifiers & Qt.MetaModifier)) {
            if (root.cfg.closePanaceaFirst) {
                root.collapse();
            } else {
                root.closeActiveWindow();
            }
            event.accepted = true;
            return;
        }
    }
    // клики ловим только там, где нарисована пилюля
    // Пока открыта закреплённая страница, ввод принимает всё окно:
    // иначе клики по панели (особенно по центрированным настройкам)
    // проваливались мимо, и ползунки не реагировали.
    // Спрятан ли остров прямо сейчас. Всё, ради чего его вообще показывают —
    // раскрытая панель, перетаскивание, громкость — держит его на экране.
    readonly property bool pillHidden: root.cfg.pillAutoHide
                                       && !root.expanded && !root.holdOpen
                                       && !root.osdActive && !root.pillDragging
                                       && !revealHover.hovered && !capsuleHover.hovered

    // Появление из-за кромки — не повод раскрываться. Остров выезжает прямо
    // под неподвижный курсор, и раскрытие по наведению срабатывало само:
    // человек хотел увидеть часы, а получал панель. Взводим раскрытие
    // заново, только когда курсор после этого действительно двинется.
    onPillHiddenChanged: {
        if (root.pillHidden) return;
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
    }

    // Полоска у самой кромки: спрятанный остров курсором не поймать, и
    // вернуть его нечем — кроме узкой зоны, которая ловит наведение.
    Item {
        id: revealStrip
        visible: root.cfg.pillAutoHide
        anchors.top:    root.pillAtBottom ? undefined : parent.top
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtRight  ? undefined : parent.left
        anchors.right:  root.pillAtRight  ? parent.right : undefined
        width:  root.pillSide ? 4 : parent.width
        height: root.pillSide ? parent.height : 4
        HoverHandler { id: revealHover }
    }

    Region {
        id: capsuleRegion
        item: capsule
        // спрятанный остров вне экрана, и без полоски его не позвать
        Region {
            item: root.cfg.pillAutoHide ? revealStrip : null
            intersection: Intersection.Combine
        }
        Region {
            item: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || detachedPanel.opacity > 0.005)) ? detachedPanel : null
            intersection: Intersection.Combine
        }
    }
    mask: root.holdOpen ? null : capsuleRegion
    // Лаунчер забирает клавиатуру сразу (Exclusive), чтобы можно было
    // печатать без клика. OnDemand отдаёт фокус только после клика мышью.
    WlrLayershell.keyboardFocus: root.holdOpen ? WlrKeyboardFocus.Exclusive
                                              : WlrKeyboardFocus.None

    readonly property var activePanel: (root.cfg.pillKeepVisible && root.expanded && !root.settingsMode) ? detachedPanel : capsule

    // Клик мимо закреплённой панели — закрыть.
    // Области лежат строго ВОКРУГ активной панели, поэтому клики по элементам
    // и тумблерам внутри панели физически до них не доходят и панель не сбрасывается.
    Repeater {
        model: 4
        MouseArea {
            required property int index
            enabled: root.holdOpen
            visible: enabled
            z: 5
            // 0 — сверху, 1 — снизу, 2 — слева, 3 — справа от активной панели
            x: index === 3 ? root.activePanel.x + root.activePanel.width : 0
            y: index === 1 ? root.activePanel.y + root.activePanel.height
             : index >= 2 ? root.activePanel.y : 0
            width:  index < 2 ? root.width
                  : index === 2 ? root.activePanel.x
                                : Math.max(0, root.width - root.activePanel.x - root.activePanel.width)
            height: index === 0 ? root.activePanel.y
                  : index === 1 ? Math.max(0, root.height - root.activePanel.y - root.activePanel.height)
                                : root.activePanel.height
            onClicked: root.collapse()
        }
    }

    // Снимок прежних обоев: лежит ниже пилюли и выше рабочего стола,
    // клики не ловит — маска окна всё равно пропускает их насквозь.
    Image {
        anchors.fill: parent
        z: -5
        // Пока кроссфейда нет, снимок не нужен и в памяти его быть не должно:
        // распакованные обои во весь экран — это десяток мегабайт, которые
        // висели круглые сутки ради семисот миллисекунд перехода.
        source: (root.themeFading || opacity > 0.01) ? root.themeFadeWall : ""
        fillMode: Image.PreserveAspectCrop
        // у обоев бывает 75 мегапикселей: без ограничения Qt отказывается их
        // декодировать (лимит 256 МБ на картинку) и кроссфейд не появлялся
        sourceSize.width: root.screen ? root.screen.width : 1920
        asynchronous: false
        cache: false
        visible: opacity > 0.01
        opacity: root.themeFading ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
        }
    }

    // Подсветка кромки, к которой прицепится остров. Пока тянут по пустоте,
    // ничего не горит — значит отпускать некуда, вернётся на место.
    Repeater {
        model: ["top", "bottom", "left", "right"]
        Rectangle {
            required property string modelData
            readonly property bool side: modelData === "left" || modelData === "right"
            readonly property bool lit: root.pillDragging && root.dragEdge === modelData

            width:  side ? 4 : parent.width
            height: side ? parent.height : 4
            x: modelData === "right" ? parent.width - width : 0
            y: modelData === "bottom" ? parent.height - height : 0
            z: 80
            radius: 2
            color: root.colOn
            opacity: lit ? 0.9 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // ------------------------------------------------------------- сама пилюля
    Rectangle {
        id: capsule

        // Прижата к своей кромке и растёт от неё — поэтому «раскрытие к
        // центру» получается само, без отдельной анимации направления.
        anchors.top:    root.pillAtTop    ? parent.top    : undefined
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtLeft   ? parent.left   : undefined
        anchors.right:  root.pillAtRight  ? parent.right  : undefined
        anchors.horizontalCenter: root.pillSide ? undefined : parent.horizontalCenter
        anchors.verticalCenter:   root.pillSide ? parent.verticalCenter : undefined

        // у кромки — 0, в режиме настроек — по центру экрана
        // Вне режима выреза остров отходит от кромки на islandGap: он
        // перестаёт быть продолжением края экрана и становится отдельной
        // капсулой, висящей рядом с ним.
        readonly property real freeGap: root.cfg.notchMode ? 0 : root.cfg.islandGap
        // Спрятанный остров уходит за кромку целиком: отрицательный отступ
        // выносит его за границу окна, и на экране не остаётся ничего.
        readonly property real edgeMargin: root.settingsMode && !root.pillSide
                                           ? Math.max(24, (root.height - targetH) / 2)
                                           : (root.pillHidden || root.braveDodgeActive || root.manualHidden) ? -(targetH + 14) : freeGap
        // у боковых положений от кромки отрывает уже горизонтальный отступ
        readonly property real sideMargin: root.settingsMode && root.pillSide
                                           ? Math.max(24, (root.width - width) / 2)
                                           : (root.pillHidden || root.manualHidden) ? -(width + 4) : freeGap
        anchors.topMargin:    root.pillAtTop    ? edgeMargin : 0
        anchors.bottomMargin: root.pillAtBottom ? edgeMargin : 0
        anchors.leftMargin:   root.pillAtLeft   ? sideMargin : 0
        anchors.rightMargin:  root.pillAtRight  ? sideMargin : 0
        readonly property bool isHiding: (root.pillHidden || root.braveDodgeActive || root.manualHidden)
        readonly property int marginAnimDur: isHiding ? 290 : (root.expanded ? 340 : 380)
        readonly property var marginAnimEase: isHiding ? Easing.InCubic : (root.expanded ? Easing.OutCubic : Easing.OutBack)

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: capsule.marginAnimDur
                easing.type: capsule.marginAnimEase
                easing.overshoot: 1.04
            }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: capsule.marginAnimDur
                easing.type: capsule.marginAnimEase
                easing.overshoot: 1.04
            }
        }
        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: capsule.marginAnimDur
                easing.type: capsule.marginAnimEase
                easing.overshoot: 1.04
            }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: capsule.marginAnimDur
                easing.type: capsule.marginAnimEase
                easing.overshoot: 1.04
            }
        }

        // Свёрнутый остров измеряется вдоль своей кромки и поперёк неё: у
        // боковых положений он стоит вертикально, поэтому длина уходит в
        // высоту, а толщина — в ширину.
        // collapsedW задаёт нижнюю границу, а не саму ширину: содержимое
        // свёрнутого острова меняется (часы, трек, всплеск громкости), и
        // жёсткая ширина обрезала бы его.
        // Nothing носит остров заметно длиннее: там по краям стоят точки
        // столов и три показателя сразу, и на общей нижней границе всё это
        // жалось к часам вплотную.
        readonly property int collapsedMin: root.cfg.collapsedW

        // Округляем до чётного числа пикселей. Остров стоит по центру экрана,
        // то есть его x равен половине разности ширин: при нечётной или
        // дробной длине он попадает на полпикселя, и вогнутые уголки по бокам
        // — отдельные элементы со своими координатами — приезжают на ту же
        // половину. На стыке остаётся сглаженная серая щель, и правый уголок
        // начинает читаться как приклеенный отдельно.
        //
        // Раньше до этого не доходило: содержимое было уже нижней границы, и
        // длиной работало ровное число из настроек. Точечные цифры шире, и
        // дробная ширина содержимого стала попадать наружу.
        function evenUp(v) { return Math.round(v / 2) * 2; }

        readonly property real idleLen: root.voxActive
                    ? capsule.evenUp(Math.max(voxCapsule.implicitWidth + 40, 240))
                : root.recPickActive
                    ? capsule.evenUp(Math.max(recPickCapsule.implicitWidth + 28, 240))
                : root.btToastActive
                    ? capsule.evenUp(btCapsule.implicitWidth + 36)
                : root.clipToastActive
                    ? capsule.evenUp(clipCapsule.implicitWidth + 36)
                : root.cameraToastActive
                    ? capsule.evenUp(cameraCapsule.implicitWidth + 36)
                : root.kbdLightToastActive
                    ? capsule.evenUp(kbdLightCapsule.implicitWidth + 36)
                : root.powerProfileToastActive
                    ? capsule.evenUp(powerProfileCapsule.implicitWidth + 36)
                : root.acToastActive
                    ? capsule.evenUp(Math.max(acCapsule.implicitWidth + 36, 320))
                : root.fullBattToastActive
                    ? capsule.evenUp(fullBattCapsule.implicitWidth + 36)
                : root.lowBattToastActive
                    ? capsule.evenUp(lowBattCapsule.implicitWidth + 36)
                : root.toastActive ? 440
                : root.osdActive ? capsule.evenUp(osdCapsule.implicitWidth + 32)
                : root.pillSide  ? capsule.evenUp(Math.max(vertCapsule.implicitHeight + 30,
                                                           capsule.collapsedMin))
                : root.musicIslandActive
                    ? capsule.evenUp(Math.max(musicCapsule.implicitWidth,
                                              root.musicCenterMode === 4 ? 154
                                            : root.musicCenterMode === 2 ? 240
                                            : 204))
                : (root.themeNothing || root.themeMaterial)
                    ? capsule.evenUp(modernCapsule.implicitWidth)
                : capsule.evenUp(idleCapsule.implicitWidth + 32)
        readonly property real idleThick: root.anySystemToastActive
                ? root.pillH
                : root.toastActive
                ? toastCapsule.implicitHeight + 24 : root.pillH

        width: root.settingsMode ? root.settingsW
             : (root.expanded && !root.cfg.pillKeepVisible) ? (root.page === "islandmusic" ? 460 : (root.page === "power" ? 620 : root.panelW))
             : root.pillSide     ? idleThick
                                 : idleLen
        // целевая высота — к ней анимируется height и по ней же сразу
        // рассчитывается центрирование, чтобы движение было одноэтапным
        // Высота содержимого держится отдельно: при смене страницы новый вид
        // на первом кадре ещё не разложен и его implicitHeight равен нулю.
        // Раньше капсула успевала схлопнуться до нуля и разложиться заново —
        // отсюда рывок при переходе, например, из плиток в календарь.
        property real contentH: 220

        property bool lyricsAnimating: false
        property real baseLyricsContentH: 0
        Timer {
            id: lyricsAnimTimer
            interval: 420
            onTriggered: {
                capsule.lyricsAnimating = false;
                capsule.applyContentH();
            }
        }

        // Раскладка новой страницы идёт в несколько проходов: сетка календаря
        // из 42 ячеек успевает отдать промежуточные высоты. Если применять
        // каждую, капсула дёргается. Собираем их в один шаг через таймер.
        Timer {
            id: contentSettle
            interval: 24
            onTriggered: capsule.applyContentH()
        }
        function refreshContentH() {
            if (capsule.lyricsAnimating) return;
            contentSettle.restart();
        }
        function applyContentH() {
            if (capsule.lyricsAnimating) return;
            var it = contentLoader.item;
            if (!it || it.implicitHeight <= 40) return;
            var target = it.implicitHeight + 30;
            var delta = (root.page === "islandmusic" || contentLoader.sourceComponent === islandMusicComp) ? ((root.cfg.islandLyricsHeight || 240) + 14) : 216; // ? 254 : 216
            capsule.baseLyricsContentH = root.mediaLyricsOpen ? Math.max(220, target - delta) : target;
            // Мелкие колебания раскладки цель не двигают. Высота идёт через
            // Behavior, а тот на каждое изменение цели начинает анимацию
            // заново — с текущей точки и на полную длительность. Пока страница
            // доразмечается, цель успевает поменяться несколько раз, и вместо
            // одного плавного роста капсула идёт ступеньками. Разница в
            // несколько пикселей глазу не видна, а перезапуск — виден.
            if (Math.abs(target - capsule.contentH) < 8) return;
            capsule.contentH = target;
        }
        Connections {
            target: contentLoader
            function onItemChanged() {
                capsule.lyricsAnimating = false;
                capsule.baseLyricsContentH = 0;
                lyricsAnimTimer.stop();
                capsule.refreshContentH();
            }
        }
        Connections {
            target: contentLoader.item
            ignoreUnknownSignals: true
            function onImplicitHeightChanged() { capsule.refreshContentH(); }
        }

        // Раскрытая панель не выше expandedH: страницы бывают длинные, но
        // их высоту ограничивает уже своя прокрутка, а не остров.
        readonly property real targetH: root.settingsMode ? Math.min(contentH, root.height - 48)
                : (root.expanded && !root.cfg.pillKeepVisible) ? Math.min(contentH, ((contentLoader.sourceComponent === controlsComp || contentLoader.sourceComponent === islandMusicComp || root.page === "main" || root.page === "islandmusic") ? Math.max(contentH, root.cfg.expandedH) : root.cfg.expandedH), root.height - 48)
                : root.pillSide ? idleLen
                                : idleThick
        // Не выше экрана: у боковых кромок вертикальная раскладка страницы
        // отдавала такую высоту, что остров разворачивался во весь экран.
        height: Math.min(targetH, root.height - root.gap * 2)

        // Перенос: капсула сдвигается от своего места на dragDX/dragDY. Пока
        // тянут — без анимации, чтобы шла точно за курсором; на отпускании
        // смещение сбрасывается в ноль и она сама доезжает до кромки.
        transform: Translate {
            x: root.dragDX
            y: root.dragDY
            Behavior on x {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
        }

        onXChanged:      root.pillRectX = capsule.x
        onYChanged:      root.pillRectY = capsule.y
        onWidthChanged:  root.pillRectW = capsule.width
        onHeightChanged: root.pillRectH = capsule.height
        Component.onCompleted: {
            root.pillRectX = capsule.x;      root.pillRectY = capsule.y;
            root.pillRectW = capsule.width;  root.pillRectH = capsule.height;
        }

        // Пока карусель обоев открыта, остров спрятан: она выросла из него,
        // и два острова на экране разом смотрелись бы как две панели.
        opacity: root.wallsOpen ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.animFast } }

        color: root.currentNotchBg
        Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
        // Углы у прижатой кромки срезаны, у смотрящей в экран — скруглены:
        // так остров выглядит выросшим из края, а не приклеенным к нему.
        // В режиме настроек капсула отрывается от кромки, и круглыми
        // становятся все четыре.
        // Оторванная от кромки капсула круглая со всех сторон: срезать ей
        // углы не от чего, кромка её больше не держит.
        readonly property real edgeR: (root.settingsMode || !root.cfg.notchMode)
                                      ? (root.cfg.islandRadius > 0 ? root.cfg.islandRadius : 26)
                                      : 0
        readonly property real freeR: (root.settingsMode || (root.expanded && !root.cfg.pillKeepVisible))
                ? (root.cfg.islandRadius > 0 && !root.cfg.notchMode ? root.cfg.islandRadius : 26)
                : (root.cfg.islandRadius > 0 && !root.cfg.notchMode
                   ? root.cfg.islandRadius : root.pillH / 2)
        topLeftRadius:     root.pillAtTop || root.pillAtLeft  ? edgeR : freeR
        topRightRadius:    root.pillAtTop || root.pillAtRight ? edgeR : freeR
        bottomLeftRadius:  root.pillAtBottom || root.pillAtLeft  ? edgeR : freeR
        bottomRightRadius: root.pillAtBottom || root.pillAtRight ? edgeR : freeR
        Behavior on topLeftRadius {
            NumberAnimation {
                duration: root.expanded ? 320 : 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on topRightRadius {
            NumberAnimation {
                duration: root.expanded ? 320 : 260
                easing.type: Easing.OutCubic
            }
        }

        // Niente bordo, in nessuno stato: e' l'unica differenza di stile che
        // c'era fra pillola e pannello. Un bordo largo 1 viene disegnato
        // *dentro* al rettangolo, quindi anche когда era trasparente lasciava
        // passare 1px di sfondo sur lato superiore: da тут l'impressione che
        // la pillola non fosse attaccata al bordo dello schermo e что fondo
        // cambiasse all'apertura.
        border.width: 0

        // Animaciones ultra-fluidas y livianas de la Isla Dinámica
        Behavior on width {
            NumberAnimation {
                duration: root.expanded ? 340 : 280
                easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.05
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: (capsule.lyricsAnimating ? root.mediaLyricsOpen : root.expanded) ? 340 : 280
                easing.type: (capsule.lyricsAnimating ? root.mediaLyricsOpen : root.expanded) ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.05
            }
        }
        Behavior on bottomLeftRadius {
            NumberAnimation {
                duration: root.expanded ? 320 : 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on bottomRightRadius {
            NumberAnimation {
                duration: root.expanded ? 320 : 260
                easing.type: Easing.OutCubic
            }
        }

        clip: true

        // --- курсор отслеживаем поверх всего содержимого
        HoverHandler {
            id: capsuleHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            // Где стоял курсор, когда раскрытие по наведению запретили.
            // Запрет ставится после переноса острова и после клика по
            // уведомлению, а снимался он только уходом курсора с острова.
            // Если остров вставал ровно под неподвижным курсором (а после
            // переноса к кромке так и происходит), уходить было нечему:
            // запрет оставался навсегда, и панель больше не открывалась.
            // Поэтому его снимает ещё и осмысленный сдвиг мыши.
            property point armPos: Qt.point(-9999, -9999)
            // точку отсчёта ставят те места, что запрещают раскрытие
            function markArmPoint() {
                capsuleHover.armPos = capsuleHover.hovered
                        ? capsuleHover.point.scenePosition : Qt.point(-9999, -9999);
            }
            onPointChanged: {
                if (root.hoverExpandArmed || !capsuleHover.hovered) return;
                var p = capsuleHover.point.scenePosition;
                if (Math.abs(p.x - capsuleHover.armPos.x)
                    + Math.abs(p.y - capsuleHover.armPos.y) < 12) return;
                root.hoverExpandArmed = true;
                expandTimer.restart();
            }

            onHoveredChanged: {
                if (root.manualHidden) return;
                if (hovered && root.braveOnScreen && !root.expanded) {
                    braveReturnTimer.stop();
                    root.braveDodgeActive = true;
                    braveDodgePollTimer.restart();
                    return;
                }
                // курсор снова на острове — считать сдвиг заново от этой точки
                if (hovered && !root.hoverExpandArmed)
                    capsuleHover.armPos = capsuleHover.point.scenePosition;
                if (hovered) {
                    collapseTimer.stop();
                    expandTimer.restart();
                    rearmTimer.stop();
                } else {
                    expandTimer.stop();
                    collapseTimer.restart();
                    // Курсор ушёл — разрешаем раскрытие снова, но не сразу.
                    // При переезде к другой кромке остров на кадр выскакивает
                    // из-под курсора, и мгновенное возвращение разрешения
                    // означало, что у новой кромки он тут же раскрывался под
                    // тем же самым курсором.
                    rearmTimer.restart();
                }
            }
        }
        // Раскрыть плитки. Страницу трогаем только если панель ещё закрыта:
        // иначе наведение сбрасывало бы уже открытый список сетей.
        //
        // Открываются всегда плитки. Ни музыка, ни идущая запись своей
        // страницы не подсовывают: трек живёт карточкой прямо здесь, а до
        // пульта записи один клик по плитке — зато не приходится гадать,
        // что откроется.
        function openPanel() {
            root.manualHidden = false;
            if (!root.expanded) {
                pageResetTimer.stop();
                root.page = "main";
            }
            root.expanded = true;
        }

        Timer {
            id: expandTimer; interval: 0
            onTriggered: {
                if (root.braveOnScreen || root.braveDodgeActive || root.manualHidden) return;
                if (!capsuleHover.hovered || root.launcherOpen) return;
                if (!root.hoverExpandArmed) return;
                // пока висит уведомление, наведение не раскрывает панель:
                // иначе до крестика не добраться
                if (root.toastActive || root.btToastActive || root.acToastActive || root.lowBattToastActive || root.fullBattToastActive || root.powerProfileToastActive || root.kbdLightToastActive || root.cameraToastActive || root.recPickActive || root.voxActive) return;
                // При автопрятании наведением остров только показывают. Он и
                // выезжает-то из-за кромки под этот самый курсор, так что
                // раскрытие следом означало бы: хотел посмотреть время —
                // получи панель во весь экран. Разворачивает клик.
                if (root.cfg.pillAutoHide) return;
                capsule.openPanel();
            }
        }
        // курсор должен побыть в стороне, а не просто мигнуть мимо
        Timer {
            id: rearmTimer
            interval: 450
            onTriggered: root.hoverExpandArmed = true
        }
        Timer {
            id: collapseTimer; interval: 180
            onTriggered: {
                if (capsuleHover.hovered || (detachedHover.hovered && root.cfg.pillKeepVisible) || root.holdOpen) return;
                root.collapse();
            }
        }

        // Клик по свёрнутому острову разворачивает его
        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: !root.expanded && !root.pillDragging
                     && !root.braveDodgeActive && !root.manualHidden
                     && !root.anyToastActive
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.braveOnScreen) return;
                capsule.openPanel();
            }
        }

        // В режиме pillKeepVisible при открытой отдельной панели клик по фону острова закрывает её
        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.cfg.pillKeepVisible && root.expanded && !root.settingsMode
                     && !root.toastActive && !root.pillDragging
            cursorShape: Qt.PointingHandCursor
            onClicked: root.collapse()
        }

        // Клик по карточке открывает историю. Отдельным слоем под ней:
        // внутри RowLayout якоря ломают раскладку.
        // Нажатие открывает сам повод: чат, письмо, загрузку. Раньше карточка
        // уводила в список уведомлений — оттуда всё равно приходилось искать
        // приложение руками.
        //
        // z поверх всего содержимого капсулы: пока висит карточка, ни одна
        // область под ней не должна перехватывать щелчок.
        MouseArea {
            anchors.fill: parent
            z: 100
            enabled: root.toastActive
            visible: enabled
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.notifCurrent) root.activateNotification(root.notifCurrent)
        }

        // ------------------------------------------ свёрнутое: уведомление
        RowLayout {
            id: toastCapsule
            // Выше области нажатия карточки: сама она щелчки не перехватывает
            // (это просто текст и иконки), зато крестик внутри остаётся
            // доступным — иначе его накрыло бы прозрачной областью.
            z: 110
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            anchors.topMargin: 12
            spacing: 12
            visible: root.toastActive && !root.anySystemToastActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // значок программы, если прислали
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: root.notifUrgent ? Qt.rgba(1, 0.27, 0.27, 0.18)
                                        : Qt.rgba(1, 1, 1, 0.08)

                Image {
                    id: toastIcon
                    anchors.fill: parent
                    anchors.margins: 5
                    source: root.notifImage
                    // не Ready — значит не открылась: пусть лучше будет свой
                    // значок, чем клетчатый прямоугольник «битой картинки»
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !toastIcon.visible
                    text: String.fromCodePoint(root.notifUrgent ? 0xF0026 : 0xF009A)
                    color: root.notifUrgent ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: root.notifSummary
                        color: root.colFg
                        elide: Text.ElideRight
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                    Text {
                        text: root.notifApp
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    // «Показывать текст в карточке» из настроек: выключено —
                    // видно только приложение и заголовок
                    visible: root.notifBody.length > 0 && root.cfg.notifPreview
                    text: root.notifBody
                    color: root.colMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    // Спецификация разрешает в теле подмножество разметки
                    // (<b>, <i>, <u>, <a>), и мы заявляем её поддержку в
                    // bodyMarkupSupported. PlainText показывал теги как есть —
                    // Telegram присылал «<b>Паша брат</b>» прямо текстом.
                    textFormat: Text.StyledText
                    font { family: root.fontFam; pixelSize: root.fontSize - 3 }
                }
            }

            // закрыть тост
            Text {
                Layout.alignment: Qt.AlignTop
                text: "×"
                color: closeMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissToast()
                }
            }
        }

        // ---------------------------------- свёрнутое: Bluetooth устройство
        // Слева иконка устройства (наушники, мышь, клавиатура, геймпад и т.д.),
        // по центру статус (Подключено / Отключено) и имя, справа кольцо с зарядом.
        RowLayout {
            id: btCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 11
            visible: root.btToastActive && !root.clipToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4

                // Expanding radio wave ripples
                Rectangle {
                    id: btRipple1
                    anchors.centerIn: parent
                    width: 24; height: 24; radius: 12
                    color: Qt.rgba(root.colBt.r, root.colBt.g, root.colBt.b, 0.08)
                    border.color: root.btToastDisconnected ? root.colCrit : root.colBt
                    border.width: 1.5
                    scale: 0.35
                    opacity: 0.0
                    visible: opacity > 0.001
                }
                Rectangle {
                    id: btRipple2
                    anchors.centerIn: parent
                    width: 24; height: 24; radius: 12
                    color: Qt.rgba(root.colBt.r, root.colBt.g, root.colBt.b, 0.05)
                    border.color: root.btToastDisconnected ? root.colCrit : root.colBt
                    border.width: 1.5
                    scale: 0.35
                    opacity: 0.0
                    visible: opacity > 0.001
                }

                Text {
                    id: btIconText
                    anchors.centerIn: parent
                    text: root.btToastDisconnected ? String.fromCodePoint(0xF00B2)
                        : root.btToastType === "earbuds" ? String.fromCodePoint(0xF00AF)
                        : root.btToastType === "mouse" ? String.fromCodePoint(0xF098B)
                        : root.btToastType === "keyboard" ? String.fromCodePoint(0xF030C)
                        : root.btToastType === "gamepad" ? String.fromCodePoint(0xF02B4)
                        : root.btToastType === "phone" ? String.fromCodePoint(0xF011C)
                        : root.btToastType === "speaker" ? String.fromCodePoint(0xF04C3)
                        : root.btToastType === "watch" ? String.fromCodePoint(0xF0584)
                        : String.fromCodePoint(0xF00AF)
                    color: (root.btToastDisconnected || root.btToastLowBatt) ? root.colCrit : (root.themeNothing ? root.colOn : root.colBt)
                    font { family: root.fontFam; pixelSize: 22 }
                    transformOrigin: Item.Center
                }

                SequentialAnimation {
                    id: btPulseAnim
                    running: root.btToastActive && !root.btToastDisconnected
                    loops: Animation.Infinite

                    ParallelAnimation {
                        // Ripple 1
                        SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation {
                                    target: btRipple1
                                    property: "scale"
                                    from: 0.35
                                    to: 1.6
                                    duration: 700
                                    easing.type: Easing.OutQuad
                                }
                                NumberAnimation {
                                    target: btRipple1
                                    property: "opacity"
                                    from: 0.8
                                    to: 0.0
                                    duration: 700
                                    easing.type: Easing.OutQuad
                                }
                            }
                            PauseAnimation { duration: 300 }
                        }

                        // Ripple 2 (offset)
                        SequentialAnimation {
                            PauseAnimation { duration: 180 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: btRipple2
                                    property: "scale"
                                    from: 0.35
                                    to: 1.7
                                    duration: 700
                                    easing.type: Easing.OutQuad
                                }
                                NumberAnimation {
                                    target: btRipple2
                                    property: "opacity"
                                    from: 0.6
                                    to: 0.0
                                    duration: 700
                                    easing.type: Easing.OutQuad
                                }
                            }
                            PauseAnimation { duration: 120 }
                        }

                        // Bluetooth icon pop & breathe
                        SequentialAnimation {
                            NumberAnimation {
                                target: btIconText
                                property: "scale"
                                from: 1.0
                                to: 1.28
                                duration: 200
                                easing.type: Easing.OutBack
                            }
                            NumberAnimation {
                                target: btIconText
                                property: "scale"
                                from: 1.28
                                to: 0.94
                                duration: 180
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                target: btIconText
                                property: "scale"
                                from: 0.94
                                to: 1.0
                                duration: 160
                                easing.type: Easing.OutQuad
                            }
                            PauseAnimation { duration: 460 }
                        }
                    }
                }

                Connections {
                    target: root
                    function onBtToastActiveChanged() {
                        if (!root.btToastActive) {
                            btRipple1.opacity = 0;
                            btRipple2.opacity = 0;
                            btIconText.scale = 1.0;
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                transform: Translate { y: -2 }

                Text {
                    text: root.btToastLowBatt ? root.tr("Низкий заряд батареи")
                        : root.btToastDisconnected ? root.tr("Отключено")
                        : root.tr("Подключено")
                    color: (root.btToastDisconnected || root.btToastLowBatt) ? root.colCrit : root.colMuted
                    transform: Translate { y: 2 }
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
                Text {
                    Layout.maximumWidth: 220
                    text: root.btToastName
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize + 1; bold: true }
                }
            }

            // Правая часть: кольцо заряда или иконка состояния
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 48

                // Кольцо заряда при наличии батареи
                Canvas {
                    id: btRing
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery >= 0

                    readonly property real level:
                        root.btConnectedBattery >= 0 ? root.btConnectedBattery / 100 : 0
                    property real fill: 0
                    readonly property real lineW: 3.5

                    onFillChanged: requestPaint()
                    onLevelChanged: {
                        if (!root.btToastActive) return;
                        btRingAnim.stop();
                        btRingAnim.from = btRing.fill;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }

                    NumberAnimation {
                        id: btRingAnim
                        target: btRing; property: "fill"
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    function play() {
                        btRingAnim.stop();
                        btRing.fill = 0;
                        btRingAnim.from = 0;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }
                    Connections {
                        target: root
                        function onBtToastActiveChanged() {
                            if (root.btToastActive) btRing.play();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0) return;
                        var c = root.colFg;
                        if (root.btConnectedBattery >= 0 && root.btConnectedBattery <= 20) {
                            c = root.colCrit;
                        } else if (root.themeNothing) {
                            c = root.colOn;
                        } else if (root.btConnectedBattery > 20) {
                            c = root.colBt;
                        }
                        var r = (Math.min(width, height) - lineW) / 2;
                        var cx = width / 2, cy = height / 2;

                        ctx.lineWidth = lineW;
                        ctx.lineCap = "round";

                        // бледный контур
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.stroke();

                        // дуга заряда
                        if (fill > 0) {
                            var start = -Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, start, start + 2 * Math.PI * fill);
                            ctx.strokeStyle = c;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(root.btConnectedBattery)
                        color: root.btConnectedBattery <= 20 ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 6; bold: true }
                    }
                }

                // Иконка без батареи
                Rectangle {
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery < 0
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00AF)
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }

                // Индикатор отключения
                Rectangle {
                    anchors.fill: parent
                    visible: root.btToastDisconnected
                    radius: 14
                    color: Qt.rgba(1, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00B2)
                        color: root.colCrit
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }
            }
        }

        // ---- свёрнутое: зарядка подключена (чистый премиальный Dynamic Island без лишних линий)


        // ---- раскрытый остров музыки: динамический градиент и анимированная волна
        Canvas {
            id: islandMusicWave
            anchors.fill: parent
            z: 1
            visible: root.expanded && root.page === "islandmusic" && (opacity > 0.01)
            opacity: (root.expanded && root.page === "islandmusic") ? (root.mediaLyricsOpen ? 0.0 : 1.0) : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.mediaLyricsOpen ? 260 : 300
                    easing.type: Easing.OutCubic
                }
            }

            property color col1: root.mediaArtColor
            property color col2: root.mediaArtColor2
            property real phase: 0
            property real beatEnergy: 0.15

            onPhaseChanged: requestPaint()
            onBeatEnergyChanged: requestPaint()
            onCol1Changed: requestPaint()
            onCol2Changed: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: {
                if (!capsule.lyricsAnimating) requestPaint();
            }

            onVisibleChanged: {
                if (visible) CavaSource.acquire();
                else CavaSource.release();
            }
            Component.onDestruction: if (visible) CavaSource.release()

            Timer {
                interval: 24
                running: islandMusicWave.visible && (!capsule.lyricsAnimating || !root.mediaLyricsOpen)
                repeat: true
                onTriggered: {
                    var rawAudio = 0.0;
                    if (CavaSource.hasCava && CavaSource.levels && CavaSource.levels.length >= 8) {
                        // Высокая чувствительность к басовому кику (полосы 0..6)
                        var bSum = 0;
                        for (var i = 0; i < 7; i++) {
                            bSum += (CavaSource.levels[i] || 0);
                        }
                        var bass = (bSum / 7) * 2.2;

                        // Средние частоты и атака инструментов (полосы 7..14)
                        var mSum = 0;
                        for (var j = 7; j < 15; j++) {
                            mSum += (CavaSource.levels[j] || 0);
                        }
                        var mid = (mSum / 8) * 1.4;

                        rawAudio = Math.max(bass * 0.85 + mid * 0.35, bass);
                    }
                    var sensMultiplier = (root.cfg.musicWaveSens !== undefined ? root.cfg.musicWaveSens : 100) / 100.0;
                    var isPlaying = root.player && root.player.isPlaying;
                    var target = isPlaying ? Math.max(0.0, Math.min(1.0, rawAudio * sensMultiplier)) : 0.0;

                    // Реактивная атака (мгновенный отклик на бит) и плавный естественный спад
                    if (target > islandMusicWave.beatEnergy) {
                        islandMusicWave.beatEnergy = islandMusicWave.beatEnergy * 0.20 + target * 0.80;
                    } else {
                        islandMusicWave.beatEnergy = islandMusicWave.beatEnergy * 0.82 + target * 0.18;
                    }

                    // Скорость течения волны: на битах быстрее, в тишине и паузе успокаивается
                    var phaseStep = 0.020 + islandMusicWave.beatEnergy * 0.055;
                    islandMusicWave.phase += phaseStep;
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width;
                var h = height;
                if (w <= 0 || h <= 0) return;

                // 1. Клип строго по радиусам капсулы: углы ВСЕГДА идеально скруглены
                var mr = Math.min(w, h) / 2;
                var tl = Math.min(capsule.topLeftRadius, mr);
                var tr = Math.min(capsule.topRightRadius, mr);
                var br = Math.min(capsule.bottomRightRadius, mr);
                var bl = Math.min(capsule.bottomLeftRadius, mr);
                ctx.beginPath();
                ctx.moveTo(tl, 0);
                ctx.arcTo(w, 0, w, h, tr);
                ctx.arcTo(w, h, 0, h, br);
                ctx.arcTo(0, h, 0, 0, bl);
                ctx.arcTo(0, 0, w, 0, tl);
                ctx.closePath();
                ctx.clip();

                // 2. Базовый сплошной глубокий чёрный фон на всю площадь капсулы
                ctx.fillStyle = "#000000";
                ctx.fillRect(0, 0, w, h);

                var c1 = col1;
                var c2 = col2;
                var beat = beatEnergy;

                // 3. Фоновый деграде-градиент: в тишине опускается вниз, на битах мягко поднимается под кнопки
                var glowTop = h * (0.64 - beat * 0.18);
                var bgGrad = ctx.createLinearGradient(0, glowTop, 0, h);
                bgGrad.addColorStop(0.00, "rgba(0, 0, 0, 0)");
                bgGrad.addColorStop(0.35, Qt.rgba(c2.r, c2.g, c2.b, 0.15 + beat * 0.18));
                bgGrad.addColorStop(0.70, Qt.rgba(c1.r, c1.g, c1.b, 0.40 + beat * 0.25));
                bgGrad.addColorStop(1.00, Qt.rgba(c1.r, c1.g, c1.b, 0.75 + beat * 0.20));
                ctx.fillStyle = bgGrad;
                ctx.fillRect(0, glowTop, w, h - glowTop);

                // 4. Волна 1 (Задняя жидкостная волна - цвет c2: в тишине у дна h*0.84, на битах поднимается до h*0.74)
                var base1 = h * (0.84 - beat * 0.10);
                var amp1 = 3.5 + beat * 6.5;
                var k1 = (2 * Math.PI) / (w * 0.75);
                var ph1 = phase * 1.1;

                ctx.beginPath();
                ctx.moveTo(0, h);
                for (var x = 0; x <= w; x += 4) {
                    var y1 = base1 + amp1 * Math.sin(k1 * x + ph1)
                                  + (amp1 * 0.38) * Math.cos(k1 * 1.8 * x - ph1 * 0.5);
                    if (x === 0) ctx.lineTo(0, y1); else ctx.lineTo(x, y1);
                }
                ctx.lineTo(w, h);
                ctx.closePath();
                var gradWave1 = ctx.createLinearGradient(0, base1 - amp1, w, h);
                gradWave1.addColorStop(0.0, Qt.rgba(c2.r, c2.g, c2.b, 0.35 + beat * 0.22));
                gradWave1.addColorStop(1.0, Qt.rgba(c1.r, c1.g, c1.b, 0.70 + beat * 0.25));
                ctx.fillStyle = gradWave1;
                ctx.fill();

                // 5. Волна 2 (Передняя жидкостная волна - цвет c1: в тишине спокойная у h*0.86, на битах поднимается до h*0.76)
                var base2 = h * (0.86 - beat * 0.10);
                var amp2 = 4.0 + beat * 7.5;
                var k2 = (2 * Math.PI) / (w * 0.52);
                var ph2 = phase * 1.6;

                ctx.beginPath();
                ctx.moveTo(0, h);
                var wave2Points = [];
                for (var x2 = 0; x2 <= w; x2 += 3) {
                    var y2 = base2 + amp2 * Math.sin(k2 * x2 + ph2)
                                  + (amp2 * 0.35) * Math.sin(k2 * 2.1 * x2 - ph2 * 0.4);
                    wave2Points.push({x: x2, y: y2});
                    if (x2 === 0) ctx.lineTo(0, y2); else ctx.lineTo(x2, y2);
                }
                ctx.lineTo(w, h);
                ctx.closePath();
                var gradWave2 = ctx.createLinearGradient(0, base2 - amp2, 0, h);
                gradWave2.addColorStop(0.0, Qt.rgba(c1.r, c1.g, c1.b, 0.55 + beat * 0.30));
                gradWave2.addColorStop(0.50, Qt.rgba(c1.r, c1.g, c1.b, 0.75 + beat * 0.18));
                gradWave2.addColorStop(1.0, Qt.rgba(c2.r, c2.g, c2.b, 0.90 + beat * 0.08));
                ctx.fillStyle = gradWave2;
                ctx.fill();

                // 6. Тонкий световой контур по гребню волны (в тишине еле заметен, на битах загорается)
                ctx.beginPath();
                for (var i = 0; i < wave2Points.length; i++) {
                    var pt = wave2Points[i];
                    if (i === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y);
                }
                ctx.lineWidth = 1.4;
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12 + beat * 0.35);
                ctx.stroke();
            }
        }

        // Анимированный значок батареи и молнии зарядки в стиле iPhone Dynamic Island:
        // при зарядке вокруг молнии каждую секунду расходится мягкая круглая волна (ripple),
        // плавно затухающая внутри пилюли острова, а сама молния делает лёгкий тактильный микро-пульс.
        component ChargeBolt: Item {
            id: cb
            property string icon: root.batteryIcon
            property real pixelSize: root.iconSize - 2
            property color chargeColor: root.colCharge
            property color iconColor: cb.charging ? cb.chargeColor
                                    : (!root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                    : (!root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                    : root.colFg))
            property bool charging: root.batteryCharging
            property bool active: true

            implicitWidth: Math.max(16, boltText.implicitWidth + 2)
            implicitHeight: Math.max(16, boltText.implicitHeight)

            // Круглая волна (iPhone Dynamic Island charging ripple)
            Rectangle {
                id: ripple
                anchors.centerIn: parent
                width: Math.round(cb.pixelSize * 1.8)
                height: width
                radius: width / 2
                color: Qt.rgba(cb.chargeColor.r, cb.chargeColor.g, cb.chargeColor.b, 0.16)
                border.color: cb.chargeColor
                border.width: 1.5
                antialiasing: true
                scale: 0.35
                opacity: 0.0
                visible: (root.cfg.chargeRipple !== false) && opacity > 0.001
                z: 0
            }

            // Значок молнии / батареи
            Text {
                id: boltText
                anchors.centerIn: parent
                z: 1
                text: cb.icon
                color: cb.iconColor
                font {
                    family: root.fontFam
                    pixelSize: cb.pixelSize
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // Анимация волны каждые 1000 мс (1 секунда)
            SequentialAnimation {
                id: rippleAnim
                running: cb.charging && cb.active && cb.visible && cb.opacity > 0.01
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: ripple
                        property: "scale"
                        from: 0.35
                        to: 1.14
                        duration: 680
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: ripple
                        property: "opacity"
                        from: 0.85
                        to: 0.0
                        duration: 680
                        easing.type: Easing.OutQuad
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: boltText
                            property: "scale"
                            from: 1.0
                            to: 1.18
                            duration: 160
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: boltText
                            property: "scale"
                            from: 1.18
                            to: 1.0
                            duration: 240
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation {
                            duration: 280
                        }
                    }
                }
                PauseAnimation {
                    duration: 320
                }
            }

            onChargingChanged: {
                if (!charging) {
                    ripple.opacity = 0;
                    ripple.scale = 0.35;
                    boltText.scale = 1.0;
                }
            }
        }

        // ---- свёрнутое: тост зарядки (REDISEÑADO DESDE CERO - Dynamic Island) ------------
        Item {
            id: acCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: acRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.acToastActive && !root.lowBattToastActive && !root.fullBattToastActive && !root.powerProfileToastActive && !root.kbdLightToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            RowLayout {
                id: acRow
                anchors.centerIn: parent
                spacing: 16

                // 1. Слева: светящийся бейдж с молнией и пульсирующей аурой (iOS / Nothing)
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 32
                    implicitHeight: 32

                    // Пульсирующая внешняя волна энергии
                    Rectangle {
                        id: acPulseRing
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        radius: 16
                        color: "transparent"
                        border.color: root.colCharge
                        border.width: 1.5
                        scale: 0.7
                        opacity: 0.0

                        SequentialAnimation on scale {
                            running: root.acToastActive
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.7; to: 1.55; duration: 900; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 250 }
                        }
                        SequentialAnimation on opacity {
                            running: root.acToastActive
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.85; to: 0.0; duration: 900; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 250 }
                        }
                    }

                    // Бейдж-сквиркл
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 9
                        color: Qt.rgba(root.colCharge.r, root.colCharge.g, root.colCharge.b, 0.22)
                        border.color: Qt.rgba(root.colCharge.r, root.colCharge.g, root.colCharge.b, 0.50)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF0241)
                            color: root.colCharge
                            font { family: root.fontFam; pixelSize: 15 }
                            scale: acBoltPulse.scaleVal

                            Item {
                                id: acBoltPulse
                                property real scaleVal: 1.0
                                SequentialAnimation on scaleVal {
                                    running: root.acToastActive
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 1.22; duration: 220; easing.type: Easing.OutBack }
                                    NumberAnimation { from: 1.22; to: 1.0; duration: 320; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: 610 }
                                }
                            }
                        }
                    }
                }

                // 2. По центру: двухуровневая типографика (Заголовок + Подзаголовок)
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                        text: ((root.cfg.chargeText && root.cfg.chargeText.length > 0) ? root.cfg.chargeText : root.tr("Заряжается"))
                        color: root.colFg
                        font {
                            family: root.fontFam
                            pixelSize: root.fontSize
                            bold: true
                        }
                    }

                    Text {
                        text: root.tr("Питание от сети")
                        color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.60)
                        font {
                            family: root.fontFam
                            pixelSize: root.fontSize - 4
                        }
                    }
                }

                // 3. Справа: процент заряда и эстетичная батарея iOS с живым заполнением и переливом
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 9

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.batteryPct + "%"
                        color: root.colCharge
                        font {
                            family: root.fontFam
                            pixelSize: root.fontSize + 1
                            bold: true
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 35
                        implicitHeight: 16

                        // Внешний корпус батареи
                        Rectangle {
                            id: acBattShell
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 29
                            height: 15
                            radius: 4
                            color: "transparent"
                            border.color: root.colCharge
                            border.width: 1.5
                            clip: true

                            // Внутренний уровень заряда
                            Rectangle {
                                id: acBattFill
                                anchors.left: parent.left
                                anchors.leftMargin: 1.5
                                anchors.top: parent.top
                                anchors.topMargin: 1.5
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1.5
                                width: Math.max(4, Math.round((acBattShell.width - 3) * Math.max(0.08, root.batteryPct / 100)))
                                radius: 2.5
                                color: root.colCharge

                                // Световой блик / волна энергии по индикатору заряда
                                Rectangle {
                                    id: acShimmer
                                    width: 8
                                    height: parent.height
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    radius: 2

                                    SequentialAnimation on x {
                                        running: root.acToastActive
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -8; to: acBattFill.width; duration: 950; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }
                            }
                        }

                        // Плюсовой контакт справа
                        Rectangle {
                            anchors.left: acBattShell.right
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 6
                            radius: 1
                            color: root.colCharge
                        }
                    }
                }
            }
        }

        // ---- свёрнутое: тост низкой батареи (iPhone Dynamic Island) ------------
        Item {
            id: lowBattCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: lowBattRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.lowBattToastActive && !root.fullBattToastActive && !root.powerProfileToastActive && !root.kbdLightToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            readonly property int currentPct: root.lowBattAlertPct !== undefined ? root.lowBattAlertPct : root.batteryPct
            readonly property bool isCriticalBatt: currentPct <= (root.cfg.lowBatteryCritThreshold !== undefined ? root.cfg.lowBatteryCritThreshold : 15)
            readonly property color lowBattColor: isCriticalBatt ? root.colBattCrit : root.colBattWarn
            readonly property color lowBattBadgeBg: isCriticalBatt
                ? Qt.rgba(root.colBattCrit.r, root.colBattCrit.g, root.colBattCrit.b, 0.24)
                : Qt.rgba(root.colBattWarn.r, root.colBattWarn.g, root.colBattWarn.b, 0.24)

            RowLayout {
                id: lowBattRow
                anchors.centerIn: parent
                spacing: 24

                // Текст слева: 20% Batería / 15% Batería
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: lowBattCapsule.currentPct + "% " + (lowBattCapsule.isCriticalBatt ? ((root.cfg.battCritText && root.cfg.battCritText.length > 0) ? root.cfg.battCritText : root.tr("Batería crítica")) : ((root.cfg.battWarnText && root.cfg.battWarnText.length > 0) ? root.cfg.battWarnText : root.tr("Batería baja")))
                    color: root.colFg
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize
                        bold: true
                    }
                }

                // Оранжевый/красный бейдж справа с батареей и пульсирующей волной
                Rectangle {
                    id: lowBattBadge
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 64
                    implicitHeight: 28
                    radius: 14
                    color: lowBattCapsule.lowBattBadgeBg

                    Item {
                        anchors.centerIn: parent
                        width: 33
                        height: 16

                        // Внешний корпус батареи в стиле iOS
                        Rectangle {
                            id: battShell
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 29
                            height: 15
                            radius: 4
                            color: "transparent"
                            border.color: lowBattCapsule.lowBattColor
                            border.width: 1.5
                            clip: true

                            // Внутренний уровень заряда (касается верхнего и нижнего краёв без зазора)
                            Rectangle {
                                id: battFill
                                anchors.left: parent.left
                                anchors.leftMargin: 1.5
                                anchors.top: parent.top
                                anchors.topMargin: 1.5
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1.5
                                width: Math.max(4, Math.round((battShell.width - 3) * Math.max(0.08, lowBattCapsule.currentPct / 100)))
                                radius: 2.5
                                color: lowBattCapsule.lowBattColor
                            }
                        }

                        // Плюсовой контакт батареи справа
                        Rectangle {
                            anchors.left: battShell.right
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 6
                            radius: 1
                            color: lowBattCapsule.lowBattColor
                        }

                        // Пульсирующая волна вокруг индикатора уровня
                        Rectangle {
                            id: lowBattRipple
                            anchors.verticalCenter: battShell.verticalCenter
                            anchors.horizontalCenter: battShell.left
                            anchors.horizontalCenterOffset: Math.min(battShell.width / 2, Math.max(6, battFill.width / 2 + 2))
                            width: 18
                            height: 22
                            radius: 9
                            color: "transparent"
                            border.color: lowBattCapsule.lowBattColor
                            border.width: 2.0
                            scale: 0.6
                            opacity: 0.0

                            SequentialAnimation on scale {
                                running: root.lowBattToastActive
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.6; to: 1.45; duration: 800; easing.type: Easing.OutQuad }
                                PauseAnimation { duration: 200 }
                            }
                            SequentialAnimation on opacity {
                                running: root.lowBattToastActive
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.95; to: 0.0; duration: 800; easing.type: Easing.OutQuad }
                                PauseAnimation { duration: 200 }
                            }
                        }
                    }
                }
            }
        }

        // ---- свёрнутое: тост полного заряда (100% Fully Charged / 80% Charged) ------------
        Item {
            id: fullBattCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: fullBattRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.fullBattToastActive && !root.powerProfileToastActive && !root.kbdLightToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            RowLayout {
                id: fullBattRow
                anchors.centerIn: parent
                spacing: 20

                // Текст слева: 100% Carga completa / 80% Carga al 80%
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    Text {
                        text: (root.chargeAlertPct || 100) + "%"
                        color: root.colCharge
                        font {
                            family: root.fontFam
                            pixelSize: root.fontSize + 1
                            bold: true
                        }
                    }

                    Text {
                        text: root.chargeAlertPct >= 100
                            ? ((root.cfg.battFullText && root.cfg.battFullText.length > 0) ? root.cfg.battFullText : root.tr("Carga completa"))
                            : ((root.cfg.batt80Text && root.cfg.batt80Text.length > 0) ? root.cfg.batt80Text : root.tr("Carga al 80%"))
                        color: root.colFg
                        font {
                            family: root.fontFam
                            pixelSize: root.fontSize - 1
                            bold: true
                        }
                    }
                }

                // Зелёный бейдж справа с батареей и плавной анимацией заполнения
                Rectangle {
                    id: fullBattBadge
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 68
                    implicitHeight: 28
                    radius: 14
                    color: Qt.rgba(root.colCharge.r, root.colCharge.g, root.colCharge.b, 0.22)
                    border.color: Qt.rgba(root.colCharge.r, root.colCharge.g, root.colCharge.b, 0.45)
                    border.width: 1

                    Item {
                        anchors.centerIn: parent
                        width: 35
                        height: 16

                        // Внешний корпус батареи iOS
                        Rectangle {
                            id: fullBattShell
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 29
                            height: 15
                            radius: 4
                            color: "transparent"
                            border.color: root.colCharge
                            border.width: 1.5
                            clip: true

                            // Внутренний уровень заряда с плавной анимацией заполнения (касается верхнего и нижнего краёв)
                            Rectangle {
                                id: fullBattFill
                                anchors.left: parent.left
                                anchors.leftMargin: 1.5
                                anchors.top: parent.top
                                anchors.topMargin: 1.5
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1.5
                                radius: 2.5
                                color: root.colCharge

                                readonly property real maxW: fullBattShell.width - 3
                                width: 0

                                ParallelAnimation {
                                    id: fullFillAnim
                                    running: root.fullBattToastActive

                                    NumberAnimation {
                                        target: fullBattFill
                                        property: "width"
                                        from: 2
                                        to: Math.round(fullBattFill.maxW * Math.min(1.0, (root.chargeAlertPct || 100) / 100))
                                        duration: 1100
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: fillShimmer
                                        property: "x"
                                        from: -8
                                        to: fullBattFill.maxW + 4
                                        duration: 1200
                                        easing.type: Easing.InOutQuad
                                    }
                                }

                                // Скользящий блик поверх заполнения
                                Rectangle {
                                    id: fillShimmer
                                    width: 8
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    radius: 1
                                    color: Qt.rgba(1, 1, 1, 0.50)
                                    x: -8
                                }
                            }
                        }

                        // Плюсовой контакт батареи справа
                        Rectangle {
                            anchors.left: fullBattShell.right
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 6
                            radius: 1
                            color: root.colCharge
                        }

                        // Финальная вспышка-волна при достижении целевого заряда
                        Rectangle {
                            id: fullBattRipple
                            anchors.centerIn: fullBattShell
                            width: fullBattShell.width + 6
                            height: fullBattShell.height + 6
                            radius: 7
                            color: "transparent"
                            border.color: root.colCharge
                            border.width: 2.0
                            scale: 0.9
                            opacity: 0.0

                            SequentialAnimation on scale {
                                running: root.fullBattToastActive
                                PauseAnimation { duration: 900 }
                                NumberAnimation { from: 0.9; to: 1.50; duration: 650; easing.type: Easing.OutQuad }
                            }
                            SequentialAnimation on opacity {
                                running: root.fullBattToastActive
                                PauseAnimation { duration: 900 }
                                NumberAnimation { from: 0.8; to: 0.0; duration: 650; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }
        }

        // ---- свёрнутое: тост профиля питания (Lenovo LOQ Fn+Q / Modo Ahorro, Equilibrado, Rendimiento) ------------
        Item {
            id: powerProfileCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: profileRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.powerProfileToastActive && !root.kbdLightToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            readonly property string prof: root.powerProfile || "balanced"
            readonly property color profColor: root.powerProfileColor

            readonly property string profTitle:
                prof === "power-saver" ? root.tr("Modo Ahorro")
              : prof === "performance" ? root.tr("Modo Rendimiento")
                                       : root.tr("Modo Equilibrado")

            readonly property string profSub:
                prof === "power-saver" ? root.tr("Silencioso")
              : prof === "performance" ? root.tr("Máximo rendimiento")
                                       : root.tr("Equilibrio estándar")

            readonly property string profGlyph:
                prof === "power-saver" ? String.fromCodePoint(0xF0328)
              : prof === "performance" ? String.fromCodePoint(0xF0238)
                                       : String.fromCodePoint(0xF0538)

            RowLayout {
                id: profileRow
                anchors.centerIn: parent
                spacing: 10

                // Badge animado con icono a la izquierda
                Rectangle {
                    id: profBadge
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 30
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(powerProfileCapsule.profColor.r, powerProfileCapsule.profColor.g, powerProfileCapsule.profColor.b, 0.16)
                    border.color: Qt.rgba(powerProfileCapsule.profColor.r, powerProfileCapsule.profColor.g, powerProfileCapsule.profColor.b, 0.45)
                    border.width: 1

                    // Onda concéntrica pulsante
                    Rectangle {
                        id: profRipple
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: width / 2
                        color: "transparent"
                        border.color: powerProfileCapsule.profColor
                        border.width: 1.5
                        opacity: 0
                    }

                    Text {
                        id: profGlyphTxt
                        anchors.centerIn: parent
                        text: powerProfileCapsule.profGlyph
                        color: powerProfileCapsule.profColor
                        font {
                            family: root.fontFam
                            pixelSize: 13
                        }
                    }

                    ParallelAnimation {
                        id: profAnim
                        running: root.powerProfileToastActive

                        NumberAnimation {
                            target: profRipple
                            property: "width"
                            from: 18; to: 44
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: profRipple
                            property: "height"
                            from: 18; to: 44
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: profRipple
                            property: "opacity"
                            from: 0.9; to: 0.0
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: profGlyphTxt
                                property: "scale"
                                from: 0.7; to: 1.25
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                            NumberAnimation {
                                target: profGlyphTxt
                                property: "scale"
                                to: 1.0
                                duration: 160
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                // Título del perfil
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: powerProfileCapsule.profTitle
                    color: powerProfileCapsule.profColor
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize
                        bold: true
                    }
                }

                // Separador sutil
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "·"
                    color: Qt.rgba(1, 1, 1, 0.3)
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize - 1
                    }
                }

                // Subtítulo descriptivo horizontal
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: powerProfileCapsule.profSub
                    color: root.colMuted
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize - 2
                    }
                }
            }
        }

        // ---- свёрнутое: тост яркости клавиатуры (Lenovo LOQ Fn+Space / 0%, 50%, 100%) ------------
        Item {
            id: kbdLightCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: kbdRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.kbdLightToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            readonly property int lvl: root.kbdLightLevel
            readonly property string lvlPercent: lvl === 2 ? "100%" : (lvl === 1 ? "50%" : "0%")
            readonly property color lvlColor: lvl === 2 ? root.colOn : (lvl === 1 ? root.colFg : root.colMuted)

            readonly property string lvlSub:
                lvl === 2 ? root.tr("Brillo Máximo")
              : lvl === 1 ? root.tr("Brillo Medio")
                          : root.tr("Apagado")

            function triggerAnim() {
                if (kbdAnim) kbdAnim.restart();
            }
            onLvlChanged: triggerAnim()

            RowLayout {
                id: kbdRow
                anchors.centerIn: parent
                spacing: 10

                // Badge animado con icono de teclado a la izquierda
                Rectangle {
                    id: kbdBadge
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 30
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(kbdLightCapsule.lvlColor.r, kbdLightCapsule.lvlColor.g, kbdLightCapsule.lvlColor.b, 0.16)
                    border.color: Qt.rgba(kbdLightCapsule.lvlColor.r, kbdLightCapsule.lvlColor.g, kbdLightCapsule.lvlColor.b, 0.45)
                    border.width: 1

                    // Onda concéntrica pulsante
                    Rectangle {
                        id: kbdRipple
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: width / 2
                        color: "transparent"
                        border.color: kbdLightCapsule.lvlColor
                        border.width: 1.5
                        opacity: 0
                    }

                    Text {
                        id: kbdIconTxt
                        anchors.centerIn: parent
                        text: "󰌌"
                        color: kbdLightCapsule.lvlColor
                        font { family: root.fontFam; pixelSize: 13 }
                    }

                    ParallelAnimation {
                        id: kbdAnim
                        running: root.kbdLightToastActive

                        NumberAnimation {
                            target: kbdRipple
                            property: "width"
                            from: 18; to: 44
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: kbdRipple
                            property: "height"
                            from: 18; to: 44
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: kbdRipple
                            property: "opacity"
                            from: 0.85; to: 0.0
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: kbdIconTxt
                                property: "scale"
                                from: 0.7; to: 1.25
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                            NumberAnimation {
                                target: kbdIconTxt
                                property: "scale"
                                to: 1.0
                                duration: 160
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                // Título "Teclado"
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.tr("Teclado")
                    color: root.colFg
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize
                        bold: true
                    }
                }

                // Chip de porcentaje: 100% / 50% / 0%
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: kbdPctTxt.implicitWidth + 12
                    implicitHeight: 20
                    radius: 10
                    color: Qt.rgba(kbdLightCapsule.lvlColor.r, kbdLightCapsule.lvlColor.g, kbdLightCapsule.lvlColor.b, 0.18)
                    border.color: Qt.rgba(kbdLightCapsule.lvlColor.r, kbdLightCapsule.lvlColor.g, kbdLightCapsule.lvlColor.b, 0.40)
                    border.width: 1

                    Text {
                        id: kbdPctTxt
                        anchors.centerIn: parent
                        text: kbdLightCapsule.lvlPercent
                        color: kbdLightCapsule.lvlColor
                        font {
                            family: root.fontBody
                            pixelSize: root.fontSize - 3
                            bold: true
                        }
                    }
                }

                // Separador sutil
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "·"
                    color: Qt.rgba(1, 1, 1, 0.3)
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize - 1
                    }
                }

                // Subtítulo descriptivo
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: kbdLightCapsule.lvlSub
                    color: root.colMuted
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize - 2
                    }
                }

                // Indicador visual de 2 etapas LED de hardware
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    spacing: 4

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: kbdLightCapsule.lvl >= 1 ? kbdLightCapsule.lvlColor : Qt.rgba(1, 1, 1, 0.18)
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: kbdLightCapsule.lvl >= 2 ? kbdLightCapsule.lvlColor : Qt.rgba(1, 1, 1, 0.18)
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }
        }

        // ---- свёрнутое: тост буфера обмена (Clipboard Flash) ------------
        Item {
            id: clipCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: clipRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.clipToastActive && !root.btToastActive && !root.acToastActive && !root.lowBattToastActive && !root.fullBattToastActive && !root.powerProfileToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            RowLayout {
                id: clipRow
                anchors.centerIn: parent
                spacing: 9

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 26
                    implicitHeight: 22
                    radius: 7
                    color: Qt.rgba(root.colOn.r, root.colOn.g, root.colOn.b, 0.20)
                    border.color: Qt.rgba(root.colOn.r, root.colOn.g, root.colOn.b, 0.50)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅍"
                        color: root.colOn
                        font { family: root.fontFam; pixelSize: 12 }
                    }
                }

                Text {
                    text: root.tr("Copiado")
                    color: root.colOn
                    font { family: root.fontBody; pixelSize: root.fontSize - 3; bold: true }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: clipTxt.implicitWidth + 14
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Text {
                        id: clipTxt
                        anchors.centerIn: parent
                        text: root.clipToastText
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Aura reactiva de reproducción en Notch (Audio Ripple)
        Rectangle {
            id: notchAudioGlow
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.70
            height: 2
            radius: 1
            visible: !root.expanded && root.mediaPlaying && (root.cfg.notchAudioRipple !== false)
            opacity: visible ? 0.75 : 0
            color: (root.mediaArtColor && root.mediaArtColor !== "#000000") ? root.mediaArtColor : root.colOn
            SequentialAnimation on opacity {
                running: notchAudioGlow.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.85; duration: 900; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on width {
                running: notchAudioGlow.visible
                loops: Animation.Infinite
                NumberAnimation { to: capsule.width * 0.88; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: capsule.width * 0.55; duration: 1100; easing.type: Easing.InOutSine }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ---- Тост «Камера заблокирована / разблокирована» ----------------
        Item {
            id: cameraCapsule
            z: 110
            anchors.centerIn: parent
            implicitWidth: camRow.implicitWidth
            implicitHeight: root.pillH
            visible: root.cameraToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            readonly property bool isBlocked: root.cameraBlocked
            readonly property color camColor: isBlocked ? root.colCrit : (root.themeMaterial ? root.colOn : root.colCharge)
            readonly property string camTitle: root.tr("Cámara")
            readonly property string camSub: isBlocked ? root.tr("Obturador cerrado · Privacidad") : root.tr("Obturador abierto · Activa")
            readonly property string camIcon: isBlocked ? "󰄂" : "󰄀"

            function triggerAnim() {
                if (camAnim) camAnim.restart();
            }
            onIsBlockedChanged: triggerAnim()

            RowLayout {
                id: camRow
                anchors.centerIn: parent
                spacing: 10

                // Badge animado con icono de cámara
                Rectangle {
                    id: camBadge
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 30
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(cameraCapsule.camColor.r, cameraCapsule.camColor.g, cameraCapsule.camColor.b, 0.16)
                    border.color: Qt.rgba(cameraCapsule.camColor.r, cameraCapsule.camColor.g, cameraCapsule.camColor.b, 0.45)
                    border.width: 1

                    // Onda concéntrica pulsante
                    Rectangle {
                        id: camRipple
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: width / 2
                        color: "transparent"
                        border.color: cameraCapsule.camColor
                        border.width: 1.5
                        opacity: 0
                    }

                    Text {
                        id: camIconTxt
                        anchors.centerIn: parent
                        text: cameraCapsule.camIcon
                        color: cameraCapsule.camColor
                        font { family: root.fontFam; pixelSize: 13 }
                    }

                    ParallelAnimation {
                        id: camAnim
                        running: root.cameraToastActive

                        NumberAnimation {
                            target: camRipple
                            property: "width"
                            from: 18; to: 44
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: camRipple
                            property: "height"
                            from: 18; to: 44
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: camRipple
                            property: "opacity"
                            from: 0.85; to: 0.0
                            duration: 700
                            easing.type: Easing.OutQuad
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: camIconTxt
                                property: "scale"
                                from: 0.7; to: 1.25
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                            NumberAnimation {
                                target: camIconTxt
                                property: "scale"
                                to: 1.0
                                duration: 160
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }

                // Título: "Cámara"
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: cameraCapsule.camTitle
                    color: root.colFg
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize
                        bold: true
                    }
                }

                // Chip de estado: Bloqueada / Desbloqueada
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: camStatusTxt.implicitWidth + 12
                    implicitHeight: 20
                    radius: 10
                    color: Qt.rgba(cameraCapsule.camColor.r, cameraCapsule.camColor.g, cameraCapsule.camColor.b, 0.18)
                    border.color: Qt.rgba(cameraCapsule.camColor.r, cameraCapsule.camColor.g, cameraCapsule.camColor.b, 0.40)
                    border.width: 1

                    Text {
                        id: camStatusTxt
                        anchors.centerIn: parent
                        text: cameraCapsule.isBlocked ? root.tr("Bloqueada") : root.tr("Desbloqueada")
                        color: cameraCapsule.camColor
                        font {
                            family: root.fontBody
                            pixelSize: root.fontSize - 3
                            bold: true
                        }
                    }
                }

                // Separador sutil
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "·"
                    color: Qt.rgba(1, 1, 1, 0.3)
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize - 1
                    }
                }

                // Subtítulo descriptivo
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: cameraCapsule.camSub
                    color: root.colMuted
                    font {
                        family: root.fontFam
                        pixelSize: root.fontSize - 2
                    }
                }

                // Indicador visual de estado de privacidad
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: cameraCapsule.camColor
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }

        // ---- свёрнутое: выбор экрана для записи -------------------------
        // Несколько мониторов — спрашиваем, какой писать: значок записи,
        // подпись и по чипу на каждый экран. Клик по чипу запускает запись
        // именно этого выхода; × отменяет. z выше остальных капсул — карточка
        // интерактивная, клики должны доходить до чипов.
        RowLayout {
            id: recPickCapsule
            z: 130
            anchors.centerIn: parent
            spacing: 9
            visible: root.recPickActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF044A)
                color: root.colCrit
                font { family: root.fontFam; pixelSize: root.iconSize + 2 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.tr("Записать экран")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Repeater {
                model: root.recPickMons
                delegate: Rectangle {
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    radius: 9
                    implicitWidth: chipTxt.implicitWidth + 20
                    implicitHeight: 26
                    color: chipMa.containsMouse ? root.colOn : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: modelData.name
                        color: chipMa.containsMouse ? "#ffffff" : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startRecordOn(modelData.name)
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "×"
                color: pickCloseMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                MouseArea {
                    id: pickCloseMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRecPick()
                }
            }
        }

        // ---- свёрнутое: голосовой ввод (voxtype) ------------------------
        // Пока зажата кнопка/клавиша — «Слушаю…» с живым эквалайзером микрофона (cava);
        // после отпускания, пока voxtype печатает текст, — «Расшифровываю…».
        RowLayout {
            id: voxCapsule
            z: 120
            anchors.centerIn: parent
            spacing: 10
            visible: root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF036C)   // микрофон
                color: root.voxState === "listening"
                    ? (root.themeNothing ? root.colCrit : root.colVox)
                    : (root.themeNothing ? root.colFg : root.colOn)
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }

                SequentialAnimation on opacity {
                    running: root.voxState === "transcribing" && root.cfg.animStatusPulse
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.35; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                }
                onVisibleChanged: if (!visible) opacity = 1
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.voxState === "transcribing" ? root.tr("Расшифровываю…")
                                                       : root.tr("Слушаю…")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            MicWaveBars {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 18
                visible: root.voxState === "listening"
                active: root.voxState === "listening" && root.voxActive
                barColor: root.themeNothing ? root.colCrit : root.colVox
                barCount: 9
                gap: 2.5
            }
        }

        // ------------------------------------------- свёрнутое: уровень (OSD)
        RowLayout {
            id: osdCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 12
            visible: root.osdActive && !root.toastActive && !root.anySystemToastActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                text: root.osdIcon
                color: root.osdMuted ? root.colMuted : root.colFg
                // Ширина зафиксирована: глифы громкости, микрофона и солнца
                // разной ширины, из-за чего пилюля дёргалась при смене уровня.
                Layout.preferredWidth: mOsdIcon.width + 4
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.iconSize }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 5
                Layout.alignment: Qt.AlignVCenter
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.16)

                Rectangle {
                    width: parent.width * (root.osdMuted ? 0 : root.osdValue)
                    height: parent.height
                    radius: 3
                    color: root.osdKind === "bright" ? root.colWarn : root.colOn
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            Text {
                Layout.preferredWidth: mBatt.width
                horizontalAlignment: Text.AlignRight
                text: root.osdMuted ? "—" : Math.round(root.osdValue * 100) + "%"
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
        }

        // Эталоны ширины: числа в пилюле занимают место по самому широкому
        // варианту, поэтому капсула не растягивается и не сужается на ходу.
        TextMetrics {
            id: mClock
            font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            // Эталон под самый широкий вариант ИМЕННО текущего формата:
            // с секундами строка длиннее, а место под неё резервировалось
            // старое — часы налезали на соседей, и остров стоял впритык.
            text: (root.cfg.clock12 ? "12:00" : "00:00")
                  + (root.cfg.clockSeconds ? ":00" : "")
                  + (root.cfg.clock12 ? " PM" : "")
        }
        TextMetrics {
            id: mBatt
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "100%"
        }
        TextMetrics {
            id: mBattIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            // глифы заряда моноширинные между собой, хватит одного образца
            text: String.fromCodePoint(0xF0079)
        }
        TextMetrics {
            id: mOsdIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            // самый широкий из используемых глифов уровня
            text: String.fromCodePoint(0xF057E)
        }
        TextMetrics {
            id: mWs
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "10"
        }

        // ---------------------------------------------------- свёрнутое: покой
        RowLayout {
            id: idleCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: root.cfg.notchSectionGap || 14
            // На теме Nothing свёрнутый остров устроен иначе — его собирает
            // nothingCapsule, а эта раскладка целиком уступает ему место.
            visible: !root.themeNothing && !root.themeMaterial && !root.musicIslandActive && (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.anyToastActive
            // Прозрачностью, а не visible: у скрытой раскладки implicitWidth
            // равен нулю, и остров считал бы свою длину по пустоте.
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }


            // идёт долгая работа — значок, подпись и полоска слева от даты
            RowLayout {
                spacing: 7
                visible: root.busyLabel.length > 0

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busyGlyph
                    color: root.colOn
                    font { family: root.fontFam; pixelSize: root.fontSize - 2 }
                }

                Text {
                    Layout.maximumWidth: 130
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busyLabel
                    color: root.colFg
                    elide: Text.ElideMiddle
                    font { family: root.fontFam; pixelSize: root.fontSize - 2 }
                }

                // Полоска, а не проценты цифрами: остров и так узкий, а точное
                // число тут никому не нужно — важно, что дело движется.
                Rectangle {
                    id: busyTrack
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 4
                    Layout.alignment: Qt.AlignVCenter
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)
                    clip: true

                    readonly property bool unknown: root.busyProgress < 0

                    Rectangle {
                        id: busyFill
                        // Пока проценты неизвестны, короткий отрезок ходит
                        // туда-обратно: полоса в ноль читалась бы как «ничего
                        // не происходит», а полная — как «уже готово».
                        width: busyTrack.unknown ? parent.width * 0.4
                             : parent.width * Math.min(100, root.busyProgress) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.colOn
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                        SequentialAnimation on x {
                            running: busyTrack.unknown && busyTrack.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: busyTrack.width - busyFill.width
                                              duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: busyTrack.width - busyFill.width; to: 0
                                              duration: 900; easing.type: Easing.InOutSine }
                        }
                        onXChanged: if (!busyTrack.unknown) x = 0
                    }
                }

                // разделитель — чтобы работа читалась отдельно от часов
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            // идёт запись — мигающая точка и таймер слева от даты
            RowLayout {
                spacing: 6
                visible: root.recActive

                Rectangle {
                    Layout.preferredWidth: 9
                    Layout.preferredHeight: 9
                    Layout.alignment: Qt.AlignVCenter
                    radius: 5
                    color: root.recPaused ? root.colWarn : root.colCrit
                    // на паузе точка горит ровно, при записи — пульсирует
                    SequentialAnimation on opacity {
                        running: root.recActive && !root.recPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: if (!visible) opacity = 1
                }
                Text {
                    text: root.recTimeText
                    color: root.recPaused ? root.colWarn : root.colCrit
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
            }

            // Погода перед датой: значок и градусы. Виджетов на обоях у этой
            // темы нет, и остров — единственное место, где погода вообще
            // видна, поэтому она здесь, а не только на Nothing.
            Item {
                visible: root.weatherReady && root.cfg.weatherOnIsland
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: islWthRow1.implicitWidth + 8
                implicitHeight: islWthRow1.implicitHeight

                RowLayout {
                    id: islWthRow1
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.weatherGlyph
                        color: islWthMa1.containsMouse ? root.colOn : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.weatherTemp + "°"
                        color: islWthMa1.containsMouse ? root.colOn : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                }

                MouseArea {
                    id: islWthMa1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWeatherDetails()
                }

                // разделитель — чтобы погода читалась отдельно от даты
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 14
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            Text {
                text: root.dayText
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
            Text {
                text: root.timeText
                color: root.colFg
                Layout.preferredWidth: mClock.width
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            // номер текущего рабочего стола: перелистывается при смене
            FlipText {
                value: String(root.wsId)
                textColor: root.colFg
                fontFam: root.fontFam
                pixelSize: root.fontSize - 1
                minWidth: mWs.width
                Layout.alignment: Qt.AlignVCenter
            }

            // текущая раскладка: перелистывается при Alt+Shift
            FlipText {
                value: root.kbLayout
                textColor: root.colFg
                fontFam: root.fontFam
                pixelSize: root.fontSize - 2
                Layout.alignment: Qt.AlignVCenter
            }

            // Место резервируется под самый широкий вариант («100%»), иначе
            // пилюля дышала бы на каждом проценте. Но раньше эталонная
            // ширина висела на самом числе, и весь запас копился между
            // иконкой и цифрами — на «48%» там зияла дыра. Теперь ширину
            // держит контейнер, а пара внутри стоит по центру вплотную.
            Item {
                // без батареи блока нет совсем: на настольной машине это не
                // «ноль процентов», а «нечему показываться»
                visible: root.batteryPresent
                Layout.preferredWidth: root.batteryPresent
                                       ? mBattIcon.width + battPair.spacing + mBatt.width : 0
                Layout.preferredHeight: root.pillH
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: battPair
                    anchors.centerIn: parent
                    spacing: root.cfg.notchBatteryGap || 6

                    ChargeBolt {
                        Layout.alignment: Qt.AlignVCenter
                        pixelSize: root.iconSize
                        active: !root.musicIslandActive && !root.themeNothing
                    }
                    Text {
                        text: root.batteryPct + "%"
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                }
            }
        }

        // ------------------------------------------ свёрнутое: Nothing OS & Material Design 3
        // Unificación adaptativa limpia: conserva al 100% las fuentes, dimensiones,
        // animaciones con rebote (OutBack), iconos y atajos de interacción sin duplicar código.
        Item {
            id: modernCapsule
            anchors.fill: parent
            height: root.pillH
            visible: (root.themeNothing || root.themeMaterial) && !root.musicIslandActive && (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.anyToastActive
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            implicitWidth: modernRow.implicitWidth + 36

            RowLayout {
                id: modernRow
                anchors.centerIn: parent
                spacing: root.themeNothing ? 14 : 16

                // ------------------------------------------- слева/izquierda: запись, столы/escritorios, погода/clima
                RowLayout {
                    id: modernLeft
                    Layout.alignment: Qt.AlignVCenter
                    spacing: root.themeNothing ? 25 : 16

                    // Punto de grabación / Индикатор записи
                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        Layout.alignment: Qt.AlignVCenter
                        radius: 4
                        visible: root.recActive
                        color: root.recPaused ? root.colWarn : root.colCrit
                        SequentialAnimation on opacity {
                            running: root.recActive && !root.recPaused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                        }
                        onVisibleChanged: if (!visible) opacity = 1
                    }

                    // Píldoras / puntos de escritorios
                    RowLayout {
                        id: modernWsRow
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Repeater {
                            model: root.wsList

                            Rectangle {
                                required property var modelData
                                readonly property bool here: modelData === root.wsId
                                property real len: here ? (root.themeNothing ? 17 : 18) : 6
                                property bool settled: false
                                Component.onCompleted: settled = true

                                Layout.preferredWidth: len
                                Layout.preferredHeight: 6
                                Layout.alignment: Qt.AlignVCenter
                                radius: 3
                                color: here ? ((root.musicIslandActive && root.themeMaterial) ? root.mediaArtColor : (root.themeMaterial ? root.colOn : root.colFg)) : root.colFg
                                opacity: here ? 1.0 : (modernWsMa.containsMouse ? (root.themeNothing ? 0.6 : 0.65) : (root.themeNothing ? 0.3 : 0.28))

                                Behavior on len {
                                    enabled: settled
                                    NumberAnimation {
                                        duration: root.themeMaterial ? 220 : root.animMs
                                        easing.type: root.themeMaterial ? Easing.OutBack : Easing.OutCubic
                                        easing.overshoot: 1.15
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on opacity {
                                    enabled: settled
                                    NumberAnimation { duration: root.animFast }
                                }

                                MouseArea {
                                    id: modernWsMa
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.gotoWorkspace(modelData)
                                }
                            }
                        }
                    }

                    // Clima / Погода (Nothing: DotIcon + Text / Material 3: Glyph + Text Bold)
                    Item {
                        visible: root.weatherReady && root.cfg.weatherOnIsland
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: modernWthRow.implicitWidth
                        implicitHeight: modernWthRow.implicitHeight

                        RowLayout {
                            id: modernWthRow
                            anchors.fill: parent
                            spacing: 5

                            // Nothing: DotIcon
                            DotIcon {
                                visible: root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                code: root.weatherIcon
                                size: root.dotHClock
                                color: modernWthMa.containsMouse ? root.colOn : root.colFg
                            }

                            // Material 3: Nerd Glyph
                            Text {
                                visible: !root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                text: root.weatherGlyph
                                color: modernWthMa.containsMouse ? root.colOn : root.colFg
                                font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            // Texto de temperatura
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: root.weatherTemp + "°"
                                color: modernWthMa.containsMouse ? root.colOn : root.colFg
                                font {
                                    family: root.fontFam
                                    pixelSize: root.themeNothing ? root.fontSize : (root.fontSize - 1)
                                    bold: !root.themeNothing
                                }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        MouseArea {
                            id: modernWthMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openWeatherDetails()
                        }
                    }
                }

                // ------------------------------------------- центр/centro: часы / reloj o ventana activa
                Item {
                    id: modernCenterSlot
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                    implicitWidth: showHoverWindow ? (hoverWinRow.implicitWidth + 8) : (root.themeNothing ? modernDotClock.implicitWidth : modernTextClock.implicitWidth)
                    implicitHeight: root.pillH
                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    readonly property bool showHoverWindow: (root.cfg.notchActiveWindowHover !== false)
                        && capsuleHover.hovered
                        && root.activeWindowClass.length > 0

                    // Reloj en reposo
                    Item {
                        anchors.centerIn: parent
                        visible: !modernCenterSlot.showHoverWindow
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        DotText {
                            id: modernDotClock
                            visible: root.themeNothing
                            anchors.centerIn: parent
                            value: root.timeText
                            size: root.dotHClock
                            gapRatio: 0.1
                            color: root.colFg
                        }

                        Text {
                            id: modernTextClock
                            visible: !root.themeNothing
                            anchors.centerIn: parent
                            text: root.timeText
                            color: root.colFg
                            font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                        }
                    }

                    // Chip de Ventana Activa (Hover Peek)
                    RowLayout {
                        id: hoverWinRow
                        anchors.centerIn: parent
                        spacing: 6
                        visible: modernCenterSlot.showHoverWindow
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        Text {
                            text: root.activeWindowGlyph(root.activeWindowClass)
                            color: root.colOn
                            font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                        }

                        Text {
                            text: root.formatAppTitle(root.activeWindowClass, root.activeWindowTitle)
                            color: root.colFg
                            font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                            elide: Text.ElideRight
                        }
                    }
                }

                // ------------------------------------------- справа/derecha: сеть/red, звук/audio, заряд/batería
                RowLayout {
                    id: modernRight
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 14

                    Text {
                        visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)
                        text: (root.loadCpu >= 0 ? "CPU " + root.loadCpu + "%" + (root.loadTempCpu >= 0 ? " " + root.loadTempCpu + "°" : "") : "")
                            + (root.loadGpu >= 0 ? "  GPU " + root.loadGpu + "%" + (root.loadTempGpu >= 0 ? " " + root.loadTempGpu + "°" : "") : "")
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                    }

                    // 1. Red / Сеть (кабель или Wi-Fi)
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: (root.wiredOn ? (root.iconSize - 6) : modernWifiTxt.implicitWidth) + (root.themeNothing ? 12 : 8)
                        Layout.preferredHeight: root.iconSize

                        LanGlyph {
                            anchors.centerIn: parent
                            width: root.iconSize - 6
                            height: root.iconSize - 6
                            visible: root.wiredOn
                            color: root.colFg
                        }
                        Text {
                            id: modernWifiTxt
                            anchors.centerIn: parent
                            visible: !root.wiredOn
                            text: root.wifiOn ? (root.wifiQuality > 66 ? "󰤨"
                                               : root.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                            color: root.wifiOn ? root.colFg : root.colMuted
                            font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                        }
                    }

                    // 2. Audio / Звук (иконка + громкость с колесом мыши и mute)
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: modernAudioRow.implicitWidth
                        implicitHeight: modernAudioRow.implicitHeight

                        RowLayout {
                            id: modernAudioRow
                            anchors.fill: parent
                            spacing: root.themeNothing ? 5 : 4

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: !root.sinkAudio ? String.fromCodePoint(0xF075F)
                                    : root.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                                    : root.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                                    : root.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                    : String.fromCodePoint(0xF057E)
                                color: (root.sinkAudio && root.sinkAudio.muted)
                                       ? root.colMuted : root.colFg
                                font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                            }

                            // Nothing: DotText
                            DotText {
                                visible: root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                value: root.sinkAudio
                                       ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                                size: root.dotHSmall
                                color: (root.sinkAudio && root.sinkAudio.muted)
                                       ? root.colMuted : root.colFg
                            }

                            // Material 3: Text
                            Text {
                                visible: !root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                text: root.sinkAudio ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                                color: (root.sinkAudio && root.sinkAudio.muted) ? root.colMuted : root.colFg
                                font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted;
                            }
                            onWheel: wheel => {
                                if (!root.sinkAudio) return;
                                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                root.sinkAudio.volume = Math.max(0, Math.min(1.5, root.sinkAudio.volume + step));
                            }
                        }
                    }

                    // 3. Batería / Батарея (ChargeBolt + заряд с кликами для тостов)
                    Item {
                        visible: root.batteryPresent
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: modernBattRow.implicitWidth
                        implicitHeight: modernBattRow.implicitHeight

                        RowLayout {
                            id: modernBattRow
                            anchors.fill: parent
                            spacing: root.cfg.notchBatteryGap || (root.themeNothing ? 8 : 6)

                            ChargeBolt {
                                Layout.alignment: Qt.AlignVCenter
                                pixelSize: root.iconSize - 2
                                active: !root.musicIslandActive
                            }

                            // Nothing: DotText
                            DotText {
                                visible: root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                value: String(root.batteryPct)
                                size: root.dotHSmall
                                color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                     : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                     : root.colFg
                            }

                            // Material 3: Text
                            Text {
                                visible: !root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                text: String(root.batteryPct)
                                color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                     : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                     : root.colFg
                                font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.showAcToast();
                                } else {
                                    root.showLowBattToast(root.batteryPct || 20);
                                }
                            }
                        }
                    }
                }

            }
        }

        // ------------------------------------------ свёрнутое: Dynamic Island (Музыка)
        Item {
            id: musicCapsule
            anchors.fill: parent
            height: root.pillH
            visible: root.musicIslandActive
                     && (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode))
                     && !root.anyToastActive
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }
            implicitWidth: (root.musicCenterMode === 4 ? 148
                          : root.musicCenterMode === 3 ? (mfnRow.implicitWidth + 116)
                          : (musicCenterBox.width + 96))

            // Обложка трека слева (3D поворот зеркала при смене трека + отсутствие мигания ноты)
            FlipArt {
                id: musicArtBox
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: root.cfg.musicArtSize !== undefined ? root.cfg.musicArtSize : 24
                height: root.cfg.musicArtSize !== undefined ? root.cfg.musicArtSize : 24
                artRadius: root.cfg.musicCoverRadius !== undefined ? root.cfg.musicCoverRadius : 7
                trackKey: root.mediaArtTrack
                artSource: root.effectiveMediaArt
                placeholderColor: root.colMuted
                fontFam: root.fontFam
                iconSize: 13
                sourceSize: 256
                rippleUnderCover: root.cfg.musicCoverRipple !== false
                rippleShape: root.cfg.musicCoverRippleShape !== undefined ? root.cfg.musicCoverRippleShape : 0
                rippleSens: (root.cfg.musicCoverRippleSens !== undefined ? root.cfg.musicCoverRippleSens : 100) / 100.0
                rippleFreq: root.cfg.musicCoverRippleFreq !== undefined ? root.cfg.musicCoverRippleFreq : 0
                ripplePersistence: (root.cfg.musicCoverRipplePersistence !== undefined ? root.cfg.musicCoverRipplePersistence : 100) / 100.0
                bounceEnabled: root.cfg.musicCoverBounce !== false
                reactionIntensity: (root.cfg.musicArtReactionIntensity !== undefined ? root.cfg.musicArtReactionIntensity : 50) / 100.0
                reactionActive: root.mediaPlaying
                waveOverlay: root.cfg.musicWavePos === 1 || root.cfg.musicWavePos === 2
                dominantColor: root.mediaArtColor
                waveColor: root.effectiveWaveColor

                // Клик по обложке — пауза / воспроизведение
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }


            // Центральный блок с плавной анимацией fade-in / fade-out:
            // 0 = часы Nothing, 1 = уровень батареи Nothing, 2 = часы + батарея, 3 = всё вместе (через musicFullNormalBox), 4 = ничего (Dynamic Island classic)
            Item {
                id: musicCenterBox
                anchors.centerIn: parent
                height: root.pillH
                width: root.musicCenterMode === 0 ? (root.themeNothing ? musicClock.implicitWidth : musicClockM3.implicitWidth)
                     : root.musicCenterMode === 1 ? musicBattery.implicitWidth
                     : root.musicCenterMode === 2 ? musicClockAndBattery.implicitWidth
                     : 0

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                // 1. Часы: Nothing DotText или Material You Text Bold
                DotText {
                    id: musicClock
                    anchors.centerIn: parent
                    value: root.timeText
                    size: root.dotHClock
                    gapRatio: 0.1
                    color: root.colFg
                    opacity: (root.musicCenterMode === 0 && root.themeNothing) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }
                }
                Text {
                    id: musicClockM3
                    anchors.centerIn: parent
                    text: root.timeText
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                    opacity: (root.musicCenterMode === 0 && !root.themeNothing) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }
                }

                // 2. Уровень батареи (иконка + процент)
                RowLayout {
                    id: musicBattery
                    anchors.centerIn: parent
                    spacing: root.cfg.notchBatteryGap || (root.themeNothing ? 8 : 6)
                    opacity: root.musicCenterMode === 1 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }

                    ChargeBolt {
                        Layout.alignment: Qt.AlignVCenter
                        pixelSize: root.iconSize - 2
                        active: root.musicCenterMode === 1
                    }

                    DotText {
                        visible: root.themeNothing
                        Layout.alignment: Qt.AlignVCenter
                        value: String(root.batteryPct)
                        size: root.dotHClock
                        gapRatio: 0.1
                        color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                             : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                             : root.colFg
                    }

                    Text {
                        visible: !root.themeNothing
                        Layout.alignment: Qt.AlignVCenter
                        text: String(root.batteryPct) + "%"
                        color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                             : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                             : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                }

                // 3. Часы и батарея одновременно (Mode 2)
                RowLayout {
                    id: musicClockAndBattery
                    anchors.centerIn: parent
                    spacing: root.cfg.notchSectionGap || (root.themeNothing ? 12 : 10)
                    opacity: root.musicCenterMode === 2 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }

                    DotText {
                        visible: root.themeNothing
                        Layout.alignment: Qt.AlignVCenter
                        value: root.timeText
                        size: root.dotHClock
                        gapRatio: 0.1
                        color: root.colFg
                    }

                    Text {
                        visible: !root.themeNothing
                        Layout.alignment: Qt.AlignVCenter
                        text: root.timeText
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: root.cfg.notchBatteryGap || (root.themeNothing ? 8 : 6)

                        ChargeBolt {
                            Layout.alignment: Qt.AlignVCenter
                            pixelSize: root.iconSize - 2
                            active: root.musicCenterMode === 2
                        }

                        DotText {
                            visible: root.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            value: String(root.batteryPct)
                            size: root.dotHClock
                            gapRatio: 0.1
                            color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                 : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                 : root.colFg
                        }

                        Text {
                            visible: !root.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            text: String(root.batteryPct) + "%"
                            color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                 : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                 : root.colFg
                            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                        }
                    }
                }
            }

            // 4. Todo combinado: Notch normal completo en el centro (Mode 3)
            Item {
                id: musicFullNormalBox
                anchors.centerIn: parent
                height: root.pillH
                width: mfnRow.implicitWidth
                opacity: root.musicCenterMode === 3 ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                implicitWidth: mfnRow.implicitWidth

                RowLayout {
                    id: mfnRow
                    anchors.centerIn: parent
                    spacing: 14

                    // Слева: столы + погода
                    RowLayout {
                        id: mfnLeft
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 25

                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        Layout.alignment: Qt.AlignVCenter
                        radius: 4
                        visible: root.recActive
                        color: root.recPaused ? root.colWarn : root.colCrit
                    }

                    RowLayout {
                        id: mfnWsRow
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Repeater {
                            model: root.wsList

                            Rectangle {
                                required property var modelData
                                readonly property bool here: modelData === root.wsId
                                property real len: here ? (root.themeNothing ? 17 : 18) : 6
                                property bool settled: false
                                Component.onCompleted: settled = true

                                Layout.preferredWidth: len
                                Layout.preferredHeight: 6
                                Layout.alignment: Qt.AlignVCenter
                                radius: 3
                                color: here ? ((root.musicIslandActive && root.themeMaterial) ? root.mediaArtColor : (root.themeMaterial ? root.colOn : root.colFg)) : root.colFg
                                opacity: here ? 1.0 : (mfnWsMa.containsMouse ? (root.themeNothing ? 0.6 : 0.65) : (root.themeNothing ? 0.3 : 0.28))

                                Behavior on len {
                                    enabled: settled
                                    NumberAnimation {
                                        duration: root.themeMaterial ? 220 : root.animMs
                                        easing.type: root.themeMaterial ? Easing.OutBack : Easing.OutCubic
                                        easing.overshoot: 1.15
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on opacity {
                                    enabled: settled
                                    NumberAnimation { duration: root.animFast }
                                }

                                MouseArea {
                                    id: mfnWsMa
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.gotoWorkspace(modelData)
                                }
                            }
                        }
                    }

                    Item {
                        visible: root.weatherReady && root.cfg.weatherOnIsland
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: mfnWthRow.implicitWidth
                        implicitHeight: mfnWthRow.implicitHeight

                        RowLayout {
                            id: mfnWthRow
                            anchors.fill: parent
                            spacing: 5

                            // Nothing: DotIcon
                            DotIcon {
                                visible: root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                code: root.weatherIcon
                                size: root.dotHClock
                                color: mfnWthMa.containsMouse ? root.colOn : root.colFg
                            }

                            // Material 3: Nerd Glyph
                            Text {
                                visible: !root.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                text: root.weatherGlyph
                                color: mfnWthMa.containsMouse ? root.colOn : root.colFg
                                font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            // Texto de temperatura
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: root.weatherTemp + "°"
                                color: mfnWthMa.containsMouse ? root.colOn : root.colFg
                                font {
                                    family: root.fontFam
                                    pixelSize: root.themeNothing ? root.fontSize : (root.fontSize - 1)
                                    bold: !root.themeNothing
                                }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        MouseArea {
                            id: mfnWthMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openWeatherDetails()
                        }
                    }
                }

                // Centro: Reloj Nothing o Material 3
                DotText {
                    id: mfnClock
                    visible: root.themeNothing
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                    value: root.timeText
                    size: root.dotHClock
                    gapRatio: 0.1
                    color: root.colFg
                }

                Text {
                    id: mfnClockM3
                    visible: !root.themeNothing
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    text: root.timeText
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }

                // Справа: сеть (с extra padding), звук, заряд
                RowLayout {
                    id: mfnRight
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 14

                    Text {
                        visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)
                        text: (root.loadCpu >= 0 ? "CPU " + root.loadCpu + "%" + (root.loadTempCpu >= 0 ? " " + root.loadTempCpu + "°" : "") : "")
                            + (root.loadGpu >= 0 ? "  GPU " + root.loadGpu + "%" + (root.loadTempGpu >= 0 ? " " + root.loadTempGpu + "°" : "") : "")
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                    }

                    // 1. Сеть (кабель или Wi-Fi) с +padding
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: (root.wiredOn ? (root.iconSize - 6) : mfnWifiTxt.implicitWidth) + 12
                        Layout.preferredHeight: root.iconSize

                        LanGlyph {
                            anchors.centerIn: parent
                            width: root.iconSize - 6
                            height: root.iconSize - 6
                            visible: root.wiredOn
                            color: root.colFg
                        }
                        Text {
                            id: mfnWifiTxt
                            anchors.centerIn: parent
                            visible: !root.wiredOn
                            text: root.wifiOn ? (root.wifiQuality > 66 ? "󰤨"
                                               : root.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                            color: root.wifiOn ? root.colFg : root.colMuted
                            font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                        }
                    }

                    RowLayout {
                        spacing: 5

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: !root.sinkAudio ? String.fromCodePoint(0xF075F)
                                : root.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                                : root.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                                : root.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                                               : String.fromCodePoint(0xF057E)
                            color: (root.sinkAudio && root.sinkAudio.muted)
                                   ? root.colMuted : root.colFg
                            font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                        }

                        DotText {
                            visible: root.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            value: root.sinkAudio
                                   ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                            size: root.dotHSmall
                            color: (root.sinkAudio && root.sinkAudio.muted)
                                   ? root.colMuted : root.colFg
                        }

                        Text {
                            visible: !root.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            text: root.sinkAudio ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                            color: (root.sinkAudio && root.sinkAudio.muted) ? root.colMuted : root.colFg
                            font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                        }
                    }

                    RowLayout {
                        spacing: root.cfg.notchBatteryGap || 8
                        visible: root.batteryPresent

                        ChargeBolt {
                            Layout.alignment: Qt.AlignVCenter
                            pixelSize: root.iconSize - 2
                            active: root.musicCenterMode === 3
                        }

                        DotText {
                            visible: root.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            value: String(root.batteryPct)
                            size: root.dotHSmall
                            color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                 : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                 : root.colFg
                        }

                        Text {
                            visible: !root.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            text: String(root.batteryPct)
                            color: !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryCritThreshold || 15) ? root.colBattCrit
                                 : !root.acOnline && root.batteryPct <= (root.cfg.lowBatteryThreshold || 20) ? root.colBattWarn
                                 : root.colFg
                            font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                        }
                    }
                }
            }
        }


            // Полосы эквалайзера справа (5 полос, окрашенных цветом обложки или выбранным режимом)
            WaveBars {
                id: musicWave
                visible: (root.cfg.musicWaveEnabled !== false) && (root.cfg.musicWavePos === 0 || root.cfg.musicWavePos === 2 || root.cfg.musicWavePos === undefined)
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 16
                barCount: 5
                gap: 2.5
                barColor: root.effectiveWaveColor
                sensMultiplier: (root.cfg.musicRightWaveSens !== undefined ? root.cfg.musicRightWaveSens : 100) / 100.0
                freqMode: root.cfg.musicRightWaveFreq !== undefined ? root.cfg.musicRightWaveFreq : 0
                persistenceMultiplier: (root.cfg.musicRightWavePersistence !== undefined ? root.cfg.musicRightWavePersistence : 100) / 100.0
                active: root.player ? root.player.isPlaying : false
                morphPause: true
                notchEntered: root.musicIslandActive
                Behavior on barColor { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: musicWave.hovered = true
                    onExited: musicWave.hovered = false
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }
        }

            // Текст столбиком: каждая буква на своей строке. Повёрнутый на
            // 90° текст пришлось бы читать с наклонённой головой, а так
            // вертикальный остров остаётся читаемым.
            component VertText: Column {
                id: vt
                property string value: ""
                property color textColor: root.colFg
                property real size: root.fontSize
                property bool bold: false
                property int maxChars: 16

                spacing: -2
                Repeater {
                    model: String(vt.value).slice(0, vt.maxChars).split("")
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData === " " ? "·" : modelData
                        color: vt.textColor
                        font {
                            family: root.fontFam
                            pixelSize: vt.size
                            bold: vt.bold
                        }
                    }
                }
            }

            // ------------------------------------- вертикальный остров
            // У боковых кромок содержимое стоит столбиком и НЕ повёрнуто:
            // повёрнутый текст читается только с наклонённой головой. Поэтому
            // здесь свой набор — короткие значения, которые влезают в толщину
            // острова: часы двумя строками, стол, раскладка, заряд.
            ColumnLayout {
                id: vertCapsule
                anchors.centerIn: parent
                width: root.pillH
                spacing: 7
                visible: (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.anySystemToastActive
                opacity: root.pillSide ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animFast } }

                // Играет музыка: обложка и эквалайзер. Названию в толщину
                // острова не поместиться, а повёрнутый текст не читается —
                // поэтому оно показывается подписью при наведении.
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: mediaCol.implicitHeight
                    visible: root.mediaActive

                ColumnLayout {
                    id: mediaCol
                    anchors.fill: parent
                    spacing: 5

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Image {
                            id: vertArt
                            anchors.fill: parent
                            source: root.effectiveMediaArt || root.mediaArt
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(256, 256)
                            mipmap: true
                            smooth: true
                            antialiasing: true
                            visible: false
                            layer.enabled: true
                        }
                        Item {
                            id: vertArtMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            layer.smooth: true
                            Rectangle { anchors.fill: parent; radius: 7; color: "#ffffff"; antialiasing: true }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: vertArt
                            maskEnabled: true
                            maskSource: vertArtMask
                            visible: vertArt.status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: vertArt.status !== Image.Ready
                            text: "󰝚"
                            color: root.colMuted
                            font { family: root.fontFam; pixelSize: 11 }
                        }
                    }

                    // название трека столбиком: коротко, но читаемо
                    VertText {
                        Layout.alignment: Qt.AlignHCenter
                        value: root.player ? String(root.player.trackTitle || "") : ""
                        textColor: root.colFg
                        size: root.fontSize - 3
                        bold: true
                        maxChars: 10
                    }

                    // Тот же эквалайзер, что и в горизонтальном виде, только
                    // повёрнутый: полосы абстрактные, читать их не нужно.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 28
                        WaveBars {
                            anchors.centerIn: parent
                            width: 28
                            height: 14
                            rotation: -90
                            barColor: root.colFg
                            sensMultiplier: (root.cfg.musicRightWaveSens !== undefined ? root.cfg.musicRightWaveSens : 100) / 100.0
                            freqMode: root.cfg.musicRightWaveFreq !== undefined ? root.cfg.musicRightWaveFreq : 0
                            persistenceMultiplier: (root.cfg.musicRightWavePersistence !== undefined ? root.cfg.musicRightWavePersistence : 100) / 100.0
                            active: root.player ? root.player.isPlaying : false
                            morphPause: true
                            notchEntered: root.mediaActive
                        }
                    }

                }

                    // Клик открывает плеер, наведение показывает название:
                    // подпись рисует корень, поэтому текст остаётся прямым.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            var t = root.player ? String(root.player.trackTitle || "") : "";
                            if (t.length === 0) return;
                            var p = mapToItem(null, width / 2, height / 2);
                            root.showTip(t, p.x, p.y);
                        }
                        onExited: root.hideTip(root.player
                                               ? String(root.player.trackTitle || "") : "")
                        onClicked: root.togglePage("media")
                    }
                }

                // идёт запись экрана
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                }

                // Черта отделяет музыку от постоянной части — как в
                // горизонтальном виде она стоит между cava и днём недели.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 1
                    visible: root.mediaActive
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                // день недели столбиком
                VertText {
                    Layout.alignment: Qt.AlignHCenter
                    value: root.dayText
                    textColor: root.colMuted
                    size: root.fontSize - 2
                    bold: true
                }

                // часы: часы и минуты отдельными строками
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timeText.split(":")[0] || ""
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (root.timeText.split(":")[1] || "").replace(/[^0-9]/g, "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: String(root.wsId)
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.kbLayout
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)
                    text: (root.loadCpu >= 0 ? "C" + root.loadCpu + "%" + (root.loadTempCpu >= 0 ? "/" + root.loadTempCpu + "°" : "") : "")
                          + (root.loadGpu >= 0 ? " G" + root.loadGpu + "%" + (root.loadTempGpu >= 0 ? "/" + root.loadTempGpu + "°" : "") : "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                }
                ChargeBolt {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    pixelSize: root.fontSize - 1
                    active: root.pillSide
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryPct
                    color: root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
            }

        // ------------------------------------------------------- ручка переноса
        // Полоса над содержимым: тянут за неё, а не за всю панель — иначе
        // любое движение по плиткам таскало бы остров. Видна только когда
        // перенос разрешён и открыты быстрые настройки.
        Item {
            id: dragHandle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            z: 60
            visible: root.cfg.pillDrag && root.expanded && root.page === "main"
                     && !root.settingsMode

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 4
                radius: 2
                color: root.pillDragging ? root.colOn
                     : (handleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.45)
                                               : Qt.rgba(1, 1, 1, 0.18))
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: handleMa
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.pillDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0

                onPressed: mouse => {
                    var p = mapToItem(null, mouse.x, mouse.y);
                    handleMa.pressX = p.x;
                    handleMa.pressY = p.y;
                    root.pillDragging = true;
                }
                onPositionChanged: mouse => {
                    if (!root.pillDragging) return;
                    var p = mapToItem(null, mouse.x, mouse.y);
                    root.dragDX = p.x - handleMa.pressX;
                    root.dragDY = p.y - handleMa.pressY;
                    root.dragEdge = root.edgeAt(capsule.x + root.dragDX + capsule.width / 2,
                                                capsule.y + root.dragDY + capsule.height / 2);
                }
                onReleased: root.dropPill()
                onCanceled: root.dropPill()
            }
        }

        // --------------------------------------------------- раскрытая панель
        Loader {
            id: contentLoader
            z: 10
            parent: (root.cfg.pillKeepVisible && root.expanded && !root.settingsMode) ? detachedPanel : capsule
            anchors.top: parent ? parent.top : undefined
            anchors.topMargin: 15
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            // Ширина берётся у ЦЕЛЕВОЙ панели, а не у анимируемой капсулы:
            // иначе содержимое переливалось по ширине на каждом кадре
            width: ((root.page === "settings" || root.page === "files" || root.page === "media") ? root.settingsW : (root.page === "islandmusic" ? 460 : (root.page === "power" ? 620 : root.panelW))) - 30
            // Пока показывается карточка выбора экрана (или тост), контент
            // раскрытой панели не рисуем: при старте записи из quick settings
            // панель сворачивается, а её содержимое иначе видно ещё пару кадров
            // позади карточки — экраны «проблёскивали».
            active: (root.expanded || capsule.height > root.pillH + 4 || (root.cfg.pillKeepVisible && detachedPanel.opacity > 0.005))
                    && (!root.anySystemToastActive || root.expanded)
            visible: !root.anySystemToastActive || root.expanded
            // без этого клавиатура не доходила до содержимого страницы:
            // сам Loader фокуса не имел, и forceActiveFocus() внутри вида
            // ни к чему не приводил
            focus: true
            onLoaded: if (item) item.forceActiveFocus()
            // Esc закрывает любую страницу: если сам вид его не обработал
            // (или обработал только на подстранице), событие всплывает сюда.
            // Сначала спрашиваем вид, есть ли ему куда вернуться: со списка
            // сетей или устройств Escape должен уводить к плиткам, а не
            // захлопывать панель целиком.
            Keys.onEscapePressed: {
                var it = contentLoader.item;
                if (it && typeof it.goBack === "function" && it.goBack()) return;
                root.collapse();
            }
            y: root.expanded ? 0 : -8
            opacity: root.expanded ? 1 : 0
            Behavior on y {
                NumberAnimation {
                    duration: root.expanded ? 280 : 160
                    easing.type: root.expanded ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.05
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.expanded ? 240 : 130
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: root.page === "launcher" ? launcherComp
                           : root.page === "settings" ? settingsComp
                           : root.page === "clip"     ? clipComp
                           : root.page === "power"    ? powerComp
                           : root.page === "notif"    ? notifComp
                           : root.page === "audio"    ? audioComp
                           : root.page === "cal"      ? calComp
                           : root.page === "record"   ? recordComp
                           : root.page === "files"    ? filesComp
                           : root.page === "media"    ? mediaComp
                           : root.page === "islandmusic" ? islandMusicComp
                           : root.page === "auth"     ? authComp
                           : root.page === "vault"    ? vaultComp
                           : root.page === "vaultsave" ? vaultSaveComp
                           : root.page === "agents"   ? agentsComp
                                                      : controlsComp
        }

        Component { id: controlsComp; ControlsView { sys: root } }
        Component { id: launcherComp; LauncherView { sys: root } }
        Component { id: settingsComp; SettingsView { sys: root; tab: root.settingsTab } }
        Component { id: clipComp;     ClipboardView { sys: root } }
        Component { id: powerComp;    PowerView { sys: root } }
        Component { id: notifComp;    NotificationsView { sys: root } }
        Component { id: audioComp;    AudioView { sys: root } }
        Component { id: calComp;      CalendarView { sys: root } }
        Component { id: recordComp;   RecordView { sys: root } }
        Component { id: filesComp;    FilesView { sys: root } }
        Component { id: mediaComp;    MediaView { sys: root } }
        Component { id: islandMusicComp; IslandMusicView { sys: root } }
        Component { id: authComp;     AuthView { sys: root } }
        Component { id: vaultComp;     VaultView { sys: root } }
        Component { id: vaultSaveComp; VaultSaveView { sys: root } }
        Component { id: agentsComp;    AgentsView { sys: root } }
    }

    // ------------------------------------------------ отдельная плавающая панель
    // При включённом «Остров виден при раскрытии» (pillKeepVisible):
    // верхний остров остаётся в свёрнутом виде, а раскрытая панель страниц
    // (быстрые настройки, календарь, лаунчер и т.д.) открывается отдельной
    // плавающей карточкой под ним.
    Rectangle {
        id: detachedPanel
        z: 50
        readonly property bool showMe: root.cfg.pillKeepVisible && !root.settingsMode && root.expanded

        visible: root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || opacity > 0.005)
        opacity: showMe ? 1 : 0
        scale: showMe ? 1 : 0.96

        transformOrigin: root.pillAtBottom ? Item.Bottom
                       : root.pillAtLeft   ? Item.Left
                       : root.pillAtRight  ? Item.Right
                                           : Item.Top

        transform: Translate {
            y: root.pillAtBottom
               ? (detachedPanel.showMe ? 0 : 10)
               : (detachedPanel.showMe ? 0 : -10)
            x: root.pillAtRight
               ? (detachedPanel.showMe ? 0 : 10)
               : root.pillAtLeft
               ? (detachedPanel.showMe ? 0 : -10)
               : 0

            Behavior on y {
                NumberAnimation {
                    duration: detachedPanel.showMe ? root.animMs : root.animFast
                    easing.type: detachedPanel.showMe
                                 ? (root.animBounce > 0 ? Easing.OutBack : Easing.OutCubic)
                                 : Easing.OutCubic
                    easing.overshoot: root.easeOvershoot
                }
            }
            Behavior on x {
                NumberAnimation {
                    duration: detachedPanel.showMe ? root.animMs : root.animFast
                    easing.type: detachedPanel.showMe
                                 ? (root.animBounce > 0 ? Easing.OutBack : Easing.OutCubic)
                                 : Easing.OutCubic
                    easing.overshoot: root.easeOvershoot
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: detachedPanel.showMe ? root.animFade : Math.round(root.animFade * 0.75)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: detachedPanel.showMe ? root.animMs : root.animFast
                easing.type: detachedPanel.showMe
                             ? (root.animBounce > 0 ? Easing.OutBack : Easing.OutCubic)
                             : Easing.OutCubic
                easing.overshoot: root.easeOvershoot
            }
        }

        readonly property real panelGap: root.cfg.islandGap > 0 ? root.cfg.islandGap : 10

        width: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || opacity > 0.005)) ? root.panelW : 0

        readonly property real detachedTargetH: Math.min(capsule.contentH, ((contentLoader.sourceComponent === controlsComp || contentLoader.sourceComponent === islandMusicComp || root.page === "main" || root.page === "islandmusic") ? Math.max(capsule.contentH, root.cfg.expandedH) : root.cfg.expandedH))
        height: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || opacity > 0.005))
                ? Math.min(detachedTargetH, root.height - (capsule.y + capsule.height + panelGap + 24))
                : 0
        Behavior on height { NumberAnimation { duration: root.animQuick; easing.type: Easing.OutCubic } }

        x: root.pillSide
           ? (root.pillAtLeft  ? capsule.x + capsule.width + panelGap
              : root.pillAtRight ? capsule.x - width - panelGap
              : Math.max(12, Math.min(root.width - width - 12, capsule.x + (capsule.width - width) / 2)))
           : Math.max(12, Math.min(root.width - width - 12, capsule.x + (capsule.width - width) / 2))

        y: root.pillAtBottom
           ? capsule.y - height - panelGap
           : root.pillAtTop
              ? capsule.y + capsule.height + panelGap
              : Math.max(12, Math.min(root.height - height - 12, capsule.y + (capsule.height - height) / 2))

        radius: root.cfg.islandRadius > 0 ? root.cfg.islandRadius : 24
        color: root.colBg
        Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
        border.width: 0
        clip: true

        HoverHandler {
            id: detachedHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                } else if (!capsuleHover.hovered && !root.holdOpen) {
                    collapseTimer.restart();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }
    }

    // ------------------------------------------------------- общий тултип
    // Панель настроек обрезается капсулой (clip), и подпись, выходящая за её
    // левый край, там просто исчезала. Поэтому тултип рисует сам корень:
    // вид сообщает текст и точку, от которой раскрываться влево.
    property string tipText: ""
    property real   tipX: 0
    property real   tipY: 0
    function showTip(text, x, y) { root.tipText = text; root.tipX = x; root.tipY = y; }
    function hideTip(text) { if (root.tipText === text) root.tipText = ""; }

    Rectangle {
        id: globalTip
        z: 200
        visible: opacity > 0.01
        opacity: root.tipText.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }

        width: globalTipText.implicitWidth + 20
        height: 26
        radius: 13
        x: Math.max(6, root.tipX - width - 10)
        y: root.tipY - height / 2
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: root.colLine
        border.width: 1

        scale: root.tipText.length > 0 ? 1 : 0.92
        transformOrigin: Item.Right
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            id: globalTipText
            anchors.centerIn: parent
            text: root.tipText
            color: root.colFg
            font { family: root.fontFam; pixelSize: 11 }
        }
    }

    // ------------------------------------ плавное примыкание к кромке экрана
    // Два вогнутых уголка по бокам: переход от кромки к пилюле без ступеньки.
    // Вогнутые уголки примыкания: цепляются к той же кромке, что и остров, и
    // стоят с двух его сторон. Форма выбирается по кромке: у вертикального
    // острова та же четверть круга, только развёрнутая — заливка должна
    // прижиматься к краю экрана и к торцу капсулы.
    NotchCorner {
        id: notchBefore
        // «до» острова: слева от него, а у боковых кромок — над ним
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "left"
        fill: root.currentNotchBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? -1 : (root.pillAtBottom ? -1 : 1)
        }
        // Округляем с перекрытием в 1px: уголок — отдельный элемент со своими координатами,
        // и без лёгкого перекрытия на стыке возникает субпиксельная щель/линия.
        x: root.pillSide ? (root.pillAtLeft ? capsule.x : parent.width - width)
                         : (Math.ceil(capsule.x) - width + 1)
        y: root.pillSide ? capsule.y - height
         : root.pillAtBottom ? (capsule.y + capsule.height - height) : capsule.y
        opacity: root.cornersOn ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
    NotchCorner {
        id: notchAfter
        // «после» острова: справа от него, а у боковых кромок — под ним
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "right"
        fill: root.currentNotchBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? 1 : (root.pillAtBottom ? -1 : 1)
        }
        // Перекрытие на 1px исключает появление вертикальной линии/щели на стыке
        x: root.pillSide ? (root.pillAtLeft ? capsule.x : parent.width - width)
                         : (Math.floor(capsule.x + capsule.width) - 1)
        y: root.pillSide ? capsule.y + capsule.height
         : root.pillAtBottom ? (capsule.y + capsule.height - height) : capsule.y
        opacity: root.cornersOn ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
}

// Обзор рабочих столов — отдельный полноэкранный слой: пилюля тут ни при
// чём, а клавиатура нужна целиком.
LazyLoader {
    activeAsync: root.overviewOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.overviewOpen ? WlrKeyboardFocus.Exclusive
                                                       : WlrKeyboardFocus.None
        visible: root.overviewOpen

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: root.overviewOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // Обзор столов создаётся сразу и живёт вместе с оболочкой.
        // Ленивая загрузка тут не прижилась: слой всплывает по Super+Tab, и
        // отдавать его создание на момент нажатия — значит рисковать самим
        // нажатием ради пары мегабайт. Тяжёлые превью окон и так живые только
        // пока слой открыт.
        OverviewView {
            anchors.fill: parent
            sys: root
        }
    }
}

// Обои — тоже свой полноэкранный слой: карусель раскрывается по центру
// экрана, а клавиатура нужна ей целиком (стрелки, Enter, Esc).
LazyLoader {
    // Собираем слой заранее — как только прочитан список обоев. Иначе первое
    // открытие уходило на создание трёх сотен карточек, и полсекунды экран
    // был пустым.
    activeAsync: root.wallsOpen || root.wallListReady

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wallsOpen ? WlrKeyboardFocus.Exclusive
                                                    : WlrKeyboardFocus.None
        // окно живёт всё время, но показывается только на открытии
        visible: root.wallsOpen || wallsFade.opacity > 0.01

        Rectangle {
            id: wallsFade
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            opacity: root.wallsOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animMs } }
        }

        // Раскрывается из острова: точка роста — та кромка, где он висит,
        // поэтому карусель выглядит развернувшейся пилюлей, а не отдельным
        // окном, приехавшим со стороны.
        // Карусель обоев. Слой над ней уже ленивый (LazyLoader выше строит
        // его только когда прочитан список обоев), а сами картинки грузятся
        // по мере показа — второй уровень ленивости лишь ломал открытие.
        WallpapersView {
            anchors.fill: parent
            sys: root
        }
    }
}

// Клавиши (Super + /) — свой полноэкранный слой, а не тайлящееся окно:
// раскрывается из острова по центру экрана и так же складывается обратно.
LazyLoader {
    activeAsync: root.keysWindowOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.keysWindowOpen ? WlrKeyboardFocus.Exclusive
                                                         : WlrKeyboardFocus.None
        visible: root.keysWindowOpen || keysScrim.opacity > 0.01

        Rectangle {
            id: keysScrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            opacity: root.keysWindowOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animMs } }
        }

        // клик мимо карточки закрывает — как у обзора столов и карусели обоев
        MouseArea {
            anchors.fill: parent
            onClicked: root.keysWindowOpen = false
        }

        // Карточка начинает ровно в геометрии капсулы и растёт до своего
        // размера по центру: получается развернувшийся остров, а не окно,
        // приехавшее со стороны.
        Rectangle {
            id: keysCard
            readonly property real fullW: Math.min(1280, parent.width - 80)
            readonly property real fullH: Math.min(940, parent.height - 80)

            color: root.colBg
            Behavior on color  { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
            clip: true
            x: root.keysWindowOpen ? (parent.width - fullW) / 2 : root.pillRectX
            y: root.keysWindowOpen ? (parent.height - fullH) / 2 : root.pillRectY
            width:  root.keysWindowOpen ? fullW : Math.max(8, root.pillRectW)
            height: root.keysWindowOpen ? fullH : Math.max(8, root.pillRectH)
            radius: root.keysWindowOpen ? 26 : Math.min(width, height) / 2

            Behavior on x      { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on y      { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on width  { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }

            // Прокрутки нет: список разложен в три колонки и целиком
            // помещается в карточку, а сама она занимает почти весь экран.
            // За сочетанием заглядывают на секунду, посреди другой работы —
            // искать его колесом дольше, чем вспоминать самому.
            SetKeys {
                id: keysBody
                anchors.fill: parent
                anchors.margins: 26
                sys: root
                // содержимое проявляется вслед за карточкой: на первых кадрах
                // она ещё размером с пилюлю, и список в неё не влезает
                opacity: root.keysWindowOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animMs } }
            }
        }
    }
}

// Экран «что нового» после обновления. Отдельным слоем поверх всего: его
// показывают один раз, и он должен перехватывать клавиатуру.
PanelWindow {
    visible: root.whatsNewOpen
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.whatsNewOpen ? WlrKeyboardFocus.Exclusive
                                                   : WlrKeyboardFocus.None

    Loader {
        anchors.fill: parent
        active: root.whatsNewOpen
        sourceComponent: WhatsNewView {
            sys: root
            lines: root.whatsNew
        }
    }
}

// Ventana de Bienvenida e Introducción (primera instalación o apertura voluntaria)
PanelWindow {
    visible: root.welcomeOpen
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.welcomeOpen && !root.whatsNewOpen) ? WlrKeyboardFocus.Exclusive
                                                  : WlrKeyboardFocus.None

    Loader {
        anchors.fill: parent
        active: root.welcomeOpen
        sourceComponent: WelcomeView {
            sys: root
            reinstallBanner: root.reinstallStatusMsg
            reinstallIsError: root.reinstallStatusIsError
        }
    }
}


// Проводник отдельным окном. Живёт на уровне ShellRoot, а не внутри
// пилюли: окно не может быть ребёнком другого окна.
Instantiator {
    model: filesWindows

    FloatingWindow {
        required property var model
        title: "Panacea · " + root.tr("Проводник")
        color: root.colBg
        minimumSize.width: 720
        minimumSize.height: 460
        visible: true
        // крестик в заголовке — окно должно уйти и из списка
        onVisibleChanged: if (!visible) root.closeFilesWindow(model.wid)

        FilesView {
            anchors.fill: parent
            anchors.margins: 15
            sys: root
            // папка, с которой окно открылось (пусто — домашняя)
            dir: model.startDir
            // в оконном режиме закрывать надо своё окно, а не пилюлю
            windowMode: true
            windowId: model.wid
        }
    }
}

// Стоп-кадр под выделение области скриншота.
//
// Обычное «выдели область и сними» выделяет по живому экрану, и снять то,
// что закрывается от первого движения мыши — меню, всплывающую подсказку,
// список автодополнения — нечем: пока тянешь рамку, снимать уже нечего.
// Поэтому shot.sh сначала снимает экран целиком, показывает снимок этим
// слоем поверх всего, и только потом запускает выделение. Итоговый кадр
// снимается с замершего слоя, так что обрезать исходный файл не нужно —
// иначе понадобился бы ещё и ImageMagick.
//
// Окно детального прогноза погоды на несколько дней
PanelWindow {
    id: weatherDetailsWin
    visible: root.weatherDetailsOpen
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.weatherDetailsOpen ? WlrKeyboardFocus.Exclusive
                                                         : WlrKeyboardFocus.None

    // Затемнение фона при клике на которое окно закрывается
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.weatherDetailsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.weatherDetailsOpen = false
        }
    }

    Keys.onEscapePressed: root.weatherDetailsOpen = false

    WeatherDetailsView {
        anchors.centerIn: parent
        sys: root
        forecastData: root.weatherForecastData
        scale: root.weatherDetailsOpen ? 1 : 0.93
        opacity: root.weatherDetailsOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
}

// ---------------------------------------------------- настольные виджеты
// Карточки на обоях: дата, погода, часы. Раскладка у них общая для тем, а
// начертание своё: на Nothing числа точками, на остальных обычным шрифтом.
// Выбирает его сама карточка — слою достаточно знать, включены ли виджеты.
//
// Слой Bottom: над обоями, но под окнами.
// Область ввода ограничена карточками виджетов: клик по карточке погоды
// открывает подробный прогноз, а пустой рабочий стол остаётся свободным.
PanelWindow {
    id: widgetsWin

    visible: root.cfg.featWidgets
    screen: root.screen
    anchors { top: true; left: true }
    implicitWidth:  widgets.implicitWidth + 56
    implicitHeight: widgets.implicitHeight + 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: widgets }

    WidgetsView {
        id: widgets
        sys: root
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 28
        // ниже острова: тот стоит по центру верхней кромки и до левого
        // угла не достаёт, но запас нужен под его вогнутый уголок
        anchors.topMargin: 28
    }
}

// ---------------------------------------------------- macOS Dock Window
// Barra inferior estilo macOS centrada horizontalmente con el notch superior.
PanelWindow {
    id: dockWin
    screen: root.screen
    anchors { bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: root.cfg.dockEnabled !== false && !root.lockActive && (!root.fullscreenActive || root.dockVisible || (typeof dockSlideAnim !== "undefined" && dockSlideAnim.running))

    implicitWidth: dockView.implicitWidth + 40
    implicitHeight: (root.cfg.dockIconSize || 48) + 60

    Item {
        id: autoHideSensor
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(320, dockView.width)
        height: 6
        visible: !!root.cfg.dockAutoHide
    }

    Region {
        id: dockMaskRegion
        item: dockView
        Region {
            item: root.cfg.dockAutoHide ? autoHideSensor : null
            intersection: Intersection.Combine
        }
    }
    mask: dockMaskRegion

    HoverHandler {
        id: dockWinHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
            if (!hovered && root.cfg.dockAutoHide) dockWinHideTimer.restart();
            else if (hovered && root.cfg.dockAutoHide) dockWinHideTimer.stop();
        }
    }

    Timer {
        id: dockWinHideTimer
        interval: 420
    }

    readonly property bool dockAppeared: root.dockVisible && (!root.cfg.dockAutoHide || root.dockForced || dockWinHover.hovered || dockWinHideTimer.running)

    DockView {
        id: dockView
        sys: root
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dockWin.dockAppeared ? 0 : -(dockView.implicitHeight + 28)
        anchors.horizontalCenter: parent.horizontalCenter

        opacity: (dockWin.dockAppeared || (typeof dockSlideAnim !== "undefined" && dockSlideAnim.running)) ? 1.0 : 0.0

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                id: dockSlideAnim
                duration: dockWin.dockAppeared ? 380 : 290
                easing.type: dockWin.dockAppeared ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.04
            }
        }
    }
}

// Слой на каждый экран, а не один на root.screen: grim снимает всю раскладку
// одной картинкой, и каждое окно показывает свой её кусок, сдвинув снимок на
// начало своего экрана.
Variants {
    model: root.freezeShot !== "" ? Quickshell.screens : []

    PanelWindow {
        id: freezeWin
        required property var modelData

        screen: freezeWin.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "black"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // Кадр только показывается. Клавиатура и мышь целиком достаются
        // выделению: с непустой областью ввода клики уходили бы в этот слой,
        // и рамку было бы нечем тянуть.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Image {
            // grim снимает раскладку в физических пикселях, а поверхности
            // экранов — логические (при масштабе 200% вдвое меньше). Рисовать
            // кадр «пиксель в пиксель» нельзя: на масштабированном экране виден
            // был бы только верхний левый угол — экран будто «зумило», и снять
            // весь экран не получалось. Поэтому растягиваем весь кадр в
            // логические границы раскладки и сдвигаем на начало своего экрана —
            // получается ровно 1:1 с тем, что на экране, при любом масштабе.
            x: root.freezeBounds.x - freezeWin.modelData.x
            y: root.freezeBounds.y - freezeWin.modelData.y
            width: root.freezeBounds.width
            height: root.freezeBounds.height
            source: root.freezeShot
            fillMode: Image.Stretch
            smooth: true
            // Файл временный и каждый раз новый, но имя может повториться —
            // кэш отдал бы прошлый снимок.
            cache: false
        }
    }
}

}
