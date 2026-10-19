import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Настольные виджеты темы Nothing и Material You (Android 12/13/14) — карточки поверх обоев.
Item {
    id: view

    property var sys

    readonly property bool isMaterial: !!(view.sys && view.sys.themeMaterial)

    // Ширина колонки и просвет между карточками.
    readonly property real col: isMaterial ? 156 : 144
    readonly property real gap: isMaterial ? 14 : 12
    readonly property real fullW: view.col * 2 + view.gap

    implicitWidth: isMaterial ? m3WidgetsStack.implicitWidth : view.fullW
    implicitHeight: isMaterial ? m3WidgetsStack.implicitHeight : stack.implicitHeight

    // ------------------------------------------------------------------
    // Paleta dinámica Material You sincronizada con el notch
    readonly property bool isMonochromeMedia: {
        if (!view.sys || !view.sys.mediaArtColor) return false;
        if (view.sys.musicIslandActive !== undefined && !view.sys.musicIslandActive) return false;
        var c = view.sys.mediaArtColor;
        return (c.hslSaturation !== undefined && c.hslSaturation <= 0.08);
    }

    // El fondo del widget solo coincide con el fondo del notch en portadas blanco y negro (isMonochromeMedia).
    // De lo contrario, utiliza el color estándar de Material You (superficie / anterior).
    readonly property color widgetBg: view.isMonochromeMedia
        ? ((view.sys && view.sys.currentNotchBg) ? view.sys.currentNotchBg : Qt.rgba(0.08, 0.08, 0.09, 0.98))
        : ((view.sys && view.sys.colM3Surface) ? view.sys.colM3Surface : Qt.rgba(0.13, 0.11, 0.16, 0.94))

    readonly property color m3Burgundy: {
        if (view.isMonochromeMedia)
            return view.widgetBg;
        if (view.sys && view.sys.matugenColors && view.sys.matugenColors.primary_container)
            return view.sys.matugenColors.primary_container.dark.color;
        return "#421024";
    }

    readonly property color m3Blush: {
        if (view.isMonochromeMedia)
            return (view.sys && view.sys.colFg) ? view.sys.colFg : "#e2e2e2";
        if (view.sys && view.sys.matugenColors && view.sys.matugenColors.primary_container)
            return view.sys.matugenColors.primary_container.light.color;
        if (view.sys && view.sys.matugenColors && view.sys.matugenColors.surface_container_highest)
            return view.sys.matugenColors.surface_container_highest.light.color;
        return "#fad5dc";
    }
    readonly property color m3RoseFab: {
        if (view.isMonochromeMedia)
            return (view.sys && view.sys.colOn) ? view.sys.colOn : "#ffffff";
        if (view.sys && view.sys.colOn)
            return view.sys.colOn;
        if (view.sys && view.sys.matugenColors && view.sys.matugenColors.primary)
            return view.sys.matugenColors.primary.dark.color;
        return "#e08096";
    }
    readonly property color m3Amber: "#f59a4c"
    readonly property color m3DarkText: {
        if (view.sys && view.sys.matugenColors && view.sys.matugenColors.on_surface)
            return view.sys.matugenColors.on_surface.light.color;
        return "#3c0d1e";
    }
    readonly property color m3LightText: {
        if (view.sys && view.sys.matugenColors && view.sys.matugenColors.on_primary_container)
            return view.sys.matugenColors.on_primary_container.dark.color;
        return "#fce8ec";
    }
    readonly property string m3Font: "Open Sans"

    // Общий вид карточки: тёмная плашка со скруглением. Фон непрозрачный,
    // а не полупрозрачный: обои под ним бывают любые, и на светлой картинке
    // сквозь полупрозрачную плашку не читались бы ни цифры, ни подписи.
    component Card: Rectangle {
        radius: view.sys && view.sys.themeMaterial ? 28 : 22
        color: (view.sys && view.sys.themeMaterial)
               ? (view.isMonochromeMedia ? view.widgetBg : Qt.rgba(0.13, 0.11, 0.16, 0.94))
               : Qt.rgba(0.09, 0.09, 0.09, 0.96)
        border.color: view.sys && view.sys.themeMaterial
                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14)
                      : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }
    }

    // Число: точками на Nothing, обычным шрифтом на остальных темах.
    //
    // Раскладка карточек у тем общая, разное только начертание — поэтому
    // выбор спрятан сюда, а не размазан по каждому месту, где стоит цифра.
    // Кегль шрифта берётся с запасом от высоты точечной цифры: у той высота
    // и есть весь рост, а у буквы pixelSize считается по всей строке, вместе
    // с надстрочным и подстрочным просветом.
    component Num: Item {
        id: num
        property string value: ""
        property real size: 14
        property real gapRatio: 0.22
        property color color: view.sys.colFg

        implicitWidth:  view.sys.themeNothing ? dots.implicitWidth  : plain.implicitWidth
        implicitHeight: view.sys.themeNothing ? dots.implicitHeight : plain.implicitHeight

        DotText {
            id: dots
            visible: view.sys.themeNothing
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
        Text {
            id: plain
            visible: !view.sys.themeNothing
            text: num.value
            color: (view.sys && view.sys.themeMaterial && num.size >= 40) ? view.sys.colOn : num.color
            font {
                family: view.sys.fontFam
                pixelSize: Math.round(num.size * 1.35)
                bold: view.sys && view.sys.themeMaterial ? true : false
            }
        }
    }

    // Значок погоды тем же порядком: точечный на Nothing, знак шрифта иначе.
    component WIcon: Item {
        id: wico
        property real size: 20
        property color color: view.sys.colFg

        implicitWidth:  view.sys.themeNothing ? wdots.implicitWidth  : wglyph.implicitWidth
        implicitHeight: view.sys.themeNothing ? wdots.implicitHeight : wglyph.implicitHeight

        DotIcon {
            id: wdots
            visible: view.sys.themeNothing
            code: view.sys.weatherIcon
            size: wico.size
            color: wico.color
        }
        Text {
            id: wglyph
            visible: !view.sys.themeNothing
            text: view.sys.weatherGlyph
            color: wico.color
            font { family: view.sys.fontFam; pixelSize: Math.round(wico.size * 1.3) }
        }
    }

    // Мелкая подпись под значением — заглавными вразрядку, как в теме.
    component Caption: Text {
        color: view.sys.colMuted
        elide: Text.ElideRight
        font {
            family: view.sys.fontFam
            pixelSize: 9
            capitalization: view.sys && view.sys.themeMaterial ? Font.MixedCase : Font.AllUppercase
            letterSpacing: view.sys && view.sys.themeMaterial ? 0.4 : 1.1
        }
    }

    ColumnLayout {
        id: stack
        visible: !view.isMaterial
        width: view.fullW
        spacing: view.gap

        // ------------------------------------------------------ дата
        Card {
            Layout.preferredWidth: view.col
            Layout.preferredHeight: 112

            // Число крупно, день недели мелко в углу. Красный здесь
            // единственный на весь набор — им отмечены выходные, и больше
            // ему на рабочем столе делать нечего.
            // Число по центру карточки, а подписи разведены по углам: день
            // недели в верхний правый, месяц в нижний левый. Так число ни с
            // одной из них не соседствует вплотную и читается само по себе.
            Num {
                anchors.centerIn: parent
                value: view.sys.dayNum
                size: 52
                gapRatio: 0.14
                color: view.sys.colFg
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 16
                anchors.topMargin: 13
                text: view.sys.dayText
                color: view.sys.weekend ? view.sys.colCrit : view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: 11; bold: true
                }
            }

            // Месяц словом под числом. Обычным шрифтом: точками набраны
            // цифры, а слово по той же сетке пришлось бы рисовать по букве.
            Caption {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.bottomMargin: 12
                width: parent.width - 30
                // Ярче общего приглушённого: тот рассчитан на подписи под
                // значением, а здесь месяц — сам по себе, второй половиной
                // даты, и в приглушённом тонет.
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g,
                               view.sys.colFg.b, 0.85)
                text: view.sys.monthText
            }
        }

        // ------------------------------- погода: большая карточка и соседи
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Градусы, значок и город. Единственное место, где показана
            // температура.
            // Высота ровно та, что складывается справа: карточка описания
            // 62, просвет 12 и кружки 66. Было 132 против 140, и правый
            // столбец на восемь пикселей не сходился с левым — в наборе из
            // прямоугольников такой перекос видно сразу.
            Card {
                id: mainWeatherCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 62 + view.gap + 66
                Layout.alignment: Qt.AlignTop
                color: wCardMa.containsMouse
                       ? ((view.sys && view.sys.themeMaterial && view.sys.colM3SurfaceContainerHigh) ? view.sys.colM3SurfaceContainerHigh : (view.sys && view.sys.themeMaterial ? Qt.rgba(0.20, 0.18, 0.24, 0.98) : Qt.rgba(0.13, 0.13, 0.14, 0.98)))
                       : ((view.sys && view.sys.themeMaterial)
                          ? (view.isMonochromeMedia ? view.widgetBg : Qt.rgba(0.13, 0.11, 0.16, 0.94))
                          : Qt.rgba(0.09, 0.09, 0.09, 0.96))
                border.color: wCardMa.containsMouse
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                              : (view.sys && view.sys.themeMaterial ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                scale: wCardMa.pressed ? 0.985 : (wCardMa.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    // Погодные числа обычным шрифтом, а не точками. Точки
                    // оставлены числу даты и часам — тем, что и на макете
                    // набрано ими. Градус в точечной сетке выходит квадратным
                    // кружком из четырёх точек, а он должен быть гладким.
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.sys.weatherReady ? view.sys.weatherTemp + "°" : "--°"
                        color: view.sys && view.sys.themeMaterial ? view.sys.colOn : view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 26; bold: !!(view.sys && view.sys.themeMaterial) }
                    }

                    WIcon {
                        Layout.alignment: Qt.AlignHCenter
                        size: 30
                        color: view.sys && view.sys.themeMaterial ? view.sys.colOn : view.sys.colFg
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: view.col - 20
                        text: view.sys.weatherReady
                              ? view.sys.weatherPlace : view.sys.tr("Нет данных")
                        color: view.sys.colMuted
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: 11 }
                    }
                }

                MouseArea {
                    id: wCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.openWeatherDetails()
                }
            }

            ColumnLayout {
                Layout.preferredWidth: view.col
                Layout.alignment: Qt.AlignTop
                spacing: view.gap

                // Что за погода — словами. Градусов здесь нет намеренно:
                // они уже сказаны слева.
                Card {
                    Layout.preferredWidth: view.col
                    Layout.preferredHeight: 62
                    color: descCardMa.containsMouse
                           ? ((view.sys && view.sys.themeMaterial && view.sys.colM3SurfaceContainerHigh) ? view.sys.colM3SurfaceContainerHigh : (view.sys && view.sys.themeMaterial ? Qt.rgba(0.20, 0.18, 0.24, 0.98) : Qt.rgba(0.13, 0.13, 0.14, 0.98)))
                           : ((view.sys && view.sys.themeMaterial)
                              ? (view.isMonochromeMedia ? view.widgetBg : Qt.rgba(0.13, 0.11, 0.16, 0.94))
                              : Qt.rgba(0.09, 0.09, 0.09, 0.96))
                    border.color: descCardMa.containsMouse
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                                  : (view.sys && view.sys.themeMaterial ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                    scale: descCardMa.pressed ? 0.985 : (descCardMa.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        WIcon {
                            Layout.alignment: Qt.AlignVCenter
                            size: 18
                            color: view.sys.colFg
                        }

                        // В две строки, а не в одну с многоточием. Описание
                        // приходит от сервиса и бывает длинным — «overcast
                        // clouds» в одну строку не влезало и обрывалось на
                        // «overcast …», то есть теряло ровно то слово, ради
                        // которого карточка и стоит.
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: view.sys.weatherReady ? view.sys.weatherDesc : "—"
                            color: view.sys.colFg
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 0.95
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        id: descCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.openWeatherDetails()
                    }
                }

                // Два кружка: влажность и ветер. Круглые, чтобы не спорить
                // с прямоугольниками вокруг, и мелкие — это подробности, а
                // не главное на столе.
                RowLayout {
                    Layout.preferredWidth: view.col
                    spacing: view.gap

                    Repeater {
                        model: [
                            { v: view.sys.weatherHumidity, suffix: "%",
                              cap: view.sys.tr("Влажность") },
                            // Единица у ветра стоит в подписи, а не при
                            // числе: в кружок «5 м/с» не помещается, а без
                            // единицы число ничего не значит.
                            { v: view.sys.weatherWind, suffix: "",
                              cap: view.sys.tr("Ветер") + " " + view.sys.weatherWindUnit }
                        ]

                        Rectangle {
                            id: circleCard
                            required property var modelData
                            Layout.preferredWidth: 66
                            Layout.preferredHeight: 66
                            radius: view.sys && view.sys.themeMaterial ? 22 : 33
                            color: circleMa.containsMouse
                                   ? ((view.sys && view.sys.themeMaterial && view.sys.colM3SurfaceContainerHigh) ? view.sys.colM3SurfaceContainerHigh : (view.sys && view.sys.themeMaterial ? Qt.rgba(0.20, 0.18, 0.24, 0.98) : Qt.rgba(0.13, 0.13, 0.14, 0.98)))
                                   : ((view.sys && view.sys.themeMaterial)
                                      ? (view.isMonochromeMedia ? view.widgetBg : ((view.sys && view.sys.colM3SurfaceContainer) ? view.sys.colM3SurfaceContainer : Qt.rgba(0.16, 0.14, 0.19, 0.94)))
                                      : Qt.rgba(0.09, 0.09, 0.09, 0.96))
                            border.color: circleMa.containsMouse
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                                          : (view.sys && view.sys.themeMaterial ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                            border.width: 1
                            scale: circleMa.pressed ? 0.96 : (circleMa.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: view.sys.weatherReady
                                          ? circleCard.modelData.v + circleCard.modelData.suffix : "--"
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 15 }
                                }
                                // Подпись мельче и без разрядки: «HUMIDITY»
                                // вразрядку не помещалось в круг и лезло на
                                // его край. Кружок заодно подрос.
                                Caption {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: 58
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 8
                                    font.letterSpacing: 0.3
                                    text: circleCard.modelData.cap
                                }
                            }

                            MouseArea {
                                id: circleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.openWeatherDetails()
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ часы
        Card {
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 62

            Num {
                anchors.centerIn: parent
                value: view.sys.timeText
                size: 30
                gapRatio: 0.14
                color: view.sys.colFg
            }
        }
    }

    // ------------------------------------------------------------------
    // ------------------------------------------------------------------
    // MATERIAL YOU (ANDROID 12/13/14) WIDGETS
    // Recreación 100% fiel de los 6 widgets originales de la foto:
    // 1. Reloj Margarita / Scalloped Daisy Clock ("Tue 19", 12 lóbulos, agujas gruesas)
    // 2. Google Photos Memories Frame (collage horizontal de 3 fotos enmarcadas)
    // 3. Google Weather Pebble (guijarro orgánico asimétrico, "62°", sol y nube blanca)
    // 4. Google Keep Quick Capture Bar (píldora con botón FAB + y 4 herramientas)
    // 5. Google Fit Activity Dumbbell (píldora diagonal a 45° con 2 discos: pasos y calorías)
    // 6. Google Keep Checklist Card ("Vacay Packing" con FAB +, tachado naranja interactivo)
    // ------------------------------------------------------------------
    RowLayout {
        id: m3WidgetsStack
        visible: view.isMaterial
        spacing: 24

        // 1. Reloj Analógico Margarita (Scalloped Daisy Clock - Escala 1.2x)
        Item {
            id: m3ScallopClock
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 185
            Layout.preferredHeight: 185
            scale: clockMa.pressed ? 0.985 : (clockMa.containsMouse ? 1.025 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            // Fondo con 12 pétalos festoneados continuos y redondeados
            Canvas {
                id: scallopCanvas
                anchors.fill: parent
                antialiasing: true
                property color fillColor: view.isMonochromeMedia ? view.widgetBg : view.m3Burgundy
                Behavior on fillColor { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
                onFillColorChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = fillColor;
                    ctx.beginPath();
                    var cx = width / 2, cy = height / 2;
                    var R0 = width * 0.42;
                    var A = width * 0.030;
                    var B = width * 0.0025;
                    var steps = 180;
                    for (var i = 0; i <= steps; i++) {
                        var a = (i / steps) * Math.PI * 2;
                        var r = R0 + A * Math.cos(12 * a) - B * Math.cos(24 * a);
                        var x = cx + r * Math.cos(a);
                        var y = cy + r * Math.sin(a);
                        if (i === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.closePath();
                    ctx.fill();
                    var strokeCol = (view.sys && view.sys.colOn) ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14) : Qt.rgba(1, 1, 1, 0.08);
                    ctx.strokeStyle = strokeCol;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }

            // Fecha en el cuadrante superior derecho alejada de las agujas (pétalo exterior)
            Text {
                x: Math.round(parent.width * 0.62)
                y: Math.round(parent.height * 0.12)
                text: view.sys ? (view.sys.dayText + " " + view.sys.dayNum) : "Tue 19"
                color: view.isMonochromeMedia
                    ? ((view.sys && view.sys.colOn) ? view.sys.colOn : view.m3Blush)
                    : view.m3Blush
                font {
                    family: view.m3Font
                    pixelSize: 11
                    bold: true
                }
                transform: Rotation { angle: 36 }
            }

            // Punto indicador Material You a las 7:30
            Rectangle {
                x: Math.round(parent.width * 0.23)
                y: Math.round(parent.height * 0.70)
                width: 12
                height: 12
                radius: 6
                color: view.isMonochromeMedia
                    ? ((view.sys && view.sys.colOn) ? view.sys.colOn : view.m3Blush)
                    : view.m3Blush
            }

            // Agujas geométricas con clara diferenciación visual y espacio holgado con el texto
            Item {
                id: clockHands
                anchors.centerIn: parent
                width: 0; height: 0

                property real hourAngle: 0
                property real minAngle: 0

                function updateHands() {
                    var now = new Date();
                    var s = now.getSeconds() + now.getMilliseconds() / 1000;
                    var m = now.getMinutes() + s / 60;
                    var h = (now.getHours() % 12) + m / 60;
                    minAngle = m * 6;
                    hourAngle = h * 30;
                }

                Timer {
                    interval: 1000
                    running: view.isMaterial
                    repeat: true
                    onTriggered: clockHands.updateHands()
                }
                Component.onCompleted: clockHands.updateHands()

                // Aguja Horaria: más corta y gruesa, color rosa acento
                Rectangle {
                    id: hHand
                    width: 14
                    height: 32
                    radius: 7
                    color: view.m3RoseFab
                    x: -width / 2
                    y: -height
                    transform: Rotation {
                        origin.x: hHand.width / 2
                        origin.y: hHand.height
                        angle: clockHands.hourAngle
                    }
                }

                // Aguja Minutera: longitud calibrada para no colisionar con la fecha
                Rectangle {
                    id: mHand
                    width: 10
                    height: 48
                    radius: 5
                    color: view.isMonochromeMedia
                        ? ((view.sys && view.sys.colFg) ? view.sys.colFg : view.m3Blush)
                        : view.m3Blush
                    x: -width / 2
                    y: -height
                    transform: Rotation {
                        origin.x: mHand.width / 2
                        origin.y: mHand.height
                        angle: clockHands.minAngle
                    }
                }

                // Eje central con remache
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: view.m3RoseFab

                    Rectangle {
                        anchors.centerIn: parent
                        width: 5
                        height: 5
                        radius: 2.5
                        color: view.isMonochromeMedia ? view.widgetBg : view.m3Burgundy
                    }
                }
            }

            MouseArea {
                id: clockMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys ? view.sys.togglePage("main") : null
            }
        }

        // 2. Guijarro de Clima Orgánico (Google Weather Pebble - "Círculo Esquinado" / Squircle Material You)
        Item {
            id: m3WeatherPebble
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 185
            Layout.preferredHeight: 185
            scale: weatherMa.pressed ? 0.985 : (weatherMa.containsMouse ? 1.025 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            // Fondo: "Círculo esquinado" (Squircle / rounded card girado 22° fiel al original)
            Rectangle {
                anchors.centerIn: parent
                width: 158
                height: 140
                radius: 54
                rotation: 22
                color: view.isMonochromeMedia ? view.widgetBg : view.m3Blush
                border.color: (view.sys && view.sys.colOn) ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                antialiasing: true
                Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            // CAPA 2 (UNA CAPA MÁS ATRÁS): Número de temperatura
            // El usuario solicitó expresamente: "el numero va una capa mas atras que la nube/sol/nube lluvia etc"
            // z: 1 garantiza que quede por detrás de los elementos de la ilustración (z: 2)
            Text {
                id: tempText
                z: 1
                x: 76
                y: 38
                text: (view.sys && view.sys.weatherReady) ? view.sys.weatherTemp + "°" : "62°"
                color: {
                    if (view.isMonochromeMedia) {
                        var bg = view.widgetBg;
                        return (0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b) > 0.6
                               ? "#141218"
                               : ((view.sys && view.sys.colFg) ? view.sys.colFg : "#ffffff");
                    }
                    return view.m3DarkText;
                }
                font {
                    family: view.m3Font
                    pixelSize: 52
                    bold: true
                }
                transform: Rotation { angle: 16 }
            }

            // CAPA 3: Ilustración del Clima (Sol, Nube, Nube de Lluvia, etc.) EN FRENTE DEL NÚMERO
            Item {
                id: weatherArt
                z: 2
                anchors.fill: parent

                readonly property string wCode: (view.sys && view.sys.weatherIcon && view.sys.weatherIcon.length >= 2) ? String(view.sys.weatherIcon).slice(0, 2) : "02"
                readonly property bool isNight: (view.sys && view.sys.weatherIcon) ? String(view.sys.weatherIcon).endsWith("n") : false
                readonly property bool isRain: wCode === "09" || wCode === "10"
                readonly property bool isStorm: wCode === "11"
                readonly property bool isSnow: wCode === "13"
                readonly property bool isMist: wCode === "50"
                readonly property bool isCloudy: wCode === "03" || wCode === "04"
                readonly property bool isClear: wCode === "01"
                readonly property bool hasSun: !isRain && !isStorm && !isSnow && !isMist && !isCloudy

                // Sol (asoma detrás de la nube pero por DELANTE del número)
                Rectangle {
                    visible: weatherArt.hasSun
                    x: weatherArt.isClear ? 48 : 58
                    y: weatherArt.isClear ? 68 : 74
                    width: weatherArt.isClear ? 56 : 40
                    height: weatherArt.isClear ? 56 : 40
                    radius: width / 2
                    color: weatherArt.isNight ? "#e2e8f0" : "#fde68a"
                }

                // Nube trasera oscura (para nublado intenso o tormenta)
                Item {
                    visible: weatherArt.isCloudy || weatherArt.isStorm
                    x: 14
                    y: 84
                    width: 76
                    height: 48
                    opacity: 0.65

                    Rectangle { x: 1; y: 12; width: 32; height: 32; radius: 16; color: "#cbd5e1" }
                    Rectangle { x: 15; y: -2; width: 44; height: 44; radius: 22; color: "#cbd5e1" }
                    Rectangle { x: 42; y: 12; width: 32; height: 32; radius: 16; color: "#cbd5e1" }
                    Rectangle { x: -1; y: 16; width: 75; height: 28; radius: 14; color: "#cbd5e1" }
                }

                // Nube blanca esponjosa principal (visible en todas las condiciones excepto despejado pleno)
                Item {
                    visible: !weatherArt.isClear
                    x: 26
                    y: 92
                    width: 80
                    height: 52

                    // Lóbulo izquierdo
                    Rectangle {
                        x: 1
                        y: 12
                        width: 34
                        height: 34
                        radius: 17
                        color: "#ffffff"
                    }
                    // Lóbulo central superior
                    Rectangle {
                        x: 15
                        y: -2
                        width: 46
                        height: 46
                        radius: 23
                        color: "#ffffff"
                    }
                    // Lóbulo derecho
                    Rectangle {
                        x: 44
                        y: 12
                        width: 34
                        height: 34
                        radius: 17
                        color: "#ffffff"
                    }
                    // Base redondeada
                    Rectangle {
                        x: -1
                        y: 16
                        width: 79
                        height: 30
                        radius: 15
                        color: "#ffffff"
                    }
                }

                // Rayo para tormenta
                Text {
                    visible: weatherArt.isStorm
                    x: 52
                    y: 122
                    text: "⚡"
                    font.pixelSize: 18
                }

                // Gotas de lluvia
                Row {
                    visible: weatherArt.isRain || weatherArt.isStorm
                    x: 38
                    y: 132
                    spacing: 10
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 3.5
                            height: 12
                            radius: 2
                            color: "#60a5fa"
                            rotation: 18
                        }
                    }
                }

                // Copos de nieve
                Row {
                    visible: weatherArt.isSnow
                    x: 32
                    y: 132
                    spacing: 8
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#ffffff"
                        }
                    }
                }

                // Líneas de niebla
                Column {
                    visible: weatherArt.isMist
                    x: 28
                    y: 128
                    spacing: 5
                    Repeater {
                        model: 2
                        Rectangle {
                            width: 50
                            height: 3.5
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.75)
                        }
                    }
                }
            }

            MouseArea {
                id: weatherMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys ? view.sys.openWeatherDetails() : null
            }
        }
    }
}
