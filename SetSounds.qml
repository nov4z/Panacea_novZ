import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Panel de Ajustes: Estudio de Sonido & Síntesis Acústica
// Módulos divididos, comprensibles y con parámetros físicos ampliados.
ColumnLayout {
    id: page

    property var sys

    // Pack seleccionado para el banco de pruebas
    property string auditionPack: page.sys ? page.sys.activeSoundPack() : "material"

    // Estado del compilador de sonidos
    property string compileStatus: ""
    property bool isCompiling: false

    // Estado del reproductor de prueba en serie
    property int allSoundIdx: -1
    property alias allSoundTimer: allSoundTimer

    property var soundPacksList: [
        { id: "nothing",  text: "Nothing OS",    icon: "󰇙", desc: "Digital minimalista, clicks breves y agudos" },
        { id: "material", text: "Material You",   icon: "󰏤", desc: "Acústico profundo, marimba y cuerpo orgánico" },
        { id: "zen",      text: "Zen Calma",     icon: "󰌪", desc: "Madera suave, resonancia baja y caída lenta" },
        { id: "cyber",    text: "Cyberpunk FM",  icon: "󰓅", desc: "Síntesis FM brillante y modulación sci-fi" },
        { id: "retro",    text: "Retro 8-Bit",   icon: "󰘚", desc: "Chiptune arcade puro de ondas cuadradas" },
        { id: "bubble",   text: "Aqua Bubble",   icon: "󰍜", desc: "Burbujas líquidas con glide de frecuencia" },
        { id: "custom",   text: "Personalizado", icon: "󰌌", desc: "Sintetizado según los parámetros del estudio" }
    ]

    // Modelos divididos por categorías funcionales
    property var soundsSystem: [
        { id: "island_pop",        label: "Notch Pop",               icon: "󰍜" },
        { id: "settings_open",     label: "Ajustes (Super+I)",       icon: "󰅀" },
        { id: "settings_close",    label: "Ajustes (Cerrar)",        icon: "󰅖" },
        { id: "notification",      label: "Notificación Entrante",   icon: "󰂚" },
        { id: "screenshot",        label: "Captura de Pantalla",     icon: "󰄀" }
    ]

    property var soundsPower: [
        { id: "charge",           label: "Cargador Conectado",      icon: "󰂄" },
        { id: "batt_full",        label: "Batería Completa 100%",   icon: "󰁹" },
        { id: "batt_full",        label: "Carga Segura 80%",        icon: "󰂂" },
        { id: "lowbatt",          label: "Batería Baja / Aviso",    icon: "󰂃" },
        { id: "mode_powersave",   label: "Modo Ahorro",             icon: "󰌪" },
        { id: "mode_balanced",    label: "Modo Equilibrado",        icon: "󰾅" },
        { id: "mode_performance", label: "Modo Rendimiento",        icon: "󰓅" }
    ]

    property var soundsSecurity: [
        { id: "lock",        label: "Cámara Bloqueada (Obturador)",   icon: "󰄟" },
        { id: "unlock",      label: "Cámara Desbloqueada (Activa)",   icon: "󰄀" },
        { id: "lock",        label: "Bloqueo de Pantalla",            icon: "󰌾" },
        { id: "unlock",      label: "Desbloqueo de Sesión",           icon: "󰌿" },
        { id: "voice_start", label: "Asistente Voz Inicio",           icon: "󰍬" },
        { id: "voice_done",  label: "Asistente Voz Fin",              icon: "󰍭" }
    ]

    property var soundsTouch: [
        { id: "connect",     label: "Bluetooth Conectar",      icon: "󰂯" },
        { id: "disconnect",  label: "Bluetooth Desconectar",   icon: "󰂲" },
        { id: "kbd_light_0", label: "Luz Teclado 0% (Off)",    icon: "󰌌" },
        { id: "kbd_light_1", label: "Luz Teclado 50% (Media)", icon: "󰌌" },
        { id: "kbd_light_2", label: "Luz Teclado 100% (Full)", icon: "󰌌" },
        { id: "tock",        label: "Tock Táctil / Switch",    icon: "󰌌" },
        { id: "vol_tick",    label: "Paso de Volumen",         icon: "󰕾" }
    ]

    // Lista concatenada para el reproductor secuencial
    readonly property var allSoundsList: soundsSystem.concat(soundsPower).concat(soundsSecurity).concat(soundsTouch)

    Timer {
        id: allSoundTimer
        interval: 440
        repeat: true
        onTriggered: {
            page.allSoundIdx++;
            if (page.allSoundIdx < page.allSoundsList.length) {
                page.sys.playSound(page.allSoundsList[page.allSoundIdx].id, page.auditionPack);
            } else {
                page.allSoundIdx = -1;
                allSoundTimer.stop();
            }
        }
    }

    Timer {
        id: clearStatusTimer
        interval: 3500
        repeat: false
        onTriggered: page.compileStatus = ""
    }

    // Proceso para compilar packs de sonido en segundo plano
    Process {
        id: pCompile
        command: []
        onExited: code => {
            page.isCompiling = false;
            if (code === 0) {
                page.compileStatus = page.sys.isEn ? "Pack compiled and ready!" : "¡Pack generado con éxito!";
                page.sys.playSound("connect", page.auditionPack);
            } else {
                page.compileStatus = page.sys.isEn ? "Generation error." : "Error al sintetizar.";
            }
            clearStatusTimer.restart();
        }
    }


    // Proceso para previsualizar sonido en tiempo real
    Process {
        id: pPreview
        command: []
    }

    property bool isPreviewPlaying: false
    Timer {
        id: previewPulseTimer
        interval: 1400
        repeat: false
        onTriggered: page.isPreviewPlaying = false
    }

    function runPreview() {
        page.isPreviewPlaying = true;
        previewPulseTimer.restart();

        var style = page.sys.cfg.soundCustomStyle || "marimba";
        var depth = page.sys.cfg.soundCustomDepth !== undefined ? page.sys.cfg.soundCustomDepth : 0.6;
        var att = page.sys.cfg.soundCustomAttack !== undefined ? page.sys.cfg.soundCustomAttack : 0.5;
        var dec = page.sys.cfg.soundCustomDecay !== undefined ? page.sys.cfg.soundCustomDecay : 1.0;
        var bri = page.sys.cfg.soundCustomBright !== undefined ? page.sys.cfg.soundCustomBright : 0.5;
        var pitch = page.sys.cfg.soundCustomPitch !== undefined ? page.sys.cfg.soundCustomPitch : 0.0;
        var warmth = page.sys.cfg.soundCustomWarmth !== undefined ? page.sys.cfg.soundCustomWarmth : 0.2;
        var spatial = page.sys.cfg.soundCustomSpatialWidth !== undefined ? page.sys.cfg.soundCustomSpatialWidth : 0.50;
        var reverb = page.sys.cfg.soundCustomReverb !== undefined ? page.sys.cfg.soundCustomReverb : 0.15;
        var vib = page.sys.cfg.soundCustomVibrato !== undefined ? page.sys.cfg.soundCustomVibrato : 0.0;
        var cut = page.sys.cfg.soundCustomCutoff !== undefined ? page.sys.cfg.soundCustomCutoff : 1.0;
        var gain = page.sys.cfg.soundCustomGain !== undefined ? page.sys.cfg.soundCustomGain : 1.0;

        pPreview.command = [
            "python3", Quickshell.env("HOME") + "/.config/panacea/sound_engine.py", "preview",
            "--style", style,
            "--depth", depth.toFixed(2),
            "--attack", att.toFixed(2),
            "--decay", dec.toFixed(2),
            "--brightness", bri.toFixed(2),
            "--pitch", pitch.toFixed(1),
            "--warmth", warmth.toFixed(2),
            "--spatial", spatial.toFixed(2),
            "--reverb", reverb.toFixed(2),
            "--vibrato", vib.toFixed(2),
            "--cutoff", cut.toFixed(2),
            "--gain", gain.toFixed(2)
        ];
        pPreview.running = false;
        pPreview.running = true;
    }

    function generateCustomPack() {
        if (page.isCompiling) return;
        page.isCompiling = true;
        page.compileStatus = page.sys.isEn ? "Synthesizing custom pack..." : "Sintetizando pack personalizado...";

        var style = page.sys.cfg.soundCustomStyle || "marimba";
        var depth = page.sys.cfg.soundCustomDepth !== undefined ? page.sys.cfg.soundCustomDepth : 0.6;
        var att = page.sys.cfg.soundCustomAttack !== undefined ? page.sys.cfg.soundCustomAttack : 0.5;
        var dec = page.sys.cfg.soundCustomDecay !== undefined ? page.sys.cfg.soundCustomDecay : 1.0;
        var bri = page.sys.cfg.soundCustomBright !== undefined ? page.sys.cfg.soundCustomBright : 0.5;
        var pitch = page.sys.cfg.soundCustomPitch !== undefined ? page.sys.cfg.soundCustomPitch : 0.0;
        var warmth = page.sys.cfg.soundCustomWarmth !== undefined ? page.sys.cfg.soundCustomWarmth : 0.2;
        var spatial = page.sys.cfg.soundCustomSpatialWidth !== undefined ? page.sys.cfg.soundCustomSpatialWidth : 0.50;
        var reverb = page.sys.cfg.soundCustomReverb !== undefined ? page.sys.cfg.soundCustomReverb : 0.15;
        var vib = page.sys.cfg.soundCustomVibrato !== undefined ? page.sys.cfg.soundCustomVibrato : 0.0;
        var cut = page.sys.cfg.soundCustomCutoff !== undefined ? page.sys.cfg.soundCustomCutoff : 1.0;
        var gain = page.sys.cfg.soundCustomGain !== undefined ? page.sys.cfg.soundCustomGain : 1.0;

        pCompile.command = [
            "python3", Quickshell.env("HOME") + "/.config/panacea/sound_engine.py", "generate",
            "--pack", "custom",
            "--style", style,
            "--depth", depth.toFixed(2),
            "--attack", att.toFixed(2),
            "--decay", dec.toFixed(2),
            "--brightness", bri.toFixed(2),
            "--pitch", pitch.toFixed(1),
            "--warmth", warmth.toFixed(2),
            "--spatial", spatial.toFixed(2),
            "--reverb", reverb.toFixed(2),
            "--vibrato", vib.toFixed(2),
            "--cutoff", cut.toFixed(2),
            "--gain", gain.toFixed(2)
        ];
        pCompile.running = false;
        pCompile.running = true;
    }


    Layout.fillWidth: true
    spacing: 16

    // ---------------------------------------------------------- Encabezado General
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: page.sys.isEn ? "Sound Studio & Acoustic Synthesis" : "Estudio de Sonido & Síntesis Acústica"
            color: page.sys.colFg
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize + 3; bold: true }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.isEn
                ? "Organized studio: configure independent sound themes per appearance, tweak expanded acoustic DSP parameters, or audition categorized audio groups."
                : "Estudio organizado por módulos: asigna temas por apariencia, diseña timbres con parámetros DSP ampliados o audiciona grupos de sonidos categorizados."
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }
    }

    // ---------------------------------------------------------- 1. ESTADO GLOBAL & INTERRUPTOR
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.20)
                border.color: page.sys.colOn
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰕾"
                    color: page.sys.colOn
                    font { family: page.sys.fontFam; pixelSize: 18 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.isEn ? "System Audio Status" : "Estado del Audio del Sistema"
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
                Text {
                    text: (page.sys.isEn ? "Active Playing Pack: " : "Pack Actualmente en Reproducción: ")
                          + page.sys.activeSoundPack().toUpperCase()
                    color: page.sys.colOn
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                }
            }

            // Botón de prueba rápida
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: testBtnRow.implicitWidth + 20
                radius: 14
                color: testMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                border.color: page.sys.colOn
                border.width: 1

                RowLayout {
                    id: testBtnRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "󰐊"; color: page.sys.colOn; font { family: page.sys.fontFam; pixelSize: 11 } }
                    Text {
                        text: page.sys.isEn ? "Test Sound" : "Probar Sonido"
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                    }
                }

                MouseArea {
                    id: testMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.sys.playSound("connect")
                }
            }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.isEn ? "Master UI Sound Effects" : "Efectos de sonido de la interfaz"
            sub: page.sys.isEn
                ? "Master toggle for all notifications, battery alerts, sliders, and profile chimes."
                : "Interruptor maestro para todos los avisos, alertas de batería, deslizadores y notch."
            on: page.sys.cfg.uiSounds !== false
            onToggled: v => {
                page.sys.cfg.uiSounds = v;
                page.sys.saveCfg();
                if (v) page.sys.playSound("connect");
            }
        }
    }


    // ---------------------------------------------------------- 2. ASIGNACIÓN POR APARIENCIA (SEPARADO)
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰓃"
                color: page.sys.colOn
                font { family: page.sys.fontFam; pixelSize: 18 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.isEn ? "Sound Assignment per Visual Theme" : "Asignación de Sonidos por Tema Visual"
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
                Text {
                    text: page.sys.isEn
                        ? "Choose whether sounds switch dynamically when changing desktop themes or stay fixed."
                        : "Elige si los sonidos cambian automáticamente al alternar apariencias o permanecen fijos."
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }

        SetSelect {
            sys: page.sys
            visible: page.sys.cfg.uiSounds !== false
            label: page.sys.isEn ? "Binding Mode" : "Modo de Selección de Pack"
            options: [
                { id: "auto",     text: page.sys.isEn ? "Dynamic by Appearance" : "Por Apariencia" },
                { id: "override", text: page.sys.isEn ? "Global Fixed"          : "Fijo Global" }
            ]
            value: page.sys.cfg.soundPack === "auto" ? "auto" : "override"
            onPicked: id => {
                if (id === "auto") {
                    page.sys.cfg.soundPack = "auto";
                } else {
                    page.sys.cfg.soundPack = page.sys.activeSoundPack();
                }
                page.sys.saveCfg();
                page.sys.playSound("connect");
            }
        }

        // Sub-bloque: Fijo Global
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: fixedCol.implicitHeight + 20
            visible: page.sys.cfg.uiSounds !== false && page.sys.cfg.soundPack !== "auto"
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.08)

            ColumnLayout {
                id: fixedCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                SetSelect {
                    sys: page.sys
                    label: page.sys.isEn ? "Fixed System Pack" : "Pack Fijo para Todo el Sistema"
                    options: [
                        { id: "nothing",  text: "Nothing" },
                        { id: "material", text: "Material" },
                        { id: "zen",      text: "Zen" },
                        { id: "cyber",    text: "Cyber" },
                        { id: "retro",    text: "Retro" },
                        { id: "bubble",   text: "Bubble" },
                        { id: "custom",   text: "Personalizado" }
                    ]
                    value: page.sys.cfg.soundPack
                    onPicked: id => {
                        page.sys.cfg.soundPack = id;
                        page.sys.saveCfg();
                        page.auditionPack = id;
                        page.sys.playSound("connect", id);
                    }
                }
            }
        }

        // Sub-bloque: Por Apariencia Dividido
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: page.sys.cfg.uiSounds !== false && page.sys.cfg.soundPack === "auto"

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: nothRow.implicitHeight + 16
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: page.sys.themeNothing ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.07)

                RowLayout {
                    id: nothRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Text { text: "󰇙"; color: page.sys.colOn; font { family: page.sys.fontFam; pixelSize: 14 } }

                    SetSelect {
                        sys: page.sys
                        label: page.sys.isEn ? "Nothing OS Appearance Sound" : "Sonido para Apariencia Nothing OS"
                        options: [
                            { id: "nothing",  text: "Nothing" },
                            { id: "material", text: "Material" },
                            { id: "zen",      text: "Zen" },
                            { id: "cyber",    text: "Cyber" },
                            { id: "retro",    text: "Retro" },
                            { id: "bubble",   text: "Bubble" },
                            { id: "custom",   text: "Personalizado" }
                        ]
                        value: page.sys.cfg.soundPackForNothing || "nothing"
                        onPicked: id => {
                            page.sys.cfg.soundPackForNothing = id;
                            page.sys.saveCfg();
                            page.auditionPack = id;
                            page.sys.playSound("connect", id);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: matRow.implicitHeight + 16
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: page.sys.themeMaterial ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.07)

                RowLayout {
                    id: matRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Text { text: "󰏤"; color: page.sys.colOn; font { family: page.sys.fontFam; pixelSize: 14 } }

                    SetSelect {
                        sys: page.sys
                        label: page.sys.isEn ? "Material You Appearance Sound" : "Sonido para Apariencia Material You"
                        options: [
                            { id: "material", text: "Material" },
                            { id: "nothing",  text: "Nothing" },
                            { id: "zen",      text: "Zen" },
                            { id: "cyber",    text: "Cyber" },
                            { id: "retro",    text: "Retro" },
                            { id: "bubble",   text: "Bubble" },
                            { id: "custom",   text: "Personalizado" }
                        ]
                        value: page.sys.cfg.soundPackForMaterial || "material"
                        onPicked: id => {
                            page.sys.cfg.soundPackForMaterial = id;
                            page.sys.saveCfg();
                            page.auditionPack = id;
                            page.sys.playSound("connect", id);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: clasRow.implicitHeight + 16
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: (!page.sys.themeNothing && !page.sys.themeMaterial) ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.07)

                RowLayout {
                    id: clasRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Text { text: "󰘚"; color: page.sys.colOn; font { family: page.sys.fontFam; pixelSize: 14 } }

                    SetSelect {
                        sys: page.sys
                        label: page.sys.isEn ? "Classic Appearance Sound" : "Sonido para Apariencia Clásica"
                        options: [
                            { id: "nothing",  text: "Nothing" },
                            { id: "material", text: "Material" },
                            { id: "zen",      text: "Zen" },
                            { id: "cyber",    text: "Cyber" },
                            { id: "retro",    text: "Retro" },
                            { id: "bubble",   text: "Bubble" },
                            { id: "custom",   text: "Personalizado" }
                        ]
                        value: page.sys.cfg.soundPackForDefault || "nothing"
                        onPicked: id => {
                            page.sys.cfg.soundPackForDefault = id;
                            page.sys.saveCfg();
                            page.auditionPack = id;
                            page.sys.playSound("connect", id);
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- 3. PRESETS TEMÁTICOS DE UN CLIC
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰓎"
                color: page.sys.colOn
                font { family: page.sys.fontFam; pixelSize: 18 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.isEn ? "Curated Sonic Presets" : "Colección de Presets Temáticos"
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
                Text {
                    text: page.sys.isEn
                        ? "Click any card to select for audition, or click play to preview its signature tone."
                        : "Haz clic en una tarjeta para seleccionarla en el banco de pruebas o en el botón para escucharla."
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: page.soundPacksList

                Rectangle {
                    id: presetCard
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    radius: 10
                    color: page.auditionPack === modelData.id
                        ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.16)
                        : (presetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.color: page.auditionPack === modelData.id
                        ? page.sys.colOn
                        : (presetMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.5) : page.sys.colLine)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: modelData.icon
                                color: page.sys.colOn
                                font { family: page.sys.fontFam; pixelSize: 15 }
                            }

                            Text {
                                text: modelData.text
                                color: page.sys.colFg
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: true }
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 12
                                color: quickPlayMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐊"
                                    color: page.sys.colOn
                                    font { family: page.sys.fontFam; pixelSize: 11 }
                                }

                                MouseArea {
                                    id: quickPlayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        page.auditionPack = modelData.id;
                                        page.sys.playSound("connect", modelData.id);
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: page.sys.colMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 5 }
                        }
                    }

                    MouseArea {
                        id: presetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.auditionPack = modelData.id;
                            page.sys.playSound("mode_balanced", modelData.id);
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- 4. SINTETIZADOR INTERACTIVO DIVIDIDO POR BLOQUES
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰌌"
                color: page.sys.colOn
                font { family: page.sys.fontFam; pixelSize: 18 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.isEn ? "Physical Synthesizer (Custom Pack)" : "Sintetizador Físico (Pack Personalizado)"
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
                Text {
                    text: page.sys.isEn
                        ? "Granular parameters divided into logical acoustic blocks: Timing, Pitch & Harmonics, Texture & Ambience, and Output."
                        : "Parámetros acústicos divididos en bloques comprensibles: Envolvente, Tono y Armónicos, Textura y Espacialidad, y Nivel Master."
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }

        // --- BLOQUE A: ENVOLVENTE & TIEMPO ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: blkATitle.implicitHeight + blkACol.implicitHeight + 24
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: Qt.rgba(1, 1, 1, 0.07)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: blkATitle
                    spacing: 6
                    Text { text: "⏱️"; font { pixelSize: 13 } }
                    Text {
                        text: page.sys.isEn ? "1. Envelope & Timing" : "1. Envolvente & Dinámica Temporal"
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                    }
                }

                ColumnLayout {
                    id: blkACol
                    Layout.fillWidth: true
                    spacing: 6

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Attack Softness (Transient shaping)" : "Suavidad de Ataque (Click percusivo vs Entrada suave)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomAttack !== undefined ? page.sys.cfg.soundCustomAttack : 0.5) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomAttack = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Decay & Resonance (Sustain multiplier)" : "Caída y Sostén (Duración natural de la nota)"
                        from: 40; to: 250; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomDecay !== undefined ? page.sys.cfg.soundCustomDecay : 1.0) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomDecay = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }
                }
            }
        }

        // --- BLOQUE B: TONO, ARMÓNICOS & FILTRO ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: blkBTitle.implicitHeight + blkBCol.implicitHeight + 24
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: Qt.rgba(1, 1, 1, 0.07)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: blkBTitle
                    spacing: 6
                    Text { text: "🎵"; font { pixelSize: 13 } }
                    Text {
                        text: page.sys.isEn ? "2. Pitch, Harmonics & Filter" : "2. Tono, Armónicos & Filtro Frecuencial"
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                    }
                }

                ColumnLayout {
                    id: blkBCol
                    Layout.fillWidth: true
                    spacing: 6

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Pitch Transpose (General semitones)" : "Afinación General (Transposición tonal)"
                        from: -12; to: 12; step: 1; suffix: " st"
                        value: Math.round(page.sys.cfg.soundCustomPitch !== undefined ? page.sys.cfg.soundCustomPitch : 0.0)
                        onMoved: v => {
                            page.sys.cfg.soundCustomPitch = v;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Subharmonic Depth (Low-end body)" : "Profundidad de Graves (Subarmónicos f/2 y f/4)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomDepth !== undefined ? page.sys.cfg.soundCustomDepth : 0.6) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomDepth = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "High Brightness (Upper overtones)" : "Brillo de Armónicos Altos (Agudos cristalinos)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomBright !== undefined ? page.sys.cfg.soundCustomBright : 0.5) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomBright = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Low-pass Filter Cutoff (Dark vs Open)" : "Filtro Paso Bajo (Timbre oscuro vs abierto)"
                        from: 20; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomCutoff !== undefined ? page.sys.cfg.soundCustomCutoff : 1.0) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomCutoff = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }
                }
            }
        }

        // --- BLOQUE C: TEXTURA, CALIDEZ & ESPACIO ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: blkCTitle.implicitHeight + blkCCol.implicitHeight + 24
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: Qt.rgba(1, 1, 1, 0.07)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: blkCTitle
                    spacing: 6
                    Text { text: "✨"; font { pixelSize: 13 } }
                    Text {
                        text: page.sys.isEn ? "3. Texture, Warmth & Spatial Reverb" : "3. Textura, Calidez & Espacialidad"
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                    }
                }

                ColumnLayout {
                    id: blkCCol
                    Layout.fillWidth: true
                    spacing: 6

                    SetSelect {
                        sys: page.sys
                        label: page.sys.isEn ? "Oscillator Timbre Model" : "Modelo de Oscilador Base"
                        options: [
                            { id: "marimba", text: "Marimba" },
                            { id: "glass",   text: "Cristal" },
                            { id: "fm",      text: "FM Sci-Fi" },
                            { id: "bit",     text: "8-Bit" },
                            { id: "bubble",  text: "Burbuja" }
                        ]
                        value: page.sys.cfg.soundCustomStyle || "marimba"
                        onPicked: id => {
                            page.sys.cfg.soundCustomStyle = id;
                            page.sys.saveCfg();
                            page.runPreview();
                        }
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Analog Warmth & Drive" : "Calidez Analógica (Saturación suave y armónicos)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomWarmth !== undefined ? page.sys.cfg.soundCustomWarmth : 0.2) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomWarmth = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Stereo Spatial Width (Lateral soundstage & diffusion)" : "Espacialidad Estéreo (Apertura y difusión lateral)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomSpatialWidth !== undefined ? page.sys.cfg.soundCustomSpatialWidth : 0.50) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomSpatialWidth = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Acoustic Reverb Tail (Room reflections & decay duration)" : "Cola de Reverb Acústica (Reflexiones de sala y caída)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomReverb !== undefined ? page.sys.cfg.soundCustomReverb : 0.15) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomReverb = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Subtle Vibrato Modulation" : "Modulación de Vibrato (Oscilación sutil de tono)"
                        from: 0; to: 100; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomVibrato !== undefined ? page.sys.cfg.soundCustomVibrato : 0.0) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomVibrato = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }
                }
            }
        }

        // --- BLOQUE D: SALIDA MASTER & ACCIONES ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: blkDTitle.implicitHeight + blkDCol.implicitHeight + 24
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: Qt.rgba(1, 1, 1, 0.07)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: blkDTitle
                    spacing: 6
                    Text { text: "🔊"; font { pixelSize: 13 } }
                    Text {
                        text: page.sys.isEn ? "4. Master Gain & Actions" : "4. Ganancia Master & Acciones"
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                    }
                }

                ColumnLayout {
                    id: blkDCol
                    Layout.fillWidth: true
                    spacing: 8

                    SetSlider {
                        sys: page.sys
                        label: page.sys.isEn ? "Master Output Gain" : "Ganancia de Salida Master"
                        from: 50; to: 150; step: 5; suffix: "%"
                        value: Math.round((page.sys.cfg.soundCustomGain !== undefined ? page.sys.cfg.soundCustomGain : 1.0) * 100)
                        onMoved: v => {
                            page.sys.cfg.soundCustomGain = v / 100.0;
                            page.sys.saveCfg();
                        }
                        onReleased: page.runPreview()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12

                        // Botón de Previsualizar
                        Rectangle {
                            id: btnPrevRect
                            readonly property bool isAuditioning: page.isPreviewPlaying || (pPreview && pPreview.running)
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: btnPrevRow.implicitWidth + 28
                            radius: 8
                            color: isAuditioning
                                ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                                : (prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                            border.color: isAuditioning ? page.sys.colOn : (prevMa.containsMouse ? page.sys.colOn : page.sys.colLine)
                            border.width: isAuditioning ? 1.5 : 1
                            scale: isAuditioning ? 1.03 : (prevMa.containsMouse ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            RowLayout {
                                id: btnPrevRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: btnPrevRect.isAuditioning ? "󰎈" : "󰐊"
                                    color: page.sys.colOn
                                    font { family: page.sys.fontFam; pixelSize: 13 }
                                    scale: btnPrevRect.isAuditioning ? 1.25 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                }
                                Text {
                                    text: page.sys.isEn ? "Audition Tone" : "Probar Acorde en Vivo"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                                }
                                Rectangle {
                                    visible: btnPrevRect.isAuditioning
                                    width: 6; height: 6; radius: 3
                                    color: page.sys.colOn
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: btnPrevRect.isAuditioning
                                        NumberAnimation { from: 0.3; to: 1.0; duration: 250; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 1.0; to: 0.3; duration: 250; easing.type: Easing.InOutQuad }
                                    }
                                }
                            }

                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.runPreview()
                            }
                        }

                        // Botón de Compilar Todo el Pack Custom
                        Rectangle {
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: btnCompRow.implicitWidth + 28
                            radius: 8
                            color: page.isCompiling
                                ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25)
                                : (compMa.containsMouse ? page.sys.colOn : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.85))

                            RowLayout {
                                id: btnCompRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: page.isCompiling ? "󰑣" : "󰌌"
                                    color: Qt.color("#000000")
                                    font { family: page.sys.fontFam; pixelSize: 14 }
                                    RotationAnimation on rotation {
                                        running: page.isCompiling
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 800
                                    }
                                }
                                Text {
                                    text: page.isCompiling
                                        ? (page.sys.isEn ? "Synthesizing suite..." : "Sintetizando colección...")
                                        : (page.sys.isEn ? "Compile 'Custom' Pack (20 Studio Sounds)" : "Compilar Pack 'Custom' (20 Sonidos de Estudio)")
                                    color: Qt.color("#000000")
                                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                                }
                            }

                            MouseArea {
                                id: compMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.generateCustomPack();
                                    page.auditionPack = "custom";
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.compileStatus
                            color: page.sys.colOn
                            elide: Text.ElideRight
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- 5. BANCO DE AUDICIÓN DIVIDIDO POR CATEGORÍAS
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "󰕾"
                color: page.sys.colOn
                font { family: page.sys.fontFam; pixelSize: 18 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.isEn ? "Audition Board (Divided by Categories)" : "Banco de Pruebas (Dividido por Categorías)"
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
                Text {
                    text: page.sys.isEn
                        ? "Categorized sound triggers. Click any button to play its acoustic sample immediately."
                        : "Sonidos organizados por categoría. Haz clic en cualquiera para escuchar su disparo acústico."
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            // Botón de Reproducir Todos
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: testAllRow.implicitWidth + 20
                radius: 8
                color: page.allSoundTimer.running
                    ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                    : (testAllMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                border.color: page.allSoundTimer.running ? page.sys.colOn : page.sys.colLine
                border.width: 1

                RowLayout {
                    id: testAllRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: page.allSoundTimer.running ? "󰏤" : "󰐊"
                        color: page.sys.colOn
                        font { family: page.sys.fontFam; pixelSize: 12 }
                    }
                    Text {
                        text: page.allSoundTimer.running
                            ? (page.sys.isEn ? "Stop" : "Detener")
                            : (page.sys.isEn ? "Play Entire Pack" : "Reproducir Todo")
                        color: page.allSoundTimer.running ? page.sys.colOn : page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                    }
                }

                MouseArea {
                    id: testAllMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.allSoundTimer.running) {
                            page.allSoundTimer.stop();
                            page.allSoundIdx = -1;
                        } else {
                            page.allSoundIdx = 0;
                            page.sys.playSound(page.allSoundsList[0].id, page.auditionPack);
                            page.allSoundTimer.start();
                        }
                    }
                }
            }
        }

        // Selector del pack a audicionar
        SetSelect {
            sys: page.sys
            label: page.sys.isEn ? "Pack Being Auditioned" : "Pack Seleccionado para Pruebas"
            options: [
                { id: "nothing",  text: "Nothing OS" },
                { id: "material", text: "Material You" },
                { id: "zen",      text: "Zen Calma" },
                { id: "cyber",    text: "Cyberpunk" },
                { id: "retro",    text: "Retro 8-Bit" },
                { id: "bubble",   text: "Aqua Bubble" },
                { id: "custom",   text: "Personalizado" }
            ]
            value: page.auditionPack
            onPicked: id => {
                page.auditionPack = id;
                page.sys.playSound("connect", id);
            }
        }

        // --- CATEGORÍA 1: SISTEMA & NAVEGACIÓN ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: page.sys.isEn ? "🔔 System & Navigation" : "🔔 Sistema & Navegación"
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: page.soundsSystem
                    delegate: soundButtonComponent
                }
            }
        }

        // --- CATEGORÍA 2: ENERGÍA & PERFILES ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Layout.topMargin: 4

            Text {
                text: page.sys.isEn ? "⚡ Battery & Performance Profiles" : "⚡ Energía & Perfiles de Rendimiento"
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: page.soundsPower
                    delegate: soundButtonComponent
                }
            }
        }

        // --- CATEGORÍA 3: SEGURIDAD & VOZ ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Layout.topMargin: 4

            Text {
                text: page.sys.isEn ? "🔒 Security & Voice Input" : "🔒 Seguridad & Asistente de Voz"
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: page.soundsSecurity
                    delegate: soundButtonComponent
                }
            }
        }

        // --- CATEGORÍA 4: CONECTIVIDAD & TÁCTIL ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Layout.topMargin: 4

            Text {
                text: page.sys.isEn ? "⌨️ Connectivity & Touch Haptics" : "⌨️ Conectividad & Respuesta Táctil"
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: page.soundsTouch
                    delegate: soundButtonComponent
                }
            }
        }
    }

    // Componente reutilizable para los botones de sonido
    Component {
        id: soundButtonComponent

        Rectangle {
            id: sndTile
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 8

            readonly property bool isAuditioning: page.allSoundTimer.running
                && page.allSoundIdx >= 0
                && page.allSoundIdx < page.allSoundsList.length
                && page.allSoundsList[page.allSoundIdx]
                && page.allSoundsList[page.allSoundIdx].id === modelData.id

            color: isAuditioning
                ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.30)
                : (tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
            border.color: isAuditioning
                ? page.sys.colOn
                : (tileMa.containsMouse ? page.sys.colOn : page.sys.colLine)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: modelData.icon
                    color: tileMa.containsMouse || sndTile.isAuditioning ? page.sys.colOn : page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: 13 }
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: tileMa.containsMouse || sndTile.isAuditioning ? page.sys.colFg : page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: tileMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.sys.playSound(modelData.id, page.auditionPack)
            }
        }
    }
}
