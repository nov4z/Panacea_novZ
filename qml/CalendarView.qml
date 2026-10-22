import QtQuick
import QtQuick.Layouts

// Календарь: сетка месяца, сегодняшний день подсвечен.
// Неделя начинается с понедельника.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: view.sys.page = "main"
    Keys.onLeftPressed:  view.shift(-1)
    Keys.onRightPressed: view.shift(1)

    readonly property date today: new Date()
    property int viewYear:  today.getFullYear()
    property int viewMonth: today.getMonth()          // 0..11
    property int shiftDir: 0

    function shift(delta) {
        shiftDir = delta;
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0)  { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        viewMonth = m; viewYear = y;
        gridAnim.restart();
    }
    function toToday() {
        var m = today.getMonth();
        var y = today.getFullYear();
        shiftDir = (y > viewYear || (y === viewYear && m > viewMonth)) ? 1 : -1;
        viewYear = y;
        viewMonth = m;
        gridAnim.restart();
    }

    readonly property var monthsRu: ["Январь","Февраль","Март","Апрель","Май","Июнь",
                                     "Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"]
    readonly property var monthsEn: ["January","February","March","April","May","June",
                                     "July","August","September","October","November","December"]
    readonly property var monthsEs: ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
                                     "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
    readonly property var monthsTr: ["Ocak","Şubat","Mart","Nisan","Mayıs","Haziran",
                                     "Temmuz","Ağustos","Eylül","Ekim","Kasım","Aralık"]
    readonly property var dowRu: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
    readonly property var dowEn: ["Mo","Tu","We","Th","Fr","Sa","Su"]
    readonly property var dowEs: ["Lu","Ma","Mi","Ju","Vi","Sá","Do"]
    readonly property var dowTr: ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    readonly property bool isTr: view.sys ? (view.sys.languageCode === "tr" || view.sys.isTr) : false
    readonly property bool isEs: view.sys ? view.sys.isEs : false
    readonly property bool isEn: view.sys ? view.sys.isEn : false
    readonly property bool isMaterial: !!(view.sys && view.sys.themeMaterial)

    readonly property var currentMonths: isTr ? monthsTr : (isEs ? monthsEs : (isEn ? monthsEn : monthsRu))
    readonly property var currentDow: isTr ? dowTr : (isEs ? dowEs : (isEn ? dowEn : dowRu))

    // 42 ячейки: шесть недель, чтобы сетка не прыгала между месяцами
    readonly property var cells: {
        var first = new Date(viewYear, viewMonth, 1);
        // getDay(): 0 — воскресенье; нам нужен понедельник первым
        var lead = (first.getDay() + 6) % 7;
        var start = new Date(viewYear, viewMonth, 1 - lead);
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                isToday: d.getFullYear() === today.getFullYear()
                         && d.getMonth() === today.getMonth()
                         && d.getDate() === today.getDate(),
                weekend: i % 7 >= 5
            });
        }
        return out;
    }

    component NavBtn: Rectangle {
        property string sym: ""
        signal pressedAction()

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: isMaterial ? 15 : 10
        color: navMa.containsMouse
               ? (isMaterial ? (view.sys.colM3SurfaceContainerHigh || Qt.rgba(1, 1, 1, 0.15)) : Qt.rgba(1, 1, 1, 0.13))
               : (isMaterial ? (view.sys.colM3SurfaceContainer || Qt.rgba(1, 1, 1, 0.08)) : Qt.rgba(1, 1, 1, 0.06))
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: navMa.pressed ? 0.94 : (navMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: parent.sym
            color: isMaterial ? (view.sys.colOn || view.sys.colFg) : view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
        }
        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.pressedAction()
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NavBtn { sym: "‹"; onPressedAction: view.shift(-1) }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.currentMonths[view.viewMonth]
                    color: isMaterial ? (view.sys.colOn || view.sys.colFg) : view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.viewYear
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            NavBtn { sym: "›"; onPressedAction: view.shift(1) }
        }

        // дни недели
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: view.currentDow
                Text {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5
                           ? (isMaterial ? (view.sys.colCrit || "#e08096") : Qt.rgba(1, 0.42, 0.42, 0.55))
                           : (isMaterial ? (view.sys.colM3OnSurface || view.sys.colMuted) : view.sys.colMuted)
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                }
            }
        }

        // сетка месяца
        GridLayout {
            id: monthGrid
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4
            transform: Translate {
                id: gridTrans
                x: 0
            }
            SequentialAnimation {
                id: gridAnim
                PropertyAction { target: gridTrans; property: "x"; value: view.shiftDir > 0 ? 18 : -18 }
                PropertyAction { target: monthGrid; property: "opacity"; value: 0.35 }
                ParallelAnimation {
                    NumberAnimation { target: gridTrans; property: "x"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: monthGrid; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                }
            }

            Repeater {
                model: view.cells

                Rectangle {
                    id: cell
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: isMaterial ? 17 : 10
                    color: cell.modelData.isToday
                           ? (isMaterial
                              ? (view.sys.colOn || "#ffffff")
                              : (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22) : Qt.rgba(1, 1, 1, 0.22)))
                           : (cellMa.containsMouse && cell.modelData.inMonth
                              ? (isMaterial ? (view.sys.colM3SurfaceContainerHigh || Qt.rgba(1, 1, 1, 0.10)) : Qt.rgba(1, 1, 1, 0.08))
                              : "transparent")
                    border.color: cell.modelData.isToday
                                  ? (isMaterial ? "transparent" : (view.sys ? view.sys.colOn : "#ffffff"))
                                  : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 140 } }
                    scale: (cellMa.containsMouse && cell.modelData.inMonth) ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        color: !cell.modelData.inMonth ? Qt.rgba(1, 1, 1, 0.18)
                             : cell.modelData.isToday
                               ? (isMaterial
                                  ? (view.sys.colM3OnPrimary || (view.sys.matugenColors && view.sys.matugenColors.on_primary ? view.sys.matugenColors.on_primary.dark.color : "#121212"))
                                  : view.sys.colFg)
                             : cell.modelData.weekend
                               ? (isMaterial ? (view.sys.colCrit || "#e08096") : Qt.rgba(1, 0.42, 0.42, 0.85))
                               : view.sys.colFg
                        font {
                            family: view.sys.fontFam
                            pixelSize: view.sys.fontSize - 2
                            bold: cell.modelData.isToday
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }

        // возврат к текущему месяцу
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 118
            Layout.preferredHeight: 28
            radius: isMaterial ? 14 : 10
            visible: view.viewMonth !== view.today.getMonth()
                     || view.viewYear !== view.today.getFullYear()
            color: todayMa.containsMouse
                   ? (isMaterial ? (view.sys.colM3SurfaceContainerHigh || Qt.rgba(1, 1, 1, 0.15)) : Qt.rgba(1, 1, 1, 0.13))
                   : (isMaterial ? (view.sys.colM3SurfaceContainer || Qt.rgba(1, 1, 1, 0.08)) : Qt.rgba(1, 1, 1, 0.06))
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: todayMa.pressed ? 0.96 : (todayMa.containsMouse ? 1.03 : 1.0)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Text {
                anchors.centerIn: parent
                text: view.sys.tr("Сегодня")
                color: isMaterial ? (view.sys.colOn || view.sys.colFg) : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: isMaterial }
            }
            MouseArea {
                id: todayMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.toToday()
            }
        }
    }
}
