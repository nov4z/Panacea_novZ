import QtQuick

// Живой эквалайзер.
//
// Сам спектр не считает: берёт общий поток из CavaSource и усредняет его
// до своего barCount. Благодаря этому раскрытие капсулы в плеер сразу
// показывает настоящий звук — cava уже крутится ради полос в капсуле,
// стартовать заново и мелькать заглушкой больше нечему.
//
// Если cava в системе нет — мягкая синтетическая волна, чтобы капсула не
// выглядела мёртвой. Как только cava установят, он подхватится сам.
Item {
    id: wave

    property color barColor: "#ffffff"
    property bool  active: true
    property int   barCount: 7
    property real  gap: 2
    property real  sensMultiplier: 1.0
    property int   freqMode: 0                 // 0 = Espectro completo, 1 = Graves, 2 = Medios, 3 = Agudos
    property real  persistenceMultiplier: 1.0  // 0.5 a 2.5

    // Морфинг паузы и переходы острова (Dynamic Island)
    property bool  morphPause: false
    property bool  notchEntered: true
    property bool  hovered: false

    property real morphProgress: morphPause ? (active ? 1.0 : 0.0) : 1.0
    Behavior on morphProgress {
        NumberAnimation {
            duration: 320
            easing.type: wave.active ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 1.18
        }
    }

    scale: (notchEntered ? 1.0 : 0.25) * (hovered ? 1.14 : 1.0)
    opacity: notchEntered ? 1.0 : 0.0
    Behavior on scale {
        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.22 }
    }
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // уровни 0..1 для каждой полосы
    property var levels: []

    // ------------------------------------------------------------- настоящий
    // Пока полосы видимы и звучат, держим общий cava живым.
    onActiveChanged: active ? CavaSource.acquire() : CavaSource.release()
    Component.onDestruction: if (active) CavaSource.release()

    property bool hasRealAudio: false
    property real lastRealAudioTime: 0

    // ------------------------------------------------------------- audio real de Cava
    function resample(src) {
        var n = src.length;
        if (n === 0) return;

        // Calcular la energía bruta real del espectro para detectar si realmente suena música
        var rawEnergy = 0;
        for (var s = 0; s < n; s++) {
            var sv = src[s] || 0;
            if (sv > rawEnergy) rawEnergy = sv;
        }

        var hasAudioNow = (rawEnergy > 0.04);
        if (hasAudioNow) {
            wave.hasRealAudio = true;
            wave.lastRealAudioTime = Date.now();
        } else if (Date.now() - wave.lastRealAudioTime > 220) {
            wave.hasRealAudio = false;
        }

        // Si no hay audio real sonando (silencio, pausa, carga), NO pisar la onda fluida sintética
        if (!wave.hasRealAudio) return;

        var startIdx = 0;
        var endIdx = n;
        if (wave.freqMode === 1) {
            startIdx = 0;
            endIdx = Math.max(1, Math.floor(n * 0.40));
        } else if (wave.freqMode === 2) {
            startIdx = Math.floor(n * 0.15);
            endIdx = Math.max(startIdx + 1, Math.floor(n * 0.80));
        } else if (wave.freqMode === 3) {
            startIdx = Math.floor(n * 0.45);
            endIdx = n;
        }

        var span = Math.max(1, endIdx - startIdx);
        var persist = Math.max(0.4, wave.persistenceMultiplier);
        var decayFactor = Math.min(0.94, Math.max(0.35, 0.65 + 0.20 * (persist - 1.0)));

        var a = [];
        for (var i = 0; i < wave.barCount; i++) {
            // Mapeo perceptual armónico: reparte bajos, medios y agudos
            // de forma balanceada a lo largo de toda la barra (0 a barCount-1) sin zonas muertas
            var frac0 = i / wave.barCount;
            var frac1 = (i + 1) / wave.barCount;

            var p0 = Math.pow(frac0, 1.20);
            var p1 = Math.pow(frac1, 1.20);

            var from = Math.min(n - 1, startIdx + Math.floor(p0 * span));
            var to   = Math.min(n, Math.max(from + 1, startIdx + Math.ceil(p1 * span)));

            var sum = 0;
            for (var j = from; j < to; j++) sum += (src[j] || 0);
            var val = sum / Math.max(1, to - from);

            // Realce armónico progresivo para que las frecuencias medias-altas y agudos
            // tengan presencia y animen con vitalidad toda la extensión de la barra
            var eqFactor = 1.0 + 1.15 * Math.pow(frac0, 1.1);
            val *= eqFactor;

            if (wave.freqMode === 2) val *= 1.35;
            else if (wave.freqMode === 3) val *= 1.70;

            // Presencia rítmica viva para agudos: si suena música, la parte derecha siempre baila
            var rhythmicLife = 0.09 * rawEnergy * (0.6 + 0.4 * frac0);
            val = Math.max(val, rhythmicLife);
            val = Math.min(1.0, val);

            var prevVal = (wave.hasRealAudio && wave.levels && wave.levels.length > i) ? wave.levels[i] : 0;
            if (val < prevVal) {
                val = Math.max(val, prevVal * decayFactor);
            }
            a.push(val);
        }
        wave.levels = a;
    }

    Connections {
        target: CavaSource
        enabled: wave.active && CavaSource.hasCava
        function onLevelsChanged() { wave.resample(CavaSource.levels); }
    }

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < barCount; i++) a.push(0.2);
        levels = a;
        if (active) CavaSource.acquire();
        if (CavaSource.hasCava) resample(CavaSource.levels);
    }

    // -------------------------------------------------------------- onda fluida sintética / idle
    Timer {
        // 30 cuadros/segundo: onda continua y fluida como una ola en el agua
        interval: 33
        running: !wave.hasRealAudio && (wave.active || !wave.morphPause)
        repeat: true
        onTriggered: {
            var a = [];
            var isPlaying = wave.active;
            // Si está reproduciendo pero no hay audio de Cava (cargando o segundos finales sin sonido): onda viva
            // Si está en pausa o no hay música: onda suave и relajante
            var t = Date.now() / (isPlaying ? 240 : 340);
            var baseAmp = isPlaying ? 0.44 : 0.30;
            var sinAmp1 = isPlaying ? 0.34 : 0.22;
            var sinAmp2 = isPlaying ? 0.18 : 0.12;
            var minV    = isPlaying ? 0.10 : 0.08;

            for (var i = 0; i < wave.barCount; i++) {
                // Doble sinusoide con desfase armónico para efecto de ola continua y orgánica
                var v = baseAmp + sinAmp1 * Math.sin(t + i * 0.85)
                                + sinAmp2 * Math.sin(t * 1.6 + i * 1.8);
                a.push(Math.max(minV, Math.min(1.0, v)));
            }
            wave.levels = a;
        }
    }

    // Geometría para el morphing a icono de pausa
    readonly property int leftPauseIdx: barCount >= 5 ? 1 : 0
    readonly property int rightPauseIdx: barCount >= 5 ? 3 : Math.max(1, barCount - 1)
    readonly property real normalBarWidth: (wave.width - wave.gap * (Math.max(1, wave.barCount) - 1)) / Math.max(1, wave.barCount)
    readonly property real pauseBarWidth: Math.max(2.6, Math.min(3.8, wave.width * 0.13))
    readonly property real pauseBarGap: Math.max(3.0, Math.min(4.8, wave.width * 0.16))
    readonly property real totalPauseWidth: 2 * pauseBarWidth + pauseBarGap
    readonly property real pauseStartX: (wave.width - totalPauseWidth) / 2
    readonly property real pauseLeftX: pauseStartX
    readonly property real pauseRightX: pauseStartX + pauseBarWidth + pauseBarGap
    readonly property real pauseBarHeight: Math.max(8, wave.height * 0.70)

    Item {
        anchors.fill: parent

        Repeater {
            model: wave.barCount
            Rectangle {
                id: barRect
                required property int index

                readonly property bool isLeftPillar: index === wave.leftPauseIdx
                readonly property bool isRightPillar: index === wave.rightPauseIdx
                readonly property bool isPillar: wave.morphPause && (isLeftPillar || isRightPillar)

                readonly property real normalX: index * (wave.normalBarWidth + wave.gap)
                readonly property real pillarTargetX: isLeftPillar ? wave.pauseLeftX : (isRightPillar ? wave.pauseRightX : normalX)

                x: isPillar ? (normalX * wave.morphProgress + pillarTargetX * (1.0 - wave.morphProgress)) : normalX
                width: isPillar ? (wave.normalBarWidth * wave.morphProgress + wave.pauseBarWidth * (1.0 - wave.morphProgress)) : wave.normalBarWidth
                radius: width / 2
                color: wave.barColor

                property real rawLevel: (wave.levels && wave.levels.length > index) ? (wave.levels[index] || 0.06) : 0.06
                Behavior on rawLevel {
                    NumberAnimation {
                        duration: Math.round(90 * Math.max(0.4, Math.min(2.5, wave.persistenceMultiplier)))
                        easing.type: Easing.OutCubic
                    }
                }

                readonly property real rawWaveHeight: Math.max(2,
                    Math.pow(Math.min(1, barRect.rawLevel * wave.sensMultiplier), 0.6) * wave.height)

                height: isPillar
                    ? (rawWaveHeight * wave.morphProgress + wave.pauseBarHeight * (1.0 - wave.morphProgress))
                    : (rawWaveHeight * wave.morphProgress)

                opacity: isPillar
                    ? ((0.55 + 0.45 * height / Math.max(1, wave.height)) * wave.morphProgress + 0.95 * (1.0 - wave.morphProgress))
                    : ((0.55 + 0.45 * height / Math.max(1, wave.height)) * wave.morphProgress)

                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
