import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Menú de Energía y Sesión (Super+N / Ctrl+Alt+Del) en estilo Panacea / Material Design 3.
// Primer toque selecciona / arma la acción, segundo toque confirma para evitar apagados accidentales.
// Escape cancela y cierra el menú.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property int armed: -1          // índice de la acción esperando confirmación
    property int current: 0

    Timer {
        id: disarm
        interval: 2600
        onTriggered: view.armed = -1
    }

    readonly property var actions: view.sys.cfg.featLock ? view.allActions
                                 : view.allActions.filter(a => a.id !== "lock")
    readonly property var allActions: [
        {
            id: "sleep",
            icon: "",
            label: view.sys.tr("Suspender"),
            cmd: "systemctl suspend",
            accent: view.sys.tint("#38bdf8"),
            hint: view.sys.tr("Suspender en RAM")
        },
        {
            id: "logout",
            icon: String.fromCodePoint(0xF0343),
            label: view.sys.tr("Cerrar sesión"),
            cmd: "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then "
               + "niri msg action quit --skip-confirmation; "
               + "else out=$(hyprctl dispatch 'hl.dsp.exit()' 2>&1); case \"$out\" in ok*) ;; *) hyprctl dispatch exit ;; esac; fi",
            accent: view.sys.tint("#fbbf24"),
            hint: view.sys.tr("Cerrar sesión activa")
        },
        {
            id: "reboot",
            icon: String.fromCodePoint(0xF0709),
            label: view.sys.tr("Reiniciar"),
            cmd: "systemctl reboot",
            accent: view.sys.tint("#fb923c"),
            hint: view.sys.tr("Reiniciar sistema")
        },
        {
            id: "poweroff",
            icon: String.fromCodePoint(0xF0425),
            label: view.sys.tr("Apagar"),
            cmd: "systemctl poweroff",
            accent: view.sys.tint("#f43f5e"),
            hint: view.sys.tr("Apagar el equipo")
        }
    ]

    function trigger(i) {
        if (i < 0 || i >= actions.length) return;
        if (!actions[i].instant && view.armed !== i) {
            view.armed = i;
            view.current = i;
            if (view.sys && view.sys.playSound) view.sys.playSound("pop");
            disarm.restart();
            return;
        }
        disarm.stop();
        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
        view.sys.runDetached(actions[i].cmd);
        view.sys.collapse();
    }

    focus: true
    Keys.onEscapePressed: view.sys.collapse()
    Keys.onReturnPressed: trigger(current)
    Keys.onLeftPressed:  { if (current > 0) { current--; armed = -1; } }
    Keys.onRightPressed: { if (current < actions.length - 1) { current++; armed = -1; } }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        transform: Translate {
            id: powerTrans
            y: 0
        }
        Component.onCompleted: {
            powerTrans.y = 8;
            powerTransAnim.start();
        }
        NumberAnimation {
            id: powerTransAnim
            target: powerTrans
            property: "y"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }

        // ------------------------------------------------------------- Encabezado estilizado
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: view.armed >= 0
                       ? Qt.rgba(view.actions[view.armed].accent.r, view.actions[view.armed].accent.g, view.actions[view.armed].accent.b, 0.22)
                       : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.color: view.armed >= 0
                              ? view.actions[view.armed].accent
                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Glyph {
                    anchors.centerIn: parent
                    glyph: String.fromCodePoint(view.armed >= 0 ? 0xF0026 : 0xF0425)
                    color: view.armed >= 0 ? view.actions[view.armed].accent : view.sys.colFg
                    size: 16
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: view.armed >= 0
                          ? view.sys.tr("Confirmación: Presiona de nuevo para ") + view.actions[view.armed].label.toLowerCase()
                          : view.sys.tr("Opciones de Energía")
                    color: view.armed >= 0 ? view.actions[view.armed].accent : view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.armed >= 0
                          ? view.sys.tr("Se cancelará automáticamente en unos segundos si no confirmas")
                          : view.sys.tr("Selecciona una acción para continuar")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
            }

            // Indicador de cancelación rápida
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: escRow.implicitWidth + 14
                radius: 12
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                border.width: 1

                RowLayout {
                    id: escRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "ESC"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                    }
                    Text {
                        text: view.sys.tr("cerrar")
                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.40)
                        font { family: view.sys.fontFam; pixelSize: 9 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.collapse()
                }
            }
        }

        // ------------------------------------------------------------- Tarjetas de Acción
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: view.actions

                Rectangle {
                    id: card
                    required property int index
                    required property var modelData

                    readonly property bool isArmed: view.armed === index
                    readonly property bool isCurrent: view.current === index
                    readonly property color accentColor: modelData.accent

                    Layout.fillWidth: true
                    Layout.preferredHeight: 126
                    radius: 18
                    clip: true

                    // Fondo degradado sutil
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: card.isArmed
                                   ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.28)
                                   : ((btnMa.containsMouse || card.isCurrent)
                                      ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.15)
                                      : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05))
                        }
                        GradientStop {
                            position: 1.0
                            color: card.isArmed
                                   ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.18)
                                   : ((btnMa.containsMouse || card.isCurrent)
                                      ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                      : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.025))
                        }
                    }

                    border.color: card.isArmed
                                  ? card.accentColor
                                  : ((btnMa.containsMouse || card.isCurrent)
                                     ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.45)
                                     : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
                    border.width: card.isArmed ? 1.5 : 1

                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    scale: btnMa.pressed ? 0.96 : ((btnMa.containsMouse || card.isCurrent) && view.sys.cfg.animCardLift !== false ? 1.035 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    onIsCurrentChanged: if (isCurrent && modelData.id === "reboot" && view.sys.cfg.animPowerIcons !== false) rebootSpin.restart()

                    // Barra de progreso de cuenta regresiva cuando está armado
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        visible: card.isArmed
                        color: card.accentColor

                        NumberAnimation on width {
                            id: armProgressAnim
                            running: card.isArmed
                            from: card.width
                            to: 0
                            duration: 2600
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Contenedor de icono estilizado
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 14
                            color: card.isArmed
                                   ? card.accentColor
                                   : ((btnMa.containsMouse || card.isCurrent)
                                      ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.22)
                                      : Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.12))
                            border.color: (btnMa.containsMouse || card.isCurrent || card.isArmed)
                                          ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.50)
                                          : Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.20)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            readonly property color glyphInk: card.isArmed ? "#000000" : card.accentColor

                            // Animación de sueño Zzz
                            Item {
                                anchors.fill: parent
                                visible: modelData.id === "sleep"

                                Text {
                                    x: 10; y: 19
                                    text: "Z"
                                    color: parent.parent.glyphInk
                                    font { family: view.sys.fontBody; pixelSize: 18; bold: true }
                                }
                                Text {
                                    x: 23
                                    y: ((btnMa.containsMouse || card.isCurrent) && view.sys.cfg.animPowerIcons !== false) ? 5 : 8
                                    text: "z"
                                    color: parent.parent.glyphInk
                                    font { family: view.sys.fontBody; pixelSize: 10; bold: true }
                                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                }
                                Text {
                                    x: 29; y: 13
                                    text: "z"
                                    color: parent.parent.glyphInk
                                    font { family: view.sys.fontBody; pixelSize: 13; bold: true }
                                }
                            }

                            // Icono estándar
                            Glyph {
                                id: iconGlyph
                                anchors.centerIn: parent
                                visible: modelData.id !== "sleep"
                                glyph: modelData.icon
                                color: parent.glyphInk
                                size: 22
                                transformOrigin: Item.Center

                                scale: ((btnMa.containsMouse || card.isCurrent) && view.sys.cfg.animPowerIcons !== false && modelData.id === "poweroff") ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }

                            NumberAnimation {
                                id: rebootSpin
                                target: iconGlyph
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 520
                                easing.type: Easing.OutCubic
                                onFinished: iconGlyph.rotation = 0
                            }
                        }

                        // Etiqueta y texto de confirmación
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                color: card.isArmed ? card.accentColor : ((btnMa.containsMouse || card.isCurrent) ? view.sys.colFg : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.90))
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 2
                                    bold: true
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: card.isArmed ? view.sys.tr("CONFIRMAR") : modelData.hint
                                color: card.isArmed ? card.accentColor : view.sys.colMuted
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: card.isArmed ? 10 : 9
                                    bold: card.isArmed
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            view.current = index;
                            view.forceActiveFocus();
                            if (modelData.id === "reboot" && view.sys.cfg.animPowerIcons !== false) {
                                rebootSpin.restart();
                            }
                        }
                        onClicked: view.trigger(index)
                    }
                }
            }
        }

        // ------------------------------------------------------------- Atajos de teclado en el pie
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 6
                Rectangle {
                    width: 18; height: 16; radius: 4
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                    Text { anchors.centerIn: parent; text: "←"; color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                }
                Rectangle {
                    width: 18; height: 16; radius: 4
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                    Text { anchors.centerIn: parent; text: "→"; color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                }
                Text { text: view.sys.tr("navegar"); color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35); font { family: view.sys.fontFam; pixelSize: 9 } }
            }

            RowLayout {
                spacing: 6
                Rectangle {
                    width: 26; height: 16; radius: 4
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                    Text { anchors.centerIn: parent; text: "↵"; color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 10 } }
                }
                Text { text: view.sys.tr("ejecutar"); color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35); font { family: view.sys.fontFam; pixelSize: 9 } }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
