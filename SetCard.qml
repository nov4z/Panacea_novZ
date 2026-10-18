import QtQuick
import QtQuick.Layouts

// Карточка раздела: тёмная плашка со скруглением, внутри — строки настроек.
// Разделительных линий между строками нет, ритм задаёт только шаг отступов.
Rectangle {
    id: card

    property var sys
    default property alias content: inner.data
    property alias spacing: inner.spacing
    property int pad: 18

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + pad * 2
    radius: 18
    clip: true

    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: cardHover.hovered
                   ? Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.075)
                   : Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.048)
        }
        GradientStop {
            position: 1.0
            color: cardHover.hovered
                   ? Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.050)
                   : Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.028)
        }
    }

    border.width: 1
    border.color: cardHover.hovered
                  ? Qt.rgba(card.sys.colOn.r, card.sys.colOn.g, card.sys.colOn.b, 0.35)
                  : Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.085)

    Behavior on border.color { ColorAnimation { duration: card.sys ? card.sys.animHover : 160 } }


    HoverHandler {
        id: cardHover
    }

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: card.pad
        spacing: 15
    }
}
