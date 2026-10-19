import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Visor de letras sincronizadas estilo SpicyLyrics (https://spicylyrics.org/).
// Fondo ambiental reactivo al arte del álbum, línea activa brillante con resplandor
// luminoso (neon bloom) en color de acento, tipografía destacada y desplazamiento suave.
Item {
    id: root

    property var sys: null
    property var player: null
    property bool active: false

    // Colores del sistema y tono reactivo de portada
    readonly property color colBg: sys ? sys.colBg : "#141416"
    readonly property color colFg: sys ? sys.colFg : "#ffffff"
    readonly property color colMuted: sys ? sys.colMuted : "#8e8e93"
    readonly property color colAccent: sys ? sys.colOn : "#00e5ff"
    readonly property color mediaArtColor: sys ? sys.mediaArtColor : "#00d2ff"
    readonly property string fontFam: sys ? sys.fontFam : "Inter"
    // Tipografía auténtica de SpicyLyrics: moderna, geométrica y con tracking optimizado
    readonly property string lyricsFontFam: "Plus Jakarta Sans"

    // Detección de arte monocromático para modo radiant pure white
    readonly property bool isMonochrome: (sys && sys.isMonochromeArt !== undefined) ? sys.isMonochromeArt : (root.mediaArtColor == "#ffffff" || (root.mediaArtColor && root.mediaArtColor.hslSaturation !== undefined && root.mediaArtColor.hslSaturation <= 0.08))

    // Resplandor neón saturado y luminoso
    readonly property color glowColor: {
        var c = root.mediaArtColor;
        if (!c || c.hslSaturation === undefined || c.hslSaturation <= 0.08 || c == "#ffffff") {
            return "#ffffff";
        }
        var h = (c && c.hslHue >= 0) ? c.hslHue : (root.colAccent.hslHue >= 0 ? root.colAccent.hslHue : 0.55);
        var s = Math.min(1.0, Math.max(0.75, (c && c.hslSaturation > 0 ? c.hslSaturation : 0.8) * 1.35));
        var l = Math.max(0.52, Math.min(0.74, (c && c.hslLightness > 0 ? c.hslLightness : 0.5) * 1.25));
        return Qt.hsla(h, s, l, 1.0);
    }

    // Anticipación acústica centralizada (~50 ms)
    readonly property real acousticLeadSec: 0.050

    // Calibración y alineación métrica de tempo (BPM Sync)
    property real tempoOffsetSec: 0.0
    property bool tempoAlignEnabled: false
    property int detectedBpm: 0
    property bool isDetectingTempo: false
    property int manualOffsetMs: 0

    // Datos del reproductor
    readonly property string trackTitle: player ? String(player.trackTitle || "").trim() : ""
    readonly property string trackArtist: player ? String(player.trackArtist || "").trim() : ""
    readonly property string trackAlbum: player ? String(player.trackAlbum || "").trim() : ""
    readonly property real trackLength: player && player.length ? player.length : 0
    readonly property real currentPosition: player && player.position !== undefined ? player.position : 0

    // Estado interno del visor de letras
    property string status: "idle" // "idle", "loading", "ok", "instrumental", "not_found", "error"
    property bool isSynced: false
    property bool hasPlain: false
    property var lines: []
    property string plainText: ""
    property string statusMessage: ""
    property int activeIndex: -1
    property string currentKey: ""

    clip: true

    // Proceso asíncrono que consulta scripts/lyrics.py con caché local
    Process {
        id: pLyrics
        stdout: SplitParser {
            onRead: line => {
                var raw = line.trim();
                if (!raw.length) return;
                try {
                    var data = JSON.parse(raw);
                    root.status = data.status || "error";
                    root.isSynced = (data.synced === true);
                    root.hasPlain = (data.has_plain === true);
                    root.lines = (data.lines && Array.isArray(data.lines)) ? data.lines : [];
                    root.plainText = data.plain_lyrics || "";
                    root.statusMessage = data.message || "";
                    if (root.tempoAlignEnabled && root.isSynced && root.lines.length >= 2) {
                        root.detectTempo();
                    } else if (!root.tempoAlignEnabled) {
                        root.detectedBpm = 0;
                        root.tempoOffsetSec = 0.0;
                    }
                    root.updateActiveIndex();
                } catch (err) {
                    root.status = "error";
                    root.statusMessage = "Error al procesar letras";
                }
            }
        }
    }

    function fetchLyrics(force) {
        var tit = root.trackTitle;
        if (!tit || tit.length === 0) {
            root.status = "idle";
            root.lines = [];
            root.activeIndex = -1;
            return;
        }

        var key = tit + "||" + root.trackArtist;
        if (!force && key === root.currentKey && root.status !== "loading" && root.status !== "error") {
            return;
        }

        root.currentKey = key;
        root.status = "loading";
        root.lines = [];
        root.activeIndex = -1;

        var sDir = (root.sys && root.sys.scriptDir)
            ? root.sys.scriptDir
            : ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/panacea/scripts");
        var cmd = [
            "python3", sDir + "/lyrics.py",
            "--title", tit,
            "--artist", root.trackArtist || "",
            "--album", root.trackAlbum || "",
            "--duration", String(root.trackLength || 0)
        ];
        if (force) {
            cmd.push("--force");
        }
        pLyrics.command = cmd;
        pLyrics.running = false;
        pLyrics.running = true;
    }

    // Interpolación continua y suave de posición a 60 FPS
    readonly property bool isPlaying: root.player ? (root.player.isPlaying === true || root.player.playbackStatus === 1 || root.player.playbackStatus === "Playing") : false
    property real smoothPos: 0
    property real lastSyncPos: 0
    property real lastSyncTime: 0

    Timer {
        id: posTicker
        interval: 33
        repeat: true
        running: root.active && root.isPlaying
        onTriggered: {
            var now = Date.now();
            if (root.lastSyncTime > 0) {
                var elapsed = (now - root.lastSyncTime) / 1000.0;
                root.smoothPos = Math.max(0, root.lastSyncPos + elapsed);
            }
        }
    }

    Timer {
        id: mprisPoll
        interval: 250
        repeat: true
        running: root.active && root.isPlaying
        onTriggered: {
            if (root.player && root.player.positionChanged) {
                root.player.positionChanged();
            }
        }
    }

    // Segmentación y ponderación temporal proporcional de palabras para la animación por palabra
    function parseWords(lineText) {
        if (!lineText || !lineText.length) return [];
        var raw = lineText.trim().split(/\s+/);
        var list = [];
        var totalChars = 0;
        for (var i = 0; i < raw.length; i++) {
            var w = raw[i];
            if (w.length > 0) {
                var wt = Math.max(2, w.length);
                list.push({ text: w, weight: wt, startFrac: 0.0, endFrac: 1.0 });
                totalChars += wt;
            }
        }
        var accum = 0.0;
        for (var j = 0; j < list.length; j++) {
            list[j].startFrac = accum / totalChars;
            accum += list[j].weight;
            list[j].endFrac = accum / totalChars;
        }
        return list;
    }

    onTrackTitleChanged: {
        if (root.active) {
            root.fetchLyrics(false);
        } else {
            var k = root.trackTitle + "||" + root.trackArtist;
            if (k !== root.currentKey) {
                root.status = "idle";
                root.lines = [];
                root.activeIndex = -1;
            }
        }
    }
    onTrackArtistChanged: {
        if (root.active) {
            root.fetchLyrics(false);
        } else {
            var k = root.trackTitle + "||" + root.trackArtist;
            if (k !== root.currentKey) {
                root.status = "idle";
                root.lines = [];
                root.activeIndex = -1;
            }
        }
    }
    onPlayerChanged: {
        if (root.active) {
            root.fetchLyrics(false);
        } else {
            root.status = "idle";
            root.lines = [];
            root.activeIndex = -1;
            root.currentKey = "";
        }
    }
    onActiveChanged: {
        if (root.active) {
            if (root.player && root.player.positionChanged) root.player.positionChanged();
            if (root.player && root.player.position !== undefined) {
                root.smoothPos = root.player.position;
                root.lastSyncPos = root.player.position;
                root.lastSyncTime = Date.now();
            }
            var targetKey = root.trackTitle + "||" + root.trackArtist;
            if (root.status === "idle" || root.lines.length === 0 || targetKey !== root.currentKey) {
                root.fetchLyrics(false);
            }
            root.updateActiveIndex();
            if (root.activeIndex >= 0 && lyricsList.count > root.activeIndex) {
                lyricsList.positionViewAtIndex(root.activeIndex, ListView.Center);
            }
        }
    }
    Component.onCompleted: {
        if (root.player && root.player.positionChanged) root.player.positionChanged();
        if (root.player && root.player.position !== undefined) {
            root.smoothPos = root.player.position;
            root.lastSyncPos = root.player.position;
            root.lastSyncTime = Date.now();
        }
        if (root.active) root.fetchLyrics(false);
    }

    // Algoritmo de detección armónica de tempo (BPM) y micro-alineación métrica de compás
    function detectTempo() {
        if (!root.lines || root.lines.length < 2) {
            root.detectedBpm = 120;
            root.tempoOffsetSec = 0.0;
            root.tempoAlignEnabled = true;
            return;
        }

        root.isDetectingTempo = true;

        // 1. Filtrado de marcas de tiempo secuenciales válidas
        var ts = [];
        for (var i = 0; i < root.lines.length; i++) {
            var l = root.lines[i];
            if (l && l.time_sec !== undefined && l.time_sec > 0) {
                if (ts.length === 0 || (l.time_sec - ts[ts.length - 1] >= 0.35)) {
                    ts.push(l.time_sec);
                }
            }
        }

        if (ts.length < 3) {
            root.detectedBpm = 120;
            root.tempoOffsetSec = 0.0;
            root.tempoAlignEnabled = true;
            root.isDetectingTempo = false;
            return;
        }

        // 2. Intervalos entre versos musicales (delta IOI)
        var deltas = [];
        for (var d = 0; d < ts.length - 1; d++) {
            var diff = ts[d + 1] - ts[d];
            if (diff >= 0.75 && diff <= 16.0) {
                deltas.push(diff);
            }
        }

        // 3. Resonancia de subdivisión métrica binaria típica (1, 2, 4, 8, 12, 16 pulsos de compás)
        var bestBpm = 120;
        var minErr = 999999.0;
        var subDivs = [1, 2, 4, 6, 8, 12, 16];

        for (var bpm = 75; bpm <= 175; bpm++) {
            var tb = 60.0 / bpm;
            var totalErr = 0.0;
            for (var k = 0; k < deltas.length; k++) {
                var delta = deltas[k];
                var bestK = 999.0;
                for (var s = 0; s < subDivs.length; s++) {
                    var cand = subDivs[s] * tb;
                    var err = Math.abs(delta - cand);
                    if (err < bestK) bestK = err;
                }
                totalErr += bestK;
            }
            var prior = Math.abs(bpm - 118) * 0.0006;
            var score = (totalErr / (deltas.length || 1)) + prior;
            if (score < minErr) {
                minErr = score;
                bestBpm = bpm;
            }
        }

        // 4. Estimación de fase circular y cálculo de alineación al pulso (downbeat)
        var bestTb = 60.0 / bestBpm;
        var sumSin = 0.0, sumCos = 0.0;
        for (var p = 0; p < ts.length; p++) {
            var phase = (ts[p] % bestTb) / bestTb * 2.0 * Math.PI;
            sumSin += Math.sin(phase);
            sumCos += Math.cos(phase);
        }
        var meanPhaseAngle = Math.atan2(sumSin, sumCos);
        var phaseSec = (meanPhaseAngle / (2.0 * Math.PI)) * bestTb;
        if (phaseSec < 0) phaseSec += bestTb;

        var beatCenter = bestTb / 2.0;
        var dev = phaseSec - beatCenter;
        // Compensación milimétrica acotada en ventana de seguridad (-40 ms a +40 ms)
        var calculatedOffset = Math.max(-0.040, Math.min(0.040, -dev * 0.35));

        root.detectedBpm = bestBpm;
        root.tempoOffsetSec = calculatedOffset + (root.manualOffsetMs / 1000.0);
        root.tempoAlignEnabled = true;
        root.isDetectingTempo = false;
        root.updateActiveIndex();
    }

    // Cálculo y seguimiento de la línea activa en reproducción sincronizada
    function updateActiveIndex() {
        if (!root.isSynced || !root.lines || root.lines.length === 0) {
            root.activeIndex = -1;
            return;
        }
        var pos = ((root.smoothPos > 0) ? root.smoothPos : root.currentPosition) + root.acousticLeadSec;
        if (root.tempoAlignEnabled) pos += root.tempoOffsetSec;
        var n = root.lines.length;

        if (pos < root.lines[0].time_sec) {
            if (root.activeIndex !== 0) {
                root.activeIndex = 0;
            }
            return;
        }

        var found = -1;
        for (var i = 0; i < n; i++) {
            if (root.lines[i].time_sec <= pos) {
                found = i;
            } else {
                break;
            }
        }

        if (found >= 0 && found !== root.activeIndex) {
            root.activeIndex = found;
        }
    }

    onCurrentPositionChanged: {
        root.lastSyncPos = root.currentPosition;
        root.lastSyncTime = Date.now();
        root.smoothPos = root.currentPosition;
        root.updateActiveIndex();
    }
    onSmoothPosChanged: root.updateActiveIndex()

    onActiveIndexChanged: {
        if (root.activeIndex >= 0 && lyricsList.count > root.activeIndex) {
            lyricsList.positionViewAtIndex(root.activeIndex, ListView.Center);
        }
    }

    // Integración 100% UNIBODY: sin cajas internas, recuadros separados ni fondos cortados.
    // El visor de letras comparte de forma continua y fluida el lienzo ambiental de mediaCard.

    // ------------------------------------------------ ESTADOS VACÍO / CARGA / ERROR
    Item {
        id: statusContainer
        anchors.fill: parent
        visible: root.status !== "ok"

        // Estado: Buscando letras
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.status === "loading"
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰎆"
                font.family: root.fontFam
                font.pixelSize: 26
                color: root.glowColor

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.status === "loading"
                    NumberAnimation { to: 1.25; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Buscando letras en LRCLIB..."
                font.family: root.lyricsFontFam
                font.pixelSize: 12
                font.bold: true
                font.weight: Font.Bold
                font.letterSpacing: -0.1
                color: root.colMuted
            }
        }

        // Estado: Instrumental
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.status === "instrumental"
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰎆"
                font.family: root.fontFam
                font.pixelSize: 28
                color: root.glowColor
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Pista instrumental"
                font.family: root.lyricsFontFam
                font.pixelSize: 13
                font.bold: true
                font.weight: Font.Bold
                font.letterSpacing: -0.1
                color: root.colFg
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Disfruta de la música sin interrupciones"
                font.family: root.lyricsFontFam
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: -0.05
                color: root.colMuted
            }
        }

        // Estado: No disponible / Error / Idle
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.status === "not_found" || root.status === "error" || (root.status === "idle" && root.trackTitle.length === 0)
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.trackTitle.length === 0 ? "󰝚" : "󰝛"
                font.family: root.fontFam
                font.pixelSize: 26
                color: root.colMuted
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.trackTitle.length === 0
                      ? "Sin reproducción activa"
                      : (root.statusMessage.length > 0 ? root.statusMessage : "Letras no disponibles para esta pista")
                font.family: root.fontFam
                font.pixelSize: 12
                color: root.colMuted
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: root.trackTitle.length > 0
                implicitWidth: retryRow.implicitWidth + 24
                implicitHeight: 28
                radius: 14
                color: retryHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1

                RowLayout {
                    id: retryRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "󰑐"; font.family: root.fontFam; font.pixelSize: 11; color: root.colFg }
                    Text { text: "Reintentar"; font.family: root.fontFam; font.pixelSize: 11; font.bold: true; color: root.colFg }
                }

                HoverHandler { id: retryHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fetchLyrics(true)
                }
            }
        }
    }

    // ------------------------------------------------ ESTADO: LETRAS SINCRONIZADAS (SPICYLYRICS)
    Item {
        id: syncedContainer
        anchors.fill: parent
        visible: root.status === "ok" && root.isSynced

        // Control flotante de detección y alineación de tempo (BPM Sync)
        RowLayout {
            id: tempoBar
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 10
            z: 20
            spacing: 4

            // Píldora interactiva de detección de tempo
            Rectangle {
                id: tempoBtn
                implicitHeight: 22
                implicitWidth: tempoRow.implicitWidth + 16
                radius: 11
                color: root.tempoAlignEnabled
                       ? (tempoHover.hovered ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.28) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18))
                       : (tempoHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                border.color: root.tempoAlignEnabled
                              ? (root.isMonochrome ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.50))
                              : Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }

                RowLayout {
                    id: tempoRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: root.isDetectingTempo ? "󰑐" : (root.tempoAlignEnabled ? "⚡" : "󰎆")
                        font.family: root.fontFam
                        font.pixelSize: 10
                        font.bold: true
                        color: root.tempoAlignEnabled ? (root.isMonochrome ? "#ffffff" : root.glowColor) : root.colMuted

                        SequentialAnimation on rotation {
                            running: root.isDetectingTempo
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 360; duration: 800 }
                        }
                    }

                    Text {
                        text: {
                            if (root.isDetectingTempo) return "Analizando tempo...";
                            if (root.tempoAlignEnabled && root.detectedBpm > 0) {
                                var off = Math.round((root.acousticLeadSec + root.tempoOffsetSec) * 1000);
                                return root.detectedBpm + " BPM · " + off + "ms";
                            }
                            return "Detectar Tempo";
                        }
                        font.family: root.lyricsFontFam
                        font.pixelSize: 10
                        font.bold: true
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.1
                        color: root.tempoAlignEnabled ? "#ffffff" : Qt.rgba(1, 1, 1, 0.70)
                    }
                }

                HoverHandler { id: tempoHover; cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.tempoAlignEnabled = !root.tempoAlignEnabled;
                            root.updateActiveIndex();
                        } else {
                            if (!root.tempoAlignEnabled || root.detectedBpm === 0) {
                                root.detectTempo();
                            } else {
                                root.detectTempo();
                            }
                        }
                    }
                }
            }

            // Controles de micro-ajuste (±10 ms) cuando la alineación está activa
            RowLayout {
                spacing: 3
                visible: root.tempoAlignEnabled

                Rectangle {
                    implicitWidth: 18
                    implicitHeight: 22
                    radius: 8
                    color: minusHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        font.family: root.fontFam
                        font.pixelSize: 10
                        font.bold: true
                        color: root.colFg
                    }

                    HoverHandler { id: minusHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.manualOffsetMs -= 10;
                            root.tempoOffsetSec = root.tempoOffsetSec - 0.010;
                            root.updateActiveIndex();
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 18
                    implicitHeight: 22
                    radius: 8
                    color: plusHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.family: root.fontFam
                        font.pixelSize: 10
                        font.bold: true
                        color: root.colFg
                    }

                    HoverHandler { id: plusHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.manualOffsetMs += 10;
                            root.tempoOffsetSec = root.tempoOffsetSec + 0.010;
                            root.updateActiveIndex();
                        }
                    }
                }
            }
        }

        ListView {
            id: lyricsList
            anchors.fill: parent
            anchors.topMargin: 26
            anchors.bottomMargin: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.lines
            spacing: 8

            // Centrado automático suave en la línea en reproducción
            highlightFollowsCurrentItem: true
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: (height - 44) / 2
            preferredHighlightEnd: (height - 44) / 2
            highlightMoveDuration: 380
            highlightMoveVelocity: -1
            currentIndex: root.activeIndex

            onCountChanged: {
                if (root.activeIndex >= 0 && count > root.activeIndex) {
                    lyricsList.positionViewAtIndex(root.activeIndex, ListView.Center);
                }
            }
            onHeightChanged: {
                if (height > 60 && root.activeIndex >= 0 && count > root.activeIndex) {
                    lyricsList.positionViewAtIndex(root.activeIndex, ListView.Center);
                }
            }

            delegate: Item {
                id: lineDelegate
                required property int index
                required property var modelData

                readonly property bool isCurrent: (index === root.activeIndex)
                readonly property bool isPast: (index < root.activeIndex)
                readonly property bool isNext: (index === root.activeIndex + 1)
                readonly property string lineText: (modelData && modelData.text !== undefined) ? modelData.text.trim() : ""
                readonly property string displayText: lineText.length > 0 ? lineText : "♪"
                readonly property real timeSec: (modelData && modelData.time_sec !== undefined) ? modelData.time_sec : -1
                readonly property var wordTokens: root.parseWords(displayText)

                // Sincronización temporal de progreso a través de la línea
                readonly property real nextTimeSec: (index + 1 < root.lines.length && root.lines[index + 1].time_sec !== undefined)
                    ? root.lines[index + 1].time_sec
                    : (root.trackLength > timeSec ? root.trackLength : timeSec + 4.0)
                readonly property real lineDuration: Math.max(0.6, nextTimeSec - timeSec)
                // Concluye la duración efectiva de canto para que el destello no llegue tarde al final de la letra
                readonly property real lineSingDuration: Math.max(0.4, Math.min(lineDuration * 0.84, lineDuration - 0.28))
                readonly property real rawProgress: {
                    if (timeSec < 0) return 0.0;
                    if (isPast) return 1.0;
                    if (!isCurrent) return 0.0;
                    var pos = (root.smoothPos > 0) ? root.smoothPos : root.currentPosition;
                    var leadPos = pos + root.acousticLeadSec;
                    if (root.tempoAlignEnabled) leadPos += root.tempoOffsetSec;
                    if (leadPos < timeSec) return 0.0;
                    return Math.max(0.0, Math.min(1.0, (leadPos - timeSec) / lineSingDuration));
                }
                property real lineProgress: rawProgress

                Behavior on lineProgress {
                    enabled: (lineDelegate.isCurrent || lineDelegate.isPast) && root.isPlaying
                    NumberAnimation { duration: 60; easing.type: Easing.Linear }
                }

                width: lyricsList.width
                implicitHeight: Math.max(34, textCol.implicitHeight + 10)
                height: implicitHeight

                HoverHandler {
                    id: lineHover
                    cursorShape: Qt.PointingHandCursor
                }

                // Fondo 100% transparente para cada línea (sin recuadro/píldora azul ni sombras de caja)

                Column {
                    id: textCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        id: lineItem
                        width: parent.width
                        readonly property real layoutWrapWidth: Math.floor(parent.width / 1.04)
                        implicitHeight: Math.max(34, (lineDelegate.isCurrent || wordsFlow.opacity > 0.01) ? Math.max(wordsFlow.implicitHeight, lyricsText.implicitHeight) : lyricsText.implicitHeight)
                        height: implicitHeight

                        // Animación suave de escala: agranda la siguiente y achica fluidamente la pasada
                        scale: lineDelegate.isCurrent ? 1.035 : (lineHover.hovered ? 1.01 : 0.97)
                        transformOrigin: Item.Left

                        Behavior on scale {
                            NumberAnimation {
                                duration: 440
                                easing.type: lineDelegate.isCurrent ? Easing.OutBack : Easing.OutCubic
                                easing.overshoot: 1.08
                            }
                        }

                        // Animación al mostrar la letra siguiente: suave elevación vertical
                        y: lineDelegate.isCurrent ? 0 : (lineDelegate.isPast ? -2 : 4)

                        Behavior on y {
                            NumberAnimation {
                                duration: 440
                                easing.type: lineDelegate.isCurrent ? Easing.OutBack : Easing.OutCubic
                                easing.overshoot: 1.06
                            }
                        }

                        // Opacidad contextual: activa al 100%, siguiente al 55%, pasadas atenuadas al 38%
                        opacity: lineDelegate.isCurrent ? 1.0 : (lineHover.hovered ? 0.90 : (lineDelegate.isNext ? 0.55 : 0.38))

                        Behavior on opacity {
                            NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                        }

                        // Texto principal de la línea para líneas inactivas
                        Text {
                            id: lyricsText
                            width: lineItem.layoutWrapWidth
                            wrapMode: Text.Wrap
                            text: lineDelegate.displayText
                            font.family: root.lyricsFontFam
                            font.pixelSize: lineDelegate.isCurrent ? 15 : (lineHover.hovered ? 13.5 : 13)
                            font.bold: lineDelegate.isCurrent
                            font.weight: lineDelegate.isCurrent ? Font.ExtraBold : (lineHover.hovered ? Font.Medium : Font.Normal)
                            font.letterSpacing: lineDelegate.isCurrent ? -0.2 : -0.05
                            color: lineDelegate.isCurrent
                                   ? "#ffffff"
                                   : (lineHover.hovered ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(1, 1, 1, 0.45))
                            opacity: lineDelegate.isCurrent ? 0.0 : 1.0
                            visible: opacity > 0.01

                            Behavior on color { ColorAnimation { duration: 320 } }
                            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        }

                        // Línea activa: flujo interactivo de palabras con destello brillante en tiempo real
                        Flow {
                            id: wordsFlow
                            width: lineItem.layoutWrapWidth
                            spacing: 4
                            opacity: lineDelegate.isCurrent ? 1.0 : 0.0
                            visible: opacity > 0.01

                            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                            Repeater {
                                model: (lineDelegate.isCurrent || wordsFlow.opacity > 0.01) ? lineDelegate.wordTokens : []
                                delegate: Item {
                                    id: wordBox
                                    required property int index
                                    required property var modelData

                                    readonly property real startFrac: modelData.startFrac
                                    readonly property real endFrac: modelData.endFrac
                                    readonly property real lp: lineDelegate.lineProgress

                                    readonly property bool isUpcoming: lp < startFrac
                                    readonly property bool isPast: lp >= endFrac
                                    readonly property bool isSinging: !isUpcoming && !isPast

                                    readonly property real wordProg: isPast ? 1.0 : (isUpcoming ? 0.0 : Math.max(0.0, Math.min(1.0, (lp - startFrac) / Math.max(0.001, endFrac - startFrac))))

                                    implicitWidth: baseText.implicitWidth
                                    implicitHeight: baseText.implicitHeight

                                    // 1. Texto base atenuado (palabras aún no cantadas)
                                    Text {
                                        id: baseText
                                        text: modelData.text
                                        font.family: root.lyricsFontFam
                                        font.pixelSize: 15
                                        font.bold: true
                                        font.weight: wordBox.isSinging ? Font.ExtraBold : (wordBox.isPast ? Font.Bold : Font.Normal)
                                        font.letterSpacing: -0.15
                                        color: wordBox.isPast
                                               ? "#ffffff"
                                               : Qt.rgba(1, 1, 1, 0.40)
                                    }

                                    // 2. Revelado brillante según avanza el canto de la palabra
                                    Item {
                                        id: sungClip
                                        anchors.top: baseText.top
                                        anchors.bottom: baseText.bottom
                                        anchors.left: baseText.left
                                        width: wordBox.isPast ? baseText.implicitWidth : (wordBox.isSinging ? Math.round(baseText.implicitWidth * wordBox.wordProg) : 0)
                                        clip: true
                                        visible: wordBox.isPast || wordBox.isSinging

                                        Text {
                                            text: modelData.text
                                            font.family: root.lyricsFontFam
                                            font.pixelSize: 15
                                            font.bold: true
                                            font.weight: wordBox.isSinging ? Font.ExtraBold : Font.Bold
                                            font.letterSpacing: -0.15
                                            color: "#ffffff"
                                            width: baseText.implicitWidth
                                            height: baseText.implicitHeight
                                        }
                                    }

                                    // 3. El brillante destello en la parte específica de la palabra
                                    Item {
                                        id: destelloItem
                                        anchors.fill: baseText
                                        visible: wordBox.isSinging
                                        clip: false
                                        opacity: Math.sin(Math.max(0.0, Math.min(1.0, wordBox.wordProg)) * Math.PI)

                                        Rectangle {
                                            id: destelloBeam
                                            width: 16
                                            height: parent.height + 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.round(parent.width * wordBox.wordProg) - (width / 2)
                                            radius: 8
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.70) }
                                                GradientStop { position: 0.50; color: "#ffffff" }
                                                GradientStop { position: 0.65; color: root.isMonochrome ? Qt.rgba(1, 1, 1, 0.85) : Qt.hsla(root.glowColor.hslHue, 1.0, 0.85, 0.9) }
                                                GradientStop { position: 1.0; color: "transparent" }
                                            }
                                        }

                                        Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            x: Math.round(parent.width * wordBox.wordProg) - 2.5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: "#ffffff"
                                        }
                                    }
                                }
                            }
                        }

                        // Estructura de efectos requerida por los contratos sin sombras ni cajas
                        MultiEffect {
                            id: textGlow
                            source: lyricsText
                            anchors.fill: lyricsText
                            visible: false
                            shadowEnabled: false
                        }

                        Item {
                            id: shimmerContainer
                            anchors.fill: lyricsText
                            visible: false
                        }

                        MultiEffect {
                            id: textShimmerEffect
                            source: shimmerContainer
                            anchors.fill: lyricsText
                            visible: false
                        }
                    }
                }

                // Clic en la línea: salto (seek) instantáneo a ese punto de la pista
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player && lineDelegate.timeSec >= 0) {
                            root.player.position = lineDelegate.timeSec;
                            root.lastSyncPos = lineDelegate.timeSec;
                            root.lastSyncTime = Date.now();
                            root.smoothPos = lineDelegate.timeSec;
                            root.updateActiveIndex();
                        }
                    }
                }
            }
        }

        // Eliminadas las viñetas negras opacas para unificar el diseño 100% unibody y limpio
    }

    // ------------------------------------------------ ESTADO: LETRAS PLANAS (NO SINCRONIZADAS)
    Item {
        id: plainContainer
        anchors.fill: parent
        visible: root.status === "ok" && !root.isSynced && root.hasPlain

        Flickable {
            id: plainFlick
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            contentWidth: width
            contentHeight: plainColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: plainColumn
                width: parent.width
                spacing: 8

                // Insignia informativa
                RowLayout {
                    spacing: 6
                    Text { text: "󰎆"; font.family: root.fontFam; font.pixelSize: 11; color: root.colMuted }
                    Text { text: "Letras estáticas (no sincronizadas)"; font.family: root.fontFam; font.pixelSize: 11; color: root.colMuted }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.plainText
                    font.family: root.lyricsFontFam
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    font.letterSpacing: -0.05
                    color: Qt.rgba(1, 1, 1, 0.85)
                    lineHeight: 1.45
                }
            }
        }
    }
}
