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
    // Режимы карточек Nothing OS
    readonly property string clockMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetClockMode) || "analog"
    readonly property string rightMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetRightMode) || "weather"
    readonly property string progressMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetProgressMode) || "day"

    // Формат часов: 12-часовой или 24-часовой (из системных настроек)
    readonly property bool is12: view.sys && view.sys.cfg ? Boolean(view.sys.cfg.clock12) : false

    // Синхронизация с системным временем через view.sys
    readonly property int curHour: (view.sys && view.sys.timeHour !== undefined) ? view.sys.timeHour : (new Date()).getHours()
    readonly property int curMin: (view.sys && view.sys.timeMinute !== undefined) ? view.sys.timeMinute : (new Date()).getMinutes()
    readonly property int curMonth: { var _ = (view.sys && view.sys.dayNum); return (new Date()).getMonth(); }

    readonly property int curDayOfYear: {
        var _ = (view.sys && view.sys.dayNum);
        var now = new Date();
        var start = new Date(now.getFullYear(), 0, 1);
        return Math.floor((now - start) / (1000 * 60 * 60 * 24));
    }
    readonly property int totalDaysInYear: {
        var _ = (view.sys && view.sys.dayNum);
        var now = new Date();
        var start = new Date(now.getFullYear(), 0, 1);
        var end = new Date(now.getFullYear() + 1, 0, 1);
        return Math.max(1, Math.round((end - start) / (1000 * 60 * 60 * 24)));
    }

    readonly property int dayPct: Math.min(100, Math.max(0, Math.floor((curHour * 60 + curMin) / 1440 * 100)))
    readonly property int yearPct: Math.min(100, Math.max(0, Math.floor(curDayOfYear / totalDaysInYear * 100)))

    readonly property int remainDayMins: Math.max(0, 1440 - (curHour * 60 + curMin))
    readonly property string remainDayText: Math.floor(remainDayMins / 60) + (view.sys && view.sys.isEn ? "h " : (view.sys && view.sys.isTr ? "sa " : (view.sys && view.sys.isEs ? "h " : "ч "))) + (remainDayMins % 60) + (view.sys && view.sys.isEn ? "m" : (view.sys && view.sys.isTr ? "dk" : (view.sys && view.sys.isEs ? "m" : "м")))
    readonly property int remainYearDays: Math.max(0, totalDaysInYear - curDayOfYear)

    function weatherConditionTr(desc) {
        if (!desc) return "—";
        var d = String(desc).trim();
        if (!d.length) return "—";

        var lang = "es";
        if (view.sys) {
            if (view.sys.languageCode === "ru") lang = "ru";
            else if (view.sys.languageCode === "en") lang = "en";
            else if (view.sys.languageCode === "tr" || view.sys.isTr) lang = "tr";
            else if (view.sys.isEs || view.sys.languageCode === "es") lang = "es";
        }

        var map = {
            "clear sky": { es: "Cielo despejado", en: "Clear sky", ru: "Ясно", tr: "Açık" },
            "clear": { es: "Cielo despejado", en: "Clear", ru: "Ясно", tr: "Açık" },
            "ясно": { es: "Cielo despejado", en: "Clear sky", ru: "Ясно", tr: "Açık" },
            "mainly clear": { es: "Mayormente despejado", en: "Mainly clear", ru: "В основном ясно", tr: "Çoğunlukla açık" },
            "в основном ясно": { es: "Mayormente despejado", en: "Mainly clear", ru: "В основном ясно", tr: "Çoğunlukla açık" },
            "few clouds": { es: "Poco nublado", en: "Few clouds", ru: "Малооблачно", tr: "Az bulutlu" },
            "малооблачно": { es: "Poco nublado", en: "Few clouds", ru: "Малооблачно", tr: "Az bulutlu" },
            "scattered clouds": { es: "Nubes dispersas", en: "Scattered clouds", ru: "Рассеянные облака", tr: "Parçalı bulutlu" },
            "рассеянные облака": { es: "Nubes dispersas", en: "Scattered clouds", ru: "Рассеянные облака", tr: "Parçalı bulutlu" },
            "partly cloudy": { es: "Parcialmente nublado", en: "Partly cloudy", ru: "Переменная облачность", tr: "Parçalı bulutlu" },
            "переменная облачность": { es: "Parcialmente nublado", en: "Partly cloudy", ru: "Переменная облачность", tr: "Parçalı bulutlu" },
            "broken clouds": { es: "Parcialmente nublado", en: "Broken clouds", ru: "Облачно с прояснениями", tr: "Çok bulutlu" },
            "облачно с прояснениями": { es: "Parcialmente nublado", en: "Broken clouds", ru: "Облачно с прояснениями", tr: "Çok bulutlu" },
            "overcast": { es: "Nublado", en: "Overcast", ru: "Пасмурно", tr: "Kapalı" },
            "пасмурно": { es: "Nublado", en: "Overcast", ru: "Пасмурно", tr: "Kapalı" },
            "cloudy": { es: "Nublado", en: "Cloudy", ru: "Облачно", tr: "Bulutlu" },
            "clouds": { es: "Nublado", en: "Cloudy", ru: "Облачно", tr: "Bulutlu" },
            "облачно": { es: "Nublado", en: "Cloudy", ru: "Облачно", tr: "Bulutlu" },
            "fog": { es: "Niebla", en: "Fog", ru: "Туман", tr: "Sisli" },
            "туман": { es: "Niebla", en: "Fog", ru: "Туман", tr: "Sisli" },
            "mist": { es: "Niebla", en: "Mist", ru: "Туман", tr: "Sisli" },
            "haze": { es: "Neblina", en: "Haze", ru: "Дымка", tr: "Puslu" },
            "дымка": { es: "Neblina", en: "Haze", ru: "Дымка", tr: "Puslu" },
            "smoke": { es: "Humo", en: "Smoke", ru: "Дым", tr: "Duman" },
            "dust": { es: "Polvo", en: "Dust", ru: "Пыль", tr: "Toz" },
            "sand": { es: "Arena", en: "Sand", ru: "Песок", tr: "Kum" },
            "drizzle": { es: "Llovizna", en: "Drizzle", ru: "Морось", tr: "Çiseleme" },
            "light drizzle": { es: "Llovizna ligera", en: "Light drizzle", ru: "Небольшая морось", tr: "Hafif çiseleme" },
            "dense drizzle": { es: "Llovizna densa", en: "Dense drizzle", ru: "Плотная морось", tr: "Yoğun çiseleme" },
            "freezing drizzle": { es: "Llovizna helada", en: "Freezing drizzle", ru: "Замерзающая морось", tr: "Dondurucu çiseleme" },
            "heavy drizzle": { es: "Llovizna fuerte", en: "Heavy drizzle", ru: "Сильная морось", tr: "Kuvvetli çiseleme" },
            "морось": { es: "Llovizna", en: "Drizzle", ru: "Морось", tr: "Çiseleme" },
            "rain": { es: "Lluvia", en: "Rain", ru: "Дождь", tr: "Yağmurlu" },
            "light rain": { es: "Lluvia ligera", en: "Light rain", ru: "Небольшой дождь", tr: "Hafif yağmurlu" },
            "heavy rain": { es: "Lluvia fuerte", en: "Heavy rain", ru: "Сильный дождь", tr: "Kuvvetli yağmurlu" },
            "moderate rain": { es: "Lluvia moderada", en: "Moderate rain", ru: "Умеренный дождь", tr: "Orta şiddetli yağmurlu" },
            "freezing rain": { es: "Lluvia helada", en: "Freezing rain", ru: "Ледяной дождь", tr: "Dondurucu yağmur" },
            "very heavy rain": { es: "Lluvia muy fuerte", en: "Very heavy rain", ru: "Очень сильный дождь", tr: "Çok şiddetli yağmur" },
            "extreme rain": { es: "Lluvia torrencial", en: "Extreme rain", ru: "Экстремальный дождь", tr: "Aşırı yağmur" },
            "дождь": { es: "Lluvia", en: "Rain", ru: "Дождь", tr: "Yağmurlu" },
            "rain showers": { es: "Chubascos", en: "Rain showers", ru: "Ливень", tr: "Sağanak yağış" },
            "shower rain": { es: "Chubascos", en: "Shower rain", ru: "Ливень", tr: "Sağanak yağış" },
            "light rain showers": { es: "Chubascos ligeros", en: "Light rain showers", ru: "Небольшой ливень", tr: "Hafif sağanak" },
            "heavy rain showers": { es: "Chubascos fuertes", en: "Heavy rain showers", ru: "Сильный ливень", tr: "Kuvvetli sağanak" },
            "ливень": { es: "Chubascos", en: "Rain showers", ru: "Ливень", tr: "Sağanak yağış" },
            "sleet": { es: "Aguanieve", en: "Sleet", ru: "Мокрый снег", tr: "Sulu kar" },
            "shower sleet": { es: "Aguanieve", en: "Shower sleet", ru: "Мокрый снег", tr: "Sulu kar" },
            "мокрый снег": { es: "Aguanieve", en: "Sleet", ru: "Мокрый снег", tr: "Sulu kar" },
            "snow": { es: "Nieve", en: "Snow", ru: "Снег", tr: "Karlı" },
            "light snow": { es: "Nieve ligera", en: "Light snow", ru: "Небольшой снег", tr: "Hafif karlı" },
            "heavy snow": { es: "Nieve fuerte", en: "Heavy snow", ru: "Снегопад", tr: "Yoğun karlı" },
            "snow grains": { es: "Granizo menudo", en: "Snow grains", ru: "Снежные зерна", tr: "Kar taneleri" },
            "снег": { es: "Nieve", en: "Snow", ru: "Снег", tr: "Karlı" },
            "snow showers": { es: "Chubascos de nieve", en: "Snow showers", ru: "Снегопад", tr: "Kar sağanağı" },
            "light snow showers": { es: "Chubascos de nieve ligeros", en: "Light snow showers", ru: "Небольшой снегопад", tr: "Hafif kar sağanağı" },
            "heavy snow showers": { es: "Chubascos de nieve fuertes", en: "Heavy snow showers", ru: "Сильный снегопад", tr: "Kuvvetli kar sağanağı" },
            "снегопад": { es: "Chubascos de nieve", en: "Snow showers", ru: "Снегопад", tr: "Kar sağanağı" },
            "thunderstorm": { es: "Tormenta", en: "Thunderstorm", ru: "Гроза", tr: "Gök gürültülü fırtına" },
            "thunderstorm with light rain": { es: "Tormenta con lluvia ligera", en: "Thunderstorm with light rain", ru: "Гроза с небольшим дождём", tr: "Hafif yağmurlu fırtına" },
            "thunderstorm with rain": { es: "Tormenta con lluvia", en: "Thunderstorm with rain", ru: "Гроза с дождём", tr: "Yağmurlu fırtına" },
            "thunderstorm with heavy rain": { es: "Tormenta con lluvia fuerte", en: "Thunderstorm with heavy rain", ru: "Гроза с сильным дождём", tr: "Kuvvetli yağmurlu fırtına" },
            "thunderstorm with hail": { es: "Tormenta con granizo", en: "Thunderstorm with hail", ru: "Гроза с градом", tr: "Dolu fırtınası" },
            "гроза": { es: "Tormenta", en: "Thunderstorm", ru: "Гроза", tr: "Gök gürültülü fırtına" },
            "squall": { es: "Chubasco", en: "Squall", ru: "Шквал", tr: "Bora" },
            "squalls": { es: "Chubascos", en: "Squalls", ru: "Шквалы", tr: "Fırtına" },
            "tornado": { es: "Tornado", en: "Tornado", ru: "Торнадо", tr: "Hortum" }
        };

        var entry = map[d.toLowerCase()];
        if (entry && entry[lang]) return entry[lang];
        if (view.sys && view.sys.tr) {
            var trRes = view.sys.tr(d);
            if (trRes && trRes !== d) return trRes;
            var trLower = view.sys.tr(d.toLowerCase());
            if (trLower && trLower !== d.toLowerCase()) return trLower;
        }
        return d;
    }

    // Пульсация текущего сегмента времени в стиле глифов Nothing
    property real pulseOpacity: 1.0
    SequentialAnimation on pulseOpacity {
        loops: Animation.Infinite
        running: view.visible && !view.isMaterial
        NumberAnimation { to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
    }

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

        // ------------------------------------------------------ Ряд 1: Дата и Часы
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Карточка даты (144x140)
            Card {
                id: dateCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                color: dateMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: dateMa.containsMouse ? (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Num {
                    anchors.centerIn: parent
                    value: view.sys ? view.sys.dayNum : ""
                    size: 50
                    gapRatio: 0.14
                    color: view.sys ? view.sys.colFg : "#ffffff"
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 16
                    anchors.topMargin: 13
                    text: view.sys ? view.sys.dayText : ""
                    color: (view.sys && view.sys.weekend) ? view.sys.colCrit : (view.sys ? view.sys.colMuted : "#888888")
                    font {
                        family: view.sys ? view.sys.fontFam : "sans-serif"
                        pixelSize: 11
                        bold: true
                    }
                }

                Caption {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    anchors.bottomMargin: 13
                    width: parent.width - 32
                    color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.85) : "#dddddd"
                    text: view.sys ? view.sys.monthText : ""
                }

                MouseArea {
                    id: dateMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.togglePage) view.sys.togglePage("cal");
                    }
                }
            }

            // Карточка часов Nothing OS (144x140) — переключает аналоговые / цифровые
            Card {
                id: clockCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                color: clockMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: clockMa.containsMouse ? (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // Режим аналоговых часов Nothing
                Item {
                    anchors.fill: parent
                    visible: view.clockMode === "analog"

                    Canvas {
                        id: clockCanvas
                        anchors.fill: parent

                        Connections {
                            target: view.sys
                            ignoreUnknownSignals: true
                            function onTimeSecondChanged() { clockCanvas.requestPaint(); }
                            function onTimeTextChanged() { clockCanvas.requestPaint(); }
                            function onTimeHourChanged() { clockCanvas.requestPaint(); }
                        }

                        Connections {
                            target: view
                            function onIs12Changed() { clockCanvas.requestPaint(); }
                        }

                        Timer {
                            interval: 1000
                            running: view.visible && !view.isMaterial && view.clockMode === "analog"
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: clockCanvas.requestPaint()
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = Math.min(cx, cy) - 16;

                            var is12 = view.is12;

                            if (is12) {
                                // 12-часовой циферблат: 12 точечных меток (шаг 30°)
                                for (var i = 0; i < 12; i++) {
                                    var ang = i * (Math.PI / 6) - Math.PI / 2;
                                    var x = cx + Math.cos(ang) * r;
                                    var y = cy + Math.sin(ang) * r;
                                    ctx.beginPath();
                                    if (i % 3 === 0) {
                                        // 12, 3, 6, 9 часов: акцентные белые точки
                                        ctx.arc(x, y, 2.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "#ffffff";
                                    } else {
                                        // Промежуточные часы: полупрозрачные точки
                                        ctx.arc(x, y, 1.3, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
                                    }
                                    ctx.fill();
                                }
                            } else {
                                // 24-часовой циферблат: 24 точечные метки (шаг 15°)
                                for (var j = 0; j < 24; j++) {
                                    var ang24 = j * (Math.PI / 12) - Math.PI / 2;
                                    var x24 = cx + Math.cos(ang24) * r;
                                    var y24 = cy + Math.sin(ang24) * r;
                                    ctx.beginPath();
                                    if (j % 6 === 0) {
                                        // 00 (полночь/верх), 06 (утро/право), 12 (полдень/низ), 18 (вечер/лево)
                                        ctx.arc(x24, y24, 2.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "#ffffff";
                                    } else if (j % 2 === 0) {
                                        // Четные часы: средние белые точки
                                        ctx.arc(x24, y24, 1.4, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.50)";
                                    } else {
                                        // Нечетные часы: тонкие деликатные точки
                                        ctx.arc(x24, y24, 1.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.25)";
                                    }
                                    ctx.fill();
                                }
                            }

                            // Синхронизация с системным временем через view.sys
                            var h = (view.sys && view.sys.timeHour !== undefined) ? view.sys.timeHour : (new Date()).getHours();
                            var m = (view.sys && view.sys.timeMinute !== undefined) ? view.sys.timeMinute : (new Date()).getMinutes();
                            var s = (view.sys && view.sys.timeSecond !== undefined) ? view.sys.timeSecond : (new Date()).getSeconds();

                            // 1. Часовая стрелка: элегантная белая капсула
                            // В 12-часовом формате оборот 12 часов (PI/6), в 24-часовом — 24 часа (PI/12)
                            var hAng = is12
                                ? (((h % 12) + m / 60 + s / 3600) * (Math.PI / 6) - Math.PI / 2)
                                : ((h + m / 60 + s / 3600) * (Math.PI / 12) - Math.PI / 2);

                            ctx.beginPath();
                            ctx.lineWidth = 3.6;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "#ffffff";
                            ctx.moveTo(cx + Math.cos(hAng) * 3, cy + Math.sin(hAng) * 3);
                            ctx.lineTo(cx + Math.cos(hAng) * (r * 0.50), cy + Math.sin(hAng) * (r * 0.50));
                            ctx.stroke();

                            // 2. Минутная стрелка: тонкая изящная белая игла (1 оборот = 60 минут)
                            var mAng = (m + s / 60) * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 2.0;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
                            ctx.moveTo(cx + Math.cos(mAng) * 3, cy + Math.sin(mAng) * 3);
                            ctx.lineTo(cx + Math.cos(mAng) * (r * 0.78), cy + Math.sin(mAng) * (r * 0.78));
                            ctx.stroke();

                            // 3. Секундная стрелка Nothing Red: тонкая стрелка с противовесом (1 оборот = 60 секунд)
                            var sAng = s * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 1.2;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = (view.sys && view.sys.colCrit) ? String(view.sys.colCrit) : "#d71921";
                            ctx.moveTo(cx - Math.cos(sAng) * (r * 0.18), cy - Math.sin(sAng) * (r * 0.18));
                            ctx.lineTo(cx + Math.cos(sAng) * (r * 0.82), cy + Math.sin(sAng) * (r * 0.82));
                            ctx.stroke();

                            // 4. Фирменная центральная втулка Nothing OS
                            ctx.beginPath();
                            ctx.arc(cx, cy, 3.8, 0, Math.PI * 2);
                            ctx.fillStyle = "#141414";
                            ctx.fill();
                            ctx.lineWidth = 1.0;
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
                            ctx.stroke();

                            // Красная точка в самом центре
                            ctx.beginPath();
                            ctx.arc(cx, cy, 1.8, 0, Math.PI * 2);
                            ctx.fillStyle = (view.sys && view.sys.colCrit) ? String(view.sys.colCrit) : "#d71921";
                            ctx.fill();
                        }
                    }
                }

                // Режим цифровых часов
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: view.clockMode !== "analog"
                    spacing: 6

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NOTHING"
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.4) : "#666666"
                    }

                    Item {
                        id: digitalClockWrap
                        Layout.alignment: Qt.AlignHCenter
                        readonly property real maxWidth: (clockCard.width > 30 ? clockCard.width : view.col) - 24
                        readonly property real scaleFactor: (digitalClockNum.implicitWidth > maxWidth && digitalClockNum.implicitWidth > 0)
                                                            ? (maxWidth / digitalClockNum.implicitWidth)
                                                            : 1.0
                        implicitWidth: Math.min(digitalClockNum.implicitWidth * scaleFactor, maxWidth)
                        implicitHeight: digitalClockNum.implicitHeight * scaleFactor

                        Num {
                            id: digitalClockNum
                            anchors.centerIn: parent
                            scale: digitalClockWrap.scaleFactor
                            transformOrigin: Item.Center
                            value: {
                                if (!view.sys) return "";
                                var _tick = view.sys.secText;
                                if (view.is12) {
                                    var d12 = new Date();
                                    return Qt.formatDateTime(d12, (view.sys && view.sys.clockSeconds) ? "h:mm:ss" : "h:mm");
                                }
                                return view.sys.timeText;
                            }
                            size: (value.length > 8) ? 15 : (value.length > 5 ? 19 : 32)
                            gapRatio: (value.length > 5) ? 0.12 : 0.14
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }
                    }

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (view.is12) {
                                var d = new Date();
                                return d.getHours() >= 12 ? "PM" : "AM";
                            }
                            return "LOCAL";
                        }
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }
                }

                MouseArea {
                    id: clockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.cfg) {
                            view.sys.cfg.widgetClockMode = (view.clockMode === "analog" ? "digital" : "analog");
                            view.sys.saveCfg();
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Ряд 2: Погода / Система
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Главная карточка погоды (144x140) — клик открывает полное окно прогноза
            Card {
                id: mainWeatherCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                Layout.alignment: Qt.AlignTop
                color: wCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: wCardMa.containsMouse ? (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (view.sys && view.sys.weatherReady) ? view.sys.weatherTemp + "°" : "--°"
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26 }
                    }

                    WIcon {
                        Layout.alignment: Qt.AlignHCenter
                        size: 28
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: view.col - 20
                        text: (view.sys && view.sys.weatherReady)
                              ? view.sys.weatherPlace : (view.sys ? view.sys.tr("Нет данных") : "--")
                        color: view.sys ? view.sys.colMuted : "#888888"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                    }
                }

                MouseArea {
                    id: wCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (view.sys) view.sys.openWeatherDetails(); }
                }
            }

            // Правая карточка (144x140) — КЛИК ПЕРЕКЛЮЧАЕТ МЕЖДУ ПОГОДОЙ И СИСТЕМОЙ
            Card {
                id: rightToggleCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                Layout.alignment: Qt.AlignTop
                color: rightCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: rightCardMa.containsMouse ? (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // Режим: ПОДРОБНОСТИ ПОГОДЫ
                Item {
                    anchors.fill: parent
                    visible: view.rightMode === "weather"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Верхняя плашка с описанием погоды
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                WIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    size: 18
                                    color: view.sys ? view.sys.colFg : "#ffffff"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: {
                                        if (!view.sys || !view.sys.weatherReady) return "—";
                                        var rawDesc = view.sys.weatherDesc;
                                        if (!rawDesc) return "—";
                                        return view.weatherConditionTr(rawDesc);
                                    }
                                    color: view.sys ? view.sys.colFg : "#ffffff"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    lineHeight: 0.95
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                                }
                            }
                        }

                        // Нижние кружки (Влажность и Ветер)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady) ? (view.sys.weatherHumidity + "%") : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15; bold: true }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: view.sys ? view.sys.tr("Влажность") : "HUMIDITY"
                                        font.pixelSize: 7
                                        font.letterSpacing: 0.2
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady) ? String(view.sys.weatherWind) : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15; bold: true }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys ? view.sys.tr("Ветер") : "WIND") + " " + (view.sys ? view.sys.weatherWindUnit : "")
                                        font.pixelSize: 7
                                        font.letterSpacing: 0.2
                                    }
                                }
                            }
                        }
                    }
                }

                // Режим: СИСТЕМНЫЙ МОНИТОР (Концентрические дуги RAM и SSD)
                Item {
                    anchors.fill: parent
                    visible: view.rightMode === "system"

                    // Верхняя строка заголовка
                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        anchors.topMargin: 10
                        spacing: 6

                        Text {
                            text: "󰍛"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13 }
                            color: view.sys ? view.sys.colMuted : "#888888"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Caption {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: {
                                if (!view.sys) return "SYSTEM";
                                if (view.sys.languageCode === "en") return "SYSTEM";
                                var trText = view.sys.tr("СИСТЕМА");
                                if (!trText || trText === "СИСТЕМА") {
                                    var s = view.sys.tr("Sistema");
                                    if (s && s !== "Sistema") return s.toUpperCase();
                                }
                                return trText || "SISTEMA";
                            }
                            color: view.sys ? view.sys.colMuted : "#888888"
                        }
                    }

                    // Концентрические кольца: внешнее RAM, внутреннее SSD
                    Item {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: 76
                        height: 76

                        Canvas {
                            id: ringsCanvas
                            anchors.fill: parent

                            Connections {
                                target: view.sys
                                ignoreUnknownSignals: true
                                function onLoadMemChanged() { ringsCanvas.requestPaint(); }
                                function onLoadDiskChanged() { ringsCanvas.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2;
                                var cy = height / 2;

                                var ram = (view.sys && view.sys.loadMem !== undefined && view.sys.loadMem >= 0) ? view.sys.loadMem : 0;
                                var disk = (view.sys && view.sys.loadDisk !== undefined && view.sys.loadDisk >= 0) ? view.sys.loadDisk : 0;

                                // Внешнее кольцо: RAM (radius 31, lineWidth 4)
                                var r1 = 31;
                                ctx.lineWidth = 4;
                                ctx.lineCap = "round";

                                ctx.beginPath();
                                ctx.arc(cx, cy, r1, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                                ctx.stroke();

                                if (ram > 0) {
                                    ctx.beginPath();
                                    var aStart = -Math.PI / 2;
                                    var aEnd = aStart + (Math.min(100, ram) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r1, aStart, aEnd);
                                    ctx.strokeStyle = ram > 85 ? ((view.sys && view.sys.colCrit) ? String(view.sys.colCrit) : "#d71921") : "rgba(255, 255, 255, 0.95)";
                                    ctx.stroke();
                                }

                                // Внутреннее кольцо: SSD (radius 21, lineWidth 4)
                                var r2 = 21;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r2, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
                                ctx.stroke();

                                if (disk > 0) {
                                    ctx.beginPath();
                                    var aStart2 = -Math.PI / 2;
                                    var aEnd2 = aStart2 + (Math.min(100, disk) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r2, aStart2, aEnd2);
                                    ctx.strokeStyle = (view.sys && view.sys.colCrit) ? String(view.sys.colCrit) : "#d71921";
                                    ctx.stroke();
                                }
                            }
                        }

                        Num {
                            anchors.centerIn: parent
                            value: (view.sys && view.sys.loadMem !== undefined && view.sys.loadMem >= 0) ? String(view.sys.loadMem) : "--"
                            size: 11
                            gapRatio: 0.18
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }
                    }

                    // Нижняя строка: показатели RAM и SSD
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        anchors.bottomMargin: 8

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: (view.sys && view.sys.loadMem !== undefined && view.sys.loadMem >= 0) ? (view.sys.loadMem + "%") : "--%"
                                color: view.sys ? view.sys.colFg : "#ffffff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { text: "RAM"; font.pixelSize: 8 }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 1
                            Layout.alignment: Qt.AlignRight
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: (view.sys && view.sys.loadDisk !== undefined && view.sys.loadDisk >= 0) ? (view.sys.loadDisk + "%") : "--%"
                                color: (view.sys && view.sys.colCrit) ? view.sys.colCrit : "#d71921"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { Layout.alignment: Qt.AlignRight; text: "SSD"; font.pixelSize: 8 }
                        }
                    }
                }

                // ЕДИНЫЙ клик по всей правой карточке: переключает Погода <-> Система
                MouseArea {
                    id: rightCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.cfg) {
                            view.sys.cfg.widgetRightMode = (view.rightMode === "weather" ? "system" : "weather");
                            view.sys.saveCfg();
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Ряд 3: Life Bar / Day & Year Progress (300x72)
        Card {
            id: progressCard
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 72
            color: progMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
            border.color: progMa.containsMouse ? (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Caption {
                        Layout.fillWidth: true
                        text: {
                            if (!view.sys) return view.progressMode === "day" ? "DAY PROGRESS" : "YEAR PROGRESS";
                            if (view.sys.languageCode === "en") return view.progressMode === "day" ? "DAY PROGRESS" : "YEAR PROGRESS";
                            if (view.progressMode === "day") {
                                var dTr = view.sys.tr("Прогресс дня");
                                return (dTr && dTr !== "Прогресс дня") ? ((view.sys && view.sys.themeMaterial) ? dTr : dTr.toUpperCase()) : (view.sys.tr("ПРОГРЕСС ДНЯ") || "PROGRESO DEL DÍA");
                            } else {
                                var yTr = view.sys.tr("Прогресс года");
                                return (yTr && yTr !== "Прогресс года") ? ((view.sys && view.sys.themeMaterial) ? yTr : yTr.toUpperCase()) : (view.sys.tr("ПРОГРЕСС ГОДА") || "PROGRESO DEL AÑO");
                            }
                        }
                        font.bold: true
                        font.pixelSize: 9
                        font.letterSpacing: 1.2
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }

                    Num {
                        value: (view.progressMode === "day" ? view.dayPct : view.yearPct) + "%"
                        size: 13
                        gapRatio: 0.15
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }
                }

                // 24 сегмента для 24 часов
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 3
                    visible: view.progressMode === "day"

                    Repeater {
                        model: 24
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curHour
                                   ? Qt.rgba(1, 1, 1, 0.88)
                                   : (index === view.curHour
                                      ? ((view.sys && view.sys.colOn) ? view.sys.colOn : ((view.sys && view.sys.colCrit) ? view.sys.colCrit : "#d71921"))
                                      : Qt.rgba(1, 1, 1, 0.12))
                            opacity: index === view.curHour ? view.pulseOpacity : 1.0
                        }
                    }
                }

                // 12 сегментов для 12 месяцев года
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 5
                    visible: view.progressMode === "year"

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curMonth
                                   ? Qt.rgba(1, 1, 1, 0.88)
                                   : (index === view.curMonth
                                      ? ((view.sys && view.sys.colOn) ? view.sys.colOn : ((view.sys && view.sys.colCrit) ? view.sys.colCrit : "#d71921"))
                                      : Qt.rgba(1, 1, 1, 0.12))
                            opacity: index === view.curMonth ? view.pulseOpacity : 1.0
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: {
                            var pfx = "Remaining ";
                            if (view.sys) {
                                if (view.sys.languageCode === "en") {
                                    pfx = "Remaining ";
                                } else {
                                    var oTr = view.sys.tr("Осталось");
                                    pfx = (oTr && oTr !== "Осталось") ? (oTr + " ") : (view.sys.tr("Осталось ") || "Restante ");
                                }
                            }
                            var sfx = (view.progressMode === "day"
                                       ? view.remainDayText
                                       : (view.remainYearDays + " " + (view.sys ? view.sys.tr("дн.") : "days")));
                            return pfx + sfx;
                        }
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font {
                            family: view.sys ? view.sys.fontFam : "sans-serif"
                            pixelSize: 10
                        }
                    }

                    Caption {
                        text: "󰔛 " + (view.progressMode === "day" ? "24H" : "365D")
                        font.pixelSize: 8
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.4) : "#666666"
                    }
                }
            }

            MouseArea {
                id: progMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.sys && view.sys.cfg) {
                        view.sys.cfg.widgetProgressMode = (view.progressMode === "day" ? "year" : "day");
                        view.sys.saveCfg();
                    }
                }
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
            scale: m3ClockMa.pressed ? 0.985 : (m3ClockMa.containsMouse ? 1.025 : 1.0)
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
                id: m3ClockMa
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
