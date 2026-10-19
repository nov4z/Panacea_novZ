import QtQuick
import QtQuick.Layouts

// SetColor. Selector de color para las páginas de configuración de Panacea.
// Permite elegir entre una amplia gama de colores preestablecidos por familias
// cromáticas o escribir cualquier código hexadecimal (#RRGGBB / #RRGGBBAA).
// Con previsualización en vivo, selección inmediata y botón de restauración.
ColumnLayout {
    id: colPick

    property var sys
    property string label: ""
    property string sub: ""
    property string value: "#3b82f6"
    property string defaultColor: ""
    property var presets: [
        "#30D158", "#22c55e", "#10b981", "#84cc16", // Verdes & Limas
        "#06b6d4", "#0ea5e9", "#3b82f6", "#2563eb", // Cyans & Azules
        "#6366f1", "#8b5cf6", "#a855f7", "#ec4899", // Índigos & Violetas
        "#ff453a", "#ef4444", "#ff9f0a", "#f59e0b", // Rojos, Naranjas & Ámbar
        "#ffffff", "#94a3b8"                         // Neutros
    ]

    signal picked(string hex)

    function selectColor(hex) {
        if (!hex || typeof hex !== "string") return;
        var h = hex.trim();
        if (!h.startsWith("#")) h = "#" + h;
        colPick.value = h;
        if (hexInput && hexInput.text.toLowerCase() !== h.toLowerCase()) {
            hexInput.text = h;
        }
        colPick.picked(h);
    }

    onValueChanged: {
        if (hexInput && (hexInput.text.toLowerCase() !== (colPick.value || "").toLowerCase())) {
            hexInput.text = colPick.value || "";
        }
    }

    Layout.fillWidth: true
    spacing: 8

    // -------------------------------------------------- Cabecera con vista previa y reset
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: colPick.label
                color: colPick.sys.colFg
                font { family: colPick.sys.fontBody; pixelSize: colPick.sys.fontSize - 1; bold: true }
            }

            Text {
                visible: colPick.sub.length > 0
                text: colPick.sub
                color: colPick.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: colPick.sys.fontBody; pixelSize: colPick.sys.fontSize - 4 }
            }
        }

        // Botón Restaurar por defecto
        Rectangle {
            visible: colPick.defaultColor.length > 0 && (colPick.value || "").toLowerCase() !== colPick.defaultColor.toLowerCase()
            Layout.preferredHeight: 28
            Layout.preferredWidth: rstRow.implicitWidth + 18
            radius: 8
            color: rstMa.containsMouse ? Qt.rgba(colPick.sys.colFg.r, colPick.sys.colFg.g, colPick.sys.colFg.b, 0.14)
                                       : Qt.rgba(colPick.sys.colFg.r, colPick.sys.colFg.g, colPick.sys.colFg.b, 0.07)
            border.color: rstMa.containsMouse ? colPick.sys.colOn : Qt.rgba(colPick.sys.colFg.r, colPick.sys.colFg.g, colPick.sys.colFg.b, 0.18)
            border.width: 1

            RowLayout {
                id: rstRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "↺"
                    color: rstMa.containsMouse ? colPick.sys.colOn : colPick.sys.colMuted
                    font { family: colPick.sys.fontBody; pixelSize: 11; bold: true }
                }
                Text {
                    text: colPick.sys.tr("Por defecto")
                    color: rstMa.containsMouse ? colPick.sys.colFg : colPick.sys.colMuted
                    font { family: colPick.sys.fontBody; pixelSize: colPick.sys.fontSize - 4 }
                }
            }

            MouseArea {
                id: rstMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: colPick.selectColor(colPick.defaultColor)
            }
        }

        // Muestra de color actual con preview animado
        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 10
            color: colPick.value || "#ffffff"
            border.color: Qt.rgba(colPick.sys.colFg.r, colPick.sys.colFg.g, colPick.sys.colFg.b, 0.35)
            border.width: 1.5

            Behavior on color { ColorAnimation { duration: 150 } }

            // Borde interior sutil
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 4
                height: parent.height - 4
                radius: 8
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.25)
                border.width: 1
            }
        }
    }

    // -------------------------------------------------- Presets y gamas de colores
    Flow {
        Layout.fillWidth: true
        width: parent ? parent.width : undefined
        spacing: 7

        Repeater {
            model: colPick.presets

            Rectangle {
                id: chip
                required property string modelData
                readonly property bool active: (colPick.value || "").toLowerCase() === chip.modelData.toLowerCase()

                width: 26
                height: 26
                radius: 13
                color: chip.modelData
                scale: chipMa.containsMouse ? 1.22 : (chip.active ? 1.10 : 1.0)
                border.color: chip.active ? colPick.sys.colFg : Qt.rgba(0, 0, 0, 0.45)
                border.width: chip.active ? 2.5 : 1

                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on border.width { NumberAnimation { duration: 120 } }

                // Punto central si está seleccionado
                Rectangle {
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    radius: 3.5
                    visible: chip.active
                    color: {
                        var c = Qt.color(chip.modelData);
                        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6 ? "#000000" : "#ffffff";
                    }
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: colPick.selectColor(chip.modelData)
                }
            }
        }
    }

    // -------------------------------------------------- Entrada Hex manual
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 140
            Layout.preferredHeight: 30
            radius: 8
            color: Qt.rgba(colPick.sys.colFg.r, colPick.sys.colFg.g, colPick.sys.colFg.b, 0.07)
            border.color: hexInput.activeFocus ? colPick.sys.colOn : Qt.rgba(colPick.sys.colFg.r, colPick.sys.colFg.g, colPick.sys.colFg.b, 0.15)
            border.width: 1

            TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                text: colPick.value || ""
                color: colPick.sys.colFg
                font { family: colPick.sys.fontBody; pixelSize: colPick.sys.fontSize - 2 }
                selectByMouse: true
                maximumLength: 9

                onTextChanged: {
                    var t = text.trim();
                    if (/^#[0-9a-fA-F]{6}$/.test(t) || /^#[0-9a-fA-F]{8}$/.test(t)) {
                        if ((colPick.value || "").toLowerCase() !== t.toLowerCase()) {
                            colPick.value = t;
                            colPick.picked(t);
                        }
                    }
                }
                onAccepted: {
                    var t = text.trim();
                    if (!t.startsWith("#")) t = "#" + t;
                    if (/^#[0-9a-fA-F]{6}$/.test(t) || /^#[0-9a-fA-F]{8}$/.test(t)) {
                        colPick.selectColor(t);
                    }
                }
            }
        }

        Text {
            text: colPick.sys.tr("Hexadecimal (#RRGGBB)")
            color: colPick.sys.colMuted
            font { family: colPick.sys.fontBody; pixelSize: colPick.sys.fontSize - 4 }
        }

        Item { Layout.fillWidth: true }
    }
}
