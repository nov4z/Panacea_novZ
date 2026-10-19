import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string trackKey: ""
    property string artSource: ""
    property real artRadius: 7
    property color placeholderColor: "#888888"
    property string fontFam: ""
    property int iconSize: 13
    property int sourceSize: 256

    // Configuración de reacción y ondas
    property bool rippleUnderCover: false  // Onda debajo de la portada
    property int  rippleShape: 0           // 0 = Circular, 1 = Cuadrada (radio de carátula), 2 = Cuadrada recta
    property real rippleSens: 1.0          // Sensibilidad de la onda tras carátula (0.25 a 2.50)
    property int  rippleFreq: 0            // 0 = Graves, 1 = Medios, 2 = Agudos, 3 = Espectro completo
    property real ripplePersistence: 1.0   // Persistencia / duración de la onda tras carátula (0.50 a 2.50)
    property bool bounceEnabled: true      // Reacción de la portada (latido/pulso)
    property int reactionMode: 0           // 0 = Normal/Estática, 1 = Latido/Pulso, 2 = Resplandor, 3 = Pulso+Resplandor
    property real reactionIntensity: 0.5   // Factor de 0.0 a 1.0
    property bool reactionActive: false    // Activo cuando reproduce música
    property bool waveOverlay: false       // Mostrar onda sobre la carátula
    property color dominantColor: "#ffffff"
    property color waveColor: dominantColor

    readonly property real rippleRadius: {
        if (root.rippleShape === 1) return root.artRadius;
        if (root.rippleShape === 2) return 0;
        return width / 2;
    }

    onReactionActiveChanged: {
        if (reactionActive) CavaSource.acquire();
        else CavaSource.release();
    }
    Component.onCompleted: {
        if (reactionActive) CavaSource.acquire();
    }
    Component.onDestruction: {
        if (reactionActive) CavaSource.release();
    }

    // Beat reactivo real
    property real beatLevel: 0.0
    property real beatSmooth: 0.0
    property real lastBeatTime: 0
    property real syntheticBeat: 0.0
    property int nextRippleIdx: 0

    function extractFrequencyEnergy(lvl) {
        if (!lvl || lvl.length === 0) return 0.0;
        var n = lvl.length;
        if (root.rippleFreq === 1) {
            // Medios (voces e instrumentos: bins 5 a 16 aprox)
            var start = Math.floor(n * 0.16);
            var end = Math.min(n - 1, Math.floor(n * 0.52));
            var sum = 0, count = 0;
            for (var i = start; i <= end; i++) {
                sum += (lvl[i] || 0);
                count++;
            }
            return (count > 0 ? (sum / count) * 1.45 : 0.0);
        } else if (root.rippleFreq === 2) {
            // Agudos (platillos, sintetizadores altos: bins 17 en adelante)
            var start = Math.floor(n * 0.52);
            var sum = 0, count = 0;
            for (var i = start; i < n; i++) {
                sum += (lvl[i] || 0);
                count++;
            }
            return (count > 0 ? (sum / count) * 1.85 : 0.0);
        } else if (root.rippleFreq === 3) {
            // Espectro completo (balance general)
            var sum = 0;
            for (var i = 0; i < n; i++) {
                sum += (lvl[i] || 0);
            }
            return (sum / n) * 1.35;
        } else {
            // Graves (bombos y sub-bajos en bins 0..4) - Default
            return (lvl[0] * 0.40 + (lvl[1] || 0) * 0.35 + (lvl[2] || 0) * 0.20 + (lvl[3] || 0) * 0.15 + (lvl[4] || 0) * 0.10);
        }
    }

    function triggerBeatRipple(energy) {
        if (!rippleUnderCover || !reactionActive) return;
        var p = energy || 0.6;
        var persist = Math.max(0.4, root.ripplePersistence);
        var targetScale = 1.20 + p * 0.60 * Math.min(1.35, Math.sqrt(persist));
        var peakOp = Math.min(0.95, 0.40 + p * 0.55);

        if (nextRippleIdx === 0) {
            animRip1.stop();
            ripCircle1.maxScale = targetScale;
            ripCircle1.peakOpacity = peakOp;
            animRip1.totalDuration = Math.round(480 * persist);
            animRip1.fade1Duration = Math.round(120 * persist);
            animRip1.fade2Duration = Math.round(360 * persist);
            animRip1.start();
            nextRippleIdx = 1;
        } else {
            animRip2.stop();
            ripCircle2.maxScale = targetScale;
            ripCircle2.peakOpacity = peakOp;
            animRip2.totalDuration = Math.round(480 * persist);
            animRip2.fade1Duration = Math.round(120 * persist);
            animRip2.fade2Duration = Math.round(360 * persist);
            animRip2.start();
            nextRippleIdx = 0;
        }
    }

    Connections {
        target: CavaSource
        enabled: root.reactionActive && CavaSource.hasCava
        function onLevelsChanged() {
            var lvl = CavaSource.levels;
            if (lvl && lvl.length >= 4) {
                var rawEnergy = root.extractFrequencyEnergy(lvl);
                var sens = Math.max(0.2, root.rippleSens);
                var energy = Math.min(1.0, rawEnergy * 1.5 * sens);
                root.beatLevel = energy;

                // Detección de impacto acústico adaptada a la sensibilidad
                var delta = energy - root.beatSmooth;
                var now = Date.now();
                var thresholdDelta = Math.max(0.04, 0.13 / Math.min(2.0, sens));
                var thresholdMinEnergy = Math.max(0.08, 0.22 / Math.min(2.0, sens));
                var minInterval = Math.max(90, 160 / Math.min(2.0, sens));

                if (delta > thresholdDelta && energy > thresholdMinEnergy && (now - root.lastBeatTime > minInterval)) {
                    root.lastBeatTime = now;
                    root.triggerBeatRipple(energy);
                }
                root.beatSmooth = root.beatSmooth * 0.80 + energy * 0.20;
            }
        }
    }

    // Ritmo sintético de respaldo cuando cava no está disponible
    Timer {
        id: syntheticBeatTimer
        interval: 460
        running: root.reactionActive && (root.bounceEnabled || root.rippleUnderCover || root.reactionMode === 1 || root.reactionMode === 3) && (!CavaSource.hasCava || !root.beatLevel)
        repeat: true
        onTriggered: {
            synthAnim.restart();
            root.triggerBeatRipple(0.55);
        }
    }

    SequentialAnimation {
        id: synthAnim
        NumberAnimation {
            target: root
            property: "syntheticBeat"
            from: 0.22
            to: 0.0
            duration: 360
            easing.type: Easing.OutQuad
        }
    }

    readonly property real effectiveBeat: Math.max(beatLevel, syntheticBeat)

    // Escala reactiva: la portada reacciona con la música
    readonly property real currentScale: {
        if (!reactionActive) return 1.0;
        if (bounceEnabled || reactionMode === 1 || reactionMode === 3) {
            return 1.0 + (effectiveBeat * 0.16 * Math.max(0.1, reactionIntensity));
        }
        return 1.0;
    }

    scale: currentScale
    Behavior on scale {
        NumberAnimation { duration: 75; easing.type: Easing.OutQuad }
    }

    // ===== Máquina de estado del giro 3D (track-aware, con debounce) =====
    // El debounce de 16ms asegura que todas las propiedades de shell.qml
    // (mediaArtTrack, mediaArtLocal, mediaArt) se estabilicen antes de
    // procesar un cambio de track, evitando flips prematuros con arte viejo.
    property int currentFace: 0         // 0 = Face A visible, 1 = Face B visible
    property string currentArt: ""      // URL del arte en la cara visible
    property string currentTrack: ""    // trackKey del track actualmente visible
    property bool flipInProgress: false // true durante la animación de 440ms

    // Estado objetivo para el próximo flip
    property int targetFace: -1
    property string targetTrack: ""
    property string targetArt: ""
    property bool targetReady: false

    // Debounce para esperar que las propiedades de shell.qml se estabilicen
    property string pendingTrackKey: ""

    readonly property real normalizedAngle: ((flipRot.angle % 360) + 360) % 360

    onTrackKeyChanged: {
        var tk = String(trackKey || "").trim();
        if (tk.length === 0 || tk === root.currentTrack) return;
        root.pendingTrackKey = tk;
        flipDebounce.restart();
    }

    onArtSourceChanged: {
        var art = String(artSource || "").trim();
        if (art.length === 0) return;

        // Durante el debounce: artSource aún se está estabilizando, ignorar
        if (flipDebounce.running) return;

        // Si estamos preparando un flip y esperando que cargue la imagen
        if (root.targetTrack.length > 0 && !root.flipInProgress && !root.targetReady) {
            root.targetArt = art;
            if (root.targetFace === 1) faceB.artSource = art;
            else faceA.artSource = art;
            root.checkTargetReady();
            return;
        }

        // Si hay un flip en curso, actualizar la cara objetivo en silencio
        if (root.flipInProgress && root.targetTrack.length > 0) {
            root.targetArt = art;
            if (root.targetFace === 1) faceB.artSource = art;
            else faceA.artSource = art;
            return;
        }

        // Actualización silenciosa para el mismo track (ej: remoto → caché local)
        if (art !== root.currentArt) {
            root.currentArt = art;
            if (root.currentFace === 0) faceA.artSource = art;
            else faceB.artSource = art;
        }
    }

    // Debounce de 16ms (~1 frame): espera a que refreshMediaArt() termine
    // de asignar las 3 propiedades (mediaArtTrack, mediaArtLocal, mediaArt)
    // antes de tomar acción.
    Timer {
        id: flipDebounce
        interval: 16
        repeat: false
        onTriggered: {
            var tk = root.pendingTrackKey;
            var art = String(root.artSource || "").trim();
            root.pendingTrackKey = "";

            if (tk.length === 0 || tk === root.currentTrack) return;

            // Inicialización del primer track
            if (root.currentTrack.length === 0) {
                root.currentTrack = tk;
                if (art.length > 0) {
                    root.currentArt = art;
                    faceA.artSource = art;
                }
                root.currentFace = 0;
                flipRot.angle = 0;
                return;
            }

            // Si hay un flip en curso, no hacer nada ahora;
            // al completar el flip se re-verificará trackKey vs currentTrack
            if (root.flipInProgress) return;

            root.initiateFlip(tk, art);
        }
    }

    function initiateFlip(tk, art) {
        root.targetFace = (root.currentFace === 0) ? 1 : 0;
        root.targetTrack = tk;
        root.targetArt = art;
        root.targetReady = false;
        flipSafetyTimer.restart();

        if (art.length === 0) {
            // Sin arte: girar al placeholder directamente
            if (root.targetFace === 1) faceB.artSource = "";
            else faceA.artSource = "";
            root.targetReady = true;
            root.doStartFlip();
            return;
        }

        // Cargar arte en la cara objetivo
        if (root.targetFace === 1) {
            faceB.artSource = art;
        } else {
            faceA.artSource = art;
        }

        root.checkTargetReady();
    }

    function checkTargetReady() {
        if (root.targetReady || root.flipInProgress) return;
        if (root.targetArt.length === 0) return;

        if (root.targetFace === 1) {
            if (artImgB.status === Image.Ready && String(artImgB.source) === root.targetArt) {
                root.targetReady = true;
                root.doStartFlip();
            }
        } else {
            if (artImgA.status === Image.Ready && String(artImgA.source) === root.targetArt) {
                root.targetReady = true;
                root.doStartFlip();
            }
        }
    }

    function doStartFlip() {
        if (root.flipInProgress) return;
        flipSafetyTimer.stop();
        root.flipInProgress = true;
        if (root.targetFace === 1) flipAnimToB.restart();
        else flipAnimToA.restart();
    }

    // Temporizador de seguridad: si la imagen nunca carga, girar de todos
    // modos (se mostrará el placeholder 󰝚)
    Timer {
        id: flipSafetyTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (!root.flipInProgress && root.targetTrack.length > 0) {
                root.targetReady = true;
                root.doStartFlip();
            }
        }
    }

    transform: Rotation {
        id: flipRot
        origin.x: root.width / 2
        origin.y: root.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: 0
    }

    SequentialAnimation {
        id: flipAnimToB
        NumberAnimation {
            target: flipRot
            property: "angle"
            from: 0
            to: 180
            duration: 440
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: {
                root.currentFace = 1;
                root.currentTrack = root.targetTrack;
                root.currentArt = root.targetArt;
                root.targetTrack = "";
                root.targetArt = "";
                root.targetFace = -1;
                root.targetReady = false;
                root.flipInProgress = false;
                // Verificar si hubo otro cambio de track durante el flip
                var tk = String(root.trackKey || "").trim();
                if (tk.length > 0 && tk !== root.currentTrack) {
                    root.pendingTrackKey = tk;
                    flipDebounce.restart();
                }
            }
        }
    }

    SequentialAnimation {
        id: flipAnimToA
        NumberAnimation {
            target: flipRot
            property: "angle"
            from: 180
            to: 360
            duration: 440
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: {
                flipRot.angle = 0;
                root.currentFace = 0;
                root.currentTrack = root.targetTrack;
                root.currentArt = root.targetArt;
                root.targetTrack = "";
                root.targetArt = "";
                root.targetFace = -1;
                root.targetReady = false;
                root.flipInProgress = false;
                // Verificar si hubo otro cambio de track durante el flip
                var tk = String(root.trackKey || "").trim();
                if (tk.length > 0 && tk !== root.currentTrack) {
                    root.pendingTrackKey = tk;
                    flipDebounce.restart();
                }
            }
        }
    }

    // ------------------------------------ Onda acústica debajo de la portada (Beat reactiva)
    Item {
        id: coverRippleGroup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        visible: root.rippleUnderCover && root.reactionActive
        z: -2

        // Onda 1 (Disparada por el beat real)
        Rectangle {
            id: ripCircle1
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: root.rippleRadius
            color: "transparent"
            border.color: root.dominantColor
            border.width: 1.5
            property real maxScale: 1.70
            property real peakOpacity: 0.80
            scale: 1.0
            opacity: 0.0

            ParallelAnimation {
                id: animRip1
                property int totalDuration: 480
                property int fade1Duration: 120
                property int fade2Duration: 360

                NumberAnimation {
                    target: ripCircle1
                    property: "scale"
                    from: 1.0
                    to: ripCircle1.maxScale
                    duration: animRip1.totalDuration
                    easing.type: Easing.OutQuad
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: ripCircle1
                        property: "opacity"
                        from: ripCircle1.peakOpacity
                        to: ripCircle1.peakOpacity * 0.6
                        duration: animRip1.fade1Duration
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: ripCircle1
                        property: "opacity"
                        from: ripCircle1.peakOpacity * 0.6
                        to: 0.0
                        duration: animRip1.fade2Duration
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }

        // Onda 2 (Disparada por el siguiente beat / alternancia)
        Rectangle {
            id: ripCircle2
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: root.rippleRadius
            color: "transparent"
            border.color: root.dominantColor
            border.width: 1.5
            property real maxScale: 1.70
            property real peakOpacity: 0.80
            scale: 1.0
            opacity: 0.0

            ParallelAnimation {
                id: animRip2
                property int totalDuration: 480
                property int fade1Duration: 120
                property int fade2Duration: 360

                NumberAnimation {
                    target: ripCircle2
                    property: "scale"
                    from: 1.0
                    to: ripCircle2.maxScale
                    duration: animRip2.totalDuration
                    easing.type: Easing.OutQuad
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: ripCircle2
                        property: "opacity"
                        from: ripCircle2.peakOpacity
                        to: ripCircle2.peakOpacity * 0.6
                        duration: animRip2.fade1Duration
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: ripCircle2
                        property: "opacity"
                        from: ripCircle2.peakOpacity * 0.6
                        to: 0.0
                        duration: animRip2.fade2Duration
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }

        // Anillo base que vibra continuamente con la energía instantánea del sonido
        Rectangle {
            id: ripBaseRing
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: root.rippleRadius
            color: "transparent"
            border.color: root.dominantColor
            border.width: 1.0
            scale: 1.0 + (root.effectiveBeat * 0.22 * Math.max(0.1, root.rippleSens))
            opacity: root.effectiveBeat > 0.15 ? Math.min(0.65, (root.effectiveBeat - 0.15) * 0.9 * Math.min(1.5, root.rippleSens)) : 0.0
            Behavior on scale { NumberAnimation { duration: Math.round(60 * Math.max(0.5, root.ripplePersistence)); easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: Math.round(80 * Math.max(0.5, root.ripplePersistence)); easing.type: Easing.OutQuad } }
        }
    }

    // ------------------------------------ Resplandor reactivo exterior (Glow)
    Rectangle {
        id: coverGlow
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 6
        radius: root.artRadius + 3
        color: "transparent"
        border.color: root.dominantColor
        border.width: 1.5
        opacity: (root.reactionActive && (root.reactionMode === 2 || root.reactionMode === 3))
            ? Math.min(0.9, (0.2 + 0.7 * root.effectiveBeat * Math.max(0.1, root.reactionIntensity)))
            : 0.0
        visible: opacity > 0.01
        z: -1
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    // ------------------------------------ Cara A (Frontal)
    Item {
        id: faceA
        anchors.fill: parent
        visible: root.normalizedAngle <= 90 || root.normalizedAngle >= 270
        property string artSource: ""
        readonly property bool hasArt: artSource.length > 0
        readonly property bool isReady: artImgA.status === Image.Ready

        Connections {
            target: artImgA
            function onStatusChanged() {
                if (root.targetFace === 0 && !root.flipInProgress && !root.targetReady) {
                    if (String(artImgA.source) === root.targetArt) {
                        if (artImgA.status === Image.Ready || artImgA.status === Image.Error) {
                            root.targetReady = true;
                            root.doStartFlip();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.artRadius
            color: (artImgA.status === Image.Ready ? "transparent" : Qt.rgba(1, 1, 1, 0.08))

            Image {
                id: artImgA
                anchors.fill: parent
                source: faceA.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.max(512, root.sourceSize * 2)
                sourceSize.height: Math.max(512, root.sourceSize * 2)
                mipmap: true
                smooth: true
                visible: false
                antialiasing: true
            }

            Item {
                id: artMaskA
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(512, 512)
                Rectangle {
                    width: 512
                    height: 512
                    radius: Math.round(root.artRadius * 512 / Math.max(1, parent.width))
                    scale: parent.width / 512
                    transformOrigin: Item.TopLeft
                    color: "#ffffff"
                    antialiasing: true
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: artImgA
                maskEnabled: true
                maskSource: artMaskA
                visible: artImgA.status === Image.Ready
                antialiasing: true
            }

            Text {
                anchors.centerIn: parent
                visible: !faceA.hasArt || artImgA.status === Image.Error
                text: "󰝚"
                color: root.placeholderColor
                font { family: root.fontFam; pixelSize: root.iconSize }
            }
        }
    }

    // ------------------------------------ Cara B (Reverso)
    Item {
        id: faceB
        anchors.fill: parent
        visible: root.normalizedAngle > 90 && root.normalizedAngle < 270
        property string artSource: ""
        readonly property bool hasArt: artSource.length > 0
        readonly property bool isReady: artImgB.status === Image.Ready

        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: -1
        }

        Connections {
            target: artImgB
            function onStatusChanged() {
                if (root.targetFace === 1 && !root.flipInProgress && !root.targetReady) {
                    if (String(artImgB.source) === root.targetArt) {
                        if (artImgB.status === Image.Ready || artImgB.status === Image.Error) {
                            root.targetReady = true;
                            root.doStartFlip();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.artRadius
            color: (artImgB.status === Image.Ready ? "transparent" : Qt.rgba(1, 1, 1, 0.08))

            Image {
                id: artImgB
                anchors.fill: parent
                source: faceB.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.max(512, root.sourceSize * 2)
                sourceSize.height: Math.max(512, root.sourceSize * 2)
                mipmap: true
                smooth: true
                visible: false
                antialiasing: true
            }

            Item {
                id: artMaskB
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(512, 512)
                Rectangle {
                    width: 512
                    height: 512
                    radius: Math.round(root.artRadius * 512 / Math.max(1, parent.width))
                    scale: parent.width / 512
                    transformOrigin: Item.TopLeft
                    color: "#ffffff"
                    antialiasing: true
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: artImgB
                maskEnabled: true
                maskSource: artMaskB
                visible: artImgB.status === Image.Ready
                antialiasing: true
            }

            Text {
                anchors.centerIn: parent
                visible: !faceB.hasArt || artImgB.status === Image.Error
                text: "󰝚"
                color: root.placeholderColor
                font { family: root.fontFam; pixelSize: root.iconSize }
            }
        }
    }

    // ------------------------------------ Onda sobre la carátula (Overlay opcional)
    Item {
        id: coverWaveOverlay
        visible: root.waveOverlay && root.reactionActive
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 2
        width: parent.width - 4
        height: 10
        z: 10
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.6)
        }

        Row {
            anchors.centerIn: parent
            spacing: 1.5
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 2
                    readonly property real lvl: {
                        if (root.reactionActive) {
                            var b = root.effectiveBeat;
                            if (index === 0) return 0.35 + b * 0.55;
                            if (index === 1) return 0.55 + b * 0.45;
                            if (index === 2) return 0.40 + b * 0.60;
                            return 0.25 + b * 0.45;
                        }
                        return 0.2;
                    }
                    height: Math.max(2, Math.min(8, Math.round(lvl * 8)))
                    radius: 1
                    color: root.waveColor
                    anchors.bottom: parent.bottom
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }
}
