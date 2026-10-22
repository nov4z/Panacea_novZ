import QtQuick
import QtQuick.Layouts

// Окно детального прогноза погоды на несколько дней (почасовой + 7 дней)
Item {
    id: view

    property var sys
    property var forecastData: null
    property int selectedDayIndex: 0

    implicitWidth: 680
    implicitHeight: 560

    readonly property bool isEn: view.sys ? (!view.sys.isEs && (view.sys.languageCode === "en" || view.sys.languageCode !== "ru")) : false
    readonly property bool isEs: view.sys ? (view.sys.languageCode === "es" || view.sys.isEs) : true
    readonly property bool isTr: view.sys ? (view.sys.languageCode === "tr" || view.sys.isTr) : false
    readonly property bool isMaterial: !!(view.sys && view.sys.themeMaterial)

    function dayName(dateStr, idx) {
        if (idx === 0) return view.sys.tr("Сегодня");
        if (idx === 1) return view.sys.tr("Завтра");
        if (!dateStr) return "";
        var parts = dateStr.split("-");
        if (parts.length < 3) return dateStr;
        var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        var daysRu = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
        var daysEn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var daysEs = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
        var daysTr = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"];
        var monthsRu = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
        var monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var monthsEs = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
        var monthsTr = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
        var dayArr = view.sys.isEs ? daysEs : (view.isEn ? daysEn : daysRu);
        var monArr = view.sys.isEs ? monthsEs : (view.isEn ? monthsEn : monthsRu);
        if (view.isTr) { dayArr = daysTr; monArr = monthsTr; }
        return dayArr[d.getDay()] + ", " + d.getDate() + " " + monArr[d.getMonth()];
    }

    function iconGlyph(code) {
        var k = String(code).slice(0, 2);
        return String.fromCodePoint(
              k === "01" ? 0xF0599                        // солнце
            : k === "02" ? 0xF0595                        // солнце за облаком
            : (k === "03" || k === "04") ? 0xF0590         // облако
            : (k === "09" || k === "10") ? 0xF0597         // дождь
            : k === "11" ? 0xF0593                        // гроза
            : k === "13" ? 0xF0598                        // снег
            : k === "50" ? 0xF0591                        // туман
                         : 0xF0590);
    }

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
            "дым": { es: "Humo", en: "Smoke", ru: "Дым", tr: "Duman" },
            "dust": { es: "Polvo", en: "Dust", ru: "Пыль", tr: "Toz" },
            "пыль": { es: "Polvo", en: "Dust", ru: "Пыль", tr: "Toz" },
            "sand": { es: "Arena", en: "Sand", ru: "Песок", tr: "Kum" },
            "песок": { es: "Arena", en: "Sand", ru: "Песок", tr: "Kum" },

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
            "light shower sleet": { es: "Aguanieve ligera", en: "Light shower sleet", ru: "Небольшой мокрый снег", tr: "Hafif sulu kar" },
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
            "шквал": { es: "Chubasco", en: "Squall", ru: "Шквал", tr: "Bora" },
            "шквалы": { es: "Chubascos", en: "Squalls", ru: "Шквалы", tr: "Fırtına" },

            "tornado": { es: "Tornado", en: "Tornado", ru: "Торнадо", tr: "Hortum" },
            "торнадо": { es: "Tornado", en: "Tornado", ru: "Торнадо", tr: "Hortum" }
        };

        var entry = map[d.toLowerCase()];
        if (entry && entry[lang]) {
            return entry[lang];
        }

        if (view.sys && view.sys.tr) {
            var trRes = view.sys.tr(d);
            if (trRes && trRes !== d) return trRes;
            var trLower = view.sys.tr(d.toLowerCase());
            if (trLower && trLower !== d.toLowerCase()) return trLower;
        }
        return d;
    }

    readonly property var currentObj: (view.forecastData && view.forecastData.current) ? view.forecastData.current : null
    readonly property var dailyList: (view.forecastData && view.forecastData.daily) ? view.forecastData.daily : []
    readonly property var hourlyList: (view.forecastData && view.forecastData.hourly) ? view.forecastData.hourly : []
    readonly property var activeDay: (dailyList.length > selectedDayIndex) ? dailyList[selectedDayIndex] : null

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: isMaterial ? 28 : 24
        color: (isMaterial && view.sys)
               ? (view.sys.colM3Surface || Qt.rgba(0.08, 0.08, 0.09, 0.98))
               : Qt.rgba(0.06, 0.06, 0.07, 0.98)
        border.color: (isMaterial && view.sys && view.sys.colOn)
                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14)
                      : view.sys.colLine
        border.width: 1
        clip: true

        // Поглощает клики внутри карточки окна, предотвращая закрытие оверлея
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ---------------------------------------------------- Шапка
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: String.fromCodePoint(0xF034E)
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 18 }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: (view.forecastData && view.forecastData.city)
                              ? view.forecastData.city : view.sys.weatherPlace
                        color: view.sys.colFg
                        font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 2; bold: true }
                        elide: Text.ElideRight
                    }

                    Text {
                        text: view.sys.tr("Прогноз погоды") + (activeDay ? " · " + view.dayName(activeDay.date, selectedDayIndex) : "")
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                }

                // Кнопка обновления
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: refMa.containsMouse ? view.sys.colHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF0450)
                        color: view.sys.weatherBusy ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 15 }
                    }
                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.refreshWeatherForecast()
                    }
                }

                // Кнопка закрытия
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: closeMa.containsMouse ? view.sys.colHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 13 }
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.weatherDetailsOpen = false
                    }
                }
            }

            // ------------------------------------ Главная карточка (Сводка)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                radius: isMaterial ? 20 : 18
                color: (isMaterial && view.sys)
                       ? (view.sys.colM3SurfaceContainer || Qt.rgba(0.12, 0.12, 0.14, 0.98))
                       : Qt.rgba(1, 1, 1, 0.04)
                border.color: (isMaterial && view.sys && view.sys.colOn)
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.10)
                              : Qt.rgba(1, 1, 1, 0.07)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 16

                    // Температура и иконка
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 12

                        Text {
                            text: view.iconGlyph(activeDay ? activeDay.icon : (currentObj ? currentObj.icon : "03d"))
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 42 }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: (activeDay ? activeDay.tempMax : (currentObj ? currentObj.temp : "--")) + "°"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 34; bold: true }
                            }
                            Text {
                                text: activeDay
                                      ? (activeDay.tempMin + "° … " + activeDay.tempMax + "° · " + view.weatherConditionTr(activeDay.desc))
                                      : (currentObj ? view.weatherConditionTr(currentObj.desc) : "—")
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                                elide: Text.ElideRight
                                Layout.maximumWidth: 180
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Сетка параметров (2 колонки)
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 3
                        rowSpacing: 6
                        columnSpacing: 12

                        // Ощущается
                        ColumnLayout {
                            spacing: 1
                            Text { text: view.sys.tr("Ощущается"); color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                            Text {
                                text: (activeDay ? activeDay.feelsMax : (currentObj ? currentObj.feels : "--")) + "°"
                                color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                        }

                        // Влажность / Осадки
                        ColumnLayout {
                            spacing: 1
                            Text { text: activeDay ? view.sys.tr("Осадки") : view.sys.tr("Влажность"); color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                            Text {
                                text: activeDay ? (activeDay.pop + "%") : ((currentObj ? currentObj.humidity : "--") + "%")
                                color: (activeDay && activeDay.pop > 40) ? view.sys.colOn : view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                        }

                        // Ветер
                        ColumnLayout {
                            spacing: 1
                            Text { text: view.sys.tr("Ветер"); color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                            Text {
                                text: (activeDay ? activeDay.wind : (currentObj ? currentObj.wind : "--")) + " " + view.sys.weatherWindUnit
                                color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                        }

                        // УФ-индекс
                        ColumnLayout {
                            spacing: 1
                            Text { text: view.sys.tr("УФ-индекс"); color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                            Text {
                                text: activeDay ? (activeDay.uv + " (" + (activeDay.uv >= 6 ? view.sys.tr("Высокий") : activeDay.uv >= 3 ? view.sys.tr("Умеренный") : view.sys.tr("Низкий")) + ")") : "--"
                                color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                            }
                        }

                        // Восход
                        ColumnLayout {
                            spacing: 1
                            Text { text: view.sys.tr("Восход"); color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                            Text {
                                text: activeDay ? activeDay.sunrise : "--:--"
                                color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                        }

                        // Закат
                        ColumnLayout {
                            spacing: 1
                            Text { text: view.sys.tr("Закат"); color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 9 } }
                            Text {
                                text: activeDay ? activeDay.sunset : "--:--"
                                color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                        }
                    }
                }
            }

            // ----------------------------- Почасовой прогноз (24 часа)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: view.sys.tr("ПОЧАСОВОЙ ПРОГНОЗ")
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 10; letterSpacing: 1.1; bold: true }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "◀ ▶ " + view.sys.tr("Прокрутка")
                        color: Qt.rgba(1, 1, 1, 0.25)
                        font { family: view.sys.fontFam; pixelSize: 9 }
                    }
                }

                Flickable {
                    id: hourlyFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    contentWidth: hourlyRow.implicitWidth
                    contentHeight: 92
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        orientation: Qt.Horizontal
                        onWheel: ev => {
                            var step = ev.pixelDelta.x !== 0 ? ev.pixelDelta.x : (ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x);
                            var max = Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width);
                            hourlyFlick.contentX = Math.max(0, Math.min(max, hourlyFlick.contentX - step));
                        }
                    }

                    RowLayout {
                        id: hourlyRow
                        spacing: 8
                        height: parent.height

                        Repeater {
                            model: hourlyList
                            Rectangle {
                                required property var modelData
                                required property int index
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 88
                                radius: isMaterial ? 16 : 14
                                color: index === 0
                                       ? ((isMaterial && view.sys)
                                          ? (view.sys.colM3PrimaryContainer || (view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : Qt.rgba(1, 1, 1, 0.25)))
                                          : (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16) : Qt.rgba(1, 1, 1, 0.16)))
                                       : (hMa.containsMouse
                                          ? ((isMaterial && view.sys)
                                             ? (view.sys.colM3SurfaceContainerHigh || Qt.rgba(1, 1, 1, 0.08))
                                             : Qt.rgba(1, 1, 1, 0.08))
                                          : ((isMaterial && view.sys)
                                             ? (view.sys.colM3SurfaceContainer || Qt.rgba(1, 1, 1, 0.03))
                                             : Qt.rgba(1, 1, 1, 0.03)))
                                border.color: index === 0
                                       ? (view.sys ? view.sys.colOn : "#ffffff")
                                       : ((isMaterial && view.sys && view.sys.colOn)
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.08)
                                          : Qt.rgba(1, 1, 1, 0.06))
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: index === 0 ? view.sys.tr("Сейчас") : modelData.time
                                        color: index === 0 ? view.sys.colOn : view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: 10; bold: index === 0 }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: view.iconGlyph(modelData.icon)
                                        color: view.sys.colFg
                                        font { family: view.sys.fontFam; pixelSize: 18 }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.temp + "°"
                                        color: view.sys.colFg
                                        font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        visible: modelData.pop > 0
                                        text: modelData.pop + "%"
                                        color: view.sys.colOn
                                        font { family: view.sys.fontFam; pixelSize: 9 }
                                    }
                                }

                                MouseArea {
                                    id: hMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------ Прогноз на 7 дней (Карусель / Список)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Text {
                    text: view.sys.tr("ПРОГНОЗ НА 7 ДНЕЙ")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10; letterSpacing: 1.1; bold: true }
                }

                ListView {
                    id: dailyListComp
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: dailyList
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: dayItem
                        required property var modelData
                        required property int index
                        width: dailyListComp.width
                        height: 38
                        radius: isMaterial ? 14 : 12
                        color: view.selectedDayIndex === index
                               ? ((isMaterial && view.sys)
                                  ? (view.sys.colM3PrimaryContainer || (view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : Qt.rgba(1, 1, 1, 0.25)))
                                  : (view.sys && view.sys.colOn ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22) : Qt.rgba(1, 1, 1, 0.22)))
                               : (dayMa.containsMouse
                                  ? ((isMaterial && view.sys)
                                     ? (view.sys.colM3SurfaceContainerHigh || Qt.rgba(1, 1, 1, 0.06))
                                     : Qt.rgba(1, 1, 1, 0.06))
                                  : ((isMaterial && view.sys)
                                     ? (view.sys.colM3SurfaceContainer || Qt.rgba(1, 1, 1, 0.02))
                                     : Qt.rgba(1, 1, 1, 0.02)))
                        border.color: view.selectedDayIndex === index
                               ? (view.sys ? view.sys.colOn : "#ffffff")
                               : ((isMaterial && view.sys && view.sys.colOn)
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.06)
                                  : Qt.rgba(1, 1, 1, 0.05))
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                Layout.preferredWidth: 110
                                text: view.dayName(dayItem.modelData.date, dayItem.index)
                                color: dayItem.index === 0 ? view.sys.colOn : view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: dayItem.index === 0 || view.selectedDayIndex === dayItem.index }
                            }

                            Text {
                                text: view.iconGlyph(dayItem.modelData.icon)
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 16 }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: view.weatherConditionTr(dayItem.modelData.desc)
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                                elide: Text.ElideRight
                            }

                            // Осадки
                            Text {
                                Layout.preferredWidth: 42
                                visible: dayItem.modelData.pop > 0
                                text: "💧 " + dayItem.modelData.pop + "%"
                                color: dayItem.modelData.pop > 40 ? view.sys.colOn : view.sys.colMuted
                                horizontalAlignment: Text.AlignRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }

                            // Мин / Макс температура
                            RowLayout {
                                Layout.preferredWidth: 90
                                spacing: 6
                                Layout.alignment: Qt.AlignRight

                                Text {
                                    text: dayItem.modelData.tempMin + "°"
                                    color: view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                                }
                                Text {
                                    text: dayItem.modelData.tempMax + "°"
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                                }
                            }
                        }

                        MouseArea {
                            id: dayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.selectedDayIndex = dayItem.index
                        }
                    }
                }
            }
        }
    }
}
