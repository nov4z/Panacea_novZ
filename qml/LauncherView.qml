import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Lanzador de aplicaciones moderno para Panacea Shell.
// Búsqueda inteligente, filtro por categorías rápidas, calculadora integrada,
// historial de aplicaciones recientes, atajos del sistema y navegación táctil/teclado.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property string query: ""
    property int index: 0
    property string activeCategory: "all" // "all", "recent", "system", "web", "media"
    readonly property int maxRows: (view.sys.cfg.launcherMaxRows !== undefined ? view.sys.cfg.launcherMaxRows : 6)

    // Historial de aplicaciones recientes guardado en caché
    property var recent: []
    readonly property string recentFile:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/panacea/recent-apps"

    Process {
        id: pRecentRead
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", view.recentFile]
        running: true
        stdout: StdioCollector {
            onStreamFinished: view.recent = text.trim().split("\n").filter(x => x.length)
        }
    }
    Process { id: pRecentWrite }

    function rememberApp(app) {
        var id = String(app.id || app.name || "");
        if (!id.length) return;
        var list = view.recent.filter(x => x !== id);
        list.unshift(id);
        if (list.length > 25) list = list.slice(0, 25);
        view.recent = list;
        pRecentWrite.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s' \"$2\" > \"$1\"",
            "_", view.recentFile, list.join("\n")];
        pRecentWrite.running = true;
    }

    function recentRank(app) {
        var i = view.recent.indexOf(String(app.id || app.name || ""));
        return i < 0 ? 999 : i;
    }

    // Acciones integradas en el lanzador
    readonly property var builtins: [
        {
            builtin: "agents",
            id: "panacea:agents",
            glyph: String.fromCodePoint(0xF1719),
            name: view.sys.tr("Agentes IA"),
            genericName: view.sys.tr("Límites de Claude, Gemini y herramientas IA"),
            category: "system",
            keys: "agents agent ai claude codex gemini copilot cursor limits usage plan agentes ia"
        },
        {
            builtin: "test_battery",
            id: "panacea:test_battery",
            glyph: String.fromCodePoint(0xF0079),
            name: view.sys.tr("Probar aviso de batería baja"),
            genericName: view.sys.tr("Animación Dynamic Island de batería baja"),
            category: "system",
            keys: "bateria battery low alert baja test prueba isla notch"
        },
        {
            builtin: "test_charge",
            id: "panacea:test_charge",
            glyph: String.fromCodePoint(0xF0241),
            name: view.sys.tr("Probar animación de carga"),
            genericName: view.sys.tr("Animación de rayo y sonido de carga"),
            category: "system",
            keys: "carga charging rayo rayito ac toast sonido test prueba isla notch"
        },
        {
            builtin: "test_fullcharge",
            id: "panacea:test_fullcharge",
            glyph: String.fromCodePoint(0xF0079),
            name: view.sys.tr("Probar batería 100%"),
            genericName: view.sys.tr("Animación de batería completa al 100%"),
            category: "system",
            keys: "bateria battery full cargado 100 carga completa test prueba isla notch"
        }
    ]

    property var systems: []

    Process {
        id: pSystems
        command: ["sh", view.sys.scriptDir + "/bootos.sh", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = String(text).trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|");
                    if (p.length < 3) continue;
                    out.push({
                        builtin: "bootos",
                        bootId: p[0],
                        name: p[1],
                        genericName: view.sys.tr("Reiniciar en ") + p[1],
                        category: "system",
                        glyph: String.fromCodePoint(0xF0709),
                        keys: p[1] + " " + p[2] + " reboot restart boot os"
                    });
                }
                view.systems = out;
            }
        }
    }

    function bootInto(app) {
        view.sys.bootIntoSystem(app.bootId);
        view.sys.closeLauncher();
    }

    readonly property var extras: view.builtins.concat(view.systems)

    function builtinMatches(b, q) {
        if (q.length === 0) return false;
        if (String(b.name).toLowerCase().indexOf(q) >= 0) return true;
        return String(b.keys).toLowerCase().indexOf(q) >= 0;
    }

    function matchesCategory(app, cat) {
        if (cat === "all") return true;
        if (cat === "recent") return view.recentRank(app) < 999;
        var s = (String(app.name || "") + " " + String(app.genericName || "") + " " + String(app.id || "") + " " + String(app.comment || "")).toLowerCase();
        if (cat === "system") {
            return app.builtin !== undefined || s.indexOf("config") >= 0 || s.indexOf("setting") >= 0 || s.indexOf("system") >= 0 || s.indexOf("terminal") >= 0 || s.indexOf("file") >= 0;
        }
        if (cat === "web") {
            return s.indexOf("browser") >= 0 || s.indexOf("web") >= 0 || s.indexOf("chrome") >= 0 || s.indexOf("brave") >= 0 || s.indexOf("firefox") >= 0 || s.indexOf("discord") >= 0;
        }
        if (cat === "media") {
            return s.indexOf("music") >= 0 || s.indexOf("audio") >= 0 || s.indexOf("sound") >= 0 || s.indexOf("video") >= 0 || s.indexOf("player") >= 0 || s.indexOf("spotify") >= 0;
        }
        return true;
    }

    // Filtrado y ordenación
    readonly property var results: {
        var q = query.trim().toLowerCase();
        var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        var starts = [], contains = [];
        var pinned = [];

        for (var b = 0; b < view.extras.length; b++) {
            var bi = view.extras[b];
            if (!view.matchesCategory(bi, view.activeCategory)) continue;
            if (q.length === 0) {
                if (bi.builtin !== "bootos") starts.push(bi);
            } else if (view.builtinMatches(bi, q)) {
                pinned.push(bi);
            }
        }

        for (var i = 0; i < all.length; i++) {
            var a = all[i];
            if (!a || a.noDisplay) continue;
            if (!view.matchesCategory(a, view.activeCategory)) continue;
            var n = String(a.name || "").toLowerCase();
            if (q.length === 0) {
                starts.push(a);
                continue;
            }
            var pos = n.indexOf(q);
            if (pos === 0) starts.push(a);
            else if (pos > 0) contains.push(a);
            else if (String(a.genericName || "").toLowerCase().indexOf(q) >= 0) contains.push(a);
        }

        var byName = function (x, y) {
            return String(x.name || "").localeCompare(String(y.name || ""));
        };

        if (q.length === 0) {
            starts.sort(function (x, y) {
                var d = view.recentRank(x) - view.recentRank(y);
                return d !== 0 ? d : byName(x, y);
            });
            return starts;
        }
        starts.sort(byName);
        contains.sort(byName);
        return pinned.concat(starts, contains);
    }

    // Calculadora rápida
    readonly property bool isMath: {
        var q = query.trim();
        if (q.length < 3) return false;
        if (!/[+\-*/^%]/.test(q)) return false;
        return /^[0-9\s+\-*/().,%^]+$/.test(q);
    }

    readonly property string mathResult: {
        if (!isMath) return "";
        try {
            var e = query.trim().replace(/,/g, ".").replace(/\^/g, "**");
            var r = Function('"use strict"; return (' + e + ')')();
            if (typeof r !== "number" || !isFinite(r)) return "";
            return String(parseFloat(r.toFixed(10)));
        } catch (err) {
            return "";
        }
    }

    Process { id: pCopyCalc }
    function copyResult() {
        if (mathResult.length === 0) return;
        pCopyCalc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", mathResult];
        pCopyCalc.running = true;
        if (view.sys && view.sys.playSound) view.sys.playSound("pop");
        view.sys.closeLauncher();
    }

    onQueryChanged: index = 0
    onActiveCategoryChanged: index = 0
    onResultsChanged: if (index >= results.length) index = Math.max(0, results.length - 1)

    function launch() {
        if (view.mathResult.length > 0) { copyResult(); return; }
        var app = results[index];
        if (!app) return;
        if (view.sys && view.sys.playSound) view.sys.playSound("pop");
        if (app.builtin === "agents") { rememberApp(app); view.sys.openAgents(); return; }
        if (app.builtin === "test_battery") { view.sys.closeLauncher(); view.sys.showLowBattToast(view.sys.batteryPct || 20); return; }
        if (app.builtin === "test_charge") { view.sys.closeLauncher(); view.sys.showAcToast(); return; }
        if (app.builtin === "test_fullcharge") { view.sys.closeLauncher(); view.sys.showFullBattToast(); return; }
        if (app.builtin === "bootos") { bootInto(app); return; }
        rememberApp(app);
        app.execute();
        view.sys.closeLauncher();
    }

    function move(delta) {
        if (results.length === 0) return;
        index = Math.max(0, Math.min(results.length - 1, index + delta));
        list.positionViewAtIndex(index, ListView.Contain);
        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
    }

    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ------------------------------------------------------------ Barra de Búsqueda
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 14
            color: input.activeFocus
                   ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09)
                   : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
            border.color: input.activeFocus
                          ? view.sys.colOn
                          : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
            border.width: input.activeFocus ? 1.5 : 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 10

                Glyph {
                    glyph: String.fromCodePoint(0xF0349)
                    color: input.activeFocus ? view.sys.colOn : view.sys.colMuted
                    size: 17
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextField {
                    id: input
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.sys.tr("Buscar aplicaciones, herramientas o cálculo…")
                    color: view.sys.colFg
                    placeholderTextColor: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.38)
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                    background: null
                    onTextChanged: view.query = text

                    Keys.onDownPressed:   view.move(1)
                    Keys.onUpPressed:     view.move(-1)
                    Keys.onReturnPressed: view.launch()
                    Keys.onEnterPressed:  view.launch()
                    Keys.onEscapePressed: view.sys.closeLauncher()
                    Keys.onTabPressed:    view.move(1)
                }

                // Botón limpiar texto
                Rectangle {
                    visible: input.text.length > 0
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: clearMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: input.text = ""
                    }
                }

                // Contador de aplicaciones en badge pill
                Rectangle {
                    visible: view.results.length > 0
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: countLabel.implicitWidth + 14
                    radius: 11
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                    border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                    border.width: 1

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: view.results.length + (view.results.length === 1 ? " app" : " apps")
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                    }
                }
            }
        }

        // ------------------------------------------------------------ Chips de Categorías Rápidas
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: view.query.length === 0

            Repeater {
                model: [
                    { id: "all",     label: "Todas" },
                    { id: "recent",  label: "Recientes" },
                    { id: "web",     label: "Internet" },
                    { id: "media",   label: "Multimedia" },
                    { id: "system",  label: "Sistema" }
                ]

                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: view.activeCategory === modelData.id

                    Layout.preferredHeight: 26
                    Layout.preferredWidth: chipText.implicitWidth + 18
                    radius: 13
                    color: active
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                           : (chipMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04))
                    border.color: active ? view.sys.colOn : (chipMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.16) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    scale: chipMa.pressed ? 0.95 : (chipMa.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.active ? view.sys.colFg : (chipMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                        font { family: view.sys.fontFam; pixelSize: 10; bold: chip.active }
                    }

                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                            view.activeCategory = chip.modelData.id;
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ------------------------------------------------------------ Tarjeta Resultado Calculadora
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: view.mathResult.length > 0
            radius: 14
            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
            border.color: view.sys.colOn
            border.width: 1.5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Glyph {
                    glyph: String.fromCodePoint(0xF00EC)
                    color: view.sys.colOn
                    size: 20
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: view.query.trim() + " ="
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 10 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: view.mathResult
                        color: view.sys.colFg
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 3; bold: true }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: calcBadgeRow.implicitWidth + 20
                    radius: 8
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                    border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.50)
                    border.width: 1

                    RowLayout {
                        id: calcBadgeRow
                        anchors.centerIn: parent
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 18
                            radius: 4
                            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                            border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.70)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -0.5
                                text: "󰌑"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                        }

                        Text {
                            text: view.sys.tr("Copiar")
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: view.copyResult()
            }
        }

        // ------------------------------------------------------------ Lista de Resultados
        ListView {
            id: list
            Layout.fillWidth: true
            visible: view.mathResult.length === 0
            Layout.preferredHeight: view.mathResult.length > 0 ? 0
                                  : Math.min(view.results.length, view.maxRows) * 56
            clip: true
            model: view.results
            currentIndex: view.index
            boundsBehavior: Flickable.OvershootBounds
            flickDeceleration: 2200
            spacing: 3

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property bool isSelected: row.index === view.index

                width: list.width - 10
                x: 4
                height: 52
                radius: 13
                color: isSelected
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                       : (rowMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.065) : "transparent")
                border.color: isSelected
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                              : (rowMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10) : "transparent")
                border.width: 1
                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                scale: rowMa.pressed ? 0.975 : ((rowMa.containsMouse || isSelected) && view.sys.cfg.animCardLift !== false ? 1.010 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                transform: Translate {
                    x: ((isSelected || rowMa.containsMouse) && view.sys.cfg.animMenuSlide !== false) ? 2 : 0
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                // Indicador vertical de selección izquierda
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    width: 3
                    radius: 1.5
                    color: view.sys.colOn
                    visible: row.isSelected
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 12

                    // Contenedor de Icono en squircle
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: row.isSelected
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        border.color: row.isSelected ? view.sys.colOn : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                        border.width: 1

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            anchors.margins: 4
                            source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 48
                            sourceSize.height: 48
                            visible: status === Image.Ready
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: !appIcon.visible && String(row.modelData.glyph || "").length > 0
                            glyph: row.modelData.glyph || ""
                            color: row.isSelected ? view.sys.colOn : view.sys.colFg
                            size: 16
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !appIcon.visible && String(row.modelData.glyph || "").length === 0
                            text: String(row.modelData.name || "?").charAt(0).toUpperCase()
                            color: row.isSelected ? view.sys.colOn : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                        }
                    }

                    // Título y descripción
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name || ""
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: 13
                                bold: row.isSelected
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: row.modelData.genericName || ""
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }

                    // Insignia física de ejecución estilo Nothing OS con tecla Return
                    Rectangle {
                        visible: row.isSelected
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: badgeRow.implicitWidth + 22
                        radius: 8
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                        border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.50)
                        border.width: 1

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 7

                            // Keycap físico para tecla Return/Enter
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 18
                                radius: 4
                                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.70)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -0.5
                                    text: "󰌑"
                                    color: view.sys.colOn
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                            }

                            Text {
                                id: launchBadgeTxt
                                text: view.sys.tr("Abrir")
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.index = row.index
                    onClicked: view.launch()
                }
            }
        }

        // ------------------------------------------------------------ Estado Vacío
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: 14
            visible: view.results.length === 0 && view.mathResult.length === 0
            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.03)
            border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Glyph {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: String.fromCodePoint(0xF0349)
                    color: view.sys.colMuted
                    size: 18
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.tr("No se encontraron aplicaciones")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.sys.tr("Prueba escribiendo otra palabra o selecciona otra categoría")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }
    }
}
