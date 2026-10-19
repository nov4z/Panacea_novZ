import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Dock (macOS). Configuración de la barra inferior estilo macOS centrada con el notch:
// visibilidad, auto-ocultación, tamaño de iconos, ampliación (zoom) y gestión de aplicaciones fijadas.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    // Lista de apps por defecto si la configuración está vacía
    readonly property string defaultAppsStr: "brave-origin.desktop,kitty.desktop,com.spotify.Client.desktop,thunar.desktop"

    // Parseo de la lista de apps fijadas
    readonly property var pinnedApps: {
        var raw = String(page.sys && page.sys.cfg && page.sys.cfg.dockApps !== undefined
                         ? page.sys.cfg.dockApps : page.defaultAppsStr);
        return raw.split(",").map(x => x.trim()).filter(x => x.length > 0);
    }

    function saveApps(arr) {
        if (!page.sys || !page.sys.cfg) return;
        page.sys.cfg.dockApps = arr.join(",");
        page.sys.saveCfg();
    }

    function moveApp(from, to) {
        if (to < 0 || to >= pinnedApps.length || from === to) return;
        var a = pinnedApps.slice();
        var item = a.splice(from, 1)[0];
        a.splice(to, 0, item);
        saveApps(a);
    }

    function removeApp(idx) {
        if (idx < 0 || idx >= pinnedApps.length) return;
        var a = pinnedApps.slice();
        a.splice(idx, 1);
        saveApps(a);
    }

    function addApp(id) {
        if (!id || pinnedApps.indexOf(id) >= 0) return;
        var a = pinnedApps.slice();
        a.push(id);
        saveApps(a);
    }

    function resetDefaults() {
        saveApps(defaultAppsStr.split(","));
    }

    // Búsqueda de información de la app a partir de su ID o nombre
    function resolveAppInfo(appId) {
        if (appId === "panacea:settings") {
            return {
                id: "panacea:settings",
                name: page.sys.tr("Ajustes de Panacea"),
                icon: "",
                glyph: "󰒓",
                isBuiltin: true
            };
        }
        if (appId === "panacea:launcher") {
            return {
                id: "panacea:launcher",
                name: page.sys.tr("Lanzador de Apps"),
                icon: "",
                glyph: "󰀻",
                isBuiltin: true
            };
        }
        if (appId === "panacea:overview") {
            return {
                id: "panacea:overview",
                name: page.sys.tr("Vista General"),
                icon: "",
                glyph: "󰕰",
                isBuiltin: true
            };
        }

        var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        var cleanId = appId.replace(/\.desktop$/, "").toLowerCase();

        for (var i = 0; i < all.length; i++) {
            var a = all[i];
            if (!a) continue;
            var aid = String(a.id || "").replace(/\.desktop$/, "").toLowerCase();
            if (aid === cleanId || String(a.id || "").toLowerCase() === appId.toLowerCase()) {
                return {
                    id: a.id,
                    name: a.name || cleanId,
                    icon: a.icon || "",
                    glyph: "",
                    isBuiltin: false
                };
            }
        }

        // Fallback por nombre si no coincidió el id
        for (var j = 0; j < all.length; j++) {
            var b = all[j];
            if (!b) continue;
            if (String(b.name || "").toLowerCase() === cleanId) {
                return {
                    id: b.id,
                    name: b.name,
                    icon: b.icon || "",
                    glyph: "",
                    isBuiltin: false
                };
            }
        }

        return {
            id: appId,
            name: cleanId.charAt(0).toUpperCase() + cleanId.slice(1),
            icon: appId,
            glyph: "",
            isBuiltin: false
        };
    }

    // ------------------------------------------------------------- 1. Interruptores principales
    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Habilitar Dock inferior")
            sub: page.sys.tr("Barra de iconos centrada con el notch superior. Atajo Super+A para alternar.")
            on: page.sys.cfg.dockEnabled !== false
            onToggled: v => { page.sys.cfg.dockEnabled = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Ocultar automáticamente (Auto-hide)")
            sub: page.sys.tr("El Dock se desliza fuera de pantalla y reaparece al acercar el puntero.")
            on: !!page.sys.cfg.dockAutoHide
            onToggled: v => { page.sys.cfg.dockAutoHide = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Efecto de ampliación (Magnification)")
            sub: page.sys.tr("Aumenta fluidamente el tamaño de los iconos adyacentes al pasar el ratón.")
            on: page.sys.cfg.dockMagnify !== false
            onToggled: v => { page.sys.cfg.dockMagnify = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Animar apertura de aplicaciones (Rebote elástico)")
            sub: page.sys.tr("El icono rebota con física elástica al hacer clic para abrir la app.")
            on: page.sys.cfg.dockBounce !== false
            onToggled: v => { page.sys.cfg.dockBounce = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Indicador de aplicaciones abiertas")
            sub: page.sys.tr("Muestra un punto luminoso debajo de las apps que tienen ventanas activas.")
            on: page.sys.cfg.dockShowRunning !== false
            onToggled: v => { page.sys.cfg.dockShowRunning = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- 2. Geometría y Zoom
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Tamaño y Animación") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Tamaño base de iconos")
            from: 24
            to: 48
            step: 2
            value: page.sys.cfg.dockIconSize || 34
            suffix: "px"
            onMoved: v => { page.sys.cfg.dockIconSize = Math.round(v); page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Escala de ampliación al pasar el cursor")
            from: 1.10
            to: 1.40
            step: 0.02
            decimals: 2
            value: page.sys.cfg.dockZoom || 1.22
            suffix: "x"
            onMoved: v => { page.sys.cfg.dockZoom = parseFloat(v.toFixed(2)); page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- 3. Apps fijadas actualmente
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            SetLabel { sys: page.sys; text: page.sys.tr("Aplicaciones fijadas en el Dock") }
            Item { Layout.fillWidth: true }
            SetButton {
                sys: page.sys
                text: page.sys.tr("Restablecer")
                onClicked: page.resetDefaults()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Usa las flechas para reordenar las aplicaciones o el botón X para retirarlas del Dock.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: page.pinnedApps

                Rectangle {
                    id: appRow
                    required property string modelData
                    required property int index

                    readonly property var info: page.resolveAppInfo(modelData)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    color: rowMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)
                                               : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.035)
                    border.width: 1
                    border.color: rowMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.3)
                                                      : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: rowMa }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Icono
                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            Image {
                                anchors.fill: parent
                                source: appRow.info.icon ? Quickshell.iconPath(appRow.info.icon, true) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appRow.info.icon || appRow.info.glyph.length > 0
                                text: appRow.info.glyph || "󰣆"
                                color: page.sys.colOn
                                font { family: page.sys.fontFam; pixelSize: 18 }
                            }
                        }

                        // Nombre e ID
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: appRow.info.name
                                color: page.sys.colFg
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                                elide: Text.ElideRight
                            }

                            Text {
                                text: appRow.modelData
                                color: page.sys.colMuted
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                                elide: Text.ElideRight
                            }
                        }

                        // Botón Subir (󰁞)
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            color: btnUpMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12) : "transparent"
                            opacity: appRow.index > 0 ? 1 : 0.25

                            Text {
                                anchors.centerIn: parent
                                text: "󰁞"
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: 14 }
                            }

                            MouseArea {
                                id: btnUpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: appRow.index > 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.moveApp(appRow.index, appRow.index - 1)
                            }
                        }

                        // Botón Bajar (󰁆)
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            color: btnDnMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12) : "transparent"
                            opacity: appRow.index < page.pinnedApps.length - 1 ? 1 : 0.25

                            Text {
                                anchors.centerIn: parent
                                text: "󰁆"
                                color: page.sys.colFg
                                font { family: page.sys.fontFam; pixelSize: 14 }
                            }

                            MouseArea {
                                id: btnDnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: appRow.index < page.pinnedApps.length - 1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.moveApp(appRow.index, appRow.index + 1)
                            }
                        }

                        // Botón Quitar (󰅖)
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            color: btnRmMa.containsMouse ? Qt.rgba(page.sys.colBattCrit.r, page.sys.colBattCrit.g, page.sys.colBattCrit.b, 0.25) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: btnRmMa.containsMouse ? page.sys.colBattCrit : page.sys.colMuted
                                font { family: page.sys.fontFam; pixelSize: 13 }
                            }

                            MouseArea {
                                id: btnRmMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.removeApp(appRow.index)
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- 4. Selector de nuevas apps
    SetCard {
        id: addAppCard
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Añadir aplicación al Dock") }

        property string searchFilter: ""

        // Campo de búsqueda de aplicaciones
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06)
            border.width: 1
            border.color: searchAppInput.activeFocus ? page.sys.colOn : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "󰍉"
                    color: page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: 14 }
                }

                TextField {
                    id: searchAppInput
                    Layout.fillWidth: true
                    placeholderText: page.sys.tr("Buscar aplicación por nombre...")
                    placeholderTextColor: page.sys.colMuted
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                    background: null
                    onTextChanged: addAppCard.searchFilter = text.trim().toLowerCase()
                }

                Rectangle {
                    visible: searchAppInput.text.length > 0
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: page.sys.colFg
                        font { family: page.sys.fontFam; pixelSize: 9 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchAppInput.text = ""
                    }
                }
            }
        }

        // Lista filtrada de aplicaciones instaladas disponibles
        readonly property var availableApps: {
            var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
            var q = addAppCard.searchFilter;
            var out = [];
            var pinned = page.pinnedApps.map(x => x.replace(/\.desktop$/, "").toLowerCase());

            // Añadir acciones especiales integradas si no están fijadas
            if (pinned.indexOf("panacea:settings") < 0) {
                out.push({ id: "panacea:settings", name: page.sys.tr("Ajustes de Panacea"), icon: "", glyph: "󰒓" });
            }
            if (pinned.indexOf("panacea:launcher") < 0) {
                out.push({ id: "panacea:launcher", name: page.sys.tr("Lanzador de Apps"), icon: "", glyph: "󰀻" });
            }
            if (pinned.indexOf("panacea:overview") < 0) {
                out.push({ id: "panacea:overview", name: page.sys.tr("Vista General"), icon: "", glyph: "󰕰" });
            }

            for (var i = 0; i < all.length; i++) {
                var a = all[i];
                if (!a || a.noDisplay) continue;
                var cleanId = String(a.id || "").replace(/\.desktop$/, "").toLowerCase();
                if (pinned.indexOf(cleanId) >= 0 || pinned.indexOf(String(a.id || "").toLowerCase()) >= 0) continue;

                var name = String(a.name || "");
                if (q.length > 0) {
                    if (name.toLowerCase().indexOf(q) < 0 && cleanId.indexOf(q) < 0) continue;
                }
                out.push({
                    id: a.id,
                    name: name,
                    icon: a.icon || "",
                    glyph: ""
                });
                if (out.length >= 15) break; // Límite razonable para rendimiento
            }
            return out;
        }

        // Indicador si no hay resultados
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            visible: addAppCard.availableApps.length === 0
            text: addAppCard.searchFilter.length > 0
                  ? page.sys.tr("No se encontraron aplicaciones coincidentes.")
                  : page.sys.tr("Todas las aplicaciones disponibles ya están fijadas.")
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: addAppCard.availableApps

                Rectangle {
                    id: availRow
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    color: availMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06) : "transparent"

                    HoverHandler { id: availMa }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Image {
                                anchors.fill: parent
                                source: availRow.modelData.icon ? Quickshell.iconPath(availRow.modelData.icon, true) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !availRow.modelData.icon || availRow.modelData.glyph.length > 0
                                text: availRow.modelData.glyph || "󰣆"
                                color: page.sys.colOn
                                font { family: page.sys.fontFam; pixelSize: 15 }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: availRow.modelData.name
                            color: page.sys.colFg
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: addBtnText.implicitWidth + 16
                            Layout.preferredHeight: 26
                            radius: 8
                            color: addBtnMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.3)
                                                          : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.15)
                            border.width: 1
                            border.color: page.sys.colOn

                            Text {
                                id: addBtnText
                                anchors.centerIn: parent
                                text: "+ " + page.sys.tr("Añadir")
                                color: page.sys.colFg
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                            }

                            MouseArea {
                                id: addBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.addApp(availRow.modelData.id);
                                    searchAppInput.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
