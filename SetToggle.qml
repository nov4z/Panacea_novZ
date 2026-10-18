import QtQuick
import QtQuick.Layouts

// Строка с тумблером: подпись слева, переключатель справа.
// Пояснение под подписью необязательное — без него строка остаётся в одну
// линию и не разъезжает по высоте.
RowLayout {
    id: row

    property var sys
    property string label: ""
    property string sub: ""
    property bool on: false
    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: row.label
            color: row.sys.colFg
            elide: Text.ElideRight
            font { family: row.sys.fontBody; pixelSize: row.sys.fontSize - 1 }
        }
        Text {
            Layout.fillWidth: true
            visible: row.sub.length > 0
            text: row.sub
            color: row.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: row.sys.fontBody; pixelSize: row.sys.fontSize - 4 }
        }
    }

    Rectangle {
        id: track
        Layout.preferredWidth: 46
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignVCenter
        radius: height / 2
        color: row.on ? row.sys.colOn
                      : ((row.sys && row.sys.themeMaterial)
                         ? Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.08)
                         : Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.10))
        border.width: 1
        border.color: row.on ? Qt.rgba(row.sys.colOn.r, row.sys.colOn.g, row.sys.colOn.b, 0.4)
                             : ((row.sys && row.sys.themeMaterial)
                                ? Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.22)
                                : Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.12))

        scale: tMa.pressed ? 0.94 : (tMa.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            id: knob
            width: (row.sys && row.sys.themeMaterial) ? (row.on ? 22 : 16) : 20
            height: (row.sys && row.sys.themeMaterial) ? (row.on ? 22 : 16) : 20
            radius: height / 2
            y: Math.round((track.height - height) / 2)
            x: row.on ? track.width - width - ((row.sys && row.sys.themeMaterial) ? 4 : 3) : ((row.sys && row.sys.themeMaterial) ? 4 : 3)
            color: row.on
                   ? ((row.sys && row.sys.themeMaterial) ? (row.sys.colM3OnPrimary || row.sys.colBg) : row.sys.colBg)
                   : Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.55)
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: row.sys.animFade } }

            // Micro-indicador central Nothing OS
            Rectangle {
                visible: !(row.sys && row.sys.themeMaterial)
                anchors.centerIn: parent
                width: 4
                height: 4
                radius: 2
                color: row.on ? row.sys.colOn : Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.3)
            }
        }

        MouseArea {
            id: tMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.sys && row.sys.playSound) row.sys.playSound("tock");
                row.toggled(!row.on);
            }
        }
    }
}
