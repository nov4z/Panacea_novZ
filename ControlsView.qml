import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth

// Раскрытая панель без музыки: Wi-Fi и Bluetooth.
//
// Три страницы внутри одной панели (sys.page):
//   main — две плитки-переключателя
//   wifi — список сетей + ввод пароля
//   bt   — список устройств
Item {
    id: view
    property var sys
    width: (parent && parent.width > 0) ? parent.width : ((view.sys && view.sys.panelW ? view.sys.panelW : 500) - 30)
    readonly property real ccBtnWidth: ((view.width > 0 ? view.width : ((view.sys && view.sys.panelW ? view.sys.panelW : 500) - 30)) - 4 * 8) / 5

    // Макет для вкладки настроек: та же панель, только неживая. Показывает
    // всегда главную страницу и слушается не сохранённой раскладки, а той,
    // что человек прямо сейчас двигает мышью.
    property bool preview: false
    property var ccOrderOverride: null

    // ------------------------------------------------- порядок блоков панели
    // Пустая настройка — заводской порядок. Неизвестные имена (остались от
    // прежней версии) отбрасываются, забытые дописываются в конец: раскладка
    // переживает и обновление оболочки, и правку файла руками.
    readonly property var ccDefault: ["clock", "wifi", "bt", "volume", "brightness", "media", "record", "battery", "lock", "shot", "notif", "settings", "power", "tray"]
    readonly property var ccDefaultSizes: ({"wifi":"1/2","bt":"1/2","volume":"1","brightness":"1","media":"1","record":"1/2","battery":"1/2","clock":"1","lock":"1/5","shot":"1/5","notif":"1/5","settings":"1/5","power":"1/5","tray":"1"})
    property var ccSizesOverride: null

    readonly property var ccOrder: {
        if (view.ccOrderOverride) return view.ccOrderOverride;
        var cfgLayout = (view.sys && view.sys.cfg) ? (view.sys.cfg.ccLayout || "") : "";
        var raw = String(cfgLayout).split(",").filter(x => x.length);
        var saved = [];
        for (var i = 0; i < raw.length; i++) {
            var k = raw[i];
            if (k === "toggles") { saved.push("wifi"); saved.push("bt"); saved.push("volume"); }
            else if (k === "sliders") { saved.push("brightness"); }
            else if (k === "power") { saved.push("record"); saved.push("battery"); }
            else if (k === "quick") { saved.push("lock"); saved.push("shot"); saved.push("notif"); saved.push("settings"); saved.push("power"); }
            else saved.push(k);
        }
        var out = saved.filter(id => view.ccDefault.indexOf(id) >= 0);
        view.ccDefault.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        return out;
    }

    function ccWidgetSize(id) {
        if (id === "lock" || id === "shot" || id === "notif" || id === "settings" || id === "power") {
            return "1/5";
        }
        if (view.ccSizesOverride && view.ccSizesOverride[id]) return view.ccSizesOverride[id];
        var raw = (view.sys && view.sys.cfg) ? view.sys.cfg.ccSizes : "";
        if (typeof raw === "string" && raw.length > 2) {
            try { var p = JSON.parse(raw); if (p && p[id]) return p[id]; } catch (e) {}
        } else if (raw && typeof raw === "object" && raw[id]) {
            return raw[id];
        }
        return view.ccDefaultSizes[id] || "1";
    }

    readonly property int ccGridCols: 60

    readonly property var ccPositions: {
        var order = view.ccOrder;
        var _sizesDep = view.ccSizesOverride;
        var _cfgSizesDep = (view.sys && view.sys.cfg) ? view.sys.cfg.ccSizes : "";
        var posMap = {};
        var curRow = 0;
        var curCol = 0;
        for (var i = 0; i < order.length; i++) {
            var id = order[i];
            var sz = view.ccWidgetSize(id);
            var span = view.ccGridCols;
            
            if (String(sz).indexOf("/") > 0) {
                var pts = String(sz).split("/");
                var num = parseInt(pts[0]) || 1;
                var den = parseInt(pts[1]) || 1;
                span = Math.round(view.ccGridCols * num / den);
            } else if (String(sz).endsWith("%")) {
                var pct = parseInt(sz) || 100;
                span = Math.round(view.ccGridCols * pct / 100);
            } else {
                span = view.ccGridCols;
            }
            if (span < 1) span = 1;
            if (span > view.ccGridCols) span = view.ccGridCols;

            if (curCol + span > view.ccGridCols) {
                curRow++;
                curCol = 0;
            }
            posMap[id] = { row: curRow, col: curCol, span: span };
            curCol += span;
            if (curCol >= view.ccGridCols) {
                curRow++;
                curCol = 0;
            }
        }
        return posMap;
    }

    // прямоугольник блока в координатах панели — по нему макет ставит
    // накладку для перетаскивания
    function ccBlock(id) {
        for (var i = 0; i < mainPage.children.length; i++)
            if (mainPage.children[i].objectName === "cc-" + id) return mainPage.children[i];
        return null;
    }
    function ccRow(id) {
        return (view.ccPositions[id] ? view.ccPositions[id].row : 0);
    }
    function ccCol(id) {
        return (view.ccPositions[id] ? view.ccPositions[id].col : 0);
    }
    function ccSpan(id) {
        return (view.ccPositions[id] ? view.ccPositions[id].span : view.ccGridCols);
    }

    // «м:сс» для полосы продолжительности; часы появляются только если нужны
    function fmtTime(sec) {
        var t = Math.max(0, Math.floor(sec));
        var h = Math.floor(t / 3600);
        var m = Math.floor((t % 3600) / 60);
        var s = t % 60;
        var mm = h > 0 && m < 10 ? "0" + m : String(m);
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" + s : String(s));
    }

    implicitHeight: stack.implicitHeight

    readonly property color battModeColor: {
        if (view.sys.batteryPct <= 15) return view.sys.colCrit;
        var p = (view.sys.powerProfile || "balanced").toLowerCase();
        if (p === "performance" || p === "max-power") return view.sys.colPowerPerf;
        if (p === "power-saver" || p === "low-power") return view.sys.colPowerSaver;
        return view.sys.colPowerBalanced;
    }

    readonly property color battModeBg: {
        if (view.sys.batteryPct <= 15) return Qt.rgba(0.22, 0.04, 0.05, 0.90);
        var p = (view.sys.powerProfile || "balanced").toLowerCase();
        if (p === "performance" || p === "max-power") return Qt.rgba(0.22, 0.04, 0.05, 0.90);
        if (p === "power-saver" || p === "low-power") return Qt.rgba(0.05, 0.10, 0.24, 0.90);
        return Qt.rgba(0.10, 0.10, 0.12, 0.90);
    }

    readonly property color battModeBorder: {
        var p = (view.sys.powerProfile || "balanced").toLowerCase();
        if (p === "balanced") return Qt.rgba(1.0, 1.0, 1.0, 0.35);
        var c = view.battModeColor;
        return Qt.rgba(c.r, c.g, c.b, 0.50);
    }

    readonly property color battModeWave: {
        var p = (view.sys.powerProfile || "balanced").toLowerCase();
        if (p === "balanced") return Qt.rgba(1.0, 1.0, 1.0, 0.38);
        var c = view.battModeColor;
        return Qt.rgba(c.r, c.g, c.b, 0.78);
    }

    readonly property color battModeInk: {
        var c = view.battModeColor;
        return (c.r > 0.85 && c.g > 0.85 && c.b > 0.85) ? "#111111" : "#ffffff";
    }

    focus: true
    Component.onCompleted: forceActiveFocus()

    // Возврат на плитки. Вынесено в функцию, потому что Escape не всегда
    // доходит сюда: фокус может сидеть в поле пароля Wi-Fi или в списке, и
    // тогда событие всплывает мимо — до Loader'а в shell.qml. Он зовёт
    // goBack() сам, и подстраница закрывается вместо всей панели.
    function goBack() {
        // с меню сети возвращаемся к списку, а не на плитки: человек пришёл
        // сюда из списка и туда же ждёт назад
        if (view.sys.page === "netmenu") {
            view.sys.page = "wifi";
            return true;
        }
        if (view.sys.page === "btmenu") {
            view.sys.page = "bt";
            return true;
        }
        if (view.sys.page === "wifi" || view.sys.page === "bt"
            || view.sys.page === "battery") {
            view.sys.page = "main";
            return true;
        }
        if (view.sys.page === "traymenu") {
            view.sys.page = "main";
            view.sys.trayMenuItem = null;
            return true;
        }
        return false;
    }

    function openBtMenu(dev) {
        if (!dev) return;
        btPage.menuDev = dev;
        btPage.menuName = dev.name || dev.address;
        btPage.menuConnected = dev.connected;
        btPage.menuPaired = dev.paired;
        btPage.menuBonded = dev.bonded;
        view.sys.page = "btmenu";
    }

    Keys.onEscapePressed: {
        // с подстраниц Esc возвращает назад, с главной — закрывает панель
        if (!view.goBack()) view.sys.collapse();
    }

    // ------------------------------------------------------- общие компоненты

    // Сегмент выбора режима питания: иконка + подпись, активный подсвечен
    component PowerSeg: Rectangle {
        property string icon: ""
        property string label: ""
        property string profile: ""
        property color accent: view.sys.colOn
        readonly property bool active: view.sys.powerProfile === profile

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 14
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.24)
                      : (segMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                             : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045))
        border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.55)
                             : (segMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.18)
                                                    : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        scale: segMa.pressed ? 0.97 : (segMa.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                color: parent.parent.active ? parent.parent.accent : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.70)
                font { family: view.sys.fontFam; pixelSize: 17 }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 11; bold: parent.parent.active }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.setPowerProfile(parent.profile)
        }
    }

    // Плитка: слева иконка (переключает), справа название (открывает список)
    component Tile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        signal iconClicked()
        signal bodyClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 16
        color: on ? (bodyMa.containsMouse ? (accent === view.sys.colOn ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(accent.r, accent.g, accent.b, 0.22))
                                          : (accent === view.sys.colOn ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(accent.r, accent.g, accent.b, 0.16)))
                  : (bodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05))
        border.color: on ? (bodyMa.containsMouse ? (accent === view.sys.colOn ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(accent.r, accent.g, accent.b, 0.50))
                                                 : (accent === view.sys.colOn ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(accent.r, accent.g, accent.b, 0.35)))
                         : (bodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : view.sys.colLine)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        scale: bodyMa.pressed ? 0.97 : ((bodyMa.containsMouse && view.sys.cfg.animTileHover !== false) ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 11

            // круглая кнопка-иконка — включить/выключить
            Rectangle {
                id: iconBtn
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: parent.parent.on ? parent.parent.accent : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: iconMa.pressed ? 0.95 : ((iconMa.containsMouse && view.sys.cfg.animTileHover) ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: iconBtn.parent.parent.icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }
                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: iconBtn.parent.parent.iconClicked()
                }
            }

            // подпись — открывает список
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            Text {
                text: ""
                color: bodyMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: bodyMa
            anchors.fill: parent
            anchors.leftMargin: 58     // не перекрываем круглую кнопку
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Кнопка-иконка нижнего ряда: замок, уведомления, настройки.
    component IconBtn: Rectangle {
        id: ibRoot
        property string glyph: ""
        property string tip: ""
        property color glyphColor: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.70)
        property color activeColor: view.sys.colOn
        property bool active: false
        property int badge: 0
        readonly property bool containsMouse: ibMa.containsMouse
        signal act()

        implicitWidth: 46
        implicitHeight: 46
        radius: 16
        z: ibMa.containsMouse ? 10 : 0
        color: ibMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                                  : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
        border.color: active ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.5)
                             : (ibMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.22)
                                                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        scale: ibMa.pressed ? 0.94 : (ibMa.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

        Glyph {
            anchors.centerIn: parent
            glyph: parent.glyph
            color: parent.active ? parent.activeColor
                 : ibMa.containsMouse ? view.sys.colFg : parent.glyphColor
            fontFam: view.sys.fontFam
            size: view.sys.iconSize
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        // счётчик непрочитанных — стильный парящий бейдж
        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            visible: parent.badge > 0
            color: view.sys.colOn
            border.color: view.sys.colBg
            border.width: 1.5
            Text {
                anchors.centerIn: parent
                text: parent.parent.badge > 9 ? "9+" : parent.parent.badge
                color: view.sys.fgOn(view.sys.colOn)
                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }
    }

    // Волна «идёт зарядка»: две несинхронные синусоиды, налитые до уровня
    // заряда и медленно ползущие вбок. Скругление рисуем прямо в канве и
    // используем как маску — обычный clip у Item только прямоугольный.
    component ChargeWave: Canvas {
        property color tint: view.sys.colOk
        property real level: 0.5        // доля высоты, до которой налито
        property real radius: 14
        property bool running: false
        property real phase: 0

        opacity: running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on tint { ColorAnimation { duration: 250 } }

        onPhaseChanged: requestPaint()
        onLevelChanged: requestPaint()
        // Без этого волна остаётся того цвета, каким её нарисовали в первый
        // раз: канва сама себя не перерисовывает, а цвет приходит от темы и
        // меняется на ходу — после переключения на Nothing заливка оставалась
        // зелёной от прежней темы.
        onTintChanged: requestPaint()

        Timer {
            interval: 45
            running: parent.running && parent.visible
            repeat: true
            onTriggered: parent.phase += 0.16
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;

            // маска — скруглённый прямоугольник плитки
            var r = Math.min(radius, Math.min(width, height) / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.arcTo(width, 0, width, height, r);
            ctx.arcTo(width, height, 0, height, r);
            ctx.arcTo(0, height, 0, 0, r);
            ctx.arcTo(0, 0, width, 0, r);
            ctx.closePath();
            ctx.clip();

            // Уровень держим в стороне от краёв: у самого верха волна
            // срезается маской и выглядит как ровная полоса.
            var base = height * (1 - Math.max(0.12, Math.min(0.92, level)));
            var amp = 3.2;
            var k = 0.055;

            var wavePts = [];
            for (var x = 0; x <= width; x += 2) {
                var y = base + amp * Math.sin(k * x + phase)
                             + amp * 0.5 * Math.sin(k * 1.9 * x - phase * 0.7);
                wavePts.push({x: x, y: y});
            }

            // 1. Relleno del cuerpo de agua con el color dinámico del modo de energía (1 sola ola)
            ctx.beginPath();
            ctx.moveTo(0, height);
            for (var i = 0; i < wavePts.length; i++) {
                ctx.lineTo(wavePts[i].x, wavePts[i].y);
            }
            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.22);
            ctx.fill();

            // 2. Borde / cresta superior de la ola: tono gris sutil
            ctx.beginPath();
            for (var i = 0; i < wavePts.length; i++) {
                if (i === 0) ctx.moveTo(wavePts[i].x, wavePts[i].y);
                else ctx.lineTo(wavePts[i].x, wavePts[i].y);
            }
            ctx.strokeStyle = Qt.rgba(0.70, 0.70, 0.72, 0.70);
            ctx.lineWidth = 1.25;
            ctx.stroke();
        }
    }

    // Компактная плитка для верхней строки: Wi-Fi и Bluetooth стоят рядом,
    // а не двумя полосами друг под другом. Иконка меньше, подпись в две
    // строки, шеврон убран — на треть ширины он только съедал место.
    component MiniTile: Rectangle {
        id: tile
        property string icon: ""
        property Component iconItem: null
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        Behavior on accent { ColorAnimation { duration: 250 } }
        property color customBg: "transparent"
        property color customBorder: "transparent"
        // плитка батареи наливается волной, пока идёт зарядка
        property bool wave: false
        property real waveLevel: 0.5
        property bool hasSubpage: false
        signal iconClicked()
        signal bodyClicked()

        implicitWidth: 140
        implicitHeight: 64
        radius: 18
        color: customBg.a > 0
               ? (tileMa.containsMouse ? Qt.rgba(customBg.r * 1.15, customBg.g * 1.15, customBg.b * 1.15, customBg.a) : customBg)
               : (tileMa.containsMouse
                  ? (on ? (accent === view.sys.colOn ? Qt.rgba(accent.r, accent.g, accent.b, 0.24) : Qt.rgba(accent.r, accent.g, accent.b, 0.26))
                        : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
                  : (on ? (accent === view.sys.colOn ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : Qt.rgba(accent.r, accent.g, accent.b, 0.18))
                        : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)))
        border.color: customBorder.a > 0
                      ? (tileMa.containsMouse ? Qt.rgba(customBorder.r * 1.15, customBorder.g * 1.15, customBorder.b * 1.15, 0.65) : customBorder)
                      : (tile.on
                         ? (tileMa.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.60) : Qt.rgba(accent.r, accent.g, accent.b, 0.40))
                         : (tileMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.18) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)))
        border.width: tile.on ? 1.5 : 1
        clip: true
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        scale: tileMa.pressed ? 0.97 : ((tileMa.containsMouse && view.sys.cfg.animTileHover !== false) ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        // под содержимым: волна не должна перекрывать подписи
        ChargeWave {
            anchors.fill: parent
            radius: parent.radius
            tint: parent.accent
            level: parent.waveLevel
            running: parent.wave
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 9

            Rectangle {
                id: miniIcon
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: tile.on ? tile.accent : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.color: tile.on ? "transparent" : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: miniIconMa.pressed ? 0.95 : ((miniIconMa.containsMouse && view.sys.cfg.animTileHover) ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                readonly property color ink: tile.on ? view.sys.fgOn(tile.accent) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.75)

                Text {
                    anchors.centerIn: parent
                    visible: tile.iconItem === null
                    text: tile.icon
                    color: miniIcon.ink
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }

                Loader {
                    id: iconLoader
                    anchors.centerIn: parent
                    active: tile.iconItem !== null
                    sourceComponent: tile.iconItem
                }

                Binding {
                    target: iconLoader.item
                    property: "color"
                    value: miniIcon.ink
                    when: iconLoader.item !== null
                }
                MouseArea {
                    id: miniIconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniIcon.parent.parent.iconClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: tile.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Text {
                visible: tile.hasSubpage
                text: "󰅂"
                color: tileMa.containsMouse ? view.sys.colFg : Qt.rgba(1, 1, 1, 0.28)
                font { family: view.sys.fontFam; pixelSize: 13 }
                Layout.alignment: Qt.AlignVCenter
                transform: Translate {
                    x: (tileMa.containsMouse && view.sys.cfg.animChevronSlide) ? 2 : 0
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            anchors.leftMargin: 48     // не перекрываем круглую кнопку
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Мелкая плашка с цифрой на странице батареи
    component BattStat: Rectangle {
        property string label: ""
        property string value: ""

        implicitWidth: 90
        implicitHeight: 46
        Layout.fillWidth: true
        radius: 14
        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 10 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
            }
        }
    }

    // Круглая кнопка управления плеером в карточке трека.
    component MediaBtn: Rectangle {
        property string icon: ""
        property bool primary: false
        property bool enabledAction: true
        signal act()

        implicitWidth: primary ? 42 : 34
        implicitHeight: primary ? 42 : 34
        radius: (view.sys && view.sys.themeMaterial) ? (primary ? 18 : 12) : width / 2
        color: primary
              ? ((view.sys && view.sys.themeMaterial)
                 ? (mbMa.containsMouse ? Qt.lighter(view.sys.colOn, 1.08) : view.sys.colOn)
                 : view.sys.colFg)
              : (mbMa.containsMouse ? view.sys.colHover : Qt.rgba(1, 1, 1, 0.08))
        opacity: enabledAction ? 1 : 0.35
        Behavior on radius { NumberAnimation { duration: 160 } }
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mbMa.pressed ? 0.95 : (mbMa.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.primary
                   ? ((view.sys && view.sys.themeMaterial)
                      ? (view.sys.colM3OnPrimary || view.sys.colBg)
                      : view.sys.colBg)
                   : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: parent.primary ? 17 : 14 }
        }
        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabledAction
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }
    }

    // Карточка звука той же высоты: название устройства сверху, под ним
    // ползунок прямо в плитке — громкость правится не уходя на страницу.
    // Дорожка-ползунок: заполнение и есть ручка, как в iOS — отдельный кружок
    // на такой высоте некуда было бы поставить. Одна на громкость и яркость:
    // они стоят рядом в одной строке, и любое расхождение в поведении между
    // соседними ползунками читается как поломка одного из них.
    component Track: Item {
        id: trk

        property real pos: 0                  // 0..1 — что показывать
        property string icon: ""              // значок слева, поверх заливки
        property string valueText: ""         // цифра справа
        property real wheelStep: 0.05
        property bool dim: false              // выключено (без звука)

        signal setFrac(real frac)
        signal iconClicked()

        implicitHeight: 24

        readonly property real padL: trk.icon.length ? 24 : 0
        function fracAt(x) {
            return Math.max(0, Math.min(1, (x + trk.padL) / Math.max(1, trk.width)));
        }

        // Заливка не анимируется в двух случаях: пока её тянут — она обязана
        // стоять точно под курсором, иначе догон читается как задержка ввода;
        // и в первые мгновения после создания — значение приходит уже после
        // него, и полоска каждый раз разъезжалась бы от нуля до своего места
        // на глазах у человека, открывшего панель.
        property bool live: false
        Component.onCompleted: liveTimer.start()
        Timer { id: liveTimer; interval: 260; onTriggered: trk.live = true }

        // Своя отметка на время серии прокруток колесом, см. onWheel ниже.
        property real wheelFrom: -1
        Timer { id: wheelIdle; interval: 260; onTriggered: trk.wheelFrom = -1 }

        property real held: -1
        readonly property real shown: trk.held >= 0 ? trk.held : trk.pos
        Timer { id: heldIdle; interval: 400; onTriggered: trk.held = -1 }
        function put(frac) {
            trk.held = Math.max(0, Math.min(1, frac));
            heldIdle.restart();
            trk.setFrac(trk.held);
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: (trkMa.containsMouse && view.sys.cfg.animSlidersGlow) ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
            border.color: (trkMa.containsMouse && view.sys.cfg.animSlidersGlow) ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            clip: true
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: Math.max(parent.height, parent.width * trk.shown)
                height: parent.height
                radius: height / 2
                color: (trkMa.containsMouse && view.sys.cfg.animSlidersGlow) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)
                opacity: trk.dim ? 0.40 : 1.0
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on width {
                    enabled: trk.live && !trkMa.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        Text {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            visible: trk.icon.length > 0
            text: trk.icon
            color: (trk.width * trk.shown) > 22 ? "#121212" : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 14 }
        }

        Text {
            id: trkVal
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: trk.valueText
            color: (trk.width * trk.shown) > (trk.width - trkVal.width - 12)
                   ? "#121212" : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
        }

        MouseArea {
            id: trkMa
            anchors.fill: parent
            anchors.leftMargin: trk.padL
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => trk.put(trk.fracAt(mouse.x))
            onPositionChanged: mouse => { if (pressed) trk.put(trk.fracAt(mouse.x)); }
            onWheel: wheel => {
                var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (d === 0) return;
                var base = trk.wheelFrom >= 0 ? trk.wheelFrom : trk.shown;
                var steps = Math.round(base / trk.wheelStep) + (d > 0 ? 1 : -1);
                var next = Math.max(0, Math.min(1, steps * trk.wheelStep));
                trk.wheelFrom = next;
                wheelIdle.restart();
                trk.put(next);
            }
        }

        MouseArea {
            width: 24
            height: parent.height
            visible: trk.icon.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: trk.iconClicked()
        }
    }

    component VolCard: Rectangle {
        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 11
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Звук")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: view.sys.sinkName.length ? view.sys.sinkName
                                                   : view.sys.tr("Нет устройств")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
            }

            Track {
                id: vol
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property var a: view.sys.sinkAudio

                pos: vol.a ? vol.a.volume : 0
                dim: vol.a ? vol.a.muted : true
                icon: !vol.a ? String.fromCodePoint(0xF075F)
                    : vol.a.muted ? String.fromCodePoint(0xF075F)
                    : vol.a.volume < 0.34 ? String.fromCodePoint(0xF057F)
                    : vol.a.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                          : String.fromCodePoint(0xF057E)
                valueText: !vol.a ? "—"
                    : vol.a.muted ? view.sys.tr("Без звука")
                                  : Math.round(vol.shown * 100) + "%"
                onSetFrac: f => { if (vol.a) vol.a.volume = Math.round(f * 20) / 20; }
                onIconClicked: if (vol.a) vol.a.muted = !vol.a.muted
            }
        }
    }

    component BrightCard: Rectangle {
        id: brCard
        property string bid: ""
        property int    bpct: 0
        property string bname: ""

        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Яркость")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.maximumWidth: 130
                    text: brCard.bname
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Track {
                id: brTrk
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                pos: Math.max(0, Math.min(1, brCard.bpct / 100))
                icon: String.fromCodePoint(0xF00DD)   // солнце
                valueText: Math.round(brTrk.shown * 100) + "%"
                onSetFrac: f => view.sys.brightSet(brCard.bid, Math.round(f * 20) * 5)
                onIconClicked: {}
            }
        }
    }

    // Шапка страницы-списка: назад + заголовок + обновить
    component Header: RowLayout {
        property string title: ""
        property bool busy: false
        signal back()
        signal refresh()

        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 32; Layout.preferredHeight: 32
            radius: 16
            color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
            border.color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
            scale: backMa.pressed ? 0.95 : (backMa.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: "󰁍"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 15 }
            }
            MouseArea {
                id: backMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.back()
            }
        }
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 14; bold: true }
        }
        Rectangle {
            Layout.preferredWidth: 32; Layout.preferredHeight: 32
            radius: 16
            color: refMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
            border.color: refMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
            scale: refMa.pressed ? 0.95 : (refMa.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Text {
                id: refIcon
                anchors.centerIn: parent; text: "󰑐"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 14 }
                RotationAnimator on rotation {
                    running: refIcon.parent.parent.busy
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
            }
            MouseArea {
                id: refMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.refresh()
            }
        }
    }

    // Строка списка
    component Row1: Rectangle {
        id: rowRoot
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool highlight: false
        property bool hasMenu: false
        property color accentColor: view.sys.colOn
        signal activated()
        signal menuRequested(real mx, real my)

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        radius: 14
        color: (rowMa.containsMouse || menuMa.containsMouse)
             ? Qt.rgba(1, 1, 1, 0.08)
             : (highlight ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.14) : Qt.rgba(1, 1, 1, 0.045))
        border.color: highlight
                    ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.40)
                    : ((rowMa.containsMouse || menuMa.containsMouse) ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07))
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        scale: rowMa.pressed ? 0.985 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: (rowMa.containsMouse && !rowRoot.highlight && view.sys.cfg.animMenuSlide) ? 2 : 0
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    var p = mapToItem(rowRoot.parent, mouse.x, mouse.y);
                    rowRoot.menuRequested(p.x, p.y);
                } else {
                    rowRoot.activated();
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 11

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: rowRoot.highlight ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                border.color: rowRoot.highlight ? "transparent" : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: rowRoot.icon
                    color: rowRoot.highlight ? view.sys.fgOn(view.sys.colOn) : view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: rowRoot.title
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Text {
                    text: rowRoot.sub
                    visible: text.length > 0
                    color: rowRoot.highlight ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Rectangle {
                visible: rowRoot.highlight
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                border.color: view.sys.colOn
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰄬"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
            }

            Rectangle {
                id: menuBtn
                visible: rowRoot.hasMenu
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: menuMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18)
                     : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                rotation: (menuMa.containsMouse && view.sys.cfg.animTileRotate) ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                scale: menuMa.pressed ? 0.92 : ((menuMa.containsMouse && view.sys.cfg.animTileRotate) ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "󰇙"
                    color: menuMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }

                MouseArea {
                    id: menuMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        var p = mapToItem(rowRoot.parent, mouse.x, mouse.y);
                        rowRoot.menuRequested(p.x, p.y);
                    }
                }
            }
        }
    }

    // Фигура значка проводной сети. Одна на всю панель: Loader создаёт по
    // своей копии там, где она понадобилась.
    Component {
        id: lanShape
        LanGlyph { width: 13; height: 13 }
    }

    // Число: точками на Nothing, обычным шрифтом на остальных темах.
    //
    // Раскладка панели у тем общая, разное только начертание, — поэтому
    // выбор спрятан сюда, а не размазан по каждому месту с цифрой. Кегль
    // шрифта берётся с запасом от высоты точечной цифры: у той высота и есть
    // весь рост, а у буквы pixelSize считается по всей строке.
    component Num: Item {
        id: num
        property string value: ""
        property real size: 12
        property real gapRatio: 0.22
        property color color: view.sys.colFg

        implicitWidth:  view.sys.themeNothing ? nDots.implicitWidth  : nPlain.implicitWidth
        implicitHeight: view.sys.themeNothing ? nDots.implicitHeight : nPlain.implicitHeight

        DotText {
            id: nDots
            visible: view.sys.themeNothing
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
        Text {
            id: nPlain
            visible: !view.sys.themeNothing
            text: num.value
            color: num.color
            font { family: view.sys.fontFam; pixelSize: Math.round(num.size * 1.35) }
        }
    }

    // ------------------------------------------------------------ запись
    // Плашка записи для темы Nothing: круглая кнопка, подпись и таймер.
    //
    // Обычная плитка показывала на этом месте частоту кадров, пока запись не
    // идёт. Число это из настроек, меняют его раз в жизни, а места оно
    // занимает столько же, сколько отсчёт. Здесь вместо него всегда стоят
    // часы записи: до начала на нуле, дальше идут.
    component RecordCard: Rectangle {
        id: recCard

        radius: 18
        color: recBodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045)
        border.color: view.sys.recActive
                      ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g,
                                view.sys.colCrit.b, 0.45)
                      : (recBodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        scale: recBodyMa.pressed ? 0.985 : ((recBodyMa.containsMouse && view.sys.cfg.animCardLift) ? 1.015 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // тело открывает страницу записи, кнопка — начинает и останавливает
        MouseArea {
            id: recBodyMa
            anchors.fill: parent
            anchors.leftMargin: 52
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.togglePage("record")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                id: recBtn
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 19
                color: view.sys.recActive ? (view.sys.colRec || view.sys.colCrit) : (recBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                border.color: view.sys.recActive ? "transparent" : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: recBtnMa.pressed ? 0.95 : ((recBtnMa.containsMouse && view.sys.cfg.animTileHover) ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(view.sys.recActive ? 0xF04DB : 0xF040A)
                    color: view.sys.recActive
                           ? view.sys.fgOn(view.sys.colCrit) : "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }

                MouseArea {
                    id: recBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.toggleRecord()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: view.sys.tr("Запись")
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font {
                        family: view.sys.fontFam; pixelSize: 12; bold: true
                    }
                }

                Num {
                    Layout.alignment: Qt.AlignLeft
                    value: view.sys.recTimeText
                    size: view.sys.dotHSmall + 2
                    color: !view.sys.recActive ? view.sys.colMuted
                         : view.sys.recPaused ? view.sys.colWarn
                                              : view.sys.colFg
                }
            }

            Text {
                text: "󰅂"
                color: recBodyMa.containsMouse ? view.sys.colFg : Qt.rgba(1, 1, 1, 0.28)
                font { family: view.sys.fontFam; pixelSize: 13 }
                Layout.alignment: Qt.AlignVCenter
                transform: Translate {
                    x: (recBodyMa.containsMouse && view.sys.cfg.animChevronSlide) ? 2 : 0
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    // ------------------------------------------------- нагрузка машины
    // Три строки: процессор, память, видео. Проценты — полоской и числом
    // сразу: полоска показывает «много или мало» с одного взгляда, число
    // отвечает «насколько именно», и одно другого не заменяет.
    component LoadRow: RowLayout {
        id: lrow
        property string glyph: ""
        property string name: ""
        property int pct: -1
        property int temp: -1

        // Мерить нечем — строки нет совсем. Полоска в нуле читалась бы как
        // «простаивает», а это другое утверждение.
        visible: lrow.pct >= 0
        spacing: 8

        Glyph {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            glyph: lrow.glyph
            color: view.sys.colMuted
            fontFam: view.sys.fontFam
            size: 12
        }

        Text {
            Layout.preferredWidth: 30
            text: lrow.name
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: 9; letterSpacing: 0.6 }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            Layout.alignment: Qt.AlignVCenter
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, lrow.pct)) / 100
                height: parent.height
                radius: parent.radius
                color: view.sys.colFg
                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        // Ширину под число резервируем по «100%», иначе полоска слева
        // дёргалась бы на каждом переходе через десяток.
        //
        // Меряем настоящим невидимым числом, а не круглой цифрой на глаз:
        // ширина точечного знака зависит и от высоты, и от просветов, и от
        // того, сколько столбцов сетки у «%». Прежние 30 пикселей были
        // меньше нужного едва не вдвое — число вылезало на полоску.
        Item {
            Layout.preferredWidth: pctRuler.implicitWidth
            Layout.preferredHeight: pctRuler.implicitHeight

            Num {
                id: pctRuler
                visible: false
                value: "100%"
                size: view.sys.dotHTiny
            }

            Num {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: lrow.pct + "%"
                size: view.sys.dotHTiny
                color: view.sys.colFg
            }
        }

        // Датчик есть не у всех: у процессора он почти всегда, у видео —
        // как повезёт с драйвером.
        RowLayout {
            spacing: 3
            visible: lrow.temp >= 0

            Glyph {
                Layout.preferredWidth: 11
                Layout.preferredHeight: 11
                glyph: String.fromCodePoint(0xF0E01)
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
                fontFam: view.sys.fontFam
                size: 10
            }
            Num {
                Layout.alignment: Qt.AlignVCenter
                value: lrow.temp + "°"
                size: view.sys.dotHTiny
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
            }
        }
    }

    component LoadCard: Rectangle {
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 4

            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0EE0); name: "CPU"
                pct: view.sys.loadCpu; temp: view.sys.loadTempCpu
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF035B); name: "RAM"
                pct: view.sys.loadMem
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0379); name: "GPU"
                pct: view.sys.loadGpu; temp: view.sys.loadTempGpu
            }
        }
    }

    // ------------------------------------------------------------- страницы
    Item {
        id: stack
        width: parent.width
        implicitHeight: (view.preview || view.sys.page === "main") ? mainPage.implicitHeight
                      : view.sys.page === "wifi" ? wifiPage.implicitHeight
                      : view.sys.page === "netmenu" ? netMenuPage.implicitHeight
                      : view.sys.page === "btmenu" ? btMenuPage.implicitHeight
                      : view.sys.page === "traymenu" ? trayPage.implicitHeight
                      : view.sys.page === "battery" ? battPage.implicitHeight
                      : btPage.implicitHeight
        // Высоту анимирует сама капсула в shell.qml. Вторая анимация здесь
        // складывалась с ней: капсула догоняла уже анимируемое значение,
        // и панель расширялась заметно дольше, чем нужно.

        // ---------------------------------------------------------- главная
        // Сетка в одну колонку, а не столбец: только она умеет явный номер
        // строки у каждого ребёнка. Порядок блоков задаётся во вкладке
        // Control Center и приходит сюда строкой из настроек — переносить
        // сам код блоков ради этого не пришлось.
        GridLayout {
            id: mainPage
            width: parent.width
            columns: view.ccGridCols
            columnSpacing: 8
            rowSpacing: 12
            readonly property bool isCurrent: (view.preview || view.sys.page === "main")
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: mainPage.isCurrent ? 0 : -28
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            // заголовок с часами и датой: клик открывает календарь
            Rectangle {
                objectName: "cc-clock"
                Layout.row: view.ccRow("clock")
                Layout.column: view.ccCol("clock")
                Layout.columnSpan: view.ccSpan("clock")
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: "transparent"
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    // Часы
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Text {
                            visible: !view.sys.themeNothing
                            text: view.sys.timeText
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 8; bold: true }
                        }

                        RowLayout {
                            visible: view.sys.themeNothing
                            spacing: 5
                            Layout.alignment: Qt.AlignVCenter

                            DotText {
                                Layout.alignment: Qt.AlignVCenter
                                value: view.sys.timeText
                                size: view.sys.dotHBig
                                color: view.sys.colFg
                            }
                            DotText {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                visible: !view.sys.cfg.clockSeconds
                                value: view.sys.secText
                                size: view.sys.dotHSmall
                                color: view.sys.colMuted
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Дата и переход в календарь
                    Rectangle {
                        id: datePill
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 30
                        implicitWidth: dateRow.implicitWidth + 20
                        radius: 15
                        color: dateMa.containsMouse
                               ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                        border.color: dateMa.containsMouse
                                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                      : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        scale: dateMa.pressed ? 0.96 : (dateMa.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                        RowLayout {
                            id: dateRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰸗"
                                color: dateMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 13 }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                            Text {
                                text: view.sys.dateLong
                                color: dateMa.containsMouse ? view.sys.colFg : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.85)
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                        }

                        MouseArea {
                            id: dateMa
                            anchors.fill: parent
                            hoverEnabled: view.sys.cfg.featCalendar
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.togglePage("cal")
                        }
                    }
                }
            }

            // ------------------------------- Wi-Fi
            MiniTile {
                id: ccWifiBlock
                objectName: "cc-wifi"
                Layout.row: view.ccRow("wifi")
                Layout.column: view.ccCol("wifi")
                Layout.columnSpan: view.ccSpan("wifi")
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                hasSubpage: true
                iconItem: view.sys.wiredOn ? lanShape : null
                icon: view.sys.wifiOn ? (view.sys.wifiQuality > 66 ? "󰤨"
                                       : view.sys.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                label: view.sys.wiredOn ? view.sys.tr("Проводная сеть")
                     : (view.sys.wifiOn && view.sys.wifiSsid.length)
                       ? view.sys.wifiSsid : "Wi-Fi"
                sub: view.sys.wiredOn ? view.sys.wiredName
                   : !view.sys.wifiOn ? view.sys.tr("Выключен")
                   : (view.sys.wifiSsid.length
                      ? view.sys.wifiQuality + "%"
                      : view.sys.tr("Не подключено"))
                on: view.sys.wiredOn || view.sys.wifiOn
                onIconClicked: if (!view.sys.wiredOn) view.sys.toggleWifi()
                onBodyClicked: {
                    if (!view.sys.wifiOn || !view.sys.cfg.featWifi) return;
                    view.sys.openSub("wifi");
                    view.sys.refreshWifiList();
                    view.sys.scanWifi();
                }
            }

            // ------------------------------- Bluetooth
            MiniTile {
                id: ccBtBlock
                objectName: "cc-bt"
                Layout.row: view.ccRow("bt")
                Layout.column: view.ccCol("bt")
                Layout.columnSpan: view.ccSpan("bt")
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                hasSubpage: true
                icon: view.sys.btOn ? "󰂯" : "󰂲"
                label: (view.sys.btOn && view.sys.btConnectedName.length)
                       ? view.sys.btConnectedName : "Bluetooth"
                sub: !view.sys.btOn ? view.sys.tr("Выключен")
                   : (view.sys.btConnectedName.length
                      ? (view.sys.btConnectedBattery >= 0
                         ? "󰥉 " + view.sys.btConnectedBattery + "%"
                         : view.sys.tr("Подключено"))
                      : view.sys.tr("Нет подключений"))
                on: view.sys.btOn
                accent: view.sys.colOn
                onIconClicked: view.sys.toggleBt()
                onBodyClicked: {
                    if (!view.sys.btOn || !view.sys.cfg.featBluetooth) return;
                    view.sys.openSub("bt");
                    view.sys.scanBt();
                }
            }

            // ------------------------------- Звук
            VolCard {
                id: ccVolBlock
                objectName: "cc-volume"
                Layout.row: view.ccRow("volume")
                Layout.column: view.ccCol("volume")
                Layout.columnSpan: view.ccSpan("volume")
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                visible: view.sys.cfg.featAudio
            }

            // ------------------------------------------- Яркость
            Item {
                id: ccBrightBlock
                objectName: "cc-brightness"
                Layout.row: view.ccRow("brightness")
                Layout.column: view.ccCol("brightness")
                Layout.columnSpan: view.ccSpan("brightness")
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                visible: view.preview || ((view.sys.brightList || []).length > 0)

                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    Repeater {
                        model: (view.preview && (!view.sys.brightList || view.sys.brightList.length === 0))
                               ? [{ id: "preview", pct: 75, name: "" }]
                               : view.sys.brightList

                        BrightCard {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 56
                            bid:  modelData.id
                            bpct: modelData.pct
                            bname: (view.sys.brightList || []).length > 1 ? modelData.name : ""
                        }
                    }
                }
            }

            // ----------------------------------------------- играющий трек
            // Стоит под переключателями: пока что-то играет, трек с кнопками
            // и эквалайзером во всю ширину заменяет отдельную страницу
            // плеера, которая раньше открывалась по наведению.
            Rectangle {
                objectName: "cc-media"
                Layout.row: view.ccRow("media")
                Layout.column: view.ccCol("media")
                Layout.columnSpan: view.ccSpan("media")
                id: mediaCard
                readonly property var p: view.sys.player
                property bool lyricsOpen: (view.sys && view.sys.mediaLyricsOpen !== undefined) ? view.sys.mediaLyricsOpen : false

                // Sombra saturada y brillante con el tono de la portada (sombra nueva)
                readonly property color shadowColor: {
                    var c = view.sys.mediaArtColor;
                    var h = (c && c.hslHue >= 0) ? c.hslHue : (view.sys.colOn.hslHue >= 0 ? view.sys.colOn.hslHue : 0.55);
                    var s = Math.min(1.0, Math.max(0.75, (c && c.hslSaturation > 0 ? c.hslSaturation : 0.8) * 1.35));
                    var l = Math.max(0.50, Math.min(0.72, (c && c.hslLightness > 0 ? c.hslLightness : 0.5) * 1.25));
                    return Qt.hsla(h, s, l, 1.0);
                }

                visible: (view.preview || view.sys.mediaActive) && (view.preview || view.sys.cfg.featPlayer)
                Layout.fillWidth: true
                Layout.preferredHeight: mediaCard.lyricsOpen ? 340 : 124
                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: mediaCard.lyricsOpen ? 340 : 280
                        easing.type: mediaCard.lyricsOpen ? Easing.OutBack : Easing.OutCubic
                        easing.overshoot: 1.05
                    }
                }
                clip: true
                Layout.topMargin: 14
                Layout.bottomMargin: 16
                radius: 16
                // Base del panel para aislar el interior del resplandor de la sombra posterior
                color: view.sys.colBg
                border.color: Qt.rgba(view.sys.mediaArtColor.r, view.sys.mediaArtColor.g, view.sys.mediaArtColor.b, cardHover.hovered ? 0.30 : 0.18)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 220 } }

                HoverHandler {
                    id: cardHover
                }

                // Tono sutil poco visible en el fondo (0.08 en reposo, 0.13 en hover)
                Rectangle {
                    anchors.fill: parent
                    radius: mediaCard.radius
                    color: Qt.rgba(view.sys.mediaArtColor.r, view.sys.mediaArtColor.g, view.sys.mediaArtColor.b, cardHover.hovered ? 0.13 : 0.08)
                    Behavior on color { ColorAnimation { duration: 220 } }
                }

                // Внутренний градиент-тень под цвет обложки альбома (0.14 -> 0.05 -> 0.01)
                Rectangle {
                    anchors.fill: parent
                    radius: mediaCard.radius
                    visible: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(view.sys.mediaArtColor.r, view.sys.mediaArtColor.g, view.sys.mediaArtColor.b, cardHover.hovered ? 0.20 : 0.14)
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                        GradientStop {
                            position: 0.6
                            color: Qt.rgba(view.sys.mediaArtColor.r, view.sys.mediaArtColor.g, view.sys.mediaArtColor.b, cardHover.hovered ? 0.08 : 0.05)
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(view.sys.mediaArtColor.r, view.sys.mediaArtColor.g, view.sys.mediaArtColor.b, cardHover.hovered ? 0.02 : 0.01)
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                    }
                }

                // Клик по свободной области карточки открывает подробный плеер (Music Island)
                MouseArea {
                    anchors.fill: parent
                    enabled: !mediaCard.lyricsOpen
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: view.sys.openMusicIsland("main")
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        // Кликабельный блок трека: обложка + название + автор
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42

                            RowLayout {
                                anchors.fill: parent
                                spacing: 11

                                // обложка
                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 10
                                    color: Qt.rgba(1, 1, 1, 0.07)

                                    Image {
                                        id: cardArt
                                        anchors.fill: parent
                                        source: view.sys.effectiveMediaArt || view.sys.mediaArt
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize: Qt.size(256, 256)
                                        mipmap: true
                                        smooth: true
                                        antialiasing: true
                                        visible: false
                                    }
                                    Item {
                                        id: cardArtMask
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true
                                        layer.textureSize: Qt.size(512, 512)
                                        Rectangle {
                                            width: 512
                                            height: 512
                                            radius: Math.round(10 * 512 / Math.max(1, parent.width))
                                            scale: parent.width / 512
                                            transformOrigin: Item.TopLeft
                                            color: "#ffffff"
                                            antialiasing: true
                                        }
                                    }
                                    MultiEffect {
                                        anchors.fill: parent
                                        source: cardArt
                                        maskEnabled: true
                                        maskSource: cardArtMask
                                        visible: cardArt.status === Image.Ready
                                        antialiasing: true
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: cardArt.status !== Image.Ready
                                        text: "󰝚"
                                        color: view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: 18 }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: mediaCard.p ? mediaCard.p.trackTitle : ""
                                        color: view.sys.colFg
                                        elide: Text.ElideRight
                                        font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: mediaCard.p ? mediaCard.p.trackArtist : ""
                                        color: view.sys.colMuted
                                        elide: Text.ElideRight
                                        font { family: view.sys.fontFam; pixelSize: 11 }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.openMusicIsland("main")
                            }
                        }

                        MediaBtn {
                            icon: "󰒮"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoPrevious : false
                            onAct: if (mediaCard.p) mediaCard.p.previous()
                        }
                        MediaBtn {
                            icon: mediaCard.p && mediaCard.p.isPlaying ? "󰏤" : "󰐊"
                            primary: true
                            enabledAction: mediaCard.p ? mediaCard.p.canTogglePlaying : false
                            onAct: if (mediaCard.p) mediaCard.p.togglePlaying()
                        }
                        MediaBtn {
                            icon: "󰒭"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoNext : false
                            onAct: if (mediaCard.p) mediaCard.p.next()
                        }
                        MediaBtn {
                            icon: "󰎆"
                            primary: mediaCard.lyricsOpen
                            enabledAction: true
                            onAct: {
                                if (view.sys && view.sys.toggleMediaLyrics) {
                                    view.sys.toggleMediaLyrics();
                                } else {
                                    mediaCard.lyricsOpen = !mediaCard.lyricsOpen;
                                }
                            }
                        }
                    }

                    // ------------------- полоса продолжительности с cava
                    // Эквалайзер и есть ползунок: пройденная часть спектра
                    // светится акцентом, остаток — приглушённый. Так плашка
                    // не растёт на две отдельные полосы, а перемотка видна
                    // прямо по звуку.
                    //
                    // Оба слоя берут один и тот же поток из CavaSource,
                    // поэтому полосы в них совпадают кадр в кадр, и стык
                    // между «сыграно» и «осталось» не видно.
                    Item {
                        id: seek
                        readonly property var p: mediaCard.p
                        readonly property real dur: seek.p ? Math.max(0, seek.p.length) : 0
                        readonly property bool usable:
                            seek.p !== null && seek.dur > 0
                            && seek.p.positionSupported && seek.p.canSeek
                        readonly property real frac: seek.dur > 0
                                ? Math.max(0, Math.min(1, seek.pos / seek.dur)) : 0

                        // позиция, которую показываем: секунды
                        property real pos: 0
                        property bool dragging: false
                        // до первого опроса анимация выключена: иначе на
                        // раскрытии полоса ехала от нуля к текущему месту
                        property bool primed: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: seek.p !== null
                        // панель закрыли — при следующем раскрытии позиция
                        // должна встать на место сразу, а не доезжать
                        Component.onDestruction: seek.primed = false

                        // MPRIS отдаёт позицию только по запросу: между
                        // опросами полосу двигает линейная анимация, иначе
                        // она прыгала бы раз в полсекунды. На перетаскивании
                        // анимация выключена — ручка идёт точно за курсором.
                        Behavior on pos {
                            enabled: seek.primed && !seek.dragging
                            NumberAnimation { duration: 520; easing.type: Easing.Linear }
                        }
                        Timer {
                            interval: 500
                            repeat: true
                            running: seek.visible && seek.p !== null
                            triggeredOnStart: true
                            onTriggered: {
                                if (seek.p === null) return;
                                seek.p.positionChanged();
                                if (seek.dragging) return;
                                seek.pos = seek.p.position;
                                seek.primed = true;
                            }
                        }
                        Connections {
                            target: mediaCard.p
                            ignoreUnknownSignals: true
                            // сменился трек — начинаем с нуля, без переезда
                            function onTrackTitleChanged() {
                                seek.dragging = false;
                                seek.primed = false;   // новый трек — снова без переезда
                                seek.pos = 0;
                            }
                        }

                        function fracOf(x) {
                            return Math.max(0, Math.min(1, x / Math.max(1, seek.width)));
                        }

                        // остаток трека — приглушённые полосы
                        WaveBars {
                            id: barsRest
                            anchors.fill: parent
                            barCount: 46
                            gap: 3
                            barColor: Qt.rgba(1, 1, 1, 0.22)
                            active: seek.p ? seek.p.isPlaying : false
                        }

                        // сыграно — те же полосы акцентом, обрезанные по позиции
                        Item {
                            width: seek.width * seek.frac
                            height: seek.height
                            clip: true
                            WaveBars {
                                width: seek.width
                                height: seek.height
                                barCount: 46
                                gap: 3
                                barColor: view.sys.colOn
                                // Оба слоя живые: с active: false верхние полосы
                                // стояли на месте, и в ритм двигались только
                                // серые из-под них. Поток у CavaSource общий и
                                // считается по ссылкам, второго процесса нет.
                                active: seek.p ? seek.p.isPlaying : false
                            }
                        }

                        // тонкая линия по низу: без неё пустые паузы в звуке
                        // выглядели бы обрывом полосы.
                        // На теме Nothing её нет: там дорожка — только сам
                        // спектр, и подчёркивание снизу спорит с ним.
                        Rectangle {
                            visible: !view.sys.themeNothing
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: (view.sys && view.sys.themeMaterial) ? 5 : 2
                            radius: height / 2
                            color: (view.sys && view.sys.themeMaterial) ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.12)
                            Rectangle {
                                width: parent.width * seek.frac
                                height: parent.height
                                radius: parent.radius
                                color: view.sys.colOn
                            }
                        }

                        // Ручка — вертикальная риска на позиции.
                        //
                        // На теме Nothing она не висит постоянно, а появляется
                        // под курсором. Совсем убрать её нельзя: перемотка
                        // осталась, а без всякого отклика непонятно, куда
                        // попадёшь, — и промах слышен сразу. Пока мышь мимо,
                        // никакой черты поверх спектра нет.
                        Rectangle {
                            x: Math.max(0, Math.min(seek.width - width, seek.width * seek.frac - width / 2))
                            width: (view.sys && view.sys.themeMaterial) ? (seekMa.pressed ? 6 : 4) : (seekMa.pressed ? 3 : 2)
                            height: (view.sys && view.sys.themeMaterial) ? 14 : parent.height
                            anchors.bottom: parent.bottom
                            radius: width / 2
                            color: (view.sys && view.sys.themeMaterial) ? view.sys.colOn : "#ffffff"
                            opacity: !seek.usable ? (view.sys.themeNothing ? 0 : 0.3)
                                   : (seekMa.containsMouse || seekMa.pressed) ? 1
                                   : (view.sys.themeNothing ? 0 : ((view.sys && view.sys.themeMaterial) ? 0.95 : 0.75))
                            scale: (view.sys && view.sys.themeMaterial && seekMa.pressed) ? 1.25 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: seekMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            preventStealing: true
                            enabled: seek.usable
                            cursorShape: seek.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => {
                                seek.dragging = true;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onReleased: mouse => {
                                // отправляем плееру уже на отпускании: на каждом
                                // кадре MPRIS-клиент начинает спорить и дёргать
                                // позицию назад
                                if (seek.usable) seek.p.position = seek.pos;
                                seek.dragging = false;
                            }
                            onCanceled: seek.dragging = false
                        }
                    }

                    // время: прошло и всего
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -6
                        visible: seek.visible && seek.dur > 0
                        Text {
                            visible: !view.sys.themeNothing
                            text: view.fmtTime(seek.pos)
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                        DotText {
                            visible: view.sys.themeNothing
                            value: view.fmtTime(seek.pos)
                            size: view.sys.dotHSmall
                            color: view.sys.colMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: !view.sys.themeNothing
                            text: view.fmtTime(seek.dur)
                            color: Qt.rgba(1, 1, 1, 0.28)
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                        DotText {
                            visible: view.sys.themeNothing
                            value: view.fmtTime(seek.dur)
                            size: view.sys.dotHSmall
                            color: Qt.rgba(1, 1, 1, 0.28)
                        }
                    }

                    // ------------------- visor de letras estilo SpicyLyrics
                    SpicyLyricsView {
                        id: spicyLyrics
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: mediaCard.lyricsOpen || mediaCard.height > 130
                        opacity: mediaCard.lyricsOpen ? 1.0 : 0.0
                        active: mediaCard.lyricsOpen
                        sys: view.sys
                        player: mediaCard.p
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // ------------------------------- запись экрана
            RecordCard {
                id: ccRecordBlock
                objectName: "cc-record"
                Layout.row: view.ccRow("record")
                Layout.column: view.ccCol("record")
                Layout.columnSpan: view.ccSpan("record")
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                visible: view.preview || view.sys.cfg.featRecord
            }

            // ------------------------------- батарея / нагрузка
            Item {
                id: ccBatteryBlock
                objectName: "cc-battery"
                Layout.row: view.ccRow("battery")
                Layout.column: view.ccCol("battery")
                Layout.columnSpan: view.ccSpan("battery")
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                visible: true

                MiniTile {
                    anchors.fill: parent
                    visible: view.preview || view.sys.batteryPresent || view.sys.showBattery || view.sys.showPowerProfiles
                    hasSubpage: true
                    icon: view.sys.batteryPresent ? view.sys.batteryLevelIcon
                                                  : String.fromCodePoint(0xF0241)
                    label: view.sys.batteryPresent ? (view.sys.batteryPct + "%") : view.sys.profileLabel
                    sub: (view.sys.batteryCharging ? view.sys.tr("Заряжается") : (view.sys.acOnline ? (view.sys.isEs ? "Conectado" : view.sys.tr("От сети")) : ""))
                         + ((view.sys.batteryCharging || view.sys.acOnline) ? " · " : "")
                         + view.sys.profileLabel
                    on: true
                    wave: true
                    waveLevel: view.sys.batteryPct > 0 ? (view.sys.batteryPct / 100) : 0.5
                    accent: view.battModeColor
                    customBg: view.battModeBg
                    customBorder: view.battModeBorder
                    onIconClicked: view.sys.openSub("battery")
                    onBodyClicked: view.sys.openSub("battery")
                }

                LoadCard {
                    anchors.fill: parent
                    visible: !view.preview && !view.sys.batteryPresent
                }
            }

            // -------------------------------- не спать + кнопки-иконки
            // Замок, уведомления и настройки уехали сюда из правого верхнего
            // угла: одна нижняя полоса вместо значков, спорящих с часами.
            
            // Блокировка экрана
            IconBtn {
                id: btnLock
                objectName: "cc-lock"
                Layout.row: view.ccRow("lock")
                Layout.column: view.ccCol("lock")
                Layout.columnSpan: view.ccSpan("lock")
                Layout.fillWidth: false
                Layout.preferredWidth: view.ccBtnWidth
                Layout.preferredHeight: 48
                glyph: String.fromCodePoint(0xF033E)
                tip: view.sys.tr("Блокировка")
                onAct: {
                    view.sys.collapse();
                    view.sys.runDetached(view.sys.scriptDir + "/lock.sh");
                }
            }

            // Снимок экрана
            IconBtn {
                id: btnShot
                objectName: "cc-shot"
                Layout.row: view.ccRow("shot")
                Layout.column: view.ccCol("shot")
                Layout.columnSpan: view.ccSpan("shot")
                Layout.fillWidth: false
                Layout.preferredWidth: view.ccBtnWidth
                Layout.preferredHeight: 48
                glyph: String.fromCodePoint(0xF0E51)
                tip: view.sys.tr("Скриншот")
                onAct: {
                    view.sys.collapse();
                    view.sys.runDetached(view.sys.scriptDir + "/shot.sh");
                }
            }

            // колокольчик: активные уведомления и история
            IconBtn {
                id: btnNotif
                objectName: "cc-notif"
                Layout.row: view.ccRow("notif")
                Layout.column: view.ccCol("notif")
                Layout.columnSpan: view.ccSpan("notif")
                visible: view.sys.cfg.featNotifications
                Layout.fillWidth: false
                Layout.preferredWidth: view.ccBtnWidth
                Layout.preferredHeight: 48
                glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                tip: view.sys.dnd ? view.sys.tr("Не беспокоить") : view.sys.tr("Уведомления")
                badge: view.sys.notifications.count
                onAct: view.sys.togglePage("notif")
            }

            // Настройки
            IconBtn {
                id: btnSettings
                objectName: "cc-settings"
                Layout.row: view.ccRow("settings")
                Layout.column: view.ccCol("settings")
                Layout.columnSpan: view.ccSpan("settings")
                Layout.fillWidth: false
                Layout.preferredWidth: view.ccBtnWidth
                Layout.preferredHeight: 48
                glyph: String.fromCodePoint(0xF0493)
                tip: view.sys.tr("Настройки")
                onAct: view.sys.togglePage("settings")
            }

            // кнопка питания: меню выключения, перезагрузки, блокировки и сна
            IconBtn {
                id: btnPower
                objectName: "cc-power"
                Layout.row: view.ccRow("power")
                Layout.column: view.ccCol("power")
                Layout.columnSpan: view.ccSpan("power")
                Layout.fillWidth: false
                Layout.preferredWidth: view.ccBtnWidth
                Layout.preferredHeight: 48
                glyph: String.fromCodePoint(0xF0425)
                tip: view.sys.tr("Питание")
                activeColor: view.sys.colCrit
                onAct: view.sys.togglePage("power")
            }

            // ------------------------------------------------ системный трей
            RowLayout {
                objectName: "cc-tray"
                Layout.row: view.ccRow("tray")
                Layout.column: view.ccCol("tray")
                Layout.columnSpan: view.ccSpan("tray")
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 10
                visible: true

                Text {
                    text: view.sys.tr("Трей")
                    color: view.sys.colMuted
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                Repeater {
                    model: view.sys.trayItems

                    Rectangle {
                        id: trayBtn
                        required property var modelData

                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        z: trayMa.containsMouse ? 10 : 0
                        radius: 12
                        color: trayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: trayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: trayMa.pressed ? 0.95 : (trayMa.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        Image {
                            id: trayIconImg
                            anchors.fill: parent
                            anchors.margins: 8
                            source: {
                                var raw = String(trayBtn.modelData.icon || "");
                                var idStr = String(trayBtn.modelData.id || "").toLowerCase();
                                var nameStr = String(trayBtn.modelData.iconName || "").toLowerCase();
                                if (idStr.indexOf("spotify") !== -1 || raw.indexOf("spotify") !== -1 || nameStr.indexOf("spotify") !== -1) {
                                    return "file:///home/nova/.local/share/icons/hicolor/32x32/apps/spotify-linux-32.png";
                                }
                                return raw;
                            }
                            fillMode: Image.PreserveAspectFit
                            smooth: true

                            onStatusChanged: {
                                if (status === Image.Error) {
                                    var idStr = String(trayBtn.modelData.id || "").toLowerCase();
                                    if (idStr.indexOf("spotify") !== -1) {
                                        source = "file:///home/nova/.local/share/icons/hicolor/scalable/apps/com.spotify.Client.svg";
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                // ПКМ — контекстное меню приложения (Telegram и т.п.)
                                if (mouse.button === Qt.RightButton) {
                                    if (!trayBtn.modelData.hasMenu) return;
                                    view.sys.trayMenuItem = trayBtn.modelData;
                                    view.sys.page = "traymenu";
                                    view.sys.holdOpen = true;
                                    return;
                                }
                                if (mouse.button === Qt.MiddleButton)
                                    trayBtn.modelData.secondaryActivate();
                                else
                                    trayBtn.modelData.activate();
                                view.sys.collapse();
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Индикатор нагрузки системы: CPU %, температура CPU, температура GPU
                Rectangle {
                    id: sysStatsPill
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    radius: 12
                    color: statsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: statsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    implicitWidth: statsRow.implicitWidth + 24
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    scale: statsMa.pressed ? 0.97 : (statsMa.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: statsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (view.sys && typeof view.sys.refreshLoad === "function")
                                view.sys.refreshLoad();
                        }
                    }

                    RowLayout {
                        id: statsRow
                        anchors.centerIn: parent
                        spacing: 8

                        // CPU Usage
                        RowLayout {
                            spacing: 3
                            Text {
                                text: "CPU"
                                color: view.sys.colMuted
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: 9
                                    bold: true
                                }
                            }
                            Text {
                                text: (view.sys.loadCpu >= 0 ? view.sys.loadCpu : "--") + "%"
                                color: view.sys.colFg
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: 11
                                    bold: true
                                }
                            }
                        }

                        // CPU Temp
                        RowLayout {
                            spacing: 2
                            Text {
                                text: String.fromCodePoint(0xF0E01)
                                color: view.sys.loadTempCpu >= 80 ? view.sys.colCrit : (view.sys.loadTempCpu >= 70 ? view.sys.colWarn : view.sys.colMuted)
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: 10
                                }
                            }
                            Text {
                                text: (view.sys.loadTempCpu >= 0 ? view.sys.loadTempCpu : "--") + "°"
                                color: view.sys.loadTempCpu >= 80 ? view.sys.colCrit : (view.sys.loadTempCpu >= 70 ? view.sys.colWarn : view.sys.colFg)
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: 11
                                    bold: true
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 12
                            color: Qt.rgba(1, 1, 1, 0.12)
                        }

                        // GPU Temp
                        RowLayout {
                            spacing: 3
                            Text {
                                text: "GPU"
                                color: view.sys.colMuted
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: 9
                                    bold: true
                                }
                            }
                            Text {
                                text: (view.sys.loadTempGpu >= 0 ? view.sys.loadTempGpu : "--") + "°"
                                color: view.sys.loadTempGpu >= 80 ? view.sys.colCrit : (view.sys.loadTempGpu >= 70 ? view.sys.colWarn : view.sys.colFg)
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: 11
                                    bold: true
                                }
                            }
                        }
                    }
                }
            }

        }

        // ---------------------------------------------------------- батарея
        // Режимы питания плюс всё, что UPower знает про заряд: сколько
        // осталось работы (или до полной зарядки), ёмкость и износ.
        ColumnLayout {
            id: battPage
            width: parent.width
            spacing: 8
            readonly property bool isCurrent: view.sys.page === "battery"
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: battPage.isCurrent ? 0 : 32
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            Header {
                title: view.sys.tr("Батарея")
                onBack: view.sys.page = "main"
            }

            // Tarjeta de estado de batería con color adaptativo al perfil activo
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                radius: 18
                color: view.battModeBg
                border.color: view.battModeBorder
                border.width: 1.5
                clip: true
                Behavior on color { ColorAnimation { duration: 250 } }
                Behavior on border.color { ColorAnimation { duration: 250 } }

                readonly property color tint: view.battModeColor

                // Onda líquida animada con el color del perfil activo
                ChargeWave {
                    anchors.fill: parent
                    radius: parent.radius
                    tint: view.battModeWave
                    level: view.sys.batteryPct > 0 ? (view.sys.batteryPct / 100) : 0.5
                    running: (view.sys.page === "battery" || view.sys.batteryCharging) && (view.sys.expanded || view.preview)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    // Squircle con el color del modo activo
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 14
                        color: view.battModeColor
                        border.color: "transparent"
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Text {
                            anchors.centerIn: parent
                            text: view.sys.batteryPresent ? view.sys.batteryLevelIcon : String.fromCodePoint(0xF0241)
                            color: view.battModeInk
                            Behavior on color { ColorAnimation { duration: 200 } }
                            font { family: view.sys.fontFam; pixelSize: 19 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: view.sys.batteryPct + "%"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 18; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (view.sys.batteryCharging ? view.sys.tr("Заряжается") : (view.sys.acOnline ? (view.sys.isEs ? "Conectado" : view.sys.tr("От сети")) : view.sys.tr("От батареи")))
                                  + ((view.sys.batteryCharging || view.sys.acOnline) ? " · " : "")
                                  + view.sys.profileLabel
                            color: Qt.rgba(1, 1, 1, 0.85)
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    // Indicador de conexión / carga
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        radius: 16
                        visible: view.sys.batteryCharging || view.sys.acOnline
                        color: Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.22)
                        border.color: Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.50)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(
                                      view.sys.batteryCharging ? 0xF0241 : 0xF06A5)
                            color: view.sys.colOk
                            font { family: view.sys.fontFam; pixelSize: 15 }
                            // пока заряжается — молния мягко пульсирует
                            SequentialAnimation on opacity {
                                running: view.sys.batteryCharging && view.sys.cfg.animStatusPulse
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 750; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                            }
                            onVisibleChanged: if (!visible) opacity = 1
                        }
                    }
                }
            }

            // режимы питания — те самые три сегмента, теперь живут здесь
            RowLayout {
                visible: view.sys.showPowerProfiles
                Layout.fillWidth: true
                spacing: 8

                PowerSeg {
                    icon: "󰾆"
                    label: view.sys.tr("Экономия")
                    profile: "power-saver"
                    accent: view.sys.colPowerSaver
                }
                PowerSeg {
                    icon: "󰾅"
                    label: view.sys.tr("Баланс")
                    profile: "balanced"
                    accent: view.sys.colPowerBalanced
                }
                PowerSeg {
                    icon: "󰓅"
                    label: view.sys.tr("Максимум")
                    profile: "performance"
                    accent: view.sys.colPowerPerf
                }
            }

            // мелкие цифры — ёмкость, износ и текущий расход, в одну полосу
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: view.sys.batteryPresent

                BattStat {
                    label: view.sys.tr("Ёмкость")
                    value: view.sys.batteryCapacity > 0
                           ? view.sys.batteryCapacity.toFixed(1) + " Wh" : "—"
                }
                BattStat {
                    label: view.sys.tr("Износ")
                    value: view.sys.batteryHealth > 0
                           ? view.sys.batteryHealth + "%" : "—"
                }
                BattStat {
                    label: view.sys.batteryCharging ? "󰐥" : "󰚥"
                    value: Math.abs(view.sys.batteryRate) > 0.05
                           ? Math.abs(view.sys.batteryRate).toFixed(1) + " W" : "—"
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
            }
        }

        // ------------------------------------------------------------ Wi-Fi
        ColumnLayout {
            id: wifiPage
            width: parent.width
            spacing: 7

            // Что за сеть выбрана правой кнопкой и что с ней можно сделать.
            property string menuSsid: ""
            property bool menuConnected: false
            property bool menuKnown: false

            readonly property bool isCurrent: view.sys.page === "wifi"
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: wifiPage.isCurrent ? 0 : 32
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            Header {
                title: view.sys.tr("Сети Wi-Fi")
                busy: view.sys.wifiBusy
                onBack: { view.sys.page = "main"; passwordFor = ""; }
                onRefresh: view.sys.scanWifi()
            }

            // ввод пароля для выбранной сети
            property string passwordFor: ""

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                visible: wifiPage.passwordFor.length > 0
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.055)
                border.color: pwField.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 8
                    spacing: 9

                    Text {
                        text: "󰌾"
                        color: pwField.activeFocus ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 15 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Пароль от «") + wifiPage.passwordFor + "»"
                        echoMode: TextInput.Password
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                        background: null
                        onAccepted: connectBtn.go()
                    }
                    Rectangle {
                        id: connectBtn
                        function go() {
                            if (!pwField.text.length) return;
                            view.sys.connectWifi(wifiPage.passwordFor, pwField.text);
                            wifiPage.passwordFor = "";
                            pwField.text = "";
                            view.sys.holdOpen = false;
                        }
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34
                        radius: 10
                        color: pwField.text.length ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: connectMa.pressed ? 0.94 : (connectMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            color: pwField.text.length ? "#ffffff" : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 14 }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea {
                            id: connectMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.go()
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiError.length > 0
                text: view.sys.wifiError
                color: view.sys.colCrit
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            // список сетей
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.wifiNetworks
                    Row1 {
                        required property var model
                        accentColor: view.sys.colWifi
                        icon: model.quality > 66 ? "󰤨" : model.quality > 33 ? "󰤥" : "󰤟"
                        title: model.ssid
                        sub: (model.security === "open" ? view.sys.tr("Открытая") : view.sys.tr("Защищённая"))
                             + " · " + model.quality + "%"
                             + (model.known ? view.sys.tr(" · сохранена") : "")
                        highlight: model.connected
                        hasMenu: model.connected || model.known
                        onActivated: {
                            if (model.connected) return;
                            if (model.security === "open" || model.known) {
                                view.sys.connectWifi(model.ssid, "");
                            } else {
                                wifiPage.passwordFor = model.ssid;
                                view.sys.holdOpen = true;
                                pwFocus.restart();
                            }
                        }
                        onMenuRequested: (mx, my) => {
                            // меню имеет смысл только там, где есть что делать:
                            // отключиться можно от текущей, забыть — сохранённую
                            if (!model.connected && !model.known) return;
                            wifiPage.menuSsid = model.ssid;
                            wifiPage.menuConnected = model.connected;
                            wifiPage.menuKnown = model.known;
                            view.sys.page = "netmenu";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiNetworks.count === 0
                text: view.sys.wifiBusy ? view.sys.tr("Поиск сетей…") : view.sys.tr("Сети не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            Timer { id: pwFocus; interval: 80; onTriggered: pwField.forceActiveFocus() }

        }

        // ------------------------------------------------- меню сети
        // Отдельной страницей, как меню трея: панель узкая, и всплывающее окно
        // поверх списка пришлось бы двигать, чтобы оно не уезжало за край.
        // Страница открывается по правой кнопке на сети и умеет ровно то, чего
        // нет в самом списке: отключиться и забыть.
        ColumnLayout {
            id: netMenuPage
            width: parent.width
            spacing: 3
            readonly property bool isCurrent: view.sys.page === "netmenu"
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: netMenuPage.isCurrent ? 0 : 32
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            Header {
                title: wifiPage.menuSsid.length ? wifiPage.menuSsid : view.sys.tr("Сеть")
                busy: view.sys.wifiBusy
                onBack: view.sys.page = "wifi"
                onRefresh: {}
            }

            Row1 {
                visible: wifiPage.menuConnected
                icon: "󰖪"
                title: view.sys.tr("Отключиться")
                sub: view.sys.tr("Связь разорвётся, сеть останется сохранённой")
                onActivated: {
                    view.sys.disconnectWifi();
                    view.sys.page = "wifi";
                }
            }

            Row1 {
                visible: wifiPage.menuKnown
                icon: "󰅖"
                title: view.sys.tr("Забыть сеть")
                sub: view.sys.tr("Больше не подключаться самому")
                onActivated: {
                    view.sys.forgetWifi(wifiPage.menuSsid);
                    view.sys.page = "wifi";
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !wifiPage.menuConnected && !wifiPage.menuKnown
                text: view.sys.tr("Для этой сети ничего не сохранено.")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // ------------------------------------------- контекстное меню трея
        ColumnLayout {
            id: trayPage
            width: parent.width
            spacing: 3
            readonly property bool isCurrent: view.sys.page === "traymenu"
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: trayPage.isCurrent ? 0 : 32
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            // цепочка вложенных подменю: последний элемент — текущее меню
            property var chain: []
            readonly property var rootHandle:
                view.sys.trayMenuItem ? view.sys.trayMenuItem.menu : null
            readonly property var handle:
                chain.length > 0 ? chain[chain.length - 1] : rootHandle

            // новая иконка — начинаем с её корневого меню.
            // Присваиваем только когда есть что сбрасывать: иначе QML видит
            // цикл chain -> handle -> chain и ругается на каждом открытии.
            onRootHandleChanged: if (chain.length > 0) chain = []

            QsMenuOpener {
                id: menuOpener
                menu: trayPage.handle
            }

            Header {
                title: view.sys.trayMenuItem
                       ? String(view.sys.trayMenuItem.tooltipTitle
                                || view.sys.trayMenuItem.title || view.sys.tr("Меню"))
                       : view.sys.tr("Меню")
                busy: false
                onBack: {
                    if (trayPage.chain.length > 0) {
                        var c = trayPage.chain.slice();
                        c.pop();
                        trayPage.chain = c;
                    } else {
                        view.sys.page = "main";
                        view.sys.trayMenuItem = null;
                    }
                }
                onRefresh: {}
            }

            Repeater {
                model: menuOpener.children

                // разделитель и обычный пункт — в одном делегате: Repeater
                // не умеет выбирать компонент по данным модели
                Item {
                    id: entry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        height: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.sys.colLine
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: entryMa.containsMouse && entry.modelData.enabled
                               ? view.sys.colHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        scale: entryMa.pressed ? 0.985 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        transform: Translate {
                            x: (entryMa.containsMouse && view.sys.cfg.animMenuSlide) ? 2 : 0
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 9

                            // галочка/радио для переключаемых пунктов
                            Text {
                                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                text: entry.modelData.checkState === Qt.Checked
                                      ? "󰄬" : "󰝦"
                                color: entry.modelData.checkState === Qt.Checked
                                       ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            Image {
                                visible: String(entry.modelData.icon || "").length > 0
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: String(entry.modelData.icon || "")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(entry.modelData.text || "")
                                color: entry.modelData.enabled
                                       ? view.sys.colFg : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            // стрелка у подменю
                            Text {
                                visible: entry.modelData.hasChildren
                                text: "󰅂"
                                color: entryMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                                transform: Translate {
                                    x: (entryMa.containsMouse && view.sys.cfg.animChevronSlide) ? 2 : 0
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        MouseArea {
                            id: entryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    var c = trayPage.chain.slice();
                                    c.push(entry.modelData);
                                    trayPage.chain = c;
                                    return;
                                }
                                entry.modelData.triggered();
                                view.sys.collapse();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !menuOpener.children || menuOpener.children.values.length === 0
                text: view.sys.tr("Меню пустое")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // -------------------------------------------------------- Bluetooth
        ColumnLayout {
            id: btPage
            width: parent.width
            spacing: 7
            readonly property bool isCurrent: view.sys.page === "bt"
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: btPage.isCurrent ? 0 : 32
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            property var menuDev: null
            property string menuName: ""
            property bool menuConnected: false
            property bool menuPaired: false
            property bool menuBonded: false

            Header {
                title: view.sys.tr("Устройства Bluetooth")
                busy: view.sys.btAdapter ? view.sys.btAdapter.discovering : false
                onBack: view.sys.page = "main"
                onRefresh: view.sys.scanBt()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.btDevices
                    Row1 {
                        id: row1
                        required property var modelData
                        accentColor: view.sys.colBt
                        icon: (modelData.icon === "audio-headset" || modelData.icon === "audio-headphones") ? "󰂯"
                            : modelData.icon === "input-mouse" ? "󰦋"
                            : modelData.icon === "input-keyboard" ? "󰌌"
                            : (modelData.icon === "audio-speakers" || modelData.icon === "audio-speaker") ? "󰓃"
                            : modelData.icon === "input-gaming" ? "󰊴"
                            : (modelData.icon === "phone" || modelData.icon === "smartphone") ? "󰄜"
                            : modelData.icon === "watch" ? "󰖄" : "󰂯"
                        title: modelData.name || modelData.address
                        // Статус проходит через «Сопряжение…» и «Подключение…»,
                        // чтобы было видно, что происходит, а не «моргало».
                        sub: modelData.pairing ? view.sys.tr("Сопряжение…")
                           : modelData.state === BluetoothDeviceState.Connecting ? view.sys.tr("Подключение…")
                           : modelData.connected ? view.sys.tr("Подключено")
                           : (modelData.paired || modelData.bonded ? view.sys.tr("Сопряжено") : view.sys.tr("Доступно"))
                             + (modelData.batteryAvailable
                                ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                        highlight: modelData.connected || modelData.pairing
                                   || modelData.state === BluetoothDeviceState.Connecting
                        hasMenu: modelData.connected || modelData.paired || modelData.bonded
                        onActivated: {
                            if (modelData.connected) { modelData.disconnect(); return; }
                            // Недоверенное устройство BlueZ подключает и тут же
                            // роняет; несопряжённое вообще не держится. Делаем
                            // доверенным, сопрягаем, а после сопряжения — сами
                            // подключаемся (pair не всегда доводит до звука).
                            modelData.trusted = true;
                            if (modelData.paired || modelData.bonded) modelData.connect();
                            else modelData.pair();
                        }
                        onMenuRequested: (mx, my) => {
                            if (!modelData.connected && !modelData.paired && !modelData.bonded) return;
                            btPage.menuDev = modelData;
                            btPage.menuName = modelData.name || modelData.address;
                            btPage.menuConnected = modelData.connected;
                            btPage.menuPaired = modelData.paired;
                            btPage.menuBonded = modelData.bonded;
                            view.sys.page = "btmenu";
                        }
                        // как только сопряжение завершилось — подключаемся
                        property var dev: modelData
                        Connections {
                            target: row1.dev
                            function onPairedChanged() {
                                if (row1.dev.paired && !row1.dev.connected) row1.dev.connect();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !view.sys.btDevices || view.sys.btDevices.values.length === 0
                text: (view.sys.btAdapter && view.sys.btAdapter.discovering)
                      ? view.sys.tr("Поиск устройств…") : view.sys.tr("Устройства не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // ------------------------------------------------- меню bluetooth устройства
        ColumnLayout {
            id: btMenuPage
            width: parent.width
            spacing: 3
            readonly property bool isCurrent: view.sys.page === "btmenu"
            opacity: isCurrent ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: btMenuPage.isCurrent ? 0 : 32
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            Header {
                title: btPage.menuName.length ? btPage.menuName : view.sys.tr("Устройство")
                onBack: view.sys.page = "bt"
                onRefresh: {}
            }

            Row1 {
                visible: btPage.menuDev ? btPage.menuDev.connected : btPage.menuConnected
                icon: "󰂲"
                title: view.sys.tr("Отключиться")
                sub: view.sys.tr("Разорвать текущее соединение")
                onActivated: {
                    if (btPage.menuDev) btPage.menuDev.disconnect();
                    view.sys.page = "bt";
                }
            }

            Row1 {
                visible: btPage.menuDev ? (!btPage.menuDev.connected && (btPage.menuDev.paired || btPage.menuDev.bonded))
                                        : (!btPage.menuConnected && (btPage.menuPaired || btPage.menuBonded))
                icon: "󰂱"
                title: view.sys.tr("Подключиться")
                sub: view.sys.tr("Установить соединение")
                onActivated: {
                    if (btPage.menuDev) {
                        btPage.menuDev.trusted = true;
                        btPage.menuDev.connect();
                    }
                    view.sys.page = "bt";
                }
            }

            Row1 {
                visible: btPage.menuDev ? (btPage.menuDev.paired || btPage.menuDev.bonded || btPage.menuDev.connected)
                                        : (btPage.menuPaired || btPage.menuBonded || btPage.menuConnected)
                icon: "󰅖"
                title: view.sys.tr("Забыть устройство")
                sub: view.sys.tr("Удалить сопряжение и настройки")
                onActivated: {
                    if (btPage.menuDev) {
                        if (btPage.menuDev.connected) btPage.menuDev.disconnect();
                        btPage.menuDev.forget();
                    }
                    view.sys.page = "bt";
                }
            }
        }
    }

}
