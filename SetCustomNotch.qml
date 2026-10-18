import QtQuick
import QtQuick.Layouts

// Notch & Isla Dinámica.
// Incluye vistas previas en vivo directamente en la ventana de ajustes
// sin necesidad de cerrarla, permitiendo probar y visualizar en tiempo real
// los modos del centro musical, carátula reactiva, ondas con color de portada,
// alertas de carga (80% / 100%) y alertas de batería baja (20% naranja / 15% rojo).
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    // Color efectivo de onda según configuración
    readonly property color effectiveWaveColor: {
        var m = page.sys.cfg.musicWaveColorMode !== undefined ? page.sys.cfg.musicWaveColorMode : 0;
        if (page.sys && page.sys.isMonochromeArt) return "#ffffff";
        if (m === 0) return page.sys.mediaArtColor;
        if (m === 1) return page.sys.colOn;
        return page.sys.colFg;
    }

    // Estado de vista previa: 0 = Música, 1 = Reposo (Notch Normal), 2 = Alerta de Batería/Carga
    property int previewState: 0
    property int previewBattMode: 80 // 80, 100, 20, 15, 0 (AC)
    property bool previewIsExpanded: false
    property bool previewLyricsOpen: false
    property string previewTrackKey: "preview_track_a"
    property bool previewWavePlaying: true

    property var soundTestModel: [
        { id: "settings_open",    label: "Abrir Super+I",         icon: "󰅀" },
        { id: "settings_close",   label: "Cerrar Super+I",        icon: "󰅖" },
        { id: "vol_tick",         label: "Tick Volumen",          icon: "󰕾" },
        { id: "kbd_light_0",      label: "Teclado 0%",            icon: "󰌌" },
        { id: "kbd_light_1",      label: "Teclado 50%",           icon: "󰌌" },
        { id: "kbd_light_2",      label: "Teclado 100%",          icon: "󰌌" },
        { id: "mode_powersave",   label: "Modo Ahorro",           icon: "󰌪" },
        { id: "mode_balanced",    label: "Modo Equilibrado",      icon: "󰾅" },
        { id: "mode_performance", label: "Modo Rendimiento",      icon: "󰓅" },
        { id: "charge",           label: "Carga AC",              icon: "󰂄" },
        { id: "batt_full",        label: "Carga Segura 80%",      icon: "󰂂" },
        { id: "batt_full",        label: "Carga Completa 100%",   icon: "󰁹" },
        { id: "lowbatt",          label: "Batería Baja",          icon: "󰂃" },
        { id: "island_pop",       label: "Isla Pop",              icon: "󰍜" },
        { id: "notification",     label: "Notificación",          icon: "󰂚" },
        { id: "screenshot",       label: "Captura",               icon: "󰄀" },
        { id: "connect",          label: "Bluetooth Conectar",    icon: "󰂯" },
        { id: "disconnect",       label: "Bluetooth Desconectar", icon: "󰂲" },
        { id: "voice_start",      label: "Voz Inicio",            icon: "󰍬" },
        { id: "voice_done",       label: "Voz Fin",               icon: "󰍭" },
        { id: "lock",             label: "Cámara Bloqueada",      icon: "󰄟" },
        { id: "unlock",           label: "Cámara Desbloqueada",   icon: "󰄀" },
        { id: "lock",             label: "Bloqueo Pantalla",      icon: "󰌾" },
        { id: "unlock",           label: "Desbloqueo Sesión",     icon: "󰌿" },
        { id: "tock",             label: "Tock Háptico",          icon: "󰌌" }
    ]

    property int allSoundIdx: -1
    property alias allSoundTimer: allSoundTimer
    Timer {
        id: allSoundTimer
        interval: 420
        repeat: true
        onTriggered: {
            page.allSoundIdx++;
            if (page.allSoundIdx < page.soundTestModel.length) {
                page.sys.playSound(page.soundTestModel[page.allSoundIdx].id);
            } else {
                page.allSoundIdx = -1;
                allSoundTimer.stop();
            }
        }
    }

    // ------------------------------------------------------------- modos del centro musical
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Vista Previa en Vivo y Modos del Notch") }

        // Switcher de estados de vista previa
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: page.sys.tr("ESTADO:")
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                Layout.alignment: Qt.AlignVCenter
            }

            Repeater {
                model: [
                    { id: 0, label: page.sys.tr("Música"), icon: "󰝚" },
                    { id: 1, label: page.sys.tr("Reposo"), icon: "󰒲" },
                    { id: 2, label: page.sys.tr("Alertas"), icon: "󱐋" }
                ]

                Rectangle {
                    id: stateBtn
                    required property var modelData
                    readonly property bool active: page.previewState === modelData.id
                    implicitWidth: stateRow.implicitWidth + 18
                    implicitHeight: 24
                    radius: 7
                    scale: stateMa.pressed ? 0.95 : (stateMa.containsMouse ? 1.03 : 1.0)
                    color: active ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                                  : (stateMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08) : "transparent")
                    border.color: active ? page.sys.colOn : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.15)
                    border.width: active ? 1.5 : 1

                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: stateBtn.modelData.icon
                            color: stateBtn.active ? page.sys.colOn : (stateMa.containsMouse ? page.sys.colFg : page.sys.colMuted)
                            font { family: page.sys.fontFam; pixelSize: 11 }
                        }

                        Text {
                            text: stateBtn.modelData.label
                            color: stateBtn.active ? page.sys.colFg : (stateMa.containsMouse ? page.sys.colFg : page.sys.colMuted)
                            font { family: page.sys.fontBody; pixelSize: 10; bold: stateBtn.active }
                        }
                    }

                    MouseArea {
                        id: stateMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                            page.previewState = stateBtn.modelData.id;
                        }
                    }
                }
            }
        }

        // Sub-selector de vista para Música (Notch Colapsado vs Isla Expandida)
        RowLayout {
            visible: page.previewState === 0
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: page.sys.tr("VISTA:")
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                Layout.alignment: Qt.AlignVCenter
            }

            Repeater {
                model: [
                    { id: false, label: page.sys.tr("Notch Colapsado"), icon: "󰍜" },
                    { id: true,  label: page.sys.tr("Isla Expandida (Super+M)"), icon: "󰓠" }
                ]

                Rectangle {
                    id: subMusicViewBtn
                    required property var modelData
                    readonly property bool active: page.previewIsExpanded === modelData.id
                    implicitWidth: subMusicTxt.implicitWidth + 24
                    implicitHeight: 20
                    radius: 5
                    color: active ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25)
                                  : (subMusicMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: active ? page.sys.colOn : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.15)
                    border.width: active ? 1.5 : 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: subMusicViewBtn.modelData.icon
                            color: subMusicViewBtn.active ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 10 }
                        }

                        Text {
                            id: subMusicTxt
                            text: subMusicViewBtn.modelData.label
                            color: subMusicViewBtn.active ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: 9; bold: subMusicViewBtn.active }
                        }
                    }

                    MouseArea {
                        id: subMusicMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                            page.previewIsExpanded = modelData.id;
                        }
                    }
                }
            }
        }

        // Sub-selector de nivel de batería cuando está en modo alerta
        RowLayout {
            visible: page.previewState === 2
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: page.sys.tr("NIVEL:")
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                Layout.alignment: Qt.AlignVCenter
            }

            Repeater {
                model: [
                    { id: 80, label: "80% (Saludable)", col: page.sys.colCharge },
                    { id: 100, label: "100% (Completa)", col: page.sys.colCharge },
                    { id: 20, label: "20% (Advertencia)", col: page.sys.colBattWarn },
                    { id: 15, label: "15% (Crítica)", col: page.sys.colBattCrit },
                    { id: 0, label: "⚡ Cargando (AC)", col: page.sys.colCharge }
                ]

                Rectangle {
                    id: subBattBtn
                    required property var modelData
                    readonly property bool active: page.previewBattMode === modelData.id
                    implicitWidth: subTxt.implicitWidth + 14
                    implicitHeight: 20
                    radius: 5
                    color: active ? Qt.rgba(modelData.col.r, modelData.col.g, modelData.col.b, 0.25)
                                  : (subMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: active ? modelData.col : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.15)
                    border.width: active ? 1.5 : 1

                    Text {
                        id: subTxt
                        anchors.centerIn: parent
                        text: modelData.label
                        color: subBattBtn.active ? page.sys.colFg : page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: 9; bold: subBattBtn.active }
                    }

                    MouseArea {
                        id: subMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.previewBattMode = modelData.id
                    }
                }
            }
        }

        // Sub-selector de prueba para alertas de cámara
        RowLayout {
            visible: page.previewState === 2
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: page.sys.tr("CÁMARA:")
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                implicitWidth: camTestTxt1.implicitWidth + 14
                implicitHeight: 20
                radius: 5
                color: camTestMa1.containsMouse ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b, 0.25) : Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b, 0.12)
                border.color: page.sys.colCrit
                border.width: 1

                Text {
                    id: camTestTxt1
                    anchors.centerIn: parent
                    text: "󰄂 " + page.sys.tr("Bloqueada")
                    color: page.sys.colCrit
                    font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                }

                MouseArea {
                    id: camTestMa1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.sys && page.sys.testCamera) page.sys.testCamera(true);
                    }
                }
            }

            Rectangle {
                implicitWidth: camTestTxt2.implicitWidth + 14
                implicitHeight: 20
                radius: 5
                color: camTestMa2.containsMouse ? Qt.rgba(page.sys.colCharge.r, page.sys.colCharge.g, page.sys.colCharge.b, 0.25) : Qt.rgba(page.sys.colCharge.r, page.sys.colCharge.g, page.sys.colCharge.b, 0.12)
                border.color: page.sys.colCharge
                border.width: 1

                Text {
                    id: camTestTxt2
                    anchors.centerIn: parent
                    text: "󰄀 " + page.sys.tr("Desbloqueada")
                    color: page.sys.colCharge
                    font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                }

                MouseArea {
                    id: camTestMa2
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.sys && page.sys.testCamera) page.sys.testCamera(false);
                    }
                }
            }
        }

        // ======================= RECUADRO DE VISTA PREVIA EN VIVO =======================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: {
                if (page.previewState === 0 && page.previewIsExpanded) {
                    var baseExp = 175;
                    var lyrH = page.previewLyricsOpen ? (page.sys.cfg.islandLyricsHeight || 240) : 0;
                    return baseExp + lyrH + ((page.sys.cfg.notchMode !== false) ? 0 : (page.sys.cfg.islandGap || 10)) + 46;
                }
                return Math.max(124, (page.sys.cfg.pillH || 38) + ((page.sys.cfg.notchMode !== false) ? 0 : (page.sys.cfg.islandGap || 10)) + 54);
            }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            radius: 14
            color: "#0f1015"
            border.color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12)
            border.width: 1
            clip: true

            // Resplandor ambiental de escritorio bajo el notch (Spotlight / Ambient Glow)
            Rectangle {
                id: previewAmbientGlow
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: liveNotchSim.width + ((page.sys.cfg.notchAmbientGlowRadius !== undefined ? page.sys.cfg.notchAmbientGlowRadius : 60) * 2)
                height: Math.max(40, (page.sys.cfg.notchAmbientGlowRadius !== undefined ? page.sys.cfg.notchAmbientGlowRadius : 60) * 1.4)
                radius: height / 2
                visible: page.sys.cfg.notchAmbientGlowEnabled !== false
                opacity: (page.sys.cfg.notchAmbientGlowEnabled !== false) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                readonly property real glowIntensityFactor: (page.sys.cfg.notchAmbientGlowIntensity !== undefined ? page.sys.cfg.notchAmbientGlowIntensity : 35) / 100.0

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: {
                            var base = (page.previewState === 0 && page.sys.mediaArtColor) ? page.sys.mediaArtColor : page.sys.colOn;
                            return Qt.rgba(base.r, base.g, base.b, Math.min(1.0, previewAmbientGlow.glowIntensityFactor * 0.65));
                        }
                    }
                    GradientStop {
                        position: 0.55
                        color: {
                            var base = (page.previewState === 0 && page.sys.mediaArtColor) ? page.sys.mediaArtColor : page.sys.colOn;
                            return Qt.rgba(base.r, base.g, base.b, Math.min(1.0, previewAmbientGlow.glowIntensityFactor * 0.18));
                        }
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            // Borde superior simulando marco de pantalla
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1.5
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.18)
            }

            // Etiqueta indicadora inferior con cápsula protectora
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                width: previewBadgeRow.implicitWidth + 18
                height: 22
                radius: 7
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)

                RowLayout {
                    id: previewBadgeRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: "#00e676"
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.35; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.0; to: 0.35; duration: 750; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        id: previewLabel
                        text: {
                            if (page.previewState === 0) {
                                if (page.previewIsExpanded) {
                                    return page.previewLyricsOpen
                                           ? page.sys.tr("VISTA PREVIA: ISLA EXPANDIDA CON LETRAS (SUPER+M)")
                                           : page.sys.tr("VISTA PREVIA: ISLA EXPANDIDA (SUPER+M)");
                                }
                                return page.sys.tr("VISTA PREVIA: MÚSICA (MODO %1)").arg(page.sys.musicCenterMode || 0);
                            }
                            if (page.previewState === 1) {
                                return page.sys.tr("VISTA PREVIA: REPOSO (NOTCH 1:1)");
                            }
                            return page.sys.tr("VISTA PREVIA: ALERTA BATERÍA (%1%)").arg(page.previewBattMode);
                        }
                        color: Qt.rgba(page.sys.colMuted.r, page.sys.colMuted.g, page.sys.colMuted.b, 0.90)
                        font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                    }
                }
            }

            // Insignia interactiva Nothing a la derecha
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                spacing: 5
                opacity: 0.65

                Text {
                    text: page.previewIsExpanded ? "󰍜" : "󰓠"
                    color: page.sys.colOn
                    font { family: page.sys.fontFam; pixelSize: 11 }
                }
                Text {
                    text: (page.previewState === 0 && page.previewIsExpanded)
                          ? page.sys.tr("CLICK PARA COLAPSAR")
                          : page.sys.tr("CLICK PARA PROBAR")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                }
            }

            // Notch / Cápsula en vivo 1:1
            Rectangle {
                id: liveNotchSim
                anchors.top: parent.top
                anchors.topMargin: (page.sys.cfg.notchMode !== false) ? 0 : (page.sys.cfg.islandGap || 10)
                anchors.horizontalCenter: parent.horizontalCenter
                height: {
                    if (page.previewState === 0 && page.previewIsExpanded) {
                        return prevExpandedCol ? (prevExpandedCol.implicitHeight + 20) : (page.previewLyricsOpen ? 420 : 180);
                    }
                    return page.sys.cfg.pillH || 38;
                }
                width: {
                    if (page.previewState === 1) {
                        var agExtraIdle = (page.sys.cfg.antigravityEnabled !== false && page.sys.cfg.antigravityMode !== "off") ? 80 : 0;
                        return Math.max(280 + agExtraIdle, (simNothingRow ? simNothingRow.implicitWidth + 36 + agExtraIdle : 310 + agExtraIdle));
                    }
                    if (page.previewState === 2) {
                        if (page.previewBattMode === 0) {
                            return Math.max(220, (simAcRow ? simAcRow.implicitWidth + 48 : 220));
                        } else if (page.previewBattMode >= 80) {
                            return Math.max(250, (simFullBattRow ? simFullBattRow.implicitWidth + 48 : 250));
                        } else {
                            return Math.max(240, (simLowBattRow ? simLowBattRow.implicitWidth + 48 : 240));
                        }
                    }
                    // previewState === 0 (Música)
                    if (page.previewIsExpanded) {
                        return Math.min(440, parent.width - 32);
                    }
                    var m = page.sys.musicCenterMode !== undefined ? page.sys.musicCenterMode : 3;
                    var baseW = 240;
                    if (m === 0) baseW = Math.max(170, (prevMusicClock ? prevMusicClock.implicitWidth + 104 : 170));
                    else if (m === 1) baseW = Math.max(180, (prevMusicBattery ? prevMusicBattery.implicitWidth + 104 : 180));
                    else if (m === 2) baseW = Math.max(240, (prevMusicBoth ? prevMusicBoth.implicitWidth + 106 : 240));
                    else if (m === 3) baseW = Math.max(330, (prevMusicFull ? prevMusicFull.implicitWidth + 108 : 360));
                    else if (m === 4) baseW = 148;
                    return baseW + liveNotchSim.agExtraWidth;
                }
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                property real agExtraWidth: (page.sys.cfg.antigravityEnabled !== false && page.sys.cfg.antigravityMode !== "off")
                    ? (18 + (page.sys.cfg.antigravityMargin !== undefined ? page.sys.cfg.antigravityMargin : 18) + (prevAgWave ? prevAgWave.implicitWidth : 38) + 12)
                    : 0

                color: page.sys.currentNotchBg || page.sys.colBg || "#000000"
                topLeftRadius: (page.sys.cfg.notchMode !== false) ? 0 : ((page.sys.cfg.islandRadius > 0) ? page.sys.cfg.islandRadius : ((page.previewState === 0 && page.previewIsExpanded) ? 26 : height / 2))
                topRightRadius: (page.sys.cfg.notchMode !== false) ? 0 : ((page.sys.cfg.islandRadius > 0) ? page.sys.cfg.islandRadius : ((page.previewState === 0 && page.previewIsExpanded) ? 26 : height / 2))
                bottomLeftRadius: (page.previewState === 0 && page.previewIsExpanded)
                    ? 26
                    : ((page.sys.cfg.islandRadius > 0 && page.sys.cfg.notchMode === false) ? page.sys.cfg.islandRadius : height / 2)
                bottomRightRadius: (page.previewState === 0 && page.previewIsExpanded)
                    ? 26
                    : ((page.sys.cfg.islandRadius > 0 && page.sys.cfg.notchMode === false) ? page.sys.cfg.islandRadius : height / 2)

                border.width: 0

                scale: 1.0
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                MouseArea {
                    id: simNotchMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        simBounceAnim.restart();
                        if (page.previewState === 0) {
                            page.previewIsExpanded = !page.previewIsExpanded;
                        }
                    }
                }

                SequentialAnimation {
                    id: simBounceAnim
                    NumberAnimation { target: liveNotchSim; property: "scale"; to: 1.03; duration: 80; easing.type: Easing.OutQuad }
                    NumberAnimation { target: liveNotchSim; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack }
                }

                // 1) Vista MÚSICA - NOTCH COLAPSADO
                Item {
                    anchors.fill: parent
                    visible: page.previewState === 0 && !page.previewIsExpanded

                    FlipArt {
                        id: prevMusicArtBox
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: page.sys.cfg.musicArtSize || 24
                        height: page.sys.cfg.musicArtSize || 24
                        artRadius: page.sys.cfg.musicCoverRadius || 7
                        trackKey: page.previewTrackKey || (page.sys.mediaArtTrack || "preview_track")
                        artSource: page.sys.effectiveMediaArt || ""
                        placeholderColor: page.sys.colMuted
                        fontFam: page.sys.fontFam
                        iconSize: 13
                        sourceSize: 256 // sourceSize: Qt.size(256, 256)
                        rippleUnderCover: page.sys.cfg.musicCoverRipple !== false
                        rippleShape: page.sys.cfg.musicCoverRippleShape !== undefined ? page.sys.cfg.musicCoverRippleShape : 0
                        rippleSens: (page.sys.cfg.musicCoverRippleSens !== undefined ? page.sys.cfg.musicCoverRippleSens : 100) / 100.0
                        rippleFreq: page.sys.cfg.musicCoverRippleFreq !== undefined ? page.sys.cfg.musicCoverRippleFreq : 0
                        ripplePersistence: (page.sys.cfg.musicCoverRipplePersistence !== undefined ? page.sys.cfg.musicCoverRipplePersistence : 100) / 100.0
                        bounceEnabled: page.sys.cfg.musicCoverBounce !== false
                        reactionIntensity: (page.sys.cfg.musicArtReactionIntensity !== undefined ? page.sys.cfg.musicArtReactionIntensity : 50) / 100.0
                        reactionActive: true
                        waveOverlay: page.sys.cfg.musicWavePos === 1 || page.sys.cfg.musicWavePos === 2
                        dominantColor: page.sys.mediaArtColor
                        waveColor: page.effectiveWaveColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (page.sys && page.sys.player) page.sys.player.togglePlaying();
                            }
                        }
                    }

                    AntigravityLogo {
                        id: prevAgLogo
                        visible: (page.sys.cfg.antigravityEnabled !== false) && (page.sys.cfg.antigravityMode !== "off")
                        active: visible
                        anchors.left: prevMusicArtBox.right
                        anchors.leftMargin: page.sys.cfg.antigravityMargin !== undefined ? page.sys.cfg.antigravityMargin : 18
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        colorMode: page.sys.cfg.antigravityMode || "anim"
                        accentColor: page.effectiveWaveColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (page.sys && page.sys.toggleAntigravityMode) page.sys.toggleAntigravityMode();
                            }
                        }
                    }

                    Item {
                        id: prevMusicCenterBox
                        anchors.centerIn: parent
                        height: parent.height
                        width: {
                            var m = page.sys.musicCenterMode !== undefined ? page.sys.musicCenterMode : 3;
                            if (m === 0) return (page.sys && page.sys.themeNothing) ? prevMusicClock.implicitWidth : prevMusicClockM3.implicitWidth;
                            if (m === 1) return prevMusicBattery.implicitWidth;
                            if (m === 2) return prevMusicBoth.implicitWidth;
                            if (m === 3) return prevMusicFull.implicitWidth;
                            return 0;
                        }

                        // Modo 0: Reloj Nothing / Material centrado
                        DotText {
                            id: prevMusicClock
                            anchors.centerIn: parent
                            value: page.sys.timeText || "17:50"
                            size: page.sys.dotHClock || 13
                            color: page.sys.colFg
                            visible: ((page.sys.musicCenterMode || 0) === 0) && (page.sys && page.sys.themeNothing)
                        }
                        Text {
                            id: prevMusicClockM3
                            anchors.centerIn: parent
                            text: page.sys.timeText || "17:50"
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize || 13; bold: true }
                            visible: ((page.sys.musicCenterMode || 0) === 0) && !(page.sys && page.sys.themeNothing)
                        }

                        // Modo 1: Batería Nothing / Material
                        RowLayout {
                            id: prevMusicBattery
                            anchors.centerIn: parent
                            spacing: page.sys.cfg.notchBatteryGap || 8
                            visible: page.sys.musicCenterMode === 1

                            ChargeBolt {
                                Layout.alignment: Qt.AlignVCenter
                                sys: page.sys
                                pixelSize: (page.sys.iconSize || 13) - 2
                                active: page.previewState === 0 && page.sys.musicCenterMode === 1
                            }
                            DotText {
                                visible: page.sys && page.sys.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                value: String(page.sys.batteryPct || 85)
                                size: page.sys.dotHClock || 13
                                color: page.sys.colFg
                            }
                            Text {
                                visible: !(page.sys && page.sys.themeNothing)
                                Layout.alignment: Qt.AlignVCenter
                                text: String(page.sys.batteryPct || 85) + "%"
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: (page.sys.fontSize || 13) - 1; bold: true }
                            }
                        }

                        // Modo 2: Reloj + Batería Nothing / Material simultáneos
                        RowLayout {
                            id: prevMusicBoth
                            anchors.centerIn: parent
                            spacing: page.sys.cfg.notchSectionGap || 10
                            visible: page.sys.musicCenterMode === 2

                            DotText {
                                visible: page.sys && page.sys.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                value: page.sys.timeText || "17:50"
                                size: page.sys.dotHClock || 13
                                color: page.sys.colFg
                            }
                            Text {
                                visible: !(page.sys && page.sys.themeNothing)
                                Layout.alignment: Qt.AlignVCenter
                                text: page.sys.timeText || "17:50"
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize || 13; bold: true }
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: page.sys.cfg.notchBatteryGap || 8
                                ChargeBolt {
                                    Layout.alignment: Qt.AlignVCenter
                                    sys: page.sys
                                    pixelSize: (page.sys.iconSize || 13) - 2
                                    active: page.previewState === 0 && page.sys.musicCenterMode === 2
                                }
                                DotText {
                                    visible: page.sys && page.sys.themeNothing
                                    value: String(page.sys.batteryPct || 85)
                                    size: page.sys.dotHClock || 13
                                    color: page.sys.colFg
                                }
                                Text {
                                    visible: !(page.sys && page.sys.themeNothing)
                                    text: String(page.sys.batteryPct || 85) + "%"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: (page.sys.fontSize || 13) - 1; bold: true }
                                }
                            }
                        }

                        // Modo 3: Notch completo normal (3 zonas proporcionales)
                        RowLayout {
                            id: prevMusicFull
                            anchors.centerIn: parent
                            spacing: 16
                            visible: page.sys.musicCenterMode === 3

                            // 1. Grupo Izquierdo: Workspaces + Clima Nothing
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 14

                                // Workspaces (Píldora activa + puntos)
                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    Rectangle {
                                        width: (page.sys && page.sys.themeNothing) ? 14 : 18
                                        height: 5
                                        radius: 2.5
                                        color: (page.sys && page.sys.themeMaterial) ? page.sys.colOn : page.sys.colFg
                                    }
                                    Rectangle { width: 4; height: 4; radius: 2; color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.35) }
                                    Rectangle { width: 4; height: 4; radius: 2; color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.35) }
                                }

                                // Clima
                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4

                                    DotIcon {
                                        visible: page.sys && page.sys.themeNothing
                                        Layout.alignment: Qt.AlignVCenter
                                        code: (page.sys && page.sys.weatherIcon && page.sys.weatherIcon.length > 0) ? page.sys.weatherIcon : "02d"
                                        size: page.sys.dotHClock || 13
                                        color: page.sys.colFg
                                    }
                                    Text {
                                        visible: !(page.sys && page.sys.themeNothing)
                                        Layout.alignment: Qt.AlignVCenter
                                        text: (page.sys && page.sys.weatherGlyph) ? page.sys.weatherGlyph : "󰖐"
                                        color: page.sys.colFg
                                        font { family: page.sys.fontFam; pixelSize: (page.sys.iconSize || 13) - 2 }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: ((page.sys && page.sys.weatherTemp) ? page.sys.weatherTemp : "22") + "°"
                                        color: page.sys.colFg
                                        font {
                                            family: page.sys.fontFam
                                            pixelSize: (page.sys.fontSize || 12) - 1
                                            bold: !(page.sys && page.sys.themeNothing)
                                        }
                                    }
                                }
                            }

                            // 2. Centro: Reloj Nothing / Material
                            DotText {
                                visible: page.sys && page.sys.themeNothing
                                Layout.alignment: Qt.AlignVCenter
                                value: page.sys.timeText || "17:50"
                                size: page.sys.dotHClock || 13
                                color: page.sys.colFg
                            }
                            Text {
                                visible: !(page.sys && page.sys.themeNothing)
                                Layout.alignment: Qt.AlignVCenter
                                text: page.sys.timeText || "17:50"
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize || 13; bold: true }
                            }

                            // 3. Grupo Derecho: Wi-Fi + Volumen + Batería
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 12

                                // Wi-Fi
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: (page.sys && page.sys.wifiOn !== false)
                                          ? ((page.sys && page.sys.wifiQuality > 66) ? "󰤨" : (page.sys && page.sys.wifiQuality > 33) ? "󰤥" : "󰤟")
                                          : "󰤨"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: (page.sys.iconSize || 13) - 1 }
                                }

                                // Volumen
                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: (!page.sys || !page.sys.sinkAudio) ? String.fromCodePoint(0xF0580)
                                            : page.sys.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                                            : page.sys.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                                            : page.sys.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                            : String.fromCodePoint(0xF057E)
                                        color: (page.sys && page.sys.sinkAudio && page.sys.sinkAudio.muted) ? page.sys.colMuted : page.sys.colFg
                                        font { family: page.sys.fontFam; pixelSize: (page.sys.iconSize || 13) - 1 }
                                    }
                                    DotText {
                                        visible: page.sys && page.sys.themeNothing
                                        Layout.alignment: Qt.AlignVCenter
                                        value: (page.sys && page.sys.sinkAudio)
                                               ? String(Math.round(page.sys.sinkAudio.volume * 100)) : "75"
                                        size: page.sys.dotHSmall || 9
                                        color: (page.sys && page.sys.sinkAudio && page.sys.sinkAudio.muted) ? page.sys.colMuted : page.sys.colFg
                                    }
                                    Text {
                                        visible: !(page.sys && page.sys.themeNothing)
                                        Layout.alignment: Qt.AlignVCenter
                                        text: (page.sys && page.sys.sinkAudio)
                                               ? String(Math.round(page.sys.sinkAudio.volume * 100)) : "75"
                                        color: (page.sys && page.sys.sinkAudio && page.sys.sinkAudio.muted) ? page.sys.colMuted : page.sys.colFg
                                        font { family: page.sys.fontFam; pixelSize: (page.sys.fontSize || 12) - 2; bold: true }
                                    }
                                }

                                // Batería
                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: page.sys.cfg.notchBatteryGap || 6
                                    ChargeBolt {
                                        Layout.alignment: Qt.AlignVCenter
                                        sys: page.sys
                                        pixelSize: (page.sys.iconSize || 13) - 2
                                        active: page.previewState === 0 && page.sys.musicCenterMode === 3
                                    }
                                    DotText {
                                        visible: page.sys && page.sys.themeNothing
                                        value: String(page.sys.batteryPct || 85)
                                        size: page.sys.dotHClock || 13
                                        color: page.sys.colFg
                                    }
                                    Text {
                                        visible: !(page.sys && page.sys.themeNothing)
                                        Layout.alignment: Qt.AlignVCenter
                                        text: String(page.sys.batteryPct || 85)
                                        color: page.sys.colFg
                                        font { family: page.sys.fontFam; pixelSize: (page.sys.fontSize || 12) - 2; bold: true }
                                    }
                                }
                            }
                        }
                    }

                    // Indicador de ondas Antigravity
                    AntigravityWave {
                        id: prevAgWave
                        visible: (page.sys.cfg.antigravityEnabled !== false) && (page.sys.cfg.antigravityMode !== "off")
                        active: visible
                        anchors.right: prevWaveBars.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        waveColor: page.effectiveWaveColor
                        subagentCount: (page.sys && page.sys.antigravitySubagents) ? page.sys.antigravitySubagents : 1
                    }

                    // Derecha: Onda de audio animada
                    WaveBars {
                        id: prevWaveBars
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (page.sys.cfg.musicWaveEnabled !== false) && (page.sys.cfg.musicWavePos === 0 || page.sys.cfg.musicWavePos === 2 || page.sys.cfg.musicWavePos === undefined)
                        width: 24
                        height: 16
                        barCount: 5
                        gap: 2.5
                        barColor: page.effectiveWaveColor
                        sensMultiplier: (page.sys.cfg.musicRightWaveSens !== undefined ? page.sys.cfg.musicRightWaveSens : 100) / 100.0
                        freqMode: page.sys.cfg.musicRightWaveFreq !== undefined ? page.sys.cfg.musicRightWaveFreq : 0
                        persistenceMultiplier: (page.sys.cfg.musicRightWavePersistence !== undefined ? page.sys.cfg.musicRightWavePersistence : 100) / 100.0
                        active: page.previewWavePlaying
                        morphPause: true
                    }
                }

                // 1b) Vista MÚSICA - ISLA DINÁMICA EXPANDIDA (Super+M)
                Item {
                    id: prevExpandedItem
                    anchors.fill: parent
                    visible: page.previewState === 0 && page.previewIsExpanded
                    clip: true

                    ColumnLayout {
                        id: prevExpandedCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: 10
                        spacing: 12

                        // Fila 1: Carátula (56x56) + Título y Artista + WaveBars (8 barras)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56

                                FlipArt {
                                    anchors.fill: parent
                                    artRadius: 13
                                    trackKey: page.previewTrackKey || (page.sys.mediaArtTrack || "preview_track")
                                    artSource: page.sys.effectiveMediaArt || page.sys.mediaArt || ""
                                    placeholderColor: page.sys.colMuted
                                    fontFam: page.sys.fontFam
                                    iconSize: 22
                                    sourceSize: 256
                                    dominantColor: page.sys.mediaArtColor
                                    waveColor: page.effectiveWaveColor

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (page.sys && page.sys.player) page.sys.player.togglePlaying();
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: (page.sys.player && page.sys.player.trackTitle)
                                          ? String(page.sys.player.trackTitle)
                                          : "Starman"
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    font { family: page.sys.fontFam; pixelSize: 14; bold: true }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (page.sys.player && (page.sys.player.trackArtist || page.sys.player.trackAlbum))
                                          ? String(page.sys.player.trackArtist || page.sys.player.trackAlbum)
                                          : "David Bowie — The Rise and Fall of Ziggy Stardust"
                                    color: Qt.rgba(1, 1, 1, 0.65)
                                    elide: Text.ElideRight
                                    font { family: page.sys.fontFam; pixelSize: 11 }
                                }

                                RowLayout {
                                    spacing: 5
                                    Rectangle {
                                        Layout.preferredWidth: 6
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: page.sys.mediaArtColor
                                    }
                                    Text {
                                        text: (page.sys.player && page.sys.player.identity) ? String(page.sys.player.identity) : "Spotify"
                                        color: Qt.rgba(1, 1, 1, 0.45)
                                        font { family: page.sys.fontFam; pixelSize: 9; bold: true }
                                    }
                                }
                            }

                            WaveBars {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 20
                                Layout.alignment: Qt.AlignVCenter
                                barCount: 8
                                gap: 2.5
                                barColor: page.effectiveWaveColor
                                active: (page.sys.player && page.sys.player.isPlaying !== undefined) ? page.sys.player.isPlaying : true
                            }
                        }

                        // Fila 2: Controles de reproducción + Botón de Letras (󰎆)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            Item { Layout.fillWidth: true }

                            // Anterior
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 21
                                color: prevExpMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: prevExpMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)
                                    font { family: page.sys.fontFam; pixelSize: 20 }
                                }

                                MouseArea {
                                    id: prevExpMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                                        if (page.sys && page.sys.player) page.sys.player.previous();
                                    }
                                }
                            }

                            // Play / Pause
                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                radius: 25
                                color: playExpMa.containsMouse ? Qt.lighter(page.sys.colOn, 1.15) : page.sys.colOn

                                Text {
                                    anchors.centerIn: parent
                                    text: (page.sys.player && page.sys.player.isPlaying) ? "󰏤" : "󰐊"
                                    color: "#ffffff"
                                    font { family: page.sys.fontFam; pixelSize: 26; bold: true }
                                }

                                MouseArea {
                                    id: playExpMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                                        if (page.sys && page.sys.player) page.sys.player.togglePlaying();
                                    }
                                }
                            }

                            // Siguiente
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 21
                                color: nextExpMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: nextExpMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)
                                    font { family: page.sys.fontFam; pixelSize: 20 }
                                }

                                MouseArea {
                                    id: nextExpMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                                        if (page.sys && page.sys.player) page.sys.player.next();
                                    }
                                }
                            }

                            // Botón de Letras Interactivo (󰎆)
                            Rectangle {
                                id: previewLyricsBtn
                                readonly property bool active: page.previewLyricsOpen
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 19
                                color: active
                                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.45)
                                       : (lyrExpMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08))
                                border.color: active
                                              ? page.sys.colOn
                                              : (lyrExpMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                                border.width: 1
                                scale: lyrExpMa.pressed ? 0.94 : (lyrExpMa.containsMouse ? 1.05 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Behavior on border.color { ColorAnimation { duration: 160 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    color: previewLyricsBtn.active ? "#ffffff" : (lyrExpMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.82))
                                    font { family: page.sys.fontFam; pixelSize: 18 }
                                }

                                MouseArea {
                                    id: lyrExpMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                                        page.previewLyricsOpen = !page.previewLyricsOpen;
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Fila 3: Barra de progreso de pista
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "1:24"
                                color: Qt.rgba(1, 1, 1, 0.65)
                                font { family: page.sys.fontFam; pixelSize: 10 }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.15)

                                Rectangle {
                                    width: parent.width * 0.38
                                    height: parent.height
                                    radius: 2
                                    color: page.sys.mediaArtColor || page.sys.colOn
                                }
                            }

                            Text {
                                text: "-2:15"
                                color: Qt.rgba(1, 1, 1, 0.65)
                                font { family: page.sys.fontFam; pixelSize: 10 }
                            }
                        }

                        // Fila 4: Visor de letras SpicyLyricsView
                        SpicyLyricsView {
                            id: previewSpicyLyrics
                            Layout.fillWidth: true
                            Layout.preferredHeight: page.previewLyricsOpen ? (page.sys.cfg.islandLyricsHeight || 240) : 0
                            visible: page.previewLyricsOpen || Layout.preferredHeight > 0.5
                            opacity: page.previewLyricsOpen ? 1.0 : 0.0
                            active: page.previewLyricsOpen
                            sys: page.sys
                            player: page.sys.player
                            clip: true

                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: page.previewLyricsOpen ? 340 : 280
                                    easing.type: page.previewLyricsOpen ? Easing.OutBack : Easing.OutCubic
                                    easing.overshoot: 1.05
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 240
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                // 2) Vista REPOSO (previewState === 1)
                Item {
                    anchors.fill: parent
                    visible: page.previewState === 1

                    AntigravityLogo {
                        id: prevAgLogoIdle
                        visible: (page.sys.cfg.antigravityEnabled !== false) && (page.sys.cfg.antigravityMode !== "off")
                        active: visible
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        colorMode: page.sys.cfg.antigravityMode || "anim"
                        accentColor: page.sys.colOn || "#00e0ff"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (page.sys && page.sys.toggleAntigravityMode) page.sys.toggleAntigravityMode();
                            }
                        }
                    }

                    RowLayout {
                        id: simNothingRow
                        anchors.centerIn: parent
                        spacing: 18

                        // 1. Izquierda: Workspaces + Clima
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 14

                            // Workspaces
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Rectangle {
                                    width: (page.sys && page.sys.themeNothing) ? 14 : 18
                                    height: 5
                                    radius: 2.5
                                    color: (page.sys && page.sys.themeMaterial) ? page.sys.colOn : page.sys.colFg
                                }
                                Rectangle { width: 4; height: 4; radius: 2; color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.35) }
                                Rectangle { width: 4; height: 4; radius: 2; color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.35) }
                            }

                            // Clima (Weather)
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4

                                DotIcon {
                                    visible: page.sys && page.sys.themeNothing
                                    Layout.alignment: Qt.AlignVCenter
                                    code: (page.sys && page.sys.weatherIcon && page.sys.weatherIcon.length > 0) ? page.sys.weatherIcon : "02d"
                                    size: page.sys.dotHClock || 13
                                    color: page.sys.colFg
                                }
                                Text {
                                    visible: !(page.sys && page.sys.themeNothing)
                                    Layout.alignment: Qt.AlignVCenter
                                    text: (page.sys && page.sys.weatherGlyph) ? page.sys.weatherGlyph : "󰖐"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: (page.sys.iconSize || 13) - 2 }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: ((page.sys && page.sys.weatherTemp) ? page.sys.weatherTemp : "22") + "°"
                                    color: page.sys.colFg
                                    font {
                                        family: page.sys.fontFam
                                        pixelSize: (page.sys.fontSize || 12) - 1
                                        bold: !(page.sys && page.sys.themeNothing)
                                    }
                                }
                            }
                        }

                        // 2. Centro: Reloj Nothing / Material con notchClockPad
                        DotText {
                            visible: page.sys && page.sys.themeNothing
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: page.sys.cfg.notchClockPad || 0
                            value: page.sys.timeText || "17:50"
                            size: page.sys.dotHClock || 13
                            color: page.sys.colFg
                        }
                        Text {
                            visible: !(page.sys && page.sys.themeNothing)
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: (page.sys.cfg.notchClockPad || 0) + 2
                            text: page.sys.timeText || "17:50"
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize || 13; bold: true }
                        }

                        // 3. Derecha: Wi-Fi, Volumen, Batería
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 12

                            // Wi-Fi
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: (page.sys && page.sys.wifiOn !== false)
                                      ? ((page.sys && page.sys.wifiQuality > 66) ? "󰤨" : (page.sys && page.sys.wifiQuality > 33) ? "󰤥" : "󰤟")
                                      : "󰤨"
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: (page.sys.iconSize || 13) - 1 }
                            }

                            // Volumen
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: (!page.sys || !page.sys.sinkAudio) ? String.fromCodePoint(0xF0580)
                                        : page.sys.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                                        : page.sys.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                                        : page.sys.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                        : String.fromCodePoint(0xF057E)
                                    color: (page.sys && page.sys.sinkAudio && page.sys.sinkAudio.muted) ? page.sys.colMuted : page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: (page.sys.iconSize || 13) - 1 }
                                }
                                DotText {
                                    visible: page.sys && page.sys.themeNothing
                                    Layout.alignment: Qt.AlignVCenter
                                    value: (page.sys && page.sys.sinkAudio)
                                           ? String(Math.round(page.sys.sinkAudio.volume * 100)) : "75"
                                    size: page.sys.dotHSmall || 9
                                    color: (page.sys && page.sys.sinkAudio && page.sys.sinkAudio.muted) ? page.sys.colMuted : page.sys.colFg
                                }
                                Text {
                                    visible: !(page.sys && page.sys.themeNothing)
                                    Layout.alignment: Qt.AlignVCenter
                                    text: (page.sys && page.sys.sinkAudio)
                                           ? String(Math.round(page.sys.sinkAudio.volume * 100)) : "75"
                                    color: (page.sys && page.sys.sinkAudio && page.sys.sinkAudio.muted) ? page.sys.colMuted : page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: (page.sys.fontSize || 12) - 2; bold: true }
                                }
                            }

                            // Batería
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: page.sys.cfg.notchBatteryGap || 6
                                ChargeBolt {
                                    Layout.alignment: Qt.AlignVCenter
                                    sys: page.sys
                                    pixelSize: (page.sys.iconSize || 13) - 2
                                    active: page.previewState === 1
                                }
                                DotText {
                                    visible: page.sys && page.sys.themeNothing
                                    Layout.alignment: Qt.AlignVCenter
                                    value: String(page.sys.batteryPct || 85)
                                    size: page.sys.dotHClock || 13
                                    color: page.sys.colFg
                                }
                                Text {
                                    visible: !(page.sys && page.sys.themeNothing)
                                    Layout.alignment: Qt.AlignVCenter
                                    text: String(page.sys.batteryPct || 85)
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: (page.sys.fontSize || 12) - 2; bold: true }
                                }
                            }
                        }
                    }

                    AntigravityWave {
                        id: prevAgWaveIdle
                        visible: (page.sys.cfg.antigravityEnabled !== false) && (page.sys.cfg.antigravityMode !== "off")
                        active: visible
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        waveColor: page.sys.colOn || "#00e0ff"
                        subagentCount: (page.sys && page.sys.antigravitySubagents) ? page.sys.antigravitySubagents : 1
                    }
                }

                // 3) Vista ALERTA BATERÍA / CARGA 1:1 REAL (previewState === 2)
                Item {
                    anchors.fill: parent
                    visible: page.previewState === 2

                    // 3a. Modo Carga AC (previewBattMode === 0)
                    RowLayout {
                        id: simAcRow
                        anchors.centerIn: parent
                        spacing: page.sys.cfg.notchSectionGap || 8
                        visible: page.previewBattMode === 0

                        ChargeBolt {
                            Layout.alignment: Qt.AlignVCenter
                            icon: String.fromCodePoint(0xF0241)
                            pixelSize: (page.sys.iconSize || 13) + 3
                            chargeColor: page.sys.colCharge || "#00e676"
                            charging: true
                            active: page.previewState === 2 && page.previewBattMode === 0
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: (page.sys.cfg.chargeText && page.sys.cfg.chargeText.length > 0) ? page.sys.cfg.chargeText : (page.sys.tr ? page.sys.tr("Cargando") : "Cargando")
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize; bold: true }
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: (page.sys.batteryPct || 85) + "%"
                            color: page.sys.colOk
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize; bold: true }
                        }
                    }

                    // 3b. Modo Batería Baja (previewBattMode <= 20)
                    RowLayout {
                        id: simLowBattRow
                        anchors.centerIn: parent
                        spacing: 24
                        visible: page.previewBattMode > 0 && page.previewBattMode <= 20

                        readonly property bool isCrit: page.previewBattMode <= (page.sys.cfg.lowBatteryCritThreshold || 15)
                        readonly property color lowColor: isCrit ? page.sys.colBattCrit : page.sys.colBattWarn
                        readonly property color lowBadgeBg: isCrit
                            ? Qt.rgba(page.sys.colBattCrit.r, page.sys.colBattCrit.g, page.sys.colBattCrit.b, 0.24)
                            : Qt.rgba(page.sys.colBattWarn.r, page.sys.colBattWarn.g, page.sys.colBattWarn.b, 0.24)

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: page.previewBattMode + "% " + (simLowBattRow.isCrit
                                ? ((page.sys.cfg.battCritText && page.sys.cfg.battCritText.length > 0) ? page.sys.cfg.battCritText : (page.sys.tr ? page.sys.tr("Batería crítica") : "Batería crítica"))
                                : ((page.sys.cfg.battWarnText && page.sys.cfg.battWarnText.length > 0) ? page.sys.cfg.battWarnText : (page.sys.tr ? page.sys.tr("Batería baja") : "Batería baja")))
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize; bold: true }
                        }

                        Rectangle {
                            id: simLowBadge
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 64
                            implicitHeight: 28
                            radius: 14
                            color: simLowBattRow.lowBadgeBg

                            Item {
                                anchors.centerIn: parent
                                width: 33
                                height: 16

                                Rectangle {
                                    id: simLowBattShell
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 29
                                    height: 15
                                    radius: 4
                                    color: "transparent"
                                    border.color: simLowBattRow.lowColor
                                    border.width: 1.5
                                    clip: true

                                    Rectangle {
                                        id: simLowBattFill
                                        anchors.left: parent.left
                                        anchors.leftMargin: 1.5
                                        anchors.top: parent.top
                                        anchors.topMargin: 1.5
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1.5
                                        width: Math.max(4, Math.round((simLowBattShell.width - 3) * Math.max(0.08, page.previewBattMode / 100)))
                                        radius: 2.5
                                        color: simLowBattRow.lowColor
                                    }
                                }

                                Rectangle {
                                    anchors.left: simLowBattShell.right
                                    anchors.leftMargin: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: 6
                                    radius: 1
                                    color: simLowBattRow.lowColor
                                }

                                Rectangle {
                                    id: simLowBattRipple
                                    anchors.verticalCenter: simLowBattShell.verticalCenter
                                    anchors.horizontalCenter: simLowBattShell.left
                                    anchors.horizontalCenterOffset: Math.min(simLowBattShell.width / 2, Math.max(6, simLowBattFill.width / 2 + 2))
                                    width: 18
                                    height: 22
                                    radius: 9
                                    color: "transparent"
                                    border.color: simLowBattRow.lowColor
                                    border.width: 2.0
                                    scale: 0.6
                                    opacity: 0.0

                                    SequentialAnimation on scale {
                                        running: page.previewState === 2 && page.previewBattMode > 0 && page.previewBattMode <= 20
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.6; to: 1.45; duration: 800; easing.type: Easing.OutQuad }
                                        PauseAnimation { duration: 200 }
                                    }
                                    SequentialAnimation on opacity {
                                        running: page.previewState === 2 && page.previewBattMode > 0 && page.previewBattMode <= 20
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.95; to: 0.0; duration: 800; easing.type: Easing.OutQuad }
                                        PauseAnimation { duration: 200 }
                                    }
                                }
                            }
                        }
                    }

                    // 3c. Modo Batería Completa / 80% (previewBattMode >= 80)
                    RowLayout {
                        id: simFullBattRow
                        anchors.centerIn: parent
                        spacing: 20
                        visible: page.previewBattMode >= 80

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            Text {
                                text: page.previewBattMode + "%"
                                color: page.sys.colCharge
                                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize + 1; bold: true }
                            }

                            Text {
                                text: page.previewBattMode >= 100
                                    ? ((page.sys.cfg.battFullText && page.sys.cfg.battFullText.length > 0) ? page.sys.cfg.battFullText : (page.sys.tr ? page.sys.tr("Carga completa") : "Carga completa"))
                                    : ((page.sys.cfg.batt80Text && page.sys.cfg.batt80Text.length > 0) ? page.sys.cfg.batt80Text : (page.sys.tr ? page.sys.tr("Carga al 80%") : "Carga al 80%"))
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 1; bold: true }
                            }
                        }

                        Rectangle {
                            id: simFullBattBadge
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 68
                            implicitHeight: 28
                            radius: 14
                            color: Qt.rgba(page.sys.colCharge.r, page.sys.colCharge.g, page.sys.colCharge.b, 0.22)
                            border.color: Qt.rgba(page.sys.colCharge.r, page.sys.colCharge.g, page.sys.colCharge.b, 0.45)
                            border.width: 1

                            Item {
                                anchors.centerIn: parent
                                width: 35
                                height: 16

                                Rectangle {
                                    id: simFullBattShell
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 29
                                    height: 15
                                    radius: 4
                                    color: "transparent"
                                    border.color: page.sys.colCharge
                                    border.width: 1.5
                                    clip: true

                                    Rectangle {
                                        id: simFullBattFill
                                        anchors.left: parent.left
                                        anchors.leftMargin: 1.5
                                        anchors.top: parent.top
                                        anchors.topMargin: 1.5
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1.5
                                        radius: 2.5
                                        color: page.sys.colCharge
                                        readonly property real maxW: simFullBattShell.width - 3
                                        width: Math.round(maxW * Math.min(1.0, page.previewBattMode / 100))

                                        Rectangle {
                                            id: simFillShimmer
                                            width: 8
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            radius: 1
                                            color: Qt.rgba(1, 1, 1, 0.50)
                                            x: -8

                                            SequentialAnimation on x {
                                                running: page.previewState === 2 && page.previewBattMode >= 80
                                                loops: Animation.Infinite
                                                NumberAnimation { from: -8; to: simFullBattShell.width; duration: 1400; easing.type: Easing.InOutQuad }
                                                PauseAnimation { duration: 1000 }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: simFullBattShell.right
                                    anchors.leftMargin: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: 6
                                    radius: 1
                                    color: page.sys.colCharge
                                }

                                Rectangle {
                                    id: simFullBattRipple
                                    anchors.centerIn: simFullBattShell
                                    width: simFullBattShell.width + 6
                                    height: simFullBattShell.height + 6
                                    radius: 7
                                    color: "transparent"
                                    border.color: page.sys.colCharge
                                    border.width: 1.5
                                    scale: 1.0
                                    opacity: 0.0

                                    SequentialAnimation on scale {
                                        running: page.previewState === 2 && page.previewBattMode >= 80
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 1.35; duration: 900; easing.type: Easing.OutQuad }
                                        PauseAnimation { duration: 1200 }
                                    }
                                    SequentialAnimation on opacity {
                                        running: page.previewState === 2 && page.previewBattMode >= 80
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.8; to: 0.0; duration: 900; easing.type: Easing.OutQuad }
                                        PauseAnimation { duration: 1200 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Uñas fluidas del notch a izquierda y derecha (hermanas de liveNotchSim)
            NotchCorner {
                id: notchCornerL
                anchors.right: liveNotchSim.left
                anchors.top: liveNotchSim.top
                r: page.sys.cfg.notchFlare || 12
                fill: liveNotchSim.color
                side: "left"
                visible: (page.sys.cfg.notchFluidCorners !== false) && (page.sys.cfg.notchMode !== false) && (page.sys.cfg.notchFlare > 0)
            }

            NotchCorner {
                id: notchCornerR
                anchors.left: liveNotchSim.right
                anchors.top: liveNotchSim.top
                r: page.sys.cfg.notchFlare || 12
                fill: liveNotchSim.color
                side: "right"
                visible: (page.sys.cfg.notchFluidCorners !== false) && (page.sys.cfg.notchMode !== false) && (page.sys.cfg.notchFlare > 0)
            }
        }

        // ======================= CONTROLES DEL ESTADO ACTIVO =======================
        // Para Música (previewState === 0)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: page.previewState === 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: page.sys.tr("Modo activo del centro musical:")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }

                SetButton {
                    sys: page.sys
                    text: page.sys.tr("Rotar modo (Super+Shift+H)")
                    onClicked: page.sys.rotateMusicCenter()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Repeater {
                        model: [
                            { id: 0, label: "Reloj", icon: "󰥔" },
                            { id: 1, label: "Batería", icon: "󰁹" },
                            { id: 2, label: "Ambos", icon: "󰥔 󰁹" },
                            { id: 3, label: "Completo", icon: "󰍹" },
                            { id: 4, label: "Mínimo", icon: "󰝚" }
                        ]

                        Rectangle {
                            id: modeSeg
                            required property var modelData
                            readonly property bool active: (page.sys.musicCenterMode !== undefined ? page.sys.musicCenterMode : 3) === modelData.id
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 7
                            scale: modeMa.pressed ? 0.96 : (modeMa.containsMouse ? 1.02 : 1.0)
                            color: active ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.30)
                                          : (modeMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08) : "transparent")
                            border.width: 1
                            border.color: active ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.50)
                                                 : (modeMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12) : "transparent")

                            Behavior on color { ColorAnimation { duration: page.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: page.sys.animFade } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: modeSeg.modelData.icon
                                    color: modeSeg.active ? page.sys.colOn : (modeMa.containsMouse ? page.sys.colFg : page.sys.colMuted)
                                    font { family: page.sys.fontFam; pixelSize: 11 }
                                }

                                Text {
                                    text: modeSeg.modelData.label
                                    color: modeSeg.active ? page.sys.colFg : (modeMa.containsMouse ? page.sys.colFg : page.sys.colMuted)
                                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: modeSeg.active }
                                }
                            }

                            MouseArea {
                                id: modeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                                    page.sys.setMusicCenterMode(modeSeg.modelData.id);
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    var m = page.sys.musicCenterMode || 0;
                    if (m === 0) return page.sys.tr("Modo 0: Reloj digital estilizado Nothing centrado.");
                    if (m === 1) return page.sys.tr("Modo 1: Nivel e icono de batería Nothing.");
                    if (m === 2) return page.sys.tr("Modo 2: Reloj y batería mostrados simultáneamente.");
                    if (m === 3) return page.sys.tr("Modo 3: Notch completo (espacios de trabajo, reloj y batería).");
                    return page.sys.tr("Modo 4: Dinámico minimalista (solo carátula y onda de audio, sin centro).");
                }
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }

        // Para Reposo (previewState === 1)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: page.previewState === 1

            Text {
                Layout.fillWidth: true
                text: page.sys.tr("Modo Reposo del Notch:")
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: page.sys.tr("En reposo el notch muestra escritorios virtuales a la izquierda, la hora en formato Nothing en el centro y el porcentaje de batería a la derecha.")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }

        // Para Alertas (previewState === 2)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: page.previewState === 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: page.sys.tr("Modos de Alerta Dynamic Island (1:1 Réplica Real):")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }

                SetButton {
                    sys: page.sys
                    text: page.sys.tr("Disparar alerta en pantalla")
                    onClicked: {
                        if (page.previewBattMode === 0) page.sys.showAcToast();
                        else if (page.previewBattMode >= 80) page.sys.showFullBattToast(page.previewBattMode);
                        else page.sys.showLowBattToast(page.previewBattMode);
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (page.previewBattMode === 0) return page.sys.tr("Alerta de conexión AC: Rayo pulsante con ondas concéntricas y porcentaje.");
                    if (page.previewBattMode >= 100) return page.sys.tr("Alerta 100%: Aviso verde con brillo deslizante en el nivel de batería al completar la carga.");
                    if (page.previewBattMode === 80) return page.sys.tr("Alerta 80%: Aviso verde de carga óptima recomendada para cuidar la salud de la batería.");
                    if (page.previewBattMode <= 15) return page.sys.tr("Alerta 15%: Aviso rojo crítico con onda de choque pulsante continua.");
                    return page.sys.tr("Alerta 20%: Advertencia ámbar/naranja de batería baja con onda pulsante.");
                }
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }
    }

    // ============================================================= DIMENSIONES, FORMA Y MODO DEL NOTCH
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Dimensiones, Forma y Modo del Notch") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Ajusta la geometría, el modo de adherencia a la pantalla y el comportamiento general del notch o cápsula flotante en tiempo real:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Modo Notch adherido al borde")
            sub: page.sys.tr("El notch se acopla a la parte superior de la pantalla con esquinas fluidas cóncavas. Si se desactiva, pasa a ser una cápsula flotante con margen.")
            on: page.sys.cfg.notchMode !== false
            onToggled: value => { page.sys.cfg.notchMode = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Esquinas fluidas cóncavas del notch")
            sub: page.sys.tr("Activa las curvas de transición orgánica (uñas) a los costados del notch al acoplarse a la pantalla.")
            on: page.sys.cfg.notchFluidCorners !== false
            onToggled: value => { page.sys.cfg.notchFluidCorners = value; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Altura de la barra (Bar height)")
            from: 24; to: 72; step: 1
            value: page.sys.cfg.pillH !== undefined ? page.sys.cfg.pillH : 38
            suffix: "px"
            onMoved: v => { page.sys.cfg.pillH = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Ancho en reposo (Collapsed width)")
            from: 120; to: 640; step: 4
            value: page.sys.cfg.collapsedW !== undefined ? page.sys.cfg.collapsedW : 260
            suffix: "px"
            onMoved: v => { page.sys.cfg.collapsedW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Altura de paneles e isla expandida (Expanded height)")
            from: 480; to: 760; step: 10
            value: page.sys.cfg.expandedH !== undefined ? page.sys.cfg.expandedH : 620
            suffix: "px"
            onMoved: v => { page.sys.cfg.expandedH = Math.round(v); page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.notchMode !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Curvatura de esquinas / Uñas (Notch flare)")
            from: 0; to: 32; step: 1
            value: page.sys.cfg.notchFlare !== undefined ? page.sys.cfg.notchFlare : 12
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchFlare = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.notchMode === false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Margen con el borde superior (Edge gap)")
            from: 0; to: 48; step: 1
            value: page.sys.cfg.islandGap !== undefined ? page.sys.cfg.islandGap : 12
            suffix: "px"
            onMoved: v => { page.sys.cfg.islandGap = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.notchMode === false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Radio de cápsula flotante (Capsule radius)")
            from: 0; to: 40; step: 1
            value: page.sys.cfg.islandRadius !== undefined ? page.sys.cfg.islandRadius : 0
            valueText: (page.sys.cfg.islandRadius === 0 || page.sys.cfg.islandRadius === undefined)
                       ? page.sys.tr("por altura (redondeado)") : page.sys.cfg.islandRadius + " px"
            onMoved: v => { page.sys.cfg.islandRadius = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Autocultar notch")
            sub: page.sys.tr("El notch se oculta automáticamente para dejar la pantalla completamente libre y reaparece al pasar el cursor por el borde superior.")
            on: page.sys.cfg.pillAutoHide
            onToggled: value => { page.sys.cfg.pillAutoHide = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Modo flotante / Overlay")
            sub: page.sys.tr("El notch flota sobre las ventanas sin reservar barra fija superior; las ventanas no saltan ni se encogen.")
            on: page.sys.cfg.pillOverlay
            onToggled: value => { page.sys.cfg.pillOverlay = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Mantener notch visible al abrir")
            sub: page.sys.tr("El notch permanece visible en reposo mientras los paneles y páginas se abren en una tarjeta flotante inferior.")
            on: page.sys.cfg.pillKeepVisible
            onToggled: value => { page.sys.cfg.pillKeepVisible = value; page.sys.saveCfg(); }
        }
    }

    // ============================================================= ANTIGRAVITY & PRODUCTIVIDAD
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Antigravity & Productividad") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Monitoreo en tiempo real del asistente de IA y agentes de desarrollo. Controla el indicador visual en el notch, efectos cromáticos y alertas acústicas:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Indicador de Antigravity en el notch")
            sub: page.sys.tr("Monitoreo en tiempo real de tareas y agentes de desarrollo con logo animado y ondas reactivas.")
            on: page.sys.cfg.antigravityEnabled !== false
            onToggled: v => {
                page.sys.cfg.antigravityEnabled = v;
                if (!v) page.sys.cfg.antigravityMode = "off";
                else if (page.sys.cfg.antigravityMode === "off") page.sys.cfg.antigravityMode = "anim";
                page.sys.saveCfg();
            }
        }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Modo visual del logo")
            options: [
                { id: "anim", text: page.sys.tr("Multicolor (5 fases)") },
                { id: "accent", text: page.sys.tr("Color de Acento") },
                { id: "off", text: page.sys.tr("Desactivado") }
            ]
            value: (!page.sys.cfg.antigravityEnabled || page.sys.cfg.antigravityMode === "off") ? "off" : (page.sys.cfg.antigravityMode || "anim")
            onPicked: id => {
                page.sys.cfg.antigravityMode = id;
                if (id === "off") {
                    page.sys.cfg.antigravityEnabled = false;
                } else {
                    page.sys.cfg.antigravityEnabled = true;
                }
                page.sys.saveCfg();
            }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido de notificación de tareas")
            sub: page.sys.tr("Emite un timbre acústico celestial al recibir avisos o completar tareas de Antigravity.")
            on: page.sys.cfg.antigravitySound !== false
            onToggled: v => {
                page.sys.cfg.antigravitySound = v;
                page.sys.saveCfg();
                if (v) {
                    var tone = page.sys.cfg.antigravityTone || "aero";
                    if (tone === "studio") page.sys.playSound("notif_antigravity_studio", "custom");
                    else page.sys.playSound("notif_antigravity_" + tone);
                }
            }
        }

        SetSelect {
            sys: page.sys
            enabled: page.sys.cfg.antigravitySound !== false
            opacity: enabled ? 1.0 : 0.4
            label: page.sys.tr("Tono acústico de Antigravity")
            options: [
                { id: "aero", text: page.sys.tr("Aero") },
                { id: "studio", text: page.sys.tr("Studio") },
                { id: "quantum", text: page.sys.tr("Quantum") },
                { id: "orbit", text: page.sys.tr("Orbit") }
            ]
            value: page.sys.cfg.antigravityTone || "aero"
            onPicked: id => {
                page.sys.cfg.antigravityTone = id;
                page.sys.saveCfg();
                if (id === "studio") page.sys.playSound("notif_antigravity_studio", "custom");
                else page.sys.playSound("notif_antigravity_" + id);
            }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Separación del indicador Antigravity")
            sub: page.sys.tr("Distancia horizontal en píxeles entre la carátula del álbum y el logo de Antigravity.")
            from: 18; to: 48; step: 2
            value: page.sys.cfg.antigravityMargin !== undefined ? page.sys.cfg.antigravityMargin : 18
            suffix: "px"
            onMoved: v => { page.sys.cfg.antigravityMargin = Math.round(v); page.sys.saveCfg(); }
        }
    }

    // ============================================================= FUNCIONES INTELIGENTES & EXTENSIONES DEL NOTCH
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Funciones Inteligentes & Extensiones del Dynamic Island") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Nuevas capacidades visuales y reactivas para el notch. Cada función puede activarse o desactivarse de forma independiente según tus preferencias:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Aviso emergente de Portapapeles (Clipboard Flash)")
            sub: page.sys.tr("Muestra una cápsula animada en el notch con vista previa elegante del texto al copiar datos al portapapeles.")
            on: page.sys.cfg.notchClipboardFlash !== false
            onToggled: v => { page.sys.cfg.notchClipboardFlash = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Aura reactiva de reproducción (Audio Ripple)")
            sub: page.sys.tr("Efecto de onda luminosa pulsante y armónica en el borde inferior del notch durante la reproducción de música.")
            on: page.sys.cfg.notchAudioRipple !== false
            onToggled: v => { page.sys.cfg.notchAudioRipple = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Título de ventana activa al pasar el cursor (Hover Peek)")
            sub: page.sys.tr("Al pasar el cursor sobre el notch en reposo, revela suavemente el icono y nombre de la aplicación actualmente en foco.")
            on: page.sys.cfg.notchActiveWindowHover !== false
            onToggled: v => { page.sys.cfg.notchActiveWindowHover = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Resplandor ambiental del notch (Ambient Glow)")
            sub: page.sys.tr("Proyecta un halo de luz reactivo y difuso debajo del notch sobre el fondo de escritorio.")
            on: page.sys.cfg.notchAmbientGlowEnabled !== false
            onToggled: v => { page.sys.cfg.notchAmbientGlowEnabled = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.notchAmbientGlowEnabled !== false
            opacity: enabled ? 1.0 : 0.4
            label: page.sys.tr("Intensidad del resplandor ambiental")
            sub: page.sys.tr("Porcentaje de brillo y opacidad del resplandor luminoso bajo el notch.")
            from: 5; to: 100; step: 5
            value: page.sys.cfg.notchAmbientGlowIntensity !== undefined ? page.sys.cfg.notchAmbientGlowIntensity : 35
            suffix: "%"
            onMoved: v => { page.sys.cfg.notchAmbientGlowIntensity = Math.round(v); page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.notchAmbientGlowEnabled !== false
            opacity: enabled ? 1.0 : 0.4
            label: page.sys.tr("Radio de difusión del resplandor")
            sub: page.sys.tr("Radio de dispersión y apertura horizontal del resplandor bajo el notch.")
            from: 20; to: 160; step: 5
            value: page.sys.cfg.notchAmbientGlowRadius !== undefined ? page.sys.cfg.notchAmbientGlowRadius : 60
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchAmbientGlowRadius = Math.round(v); page.sys.saveCfg(); }
        }
    }

    // ============================================================= VISOR DE LETRAS & EXPANSIÓN DE LA ISLA
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Visor de Letras & Expansión de la Isla") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Personaliza la altura y el comportamiento de despliegue del visor de letras sincronizadas SpicyLyrics en la Isla Dinámica (Super+M):")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Altura objetivo del visor de letras")
            sub: page.sys.tr("Dimensión vertical asignada al contenedor de SpicyLyrics al desplegarse.")
            from: 160; to: 420; step: 10
            value: page.sys.cfg.islandLyricsHeight !== undefined ? page.sys.cfg.islandLyricsHeight : 240
            suffix: "px"
            onMoved: v => { page.sys.cfg.islandLyricsHeight = Math.round(v); page.sys.saveCfg(); }
        }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Comportamiento de apertura de letras")
            options: [
                { id: "manual", text: page.sys.tr("Manual (botón 󰎆)") },
                { id: "auto", text: page.sys.tr("Automático si hay letras") },
                { id: "remember", text: page.sys.tr("Recordar último estado") }
            ]
            value: page.sys.cfg.islandLyricsBehavior || "manual"
            onPicked: id => { page.sys.cfg.islandLyricsBehavior = id; page.sys.saveCfg(); }
        }
    }

    // ============================================================= COMPORTAMIENTO Y COLOR DE CARÁTULA & ONDA
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Carátula Reactiva & Color de Onda") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Configura cómo reacciona la carátula al ritmo musical y la posición y color de las ondas de audio:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        // Color de la onda
        SetSelect {
            sys: page.sys
            label: page.sys.tr("Color de la onda de audio")
            options: [
                { id: "0", text: page.sys.tr("Color de carátula") },
                { id: "1", text: page.sys.tr("Acento del sistema") },
                { id: "2", text: page.sys.tr("Texto / Blanco") }
            ]
            value: String(page.sys.cfg.musicWaveColorMode !== undefined ? page.sys.cfg.musicWaveColorMode : 0)
            onPicked: id => {
                page.sys.cfg.musicWaveColorMode = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }

        // Fondo del notch en reproducción musical
        SetSelect {
            sys: page.sys
            label: page.sys.tr("Fondo del notch en música")
            options: [
                { id: "0", text: page.sys.tr("Tinte de portada (Spotify / M3)") },
                { id: "1", text: page.sys.tr("Acrílico vibrante") },
                { id: "2", text: page.sys.tr("Color de la onda / Acento puro") }
            ]
            value: String(page.sys.cfg.notchMusicBgMode !== undefined ? page.sys.cfg.notchMusicBgMode : 0)
            onPicked: id => {
                page.sys.cfg.notchMusicBgMode = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }

        // Ubicación de la onda
        SetSelect {
            sys: page.sys
            label: page.sys.tr("Ubicación de la onda")
            options: [
                { id: "0", text: page.sys.tr("Derecha") },
                { id: "1", text: page.sys.tr("Carátula") },
                { id: "2", text: page.sys.tr("Ambas") }
            ]
            value: String(page.sys.cfg.musicWavePos !== undefined ? page.sys.cfg.musicWavePos : 0)
            onPicked: id => {
                page.sys.cfg.musicWavePos = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }

        // Onda debajo de la portada (reacción al beat)
        SetToggle {
            sys: page.sys
            label: page.sys.tr("Onda acústica debajo de la portada")
            sub: page.sys.tr("Emite anillos de ondas acústicas que reaccionan con precisión al golpe y ritmo de la canción.")
            on: page.sys.cfg.musicCoverRipple !== false
            onToggled: v => { page.sys.cfg.musicCoverRipple = v; page.sys.saveCfg(); }
        }

        // Forma de la onda tras la carátula
        SetSelect {
            sys: page.sys
            enabled: page.sys.cfg.musicCoverRipple !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Forma de la onda tras la carátula")
            options: [
                { id: "0", text: page.sys.tr("Circular") },
                { id: "1", text: page.sys.tr("Silueta") },
                { id: "2", text: page.sys.tr("Recta") }
            ]
            value: String(page.sys.cfg.musicCoverRippleShape !== undefined ? page.sys.cfg.musicCoverRippleShape : 0)
            onPicked: id => {
                page.sys.cfg.musicCoverRippleShape = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }

        // Frecuencias de onda tras carátula
        SetSelect {
            sys: page.sys
            enabled: page.sys.cfg.musicCoverRipple !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Frecuencias de onda tras carátula")
            options: [
                { id: "0", text: page.sys.tr("Graves") },
                { id: "1", text: page.sys.tr("Medios") },
                { id: "2", text: page.sys.tr("Agudos") },
                { id: "3", text: page.sys.tr("Completo") }
            ]
            value: String(page.sys.cfg.musicCoverRippleFreq !== undefined ? page.sys.cfg.musicCoverRippleFreq : 0)
            onPicked: id => {
                page.sys.cfg.musicCoverRippleFreq = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }

        // Sensibilidad de onda tras carátula
        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.musicCoverRipple !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Sensibilidad de onda tras carátula")
            from: 25; to: 250; step: 5
            value: page.sys.cfg.musicCoverRippleSens !== undefined ? page.sys.cfg.musicCoverRippleSens : 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.musicCoverRippleSens = v; page.sys.saveCfg(); }
        }

        // Persistencia de onda tras carátula
        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.musicCoverRipple !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Persistencia de onda tras carátula")
            from: 50; to: 250; step: 5
            value: page.sys.cfg.musicCoverRipplePersistence !== undefined ? page.sys.cfg.musicCoverRipplePersistence : 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.musicCoverRipplePersistence = v; page.sys.saveCfg(); }
        }

        // Reacción de la portada con la música
        SetToggle {
            sys: page.sys
            label: page.sys.tr("Reacción de la portada con la música")
            sub: page.sys.tr("La carátula late y pulsa al compás del ritmo y las frecuencias graves del audio.")
            on: page.sys.cfg.musicCoverBounce !== false
            onToggled: v => { page.sys.cfg.musicCoverBounce = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.musicCoverBounce !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Intensidad del latido de la carátula")
            from: 10; to: 100; step: 5
            value: page.sys.cfg.musicArtReactionIntensity !== undefined ? page.sys.cfg.musicArtReactionIntensity : 50
            suffix: "%"
            onMoved: v => { page.sys.cfg.musicArtReactionIntensity = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Ecualizador de ondas activo")
            sub: page.sys.tr("Muestra las barras de audio animadas al reproducir música.")
            on: page.sys.cfg.musicWaveEnabled !== false
            onToggled: v => { page.sys.cfg.musicWaveEnabled = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.musicWaveEnabled !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Sensibilidad de onda derecha (barras)")
            from: 25; to: 250; step: 5
            value: page.sys.cfg.musicRightWaveSens !== undefined ? page.sys.cfg.musicRightWaveSens : 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.musicRightWaveSens = v; page.sys.saveCfg(); }
        }

        // Frecuencias de onda derecha (barras)
        SetSelect {
            sys: page.sys
            enabled: page.sys.cfg.musicWaveEnabled !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Frecuencias de onda derecha (barras)")
            options: [
                { id: "0", text: page.sys.tr("Completo") },
                { id: "1", text: page.sys.tr("Graves") },
                { id: "2", text: page.sys.tr("Medios") },
                { id: "3", text: page.sys.tr("Agudos") }
            ]
            value: String(page.sys.cfg.musicRightWaveFreq !== undefined ? page.sys.cfg.musicRightWaveFreq : 0)
            onPicked: id => {
                page.sys.cfg.musicRightWaveFreq = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }

        // Persistencia de onda derecha (caída)
        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.musicWaveEnabled !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Persistencia de onda derecha (caída)")
            from: 50; to: 250; step: 5
            value: page.sys.cfg.musicRightWavePersistence !== undefined ? page.sys.cfg.musicRightWavePersistence : 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.musicRightWavePersistence = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.musicWaveEnabled !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Sensibilidad de ola extendida")
            from: 25; to: 250; step: 5
            value: page.sys.cfg.musicWaveSens !== undefined ? page.sys.cfg.musicWaveSens : 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.musicWaveSens = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Tamaño de carátula en notch")
            from: 18; to: 36; step: 1
            value: page.sys.cfg.musicArtSize !== undefined ? page.sys.cfg.musicArtSize : 26
            suffix: "px"
            onMoved: v => { page.sys.cfg.musicArtSize = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Radio de curvatura de la carátula")
            from: 2; to: 14; step: 1
            value: page.sys.cfg.musicCoverRadius !== undefined ? page.sys.cfg.musicCoverRadius : 7
            suffix: "px"
            onMoved: v => { page.sys.cfg.musicCoverRadius = v; page.sys.saveCfg(); }
        }
    }

    // ============================================================= ALERTAS DE BATERÍA (CON VISTA PREVIA INLINE)
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Alertas Dynamic Island & Vista Previa") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Visualiza y prueba las alertas de batería y carga directamente en este recuadro interactivo sin que se cierre el menú de ajustes:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        // ======================= RECUADRO DE VISTA PREVIA DE ALERTAS =======================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 116
            radius: 12
            color: "#0a0c10"
            border.color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
            border.width: 1
            clip: true

            // Fondo sutil
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.04)
            }

            // Botones superiores para elegir el estado a previsualizar
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 8
                spacing: 6

                Text {
                    text: page.sys.tr("PROBAR VISTA PREVIA:")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                }

                Repeater {
                    model: [
                        { id: 80, label: "80% Carga", col: page.sys.colCharge },
                        { id: 100, label: "100% Completa", col: page.sys.colCharge },
                        { id: 20, label: "20% Naranja", col: page.sys.colBattWarn },
                        { id: 15, label: "15% Rojo", col: page.sys.colBattCrit }
                    ]

                    Rectangle {
                        id: tabBtn
                        required property var modelData
                        readonly property bool active: page.previewBattMode === modelData.id
                        width: tabTxt.implicitWidth + 16
                        height: 22
                        radius: 6
                        color: active ? Qt.rgba(modelData.col.r, modelData.col.g, modelData.col.b, 0.25)
                                      : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: active ? modelData.col : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.15)
                        border.width: active ? 1.5 : 1

                        Text {
                            id: tabTxt
                            anchors.centerIn: parent
                            text: modelData.label
                            color: tabBtn.active ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: 10; bold: tabBtn.active }
                        }

                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.previewBattMode = modelData.id;
                                simFillAnim.restart();
                            }
                        }
                    }
                }
            }

            // Cápsula Dynamic Island simulada con textos personalizados
            Rectangle {
                id: simCapsule
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40
                width: Math.max(310, simRow.implicitWidth + 40)
                radius: 20
                color: "#000000"
                border.color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1

                RowLayout {
                    id: simRow
                    anchors.centerIn: parent
                    spacing: 16

                    // Texto descriptivo izquierda (refleja en vivo los textos editados)
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Text {
                            text: page.previewBattMode + "%"
                            color: page.previewBattMode <= 15 ? page.sys.colBattCrit
                                 : page.previewBattMode <= 20 ? page.sys.colBattWarn
                                 : page.sys.colCharge
                            font { family: page.sys.fontFam; pixelSize: 14; bold: true }
                        }

                        Text {
                            text: page.previewBattMode >= 100
                                 ? (page.sys.cfg.battFullText || page.sys.tr("Carga completa"))
                                 : page.previewBattMode === 80
                                 ? (page.sys.cfg.batt80Text || page.sys.tr("Carga al 80%"))
                                 : page.previewBattMode <= 15
                                 ? (page.sys.cfg.battCritText || page.sys.tr("Batería crítica"))
                                 : (page.sys.cfg.battWarnText || page.sys.tr("Batería baja"))
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: 12; bold: true }
                        }
                    }

                    // Badge de batería derecha
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 64
                        implicitHeight: 28
                        radius: 14
                        color: page.previewBattMode <= 15
                            ? Qt.rgba(page.sys.colBattCrit.r, page.sys.colBattCrit.g, page.sys.colBattCrit.b, 0.24)
                            : page.previewBattMode <= 20
                            ? Qt.rgba(page.sys.colBattWarn.r, page.sys.colBattWarn.g, page.sys.colBattWarn.b, 0.24)
                            : Qt.rgba(page.sys.colCharge.r, page.sys.colCharge.g, page.sys.colCharge.b, 0.22)

                        Item {
                            anchors.centerIn: parent
                            width: 33
                            height: 16

                            // Shell de la batería
                            Rectangle {
                                id: simShell
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 29
                                height: 15
                                radius: 4
                                color: "transparent"
                                border.color: page.previewBattMode <= 15 ? page.sys.colBattCrit
                                            : page.previewBattMode <= 20 ? page.sys.colBattWarn
                                            : page.sys.colCharge
                                border.width: 1.5
                                clip: true

                                // Relleno interior ajustado a los bordes sin espacio libre
                                Rectangle {
                                    id: simFill
                                    anchors.left: parent.left
                                    anchors.leftMargin: 1.5
                                    anchors.top: parent.top
                                    anchors.topMargin: 1.5
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1.5
                                    radius: 2.5
                                    color: simShell.border.color
                                    width: Math.max(4, Math.round((simShell.width - 3) * (page.previewBattMode / 100)))

                                    NumberAnimation on width {
                                        id: simFillAnim
                                        from: 2
                                        to: Math.max(4, Math.round((simShell.width - 3) * (page.previewBattMode / 100)))
                                        duration: 600
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            // Terminal más
                            Rectangle {
                                anchors.left: simShell.right
                                anchors.leftMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 6
                                radius: 1
                                color: simShell.border.color
                            }
                        }
                    }
                }
            }
        }

        // ======================= CONTROLES DE ALERTA DE CARGA =======================
        SetLabel { sys: page.sys; text: page.sys.tr("Configuración de Carga") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Aviso al 80% (Carga saludable)")
            sub: page.sys.tr("Alerta Dynamic Island al alcanzar el 80% para proteger la vida útil de la batería.")
            on: page.sys.cfg.batt80Alert !== false
            onToggled: v => { page.sys.cfg.batt80Alert = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Aviso al 100% (Carga completa)")
            sub: page.sys.tr("Alerta Dynamic Island con animación de llenado y destello al llegar al 100%.")
            on: page.sys.cfg.fullBatteryAlert !== false
            onToggled: v => { page.sys.cfg.fullBatteryAlert = v; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color de carga y nivel")
            sub: page.sys.tr("Color de la batería interior, borde y porcentaje en alertas de carga.")
            value: page.sys.cfg.colCharge || "#30D158"
            defaultColor: "#30D158"
            presets: ["#30D158", "#10b981", "#059669", "#22c55e", "#16a34a", "#06b6d4", "#3b82f6", "#ffffff"]
            onPicked: hex => { page.sys.cfg.colCharge = hex; page.sys.saveCfg(); }
        }

        // ======================= CONTROLES DE ALERTA DE BATERÍA BAJA =======================
        SetLabel { sys: page.sys; text: page.sys.tr("Configuración de Batería Baja") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Avisos en el notch")
            sub: page.sys.tr("Muestra las alertas Dynamic Island con porcentaje e icono ajustado al borde sin huecos.")
            on: page.sys.cfg.lowBatteryAlert !== false
            onToggled: v => { page.sys.cfg.lowBatteryAlert = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.lowBatteryAlert !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Umbral de advertencia (Naranja)")
            from: 16; to: 30; step: 1
            value: page.sys.cfg.lowBatteryThreshold !== undefined ? page.sys.cfg.lowBatteryThreshold : 20
            suffix: "%"
            onMoved: v => { page.sys.cfg.lowBatteryThreshold = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.lowBatteryAlert !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Umbral crítico (Rojo)")
            from: 5; to: 15; step: 1
            value: page.sys.cfg.lowBatteryCritThreshold !== undefined ? page.sys.cfg.lowBatteryCritThreshold : 15
            suffix: "%"
            onMoved: v => { page.sys.cfg.lowBatteryCritThreshold = v; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color de advertencia")
            value: page.sys.cfg.colBattWarn || "#ff9f0a"
            defaultColor: "#ff9f0a"
            presets: ["#ff9f0a", "#f59e0b", "#d97706", "#f97316", "#ea580c", "#eab308", "#facc15", "#ffffff"]
            onPicked: hex => { page.sys.cfg.colBattWarn = hex; page.sys.saveCfg(); }
        }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color crítico")
            value: page.sys.cfg.colBattCrit || "#ff453a"
            defaultColor: "#ff453a"
            presets: ["#ff453a", "#ef4444", "#dc2626", "#b91c1c", "#f43f5e", "#e11d48", "#ec4899", "#ffffff"]
            onPicked: hex => { page.sys.cfg.colBattCrit = hex; page.sys.saveCfg(); }
        }

        // ======================= BOTONES DE ACCIÓN REAL (OPCIONAL EN PANTALLA) =======================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: page.sys.tr("¿Deseas probar en la isla real en la parte superior?")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                SetButton {
                    Layout.fillWidth: true
                    sys: page.sys
                    text: page.sys.tr("Isla 80%")
                    onClicked: page.sys.showFullBattToast(80)
                }

                SetButton {
                    Layout.fillWidth: true
                    sys: page.sys
                    text: page.sys.tr("Isla 100%")
                    onClicked: page.sys.showFullBattToast(100)
                }

                SetButton {
                    Layout.fillWidth: true
                    sys: page.sys
                    text: page.sys.tr("Isla 20%")
                    onClicked: page.sys.showLowBattToast(page.sys.cfg.lowBatteryThreshold || 20)
                }

                SetButton {
                    Layout.fillWidth: true
                    sys: page.sys
                    text: page.sys.tr("Isla 15%")
                    onClicked: page.sys.showLowBattToast(page.sys.cfg.lowBatteryCritThreshold || 15)
                }
            }
        }
    }

    // ============================================================= TEXTOS PERSONALIZADOS DE ALERTAS
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Textos Personalizados de Alertas") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Personaliza las frases y mensajes mostrados en el Dynamic Island al cargar o advertir nivel de batería:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetTextInput {
            sys: page.sys
            label: page.sys.tr("Texto aviso 80% (Carga saludable)")
            sub: page.sys.tr("Frase mostrada al alcanzar el 80% de batería conectada.")
            defaultValue: "Carga al 80%"
            value: page.sys.cfg.batt80Text || "Carga al 80%"
            onAccepted: t => { page.sys.cfg.batt80Text = t; page.sys.saveCfg(); }
        }

        SetTextInput {
            sys: page.sys
            label: page.sys.tr("Texto aviso 100% (Carga completa)")
            sub: page.sys.tr("Frase mostrada al llegar al 100% de carga de batería.")
            defaultValue: "Carga completa"
            value: page.sys.cfg.battFullText || "Carga completa"
            onAccepted: t => { page.sys.cfg.battFullText = t; page.sys.saveCfg(); }
        }

        SetTextInput {
            sys: page.sys
            label: page.sys.tr("Texto advertencia batería baja (Naranja)")
            sub: page.sys.tr("Frase mostrada tras caer por debajo del umbral de advertencia.")
            defaultValue: "Batería baja"
            value: page.sys.cfg.battWarnText || "Batería baja"
            onAccepted: t => { page.sys.cfg.battWarnText = t; page.sys.saveCfg(); }
        }

        SetTextInput {
            sys: page.sys
            label: page.sys.tr("Texto batería crítica (Rojo)")
            sub: page.sys.tr("Frase mostrada al caer al umbral crítico de batería.")
            defaultValue: "Batería crítica"
            value: page.sys.cfg.battCritText || "Batería crítica"
            onAccepted: t => { page.sys.cfg.battCritText = t; page.sys.saveCfg(); }
        }

        SetTextInput {
            sys: page.sys
            label: page.sys.tr("Texto al conectar cargador")
            sub: page.sys.tr("Frase de confirmación en el Dynamic Island al enchufar el cargador.")
            defaultValue: "Cargando"
            value: page.sys.cfg.chargeText || "Cargando"
            onAccepted: t => { page.sys.cfg.chargeText = t; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- animación & sonidos
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Sonidos del Sistema & Dynamic Island") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Efectos acústicos coordinados para acciones del notch, carga de energía y avisos:")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Efectos de sonido del sistema")
            sub: page.sys.tr("Sonidos para el notch, batería, capturas de pantalla, notificaciones y Bluetooth.")
            on: page.sys.cfg.uiSounds !== false
            onToggled: v => { page.sys.cfg.uiSounds = v; page.sys.saveCfg(); if (v) page.sys.playSound("island_pop"); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido al conectar cargador")
            sub: page.sys.tr("Reproduce un efecto armónico al enchufar la alimentación eléctrica.")
            on: page.sys.cfg.chargeSound !== false
            onToggled: v => { page.sys.cfg.chargeSound = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido en avisos de batería (Baja / 80% / 100%)")
            sub: page.sys.tr("Reproduce tono sutil de batería al 80/100% y aviso armónico al alcanzar nivel bajo de batería.")
            on: page.sys.cfg.battAlertSound !== false
            onToggled: v => { page.sys.cfg.battAlertSound = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido Pop de apertura Dynamic Island")
            sub: page.sys.tr("Pop acústico sutil característico al expandirse la isla dinámica.")
            on: page.sys.cfg.islandPopSound !== false
            onToggled: v => { page.sys.cfg.islandPopSound = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido de referencia al cambiar volumen")
            sub: page.sys.tr("Reproduce un suave 'pip' procedural sincronizado con el nivel de volumen como referencia acústica.")
            on: page.sys.cfg.volumeSoundTick !== false
            onToggled: v => { page.sys.cfg.volumeSoundTick = v; page.sys.saveCfg(); if (v) page.sys.playSound("vol_tick"); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido en retroiluminación de teclado (Fn+Space)")
            sub: page.sys.tr("Tonos armónicos dedicados para 0%, 50% y 100% al regular la luz del teclado.")
            on: page.sys.cfg.kbdLightSound !== false
            onToggled: v => { page.sys.cfg.kbdLightSound = v; page.sys.saveCfg(); if (v) page.sys.playSound("kbd_light_2"); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Sonido al alternar perfiles de energía (Fn+Q)")
            sub: page.sys.tr("Sonido acústico diferenciado según el modo de rendimiento seleccionado.")
            on: page.sys.cfg.powerProfileSound !== false
            onToggled: v => { page.sys.cfg.powerProfileSound = v; page.sys.saveCfg(); if (v) page.sys.playSound("mode_performance"); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Ondas pulsantes (Ripple) en el rayo")
            sub: page.sys.tr("Ondas circulares desvaneciéndose en el icono de batería mientras se carga.")
            on: page.sys.cfg.chargeRipple !== false
            onToggled: v => { page.sys.cfg.chargeRipple = v; page.sys.saveCfg(); }
        }

        // Matriz de botones de prueba de audio
        RowLayout {
            Layout.fillWidth: true
            SetLabel {
                sys: page.sys
                text: page.sys.tr("Audición de Efectos Acústicos")
                Layout.fillWidth: true
            }

            Rectangle {
                id: testAllBtn
                Layout.preferredHeight: 28
                Layout.preferredWidth: testAllRow.implicitWidth + 20
                radius: 6
                visible: page.sys.cfg.uiSounds !== false
                color: page.allSoundTimer.running ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25)
                                                  : (testAllMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                border.color: page.allSoundTimer.running ? page.sys.colOn : (testAllMa.containsMouse ? page.sys.colOn : page.sys.colLine)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

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
                        text: page.allSoundTimer.running ? page.sys.tr("Detener prueba") : page.sys.tr("Testear todos los sonidos")
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
                            page.sys.playSound(page.soundTestModel[0].id);
                            page.allSoundTimer.start();
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
                model: page.soundTestModel

                Rectangle {
                    id: sndTestBtn
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: (page.allSoundTimer.running && page.allSoundIdx >= 0 && page.soundTestModel[page.allSoundIdx].id === modelData.id)
                        ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                        : (sndTestMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: (page.allSoundTimer.running && page.allSoundIdx >= 0 && page.soundTestModel[page.allSoundIdx].id === modelData.id)
                        ? page.sys.colOn
                        : (sndTestMa.containsMouse ? page.sys.colOn : page.sys.colLine)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.icon
                            color: sndTestMa.containsMouse ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: modelData.label
                            color: sndTestMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sndTestMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.sys.playSound(modelData.id)
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- espaciados y márgenes
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Márgenes & Espaciados del Notch") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Separación entre secciones")
            from: 4; to: 32; step: 1
            value: page.sys.cfg.notchSectionGap !== undefined ? page.sys.cfg.notchSectionGap : 10
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchSectionGap = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Separación icono de batería")
            from: 2; to: 24; step: 1
            value: page.sys.cfg.notchBatteryGap !== undefined ? page.sys.cfg.notchBatteryGap : 8
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchBatteryGap = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Padding lateral reloj / tiempo")
            from: 0; to: 24; step: 1
            value: page.sys.cfg.notchClockPad !== undefined ? page.sys.cfg.notchClockPad : 0
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchClockPad = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- evasión de ventanas
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Evasión de Ventanas (Brave & Pantalla Completa)") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Esquivar ventanas maximizadas")
            sub: page.sys.tr("Oculta automáticamente el notch cuando una ventana se maximiza para no tapar pestañas.")
            on: page.sys.cfg.braveDodgeEnabled !== false
            onToggled: v => { page.sys.cfg.braveDodgeEnabled = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.sys.cfg.braveDodgeEnabled !== false
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Retorno tras esquivar")
            from: 200; to: 3000; step: 100
            value: page.sys.cfg.braveReturnDelay !== undefined ? page.sys.cfg.braveReturnDelay : 1000
            suffix: "ms"
            onMoved: v => { page.sys.cfg.braveReturnDelay = v; page.sys.saveCfg(); }
        }
    }

    // ============================================================= HARDWARE LENOVO LOQ: RETROILUMINACIÓN
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Hardware Lenovo LOQ: Retroiluminación (Fn+Space)") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Control en tiempo real, pruebas acústicas y avisos visuales en el Dynamic Island para los niveles de brillo del teclado (0%, 50%, 100%):")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        // Mini preview en vivo interactivo del estado actual del teclado
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 14
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.25)

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 26
                    radius: 13
                    color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.45)

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        color: page.sys.colOn
                        font { family: page.sys.fontFam; pixelSize: 14 }
                    }
                }

                Text {
                    text: page.sys.tr("Estado Actual:")
                    color: page.sys.colFg
                    font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 1; bold: true }
                }

                Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: kbdCurPctTxt.implicitWidth + 14
                    radius: 11
                    color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.45)

                    Text {
                        id: kbdCurPctTxt
                        anchors.centerIn: parent
                        text: page.sys.kbdLightLevel === 2 ? "100%" : (page.sys.kbdLightLevel === 1 ? "50%" : "0%")
                        color: page.sys.colOn
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                    }
                }

                Text {
                    text: "·"
                    color: page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
                }

                Text {
                    text: page.sys.kbdLightLevel === 2 ? page.sys.tr("Brillo Máximo")
                        : (page.sys.kbdLightLevel === 1 ? page.sys.tr("Brillo Medio")
                        : page.sys.tr("Apagado"))
                    color: page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 2 }
                }

                // LEDs físicos miniatura
                RowLayout {
                    spacing: 4
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: page.sys.kbdLightLevel >= 1 ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.2)
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: page.sys.kbdLightLevel >= 2 ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.2)
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }
        }

        // Fila de botones de prueba en vivo
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            SetButton {
                sys: page.sys
                text: page.sys.tr("0% (Apagado)")
                onClicked: { page.sys.setKbdBacklight(0); page.sys.showKbdLightToast(0); }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("50% (Medio)")
                onClicked: { page.sys.setKbdBacklight(1); page.sys.showKbdLightToast(1); }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("100% (Máximo)")
                onClicked: { page.sys.setKbdBacklight(2); page.sys.showKbdLightToast(2); }
            }

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                primary: true
                text: page.sys.tr("Alternar (Fn+Space)")
                onClicked: page.sys.cycleKbdBacklight()
            }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Aviso de retroiluminación en Dynamic Island")
            sub: page.sys.tr("Despliega la cápsula horizontal con indicador LED al presionar Fn+Space.")
            on: page.sys.cfg.kbdLightToast !== false
            onToggled: v => { page.sys.cfg.kbdLightToast = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Duración del aviso de teclado")
            from: 1000; to: 4000; step: 100
            value: page.sys.cfg.kbdToastDuration !== undefined ? page.sys.cfg.kbdToastDuration : 2200
            suffix: "ms"
            onMoved: v => { page.sys.cfg.kbdToastDuration = v; page.sys.saveCfg(); }
        }
    }

    // ============================================================= HARDWARE LENOVO LOQ: MODOS DE RENDIMIENTO
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Hardware Lenovo LOQ: Modos de Rendimiento (Fn+Q)") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Vinculado al hardware de Lenovo LOQ (Fn+Q o Super+Alt+P). Cambia en tiempo real entre Modo Ahorro (Silencioso), Modo Equilibrado y Modo Rendimiento con aviso animado en el Dynamic Island.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Duración del aviso de modo de energía")
            from: 1000; to: 4000; step: 100
            value: page.sys.cfg.powerToastDuration !== undefined ? page.sys.cfg.powerToastDuration : 2600
            suffix: "ms"
            onMoved: v => { page.sys.cfg.powerToastDuration = v; page.sys.saveCfg(); }
        }

        SetLabel { sys: page.sys; text: page.sys.tr("Colores de Modos de Energía (Ola & Botones)") }

        SetColor {
            sys: page.sys
            label: page.sys.tr("Color Modo Ahorro")
            sub: page.sys.tr("Color de la ola en el widget, menú de batería y notificación.")
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
            label: page.sys.tr("Color Modo Equilibrado")
            sub: page.sys.tr("Color de la ola en el widget, menú de batería y notificación.")
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
            label: page.sys.tr("Color Modo Rendimiento")
            sub: page.sys.tr("Color de la ola en el widget, menú de batería y notificación.")
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

            SetButton {
                sys: page.sys
                text: page.sys.tr("Modo Ahorro")
                onClicked: { page.sys.setPowerProfile("power-saver"); page.sys.showPowerProfileToast("power-saver"); }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Equilibrado")
                onClicked: { page.sys.setPowerProfile("balanced"); page.sys.showPowerProfileToast("balanced"); }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Rendimiento")
                onClicked: { page.sys.setPowerProfile("performance"); page.sys.showPowerProfileToast("performance"); }
            }

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                primary: true
                text: page.sys.tr("Alternar (Fn+Q)")
                onClicked: page.sys.cyclePowerProfile()
            }
        }
    }

    // ============================================================= FIDELIDAD DE ANIMACIONES DEL NOTCH
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Fidelidad de Animaciones del Dynamic Island") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Prueba en tiempo real las transiciones del notch: giro 3D continuo de portadas (FlipArt) y ondulación fluida de barras (WaveBars):")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SetButton {
                sys: page.sys
                text: page.sys.tr("Probar Giro 3D Carátula")
                onClicked: {
                    if (page.sys && page.sys.playSound) page.sys.playSound("island_pop");
                    page.previewState = 0;
                    page.previewTrackKey = (page.previewTrackKey === "preview_track_a" ? "preview_track_b" : "preview_track_a");
                }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Alternar Estado Onda")
                onClicked: {
                    if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                    page.previewState = 0;
                    page.previewWavePlaying = !page.previewWavePlaying;
                    if (page.sys && page.sys.player && page.sys.player.togglePlaying) {
                        page.sys.player.togglePlaying();
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
