import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Appearance. Тема задаёт палитру всей оболочки и ни от чего больше не
// зависит: обои меняются сами по себе, цвет — сам по себе. Тема «Default»
// оставлена как была, поэтому вручную выбранные цвет текста и акцент
// продолжают работать именно на ней.
ColumnLayout {
    id: page

    property var sys
    property var localeOptions: [{ id: "es", text: "Español" }, { id: "en", text: "English" }, { id: "ru", text: "Русский" }, { id: "tr", text: "Türkçe" }]

    Process {
        command: [page.sys.scriptDir + "/locale.sh", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var options = [
                    { id: "es", text: "Español" },
                    { id: "en", text: "English" },
                    { id: "ru", text: "Русский" },
                    { id: "tr", text: "Türkçe" }
                ];
                var lines = String(text).trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|");
                    if (parts.length !== 2 || !parts[0].length) continue;
                    if (parts[0] === "es" || parts[0] === "en" || parts[0] === "ru" || parts[0] === "tr") continue;
                    var locale = Qt.locale(parts[0]);
                    var nativeName = locale && locale.name !== "C" ? locale.nativeLanguageName : "";
                    options.push({ id: parts[0], text: nativeName ? nativeName + " · " + parts[0] : parts[1] });
                }
                if (options.length) page.localeOptions = options;
            }
        }
    }

    Layout.fillWidth: true
    spacing: 12

    property var soundAppearanceModel: [
        { id: "connect",          label: "Bluetooth",                      icon: "󰂯" },
        { id: "disconnect",       label: page.sys.tr("Отключение"),        icon: "󰂲" },
        { id: "charge",           label: page.sys.tr("Зарядка"),           icon: "󰂄" },
        { id: "mode_powersave",   label: page.sys.tr("Спокойный режим"),   icon: "󰌪" },
        { id: "mode_balanced",    label: page.sys.tr("Сбалансированный режим"), icon: "󰾅" },
        { id: "mode_performance", label: page.sys.tr("Производительный режим"), icon: "󰓅" },
        { id: "batt_full",        label: page.sys.tr("Полный заряд"),      icon: "󰁹" },
        { id: "lowbatt",          label: page.sys.tr("Низкий заряд"),      icon: "󰂃" },
        { id: "island_pop",       label: "Isla Pop",                       icon: "󰍜" },
        { id: "settings_open",    label: page.sys.tr("Открытие Super+I"),  icon: "󰅀" },
        { id: "settings_close",   label: page.sys.tr("Закрытие Super+I"),  icon: "󰅖" },
        { id: "notification",     label: page.sys.tr("Уведомление"),       icon: "󰂚" },
        { id: "screenshot",       label: page.sys.tr("Скриншот"),          icon: "󰄀" },
        { id: "voice_start",      label: page.sys.tr("Голос"),             icon: "󰍬" },
        { id: "voice_done",       label: page.sys.tr("Завершение голоса"), icon: "󰍭" },
        { id: "lock",             label: page.sys.tr("Блокировка"),        icon: "󰌾" },
        { id: "unlock",           label: page.sys.tr("Разблокировка"),     icon: "󰌿" },
        { id: "tock",             label: page.sys.tr("Tock"),              icon: "󰌌" },
        { id: "kbd_light",        label: page.sys.tr("Подсветка клавиатуры"), icon: "󰌌" },
        { id: "vol_tick",         label: page.sys.tr("Громкость"),         icon: "󰕾" }
    ]

    property int allSoundAppIdx: -1
    property alias allSoundAppTimer: allSoundAppTimer
    Timer {
        id: allSoundAppTimer
        interval: 420
        repeat: true
        onTriggered: {
            page.allSoundAppIdx++;
            if (page.allSoundAppIdx < page.soundAppearanceModel.length) {
                page.sys.playSound(page.soundAppearanceModel[page.allSoundAppIdx].id);
            } else {
                page.allSoundAppIdx = -1;
                allSoundAppTimer.stop();
            }
        }
    }

    // ------------------------------------------------------------- язык
    // Стоит первым: с языка начинают, а не заканчивают им.
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Язык") }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Язык системы")
            options: page.localeOptions
            searchable: true
            value: page.sys.cfg.lang
            onPicked: id => page.sys.setLang(id)
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.sysLangPending
                  ? page.sys.tr("Меняем язык системы…")
                  : (!page.sys.systemLocaleMatches
                     ? page.sys.tr("Оболочка уже на новом языке. Приложения и меню читают язык при входе — они переключатся после перезахода.")
                     : page.sys.tr("Оболочка переключается сразу. Приложения и меню — после перезахода: язык они читают при входе."))
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        Text {
            Layout.fillWidth: true
            visible: ["en", "ru", "tr", "es"].indexOf(page.sys.languageCode) < 0
            text: page.sys.tr("Для этого языка нет перевода интерфейса Panacea. Пока используется английский; запросите перевод через issue на GitHub.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- тема
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Тема") }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: page.sys.themes

                Rectangle {
                    id: swatch
                    required property var modelData
                    readonly property bool active: page.sys.cfg.themeId === swatch.modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 14
                    color: swatch.modelData.bg
                    border.width: swatch.active ? 2 : 1
                    border.color: swatch.active
                                  ? swatch.modelData.on
                                  : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b,
                                            swatchMa.containsMouse ? 0.30 : 0.12)
                    Behavior on border.color { ColorAnimation { duration: page.sys.animFade } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 9

                        // три кружка: акцент, текст, тревожный цвет — по ним
                        // тема узнаётся быстрее, чем по названию
                        Repeater {
                            model: [swatch.modelData.on, swatch.modelData.fg, swatch.modelData.crit]
                            Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                color: modelData
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9
                        text: swatch.modelData.name
                        color: swatch.modelData.fg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }

                    MouseArea {
                        id: swatchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.sys.setTheme(swatch.modelData.id);
                            page.sys.playSound("mode_balanced");
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.cfg.themeId === "default"
            text: page.sys.tr("На теме Default цвет текста и акцент берутся из настроек ниже; у остальных тем они свои.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.cfg.themeId === "material3"
            text: page.sys.tr("Material Design 3 (Material You): Expresivas curvas fluidas, superficies tonales y barra de reproducción animada en Super + M.")
            color: page.sys.colOn
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // ------------------------------------------------------------- Material You Color Source
        ColumnLayout {
            Layout.fillWidth: true
            visible: page.sys.cfg.themeId === "material3"
            spacing: 8

            SetSelect {
                sys: page.sys
                label: page.sys.tr("Origen de Color Material 3")
                options: [
                    { id: "wallpaper", text: page.sys.tr("Fondo") },
                    { id: "music",     text: page.sys.tr("Portada Música") },
                    { id: "manual",    text: page.sys.tr("Manual") }
                ]
                value: page.sys.cfg.m3ColorMode || "wallpaper"
                onPicked: id => {
                    page.sys.cfg.m3ColorMode = id;
                    page.sys.saveCfg();
                    page.sys.updateMatugenTheme();
                }
            }

            Text {
                Layout.fillWidth: true
                visible: (page.sys.cfg.m3ColorMode || "wallpaper") === "wallpaper"
                text: page.sys.tr("Modo Fondo: Extrae los tonos armónicos dinámicamente de tu fondo de pantalla.")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            Text {
                Layout.fillWidth: true
                visible: page.sys.cfg.m3ColorMode === "music"
                text: page.sys.tr("Modo Portada Música: Aplica el color de la portada activa (Spotify/MPRIS) atenuado estilo Spicetify para que la portada y las ondas sigan destacando.")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            SetColor {
                visible: page.sys.cfg.m3ColorMode === "manual"
                sys: page.sys
                label: page.sys.tr("Gama de Colores Material 3")
                sub: page.sys.tr("Matugen generará toda la paleta armónica Material You a partir de este color base.")
                value: page.sys.cfg.m3ManualColor || "#e08096"
                defaultColor: "#e08096"
                presets: [
                    "#e08096", "#fad5dc", "#8b5cf6", "#6750a4", "#3b82f6",
                    "#0284c7", "#06b6d4", "#10b981", "#22c55e", "#84cc16",
                    "#eab308", "#f59e0b", "#f97316", "#ef4444", "#ec4899",
                    "#d946ef", "#64748b"
                ]
                onPicked: hex => {
                    page.sys.cfg.m3ManualColor = hex;
                    page.sys.saveCfg();
                    page.sys.updateMatugenTheme();
                }
            }

            Text {
                Layout.fillWidth: true
                text: page.sys.tr("Consejo: También puedes elegir colores personalizados para Bluetooth, Wi-Fi, batería y ajustes más abajo en \"Colores del Sistema\".")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }
        }

        // Тумблер стоит здесь, рядом с выбором темы: карточки — часть облика,
        // а не отдельная служба.
        SetToggle {
            sys: page.sys
            label: page.sys.tr("Настольные виджеты")
            sub: page.sys.tr("Карточки на обоях: дата, погода и часы. Начертание берут у выбранной темы.")
            on: page.sys.cfg.featWidgets
            onToggled: v => { page.sys.cfg.featWidgets = v; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets && !page.sys.themeMaterial
            sys: page.sys
            label: page.sys.tr("Modo del reloj")
            options: [
                { id: "analog",  text: page.sys.tr("Analógico") },
                { id: "digital", text: page.sys.tr("Digital") }
            ]
            value: page.sys.cfg.widgetClockMode || "analog"
            onPicked: id => { page.sys.cfg.widgetClockMode = id; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets && !page.sys.themeMaterial
            sys: page.sys
            label: page.sys.tr("Widget secundario")
            options: [
                { id: "weather", text: page.sys.tr("Clima") },
                { id: "system",  text: page.sys.tr("Sistema") }
            ]
            value: page.sys.cfg.widgetRightMode || "weather"
            onPicked: id => { page.sys.cfg.widgetRightMode = id; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets && !page.sys.themeMaterial
            sys: page.sys
            label: page.sys.tr("Barra de progreso")
            options: [
                { id: "day",  text: page.sys.tr("Día (24H)") },
                { id: "year", text: page.sys.tr("Año (365D)") }
            ]
            value: page.sys.cfg.widgetProgressMode || "day"
            onPicked: id => { page.sys.cfg.widgetProgressMode = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.cfg.featWidgets
                     && page.sys.cfg.weatherKey.length === 0
            text: page.sys.tr("Впишите ключ и город во вкладке Weather, иначе карточка погоды останется пустой.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Прозрачность терминала. Здесь, а не в отдельной вкладке: это одна
        // ручка, и стоит она рядом с прочим внешним видом.
        SetSlider {
            sys: page.sys
            label: page.sys.tr("Прозрачность терминала")
            from: 0.5; to: 1.0; step: 0.01
            decimals: 2
            value: page.sys.cfg.termAlpha
            onMoved: v => {
                page.sys.cfg.termAlpha = v;
                page.sys.saveCfg();
                page.sys.applyTermAlpha();
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("1.00 — сплошной фон. Действует сразу; если нет — терминал держит свои настройки с прошлого входа, и его серверу нужен перезапуск.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Перезапустить терминал")
                onClicked: page.sys.restartTerminalServer()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Открытые окна терминала при этом закроются: они работают от того же сервера.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Приглушённый текст")
            from: 0.2; to: 1.0; step: 0.05
            decimals: 2
            value: page.sys.cfg.mutedAlpha
            onMoved: v => { page.sys.cfg.mutedAlpha = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- colores
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Colores del Sistema") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Forzar colores personalizados")
            sub: page.sys.tr("Aplica tus colores elegidos sobre cualquier tema, ignorando la paleta predeterminada.")
            on: page.sys.cfg.forceCustomColors
            onToggled: v => { page.sys.cfg.forceCustomColors = v; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color de Acento")
            sub: page.sys.tr("Resaltado de botones, deslizadores, bordes activos y elementos clave.")
            value: page.sys.cfg.colOn || "#3b82f6"
            defaultColor: "#3b82f6"
            presets: [
                "#007aff", "#3b82f6", "#0ea5e9", "#06b6d4", "#14b8a6",
                "#10b981", "#22c55e", "#84cc16", "#eab308", "#f59e0b",
                "#ff9f0a", "#f97316", "#ff453a", "#ef4444", "#ff2d55",
                "#f43f5e", "#ec4899", "#d946ef", "#8b5cf6", "#6366f1",
                "#ffffff", "#94a3b8"
            ]
            onPicked: hex => { page.sys.cfg.colOn = hex; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color de Texto Principal")
            sub: page.sys.tr("Texto general, números y etiquetas de la interfaz.")
            value: page.sys.cfg.colFg || "#ffffff"
            defaultColor: "#ffffff"
            presets: ["#ffffff", "#f8fafc", "#f1f5f9", "#e2e8f0", "#cbd5e1", "#94a3b8", "#fef3c7", "#ecfeff"]
            onPicked: hex => { page.sys.cfg.colFg = hex; page.sys.saveCfg(); }
        }

        SetLabel { sys: page.sys; text: page.sys.tr("Colores de Conectividad y Ajustes Rápidos") }

        SetColor {
            sys: page.sys
            label: "Bluetooth"
            sub: page.sys.tr("Tarjeta en Centro de Control, alertas e isla dinámica al conectar dispositivos (por defecto: celeste).")
            value: (page.sys && page.sys.cfg && page.sys.cfg.colBt) ? page.sys.cfg.colBt : "#0ea5e9"
            defaultColor: "#0ea5e9"
            presets: [
                "#0ea5e9", "#007aff", "#3b82f6", "#06b6d4", "#14b8a6",
                "#10b981", "#22c55e", "#84cc16", "#eab308", "#f59e0b",
                "#ff9f0a", "#f97316", "#ff453a", "#ef4444", "#ff2d55",
                "#f43f5e", "#ec4899", "#d946ef", "#8b5cf6", "#6366f1",
                "#ffffff", "#94a3b8"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.cfg) page.sys.cfg.colBt = hex;
                if (page.sys && page.sys.colBt !== undefined) page.sys.colBt = hex;
                if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
            }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Wi-Fi y Red")
            sub: page.sys.tr("Tarjeta en Centro de Control e indicadores al conectarse a la red.")
            value: (page.sys && page.sys.cfg && page.sys.cfg.colWifi) ? page.sys.cfg.colWifi : ((page.sys && page.sys.cfg && page.sys.cfg.colOn) ? page.sys.cfg.colOn : "#3b82f6")
            defaultColor: "#3b82f6"
            presets: [
                "#007aff", "#3b82f6", "#0ea5e9", "#06b6d4", "#14b8a6",
                "#10b981", "#22c55e", "#84cc16", "#eab308", "#f59e0b",
                "#ff9f0a", "#f97316", "#ff453a", "#ef4444", "#ff2d55",
                "#f43f5e", "#ec4899", "#d946ef", "#8b5cf6", "#6366f1",
                "#ffffff", "#94a3b8"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.cfg) page.sys.cfg.colWifi = hex;
                if (page.sys && page.sys.colWifi !== undefined) page.sys.colWifi = hex;
                if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
            }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Dictado por Voz / Micrófono")
            sub: page.sys.tr("Indicador de micrófono y ondas de escucha en la isla dinámica / barra superior.")
            value: (page.sys && page.sys.cfg && page.sys.cfg.colVox) ? page.sys.cfg.colVox : "#60a5fa"
            defaultColor: "#60a5fa"
            presets: [
                "#60a5fa", "#38bdf8", "#0ea5e9", "#3b82f6", "#818cf8",
                "#a78bfa", "#c084fc", "#e879f9", "#f472b6", "#fb7185",
                "#34d399", "#4ade80", "#a3e635", "#facc15", "#fb923c"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.cfg) page.sys.cfg.colVox = hex;
                if (page.sys && page.sys.colVox !== undefined) page.sys.colVox = hex;
                if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
            }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Grabación de Pantalla")
            sub: page.sys.tr("Color del botón y estado activo al grabar pantalla o capturar audio.")
            value: (page.sys && page.sys.cfg && page.sys.cfg.colRec) ? page.sys.cfg.colRec : "#ff453a"
            defaultColor: "#ff453a"
            presets: [
                "#ff453a", "#ef4444", "#dc2626", "#b91c1c", "#ff2d55",
                "#f43f5e", "#e11d48", "#ec4899", "#d946ef", "#f97316"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.cfg) page.sys.cfg.colRec = hex;
                if (page.sys && page.sys.colRec !== undefined) page.sys.colRec = hex;
                if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
            }
        }

        SetLabel { sys: page.sys; text: page.sys.tr("Colores de Batería y Alertas") }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color de Carga / 100%")
            sub: page.sys.tr("Color del rayo de carga y de las alertas de carga completada.")
            value: page.sys.cfg.colCharge || "#30D158"
            defaultColor: "#30D158"
            presets: [
                "#30D158", "#22c55e", "#10b981", "#059669", "#16a34a",
                "#84cc16", "#a3e635", "#2dd4bf", "#14b8a6", "#06b6d4",
                "#22d3ee", "#0ea5e9", "#3b82f6", "#007aff", "#ffffff", "#e2e8f0"
            ]
            onPicked: hex => { page.sys.cfg.colCharge = hex; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Batería Baja (Advertencia)")
            sub: page.sys.tr("Color de la alerta al 20% y del indicador en barra.")
            value: page.sys.cfg.colBattWarn || "#ff9f0a"
            defaultColor: "#ff9f0a"
            presets: [
                "#ff9f0a", "#f97316", "#ea580c", "#fb923c",
                "#f59e0b", "#d97706", "#b45309", "#eab308",
                "#facc15", "#fde047", "#fbbf24", "#ffffff", "#fef3c7"
            ]
            onPicked: hex => { page.sys.cfg.colBattWarn = hex; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Batería Crítica (15%)")
            sub: page.sys.tr("Color de la alerta al 15% y estado crítico.")
            value: page.sys.cfg.colBattCrit || "#ff453a"
            defaultColor: "#ff453a"
            presets: [
                "#ff453a", "#ef4444", "#dc2626", "#b91c1c", "#991b1b",
                "#ff2d55", "#f43f5e", "#e11d48", "#be123c", "#fb7185",
                "#ec4899", "#db2777", "#d946ef", "#ffffff", "#fee2e2"
            ]
            onPicked: hex => { page.sys.cfg.colBattCrit = hex; page.sys.saveCfg(); }
        }

        SetLabel { sys: page.sys; text: page.sys.tr("Colores de Modos de Energía (Ola de Batería)") }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Modo Ahorro")
            sub: page.sys.tr("Color de la ola y botón en perfil de bajo consumo.")
            value: (page.sys && page.sys.colPowerSaver) ? page.sys.colPowerSaver : ((page.sys && page.sys.cfg && page.sys.cfg.colPowerSaver) ? page.sys.cfg.colPowerSaver : "#22c55e")
            defaultColor: "#22c55e"
            presets: [
                "#30D158", "#22c55e", "#10b981", "#059669", "#16a34a",
                "#84cc16", "#a3e635", "#bef264", "#4ade80",
                "#2dd4bf", "#14b8a6", "#0d9488", "#5eead4",
                "#06b6d4", "#22d3ee", "#0891b2", "#38bdf8",
                "#ffffff", "#e2e8f0"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.setPowerColor) page.sys.setPowerColor("power-saver", hex);
                else {
                    if (page.sys) page.sys.colPowerSaver = hex;
                    if (page.sys && page.sys.cfg) page.sys.cfg.colPowerSaver = hex;
                    if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
                }
            }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Modo Equilibrado")
            sub: page.sys.tr("Color de la ola y botón en perfil balanceado.")
            value: (page.sys && page.sys.colPowerBalanced) ? page.sys.colPowerBalanced : ((page.sys && page.sys.cfg && page.sys.cfg.colPowerBalanced) ? page.sys.cfg.colPowerBalanced : "#3b82f6")
            defaultColor: "#3b82f6"
            presets: [
                "#007aff", "#3b82f6", "#2563eb", "#1d4ed8",
                "#60a5fa", "#93c5fd", "#38bdf8", "#0ea5e9",
                "#06b6d4", "#22d3ee", "#0891b2", "#00f0ff",
                "#6366f1", "#4f46e5", "#818cf8",
                "#8b5cf6", "#a855f7", "#7c3aed", "#c084fc",
                "#ffffff", "#e0f2fe"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.setPowerColor) page.sys.setPowerColor("balanced", hex);
                else {
                    if (page.sys) page.sys.colPowerBalanced = hex;
                    if (page.sys && page.sys.cfg) page.sys.cfg.colPowerBalanced = hex;
                    if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
                }
            }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Modo Rendimiento")
            sub: page.sys.tr("Color de la ola y botón en perfil de máximo rendimiento.")
            value: (page.sys && page.sys.colPowerPerf) ? page.sys.colPowerPerf : ((page.sys && page.sys.cfg && page.sys.cfg.colPowerPerf) ? page.sys.cfg.colPowerPerf : "#ff453a")
            defaultColor: "#ff453a"
            presets: [
                "#ff453a", "#ef4444", "#dc2626", "#b91c1c", "#991b1b",
                "#ff2d55", "#f43f5e", "#e11d48", "#fb7185",
                "#ff9f0a", "#f97316", "#ea580c", "#fb923c",
                "#f59e0b", "#d97706", "#eab308", "#facc15",
                "#ec4899", "#db2777", "#d946ef", "#c026d3",
                "#ffffff", "#fee2e2"
            ]
            onPicked: hex => {
                if (page.sys && page.sys.setPowerColor) page.sys.setPowerColor("performance", hex);
                else {
                    if (page.sys) page.sys.colPowerPerf = hex;
                    if (page.sys && page.sys.cfg) page.sys.cfg.colPowerPerf = hex;
                    if (page.sys && page.sys.saveCfg) page.sys.saveCfg();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Restaurar todos los colores")
                onClicked: {
                    page.sys.cfg.colOn = "#3b82f6";
                    page.sys.cfg.colFg = "#ffffff";
                    page.sys.cfg.colCharge = "#30D158";
                    page.sys.cfg.colBattWarn = "#ff9f0a";
                    page.sys.cfg.colBattCrit = "#ff453a";
                    page.sys.cfg.colPowerSaver = "#22c55e";
                    page.sys.cfg.colPowerBalanced = "#3b82f6";
                    page.sys.cfg.colPowerPerf = "#ff453a";
                    page.sys.cfg.colBt = "#0ea5e9";
                    page.sys.cfg.colWifi = "#3b82f6";
                    page.sys.cfg.colVox = "#60a5fa";
                    page.sys.cfg.colRec = "#ff453a";
                    page.sys.cfg.forceCustomColors = false;
                    page.sys.saveCfg();
                }
            }
        }
    }

    // ------------------------------------------------------------- шрифты
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Type") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Font size")
            from: 10; to: 24; step: 1
            value: page.sys.cfg.fontSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.fontSize = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Icon size")
            from: 12; to: 28; step: 1
            value: page.sys.cfg.iconSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.iconSize = v; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Body font")
            options: page.sys.fontList
            value: page.sys.cfg.fontBody || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontBody = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Display font")
            options: page.sys.fontList
            value: page.sys.cfg.fontDisplay || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontDisplay = id; page.sys.saveCfg(); }
        }

        // Значковый шрифт отдельно: подписи можно поставить любые, но иконки
        // рисует только Nerd Font, и менять его вместе с текстовым нельзя.
        SetPick {
            sys: page.sys
            label: page.sys.tr("Шрифт значков")
            options: page.sys.fontList
            value: page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontFam = id; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- геометрия
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Shape & depth") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Spacing unit")
            from: 4; to: 16; step: 1
            value: page.sys.cfg.spacingUnit
            suffix: "px"
            onMoved: v => { page.sys.cfg.spacingUnit = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Small radius")
            from: 0; to: 24; step: 1
            value: page.sys.cfg.smallRadius
            suffix: "px"
            onMoved: v => { page.sys.cfg.smallRadius = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- звуки
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Звуки") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Звуковые эффекты системы")
            sub: page.sys.tr("Зарядка, подключение Bluetooth, скриншоты, голосовой ввод")
            on: page.sys.cfg.uiSounds !== false
            onToggled: value => {
                page.sys.cfg.uiSounds = value;
                page.sys.saveCfg();
                if (value) page.sys.playSound("connect");
            }
        }

        SetSelect {
            sys: page.sys
            visible: page.sys.cfg.uiSounds !== false
            label: page.sys.tr("Tema de Sonido")
            options: [
                { id: "auto",     text: page.sys.tr("Automático (según apariencia)") },
                { id: "nothing",  text: "Nothing OS (Digital / Minimalista)" },
                { id: "material", text: "Material You (Profundo / Acústico)" }
            ]
            value: page.sys.cfg.soundPack || "auto"
            onPicked: id => {
                page.sys.cfg.soundPack = id;
                page.sys.saveCfg();
                page.sys.playSound("connect");
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: page.sys.cfg.uiSounds !== false
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.sys.tr("• Pack de sonido activo: ") + page.sys.activeSoundPack().toUpperCase() + page.sys.tr(" (asignado por apariencia o preset).")
                color: page.sys.colOn
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: openStudioRow.implicitWidth + 20
                radius: 6
                color: openStudioMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                border.color: page.sys.colOn
                border.width: 1

                RowLayout {
                    id: openStudioRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰕾"
                        color: page.sys.colOn
                        font { family: page.sys.fontFam; pixelSize: 12 }
                    }
                    Text {
                        text: page.sys.tr("Abrir Estudio de Sonido")
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                    }
                }

                MouseArea {
                    id: openStudioMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.sys.openSettingsAt("sounds")
                }
            }
        }

        // Кнопки предпрослушивания звуков (Dynamic Island & Panacea)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Text {
                Layout.fillWidth: true
                text: page.sys.tr("Предпрослушивание эффектов:")
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }

            Rectangle {
                id: testAllAppearanceBtn
                Layout.preferredHeight: 28
                Layout.preferredWidth: testAllAppRow.implicitWidth + 20
                radius: 6
                visible: page.sys.cfg.uiSounds !== false
                color: page.allSoundAppTimer.running ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25)
                                                : (testAllAppMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                border.color: page.allSoundAppTimer.running ? page.sys.colOn : (testAllAppMa.containsMouse ? page.sys.colOn : page.sys.colLine)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: testAllAppRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: page.allSoundAppTimer.running ? "󰏤" : "󰐊"
                        color: page.sys.colOn
                        font { family: page.sys.fontFam; pixelSize: 12 }
                    }
                    Text {
                        text: page.allSoundAppTimer.running ? page.sys.tr("Остановить") : page.sys.tr("Воспроизвести все звуки")
                        color: page.allSoundAppTimer.running ? page.sys.colOn : page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                    }
                }

                MouseArea {
                    id: testAllAppMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.allSoundAppTimer.running) {
                            page.allSoundAppTimer.stop();
                            page.allSoundAppIdx = -1;
                        } else {
                            page.allSoundAppIdx = 0;
                            page.sys.playSound(page.soundAppearanceModel[0].id);
                            page.allSoundAppTimer.start();
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6
            visible: page.sys.cfg.uiSounds !== false

            Repeater {
                model: page.soundAppearanceModel

                Rectangle {
                    id: sndBtn
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    readonly property bool isAuditioning: page.allSoundAppTimer.running && page.allSoundAppIdx >= 0 && page.allSoundAppIdx < page.soundAppearanceModel.length && page.soundAppearanceModel[page.allSoundAppIdx] && page.soundAppearanceModel[page.allSoundAppIdx].id === modelData.id
                    color: isAuditioning
                        ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                        : (sndMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: isAuditioning
                        ? page.sys.colOn
                        : (sndMa.containsMouse ? page.sys.colOn : page.sys.colLine)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.icon
                            color: sndMa.containsMouse ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: modelData.label
                            color: sndMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.sys.playSound(modelData.id)
                    }
                }
            }
        }
    }
}
