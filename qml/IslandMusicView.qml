import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

FocusScope {
    id: view
    property var sys

    implicitWidth: 430
    implicitHeight: col.implicitHeight + 20

    function goBack() {
        if (sys && sys.musicIslandReturnPage && sys.musicIslandReturnPage.length > 0) {
            var target = sys.musicIslandReturnPage;
            sys.musicIslandReturnPage = "";
            sys.openSub(target);
            return true;
        }
        return false;
    }

    property bool lyricsOpen: (sys && sys.mediaLyricsOpen !== undefined) ? sys.mediaLyricsOpen : false

    focus: true
    Keys.onEscapePressed: {
        if (view.lyricsOpen) {
            if (sys && sys.toggleMediaLyrics) sys.toggleMediaLyrics();
            else view.lyricsOpen = false;
        } else if (!view.goBack()) {
            sys.collapse();
        }
    }
    Keys.onSpacePressed: if (sys.player) sys.player.togglePlaying()

    readonly property var p: sys.player
    readonly property real dur: p ? Math.max(0, p.length) : 0
    readonly property bool usable: p !== null && dur > 0 && p.positionSupported && p.canSeek

    property real pos: 0
    property bool dragging: false
    property bool primed: false

    // Цвета обложки
    readonly property color col1: sys.mediaArtColor
    readonly property color col2: sys.mediaArtColor2 || Qt.darker(sys.mediaArtColor, 1.4)
    readonly property bool isWhiteWave: false
    readonly property bool isMonochromeArt: (sys && sys.isMonochromeArt !== undefined) ? sys.isMonochromeArt : (view.col1 == "#ffffff" || (view.col1 && view.col1.hslSaturation !== undefined && view.col1.hslSaturation <= 0.08))

    // Энергия бита из cava
    readonly property real beatEnergy: {
        if (!CavaSource.hasCava || CavaSource.levels.length < 3) return 0.08;
        var b = (CavaSource.levels[0] * 0.55 + CavaSource.levels[1] * 0.35 + CavaSource.levels[2] * 0.15);
        return Math.max(0, Math.min(1.0, b));
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        var s = Math.floor(sec);
        var m = Math.floor(s / 60), x = s % 60;
        return m + ":" + (x < 10 ? "0" : "") + x;
    }

    Behavior on pos {
        enabled: view.primed && !view.dragging
        NumberAnimation { duration: 520; easing.type: Easing.Linear }
    }

    Timer {
        interval: 500
        repeat: true
        running: view.visible && view.p !== null
        triggeredOnStart: true
        onTriggered: {
            if (!view.p) return;
            view.p.positionChanged();
            if (view.dragging) return;
            view.pos = view.p.position;
            view.primed = true;
        }
    }

    Connections {
        target: view.p
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            view.dragging = false;
            view.primed = false;
            view.pos = 0;
        }
    }

    // ------------------------------------------------------------- ФОНОВЫЙ ГРАДИЕНТ
    // Как в iOS Dynamic Island (фото 2):
    // Верхняя половина (обложка + название) — глубокий чистый чёрный (#000000).
    // Нижняя половина (от кнопок воспроизведения вниз) — светящаяся анимированная
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        spacing: 14

        // ------------------------------------ Ряд 1 (Верх): Обложка + Инфо + Эквалайзер (на чистом чёрном фоне)
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56

                FlipArt {
                    anchors.fill: parent
                    artRadius: 13
                    trackKey: sys.mediaArtTrack
                    artSource: sys.effectiveMediaArt || sys.mediaArt
                    placeholderColor: sys.colMuted
                    fontFam: sys.fontFam
                    iconSize: 22
                    sourceSize: 256

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (view.p) view.p.togglePlaying()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: view.p ? String(view.p.trackTitle || "—") : "—"
                    color: "#ffffff"
                    elide: Text.ElideRight
                    font { family: sys.fontFam; pixelSize: 15; bold: true }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.p ? String(view.p.trackArtist || view.p.trackAlbum || "—") : "—"
                    color: Qt.rgba(1, 1, 1, 0.65)
                    elide: Text.ElideRight
                    font { family: sys.fontFam; pixelSize: 12 }
                }

                RowLayout {
                    spacing: 5
                    Layout.topMargin: 1
                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: view.isMonochromeArt ? "#ffffff" : view.col1
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Text {
                        text: view.p ? String(view.p.identity || "Spotify") : "Spotify"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font { family: sys.fontFam; pixelSize: 10; bold: true }
                    }
                }
            }

            WaveBars {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                barCount: 8
                gap: 2.5
                barColor: "#ffffff"
                active: view.p ? view.p.isPlaying : false
            }

            Rectangle {
                id: backBtn
                visible: !!(sys && sys.musicIslandReturnPage && sys.musicIslandReturnPage.length > 0)
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 14
                color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    color: backMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
                    font { family: sys.fontFam; pixelSize: 15 }
                }

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.goBack()
                }
            }
        }

        // ------------------------------------ Ряд 2 (Центр): Кнопки управления (как в фото 2)
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 22

            Item { Layout.fillWidth: true }

            // Предыдущий трек
            Rectangle {
                id: prevBtn
                readonly property bool isM3: !!(sys && sys.themeMaterial)
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 21
                color: prevMa.containsMouse
                       ? (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.20) : (isM3 ? Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.22) : Qt.rgba(1, 1, 1, 0.18)))
                       : (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.08) : (isM3 ? Qt.rgba(sys.colFg.r, sys.colFg.g, sys.colFg.b, 0.08) : "transparent"))
                border.color: isM3 ? (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.15)) : "transparent"
                border.width: isM3 ? 1 : 0
                scale: prevMa.pressed ? 0.94 : (prevMa.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    color: view.isMonochromeArt ? (prevMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)) : (prevMa.containsMouse ? (prevBtn.isM3 ? sys.colOn : "#ffffff") : Qt.rgba(1, 1, 1, 0.88))
                    font { family: sys.fontFam; pixelSize: 22 }
                }

                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (view.p) view.p.previous()
                }
            }

            // Воспроизведение / Пауза (Material 3 FAB o iOS Dynamic Island según tema)
            Rectangle {
                id: playBtn
                readonly property bool isM3: !!(sys && sys.themeMaterial)
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                radius: 25
                color: view.isMonochromeArt
                       ? (playMa.pressed ? Qt.rgba(1, 1, 1, 0.82) : (playMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92)))
                       : (isM3
                          ? (playMa.pressed ? Qt.darker(sys.colOn, 1.25) : (playMa.containsMouse ? Qt.lighter(sys.colOn, 1.12) : sys.colOn))
                          : (playMa.pressed ? Qt.rgba(1, 1, 1, 0.22) : (playMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")))
                border.color: isM3 ? "transparent" : (playMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : "transparent")
                border.width: 1
                scale: playMa.pressed ? 0.94 : (playMa.containsMouse ? 1.04 : 1.0)

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: (view.p && view.p.isPlaying) ? 0 : 2
                    text: (view.p && view.p.isPlaying) ? "󰏤" : "󰐊"
                    color: view.isMonochromeArt ? "#141218" : (playBtn.isM3 ? (sys.colM3OnPrimary || "#381e72") : "#ffffff")
                    font { family: sys.fontFam; pixelSize: 28; bold: true }
                }

                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (view.p) view.p.togglePlaying()
                }
            }

            // Следующий трек
            Rectangle {
                id: nextBtn
                readonly property bool isM3: !!(sys && sys.themeMaterial)
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 21
                color: nextMa.containsMouse
                       ? (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.20) : (isM3 ? Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.22) : Qt.rgba(1, 1, 1, 0.18)))
                       : (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.08) : (isM3 ? Qt.rgba(sys.colFg.r, sys.colFg.g, sys.colFg.b, 0.08) : "transparent"))
                border.color: isM3 ? (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.15)) : "transparent"
                border.width: isM3 ? 1 : 0
                scale: nextMa.pressed ? 0.94 : (nextMa.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    color: view.isMonochromeArt ? (nextMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)) : (nextMa.containsMouse ? (nextBtn.isM3 ? sys.colOn : "#ffffff") : Qt.rgba(1, 1, 1, 0.88))
                    font { family: sys.fontFam; pixelSize: 22 }
                }

                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (view.p) view.p.next()
                }
            }

            // Botón interactivo de letras (󰎆)
            Rectangle {
                id: lyricsBtn
                readonly property bool isM3: !!(sys && sys.themeMaterial)
                readonly property bool active: view.lyricsOpen
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: active
                       ? (view.isMonochromeArt
                          ? (lyricsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.25))
                          : (isM3 ? sys.colOn : Qt.rgba(view.col1.r, view.col1.g, view.col1.b, 0.35)))
                       : (lyricsMa.containsMouse
                          ? (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.20) : (isM3 ? Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.22) : Qt.rgba(1, 1, 1, 0.18)))
                          : (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.08) : (isM3 ? Qt.rgba(sys.colFg.r, sys.colFg.g, sys.colFg.b, 0.08) : Qt.rgba(1, 1, 1, 0.06))))
                border.color: active
                              ? (view.isMonochromeArt ? "#ffffff" : (isM3 ? sys.colOn : Qt.rgba(view.col1.r, view.col1.g, view.col1.b, 0.60)))
                              : (view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.15) : (isM3 ? Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.15) : Qt.rgba(1, 1, 1, 0.12)))
                border.width: 1
                scale: lyricsMa.pressed ? 0.94 : (lyricsMa.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: lyricsBtn.active
                           ? (view.isMonochromeArt
                              ? "#ffffff"
                              : (lyricsBtn.isM3 ? (sys.colM3OnPrimary || "#ffffff") : "#ffffff"))
                           : (view.isMonochromeArt ? (lyricsMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)) : (lyricsMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.82)))
                    font { family: sys.fontFam; pixelSize: 18 }
                }

                MouseArea {
                    id: lyricsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.toggleMediaLyrics) {
                            view.sys.toggleMediaLyrics();
                        } else {
                            view.lyricsOpen = !view.lyricsOpen;
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ------------------------------------ Ряд 3 (Низ): Полоса перемотки (Squiggly Wave M3 / Classic)
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 10

            // Текущее время
            Text {
                text: view.fmt(view.pos)
                color: view.isMonochromeArt ? "#ffffff" : (progressBar.isM3 ? sys.colFg : (view.isWhiteWave ? "#000000" : Qt.rgba(1, 1, 1, 0.85)))
                font { family: sys.fontFam; pixelSize: 11; bold: true }
                Layout.preferredWidth: 32
                Behavior on color { ColorAnimation { duration: 220 } }
            }

            // Scrubber: Modo Material 3 (Squiggly Wave animada) o Modo Classic / Nothing
            Item {
                id: progressBar
                readonly property bool isM3: !!(sys && sys.themeMaterial)
                Layout.fillWidth: true
                Layout.preferredHeight: isM3 ? 24 : 14

                readonly property real frac: view.dur > 0 ? Math.max(0, Math.min(1, view.pos / view.dur)) : 0
                readonly property bool isNeg: view.isWhiteWave

                readonly property color barCoreColor: view.isMonochromeArt ? "#ffffff" : (isNeg ? "#000000" : "#ffffff")
                readonly property color barGlowColor: view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.35) : (isNeg ? Qt.rgba(0, 0, 0, 0.40) : "#ffffff")
                readonly property color trackBgColor: view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.16) : (isNeg ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.18))
                readonly property color scrubberRingColor: view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.45) : (isNeg ? Qt.rgba(0, 0, 0, 0.50) : Qt.rgba(1, 1, 1, 0.45))

                // ============================================ CLÁSICO / NOTHING
                // Halo / Bloom fino y sutil
                Rectangle {
                    id: outerGlow
                    visible: !progressBar.isM3 && width > 2
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width * progressBar.frac)
                    height: barMa.containsMouse || view.dragging ? 6 : 4
                    radius: height / 2
                    color: progressBar.barGlowColor
                    opacity: progressBar.isNeg ? 0.20 : (view.p && view.p.isPlaying ? (0.35 + view.beatEnergy * 0.15) : 0.20)
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 8 }
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Behavior on height { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                // Pista de fondo clásica
                Rectangle {
                    visible: !progressBar.isM3
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: barMa.containsMouse || view.dragging ? 4 : 3
                    radius: height / 2
                    color: progressBar.trackBgColor
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Behavior on height { NumberAnimation { duration: 120 } }

                    Rectangle {
                        width: parent.width * progressBar.frac
                        height: parent.height
                        radius: parent.radius
                        color: progressBar.barCoreColor
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }

                // Cabezal clásico
                Item {
                    id: scrubberHead
                    visible: !progressBar.isM3 && view.usable
                    x: Math.max(0, Math.min(progressBar.width - width, progressBar.width * progressBar.frac - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: barMa.containsMouse || view.dragging ? 12 : 8
                    height: width

                    Behavior on width { NumberAnimation { duration: 120 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 4
                        height: width
                        radius: width / 2
                        color: progressBar.barGlowColor
                        opacity: progressBar.isNeg ? 0.25 : (view.p && view.p.isPlaying ? 0.40 : 0.20)
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 6 }
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: width
                        radius: width / 2
                        color: progressBar.barCoreColor
                        border.color: progressBar.scrubberRingColor
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 220 } }
                        Behavior on border.color { ColorAnimation { duration: 220 } }
                    }
                }

                // ============================================ MATERIAL DESIGN 3 (SQUIGGLY WAVE)
                // Pista de fondo estilo píldora M3
                Rectangle {
                    visible: progressBar.isM3
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    radius: 2.5
                    color: view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(sys.colFg.r, sys.colFg.g, sys.colFg.b, 0.18)
                }

                // Onda sinusoidal viva M3 (Squiggly Wave animada al reproducir, relajándose a recta al pausar)
                Canvas {
                    id: m3Squiggly
                    visible: progressBar.isM3
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject

                    property real progressX: parent.width * progressBar.frac
                    property real phase: 0
                    readonly property real maxAmp: 7.0
                    property real targetAmp: (view.p && view.p.isPlaying && !view.dragging) ? maxAmp : 0.0
                    property real currentAmp: targetAmp
                    Behavior on currentAmp {
                        NumberAnimation {
                            duration: (view.p && view.p.isPlaying) ? 420 : 560
                            easing.type: Easing.OutCubic
                        }
                    }

                    onProgressXChanged: requestPaint()
                    onCurrentAmpChanged: requestPaint()
                    onPhaseChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    Timer {
                        interval: 22
                        // Continúa corriendo mientras reproduzca O mientras se relaje la onda hasta quedar recta (currentAmp > 0.02)
                        running: progressBar.isM3 && view.visible && ((view.p && view.p.isPlaying) || m3Squiggly.currentAmp > 0.02) && !view.dragging
                        repeat: true
                        onTriggered: {
                            // Se desacelera suavemente conforme se relaja
                            var speedRatio = Math.max(0.20, m3Squiggly.currentAmp / m3Squiggly.maxAmp);
                            m3Squiggly.phase += 0.09 * speedRatio;
                            m3Squiggly.requestPaint();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0 || progressX <= 0) return;
                        var cy = height / 2;
                        ctx.lineWidth = 5;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.strokeStyle = view.isMonochromeArt ? "#ffffff" : sys.colOn;
                        ctx.beginPath();
                        var cycleLen = 28.0; // Longitud de onda sinusoidal orgánica estilo Android 13/14
                        var freq = (Math.PI * 2) / cycleLen;
                        var step = 1.5;
                        var px = Math.min(width, progressX);
                        for (var x = 0; x <= px; x += step) {
                            var taper = Math.min(1.0, Math.min(x / 8.0, (px - x) / 10.0));
                            if (taper < 0) taper = 0;
                            var y = cy + (currentAmp * taper) * Math.sin(x * freq - phase);
                            if (x === 0) ctx.moveTo(x, y);
                            else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }

                // Cabezal M3 en forma de pastilla redondeada vertical
                Item {
                    id: m3Thumb
                    visible: progressBar.isM3 && view.usable
                    x: Math.max(0, Math.min(progressBar.width - width, progressBar.width * progressBar.frac - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: barMa.containsMouse || view.dragging ? 6 : 4
                    height: barMa.containsMouse || view.dragging ? 22 : 16

                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: width / 2
                        color: view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.35) : sys.colOn
                        opacity: barMa.containsMouse || view.dragging ? 0.35 : 0.18
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 6 }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: view.isMonochromeArt ? "#ffffff" : sys.colOn
                    }
                }

                MouseArea {
                    id: barMa
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    enabled: view.usable
                    cursorShape: view.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: mouse => {
                        view.dragging = true;
                        view.pos = Math.max(0, Math.min(1, mouse.x / width)) * view.dur;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        view.pos = Math.max(0, Math.min(1, mouse.x / width)) * view.dur;
                    }
                    onReleased: mouse => {
                        if (view.usable && view.p) {
                            view.p.position = view.pos;
                        }
                        view.dragging = false;
                    }
                    onCanceled: view.dragging = false
                }
            }

            // Оставшееся время
            Text {
                text: view.dur > 0 ? ("-" + view.fmt(Math.max(0, view.dur - view.pos))) : "--:--"
                color: view.isMonochromeArt ? Qt.rgba(1, 1, 1, 0.65) : (progressBar.isM3 ? sys.colFg : (view.isWhiteWave ? "#000000" : Qt.rgba(1, 1, 1, 0.85)))
                font { family: sys.fontFam; pixelSize: 11; bold: true }
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                Behavior on color { ColorAnimation { duration: 220 } }
            }
        }

        // ------------------------------------ Ряд 4 (Низ): Visor de letras estilo SpicyLyrics
        SpicyLyricsView {
            id: spicyLyrics
            Layout.fillWidth: true
            Layout.preferredHeight: view.lyricsOpen ? (sys && sys.cfg && sys.cfg.islandLyricsHeight !== undefined ? sys.cfg.islandLyricsHeight : 240) : 0 // Layout.preferredHeight: view.lyricsOpen ? 240 : 0
            visible: view.lyricsOpen || Layout.preferredHeight > 0.5
            opacity: view.lyricsOpen ? 1.0 : 0.0
            active: view.lyricsOpen
            sys: view.sys
            player: view.p
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: view.lyricsOpen ? 340 : 280
                    easing.type: view.lyricsOpen ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1.05
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
