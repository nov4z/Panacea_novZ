import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

// DockView: Barra inferior inspirada en macOS y basada fielmente en la foto de referencia,
// con filosofía Nothing OS: diseño full black (#000000) 100% sin bordes,
// esquinas redondeadas tipo squircle (10px border-radius),
// Logo de Arch Linux (abre Super+Space), Config al lado (abre Super+I),
// Carpeta de archivos (abre Super+E), separadores sutiles, apps fijadas,
// apps abiertas recientemente con micro-puntos indicadores blancos,
// y sin lupa, sin papelera ni carpeta de descargas con flecha.
Item {
    id: dock

    property var sys

    readonly property string defaultAppsStr: "brave-origin.desktop,kitty.desktop,com.spotify.Client.desktop,antigravity.desktop"
    readonly property int iconSize: (dock.sys && dock.sys.cfg && dock.sys.cfg.dockIconSize) || 34
    readonly property real zoomMax: (dock.sys && dock.sys.cfg && dock.sys.cfg.dockZoom) || 1.20
    readonly property bool magnifyEnabled: !(dock.sys && dock.sys.cfg && dock.sys.cfg.dockMagnify === false)
    readonly property bool bounceEnabled: !(dock.sys && dock.sys.cfg && dock.sys.cfg.dockBounce === false)
    readonly property bool showRunningEnabled: !(dock.sys && dock.sys.cfg && dock.sys.cfg.dockShowRunning === false)

    readonly property real cornerFilletR: (dock.sys && dock.sys.themeMaterial) ? 20 : 14

    readonly property color dockBgColor: {
        if (dock.sys && dock.sys.themeMaterial) {
            return (dock.sys.matugenColors && dock.sys.matugenColors.surface_container)
                ? dock.sys.matugenColors.surface_container.dark.color
                : (dock.sys.colM3SurfaceContainer || dock.sys.colBg);
        }
        if (dock.sys && dock.sys.themeNothing) {
            return "#000000";
        }
        return (dock.sys && dock.sys.colBg) ? dock.sys.colBg : "#000000";
    }

    implicitWidth: capsule.width + cornerFilletR * 2 + 10
    implicitHeight: capsule.height + 34

    // Helper: Resolver información de cualquier ítem
    function getItemInfo(id) {
        if (id === "panacea:arch") {
            return {
                id: id,
                name: "PANACEA",
                icon: (dock.sys && dock.sys.themeMaterial) ? "" : Qt.resolvedUrl("assets/arch_cachy_nothing.svg"),
                glyph: (dock.sys && dock.sys.themeMaterial) ? "󰀻" : "",
                glyphColor: (dock.sys && dock.sys.themeMaterial) ? dock.sys.colOn : "#ffffff",
                isBuiltin: true,
                builtin: "arch"
            };
        }
        if (id === "panacea:settings") {
            return {
                id: id,
                name: "AJUSTES",
                icon: "",
                glyph: "󰒓",
                glyphColor: (dock.sys && dock.sys.themeMaterial) ? dock.sys.colFg : "#ffffff",
                isBuiltin: true,
                builtin: "settings"
            };
        }
        if (id === "panacea:files") {
            return {
                id: id,
                name: "ARCHIVOS",
                icon: "",
                glyph: "󰉋",
                glyphColor: (dock.sys && dock.sys.themeMaterial) ? dock.sys.colFg : "#ffffff",
                isBuiltin: true,
                builtin: "files"
            };
        }
        if (id === "panacea:controls") {
            return {
                id: id,
                name: "CONTROL",
                icon: "",
                glyph: "󰕮",
                glyphColor: "#ffffff",
                isBuiltin: true,
                builtin: "controls"
            };
        }
        if (id === "panacea:overview") {
            return {
                id: id,
                name: "VISTA GENERAL",
                icon: "",
                glyph: "󰕰",
                glyphColor: "#ffffff",
                isBuiltin: true,
                builtin: "overview"
            };
        }

        var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        var cleanId = id.replace(/\.desktop$/, "").toLowerCase();
        for (var i = 0; i < all.length; i++) {
            var a = all[i];
            if (!a) continue;
            var aid = String(a.id || "").replace(/\.desktop$/, "").toLowerCase();
            if (aid === cleanId || String(a.id || "").toLowerCase() === id.toLowerCase()) {
                return {
                    id: a.id,
                    name: String(a.name || cleanId).toUpperCase(),
                    icon: a.icon || "",
                    glyph: "",
                    glyphColor: "#ffffff",
                    entry: a,
                    isBuiltin: false
                };
            }
        }
        for (var j = 0; j < all.length; j++) {
            var b = all[j];
            if (!b) continue;
            if (String(b.name || "").toLowerCase() === cleanId) {
                return {
                    id: b.id,
                    name: String(b.name).toUpperCase(),
                    icon: b.icon || "",
                    glyph: "",
                    glyphColor: "#ffffff",
                    entry: b,
                    isBuiltin: false
                };
            }
        }
        return {
            id: id,
            name: cleanId.toUpperCase(),
            icon: id,
            glyph: "",
            glyphColor: "#ffffff",
            entry: null,
            isBuiltin: false
        };
    }

    // 1. Sección Izquierda: Logo de Arch (Super+Space) + Config (Super+I) + Carpeta (Super+E)
    readonly property var leftItems: [
        dock.getItemInfo("panacea:arch"),
        dock.getItemInfo("panacea:settings"),
        dock.getItemInfo("panacea:files")
    ]

    // 2. Sección Central: Aplicaciones Fijadas configuradas por el usuario
    readonly property var pinnedItems: {
        var raw = String(dock.sys && dock.sys.cfg && dock.sys.cfg.dockApps !== undefined
                         ? dock.sys.cfg.dockApps : dock.defaultAppsStr);
        var ids = raw.split(",").map(x => x.trim()).filter(x => x.length > 0);
        var out = [];
        for (var i = 0; i < ids.length; i++) {
            // Evitamos duplicar los ítems de la izquierda
            if (ids[i] === "panacea:arch" || ids[i] === "panacea:settings" || ids[i] === "panacea:files" ||
                ids[i] === "panacea:finder" || ids[i] === "panacea:launcher" ||
                ids[i] === "panacea:downloads" || ids[i] === "panacea:trash") continue;
            out.push(dock.getItemInfo(ids[i]));
        }
        return out;
    }

    property int windowRevision: Compositor._hyprRevision
    Connections {
        target: Hyprland
        function onRawEvent(ev) { dock.windowRevision++; }
    }

    // 3. Sección Recientes / Abiertas (Apps en ejecución no fijadas)
    readonly property var unpinnedRunningItems: {
        var _rev = dock.windowRevision;
        if (!dock.showRunningEnabled) return [];
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        var allDesktop = DesktopEntries.applications ? DesktopEntries.applications.values : [];

        var knownClasses = ["thunar"];
        for (var i = 0; i < dock.pinnedItems.length; i++) {
            var pi = dock.pinnedItems[i];
            knownClasses.push(String(pi.id || "").replace(/\.desktop$/, "").toLowerCase());
            knownClasses.push(String(pi.name || "").toLowerCase());
        }

        var out = [];
        var seen = {};

        for (var t = 0; t < toplevels.length; t++) {
            var top = toplevels[t];
            if (!top || !top.lastIpcObject) continue;
            var cls = String(top.lastIpcObject.initialClass || top.lastIpcObject.class || "").toLowerCase();
            if (!cls.length || seen[cls]) continue;

            var isKnown = false;
            for (var k = 0; k < knownClasses.length; k++) {
                var kc = knownClasses[k];
                if (cls === kc || cls.indexOf(kc) >= 0 || kc.indexOf(cls) >= 0) {
                    isKnown = true;
                    break;
                }
            }
            if (isKnown) continue;

            seen[cls] = true;

            var matchedEntry = null;
            for (var d = 0; d < allDesktop.length; d++) {
                var de = allDesktop[d];
                if (!de) continue;
                var did = String(de.id || "").replace(/\.desktop$/, "").toLowerCase();
                var dname = String(de.name || "").toLowerCase();
                if (did === cls || did.indexOf(cls) >= 0 || cls.indexOf(did) >= 0 ||
                    dname === cls || dname.indexOf(cls) >= 0 || cls.indexOf(dname) >= 0) {
                    matchedEntry = de;
                    break;
                }
            }

            if (matchedEntry) {
                out.push({
                    id: matchedEntry.id,
                    name: String(matchedEntry.name || cls).toUpperCase(),
                    icon: matchedEntry.icon || "",
                    glyph: "",
                    glyphColor: "#ffffff",
                    entry: matchedEntry,
                    isBuiltin: false,
                    isRecentRunning: true,
                    windowClass: cls
                });
            } else {
                out.push({
                    id: cls,
                    name: cls.toUpperCase(),
                    icon: cls,
                    glyph: "",
                    glyphColor: "#ffffff",
                    entry: null,
                    isBuiltin: false,
                    isRecentRunning: true,
                    windowClass: cls
                });
            }
            if (out.length >= 5) break;
        }
        return out;
    }

    // Comprobación de estado en ejecución
    function isRunning(item) {
        if (!dock.showRunningEnabled) return false;
        if (item.isRecentRunning) return true;
        if (item.isBuiltin) {
            if (item.builtin === "arch") return !!(dock.sys && dock.sys.launcherOpen);
            if (item.builtin === "settings") return !!(dock.sys && dock.sys.expanded && dock.sys.page === "settings");
            if (item.builtin === "files") return isRunningClass("thunar") || !!(dock.sys && dock.sys.expanded && dock.sys.page === "files");
            if (item.builtin === "controls") return !!(dock.sys && dock.sys.expanded && dock.sys.page === "main");
            if (item.builtin === "overview") return !!(dock.sys && dock.sys.overviewOpen);
            return false;
        }

        var cleanId = String(item.id || "").replace(/\.desktop$/, "").toLowerCase();
        var cleanName = String(item.name || "").toLowerCase();
        return isRunningClass(cleanId) || isRunningClass(cleanName);
    }

    function isRunningClass(query) {
        var q = query.toLowerCase();
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < toplevels.length; i++) {
            var t = toplevels[i];
            if (!t || !t.lastIpcObject) continue;
            var cls = String(t.lastIpcObject.initialClass || t.lastIpcObject.class || "").toLowerCase();
            if (!cls.length) continue;
            if (cls === q || cls.indexOf(q) >= 0 || q.indexOf(cls) >= 0) return true;
            if (q.indexOf("spotify") >= 0 && cls.indexOf("spotify") >= 0) return true;
            if ((q.indexOf("kitty") >= 0 || q.indexOf("terminal") >= 0 || q.indexOf("foot") >= 0) && (cls.indexOf("kitty") >= 0 || cls.indexOf("foot") >= 0)) return true;
        }
        return false;
    }

    // Acción al hacer clic en un ítem
    function activateItem(item) {
        if (dock.sys && dock.sys.playSound) dock.sys.playSound("tock");

        if (item.isBuiltin) {
            // Arch Linux logo abre Super + Space (Launcher)
            if (item.builtin === "arch") {
                dock.sys.toggleLauncher();
                return;
            }
            // Config al lado abre Super + I (Settings)
            if (item.builtin === "settings") {
                if (dock.sys) {
                    dock.sys.settingsTab = 0;
                    dock.sys.togglePage("settings");
                }
                return;
            }
            // Carpeta abre Super + E (Files / Thunar)
            if (item.builtin === "files") {
                dock.sys.togglePage("files");
                return;
            }
            if (item.builtin === "controls") {
                dock.sys.togglePage("main");
                return;
            }
            if (item.builtin === "overview") {
                dock.sys.toggleOverview();
                return;
            }
            return;
        }

        var cls = item.windowClass || String(item.id || "").replace(/\.desktop$/, "").toLowerCase();
        if (focusWindowByClass(cls)) return;

        if (item.entry && typeof item.entry.execute === "function") {
            item.entry.execute();
        } else {
            var cmd = cls;
            if (cls.indexOf("spotify") >= 0) cmd = "spotify";
            else if (cls.indexOf("kitty") >= 0 || cls.indexOf("foot") >= 0 || cls.indexOf("terminal") >= 0) cmd = "kitty";
            else if (cls.indexOf("brave") >= 0) cmd = "brave";
            Hyprland.dispatch("exec " + cmd);
        }
    }

    function focusWindowByClass(target) {
        var q = target.toLowerCase();
        var toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < toplevels.length; i++) {
            var t = toplevels[i];
            if (!t || !t.lastIpcObject) continue;
            var cls = String(t.lastIpcObject.initialClass || t.lastIpcObject.class || "");
            var lcls = cls.toLowerCase();
            if (!lcls.length) continue;

            if (lcls === q || lcls.indexOf(q) >= 0 || q.indexOf(lcls) >= 0 ||
                (q.indexOf("spotify") >= 0 && lcls.indexOf("spotify") >= 0)) {
                Hyprland.dispatch("hl.dsp.focus({ window = 'class:" + cls + "' })");
                if (t.lastIpcObject.workspace && t.lastIpcObject.workspace.id !== undefined) {
                    Hyprland.dispatch("workspace " + t.lastIpcObject.workspace.id);
                }
                return true;
            }
        }
        return false;
    }

    property real mouseDockX: -9999
    property bool mouseInsideDock: false

    // Cápsula: Conectada al borde inferior como un Notch, FULL BLACK 100% SIN BORDES
    Rectangle {
        id: capsule
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter

        property real targetW: allSectionsRow.implicitWidth + 24
        readonly property bool expanding: targetW > width
        width: targetW
        height: dock.iconSize + 12
        radius: 14

        Behavior on width {
            NumberAnimation {
                duration: capsule.expanding ? 340 : 280
                easing.type: capsule.expanding ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.05
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }

        color: dock.dockBgColor
        border.width: (dock.sys && dock.sys.themeMaterial) ? 1 : 0
        border.color: (dock.sys && dock.sys.themeMaterial)
            ? Qt.rgba(dock.sys.colOn.r, dock.sys.colOn.g, dock.sys.colOn.b, 0.16)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 320 } }

        // Base rectangular que cuadra las esquinas inferiores para unirse limpiamente al borde
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: (dock.sys && dock.sys.themeMaterial) ? 1 : 0
            anchors.rightMargin: (dock.sys && dock.sys.themeMaterial) ? 1 : 0
            height: capsule.radius
            color: dock.dockBgColor
            Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }

        // Fila que contiene las secciones
        Row {
            id: allSectionsRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 6

            // ================= 1. Sección Izquierda (Arch Logo, Config, Carpeta)
            Row {
                spacing: 6
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: dock.leftItems
                    delegate: dockItemComponent
                }
            }

            // Separador sutil vertical
            Rectangle {
                width: 1
                height: 16
                color: (dock.sys && dock.sys.themeMaterial)
                       ? Qt.rgba(dock.sys.colFg.r, dock.sys.colFg.g, dock.sys.colFg.b, 0.16)
                       : Qt.rgba(1, 1, 1, 0.12)
                anchors.verticalCenter: parent.verticalCenter
            }

            // ================= 2. Sección Central (Apps Fijadas)
            Row {
                spacing: 6
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: dock.pinnedItems
                    delegate: dockItemComponent
                }
            }

            // Separador para apps recientes (si hay abiertas)
            Rectangle {
                width: 1
                height: 16
                color: (dock.sys && dock.sys.themeMaterial)
                       ? Qt.rgba(dock.sys.colFg.r, dock.sys.colFg.g, dock.sys.colFg.b, 0.16)
                       : Qt.rgba(1, 1, 1, 0.12)
                visible: dock.unpinnedRunningItems.length > 0
                anchors.verticalCenter: parent.verticalCenter
            }

            // ================= 3. Sección Apps Abiertas Recientes
            Row {
                spacing: 6
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                visible: dock.unpinnedRunningItems.length > 0
                Repeater {
                    model: dock.unpinnedRunningItems
                    delegate: dockItemComponent
                }
            }
        }

        // Componente delegado para cada icono del dock
        Component {
            id: dockItemComponent

            Item {
                id: slot
                required property var modelData

                width: dock.iconSize
                height: capsule.height

                readonly property bool activeRunning: {
                    if (!dock.showRunningEnabled) return false;
                    var _exp = (dock.sys && dock.sys.expanded);
                    var _page = (dock.sys && dock.sys.page);
                    return dock.isRunning(modelData);
                }

                // Centro del slot respecto a la cápsula (coordenadas estables)
                readonly property real slotCenterX: allSectionsRow.x + (slot.parent ? slot.parent.x : 0) + slot.x + slot.width / 2
                readonly property real dist: Math.abs(dock.mouseDockX - slotCenterX)
                readonly property real influenceRadius: dock.iconSize * 1.85

                // Escala máxima segura: garantiza matemáticamente que el icono nunca toque ni sobrepase el borde de la cápsula
                readonly property real maxSafeZoom: Math.min(dock.zoomMax, (capsule.height - 6) / dock.iconSize)

                readonly property real computedScale: {
                    if (!dock.magnifyEnabled || !dock.mouseInsideDock || dist >= influenceRadius) return 1.0;
                    var factor = Math.cos((dist / influenceRadius) * (Math.PI / 2));
                    return 1.0 + (maxSafeZoom - 1.0) * (factor * factor);
                }

                Item {
                    id: iconBox
                    width: dock.iconSize
                    height: dock.iconSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1 + bounceOffset

                    scale: slot.computedScale
                    transformOrigin: Item.Center

                    Behavior on scale {
                        NumberAnimation {
                            duration: 130
                            easing.type: Easing.OutCubic
                        }
                    }

                    property real bounceOffset: 0

                    SequentialAnimation {
                        id: bounceAnim
                        // Salto elástico con doble rebote físico suave y orgánico
                        NumberAnimation { target: iconBox; property: "bounceOffset"; to: -15; duration: 140; easing.type: Easing.OutCubic }
                        NumberAnimation { target: iconBox; property: "bounceOffset"; to: 2; duration: 100; easing.type: Easing.InQuad }
                        NumberAnimation { target: iconBox; property: "bounceOffset"; to: -6; duration: 80; easing.type: Easing.OutQuad }
                        NumberAnimation { target: iconBox; property: "bounceOffset"; to: 0; duration: 90; easing.type: Easing.OutQuad }
                    }

                    // Icono de la app
                    Image {
                        id: appIconImg
                        anchors.centerIn: parent
                        width: dock.iconSize - 4
                        height: dock.iconSize - 4
                        sourceSize.width: Math.round(width * 2)
                        sourceSize.height: Math.round(height * 2)
                        source: {
                            if (!slot.modelData.icon) return "";
                            if (slot.modelData.icon.indexOf("/") === 0) return "file://" + slot.modelData.icon;
                            if (slot.modelData.icon.indexOf("file://") === 0) return slot.modelData.icon;
                            return Quickshell.iconPath(slot.modelData.icon, true);
                        }
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // Glyph para Config, Carpeta y accesos directos (centrado por ink bounds ópticos mediante Glyph.qml)
                    Glyph {
                        anchors.centerIn: parent
                        visible: (!slot.modelData.icon || !appIconImg.visible) && (slot.modelData.glyph && slot.modelData.glyph.length > 0)
                        glyph: slot.modelData.glyph || "󰣆"
                        color: slot.modelData.glyphColor || "#ffffff"
                        fontFam: dock.sys ? dock.sys.fontFam : "JetBrainsMono Nerd Font"
                        size: Math.round(dock.iconSize * 0.54)
                    }

                    // Tooltip técnico Nothing OS / M3
                    Rectangle {
                        id: tooltip
                        visible: itemMa.containsMouse
                        opacity: itemMa.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        anchors.bottom: iconBox.top
                        anchors.bottomMargin: (dock.sys && dock.sys.themeMaterial) ? 10 : 8
                        anchors.horizontalCenter: iconBox.horizontalCenter

                        width: ttRow.implicitWidth + ((dock.sys && dock.sys.themeMaterial) ? 18 : 14)
                        height: ttRow.implicitHeight + ((dock.sys && dock.sys.themeMaterial) ? 8 : 6)
                        radius: (dock.sys && dock.sys.themeMaterial) ? 10 : 6
                        color: (dock.sys && dock.sys.themeMaterial)
                               ? (dock.sys.colM3SurfaceContainerHigh || dock.sys.colBg)
                               : "#000000"
                        border.width: 1
                        border.color: (dock.sys && dock.sys.themeMaterial)
                                      ? Qt.rgba(dock.sys.colOn.r, dock.sys.colOn.g, dock.sys.colOn.b, 0.22)
                                      : Qt.rgba(1, 1, 1, 0.16)

                        Row {
                            id: ttRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: (dock.sys && dock.sys.themeMaterial) ? 5 : 3
                                height: (dock.sys && dock.sys.themeMaterial) ? 5 : 3
                                radius: width / 2
                                color: (dock.sys && dock.sys.themeMaterial)
                                       ? dock.sys.colOn
                                       : (slot.modelData.builtin === "arch" ? "#ff2825" : "#ffffff")
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: slot.modelData.name
                                color: (dock.sys && dock.sys.themeMaterial) ? dock.sys.colFg : "#ffffff"
                                font {
                                    family: dock.sys ? dock.sys.fontBody : "JetBrainsMono Nerd Font"
                                    pixelSize: (dock.sys && dock.sys.themeMaterial) ? 11 : 10
                                    bold: true
                                    letterSpacing: (dock.sys && dock.sys.themeMaterial) ? 0.4 : 1.1
                                }
                            }
                        }
                    }
                }

                // Indicador de app activa (Material 3 pill o micro-punto en Nothing) perfectamente centrado con iconBox
                Rectangle {
                    id: activeIndicator
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: iconBox.horizontalCenter
                    width: (dock.sys && dock.sys.themeMaterial) ? 12 : 3
                    height: (dock.sys && dock.sys.themeMaterial) ? 2.5 : 3
                    radius: height / 2
                    color: (dock.sys && dock.sys.themeMaterial) ? dock.sys.colOn : "#ffffff"
                    scale: slot.activeRunning ? 1.0 : 0.0
                    opacity: slot.activeRunning ? 1.0 : 0.0
                    visible: opacity > 0
                    transformOrigin: Item.Center

                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on color { ColorAnimation { duration: 240 } }
                }

                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (dock.bounceEnabled) {
                            bounceAnim.restart();
                        }
                        dock.activateItem(slot.modelData);
                    }
                }
            }
        }

        // Detección pasiva de movimiento del ratón para el efecto magnify (sin interceptar clics)
        HoverHandler {
            id: dockCapsuleHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onPointChanged: {
                dock.mouseDockX = point.position.x;
            }
            onHoveredChanged: {
                dock.mouseInsideDock = hovered;
                if (!hovered) {
                    dock.mouseDockX = -9999;
                }
            }
        }
    }

    // ------------------- Esquinas curvas invertidas de unión al borde (Efecto Notch)
    NotchCorner {
        id: dockCornerLeft
        side: "left"
        fill: dock.dockBgColor
        r: dock.cornerFilletR
        anchors.bottom: parent.bottom
        anchors.right: capsule.left
        anchors.rightMargin: -1
        transform: Scale {
            origin.y: dock.cornerFilletR / 2
            yScale: -1
        }
    }

    NotchCorner {
        id: dockCornerRight
        side: "right"
        fill: dock.dockBgColor
        r: dock.cornerFilletR
        anchors.bottom: parent.bottom
        anchors.left: capsule.right
        anchors.leftMargin: -1
        transform: Scale {
            origin.y: dock.cornerFilletR / 2
            yScale: -1
        }
    }
}
