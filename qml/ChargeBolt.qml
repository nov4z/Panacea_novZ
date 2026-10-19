import QtQuick
import QtQuick.Layouts

// Átomo visual: icono de batería con animación de onda (charging ripple)
// idéntico al iPhone Dynamic Island y al notch real de Panacea.
Item {
    id: cb

    property var sys
    property string icon: (sys && sys.batteryIcon) ? sys.batteryIcon : "󰂄"
    property real pixelSize: (sys && sys.iconSize) ? (sys.iconSize - 2) : 13
    property color chargeColor: (sys && sys.colCharge) ? sys.colCharge : "#30D158"
    property color iconColor: cb.charging ? cb.chargeColor
                            : (sys && !sys.acOnline && sys.batteryPct <= ((sys.cfg && sys.cfg.lowBatteryCritThreshold) || 15) ? sys.colBattCrit
                            : (sys && !sys.acOnline && sys.batteryPct <= ((sys.cfg && sys.cfg.lowBatteryThreshold) || 20) ? sys.colBattWarn
                            : (sys ? sys.colFg : "#ffffff")))
    property bool charging: sys ? sys.batteryCharging : false
    property bool active: true
    property bool chargeRipple: (sys && sys.cfg && sys.cfg.chargeRipple !== undefined) ? sys.cfg.chargeRipple : true

    implicitWidth: Math.max(16, boltText.implicitWidth + 2)
    implicitHeight: Math.max(16, boltText.implicitHeight)

    // Dynamic Island charging ripple
    Rectangle {
        id: ripple
        anchors.centerIn: parent
        width: Math.round(cb.pixelSize * 1.8)
        height: width
        radius: width / 2
        color: Qt.rgba(cb.chargeColor.r, cb.chargeColor.g, cb.chargeColor.b, 0.16)
        border.color: cb.chargeColor
        border.width: 1.5
        antialiasing: true
        scale: 0.35
        opacity: 0.0
        visible: cb.chargeRipple && opacity > 0.001
        z: 0
    }

    // Bolt / Battery icon
    Text {
        id: boltText
        anchors.centerIn: parent
        z: 1
        text: cb.icon
        color: cb.iconColor
        font {
            family: (sys && sys.fontFam) ? sys.fontFam : ""
            pixelSize: cb.pixelSize
        }
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    SequentialAnimation {
        id: rippleAnim
        running: cb.charging && cb.active && cb.visible && cb.opacity > 0.01
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: ripple
                property: "scale"
                from: 0.35
                to: 1.14
                duration: 680
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: ripple
                property: "opacity"
                from: 0.85
                to: 0.0
                duration: 680
                easing.type: Easing.OutQuad
            }
            SequentialAnimation {
                NumberAnimation {
                    target: boltText
                    property: "scale"
                    from: 1.0
                    to: 1.18
                    duration: 220
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: boltText
                    property: "scale"
                    from: 1.18
                    to: 1.0
                    duration: 460
                    easing.type: Easing.OutQuad
                }
            }
        }
        PauseAnimation { duration: 320 }
    }
}
