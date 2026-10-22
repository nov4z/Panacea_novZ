import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Mouse & Keyboard input configuration.
// Keyboard layouts are stored in settings.json and generated into Hyprland's
// configuration so they survive shell updates.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys
        visible: Compositor.isHyprland

        SetLabel { sys: page.sys; text: page.sys.tr("Раскладки клавиатуры") }
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Selecciona una configuración rápida recomendada o ingresa códigos XKB personalizados. El cambio se aplica en tiempo real.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Presets rápidos interactivos
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { name: "Español (Latam) + US", layouts: "latam,us", variants: ",", icon: "󰌌" },
                    { name: "Español (España) + US", layouts: "es,us", variants: ",", icon: "󰌌" },
                    { name: "English (US) + Latam", layouts: "us,latam", variants: ",", icon: "󰌌" },
                    { name: "English (US) + Ruso", layouts: "us,ru", variants: ",", icon: "󰌌" },
                    { name: "Español + English + RU", layouts: "latam,us,ru", variants: ",,", icon: "󰌌" }
                ]

                Rectangle {
                    id: presetBtn
                    required property var modelData
                    readonly property bool active: page.sys.cfg.keyboardLayouts === presetBtn.modelData.layouts

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: presetBtn.active
                           ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                           : (btnMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12) : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.05))
                    border.width: 1
                    border.color: presetBtn.active
                                  ? page.sys.colOn
                                  : (btnMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.18) : "transparent")

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: presetBtn.modelData.icon
                            color: presetBtn.active ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.sys.tr(presetBtn.modelData.name)
                            color: presetBtn.active ? page.sys.colFg : page.sys.colMuted
                            elide: Text.ElideRight
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: presetBtn.active }
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            layoutsField.text = presetBtn.modelData.layouts;
                            variantsField.text = presetBtn.modelData.variants;
                            page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text);
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        }
                    }
                }
            }
        }

        // Atajo de cambio de idioma
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: page.sys.tr("Combinación para alternar teclado:")
            color: page.sys.colFg
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { name: "Alt + Shift", opt: "grp:alt_shift_toggle" },
                    { name: "Super + Espacio", opt: "grp:win_space_toggle" },
                    { name: "Ctrl + Shift", opt: "grp:ctrl_shift_toggle" },
                    { name: "Caps Lock", opt: "grp:caps_toggle" }
                ]

                Rectangle {
                    id: optChip
                    required property var modelData
                    readonly property bool active: page.sys.cfg.keyboardOptions === optChip.modelData.opt

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 8
                    color: optChip.active
                           ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.20)
                           : (optMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10) : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.04))
                    border.width: 1
                    border.color: optChip.active ? page.sys.colOn : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: page.sys.tr(optChip.modelData.name)
                        color: optChip.active ? page.sys.colFg : page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: optChip.active }
                    }

                    MouseArea {
                        id: optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            optionsField.text = optChip.modelData.opt;
                            page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text);
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        }
                    }
                }
            }
        }

        // Configuración manual XKB (avanzado)
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: page.sys.tr("Configuración manual XKB (avanzado):")
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        TextField {
            id: layoutsField
            Layout.fillWidth: true
            placeholderText: "latam,us"
            text: page.sys.cfg.keyboardLayouts
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }
        TextField {
            id: variantsField
            Layout.fillWidth: true
            placeholderText: page.sys.tr("Варианты (пустые — по умолчанию)")
            text: page.sys.cfg.keyboardVariants
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }
        TextField {
            id: optionsField
            Layout.fillWidth: true
            placeholderText: "grp:alt_shift_toggle"
            text: page.sys.cfg.keyboardOptions
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }
        Text {
            Layout.fillWidth: true
            visible: page.sys.keyboardInputError.length > 0
            text: page.sys.keyboardInputError
            color: page.sys.colCrit
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        SetButton {
            sys: page.sys
            text: page.sys.tr("Применить раскладки")
            onClicked: page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Compositor.isNiri
        text: page.sys.tr("В Niri раскладки задаются в ~/.config/niri/config.kdl; этот файл сохраняется при обновлении.")
        color: page.sys.colMuted
        wrapMode: Text.WordWrap
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Указатель") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Скорость указателя")
            from: -1; to: 1; step: 0.05
            decimals: 2
            value: page.sys.cfg.mouseSens
            onMoved: v => { page.sys.cfg.mouseSens = v; page.sys.applyInput(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("0 — скорость как её отдаёт мышь. Влево медленнее, вправо быстрее.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Прямой ввод")
            sub: page.sys.tr("Без разгона: одно и то же движение по столу всегда даёт одно и то же расстояние по экрану. То, ради чего в играх выключают повышенную точность указателя.")
            on: page.sys.cfg.mouseRaw
            onToggled: v => { page.sys.cfg.mouseRaw = v; page.sys.applyInput(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сброс") }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Вернуть заводские")
            onClicked: {
                page.sys.cfg.mouseSens = 0;
                page.sys.cfg.mouseRaw = false;
                page.sys.applyInput();
            }
        }
    }
}
