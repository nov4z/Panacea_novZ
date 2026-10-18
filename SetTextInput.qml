import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var sys
    property string label: ""
    property string sub: ""
    property string value: ""
    property string defaultValue: ""
    property string placeholder: ""
    signal accepted(string text)

    Layout.fillWidth: true
    spacing: 6

    // Cabecera: Etiqueta y botón de restaurar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.label
                color: root.sys.colFg
                font { family: root.sys.fontBody; pixelSize: root.sys.fontSize - 1 }
            }

            Text {
                visible: root.sub.length > 0
                text: root.sub
                color: root.sys.colMuted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font { family: root.sys.fontBody; pixelSize: root.sys.fontSize - 3 }
            }
        }

        Rectangle {
            visible: root.defaultValue.length > 0 && root.value !== root.defaultValue
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: rstTxt.implicitWidth + 14
            implicitHeight: 22
            radius: 5
            color: rstMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.color: Qt.rgba(root.sys.colFg.r, root.sys.colFg.g, root.sys.colFg.b, 0.18)
            border.width: 1

            Text {
                id: rstTxt
                anchors.centerIn: parent
                text: root.sys.tr("Por defecto")
                color: root.sys.colMuted
                font { family: root.sys.fontBody; pixelSize: root.sys.fontSize - 3 }
            }

            MouseArea {
                id: rstMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    inputField.text = root.defaultValue;
                    root.value = root.defaultValue;
                    root.accepted(root.defaultValue);
                }
            }
        }
    }

    // Campo de entrada
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 7
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: inputField.activeFocus ? root.sys.colOn : Qt.rgba(root.sys.colFg.r, root.sys.colFg.g, root.sys.colFg.b, 0.16)
        border.width: inputField.activeFocus ? 1.5 : 1

        Behavior on border.color { ColorAnimation { duration: 150 } }

        TextInput {
            id: inputField
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: clearBtn.visible ? clearBtn.left : parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            color: root.sys.colFg
            clip: true
            selectByMouse: true
            selectionColor: Qt.rgba(root.sys.colOn.r, root.sys.colOn.g, root.sys.colOn.b, 0.35)
            font { family: root.sys.fontBody; pixelSize: root.sys.fontSize - 1 }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: inputField.text.length === 0
                text: root.placeholder || root.defaultValue
                color: Qt.rgba(root.sys.colMuted.r, root.sys.colMuted.g, root.sys.colMuted.b, 0.6)
                font: inputField.font
            }

            onTextEdited: {
                root.value = text;
                root.accepted(text);
            }

            onEditingFinished: {
                if (root.value !== text) {
                    root.value = text;
                    root.accepted(text);
                }
            }

            onAccepted: {
                root.value = text;
                root.accepted(text);
            }
        }

        // Botón limpiar
        Item {
            id: clearBtn
            visible: inputField.text.length > 0 && inputField.activeFocus
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: clearMa.containsMouse ? root.sys.colFg : root.sys.colMuted
                font { family: root.sys.fontBody; pixelSize: 10; bold: true }
            }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    inputField.text = "";
                    root.value = "";
                    root.accepted("");
                }
            }
        }
    }
}
