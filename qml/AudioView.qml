import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Audio y Sonido: volumen maestro con preajustes rápidos, selector de dispositivos y mezclador de aplicaciones
Item {
    id: view
    property var sys

    readonly property real maxAvailableH: (view.sys.cfg.expandedH || 620) - 30
    implicitHeight: Math.min(maxAvailableH, col.implicitHeight)

    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        pStreams.running = true;
    }
    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null

    // -------------------------------------------------- mezclador de aplicaciones (pactl)
    property var streamsList: []
    property bool isUserDragging: false

    Process {
        id: pStreams
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/audio_streams.sh list"]
        stdout: SplitParser {
            onRead: data => {
                if (view.isUserDragging) return;
                try {
                    var parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) {
                        view.streamsList = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: streamsTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (!view.isUserDragging) {
                pStreams.running = false;
                pStreams.running = true;
            }
        }
    }

    Process {
        id: pStreamAction
    }

    function setAppVolume(streamId, pct) {
        pStreamAction.command = ["sh", "-c", Quickshell.env("HOME")
                                 + "/.config/panacea/scripts/audio_streams.sh set-volume "
                                 + streamId + " " + pct];
        pStreamAction.running = true;
    }

    function toggleAppMute(streamId) {
        pStreamAction.command = ["sh", "-c", Quickshell.env("HOME")
                                 + "/.config/panacea/scripts/audio_streams.sh toggle-mute "
                                 + streamId];
        pStreamAction.running = true;
        quickRefresh.restart();
    }

    Timer {
        id: quickRefresh
        interval: 150
        onTriggered: {
            if (!pStreams.running) pStreams.running = true;
        }
    }

    function getStreamIcon(name, bin, icon) {
        var s = (String(name || "") + " " + String(bin || "") + " " + String(icon || "")).toLowerCase();
        if (s.indexOf("telegram") >= 0) return String.fromCodePoint(0xF2C6);
        if (s.indexOf("spotify") >= 0) return String.fromCodePoint(0xF1BC);
        if (s.indexOf("firefox") >= 0) return String.fromCodePoint(0xF269);
        if (s.indexOf("chrome") >= 0 || s.indexOf("chromium") >= 0 || s.indexOf("brave") >= 0 || s.indexOf("zen") >= 0) return String.fromCodePoint(0xF268);
        if (s.indexOf("discord") >= 0 || s.indexOf("vesktop") >= 0 || s.indexOf("webcord") >= 0) return String.fromCodePoint(0xF392);
        if (s.indexOf("steam") >= 0) return String.fromCodePoint(0xF1B6);
        if (s.indexOf("vlc") >= 0 || s.indexOf("mpv") >= 0 || s.indexOf("video") >= 0 || s.indexOf("player") >= 0 || s.indexOf("music") >= 0) return String.fromCodePoint(0xF144);
        if (s.indexOf("game") >= 0 || s.indexOf("retroarch") >= 0 || s.indexOf("wine") >= 0 || s.indexOf("lutris") >= 0) return String.fromCodePoint(0xF11B);
        return String.fromCodePoint(0xF028);
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: scroll.contentHeight > scroll.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            width: 3
            contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                var max = Math.max(0, scroll.contentHeight - scroll.height);
                scroll.contentY = Math.max(0, Math.min(max, scroll.contentY - d));
            }
        }

        ColumnLayout {
            id: col
            width: scroll.width - (scroll.contentHeight > scroll.height ? 6 : 0)
            spacing: 14

        // ------------------------------------------------------- Cabecera estilizada
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 12
                color: backMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                                            : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                border.color: backMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.20)
                                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                scale: backMa.pressed ? 0.92 : (backMa.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.goBack()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: view.sys.tr("Audio y Sonido")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                }

                Text {
                    text: view.sink ? String(view.sink.description || view.sink.name || (view.sys && view.sys.tr ? view.sys.tr("Salida predeterminada") : "Salida predeterminada")) : (view.sys && view.sys.tr ? view.sys.tr("Control de volumen y dispositivos") : "Control de volumen y dispositivos")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: escText.implicitWidth + 14
                radius: 12
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                border.width: 1

                Text {
                    id: escText
                    anchors.centerIn: parent
                    text: "ESC"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true; letterSpacing: 0.5 }
                }
            }
        }

        // ------------------------------------------------------- Tarjeta Hero: Volumen Principal
        Rectangle {
            id: masterCard
            Layout.fillWidth: true
            Layout.preferredHeight: masterCol.implicitHeight + 28
            radius: 18
            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)
            border.color: masterHover.hovered ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 180 } }

            HoverHandler { id: masterHover }

            ColumnLayout {
                id: masterCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Fila superior: etiqueta + porcentaje pill
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰓃"
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 15 }
                    }

                    Text {
                        text: view.sys.tr("Volumen Maestro")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: volBadgeText.implicitWidth + 14
                        radius: 11
                        color: view.sinkAudio && view.sinkAudio.muted
                               ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.20)
                               : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                        border.color: view.sinkAudio && view.sinkAudio.muted
                                      ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.40)
                                      : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                        border.width: 1

                        Text {
                            id: volBadgeText
                            anchors.centerIn: parent
                            text: view.sinkAudio ? (view.sinkAudio.muted ? "MUTE" : (Math.round(view.sinkAudio.volume * 100) + "%")) : "—"
                            color: view.sinkAudio && view.sinkAudio.muted ? view.sys.colCrit : view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }
                    }
                }

                // Slider Maestro estilo píldora Nothing OS
                Item {
                    id: sl
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    readonly property real pos: view.sinkAudio ? Math.max(0, Math.min(1, view.sinkAudio.volume)) : 0
                    readonly property bool muted: view.sinkAudio ? view.sinkAudio.muted : false

                    function setFromX(x) {
                        if (!view.sinkAudio) return;
                        var r = Math.max(0, Math.min(1, x / Math.max(1, width)));
                        view.sinkAudio.volume = r;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 19
                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        border.color: drag.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                                         : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        border.width: 1
                        clip: true
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Relleno de volumen
                        Rectangle {
                            width: Math.max(38, parent.width * sl.pos)
                            height: parent.height
                            radius: 19
                            color: sl.muted ? Qt.rgba(view.sys.colMuted.r, view.sys.colMuted.g, view.sys.colMuted.b, 0.35)
                                            : view.sys.colOn
                            opacity: sl.muted ? 0.45 : 0.90
                            Behavior on width {
                                enabled: !drag.pressed
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }

                    // Botón Silenciar integrado a la izquierda
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: muteBtnMa.containsMouse ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(0, 0, 0, 0.15)
                        scale: muteBtnMa.pressed ? 0.92 : (muteBtnMa.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: sl.muted ? "󰖁"
                                : sl.pos < 0.34 ? "󰕿"
                                : sl.pos < 0.67 ? "󰖀" : "󰕾"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }
                        MouseArea {
                            id: muteBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (view.sinkAudio) view.sinkAudio.muted = !view.sinkAudio.muted
                        }
                    }

                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        anchors.leftMargin: 38
                        anchors.rightMargin: 8
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => sl.setFromX(mouse.x + 38)
                        onPositionChanged: mouse => { if (pressed) sl.setFromX(mouse.x + 38); }
                        onWheel: wheel => {
                            if (!view.sinkAudio) return;
                            var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            view.sinkAudio.volume = Math.max(0, Math.min(1, view.sinkAudio.volume + step));
                        }
                    }
                }

                // Fila de preajustes rápidos con indicación de estado activo
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "Mute", vol: -1 },
                            { label: "25%", vol: 0.25 },
                            { label: "50%", vol: 0.50 },
                            { label: "75%", vol: 0.75 },
                            { label: "100%", vol: 1.00 }
                        ]

                        Rectangle {
                            id: presetBtn
                            required property var modelData
                            readonly property bool isCurrent: {
                                if (!view.sinkAudio) return false;
                                if (presetBtn.modelData.vol < 0) return view.sinkAudio.muted;
                                return !view.sinkAudio.muted && Math.abs(view.sinkAudio.volume - presetBtn.modelData.vol) < 0.03;
                            }

                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 8
                            color: presetBtn.isCurrent
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.24)
                                   : (pMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                                                        : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05))
                            border.color: presetBtn.isCurrent
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                            border.width: presetBtn.isCurrent ? 1.5 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            scale: pMa.pressed ? 0.94 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: presetBtn.modelData.label
                                color: presetBtn.isCurrent
                                       ? view.sys.colOn
                                       : (pMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }

                            MouseArea {
                                id: pMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!view.sinkAudio) return;
                                    if (presetBtn.modelData.vol < 0) {
                                        view.sinkAudio.muted = !view.sinkAudio.muted;
                                    } else {
                                        view.sinkAudio.muted = false;
                                        view.sinkAudio.volume = presetBtn.modelData.vol;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------- Dispositivos de salida
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            Text {
                text: "󰓃"
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
            }

            Text {
                text: view.sys.tr("Dispositivos de Salida")
                color: view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                    bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                }
            }

            Rectangle {
                visible: view.sys.audioSinks.length > 0
                Layout.preferredHeight: 16
                Layout.preferredWidth: sinkCountText.implicitWidth + 10
                radius: 8
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                Text {
                    id: sinkCountText
                    anchors.centerIn: parent
                    text: String(view.sys.audioSinks.length)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: view.sys.audioSinks

            Rectangle {
                id: dev
                required property var modelData
                readonly property bool active: Pipewire.defaultAudioSink === dev.modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 16
                color: dev.active
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                       : (devMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045))
                border.color: dev.active
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                              : (devMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.16)
                                                     : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07))
                border.width: dev.active ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                scale: devMa.pressed ? 0.985 : ((devMa.containsMouse && view.sys.cfg.animCardLift) ? 1.01 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Squircle del icono de dispositivo
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 12
                        color: dev.active
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                        border.color: dev.active ? view.sys.colOn : "transparent"
                        border.width: dev.active ? 1 : 0
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                var s = String(dev.modelData.name || dev.modelData.description || "").toLowerCase();
                                if (s.indexOf("headphone") >= 0 || s.indexOf("headset") >= 0 || s.indexOf("auricular") >= 0) return "󰋋";
                                if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0) return "󰡁";
                                return "󰓃";
                            }
                            color: dev.active ? view.sys.colOn : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 16 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: String(dev.modelData.nickname || dev.modelData.description || dev.modelData.name || "Salida de Audio")
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam; pixelSize: 13
                                bold: dev.active
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dev.active ? view.sys.tr("Dispositivo predeterminado activo") : view.sys.tr("Hacer clic para activar")
                            color: dev.active ? view.sys.colOn : view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }

                    // Píldora de estado Activo
                    Rectangle {
                        visible: dev.active
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: activeTagText.implicitWidth + 16
                        radius: 12
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                        border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "󰄬"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                            Text {
                                id: activeTagText
                                text: view.sys && view.sys.tr ? view.sys.tr("Activo") : "Activo"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }
                        }
                    }

                    Text {
                        visible: !dev.active
                        text: "󰅂"
                        color: devMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }
                }

                MouseArea {
                    id: devMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.setSink(dev.modelData)
                }
            }
        }

        // Estado vacío para dispositivos
        Rectangle {
            visible: view.sys.audioSinks.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            radius: 14
            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.03)

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰓄"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 20 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.tr("No se detectaron dispositivos de salida")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }

        // ------------------------------------------ Mezclador de Aplicaciones (Streams)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Text {
                text: "󰝚"
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
            }

            Text {
                text: view.sys.tr("Mezclador de Aplicaciones")
                color: view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                    bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                }
            }

            Rectangle {
                visible: view.streamsList.length > 0
                Layout.preferredHeight: 16
                Layout.preferredWidth: streamCountText.implicitWidth + 10
                radius: 8
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)

                Text {
                    id: streamCountText
                    anchors.centerIn: parent
                    text: String(view.streamsList.length)
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: view.streamsList

            Rectangle {
                id: strCard
                required property var modelData
                required property int index

                property int currentVolPct: modelData.volume_pct !== undefined ? modelData.volume_pct : Math.round((modelData.volume || 1.0) * 100)
                property bool isMuted: modelData.muted || false

                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: 16
                color: strMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.075)
                                           : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)
                border.color: strMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.16)
                                                  : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                MouseArea {
                    id: strMa
                    anchors.fill: parent
                    hoverEnabled: true
                }

                ColumnLayout {
                    id: appCol
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 12
                    anchors.bottomMargin: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Icono de la app en squircle
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: strCard.isMuted ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                                   : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: view.getStreamIcon(strCard.modelData.name, strCard.modelData.binary, strCard.modelData.icon)
                                color: strCard.isMuted ? view.sys.colMuted : view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: strCard.modelData.name || strCard.modelData.binary || view.sys.tr("Aplicación")
                                color: strCard.isMuted ? view.sys.colMuted : view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: strCard.isMuted ? "Silenciado" : (strCard.currentVolPct + "% volumen")
                                color: strCard.isMuted ? view.sys.colCrit : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                        }

                        // Botón Silenciar App
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: appMuteMa.containsMouse ? (strCard.isMuted ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.25)
                                                                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12))
                                                           : (strCard.isMuted ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.15)
                                                                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05))
                            border.color: strCard.isMuted ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.35)
                                                          : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            scale: appMuteMa.pressed ? 0.92 : (appMuteMa.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: strCard.isMuted ? "󰖁" : "󰕾"
                                color: strCard.isMuted ? view.sys.colCrit : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                            MouseArea {
                                id: appMuteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    strCard.isMuted = !strCard.isMuted;
                                    view.toggleAppMute(strCard.modelData.id);
                                }
                            }
                        }
                    }

                    // Píldora interactiva para el volumen de la aplicación
                    Item {
                        id: appSl
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22

                        readonly property real pos: Math.max(0, Math.min(1, strCard.currentVolPct / 100))

                        function setFromX(x) {
                            var r = Math.max(0, Math.min(1, x / Math.max(1, width)));
                            var pct = Math.round(r * 100);
                            strCard.currentVolPct = pct;
                            view.setAppVolume(strCard.modelData.id, pct);
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: appDrag.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                                                         : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                            border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                            border.width: 1
                            clip: true
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Rectangle {
                                width: Math.max(parent.height, parent.width * appSl.pos)
                                height: parent.height
                                radius: 11
                                color: strCard.isMuted ? Qt.rgba(view.sys.colMuted.r, view.sys.colMuted.g, view.sys.colMuted.b, 0.25)
                                                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.80)
                                Behavior on width {
                                    enabled: !appDrag.pressed
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            id: appDrag
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => {
                                view.isUserDragging = true;
                                appSl.setFromX(mouse.x);
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    view.isUserDragging = true;
                                    appSl.setFromX(mouse.x);
                                }
                            }
                            onReleased: view.isUserDragging = false
                            onCanceled: view.isUserDragging = false
                            onWheel: wheel => {
                                var delta = wheel.angleDelta.y > 0 ? 5 : -5;
                                var p = Math.max(0, Math.min(100, strCard.currentVolPct + delta));
                                strCard.currentVolPct = p;
                                view.setAppVolume(strCard.modelData.id, p);
                            }
                        }
                    }
                }
            }
        }

        // Estado vacío del mezclador
        Rectangle {
            visible: view.streamsList.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            radius: 16
            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.035)
            border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰝛"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 20 }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.tr("Sin aplicaciones reproduciendo sonido")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.tr("Los reproductores y navegadores aparecerán aquí automáticamente")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
        }
    }
    }
}
