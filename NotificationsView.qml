import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Centro de Notificaciones rediseñado para Panacea Shell.
// Lista unificada de avisos con soporte para No Molestar (DND), filtrado,
// eliminación individual o masiva y navegación táctil/teclado.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ------------------------------------------------------------- Encabezado
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Icono del centro de notificaciones
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                border.width: 1

                Glyph {
                    anchors.centerIn: parent
                    glyph: String.fromCodePoint(0xF009A)
                    color: view.sys.colFg
                    size: 16
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: view.sys.tr("Notificaciones")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }

                // Contador de notificaciones activas
                Rectangle {
                    visible: view.sys.notifications.count > 0
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: Math.max(18, countTxt.implicitWidth + 8)
                    radius: 9
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                    border.color: view.sys.colOn
                    border.width: 1

                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                        text: view.sys.notifications.count
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                    }
                }
            }

            // Botón Modo No Molestar
            Rectangle {
                Layout.preferredWidth: Math.max(136, dndRow.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 12
                color: view.sys.dnd
                       ? Qt.rgba(view.sys.colWarn.r, view.sys.colWarn.g, view.sys.colWarn.b, 0.20)
                       : (dndMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05))
                border.color: view.sys.dnd ? view.sys.colWarn : (dndMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.20) : view.sys.colLine)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                scale: dndMa.pressed ? 0.96 : (dndMa.containsMouse ? 1.025 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 7

                    Glyph {
                        glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                        color: view.sys.dnd ? view.sys.colWarn : view.sys.colMuted
                        size: 14
                    }
                    Text {
                        text: view.sys.dnd ? view.sys.tr("Silenciado") : view.sys.tr("No molestar")
                        color: view.sys.dnd ? view.sys.colWarn : (dndMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: view.sys.dnd }
                    }
                }
                MouseArea {
                    id: dndMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                        view.sys.toggleDnd();
                    }
                }
            }

            // Botón Limpiar Todo
            Rectangle {
                Layout.preferredWidth: 94
                Layout.preferredHeight: 32
                radius: 12
                visible: view.sys.notifications.count > 0
                color: clearMa.containsMouse ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.18) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                border.color: clearMa.containsMouse ? view.sys.colCrit : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                scale: clearMa.pressed ? 0.96 : (clearMa.containsMouse ? 1.025 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Glyph {
                        glyph: String.fromCodePoint(0xF01B4) // delete
                        color: clearMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        size: 13
                    }
                    Text {
                        text: view.sys.tr("Limpiar")
                        color: clearMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: clearMa.containsMouse }
                    }
                }

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                        view.sys.clearNotifications();
                    }
                }
            }
        }

        // ------------------------------------------------------------- Lista de Notificaciones
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            clip: true
            spacing: 8
            model: view.sys.notifications
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000
            visible: view.sys.notifications.count > 0

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property int index
                required property int nId
                required property string nSummary
                required property string nBody
                required property string nApp
                required property string nImage
                required property bool   nUrgent
                required property string nTime

                width: list.width - 8
                x: 4
                height: inner.implicitHeight + 22
                radius: 14
                clip: true

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: rowMa.containsMouse
                               ? (row.nUrgent ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.16)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
                               : (row.nUrgent ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.09)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045))
                    }
                    GradientStop {
                        position: 1.0
                        color: rowMa.containsMouse
                               ? (row.nUrgent ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.10)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05))
                               : (row.nUrgent ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.04)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.025))
                    }
                }

                border.color: row.nUrgent
                              ? (rowMa.containsMouse ? view.sys.colCrit : Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.45))
                              : (rowMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40) : view.sys.colLine)
                border.width: 1

                scale: rowMa.pressed ? 0.985 : ((rowMa.containsMouse && view.sys.cfg.animCardLift) ? 1.010 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                transform: Translate {
                    x: (rowMa.containsMouse && view.sys.cfg.animMenuSlide) ? 2 : 0
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                }

                // Barra de urgencia en el lateral izquierdo
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: row.nUrgent ? 3 : 0
                    color: view.sys.colCrit
                    visible: row.nUrgent
                }

                RowLayout {
                    id: inner
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: row.nUrgent ? 14 : 12
                    anchors.rightMargin: 16
                    spacing: 12

                    // Icono de la aplicación emisora
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignTop
                        radius: 11
                        color: row.nUrgent
                               ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.22)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        border.color: row.nUrgent ? view.sys.colCrit : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                        border.width: 1

                        Image {
                            id: rowIcon
                            anchors.fill: parent
                            anchors.margins: 6
                            source: row.nImage
                            visible: source != "" && status === Image.Ready
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Glyph {
                            anchors.centerIn: parent
                            visible: !rowIcon.visible
                            glyph: String.fromCodePoint(row.nUrgent ? 0xF0026 : 0xF009A)
                            color: row.nUrgent ? view.sys.colCrit : view.sys.colMuted
                            size: 18
                        }
                    }

                    // Contenido textual
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: row.nSummary
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                            }

                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    Layout.preferredHeight: 16
                                    Layout.preferredWidth: appTxt.implicitWidth + 10
                                    radius: 8
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                                    Text {
                                        id: appTxt
                                        anchors.centerIn: parent
                                        text: row.nApp
                                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.60)
                                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                                    }
                                }

                                Text {
                                    text: row.nTime
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35)
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: row.nBody.length > 0
                            text: row.nBody
                            color: view.sys.colMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                        }
                    }

                    // Botón para descartar notificación individual
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignTop
                        radius: 13
                        color: delMa.containsMouse ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.25) : "transparent"
                        border.color: delMa.containsMouse ? view.sys.colCrit : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: delMa.containsMouse ? view.sys.colCrit : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.40)
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1 }
                        }

                        scale: delMa.pressed ? 0.9 : (delMa.containsMouse ? 1.15 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                view.sys.forgetNotification(row.index);
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.playSound) view.sys.playSound("pop");
                        view.sys.activateNotification(row.nId);
                    }
                }
            }
        }

        // ------------------------------------------------------------- Estado Vacío
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 16
            visible: view.sys.notifications.count === 0
            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.03)
            border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 21
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)

                    Glyph {
                        anchors.centerIn: parent
                        glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF012C)
                        color: view.sys.dnd ? view.sys.colWarn : view.sys.colMuted
                        size: 20
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.dnd ? view.sys.tr("Modo No Molestar Activo") : view.sys.tr("Bandeja al día")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.dnd
                          ? view.sys.tr("Las notificaciones emergentes permanecerán silenciadas")
                          : view.sys.tr("No tienes avisos ni notificaciones pendientes")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }
    }
}
