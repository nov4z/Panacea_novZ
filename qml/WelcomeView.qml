import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Ventana de Bienvenida e Introducción para Panacea_novZ.
// Se muestra en la primera instalación (o tras una reinstalación limpia)
// y presenta de forma cálida, elegante e interactiva las modificaciones
// y características más innovadoras de esta edición.
Item {
    id: view

    property var sys
    property string reinstallBanner: ""
    property bool reinstallIsError: false

    anchors.fill: parent

    // Clic fuera de la tarjeta cierra la ventana
    MouseArea {
        anchors.fill: parent
        onClicked: view.sys.dismissWelcome()
    }

    // Fondo atenuado de contraste cinemático
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)
        Behavior on opacity { NumberAnimation { duration: view.sys.animFade } }
    }

    // Tarjeta modal central unibody
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(860, parent.width - 40)
        height: Math.min(740, parent.height - 40)
        radius: 24
        color: view.sys.colBg
        border.width: 1
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14)

        // Evitar que los clics dentro de la tarjeta la cierren
        MouseArea {
            anchors.fill: parent
        }

        // Animación de entrada suave (fade + deslizamiento vertical sutil)
        opacity: 0
        transform: Translate { id: rise; y: 20 }
        Component.onCompleted: { card.opacity = 1; rise.y = 0; }
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }
        Behavior on transform { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            // ---------------------------------------------------- Encabezado
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    width: 56
                    height: 56
                    radius: 16
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28)

                    Image {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl("assets/logo-128.png")
                        sourceSize.width: 40
                        sourceSize.height: 40
                        fillMode: Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            height: 20
                            radius: 6
                            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                            implicitWidth: badgeText.implicitWidth + 12

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: "V:NOVZ · PANACEA SHELL"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }
                        }

                        Text {
                            text: "· " + view.sys.tr("Gracias por instalar")
                            color: view.sys.colMuted
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: view.sys.tr("¡Bienvenido a Panacea novZ!")
                        color: view.sys.colFg
                        font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 7; bold: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: view.sys.tr("Una experiencia de escritorio cinemática, reactiva y pulida al milímetro.")
                        color: view.sys.colMuted
                        elide: Text.ElideRight
                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                    }
                }

                // Botón cerrar (X)
                Rectangle {
                    width: 32
                    height: 32
                    radius: 10
                    color: closeMa.containsMouse
                           ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14)
                           : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                    Glyph {
                        anchors.centerIn: parent
                        glyph: String.fromCodePoint(0xF0156) // md-close
                        color: closeMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: 15
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.dismissWelcome()
                    }
                }
            }

            // -------------------------------- Banner de Estado de Reinstalación
            Rectangle {
                id: reinstallBannerBox
                visible: view.reinstallBanner.length > 0
                Layout.fillWidth: true
                radius: 12
                color: view.reinstallIsError
                       ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.15)
                       : Qt.rgba(view.sys.colCharge.r, view.sys.colCharge.g, view.sys.colCharge.b, 0.15)
                border.width: 1
                border.color: view.reinstallIsError ? view.sys.colCrit : view.sys.colCharge
                implicitHeight: bannerRow.implicitHeight + 16

                RowLayout {
                    id: bannerRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 14
                    }
                    spacing: 10

                    Glyph {
                        glyph: view.reinstallIsError
                               ? String.fromCodePoint(0xF0026) // md-alert
                               : String.fromCodePoint(0xF0054) // md-check
                        color: view.reinstallIsError ? view.sys.colCrit : view.sys.colCharge
                        fontFam: view.sys.fontFam
                        size: 16
                    }

                    Text {
                        Layout.fillWidth: true
                        text: view.reinstallBanner
                        color: view.sys.colFg
                        wrapMode: Text.WordWrap
                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2; bold: true }
                    }
                }
            }

            // -------------------------------- Área Desplazable de Características
            Flickable {
                id: scrollArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: featuresLayout.implicitHeight + 10
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: SetScroll { sys: view.sys }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, scrollArea.contentHeight - scrollArea.height);
                        scrollArea.contentY = Math.max(0, Math.min(max, scrollArea.contentY - d));
                    }
                }

                ColumnLayout {
                    id: featuresLayout
                    width: scrollArea.width
                    spacing: 12

                    // Fila 1: SpicyLyrics & BPM Sync
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Tarjeta 1: Motor SpicyLyrics
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: colCard1.implicitHeight + 24
                            radius: 16
                            color: c1Ma.containsMouse
                                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04)
                            border.width: 1
                            border.color: c1Ma.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                id: colCard1
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                        Glyph {
                                            anchors.centerIn: parent
                                            glyph: String.fromCodePoint(0xF0387) // md-music-note
                                            color: view.sys.colOn
                                            fontFam: view.sys.fontFam
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: view.sys.tr("Motor SpicyLyrics")
                                            color: view.sys.colFg
                                            font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize - 1; bold: true }
                                        }

                                        Text {
                                            text: view.sys.tr("60 FPS · 50ms")
                                            color: view.sys.colOn
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.sys.tr("Letras cinemáticas a 60 FPS con anticipación acústica de 50ms y destello armónico (harmonic shimmer).")
                                    color: view.sys.colMuted
                                    wrapMode: Text.WordWrap
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: ["60 FPS", "50ms Lead", "Shimmer"]
                                        Rectangle {
                                            height: 18
                                            radius: 5
                                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                            implicitWidth: tagT1.implicitWidth + 8
                                            Text {
                                                id: tagT1
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea { id: c1Ma; anchors.fill: parent; hoverEnabled: true }
                        }

                        // Tarjeta 2: Sincronización BPM y Tempo
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: colCard2.implicitHeight + 24
                            radius: 16
                            color: c2Ma.containsMouse
                                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04)
                            border.width: 1
                            border.color: c2Ma.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                id: colCard2
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                        Glyph {
                                            anchors.centerIn: parent
                                            glyph: String.fromCodePoint(0xF04D2) // md-speedometer
                                            color: view.sys.colOn
                                            fontFam: view.sys.fontFam
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: view.sys.tr("Sincronización BPM y Tempo")
                                            color: view.sys.colFg
                                            font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize - 1; bold: true }
                                        }

                                        Text {
                                            text: view.sys.tr("Super + M · Super + Z")
                                            color: view.sys.colOn
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.sys.tr("Botón flotante accesible con micro-ajustes acústicos de tempo y modulación dinámica.")
                                    color: view.sys.colMuted
                                    wrapMode: Text.WordWrap
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: ["Super+M", "Super+Z", "BPM Micro-sync"]
                                        Rectangle {
                                            height: 18
                                            radius: 5
                                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                            implicitWidth: tagT2.implicitWidth + 8
                                            Text {
                                                id: tagT2
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea { id: c2Ma; anchors.fill: parent; hoverEnabled: true }
                        }
                    }

                    // Fila 2: Dark Unibody & Estudio Acústico
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Tarjeta 3: Diseño Dark Unibody & Modo Radiante B&W
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: colCard3.implicitHeight + 24
                            radius: 16
                            color: c3Ma.containsMouse
                                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04)
                            border.width: 1
                            border.color: c3Ma.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                id: colCard3
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                        Glyph {
                                            anchors.centerIn: parent
                                            glyph: String.fromCodePoint(0xF03D8) // md-palette
                                            color: view.sys.colOn
                                            fontFam: view.sys.fontFam
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: view.sys.tr("Diseño Dark Unibody & Modo Radiante")
                                            color: view.sys.colFg
                                            font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize - 1; bold: true }
                                        }

                                        Text {
                                            text: view.sys.tr("Dark Unibody · Radiante B&W")
                                            color: view.sys.colOn
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.sys.tr("Estética satinada continua, esquinas pulidas y onda de audio radiante blanca para carátulas monocromáticas.")
                                    color: view.sys.colMuted
                                    wrapMode: Text.WordWrap
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: ["Satinado", "Onda Radiante", "Unibody"]
                                        Rectangle {
                                            height: 18
                                            radius: 5
                                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                            implicitWidth: tagT3.implicitWidth + 8
                                            Text {
                                                id: tagT3
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea { id: c3Ma; anchors.fill: parent; hoverEnabled: true }
                        }

                        // Tarjeta 4: Estudio Acústico Desacoplado
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: colCard4.implicitHeight + 24
                            radius: 16
                            color: c4Ma.containsMouse
                                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04)
                            border.width: 1
                            border.color: c4Ma.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                id: colCard4
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                        Glyph {
                                            anchors.centerIn: parent
                                            glyph: String.fromCodePoint(0xF057E) // md-volume-high
                                            color: view.sys.colOn
                                            fontFam: view.sys.fontFam
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: view.sys.tr("Estudio Acústico Desacoplado")
                                            color: view.sys.colFg
                                            font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize - 1; bold: true }
                                        }

                                        Text {
                                            text: view.sys.tr("7 Packs Hápticos")
                                            color: view.sys.colOn
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.sys.tr("7 paquetes de sonido háptico con separación matemática de Spatial Width y Room Reverb.")
                                    color: view.sys.colMuted
                                    wrapMode: Text.WordWrap
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: ["7 Sound Packs", "Spatial Width", "Room Reverb"]
                                        Rectangle {
                                            height: 18
                                            radius: 5
                                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                            implicitWidth: tagT4.implicitWidth + 8
                                            Text {
                                                id: tagT4
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea { id: c4Ma; anchors.fill: parent; hoverEnabled: true }
                        }
                    }

                    // Fila 3: Localización en Tiempo Real & Soporte Universal
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Tarjeta 5: Localización Completa en Tiempo Real
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: colCard5.implicitHeight + 24
                            radius: 16
                            color: c5Ma.containsMouse
                                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04)
                            border.width: 1
                            border.color: c5Ma.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                id: colCard5
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                        Glyph {
                                            anchors.centerIn: parent
                                            glyph: String.fromCodePoint(0xF05CA) // md-translate
                                            color: view.sys.colOn
                                            fontFam: view.sys.fontFam
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: view.sys.tr("Localización en Tiempo Real")
                                            color: view.sys.colFg
                                            font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize - 1; bold: true }
                                        }

                                        Text {
                                            text: view.sys.tr("ES · EN · RU")
                                            color: view.sys.colOn
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.sys.tr("Español, Inglés y Ruso sin necesidad de reiniciar la sesión, además de configuración de teclado desde el menú.")
                                    color: view.sys.colMuted
                                    wrapMode: Text.WordWrap
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: ["Español Nativo", "Zero-Restart", "Teclado"]
                                        Rectangle {
                                            height: 18
                                            radius: 5
                                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                            implicitWidth: tagT5.implicitWidth + 8
                                            Text {
                                                id: tagT5
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea { id: c5Ma; anchors.fill: parent; hoverEnabled: true }
                        }

                        // Tarjeta 6: Soporte Universal de Hardware y Reinstalación Limpia
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: colCard6.implicitHeight + 24
                            radius: 16
                            color: c6Ma.containsMouse
                                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04)
                            border.width: 1
                            border.color: c6Ma.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                id: colCard6
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 14
                                }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 10
                                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                        Glyph {
                                            anchors.centerIn: parent
                                            glyph: String.fromCodePoint(0xF0450) // md-refresh
                                            color: view.sys.colOn
                                            fontFam: view.sys.fontFam
                                            size: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: view.sys.tr("Soporte Universal & Reinstalación Limpia")
                                            color: view.sys.colFg
                                            font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize - 1; bold: true }
                                        }

                                        Text {
                                            text: view.sys.tr("Universal Linux · GitHub")
                                            color: view.sys.colOn
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.sys.tr("Adaptado a cualquier distribución Linux y hardware, con actualizador directo desde GitHub y reinstalación limpia en 2 pasos.")
                                    color: view.sys.colMuted
                                    wrapMode: Text.WordWrap
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: ["Universal Linux", "GitHub Sync", "2 Pasos Seguros"]
                                        Rectangle {
                                            height: 18
                                            radius: 5
                                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                                            implicitWidth: tagT6.implicitWidth + 8
                                            Text {
                                                id: tagT6
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9 }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea { id: c6Ma; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }
            }

            // ---------------------------------------------------- Barra Inferior / Acciones
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: view.sys.tr("Presiona Esc o Enter para continuar")
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }

                Item { Layout.fillWidth: true }

                // Botón secundario: Abrir Ajustes
                Rectangle {
                    Layout.preferredWidth: Math.max(120, settingsRow.implicitWidth + 24)
                    Layout.preferredHeight: 38
                    radius: 12
                    color: setMa.containsMouse
                           ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14)
                           : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                    RowLayout {
                        id: settingsRow
                        anchors.centerIn: parent
                        spacing: 6

                        Glyph {
                            glyph: String.fromCodePoint(0xF0493) // md-cog / settings
                            color: view.sys.colMuted
                            fontFam: view.sys.fontFam
                            size: 13
                        }

                        Text {
                            text: view.sys.tr("Abrir Ajustes")
                            color: view.sys.colMuted
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                        }
                    }

                    MouseArea {
                        id: setMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.sys.dismissWelcome();
                            view.sys.togglePage("settings");
                        }
                    }
                }

                // Botón principal llamativo: Comenzar a explorar
                Rectangle {
                    id: startBtn
                    Layout.preferredWidth: Math.max(160, startRow.implicitWidth + 32)
                    Layout.preferredHeight: 38
                    radius: 12
                    color: startMa.containsMouse
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.90)
                           : view.sys.colOn
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.30)
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                    RowLayout {
                        id: startRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: view.sys.tr("Comenzar a explorar")
                            color: "#ffffff"
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2; bold: true }
                        }

                        Glyph {
                            glyph: String.fromCodePoint(0xF0142) // md-chevron-right
                            color: "#ffffff"
                            fontFam: view.sys.fontFam
                            size: 14
                        }
                    }

                    MouseArea {
                        id: startMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.dismissWelcome()
                    }
                }
            }
        }
    }

    focus: true
    Keys.onEscapePressed: view.sys.dismissWelcome()
    Keys.onReturnPressed: view.sys.dismissWelcome()
    Keys.onEnterPressed: view.sys.dismissWelcome()
    Component.onCompleted: forceActiveFocus()
}
