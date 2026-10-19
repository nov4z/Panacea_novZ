import QtQuick
import QtQuick.Layouts

// Control Center. В макете стоит сама панель, а не её рисунок: тот же
// ControlsView, только неживой. Копия рано или поздно разошлась бы с
// оригиналом — а так человек двигает ровно то, что потом увидит.
//
// Порядок и размеры хранятся в настройках:
// ccLayout: "clock,wifi,bt,volume,brightness,media,record,battery,quick,tray"
// ccSizes: {"wifi":"1/3","bt":"1/3","volume":"1/3","brightness":"1",...}
ColumnLayout {
    id: page

    property var sys

    readonly property var blocks: [
        { id: "clock",      name: page.sys.tr("Часы и дата"), icon: "󰸗", canResize: false },
        { id: "wifi",       name: "Wi-Fi",                     icon: "󰤨", canResize: true },
        { id: "bt",         name: "Bluetooth",                 icon: "󰂯", canResize: true },
        { id: "volume",     name: page.sys.tr("Звук"),         icon: "󰕾", canResize: true },
        { id: "brightness", name: page.sys.tr("Яркость"),      icon: "󰃠", canResize: true },
        { id: "media",      name: page.sys.tr("Что играет"),   icon: "󰐊", canResize: true },
        { id: "record",     name: page.sys.tr("Запись"),       icon: "󰑋", canResize: true },
        { id: "battery",    name: page.sys.tr("Батарея"),      icon: "󰁹", canResize: true },
        { id: "lock",       name: page.sys.tr("Блокировка"),   icon: String.fromCodePoint(0xF033E), canResize: false },
        { id: "shot",       name: page.sys.tr("Скриншот"),     icon: String.fromCodePoint(0xF0E51), canResize: false },
        { id: "notif",      name: page.sys.tr("Уведомления"),  icon: String.fromCodePoint(0xF009A), canResize: false },
        { id: "settings",   name: page.sys.tr("Настройки"),    icon: String.fromCodePoint(0xF0493), canResize: false },
        { id: "power",      name: page.sys.tr("Питание"),      icon: String.fromCodePoint(0xF0425), canResize: false },
        { id: "tray",       name: "Bandeja del sistema",       icon: "󱊖", canResize: false }
    ]
    readonly property var defOrder: ["clock", "wifi", "bt", "volume", "brightness", "media", "record", "battery", "lock", "shot", "notif", "settings", "power", "tray"]
    readonly property var defSizes: ({"wifi":"1/2","bt":"1/2","volume":"1","brightness":"1","media":"1","record":"1/2","battery":"1/2","clock":"1","lock":"1/5","shot":"1/5","notif":"1/5","settings":"1/5","power":"1/5","tray":"1"})

    // черновик: применяется кнопкой, чтобы панель не прыгала на каждый сдвиг
    property var order: []
    property var sizes: ({})
    property bool dirty: false

    function load() {
        var cfgLayout = (page.sys && page.sys.cfg) ? (page.sys.cfg.ccLayout || "") : "";
        var saved = String(cfgLayout).split(",").filter(x => x.length);
        var parsed = [];
        for (var i = 0; i < saved.length; i++) {
            var k = saved[i];
            if (k === "toggles") { parsed.push("wifi"); parsed.push("bt"); parsed.push("volume"); }
            else if (k === "sliders") { parsed.push("brightness"); }
            else if (k === "power") { parsed.push("record"); parsed.push("battery"); }
            else parsed.push(k);
        }
        var out = parsed.filter(id => page.defOrder.indexOf(id) >= 0);
        page.defOrder.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        page.order = out;

        var s = Object.assign({}, page.defSizes);
        var rawSizes = (page.sys && page.sys.cfg) ? page.sys.cfg.ccSizes : "";
        if (typeof rawSizes === "string" && rawSizes.length > 2) {
            try {
                var p = JSON.parse(rawSizes);
                for (var key in p) {
                    if (p.hasOwnProperty(key)) s[key] = p[key];
                }
            } catch (e) {}
        } else if (rawSizes && typeof rawSizes === "object") {
            for (var key2 in rawSizes) {
                if (rawSizes.hasOwnProperty(key2)) s[key2] = rawSizes[key2];
            }
        }
        page.sizes = s;
        page.dirty = false;
    }

    function metaOf(id) {
        for (var i = 0; i < page.blocks.length; i++) {
            if (page.blocks[i].id === id) return page.blocks[i];
        }
        return { id: id, name: id, icon: "󰄲", canResize: false };
    }

    function nameOf(id) { return metaOf(id).name; }
    function iconOf(id) { return metaOf(id).icon; }

    function move(from, to) {
        if (to < 0 || to >= page.order.length || from === to) return;
        var a = page.order.slice();
        a.splice(to, 0, a.splice(from, 1)[0]);
        page.order = a;
        page.dirty = true;
    }

    function setWidgetSize(id, sz) {
        if (id === "lock" || id === "shot" || id === "notif" || id === "settings" || id === "power") return;
        var s = Object.assign({}, page.sizes);
        s[id] = sz;
        page.sizes = s;
        page.dirty = true;
    }

    function getWidgetSize(id) {
        if (id === "lock" || id === "shot" || id === "notif" || id === "settings" || id === "power") return "1/5";
        return (page.sizes && page.sizes[id]) ? page.sizes[id] : (page.defSizes[id] || "1");
    }

    Component.onCompleted: load()

    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- Vista Previa
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Раскладка панели") }

        Text {
            Layout.fillWidth: true
            text: "Arrastra y suelta cualquier tarjeta para reubicarla en la cuadrícula, o usa los controles inferiores para cambiar su proporción y orden."
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "Plantillas:"
                color: page.sys.colOn
                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 3; bold: true }
            }

            Rectangle {
                width: p1Text.implicitWidth + 24
                height: 28
                radius: 14
                color: p1Ma.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.15) : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.08)
                border.width: 1
                border.color: p1Ma.containsMouse ? page.sys.colOn : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.3)
                
                Text {
                    id: p1Text
                    anchors.centerIn: parent
                    text: "Clásica (Base)"
                    color: page.sys.colOn
                    font { family: page.sys.fontFam; pixelSize: 12 }
                }
                MouseArea {
                    id: p1Ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.order = Object.assign([], page.defOrder);
                        page.sizes = Object.assign({}, page.defSizes);
                    }
                }
            }

            Rectangle {
                width: p2Text.implicitWidth + 24
                height: 28
                radius: 14
                color: p2Ma.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.15) : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.08)
                border.width: 1
                border.color: p2Ma.containsMouse ? page.sys.colOn : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.3)
                
                Text {
                    id: p2Text
                    anchors.centerIn: parent
                    text: "Compacta"
                    color: page.sys.colOn
                    font { family: page.sys.fontFam; pixelSize: 12 }
                }
                MouseArea {
                    id: p2Ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.order = ["clock", "wifi", "bt", "volume", "brightness", "media", "record", "battery", "lock", "shot", "notif", "settings", "power", "tray"];
                        page.sizes = Object.assign({}, page.defSizes);
                        page.sizes["wifi"] = "1/3";
                        page.sizes["bt"] = "1/3";
                        page.sizes["volume"] = "1/3";
                        page.sizes["lock"] = "10%";
                        page.sizes["shot"] = "10%";
                        page.sizes["notif"] = "10%";
                        page.sizes["settings"] = "10%";
                        page.sizes["power"] = "10%";
                        page.sizes["record"] = "25%";
                        page.sizes["battery"] = "25%";
                    }
                }
            }
        }

        // Сама панель во всю свою ширину.
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            readonly property real scale: Math.min(1, width / Math.max(1, page.sys.panelW))
            implicitHeight: mock.implicitHeight * stage.scale

            ControlsView {
                id: mock
                sys: page.sys
                preview: true
                ccOrderOverride: page.order
                ccSizesOverride: page.sizes
                width: page.sys.panelW
                height: implicitHeight
                enabled: false
                transformOrigin: Item.TopLeft
                scale: stage.scale
            }

            // Накладки поверх блоков: двигаются независимо в 2D пространстве
            Repeater {
                model: page.order

                Item {
                    id: grip
                    required property int index
                    required property string modelData
                    readonly property var blk: mock.ccBlock(grip.modelData)
                    property bool held: false

                    visible: grip.blk !== null && grip.blk.height > 0
                    width: grip.blk ? grip.blk.width * stage.scale : 0
                    height: grip.blk ? grip.blk.height * stage.scale : 0
                    x: grip.blk ? grip.blk.x * stage.scale : 0
                    y: grip.blk ? grip.blk.y * stage.scale : 0
                    z: grip.held ? 20 : 1

                    Behavior on x {
                        enabled: !grip.held
                        NumberAnimation { duration: page.sys.animFade; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: !grip.held
                        NumberAnimation { duration: page.sys.animFade; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: grip.held
                               ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                               : (gripMa.containsMouse
                                  ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12)
                                  : "transparent")
                        border.width: grip.held ? 2 : (gripMa.containsMouse ? 1 : 0)
                        border.color: grip.held ? page.sys.colOn : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.25)
                        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                        // Etiqueta flotante con el nombre del widget
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 4
                            visible: gripMa.containsMouse || grip.held
                            height: 18
                            width: labelRow.implicitWidth + 10
                            radius: 9
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1

                            RowLayout {
                                id: labelRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: page.iconOf(grip.modelData)
                                    color: page.sys.colOn
                                    font { family: page.sys.fontFam; pixelSize: 10 }
                                }
                                Text {
                                    text: page.nameOf(grip.modelData)
                                    color: "#ffffff"
                                    font { family: page.sys.fontFam; pixelSize: 9; bold: true }
                                }
                            }
                        }

                        // Icono de arrastre
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: gripMa.containsMouse || grip.held
                            text: String.fromCodePoint(0xF01DD)
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
                        }
                    }

                    MouseArea {
                        id: gripMa
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: grip.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: grip
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 0
                        drag.maximumX: Math.max(0, stage.width - grip.width)
                        drag.minimumY: 0
                        drag.maximumY: Math.max(0, stage.height - grip.height)

                        onPressed: grip.held = true
                        onReleased: {
                            grip.held = false;
                            var dropX = grip.x + grip.width / 2;
                            var dropY = grip.y + grip.height / 2;
                            page.move(grip.index, page.dropIndex2D(dropX, dropY, grip.modelData));
                            grip.x = Qt.binding(() => grip.blk ? grip.blk.x * stage.scale : 0);
                            grip.y = Qt.binding(() => grip.blk ? grip.blk.y * stage.scale : 0);
                        }
                    }


                    Rectangle {
                        id: resizeHandle
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 16
                        color: "transparent"
                        visible: page.metaOf(grip.modelData).canResize

                        Rectangle {
                            anchors.centerIn: parent
                            width: 4
                            height: 16
                            radius: 2
                            color: resizeMa.containsMouse || resizeMa.pressed ? page.sys.colOn : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.4)
                            visible: gripMa.containsMouse || grip.held || resizeMa.containsMouse || resizeMa.pressed
                        }

                        MouseArea {
                            id: resizeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeHorCursor
                            property real startX: 0
                            property real startWidth: 0
                            property real stageW: 0
                            
                            onPressed: function(mouse) {
                                var pt = mapToItem(stage, mouse.x, mouse.y)
                                startX = pt.x
                                startWidth = grip.width
                                stageW = stage.width
                            }
                            
                            onPositionChanged: function(mouse) {
                                if (!pressed) return;
                                var pt = mapToItem(stage, mouse.x, mouse.y)
                                var dx = pt.x - startX
                                var newW = startWidth + dx
                                var maxW = stageW
                                if (newW < 40 * stage.scale) newW = 40 * stage.scale;
                                if (newW > maxW) newW = maxW;
                                
                                var pct = Math.round((newW / maxW) * 100);
                                if (pct < 5) pct = 5;
                                if (pct > 100) pct = 100;
                                
                                page.setWidgetSize(grip.modelData, pct + "%");
                            }
                        }
                    }
                }
            }
        }
    }

    // Calcula el índice del bloque más cercano en 2D al soltar
    function dropIndex2D(cx, cy, currentId) {
        var bestIdx = -1;
        var minDist = 1e9;
        for (var i = 0; i < page.order.length; i++) {
            var b = mock.ccBlock(page.order[i]);
            if (!b || b.width <= 0 || b.height <= 0) continue;
            var bx = (b.x + b.width / 2) * stage.scale;
            var by = (b.y + b.height / 2) * stage.scale;
            var dist = Math.pow(cx - bx, 2) + Math.pow(cy - by, 2);
            if (dist < minDist) {
                minDist = dist;
                bestIdx = i;
            }
        }
        return (bestIdx >= 0) ? bestIdx : (page.order.length - 1);
    }

    // ------------------------------------------------------------- Botones de acción
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Сбросить")
            onClicked: {
                page.sys.cfg.ccLayout = "";
                page.sys.cfg.ccSizes = "";
                page.sys.saveCfg();
                page.load();
            }
        }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Применить")
            primary: true
            enabled: page.dirty
            onClicked: {
                page.sys.cfg.ccLayout = page.order.join(",");
                page.sys.cfg.ccSizes = JSON.stringify(page.sizes);
                page.sys.saveCfg();
                page.dirty = false;
            }
        }
    }

    // ------------------------------------------------------------- Gestión de Widgets
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: "Organización y Tamaño de Widgets" }

        Text {
            Layout.fillWidth: true
            text: "Personaliza las proporciones de cada widget (1/3, 1/2 o Completo) y ordénalos con precisión. Dos widgets de 1/2 o tres de 1/3 se alinean automáticamente lado a lado."
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: page.order

                Rectangle {
                    id: rowItem
                    required property int index
                    required property string modelData
                    readonly property var meta: page.metaOf(rowItem.modelData)
                    readonly property string curSize: page.getWidgetSize(rowItem.modelData)

                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 12
                    color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02)
                    border.color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        // Botones de reordenamiento
                        RowLayout {
                            spacing: 3

                            Rectangle {
                                width: 24; height: 24; radius: 6
                                color: upMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (upMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                opacity: rowItem.index > 0 ? 1 : 0.25

                                Text {
                                    anchors.centerIn: parent
                                    text: "▲"
                                    color: page.sys.colFg
                                    font { pixelSize: 9 }
                                }

                                MouseArea {
                                    id: upMa
                                    anchors.fill: parent
                                    enabled: rowItem.index > 0
                                    hoverEnabled: true
                                    cursorShape: rowItem.index > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: page.move(rowItem.index, rowItem.index - 1)
                                }
                            }

                            Rectangle {
                                width: 24; height: 24; radius: 6
                                color: dnMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (dnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                opacity: rowItem.index < page.order.length - 1 ? 1 : 0.25

                                Text {
                                    anchors.centerIn: parent
                                    text: "▼"
                                    color: page.sys.colFg
                                    font { pixelSize: 9 }
                                }

                                MouseArea {
                                    id: dnMa
                                    anchors.fill: parent
                                    enabled: rowItem.index < page.order.length - 1
                                    hoverEnabled: true
                                    cursorShape: rowItem.index < page.order.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: page.move(rowItem.index, rowItem.index + 1)
                                }
                            }
                        }

                        // Icono y Nombre
                        Text {
                            text: rowItem.meta.icon
                            color: page.sys.colOn
                            font { family: page.sys.fontFam; pixelSize: 15 }
                        }

                        Text {
                            text: rowItem.meta.name
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 2; bold: true }
                        }

                        Item { Layout.fillWidth: true }

                        // Selector de tamaño
                        RowLayout {
                            spacing: 4
                            visible: rowItem.meta.canResize

                            Repeater {
                                model: [
                                    { id: "1/3", label: "1/3" },
                                    { id: "1/2", label: "1/2" },
                                    { id: "1",   label: "Completo" }
                                ]

                                Rectangle {
                                    id: pillBtn
                                    required property var modelData
                                    readonly property bool isCur: rowItem.curSize === pillBtn.modelData.id

                                    width: pillText.implicitWidth + 12
                                    height: 24
                                    radius: 12
                                    color: pillBtn.isCur
                                           ? page.sys.colOn
                                           : (pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                                    border.color: pillBtn.isCur ? "transparent" : (pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08))
                                    border.width: 1

                                    scale: pillMa.pressed ? 0.94 : (pillMa.containsMouse ? 1.04 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        id: pillText
                                        anchors.centerIn: parent
                                        text: pillBtn.modelData.label
                                        color: pillBtn.isCur ? (page.sys.themeMaterial ? (page.sys.colM3OnPrimary || page.sys.colBg) : page.sys.colBg) : page.sys.colFg
                                        font { family: page.sys.fontFam; pixelSize: 9; bold: pillBtn.isCur }
                                    }

                                    MouseArea {
                                        id: pillMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setWidgetSize(rowItem.modelData, pillBtn.modelData.id)
                                    }
                                }
                            }
                        }

                        // Etiqueta fija para no redimensionables
                        Text {
                            visible: !rowItem.meta.canResize
                            text: "Completo"
                            color: page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 10 }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- Aspecto y Micro-interacciones
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Aspecto y Micro-interacciones") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Ancho del Centro de Control")
            from: 420
            to: 640
            step: 10
            value: page.sys.cfg.panelW || 540
            suffix: "px"
            onMoved: v => { page.sys.cfg.panelW = Math.round(v); page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Resplandor dinámico en controles deslizantes")
            sub: page.sys.tr("Iluminación suave en las barras de volumen y brillo.")
            on: page.sys.cfg.animSlidersGlow !== false
            onToggled: v => { page.sys.cfg.animSlidersGlow = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Micro-elevación en bloques rápidos")
            sub: page.sys.tr("Respuesta táctil y elevación reactiva al pasar el cursor.")
            on: page.sys.cfg.animTileHover !== false
            onToggled: v => { page.sys.cfg.animTileHover = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Elevación sutil de tarjetas (3D Lift)")
            sub: page.sys.tr("Micro-escala en tarjetas de audio, brillo y reproductor.")
            on: page.sys.cfg.animCardLift !== false
            onToggled: v => { page.sys.cfg.animCardLift = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Onda fluida en tarjeta de batería")
            sub: page.sys.tr("Animación de marea líquida cuando el equipo se está cargando.")
            on: page.sys.cfg.ccShowBatteryWave !== false
            onToggled: v => { page.sys.cfg.ccShowBatteryWave = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Desplazamiento responsivo en listas")
            sub: page.sys.tr("Deslizamiento lateral kinético al seleccionar elementos.")
            on: page.sys.cfg.animMenuSlide !== false
            onToggled: v => { page.sys.cfg.animMenuSlide = v; page.sys.saveCfg(); }
        }
    }
}
