import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Окно настроек: слева поиск и список разделов, справа — сам раздел.
//
// Каждый раздел живёт отдельным файлом Set*.qml и получает только `sys`.
// Шапку с иконкой и описанием рисует каркас, поэтому страницы состоят из
// одних карточек и не повторяют друг за другом одну и ту же разметку.
Item {
    id: view

    property var sys
    // индекс раздела в view.sections
    property int tab: 0
    property alias scrollY: scroll.contentY

    implicitWidth: 1140
    implicitHeight: 780

    // ------------------------------------------------------------- разделы
    // keys — ключевые слова для поиска: по ним раздел находится, даже если
    // в названии нужного слова нет («темы» → Appearance, «wifi» → Control
    // Center).
    readonly property var sections: [
        { id: "bar",     title: "Barra & Notch",  g: 0xF12E1, page: "SetBarIsland.qml",
          sub: view.sys.tr("Cómo se sitúa el notch en el borde y cómo se despliega."),
          keys: "notch island pill bar height width остров вырез капсула barra isla" },
        { id: "customnotch", title: "Notch & Isla Dinámica", g: 0xF0241, page: "SetCustomNotch.qml",
          sub: view.sys.tr("Ajustes personalizados del notch, avisos, animaciones y música."),
          keys: "notch music bateria charging brave wave isla dinamica rayo carga aviso padding" },
        { id: "media",   title: "Multimedia",     g: 0xF0387, page: "SetMedia.qml",
          sub: view.sys.tr("Reproductor, carátulas y visualización en el notch contraído."),
          keys: "player music cover звук плеер музыка обложка reproductor audio canciones" },
        { id: "clock",   title: "Reloj & Fecha",  g: 0xF0150, page: "SetClock.qml",
          sub: view.sys.tr("Formato de hora, zona horaria y fecha mostrada."),
          keys: "clock time date timezone часы дата время пояс регион reloj hora fecha" },
        { id: "look",    title: "Apariencia",     g: 0xF03D8, page: "SetAppearance.qml",
          sub: view.sys.tr("Tema visual, fuentes y geometría de la interfaz."),
          keys: "theme font size radius spacing sounds audio haptics звуки звук звуковые эффекты тема шрифт цвет радиус отступ apariencia fuentes tema" },
        { id: "weather", title: "Clima",          g: 0xF0590, page: "SetWeather.qml",
          sub: view.sys.tr("Clave API, ciudad y unidades del pronóstico del tiempo."),
          keys: "weather temperature city openweather api key celsius fahrenheit "
                + "погода температура город ключ цельсий фаренгейт градусы clima tiempo grados temperatura" },
        { id: "motion",  title: "Movimiento",     g: 0xF15B6, page: "SetMotion.qml",
          sub: view.sys.tr("Velocidad de animaciones, rebotes y transiciones."),
          keys: "animation speed bounce анимация скорость движение movimiento velocidad animacion" },
        { id: "effects", title: "Micro-animaciones", g: 0xF06EF, page: "SetEffects.qml",
          sub: view.sys.tr("Efectos visuales y micro-interacciones en iconos, botones y menús."),
          keys: "animaciones efectos micro animaciones hover detalles iconos apagado power deslizadores" },
        { id: "sounds",  title: "Estudio de Sonido", g: 0xF057E, page: "SetSounds.qml",
          sub: view.sys.tr("Generador de sonidos, sintetizador interactivo y asignación por apariencia."),
          keys: "sounds soundpack sintetizador audio timbre nada nothing material you zen retro cyber chiptune sonidos efectos volumen" },
        { id: "launch",  title: "Lanzador",       g: 0xF0349, page: "SetLauncher.qml",
          sub: view.sys.tr("Búsqueda de aplicaciones, archivos y accesos directos."),
          keys: "launcher apps search запуск приложения поиск lanzador buscar aplicaciones" },
        { id: "dock",    title: "Dock",           g: 0xF018D, page: "SetDock.qml",
          sub: view.sys.tr("Configuración de la barra inferior, aplicaciones y visibilidad."),
          keys: "dock apps barra inferior launcher iconos aplicaciones abajo" },
        { id: "notif",   title: "Notificaciones", g: 0xF009A, page: "SetNotifications.qml",
          sub: view.sys.tr("Gestión de notificaciones, modo no molestar y avisos emergentes."),
          keys: "notifications dnd toast уведомления не беспокоить notificaciones avisos silencio" },
        { id: "cc",      title: "Centro de Control", g: 0xF062E, page: "SetControlCenter.qml",
          sub: view.sys.tr("Distribución y orden de los accesos rápidos del centro de control."),
          keys: "quick settings tiles layout wifi bluetooth плитки быстрые centro control atajos" },
        { id: "lock",    title: "Pantalla de Bloqueo", g: 0xF033E, page: "SetLock.qml",
          sub: view.sys.tr("Configuración de la pantalla de bloqueo, tiempo de espera y desenfoque."),
          keys: "lock screen blur idle блокировка экран размытие pantalla bloqueo password" },
        { id: "display", title: "Pantallas",      g: 0xF0379, page: "SetDisplay.qml",
          sub: view.sys.tr("Resolución, tasa de refresco y escala de las pantallas conectadas."),
          keys: "display monitor resolution refresh scale layout placement detect island "
                + "экран монитор разрешение герцовка раскладка расположение остров pantallas monitores resolucion" },
        { id: "input",   title: "Ratón & Touchpad", g: 0xF037D, page: "SetInput.qml",
          sub: view.sys.tr("Sensibilidad, aceleración y respuesta del ratón y touchpad."),
          keys: "mouse pointer cursor sensitivity speed accel acceleration raw input flat "
                + "мышь указатель курсор скорость сенса чувствительность разгон прямой ввод raton touchpad puntero" },
        { id: "system",  title: "Sistema",        g: 0xF0493, page: "SetSystem.qml",
          sub: view.sys.tr("Información del equipo, procesador, memoria RAM y procesos activos."),
          keys: "about system cpu ram temperature система озу температура процессы sistema procesador memoria disco" }
    ]

    readonly property var section: sections[Math.max(0, Math.min(sections.length - 1, tab))]

    // Раздел могли попросить по имени — например уведомление об обновлении
    // ведёт прямо в System. Имя ищем здесь: список разделов живёт тут же, и
    // никому снаружи не нужно знать, какой у раздела номер.
    function goToSection(id) {
        if (!id) return;
        for (var i = 0; i < view.sections.length; i++) {
            if (view.sections[i].id === id) { view.go(i); break; }
        }
        // просьбу выполнили — иначе повторное открытие настроек снова
        // уводило бы в тот же раздел
        view.sys.settingsSection = "";
    }
    Component.onCompleted: view.goToSection(view.sys.settingsSection)
    Connections {
        target: view.sys
        function onSettingsSectionChanged() { view.goToSection(view.sys.settingsSection); }
    }

    // ------------------------------------------------------------- история
    // Стрелки над разделом ходят по уже открытым, как в браузере: список
    // разделов длинный, и возврат к предыдущему руками сбивает с мысли.
    property var hist: [0]
    property int histAt: 0
    function go(i) {
        if (i === view.tab) return;
        var h = view.hist.slice(0, view.histAt + 1);
        h.push(i);
        view.hist = h;
        view.histAt = h.length - 1;
        view.tab = i;
    }
    function back()    { if (canBack)    { view.histAt--; view.tab = view.hist[view.histAt]; } }
    function forward() { if (canForward) { view.histAt++; view.tab = view.hist[view.histAt]; } }
    readonly property bool canBack:    histAt > 0
    readonly property bool canForward: histAt < hist.length - 1

    // ------------------------------------------------------------- поиск
    property string query: ""
    function matches(s) {
        if (view.query.length === 0) return true;
        var q = view.query.toLowerCase();
        return s.title.toLowerCase().indexOf(q) >= 0 || s.keys.toLowerCase().indexOf(q) >= 0;
    }

    // ========================================================== само окно
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ----------------------------------------------------- сайдбар
        ColumnLayout {
            // Ширина по самой длинной подписи, а не «на глаз»: список
            // разделов известен заранее, и лишний воздух справа от него
            // только отъедал место у самих настроек.
            readonly property real navW: {
                var m = 0;
                for (var i = 0; i < view.sections.length; i++)
                    m = Math.max(m, navMetric.advanceWidth(view.sections[i].title));
                // 7 отступ + 28 значок + 10 зазор + текст + 14 запас.
                // Метрики шрифта по семейству дают чуть меньше, чем меряет
                // сам Text (начертание подбирается позже), поэтому к тексту
                // добавлена десятая часть: без неё длинные названия резались
                // многоточием ровно там, где места на самом деле хватало.
                return Math.max(250, Math.min(340, Math.ceil(m * 1.25) + 72));
            }
            FontMetrics {
                id: navMetric
                font.family: view.sys.fontBody
                font.pixelSize: view.sys.fontSize - 1
            }

            // Вложенный в RowLayout слой по умолчанию растягивается сам —
            // без явного отказа ширина по тексту ничего не решала, и сайдбар
            // забирал всё свободное место.
            Layout.fillWidth: false
            Layout.preferredWidth: navW
            Layout.minimumWidth: navW
            Layout.maximumWidth: navW
            Layout.fillHeight: true
            spacing: 10

            // Encabezado Nothing OS del sidebar
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                Layout.leftMargin: 10
                spacing: 8

                // Точка, плавно переключающаяся между красным и белым каждую секунду
                Rectangle {
                    id: statusDot
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    property bool isRed: false
                    color: isRed ? "#ff3b30" : "#ffffff"
                    Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }

                    Timer {
                        interval: 500
                        repeat: true
                        running: true
                        onTriggered: statusDot.isRed = !statusDot.isRed
                    }
                }

                Text {
                    text: "PANACEA  //  AJUSTES"
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.42)
                    font {
                        family: view.sys.fontBody
                        pixelSize: view.sys.fontSize - 4
                        letterSpacing: 2.2
                        bold: true
                    }
                }
            }

            // поиск по разделам
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 13
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b,
                               searchInput.activeFocus ? 0.12 : 0.065)
                border.width: 1
                border.color: searchInput.activeFocus
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.65)
                              : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0349)
                    color: searchInput.activeFocus ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: clearBtn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: view.sys.colFg
                    clip: true
                    selectByMouse: true
                    selectionColor: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2 }
                    onTextChanged: view.query = text
                    onAccepted: {
                        for (var i = 0; i < view.sections.length; i++)
                            if (view.matches(view.sections[i])) { view.go(i); break; }
                    }
                    Keys.onEscapePressed: { text = ""; focus = false; }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: view.sys.tr("Buscar en configuración...")
                        color: view.sys.colMuted
                        font: searchInput.font
                    }
                }

                Rectangle {
                    id: clearBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    visible: searchInput.text.length > 0
                    color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 11 }
                    }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }

            // список разделов
            ListView {
                id: nav
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: view.sections
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: SetScroll { sys: view.sys }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, nav.contentHeight - nav.height);
                        nav.contentY = Math.max(0, Math.min(max, nav.contentY - d));
                    }
                }

                delegate: Item {
                    id: navDel
                    required property int index
                    required property var modelData
                    readonly property bool shown: view.matches(navDel.modelData)

                    width: nav.width
                    height: shown ? 42 : 0
                    visible: shown

                    Rectangle {
                        id: navItem
                        readonly property bool active: view.tab === navDel.index
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: 13
                        scale: navMa.pressed ? 0.985 : (navMa.containsMouse ? 1.012 : 1.0)
                        color: navItem.active
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                               : (navMa.containsMouse
                                  ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                                  : "transparent")
                        border.width: 1
                        border.color: navItem.active
                                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.38)
                                      : (navMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) : "transparent")

                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                        Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        // Indicador de selección lateral Nothing
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: navItem.active ? 20 : (navMa.containsMouse ? 10 : 0)
                            radius: 1.5
                            color: view.sys.colOn
                            opacity: navItem.active ? 1 : (navMa.containsMouse ? 0.5 : 0)
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 9
                                color: navItem.active
                                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                       : (navMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
                                border.width: 1
                                border.color: navItem.active
                                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                              : (navMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14) : "transparent")

                                Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                                Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(navDel.modelData.g)
                                    color: navItem.active ? view.sys.colOn : (navMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: navDel.modelData.title
                                color: navItem.active ? view.sys.colFg : (navMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                elide: Text.ElideRight
                                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1; bold: navItem.active }
                                Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            }
                        }

                        MouseArea {
                            id: navMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                view.go(navDel.index);
                            }
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------- separador vertical Nothing OS
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.leftMargin: 10
            Layout.rightMargin: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.12; color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) }
                GradientStop { position: 0.88; color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ----------------------------------------------------- раздел
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 0
            spacing: 12

            // стрелки истории и хлебные крошки
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [{ g: 0xF004D, fwd: false }, { g: 0xF0054, fwd: true }]
                    Rectangle {
                        id: navArrow
                        required property var modelData
                        readonly property bool armed: navArrow.modelData.fwd ? view.canForward : view.canBack

                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        opacity: navArrow.armed ? 1 : 0.35
                        scale: arrowMa.pressed ? 0.94 : (arrowMa.containsMouse && navArrow.armed ? 1.05 : 1.0)
                        color: arrowMa.containsMouse && navArrow.armed
                               ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: arrowMa.containsMouse && navArrow.armed
                                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                      : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                        Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(navArrow.modelData.g)
                            color: navArrow.armed ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        MouseArea {
                            id: arrowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: navArrow.armed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                if (navArrow.modelData.fwd) view.forward(); else view.back();
                            }
                        }
                    }
                }

                // Breadcrumb de orientación Nothing OS
                RowLayout {
                    spacing: 6
                    Layout.leftMargin: 6

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: view.sys.colOn
                    }

                    Text {
                        text: "AJUSTES  //  " + view.section.title.toUpperCase()
                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.38)
                        font {
                            family: view.sys.fontBody
                            pixelSize: view.sys.fontSize - 4
                            letterSpacing: 1.8
                            bold: true
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // шапка и карточки раздела в общей прокрутке
            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                ScrollBar.vertical: SetScroll { sys: view.sys }

                // Колесо крутим сами. Собственная обработка Flickable зависит
                // от того, кому достанется событие: остров ловит наведение
                // своим HoverHandler'ом и в части положений забирал колесо
                // себе — прокрутка работала только у верхней кромки.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, scroll.contentHeight - scroll.height);
                        scroll.contentY = Math.max(0, Math.min(max, scroll.contentY - d));
                    }
                }
                Keys.onPressed: event => {
                    var max = Math.max(0, scroll.contentHeight - scroll.height);
                    if (event.key === Qt.Key_Down) {
                        scroll.contentY = Math.min(max, scroll.contentY + 140);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        scroll.contentY = Math.max(0, scroll.contentY - 140);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        scroll.contentY = Math.min(max, scroll.contentY + 360);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        scroll.contentY = Math.max(0, scroll.contentY - 360);
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: pageCol
                    width: scroll.width - 12   // место под полосу прокрутки
                    spacing: 12

                    SetHeader {
                        sys: view.sys
                        glyph: String.fromCodePoint(view.section.g)
                        title: view.section.title
                        sub: view.section.sub
                    }

                    // Страницу поднимаем через setSource с готовым `sys`:
                    // при простом source страница успевает построиться с
                    // пустой ссылкой, и все её привязки к палитре падают.
                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true
                        opacity: 1.0

                        transform: Translate {
                            id: pageTrans
                            y: 0
                        }

                        function reload() {
                            animReload.restart();
                        }
                        Component.onCompleted: setSource(view.section.page, { sys: view.sys })

                        SequentialAnimation {
                            id: animReload
                            ParallelAnimation {
                                NumberAnimation { target: pageLoader; property: "opacity"; to: 0.0; duration: 90; easing.type: Easing.InQuad }
                                NumberAnimation { target: pageTrans; property: "y"; to: -8; duration: 90; easing.type: Easing.InQuad }
                            }
                            ScriptAction {
                                script: {
                                    pageLoader.setSource(view.section.page, { sys: view.sys });
                                    pageTrans.y = 12;
                                }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: pageLoader; property: "opacity"; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                                NumberAnimation { target: pageTrans; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                            }
                        }

                        Connections {
                            target: view
                            function onTabChanged() { pageLoader.reload(); }
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    // раздел сменился — прокрутка начинается сверху, а не там, где кончился
    // предыдущий
    onTabChanged: {
        scroll.contentY = 0;
        nav.positionViewAtIndex(view.tab, ListView.Contain);
    }
}
