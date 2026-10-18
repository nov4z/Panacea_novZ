import QtQuick
import QtQuick.Layouts

// Заголовок группы внутри карточки: «TYPE», «SHAPE & DEPTH».
// Мелкий, разрежённый, приглушённый Nothing OS стиль с точкой-индикатором.
RowLayout {
    id: cap

    property var sys
    property alias text: labelText.text

    Layout.fillWidth: true
    Layout.topMargin: 4
    Layout.bottomMargin: 2
    spacing: 7

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        width: 4
        height: 4
        radius: 2
        color: cap.sys ? cap.sys.colOn : "#ffffff"
    }

    Text {
        id: labelText
        color: cap.sys ? Qt.rgba(cap.sys.colFg.r, cap.sys.colFg.g, cap.sys.colFg.b, 0.45) : "#888888"
        font {
            family: cap.sys ? cap.sys.fontBody : "sans-serif"
            pixelSize: cap.sys ? (cap.sys.fontSize - 5) : 10
            letterSpacing: 1.6
            capitalization: Font.AllUppercase
            bold: true
        }
    }

    Item {
        Layout.fillWidth: true
    }
}
