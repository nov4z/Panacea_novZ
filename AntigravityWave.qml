import QtQuick

// Calm progress wave ("ola tranquila") and active subagent counter component for Panacea notch.
// Renders an organic continuous ribbon dual-harmonic sine wave via Canvas FBO oscillating in
// the notch accent color (effectiveWaveColor / colOn), accompanied immediately to its right by
// the subagent counter badge (hidden when subagentCount <= 1, shown when subagentCount >= 2).
Item {
    id: root

    property bool active: true
    property color waveColor: "#3087fb"
    property int subagentCount: 0
    property color textColor: waveColor

    // Typography design tokens matching Panacea notch
    property string fontFam: ""
    property int fontSize: 10

    // Component dimensions
    property real waveWidth: 28
    property real waveHeight: 16

    implicitWidth: active ? waveRow.implicitWidth : 0
    implicitHeight: waveHeight
    width: implicitWidth
    height: implicitHeight

    // Smooth active / idle transitions
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.6
    visible: opacity > 0.0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    Behavior on waveColor {
        ColorAnimation {
            duration: 300
            easing.type: Easing.InOutCubic
        }
    }

    onWaveColorChanged: waveCanvas.requestPaint()
    onSubagentCountChanged: waveCanvas.requestPaint()

    Row {
        id: waveRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Canvas {
            id: waveCanvas
            width: root.waveWidth
            height: root.waveHeight
            renderTarget: Canvas.FramebufferObject
            antialiasing: true
            smooth: true

            property real phase: 0.0
            readonly property int animDuration: root.subagentCount <= 1 ? 3200 : Math.max(1600, 3200 - (root.subagentCount - 1) * 400)

            NumberAnimation on phase {
                from: 0.0
                to: Math.PI * 2
                duration: waveCanvas.animDuration
                loops: Animation.Infinite
                running: root.active && root.visible
            }

            onPhaseChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                if (width <= 0 || height <= 0) return;

                ctx.lineWidth = 2.0;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.strokeStyle = root.waveColor;

                ctx.beginPath();
                var midY = height / 2.0;
                var W = width;
                var clampedSub = Math.max(0, Math.min(root.subagentCount, 5));
                var baseAmp = (height * 0.35) * (1.0 + clampedSub * 0.05);

                var k1 = 2.0 * Math.PI / W * (clampedSub <= 1 ? 1.0 : (1.2 + clampedSub * 0.2));
                var k2 = 2.0 * Math.PI / W * (clampedSub <= 1 ? 2.0 : (2.4 + clampedSub * 0.3));

                for (var x = 0; x <= W; x += 1.5) {
                    var normX = x / W;
                    var taper = Math.sin(Math.PI * normX);
                    // For clampedSub <= 1: exactamente 1 sola onda notoria que se eleva y baja suavemente
                    // For clampedSub >= 2: ondas compuestas de mayor frecuencia, dinamismo y actividad
                    // Multiplicadores enteros (+ 1.0 * phase, + 2.0 * phase) garantizan bucle infinito sin cortes
                    var y = (clampedSub <= 1)
                        ? (midY + baseAmp * taper * Math.sin(k1 * x + phase))
                        : (midY + baseAmp * taper * (Math.sin(k1 * x + phase) + 0.35 * Math.sin(k2 * x + 2.0 * phase)));
                    if (x === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }

        Item {
            id: counterBox
            visible: root.subagentCount >= 2
            width: visible ? counterText.implicitWidth : 0
            height: root.waveHeight
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            opacity: root.subagentCount >= 2 ? 1.0 : 0.0
            scale: root.subagentCount >= 2 ? 1.0 : 0.6

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: counterText
                anchors.centerIn: parent
                text: root.subagentCount >= 2 ? String(root.subagentCount) : ""
                color: root.textColor
                font.family: root.fontFam || "JetBrainsMono Nerd Font"
                font.pixelSize: root.fontSize
                font.bold: true
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                antialiasing: true
            }
        }
    }
}
