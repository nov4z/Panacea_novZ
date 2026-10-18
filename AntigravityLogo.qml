import QtQuick
import QtQuick.Effects

// Authentic Antigravity logo visual component for Panacea notch.
// Features a multi-layered composition with smooth fade-in / fade-out crossfading transitions:
// Stage 0: Logo base original (authentic multi-color palette at 100% fidelity)
// Stage 1: Rojo (vibrant luminous ruby/coral red glow without bottom shadow)
// Stage 2: Amarillo (luminous golden yellow glow)
// Stage 3: Verde (vibrant emerald green glow)
// Stage 4: Celeste (authentic Antigravity cyan glow)
// -> Loops back infinitely to Stage 0 (Logo base original).
//
// Also supports static Accent Color Mode (matching the notch wave color),
// driven by a continuous 60fps organic levitation and breathing physics animation.
Item {
    id: root

    property bool active: true
    property int size: 18

    // Mode: "anim" (cycles Base -> Rojo -> Amarillo -> Verde -> Celeste -> Base)
    //       "accent" (static tint matching the notch waves or system accent color)
    property string colorMode: "anim"
    property color accentColor: "#00e0ff"

    implicitWidth: size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight

    // Smooth entrance / exit transitions
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.6
    visible: opacity > 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    // -------------------------------------------------------------------------
    // 5-Stage Multi-Layer Fade In / Out Color Animation
    // Continuous 5-second cycle with smooth Hermite crossfading:
    // Logo Base -> Rojo -> Amarillo -> Verde -> Celeste -> Logo Base -> Loop
    // -------------------------------------------------------------------------
    property real chromaProgress: 0.0

    readonly property color colRojo:     Qt.rgba(1.00, 0.12, 0.32, 1.0) // Rojo vivo y brillante (#ff1f52)
    readonly property color colAmarillo: Qt.rgba(1.00, 0.90, 0.00, 1.0) // Amarillo luminoso (#ffe600)
    readonly property color colVerde:    Qt.rgba(0.00, 0.95, 0.45, 1.0) // Verde vibrante (#00f273)
    readonly property color colCeleste:  Qt.rgba(0.00, 0.88, 1.00, 1.0) // Celeste Antigravity (#00e0ff)

    function calcOpacity(p, center) {
        if (root.colorMode !== "anim") return 0.0;
        var diff = Math.abs(p - center);
        if (diff > 2.5) diff = 5.0 - diff;
        if (diff <= 0.25) return 1.0;
        if (diff < 0.75) {
            var t = (diff - 0.25) / 0.50;
            return 0.5 * (1.0 + Math.cos(Math.PI * t));
        }
        return 0.0;
    }

    // Sequence timing (total 5.0 units):
    // p = 0.5: Stage 0: Logo Base (overlays are 0.0)
    // p = 1.5: Stage 1: Rojo
    // p = 2.5: Stage 2: Amarillo
    // p = 3.5: Stage 3: Verde
    // p = 4.5: Stage 4: Celeste
    // -> wraps to 0.5: Stage 0: Logo Base
    readonly property real redOpacity:     calcOpacity(chromaProgress, 1.5)
    readonly property real yellowOpacity:  calcOpacity(chromaProgress, 2.5)
    readonly property real greenOpacity:   calcOpacity(chromaProgress, 3.5)
    readonly property real celesteOpacity: calcOpacity(chromaProgress, 4.5)

    // Smooth crossfade into accent mode if selected
    property real accentOpacity: root.colorMode === "accent" ? 1.0 : 0.0
    Behavior on accentOpacity {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    property bool animRunning: true

    NumberAnimation {
        id: chromaAnim
        target: root
        property: "chromaProgress"
        from: 0.0
        to: 5.0
        duration: 5000
        loops: Animation.Infinite
        running: root.active && root.colorMode === "anim" && root.animRunning
    }

    onActiveChanged: {
        if (active && colorMode === "anim") chromaProgress = 0.0;
    }

    // Contenedor unificado de capas con físicas de flotación y levitación
    Item {
        id: logoContainer
        anchors.centerIn: parent
        width: Math.max(0, Math.min(root.size, 24))
        height: Math.max(0, Math.min(root.size, 24))

        transform: Translate {
            id: floatTranslate
            y: 0
        }

        // 1. Capa base: Logo auténtico de Antigravity (siempre presente debajo, visible en Stage 0)
        Image {
            id: baseLogoImage
            anchors.fill: parent
            source: "assets/antigravity.png"
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
        }

        // 2. Capa de Modo Acento: Color de las ondas del notch (Fade in / out)
        Image {
            id: accentLayer
            anchors.fill: parent
            source: "assets/antigravity.png"
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
            opacity: root.accentOpacity
            visible: opacity > 0.001

            layer.enabled: root.accentOpacity > 0.001
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                colorization: 1.0
                colorizationColor: root.accentColor
                brightness: 0.28
                saturation: 0.50
                contrast: 0.04
            }
        }

        // 3. Capa de brillo: Rojo vivo sin sombra inferior (Fade in / out en Stage 1)
        Image {
            id: redLayer
            anchors.fill: parent
            source: "assets/antigravity.png"
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
            opacity: root.redOpacity
            visible: opacity > 0.001

            layer.enabled: root.redOpacity > 0.001
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                colorization: 1.0
                colorizationColor: root.colRojo
                brightness: 0.28
                saturation: 0.55
                contrast: 0.02
            }
        }

        // 4. Capa de brillo: Amarillo luminoso (Fade in / out en Stage 2)
        Image {
            id: yellowLayer
            anchors.fill: parent
            source: "assets/antigravity.png"
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
            opacity: root.yellowOpacity
            visible: opacity > 0.001

            layer.enabled: root.yellowOpacity > 0.001
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                colorization: 1.0
                colorizationColor: root.colAmarillo
                brightness: 0.22
                saturation: 0.45
                contrast: 0.08
            }
        }

        // 5. Capa de brillo: Verde vibrante (Fade in / out en Stage 3)
        Image {
            id: greenLayer
            anchors.fill: parent
            source: "assets/antigravity.png"
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
            opacity: root.greenOpacity
            visible: opacity > 0.001

            layer.enabled: root.greenOpacity > 0.001
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                colorization: 1.0
                colorizationColor: root.colVerde
                brightness: 0.22
                saturation: 0.45
                contrast: 0.08
            }
        }

        // 6. Capa de brillo: Celeste Antigravity (Fade in / out en Stage 4)
        Image {
            id: celesteLayer
            anchors.fill: parent
            source: "assets/antigravity.png"
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true
            opacity: root.celesteOpacity
            visible: opacity > 0.001

            layer.enabled: root.celesteOpacity > 0.001
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                colorization: 1.0
                colorizationColor: root.colCeleste
                brightness: 0.22
                saturation: 0.45
                contrast: 0.08
            }
        }
    }

    // Levitación infinita a 60 fps (flotación sinusoidal vertical, respiración de escala, rotación dinámica)
    SequentialAnimation {
        id: levitationAnim
        running: root.active
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: floatTranslate
                property: "y"
                from: 1.0
                to: -1.2
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: logoContainer
                property: "scale"
                from: 0.90
                to: 1.10
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: logoContainer
                property: "rotation"
                from: -1.5
                to: 1.5
                duration: 2600
                easing.type: Easing.InOutSine
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: floatTranslate
                property: "y"
                from: -1.2
                to: 1.0
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: logoContainer
                property: "scale"
                from: 1.10
                to: 0.90
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: logoContainer
                property: "rotation"
                from: 1.5
                to: -1.5
                duration: 2600
                easing.type: Easing.InOutSine
            }
        }
    }
}
