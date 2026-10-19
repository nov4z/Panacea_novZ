import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Portapapeles Nothing OS / Material You (Super+V) - Historial de cliphist con búsqueda y filtros
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    ListModel { id: fullModel }
    ListModel { id: displayModel }
    property string query: ""
    property string currentFilter: "all" // "all", "text", "image"

    // Parseo de cliphist list: "<id>\t<preview>"
    Process {
        id: pList
        command: ["sh", "-c", "cliphist list"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.indexOf("\t");
                if (t < 0) return;
                var id = line.substring(0, t);
                var preview = line.substring(t + 1).trim();
                if (!preview.length) return;
                if (fullModel.count >= 80) return;
                var isImg = preview.indexOf("[[ binary data") >= 0;
                fullModel.append({
                    cid: id,
                    preview: preview,
                    isImage: isImg
                });
                view.applyFilter();
            }
        }
    }

    Process { id: pCopy }
    Process { id: pWipe; command: ["sh", "-c", "cliphist wipe"] }

    function reload() {
        fullModel.clear();
        displayModel.clear();
        list.currentIndex = 0;
        pList.running = false;
        pList.running = true;
    }

    function applyFilter() {
        displayModel.clear();
        var q = view.query.toLowerCase().trim();
        for (var i = 0; i < fullModel.count; i++) {
            var item = fullModel.get(i);
            if (view.currentFilter === "text" && item.isImage) continue;
            if (view.currentFilter === "image" && !item.isImage) continue;
            if (q.length > 0 && item.preview.toLowerCase().indexOf(q) < 0) continue;
            displayModel.append({
                cid: item.cid,
                preview: item.preview,
                isImage: item.isImage,
                origIndex: i + 1
            });
        }
        if (list.currentIndex >= displayModel.count) {
            list.currentIndex = Math.max(0, displayModel.count - 1);
        }
    }

    function copyAt(i) {
        if (i < 0 || i >= displayModel.count) return;
        var id = displayModel.get(i).cid;
        pCopy.command = ["sh", "-c",
            "printf \x27%s\\t\x27 \"$1\" | cliphist decode | wl-copy", "_", id];
        pCopy.running = true;
        view.sys.collapse();
    }

    Component.onCompleted: view.reload()
    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ------------------------------------------------------- Cabecera
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰅍"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: view.sys.tr("Portapapeles")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                }

                Text {
                    text: displayModel.count + " " + (displayModel.count === 1 ? "elemento" : "elementos")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            // Acceso a Vault
            Rectangle {
                visible: view.sys.cfg.featVault
                Layout.preferredHeight: 28
                Layout.preferredWidth: 28
                radius: 10
                color: vaultMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                                             : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                border.color: view.sys.vaultUnlocked ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.4)
                                                     : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.width: 1
                scale: vaultMa.pressed ? 0.92 : (vaultMa.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(view.sys.vaultUnlocked ? 0xF0FC6 : 0xF033E)
                    color: view.sys.vaultUnlocked ? view.sys.colOk : (vaultMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                    font { family: view.sys.fontFam; pixelSize: 14 }
                }
                MouseArea {
                    id: vaultMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.togglePage("vault")
                }
            }

            // Limpiar historial
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: wipeTextRow.implicitWidth + 14
                radius: 10
                color: wipeMa.containsMouse ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.18)
                                            : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                border.color: wipeMa.containsMouse ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.40)
                                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }
                scale: wipeMa.pressed ? 0.94 : (wipeMa.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120 } }

                RowLayout {
                    id: wipeTextRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰩹"
                        color: wipeMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 13 }
                    }
                    Text {
                        text: view.sys.tr("Limpiar")
                        color: wipeMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                    }
                }

                MouseArea {
                    id: wipeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pWipe.running = true; view.reload(); }
                }
            }

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: escBadgeText.implicitWidth + 14
                radius: 12
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                border.width: 1

                Text {
                    id: escBadgeText
                    anchors.centerIn: parent
                    text: "ESC"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true; letterSpacing: 0.5 }
                }
            }
        }

        // ------------------------------------------------------- Campo de Búsqueda
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 14
            color: input.activeFocus ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                     : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)
            border.color: input.activeFocus ? view.sys.colOn
                                            : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
            border.width: input.activeFocus ? 1.5 : 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 10

                Text {
                    text: "󰍉"
                    color: input.activeFocus ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 17 }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextField {
                    id: input
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.sys.tr("Buscar en el portapapeles...")
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 13 }
                    background: null
                    onTextEdited: {
                        view.query = text;
                        view.applyFilter();
                    }

                    Keys.onEscapePressed: view.sys.collapse()
                    Keys.onReturnPressed: view.copyAt(list.currentIndex)
                    Keys.onDownPressed: if (list.currentIndex < displayModel.count - 1) list.currentIndex++
                    Keys.onUpPressed: if (list.currentIndex > 0) list.currentIndex--
                }

                // Botón borrar texto
                Rectangle {
                    visible: input.text.length > 0
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: clearMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.15)
                                                 : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: view.sys.colMuted
                        font { pixelSize: 10; bold: true }
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            input.text = "";
                            view.query = "";
                            view.applyFilter();
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------- Chips de Filtro
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { id: "all",   label: "Todos",    icon: "󰅍" },
                    { id: "text",  label: "Texto",    icon: "󰈙" },
                    { id: "image", label: "Imágenes", icon: "󰋩" }
                ]

                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: view.currentFilter === chip.modelData.id

                    Layout.preferredHeight: 26
                    Layout.preferredWidth: chipRow.implicitWidth + 16
                    radius: 13
                    color: chip.active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                       : (chipMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04))
                    border.color: chip.active ? view.sys.colOn : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                    border.width: chip.active ? 1.5 : 1
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: chip.modelData.icon
                            color: chip.active ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                        Text {
                            text: chip.modelData.label
                            color: chip.active ? view.sys.colOn : (chipMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                            font { family: view.sys.fontFam; pixelSize: 11; bold: chip.active }
                        }
                    }

                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.currentFilter = chip.modelData.id;
                            view.applyFilter();
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ------------------------------------------------------- Lista de Elementos
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 330)
            clip: true
            model: displayModel
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000
            maximumFlickVelocity: 2600

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 3; color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.22) }
            }

            delegate: Rectangle {
                id: itemCard
                required property string cid
                required property string preview
                required property bool isImage
                required property int origIndex
                required property int index
                readonly property bool isSelected: index === list.currentIndex

                width: list.width - 8
                x: 4
                height: 48
                radius: 14
                color: itemCard.isSelected
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14)
                       : (rowMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.035))
                border.color: itemCard.isSelected
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                              : (rowMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14)
                                                     : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06))
                border.width: itemCard.isSelected ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                scale: rowMa.pressed ? 0.985 : ((rowMa.containsMouse && view.sys.cfg.animCardLift) ? 1.010 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                transform: Translate {
                    x: ((rowMa.containsMouse || itemCard.isSelected) && view.sys.cfg.animMenuSlide) ? 2 : 0
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 16
                    spacing: 11

                    // Squircle del tipo de elemento
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: itemCard.isImage
                               ? Qt.rgba(0.7, 0.4, 0.9, 0.18)
                               : (itemCard.isSelected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                                      : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07))
                        border.color: itemCard.isImage ? Qt.rgba(0.7, 0.4, 0.9, 0.35) : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: itemCard.isImage ? "󰋩" : "󰈙"
                            color: itemCard.isImage ? "#d8b4fe" : (itemCard.isSelected ? view.sys.colOn : view.sys.colFg)
                            font { family: view.sys.fontFam; pixelSize: 15 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: itemCard.isImage ? view.sys.tr("Imagen binaria copiada") : itemCard.preview
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: itemCard.isImage ? view.sys.fontFam : view.sys.fontMono
                                pixelSize: 12
                                bold: itemCard.isSelected
                            }
                        }

                        Text {
                            text: itemCard.isImage ? "Datos de imagen" : (itemCard.preview.length + " caracteres")
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }

                    // Píldora de acción [󰌑 Copiar] cuando está seleccionado
                    Rectangle {
                        visible: itemCard.isSelected || rowMa.containsMouse
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: enterRow.implicitWidth + 14
                        radius: 8
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                        border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                        border.width: 1

                        RowLayout {
                            id: enterRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: 4
                                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14)
                                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌑"
                                    color: view.sys.colOn
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                            }

                            Text {
                                text: view.sys.tr("Copiar")
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }
                        }
                    }

                    Text {
                        visible: !itemCard.isSelected && !rowMa.containsMouse
                        text: "#" + itemCard.origIndex
                        color: Qt.rgba(view.sys.colMuted.r, view.sys.colMuted.g, view.sys.colMuted.b, 0.6)
                        font { family: view.sys.fontFam; pixelSize: 10 }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = index
                    onClicked: view.copyAt(index)
                }
            }
        }

        // ------------------------------------------------------- Estado Vacío
        Rectangle {
            visible: displayModel.count === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            radius: 16
            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.035)
            border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰅍"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 22 }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.query.length ? view.sys.tr("No se encontraron coincidencias") : view.sys.tr("El portapapeles está vacío")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.query.length ? view.sys.tr("Intenta con otro término o limpia los filtros") : view.sys.tr("El contenido que copies aparecerá aquí automáticamente")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }
    }
}
