import QtQuick
import QtQuick.Layouts

// Кнопка внизу страницы настроек: «Применить» рядом со «Сбросить».
//
// Два вида. Основная (primary) залита акцентом и обведена им же — ею
// подтверждают; обычная прозрачная, с тонкой рамкой — ею отменяют. Разница
// только в этом: одинаковые кнопки рядом заставляли бы читать обе, чтобы
// понять, какая из них главная.
//
// Неактивная не исчезает, а гаснет: пропадающая кнопка меняет ширину ряда,
// и соседняя прыгает под курсором.
Rectangle {
    id: btn

    property var sys
    property string text: ""
    property bool primary: false
    // false — кнопка видна, но не нажимается: применять нечего
    property bool enabled: true

    signal clicked()

    // Ширина по надписи, но не уже прежних 112: короткие кнопки — «Применить»,
    // «Сбросить» — стоят парами, и разнобой в их ширине читался бы небрежностью.
    // А длинная надпись раньше просто вылезала за края: ширина была задана
    // числом, а текст ничем не ограничен.
    Layout.preferredWidth: Math.max(112, btnLabel.implicitWidth + 26)
    Layout.preferredHeight: 32
    radius: (btn.sys && btn.sys.themeMaterial) ? 16 : 10
    opacity: btn.enabled ? 1 : 0.4

    scale: ma.pressed ? 0.96 : (ma.containsMouse ? 1.025 : 1.0)

    color: btn.primary
           ? ((btn.sys && btn.sys.themeMaterial)
              ? (ma.containsMouse ? Qt.lighter(btn.sys.colOn, 1.08) : btn.sys.colOn)
              : (ma.containsMouse
                 ? Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.36)
                 : Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.22)))
           : (ma.containsMouse ? Qt.rgba(btn.sys.colFg.r, btn.sys.colFg.g, btn.sys.colFg.b, 0.10) : "transparent")
    border.width: 1
    border.color: btn.primary
                  ? ((btn.sys && btn.sys.themeMaterial)
                     ? "transparent"
                     : (ma.containsMouse ? Qt.lighter(btn.sys.colOn, 1.15) : btn.sys.colOn))
                  : (ma.containsMouse ? Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.45) : btn.sys.colLine)

    Behavior on radius { NumberAnimation { duration: 180 } }
    Behavior on color { ColorAnimation { duration: btn.sys.animFade } }
    Behavior on border.color { ColorAnimation { duration: btn.sys.animFade } }
    Behavior on opacity { NumberAnimation { duration: btn.sys.animFade } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Text {
        id: btnLabel
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary
               ? ((btn.sys && btn.sys.themeMaterial) ? (btn.sys.colM3OnPrimary || btn.sys.colBg) : btn.sys.colFg)
               : (ma.containsMouse ? btn.sys.colFg : btn.sys.colMuted)
        font {
            family: btn.sys.fontBody
            pixelSize: btn.sys.fontSize - 3
            bold: btn.primary
        }
        Behavior on color { ColorAnimation { duration: btn.sys.animFade } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (btn.sys && btn.sys.playSound) btn.sys.playSound("tock");
            btn.clicked();
        }
    }
}
