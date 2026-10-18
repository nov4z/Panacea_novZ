import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Explorador de archivos Nothing OS para Panacea (Super + E).
// Diseñado con la misma estética, proporciones y fluidez que SettingsView (Super + I).
Item {
    id: view

    property var sys
    property bool windowMode: false
    property int  windowId: 0

    function leave() {
        if (view.windowMode) view.sys.closeFilesWindow(view.windowId);
        else                 view.sys.collapse();
    }

    implicitWidth: 1140
    implicitHeight: view.windowMode ? view.height : 780

    // ------------------------------------------------------------ estado y navegación
    property string dir: ""
    property int current: 0
    property string filter: ""
    property string sortBy: "name"
    property bool   sortDesc: false
    property bool   foldersFirst: true
    property string status: ""

    // Historial de navegación (Atrás / Adelante)
    property var dirHist: []
    property int dirHistAt: -1
    readonly property bool canBack: dirHistAt > 0
    readonly property bool canForward: dirHistAt >= 0 && dirHistAt < dirHist.length - 1
    readonly property bool canUp: view.dir !== "/" && view.dir.length > 0

    function go(path, record) {
        if (!path || path.length === 0) return;
        var rec = (record === undefined) ? true : record;
        if (rec) {
            var h = view.dirHist.slice(0, view.dirHistAt + 1);
            h.push(path);
            view.dirHist = h;
            view.dirHistAt = h.length - 1;
        }
        view.filter = "";
        view.dir = path;
        view.openWithFile = "";
        view.clearSelection();
        view.reload();
    }

    function navBack() {
        if (view.canBack) {
            view.dirHistAt--;
            view.go(view.dirHist[view.dirHistAt], false);
        }
    }

    function navForward() {
        if (view.canForward) {
            view.dirHistAt++;
            view.go(view.dirHist[view.dirHistAt], false);
        }
    }

    function up() {
        if (view.dir === "/" || !view.dir.length) return;
        var p = view.dir.replace(/\/+$/, "");
        var i = p.lastIndexOf("/");
        var parentPath = (i <= 0 ? "/" : p.slice(0, i));
        view.go(parentPath, true);
    }

    // Migas de pan interactivas
    function computeBreadcrumbs(path) {
        var home = Quickshell.env("HOME") || "";
        var res = [];
        if (!path || path === "/") {
            return [{ label: "/", path: "/" }];
        }
        if (home.length > 0 && path.indexOf(home) === 0) {
            res.push({ label: "~", path: home });
            var rel = path.substring(home.length).replace(/^\/+/, "");
            if (rel.length > 0) {
                var parts = rel.split("/");
                var cur = home;
                for (var i = 0; i < parts.length; i++) {
                    if (!parts[i].length) continue;
                    cur += "/" + parts[i];
                    res.push({ label: parts[i], path: cur });
                }
            }
        } else {
            res.push({ label: "/", path: "/" });
            var parts2 = path.replace(/^\/+/, "").split("/");
            var cur2 = "";
            for (var j = 0; j < parts2.length; j++) {
                if (!parts2[j].length) continue;
                cur2 += "/" + parts2[j];
                res.push({ label: parts2[j], path: cur2 });
            }
        }
        return res;
    }

    readonly property var breadcrumbs: computeBreadcrumbs(view.dir)

    // Modo de vista: "list" | "grid"
    readonly property string mode: view.sys.cfg.filesMode === "grid" ? "grid" : "list"
    function setMode(m) {
        if (view.mode === m) return;
        view.sys.cfg.filesMode = m;
        view.sys.saveCfg();
    }

    readonly property int gridCell: 120
    readonly property int gridCols: Math.max(1, Math.floor(contentArea.width > 0 ? contentArea.width / view.gridCell : 4))

    // Selección múltiple
    property var    selectedPaths: []
    readonly property int selectedCount: selectedPaths.length
    property int    anchorIndex: -1

    // Portapapeles
    property var    clipPaths: []
    property string clipPath: clipPaths.length ? clipPaths[0] : ""
    property string clipMode: "" // "copy" | "cut"

    // Menú contextual y modales
    property bool   menuOpen: false
    property string menuPath: ""
    property bool   menuIsDir: false
    property string menuKind: "folder"
    property real   menuX: 0
    property real   menuY: 0

    property string dialogMode: "" // "rename" | "mkdir"
    property string openWithFile: ""
    property bool   propsOpen: false
    property var    propsData: ({})
    property string propsPath: ""

    // Modelos
    ListModel { id: entries }
    ListModel { id: rawEntries }
    ListModel { id: places }
    ListModel { id: disks }
    ListModel { id: removables }
    ListModel { id: apps }

    readonly property string scripts: view.sys.scriptDir + "/files.sh"

    focus: true
    Component.onCompleted: {
        if (!view.dir.length && view.sys.filesStartDir.length) {
            view.dir = view.sys.filesStartDir;
            view.sys.filesStartDir = "";
        }
        if (!view.dir.length) view.dir = view.sys.filesDir || Quickshell.env("HOME") || "/";
        view.dirHist = [view.dir];
        view.dirHistAt = 0;
        forceActiveFocus();
        loadPlaces();
        reload();
    }

    // ---------------------------------------------------------------- procesos
    Process {
        id: pList
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 5) return;
                rawEntries.append({
                    eType: p[0], eName: p[1],
                    eSize: parseInt(p[2]) || 0,
                    eTime: parseInt(p[3]) || 0,
                    eMime: p[4]
                });
            }
        }
        onRunningChanged: {
            if (running) {
                rawEntries.clear();
            } else {
                view.applyFilter();
            }
        }
    }

    Process {
        id: pPlaces
        command: ["sh", "-c", view.scripts + " places"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                places.append({ pKey: p[0], pPath: p[1], pLabel: p[2] });
            }
        }
    }

    Process {
        id: pApps
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                apps.append({ aFile: p[0], aName: p[1], aIcon: p[2] });
            }
        }
    }

    property var opQueue: []
    Process {
        id: pAction
        onRunningChanged: {
            if (running) return;
            if (view.opQueue.length > 0) {
                var q = view.opQueue.slice();
                var next = q.shift();
                view.opQueue = q;
                view.startOp(next.args, next.note);
                return;
            }
            view.reload();
            view.countTrash();
            view.selfChange = true;
            view.sys.filesChanged();
            view.selfChange = false;
        }
    }
    property bool selfChange: false
    Connections {
        target: view.sys
        ignoreUnknownSignals: true
        function onFilesChanged() {
            if (view.selfChange || pAction.running) return;
            view.reload();
        }
    }

    property int trashCount: 0
    readonly property string trashDir:
        (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Trash/files"
    readonly property bool inTrash: view.dir === view.trashDir

    Process {
        id: pTrashCount
        command: ["sh", "-c", view.scripts + " trashcount"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: view.trashCount = parseInt(text.trim()) || 0
        }
    }

    Process {
        id: pDisks
        command: ["sh", "-c", view.scripts + " disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var d = [], r = [];
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|");
                    if (p.length < 6) continue;
                    var row = {
                        dPath: p[1], dLabel: p[2],
                        dSize: parseFloat(p[3]) || 0,
                        dUsed: parseFloat(p[4]) || 0,
                        dDev: p[5]
                    };
                    if (p[0] === "removable") r.push(row); else d.push(row);
                }
                view.syncDisks(disks, d);
                view.syncDisks(removables, r);
            }
        }
    }

    Process {
        id: pMount
        property string targetDev: ""
        command: ["sh", "-c", view.scripts + " mountdisk " + JSON.stringify(targetDev)]
        stdout: StdioCollector {
            onStreamFinished: {
                var mp = text.trim();
                view.reloadDisks();
                if (mp.length > 0) view.go(mp);
            }
        }
    }
    function mountDisk(dev) {
        if (!dev || !dev.length) return;
        pMount.targetDev = dev;
        pMount.running = false;
        pMount.running = true;
    }

    Process {
        id: pEject
        property string targetItem: ""
        command: ["sh", "-c", view.scripts + " ejectdisk " + JSON.stringify(targetItem)]
        stdout: StdioCollector {
            onStreamFinished: {
                view.reloadDisks();
                if (pEject.targetItem.length > 0 && view.dir.indexOf(pEject.targetItem) === 0) {
                    view.go(view.sys.home);
                }
            }
        }
    }
    function ejectDisk(dev, path) {
        pEject.targetItem = path && path.length > 0 ? path : dev;
        pEject.running = false;
        pEject.running = true;
    }

    function syncDisks(model, rows) {
        if (model.count !== rows.length) {
            model.clear();
            for (var i = 0; i < rows.length; i++) model.append(rows[i]);
            return;
        }
        for (var j = 0; j < rows.length; j++) {
            var cur = model.get(j);
            if (cur.dDev !== rows[j].dDev || cur.dPath !== rows[j].dPath || cur.dLabel !== rows[j].dLabel) {
                model.set(j, rows[j]);
                continue;
            }
            if (cur.dUsed !== rows[j].dUsed) model.setProperty(j, "dUsed", rows[j].dUsed);
            if (cur.dSize !== rows[j].dSize) model.setProperty(j, "dSize", rows[j].dSize);
        }
    }
    function reloadDisks() { pDisks.running = false; pDisks.running = true; }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: view.reloadDisks()
    }

    function human(b) {
        if (!b || b <= 0) return "";
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i < 2 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function countTrash() { pTrashCount.running = false; pTrashCount.running = true; }
    function emptyTrash() {
        closeMenu();
        run(["sh", "-c", view.scripts + " emptytrash"], view.sys.tr("Papelera vaciada"));
    }
    function loadPlaces() {
        places.clear();
        pPlaces.running = false;
        pPlaces.running = true;
    }

    // Recarga atómica: no vacía `entries` antes de tiempo para evitar rebotes de tamaño
    function reload() {
        pList.command = ["sh", "-c", view.scripts + " list \"$1\" \"$2\"", "_", view.dir,
                         view.sys.cfg.filesHidden ? "hidden" : ""];
        pList.running = false;
        pList.running = true;
        view.sys.filesDir = view.dir;
    }

    function applyFilter() {
        entries.clear();
        var f = view.filter.toLowerCase();
        var rows = [];
        for (var i = 0; i < rawEntries.count; i++) {
            var e = rawEntries.get(i);
            if (f.length && e.eName.toLowerCase().indexOf(f) < 0) continue;
            rows.push({ eType: e.eType, eName: e.eName, eSize: e.eSize,
                        eTime: e.eTime, eMime: e.eMime });
        }
        rows.sort(view.compare);
        for (var j = 0; j < rows.length; j++) entries.append(rows[j]);
        view.current = 0;
    }

    function compare(a, b) {
        if (view.foldersFirst && a.eType !== b.eType)
            return a.eType === "d" ? -1 : 1;

        var r = 0;
        if (view.sortBy === "time") r = a.eTime - b.eTime;
        else if (view.sortBy === "size") r = a.eSize - b.eSize;
        else if (view.sortBy === "type") {
            var ea = view.extOf(a), eb = view.extOf(b);
            r = ea < eb ? -1 : ea > eb ? 1 : 0;
        }
        if (r === 0) {
            var na = a.eName.toLowerCase(), nb = b.eName.toLowerCase();
            r = na < nb ? -1 : na > nb ? 1 : 0;
            if (view.sortBy !== "name") return r;
        }
        return view.sortDesc ? -r : r;
    }

    function extOf(e) {
        if (e.eType === "d") return "";
        var i = e.eName.lastIndexOf(".");
        return i > 0 ? e.eName.substring(i + 1).toLowerCase() : "";
    }

    function setSort(k) {
        if (view.sortBy === k) view.sortDesc = !view.sortDesc;
        else { view.sortBy = k; view.sortDesc = (k === "time" || k === "size"); }
        view.applyFilter();
    }

    function timeText(e) {
        if (!e.eTime) return "";
        var d = new Date(e.eTime * 1000);
        var now = new Date();
        var fmt = d.getFullYear() === now.getFullYear() ? "d MMM, hh:mm" : "d MMM yyyy";
        return Qt.formatDateTime(d, fmt);
    }

    function isMedia(e) {
        var m = String(e.eMime || "");
        return m.indexOf("image/") === 0 || m.indexOf("video/") === 0;
    }

    function activate(i) {
        if (i < 0 || i >= entries.count) return;
        var e = entries.get(i);
        var full = (view.dir === "/" ? "" : view.dir) + "/" + e.eName;
        if (e.eType === "d") {
            if (view.sys && view.sys.playSound) view.sys.playSound("tock");
            view.go(full, true);
            return;
        }
        if (view.sys.wallpaperPickMode) {
            var m = String(e.eMime);
            if (m.indexOf("image/") === 0) { view.sys.finishWallpaperPick(full); return; }
        }
        if (view.isMedia(e)) { view.sys.openMedia(full); return; }
        view.openWithFile = full;
        apps.clear();
        pApps.command = ["sh", "-c", view.scripts + " apps \"$1\"", "_", full];
        pApps.running = false;
        pApps.running = true;
    }

    function openWith(desktopFile) {
        if (!view.openWithFile.length) return;
        view.sys.openFileWith(view.openWithFile, desktopFile || "");
        view.openWithFile = "";
        view.leave();
    }

    function trashCurrent() {
        if (view.current < 0 || view.current >= entries.count) return;
        var e = entries.get(view.current);
        var full = (view.dir === "/" ? "" : view.dir) + "/" + e.eName;
        view.status = view.sys.tr("A papelera: ") + e.eName;
        statusClear.restart();
        pAction.command = ["sh", "-c", view.scripts + " trash \"$1\"", "_", full];
        pAction.running = true;
    }
    Timer { id: statusClear; interval: 2600; onTriggered: view.status = "" }
    function say(msg) { view.status = msg; statusClear.restart(); }

    function fullPath(name) {
        return (view.dir === "/" ? "" : view.dir) + "/" + name;
    }
    function currentPath() {
        if (view.current < 0 || view.current >= entries.count) return "";
        return view.fullPath(entries.get(view.current).eName);
    }
    function baseName(p) { return String(p).split("/").pop(); }

    function placeLabel(key, fallback) {
        switch (key) {
            case "home":      return view.sys.tr("Carpeta personal");
            case "downloads": return view.sys.tr("Descargas");
            case "documents": return view.sys.tr("Documentos");
            case "pictures":  return view.sys.tr("Imágenes");
            case "videos":    return view.sys.tr("Vídeos");
            case "music":     return view.sys.tr("Música");
            case "desktop":   return view.sys.tr("Escritorio");
            case "trash":     return view.sys.tr("Papelera");
            case "root":      return view.sys.tr("Sistema de archivos");
        }
        return fallback;
    }

    function startOp(args, note) {
        pAction.command = args;
        pAction.running = true;
        if (note !== undefined) view.say(note);
    }
    function run(args, note) {
        if (pAction.running) {
            var q = view.opQueue.slice();
            q.push({ args: args, note: note });
            view.opQueue = q;
            if (note !== undefined) view.say(note);
            return;
        }
        view.startOp(args, note);
    }
    function runLong(args, note, label) {
        view.sys.runFileOp(args, label);
        if (note !== undefined) view.say(note);
    }

    // --------------------------------------------------------- menú contextual
    function openMenu(path, isDir, x, y, kind) {
        view.menuPath = path;
        view.menuIsDir = isDir;
        view.menuKind = kind !== undefined ? kind : (path.length ? "file" : "folder");
        view.menuX = Math.max(10, Math.min(x, view.width - 220));
        view.menuY = Math.max(10, Math.min(y, Math.max(0, view.height - 280)));
        view.menuOpen = true;
    }
    function closeMenu() { view.menuOpen = false; }

    function doOpen(path) {
        if (!path.length) return;
        closeMenu();
        for (var i = 0; i < entries.count; i++) {
            if (view.fullPath(entries.get(i).eName) === path) { view.activate(i); return; }
        }
    }
    function doOpenWith(path) {
        if (!path.length) return;
        closeMenu();
        view.openWithFile = path;
        apps.clear();
        pApps.command = ["sh", "-c", view.scripts + " apps \"$1\"", "_", path];
        pApps.running = false;
        pApps.running = true;
    }

    // Selección
    function isSelected(path) { return view.selectedPaths.indexOf(path) !== -1; }
    function toggleSelection(path, idx) {
        var copy = view.selectedPaths.slice();
        var i = copy.indexOf(path);
        if (i !== -1) copy.splice(i, 1);
        else copy.push(path);
        view.selectedPaths = copy;
        if (idx !== undefined) view.anchorIndex = idx;
    }
    function selectSingle(path, idx) {
        view.selectedPaths = [path];
        if (idx !== undefined) view.anchorIndex = idx;
    }
    function selectRange(targetIdx) {
        if (view.anchorIndex < 0) view.anchorIndex = view.current;
        var start = Math.min(view.anchorIndex, targetIdx);
        var end = Math.max(view.anchorIndex, targetIdx);
        var res = [];
        for (var i = start; i <= end; i++) {
            if (i >= 0 && i < entries.count) {
                res.push(view.fullPath(entries.get(i).eName));
            }
        }
        view.selectedPaths = res;
    }
    function selectAll() {
        var res = [];
        for (var i = 0; i < entries.count; i++) {
            res.push(view.fullPath(entries.get(i).eName));
        }
        view.selectedPaths = res;
    }
    function clearSelection() {
        view.selectedPaths = [];
        view.anchorIndex = -1;
    }
    function updateSelectionByRect(rx, ry, rw, rh) {
        var rectX2 = rx + rw;
        var rectY2 = ry + rh;
        var matched = [];
        if (view.mode === "list") {
            var rowH = 40;
            var scrollY = list.contentY;
            for (var i = 0; i < entries.count; i++) {
                var itemY = i * rowH - scrollY;
                var itemY2 = itemY + rowH;
                if (itemY2 >= ry && itemY <= rectY2) {
                    matched.push(view.fullPath(entries.get(i).eName));
                }
            }
        } else {
            var cols = view.gridCols;
            var cellW = grid.cellWidth;
            var cellH = grid.cellHeight;
            var scrollY2 = grid.contentY;
            for (var j = 0; j < entries.count; j++) {
                var colIdx = j % cols;
                var rowIdx = Math.floor(j / cols);
                var itemX = colIdx * cellW;
                var itemX2 = itemX + cellW;
                var itemY3 = rowIdx * cellH - scrollY2;
                var itemY4 = itemY3 + cellH;
                if (itemX2 >= rx && itemX <= rectX2 && itemY4 >= ry && itemY3 <= rectY2) {
                    matched.push(view.fullPath(entries.get(j).eName));
                }
            }
        }
        view.selectedPaths = matched;
    }

    // Acciones de archivos
    function doCopy(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        view.clipPaths = targets;
        view.clipMode = "copy";
        closeMenu();
        view.say(targets.length === 1 ? (view.sys.tr("Copiado: ") + view.baseName(targets[0]))
                                      : (view.sys.tr("Copiados archivos: ") + targets.length));
    }
    function doCut(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        view.clipPaths = targets;
        view.clipMode = "cut";
        closeMenu();
        view.say(targets.length === 1 ? (view.sys.tr("Cortado: ") + view.baseName(targets[0]))
                                      : (view.sys.tr("Cortados archivos: ") + targets.length));
    }
    function doPaste() {
        if (!view.clipPaths.length) return;
        var op = view.clipMode === "cut" ? "move" : "copy";
        closeMenu();
        var label = view.clipPaths.length === 1 ? view.baseName(view.clipPaths[0])
                                               : (view.clipPaths.length + " " + view.sys.tr("archivos"));
        var note = (view.clipMode === "cut" ? view.sys.tr("Movido: ")
                                            : view.sys.tr("Pegado: ")) + label;
        var cmd = ["sh", "-c", view.scripts + " " + op + " \"$1\" \"keepboth\" \"${@:2}\"", "_", view.dir];
        cmd = cmd.concat(view.clipPaths);
        runLong(cmd, note, label);
        if (view.clipMode === "cut") { view.clipPaths = []; view.clipMode = ""; }
    }
    function doCopyPath(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        closeMenu();
        var text = targets.join("\n");
        run(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", text],
            view.sys.tr("Ruta copiada"));
    }
    function doTrash(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        closeMenu();
        var cmd = ["sh", "-c", view.scripts + " trash \"$@\"", "_"].concat(targets);
        var label = targets.length === 1 ? view.baseName(targets[0])
                                         : (targets.length + " " + view.sys.tr("archivos"));
        run(cmd, view.sys.tr("A papelera: ") + label);
        view.clearSelection();
    }

    // Propiedades
    function showProps(path) {
        closeMenu();
        view.propsPath = path;
        view.propsData = ({});
        pProps.command = ["sh", "-c", view.sys.scriptDir + "/props.sh \"$1\"", "_", path];
        pProps.running = true;
        view.propsOpen = true;
    }
    Process {
        id: pProps
        stdout: StdioCollector {
            onStreamFinished: {
                var o = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var t = lines[i].split("\t");
                    if (t.length >= 2) o[t[0]] = t.slice(1).join("\t");
                }
                view.propsData = o;
            }
        }
    }
    function fmtDuration(sec) {
        var s = Math.floor(parseFloat(sec) || 0);
        var h = Math.floor(s / 3600); s -= h * 3600;
        var m = Math.floor(s / 60); s -= m * 60;
        var p2 = function (n) { return n < 10 ? "0" + n : "" + n; };
        return (h > 0 ? h + ":" + p2(m) : m) + ":" + p2(s);
    }

    // Diálogos de renombrado y nueva carpeta
    function startRename(path) {
        closeMenu();
        view.menuPath = path;
        view.dialogMode = "rename";
        dialogField.text = view.baseName(path);
        dialogField.selectAll();
        dialogFocus.restart();
    }
    function startMkdir() {
        closeMenu();
        view.dialogMode = "mkdir";
        dialogField.text = view.sys.tr("Nueva carpeta");
        dialogField.selectAll();
        dialogFocus.restart();
    }
    function confirmDialog() {
        var name = dialogField.text.trim();
        var mode = view.dialogMode;
        view.dialogMode = "";
        view.forceActiveFocus();
        if (!name.length) return;
        if (mode === "rename")
            run(["sh", "-c", view.scripts + " rename \"$1\" \"$2\"", "_", view.menuPath, name],
                view.sys.tr("Renombrado"));
        else if (mode === "mkdir")
            run(["sh", "-c", view.scripts + " mkdir \"$1\" \"$2\"", "_", view.dir, name],
                view.sys.tr("Carpeta creada"));
    }
    function cancelDialog() {
        view.dialogMode = "";
        view.forceActiveFocus();
    }
    Timer { id: dialogFocus; interval: 40; onTriggered: dialogField.forceActiveFocus() }

    // Teclado
    Keys.onEscapePressed: {
        if (view.dialogMode.length) { view.cancelDialog(); return; }
        if (view.propsOpen) { view.propsOpen = false; return; }
        if (view.menuOpen) { view.closeMenu(); return; }
        if (view.selectedCount > 0) { view.clearSelection(); return; }
        if (view.openWithFile.length) { view.openWithFile = ""; return; }
        if (view.filter.length) { view.filter = ""; applyFilter(); return; }
        view.leave();
    }
    function step(delta) {
        var n = entries.count;
        if (n === 0) return;
        view.current = Math.max(0, Math.min(n - 1, view.current + delta));
    }
    Keys.onUpPressed:    view.openWithFile.length ? appList.step(-1)
                       : view.step(view.mode === "grid" ? -view.gridCols : -1)
    Keys.onDownPressed:  view.openWithFile.length ? appList.step(1)
                       : view.step(view.mode === "grid" ?  view.gridCols :  1)
    Keys.onLeftPressed:  if (view.mode === "grid") view.step(-1)
    Keys.onRightPressed: if (view.mode === "grid") view.step(1)
    Keys.onReturnPressed: view.openWithFile.length ? view.openWith(appList.currentFile())
                                                   : view.activate(view.current)
    Keys.onEnterPressed:  view.openWithFile.length ? view.openWith(appList.currentFile())
                                                   : view.activate(view.current)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Backspace) {
            if (view.filter.length) {
                view.filter = view.filter.slice(0, -1);
                applyFilter();
            } else {
                view.up();
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Delete) {
            if (view.selectedCount > 0) {
                view.doTrash("");
            } else {
                view.trashCurrent();
            }
            event.accepted = true;
            return;
        }
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_A) { view.selectAll(); event.accepted = true; return; }
            var p = view.currentPath();
            if (event.key === Qt.Key_C) { view.doCopy(p); event.accepted = true; return; }
            if (event.key === Qt.Key_X) { view.doCut(p); event.accepted = true; return; }
            if (event.key === Qt.Key_V) { view.doPaste(); event.accepted = true; return; }
            if (event.key === Qt.Key_N) { view.startMkdir(); event.accepted = true; return; }
            return;
        }
        if (event.key === Qt.Key_F2) {
            var r = view.currentPath();
            if (r.length) view.startRename(r);
            event.accepted = true;
            return;
        }
        if (event.text.length === 1 && event.text >= " ") {
            view.filter += event.text;
            applyFilter();
            event.accepted = true;
        }
    }

    // Iconografía y paleta Nothing OS por categoría
    function iconColorFor(e) {
        if (e.eType === "d") return view.sys.colOn; // Nothing Red
        var m = String(e.eMime || "");
        if (m.indexOf("image/") === 0) return "#64d2ff"; // Cyan
        if (m.indexOf("video/") === 0) return "#bf5af2"; // Purple
        if (m.indexOf("audio/") === 0) return "#30d158"; // Green
        if (m === "application/pdf" || m.indexOf("text/pdf") >= 0) return "#ff453a"; // Red-orange
        if (m.indexOf("text/") === 0 || m.indexOf("json") >= 0 || m.indexOf("javascript") >= 0) return "#ff9f0a"; // Orange
        if (m.indexOf("zip") >= 0 || m.indexOf("tar") >= 0 || m.indexOf("compress") >= 0 || m.indexOf("7z") >= 0) return "#ffd60a"; // Yellow
        return Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.55);
    }

    function iconFor(e) {
        if (e.eType === "d") return String.fromCodePoint(0xF024B); // folder
        var m = String(e.eMime || "");
        if (m.indexOf("image/") === 0) return String.fromCodePoint(0xF021F);
        if (m.indexOf("video/") === 0) return String.fromCodePoint(0xF022B);
        if (m.indexOf("audio/") === 0) return String.fromCodePoint(0xF0388);
        if (m === "application/pdf") return String.fromCodePoint(0xF0226);
        if (m.indexOf("text/") === 0) return String.fromCodePoint(0xF0219);
        if (m.indexOf("zip") >= 0 || m.indexOf("tar") >= 0 || m.indexOf("compress") >= 0 || m.indexOf("7z") >= 0)
            return String.fromCodePoint(0xF05C0);
        return String.fromCodePoint(0xF0224); // generic file
    }

    function sizeText(e) {
        if (e.eType === "d") return "";
        var s = e.eSize;
        if (s < 1024) return s + " B";
        if (s < 1024 * 1024) return (s / 1024).toFixed(0) + " KB";
        if (s < 1024 * 1024 * 1024) return (s / 1048576).toFixed(1) + " MB";
        return (s / 1073741824).toFixed(2) + " GB";
    }

    // =========================================================================
    // DISTRIBUCIÓN VISUAL (IDÉNTICA A SETTINGSVIEW)
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------- BARRA LATERAL (260px)
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 260
            Layout.minimumWidth: 260
            Layout.maximumWidth: 260
            Layout.fillHeight: true
            spacing: 10

            // Encabezado Nothing OS del sidebar
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                Layout.leftMargin: 10
                spacing: 8

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
                    text: "PANACEA  //  ARCHIVOS"
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.42)
                    font {
                        family: view.sys.fontBody
                        pixelSize: view.sys.fontSize - 4
                        letterSpacing: 2.2
                        bold: true
                    }
                }
            }

            // Cuadro de búsqueda Nothing OS
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
                    text: view.filter
                    onTextChanged: {
                        if (view.filter !== text) {
                            view.filter = text;
                            view.applyFilter();
                        }
                    }
                    Keys.onEscapePressed: { text = ""; view.filter = ""; view.applyFilter(); focus = false; }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: view.sys.tr("Filtrar archivos...")
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
                        onClicked: {
                            searchInput.text = "";
                            view.filter = "";
                            view.applyFilter();
                        }
                    }
                }
            }

            // Lista con Lugares y Unidades
            Flickable {
                id: sideFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: sideCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: SetScroll { sys: view.sys }

                ColumnLayout {
                    id: sideCol
                    width: sideFlick.width
                    spacing: 4

                    Text {
                        Layout.leftMargin: 10
                        Layout.topMargin: 4
                        Layout.bottomMargin: 2
                        text: "LUGARES"
                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35)
                        font {
                            family: view.sys.fontBody
                            pixelSize: view.sys.fontSize - 5
                            bold: true
                            letterSpacing: 1.5
                        }
                    }

                    Repeater {
                        model: places
                        Rectangle {
                            id: placeItem
                            required property var model
                            readonly property bool active: view.dir === placeItem.model.pPath

                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            radius: 12
                            scale: placeMa.pressed ? 0.985 : (placeMa.containsMouse ? 1.012 : 1.0)
                            color: placeItem.active
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                   : (placeMa.containsMouse
                                      ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                                      : "transparent")
                            border.width: 1
                            border.color: placeItem.active
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.38)
                                          : (placeMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                            // Indicador lateral Nothing OS
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: placeItem.active ? 20 : (placeMa.containsMouse ? 10 : 0)
                                radius: 1.5
                                color: view.sys.colOn
                                opacity: placeItem.active ? 1 : (placeMa.containsMouse ? 0.5 : 0)
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
                                    color: placeItem.active
                                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                           : (placeMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08))
                                    border.width: 1
                                    border.color: placeItem.active
                                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                                  : (placeMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14) : "transparent")
                                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                                    Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(
                                                  placeItem.model.pKey === "home" ? 0xF02DC
                                                : placeItem.model.pKey === "downloads" ? 0xF0179
                                                : placeItem.model.pKey === "pictures" ? 0xF021F
                                                : placeItem.model.pKey === "videos" ? 0xF022B
                                                : placeItem.model.pKey === "music" ? 0xF0388
                                                : placeItem.model.pKey === "documents" ? 0xF0219
                                                : placeItem.model.pKey === "desktop" ? 0xF0705
                                                : placeItem.model.pKey === "trash" ? 0xF0A79
                                                : placeItem.model.pKey === "root" ? 0xF02CA
                                                                                  : 0xF024B)
                                        color: placeItem.active ? view.sys.colOn : (placeMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: view.placeLabel(placeItem.model.pKey, placeItem.model.pLabel)
                                    color: placeItem.active ? view.sys.colFg : (placeMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1; bold: placeItem.active }
                                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                                }

                                // Badge de papelera
                                Rectangle {
                                    visible: placeItem.model.pKey === "trash" && view.trashCount > 0
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: Math.max(18, trashTxt.implicitWidth + 8)
                                    radius: 9
                                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                                    Text {
                                        id: trashTxt
                                        anchors.centerIn: parent
                                        text: String(view.trashCount)
                                        color: view.sys.colOn
                                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4; bold: true }
                                    }
                                }
                            }

                            MouseArea {
                                id: placeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton && placeItem.model.pKey === "trash") {
                                        var p = mapToItem(view, mouse.x, mouse.y);
                                        view.openMenu("", true, p.x, p.y, "trash");
                                        return;
                                    }
                                    if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                    view.go(placeItem.model.pPath);
                                }
                            }
                        }
                    }

                    // Sección UNIDADES / DISPOSITIVOS
                    Item { Layout.preferredHeight: 6 }

                    Text {
                        visible: disks.count > 0 || removables.count > 0
                        Layout.leftMargin: 10
                        Layout.topMargin: 4
                        Layout.bottomMargin: 2
                        text: "UNIDADES"
                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35)
                        font {
                            family: view.sys.fontBody
                            pixelSize: view.sys.fontSize - 5
                            bold: true
                            letterSpacing: 1.5
                        }
                    }

                    Repeater {
                        model: disks
                        Rectangle {
                            id: diskItem
                            required property var model
                            readonly property bool mounted: diskItem.model.dPath && diskItem.model.dPath.length > 0
                            readonly property bool active: mounted && view.dir === diskItem.model.dPath
                            readonly property real frac: (mounted && diskItem.model.dSize > 0)
                                                         ? diskItem.model.dUsed / diskItem.model.dSize : 0

                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            radius: 12
                            scale: dMa.pressed ? 0.985 : (dMa.containsMouse ? 1.012 : 1.0)
                            color: diskItem.active
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                   : (dMa.containsMouse
                                      ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                                      : "transparent")
                            border.width: 1
                            border.color: diskItem.active
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.38)
                                          : (dMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                            Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 6
                                anchors.bottomMargin: 6
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: String.fromCodePoint(diskItem.model.dDev === "mtp" ? 0xF011C : 0xF02CA)
                                        color: diskItem.active ? view.sys.colOn : view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: 15 }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: diskItem.model.dLabel
                                        color: diskItem.active ? view.sys.colFg : (dMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                        elide: Text.ElideRight
                                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1; bold: diskItem.active }
                                    }
                                    Text {
                                        visible: diskItem.mounted && diskItem.model.dSize > 0
                                        text: Math.round(diskItem.frac * 100) + "%"
                                        color: diskItem.frac > 0.9 ? view.sys.colCrit : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.45)
                                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 5; bold: true }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: diskItem.model.dSize > 0
                                    text: diskItem.mounted
                                          ? (view.human(diskItem.model.dUsed) + " / " + view.human(diskItem.model.dSize))
                                          : (view.human(diskItem.model.dSize) + " • " + view.sys.tr("Conectar"))
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35)
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 6 }
                                }

                                Rectangle {
                                    visible: diskItem.mounted && diskItem.model.dSize > 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 3
                                    radius: 1.5
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, diskItem.frac))
                                        height: parent.height
                                        radius: 1.5
                                        color: diskItem.frac > 0.9 ? view.sys.colCrit : view.sys.colOn
                                        Behavior on width { NumberAnimation { duration: 240 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: dMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (diskItem.mounted) {
                                        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                        view.go(diskItem.model.dPath);
                                    } else {
                                        view.mountDisk(diskItem.model.dDev);
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: removables
                        Rectangle {
                            id: remItem
                            required property var model
                            readonly property bool mounted: remItem.model.dPath && remItem.model.dPath.length > 0
                            readonly property bool active: mounted && view.dir === remItem.model.dPath
                            readonly property real frac: (mounted && remItem.model.dSize > 0)
                                                         ? remItem.model.dUsed / remItem.model.dSize : 0

                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 12
                            scale: remMa.pressed ? 0.98 : (remMa.containsMouse ? 1.015 : 1.0)
                            color: remItem.active
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                   : (remMa.containsMouse
                                      ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                                      : "transparent")
                            border.width: 1
                            border.color: remItem.active
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.38)
                                          : (remMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) : "transparent")

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 6
                                anchors.bottomMargin: 6
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: String.fromCodePoint(0xF129B)
                                        color: remItem.active ? view.sys.colOn : view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: 15 }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: remItem.model.dLabel
                                        color: remItem.active ? view.sys.colFg : (remMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                        elide: Text.ElideRight
                                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1; bold: remItem.active }
                                    }
                                    // Expulsión segura
                                    Rectangle {
                                        visible: remItem.mounted && (remMa.containsMouse || ejectMa.containsMouse)
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 6
                                        color: ejectMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "⏏"
                                            color: ejectMa.containsMouse ? view.sys.colCrit : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.7)
                                            font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                                        }
                                        MouseArea {
                                            id: ejectMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.ejectDisk(remItem.model.dDev, remItem.model.dPath)
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: remItem.model.dSize > 0
                                    text: remItem.mounted
                                          ? (view.human(remItem.model.dUsed) + " / " + view.human(remItem.model.dSize))
                                          : (view.human(remItem.model.dSize) + " • " + view.sys.tr("Conectar"))
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35)
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 6 }
                                }

                                Rectangle {
                                    visible: remItem.mounted && remItem.model.dSize > 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 3
                                    radius: 1.5
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, remItem.frac))
                                        height: parent.height
                                        radius: 1.5
                                        color: remItem.frac > 0.9 ? view.sys.colCrit : view.sys.colOn
                                        Behavior on width { NumberAnimation { duration: 240 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: remMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (remItem.mounted) {
                                        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                        view.go(remItem.model.dPath);
                                    } else {
                                        view.mountDisk(remItem.model.dDev);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------- SEPARADOR VERTICAL
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

        // ------------------------------------------------------------- ÁREA DE CONTENIDO
        ColumnLayout {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // FILA 1: Barra de navegación superior, Breadcrumbs Nothing OS y Acciones
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Botones de Historial: Atrás, Adelante, Subir
                Repeater {
                    model: [
                        { id: "back", g: 0xF004D, armed: view.canBack, action: view.navBack },
                        { id: "fwd",  g: 0xF0054, armed: view.canForward, action: view.navForward },
                        { id: "up",   g: 0xF0143, armed: view.canUp, action: view.up }
                    ]
                    Rectangle {
                        id: navBtn
                        required property var modelData
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        opacity: navBtn.modelData.armed ? 1 : 0.35
                        scale: btnMa.pressed ? 0.94 : (btnMa.containsMouse && navBtn.modelData.armed ? 1.05 : 1.0)
                        color: btnMa.containsMouse && navBtn.modelData.armed
                               ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: btnMa.containsMouse && navBtn.modelData.armed
                                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                      : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                        Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(navBtn.modelData.g)
                            color: navBtn.modelData.armed ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: navBtn.modelData.armed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                navBtn.modelData.action();
                            }
                        }
                    }
                }

                // Breadcrumbs Nothing OS clicables
                RowLayout {
                    spacing: 4
                    Layout.leftMargin: 6
                    Layout.fillWidth: true

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: view.sys.colOn
                    }

                    Repeater {
                        model: view.breadcrumbs
                        RowLayout {
                            id: bcRow
                            required property int index
                            required property var modelData
                            spacing: 4

                            Text {
                                visible: bcRow.index > 0
                                text: "//"
                                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.25)
                                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4; bold: true }
                            }

                            Rectangle {
                                Layout.preferredHeight: 25
                                Layout.preferredWidth: bcChipRow.implicitWidth + 14
                                radius: 8
                                color: bcMa.containsMouse
                                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                                       : (bcRow.index === view.breadcrumbs.length - 1 ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.width: 1
                                border.color: bcMa.containsMouse
                                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                                              : (bcRow.index === view.breadcrumbs.length - 1 ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    id: bcChipRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        visible: bcRow.index === 0
                                        text: bcRow.modelData.label === "~" ? "󰋜" : "󰉋"
                                        color: bcRow.index === view.breadcrumbs.length - 1 ? view.sys.colOn : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.50)
                                        font { family: view.sys.fontFam; pixelSize: 11 }
                                    }

                                    Text {
                                        id: bcTxt
                                        text: bcRow.modelData.label.toUpperCase()
                                        color: bcRow.index === view.breadcrumbs.length - 1
                                               ? view.sys.colFg
                                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.55)
                                        font {
                                            family: view.sys.fontBody
                                            pixelSize: view.sys.fontSize - 4
                                            letterSpacing: 1.2
                                            bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: bcMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (view.sys && view.sys.playSound) view.sys.playSound("tock");
                                        view.go(bcRow.modelData.path);
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Botones de acción derecha
                RowLayout {
                    spacing: 6

                    // Nueva carpeta
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        color: actMkMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: actMkMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "󰉍"
                            color: actMkMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }
                        MouseArea {
                            id: actMkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.startMkdir()
                        }
                    }

                    // Terminal aquí
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        color: actTermMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: actTermMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "󰞷"
                            color: actTermMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }
                        MouseArea {
                            id: actTermMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.runDetached("kitty --directory " + JSON.stringify(view.dir))
                        }
                    }

                    // Abrir en gestor del sistema (Thunar)
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        color: actThunarMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: actThunarMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "󰒍"
                            color: actThunarMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }
                        MouseArea {
                            id: actThunarMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.runDetached("thunar " + JSON.stringify(view.dir))
                        }
                    }

                    // Conmutador Lista / Cuadrícula
                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 28
                        radius: 9
                        color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: [
                                    { id: "list", g: 0xF0279 },
                                    { id: "grid", g: 0xF0A0E }
                                ]
                                Rectangle {
                                    id: modeToggleBtn
                                    required property var modelData
                                    readonly property bool on: view.mode === modeToggleBtn.modelData.id
                                    width: 32
                                    height: 24
                                    radius: 7
                                    color: modeToggleBtn.on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                                                           : (mMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(modeToggleBtn.modelData.g)
                                        color: modeToggleBtn.on ? view.sys.colOn : view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: 14 }
                                    }
                                    MouseArea {
                                        id: mMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.setMode(modeToggleBtn.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // FILA 2: Ordenación y filtros Nothing OS
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "ORDENAR"
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.32)
                    font {
                        family: view.sys.fontBody
                        pixelSize: view.sys.fontSize - 5
                        bold: true
                        letterSpacing: 1.2
                    }
                }

                Repeater {
                    model: [
                        { key: "name", label: "Nombre" },
                        { key: "time", label: "Fecha" },
                        { key: "size", label: "Tamaño" },
                        { key: "type", label: "Tipo" }
                    ]
                    Rectangle {
                        id: sortPill
                        required property var modelData
                        readonly property bool on: view.sortBy === sortPill.modelData.key
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: sTxt.implicitWidth + (on ? 28 : 16)
                        radius: 8
                        color: on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                  : (sMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.09) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.04))
                        border.width: 1
                        border.color: on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                id: sTxt
                                text: sortPill.modelData.label
                                color: sortPill.on ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4; bold: sortPill.on }
                            }
                            Text {
                                visible: sortPill.on
                                text: view.sortDesc ? "󰄼" : "󰄿"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                        }

                        MouseArea {
                            id: sMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.setSort(sortPill.modelData.key)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Ocultos
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: hidTxt.implicitWidth + 26
                    radius: 8
                    color: view.sys.cfg.filesHidden
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                           : (hidMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.width: 1
                    border.color: view.sys.cfg.filesHidden ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35) : "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: String.fromCodePoint(view.sys.cfg.filesHidden ? 0xF06D0 : 0xF06D1)
                            color: view.sys.cfg.filesHidden ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                        Text {
                            id: hidTxt
                            text: "Ocultos"
                            color: view.sys.cfg.filesHidden ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4; bold: view.sys.cfg.filesHidden }
                        }
                    }
                    MouseArea {
                        id: hidMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.sys.cfg.filesHidden = !view.sys.cfg.filesHidden;
                            view.sys.saveCfg();
                            view.reload();
                        }
                    }
                }

                // Carpetas primero
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: ffTxt.implicitWidth + 26
                    radius: 8
                    color: view.foldersFirst
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                           : (ffMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.width: 1
                    border.color: view.foldersFirst ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35) : "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: String.fromCodePoint(0xF024B)
                            color: view.foldersFirst ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                        Text {
                            id: ffTxt
                            text: "Carpetas primero"
                            color: view.foldersFirst ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4; bold: view.foldersFirst }
                        }
                    }
                    MouseArea {
                        id: ffMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.foldersFirst = !view.foldersFirst;
                            view.applyFilter();
                        }
                    }
                }
            }

            // CONTENEDOR DE ARCHIVOS: LISTA Y CUADRÍCULA
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Marco elástico de selección
                Rectangle {
                    id: rubberBand
                    z: 90
                    visible: false
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                    border.color: view.sys.colOn
                    border.width: 1
                    radius: 4
                }

                // VISTA DE LISTA
                ListView {
                    id: list
                    anchors.fill: parent
                    visible: view.mode === "list"
                    clip: true
                    model: entries
                    currentIndex: view.current
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: false
                    ScrollBar.vertical: SetScroll { sys: view.sys }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function (ev) {
                            var step = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y;
                            if (step === 0) return;
                            var max = Math.max(0, list.contentHeight - list.height);
                            list.contentY = Math.max(0, Math.min(max, list.contentY - step));
                        }
                    }

                    // Fondo de selección por arrastre y menú contextual vacío
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        property real startX: 0
                        property real startY: 0
                        property bool selecting: false

                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                startX = mouse.x;
                                startY = mouse.y;
                                selecting = true;
                                if (!(mouse.modifiers & Qt.ControlModifier)) view.clearSelection();
                            }
                        }
                        onPositionChanged: mouse => {
                            if (!selecting || mouse.buttons !== Qt.LeftButton) return;
                            var rx = Math.min(startX, mouse.x);
                            var ry = Math.min(startY, mouse.y);
                            var rw = Math.abs(mouse.x - startX);
                            var rh = Math.abs(mouse.y - startY);
                            if (rw > 5 || rh > 5) {
                                rubberBand.x = rx; rubberBand.y = ry;
                                rubberBand.width = rw; rubberBand.height = rh;
                                rubberBand.visible = true;
                                view.updateSelectionByRect(rx, ry, rw, rh);
                            }
                        }
                        onReleased: mouse => {
                            if (selecting) { selecting = false; rubberBand.visible = false; }
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                var p = mapToItem(view, mouse.x, mouse.y);
                                view.openMenu("", true, p.x, p.y);
                            } else if (mouse.button === Qt.LeftButton) {
                                if (rubberBand.width <= 5 && rubberBand.height <= 5) view.clearSelection();
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: listRow
                        required property int index
                        required property var model
                        readonly property bool isDir: listRow.model.eType === "d"
                        readonly property bool isSelected: view.isSelected(view.fullPath(listRow.model.eName))
                        readonly property color iconCol: view.iconColorFor(listRow.model)

                        width: list.width - 8
                        x: 4
                        height: 40
                        radius: 10
                        scale: rowMa.pressed ? 0.99 : (rowMa.containsMouse ? 1.008 : 1.0)
                        transform: Translate { x: rowMa.containsMouse ? 2 : 0 }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                        Behavior on transform { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                        color: listRow.isSelected
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                               : (listRow.index === view.current
                                  ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                  : (rowMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045) : "transparent"))
                        border.width: listRow.isSelected ? 1 : 0
                        border.color: listRow.isSelected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 16
                            spacing: 10

                            // Icono contenedor Nothing OS
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 7
                                color: Qt.rgba(listRow.iconCol.r, listRow.iconCol.g, listRow.iconCol.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(listRow.iconCol.r, listRow.iconCol.g, listRow.iconCol.b, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: view.iconFor(listRow.model)
                                    color: listRow.iconCol
                                    font { family: view.sys.fontFam; pixelSize: 14 }
                                }
                            }

                            // Nombre
                            Text {
                                Layout.fillWidth: true
                                text: listRow.model.eName
                                color: listRow.isSelected ? view.sys.colFg : (rowMa.containsMouse ? view.sys.colFg : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.88))
                                elide: Text.ElideMiddle
                                font {
                                    family: view.sys.fontBody
                                    pixelSize: view.sys.fontSize - 2
                                    bold: listRow.isDir || listRow.isSelected
                                }
                            }

                            // Fecha
                            Text {
                                Layout.preferredWidth: 120
                                text: view.timeText(listRow.model)
                                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.35)
                                horizontalAlignment: Text.AlignRight
                                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                            }

                            // Tamaño
                            Text {
                                Layout.preferredWidth: 65
                                text: view.sizeText(listRow.model)
                                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.45)
                                horizontalAlignment: Text.AlignRight
                                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                var p = view.fullPath(listRow.model.eName);
                                view.current = listRow.index;
                                view.forceActiveFocus();
                                if (mouse.button === Qt.RightButton) {
                                    if (!view.isSelected(p)) view.selectSingle(p, listRow.index);
                                    var pos = mapToItem(view, mouse.x, mouse.y);
                                    view.openMenu(p, listRow.model.eType === "d", pos.x, pos.y);
                                    return;
                                }
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    view.toggleSelection(p, listRow.index);
                                } else if (mouse.modifiers & Qt.ShiftModifier) {
                                    view.selectRange(listRow.index);
                                } else {
                                    view.selectSingle(p, listRow.index);
                                }
                            }
                            onDoubleClicked: view.activate(listRow.index)
                        }
                    }
                }

                // VISTA DE CUADRÍCULA
                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: view.mode === "grid"
                    clip: true
                    model: entries
                    currentIndex: view.current
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: false
                    ScrollBar.vertical: SetScroll { sys: view.sys }

                    cellWidth: Math.floor(width / view.gridCols)
                    cellHeight: 110

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function (ev) {
                            var step = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y;
                            if (step === 0) return;
                            var max = Math.max(0, grid.contentHeight - grid.height);
                            grid.contentY = Math.max(0, Math.min(max, grid.contentY - step));
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        property real startX: 0
                        property real startY: 0
                        property bool selecting: false

                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                startX = mouse.x; startY = mouse.y; selecting = true;
                                if (!(mouse.modifiers & Qt.ControlModifier)) view.clearSelection();
                            }
                        }
                        onPositionChanged: mouse => {
                            if (!selecting || mouse.buttons !== Qt.LeftButton) return;
                            var rx = Math.min(startX, mouse.x);
                            var ry = Math.min(startY, mouse.y);
                            var rw = Math.abs(mouse.x - startX);
                            var rh = Math.abs(mouse.y - startY);
                            if (rw > 5 || rh > 5) {
                                rubberBand.x = rx; rubberBand.y = ry;
                                rubberBand.width = rw; rubberBand.height = rh;
                                rubberBand.visible = true;
                                view.updateSelectionByRect(rx, ry, rw, rh);
                            }
                        }
                        onReleased: mouse => {
                            if (selecting) { selecting = false; rubberBand.visible = false; }
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                var p = mapToItem(view, mouse.x, mouse.y);
                                view.openMenu("", true, p.x, p.y);
                            } else if (mouse.button === Qt.LeftButton) {
                                if (rubberBand.width <= 5 && rubberBand.height <= 5) view.clearSelection();
                            }
                        }
                    }

                    delegate: Item {
                        id: gridCellItem
                        required property int index
                        required property var model
                        readonly property bool isDir: gridCellItem.model.eType === "d"
                        readonly property bool isSelected: view.isSelected(view.fullPath(gridCellItem.model.eName))
                        readonly property color iconCol: view.iconColorFor(gridCellItem.model)

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 12
                            scale: cellMa.pressed ? 0.98 : (cellMa.containsMouse ? 1.02 : 1.0)
                            color: gridCellItem.isSelected
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                                   : (gridCellItem.index === view.current
                                      ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)
                                      : (cellMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045) : "transparent"))
                            border.width: 1
                            border.color: gridCellItem.isSelected
                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                                          : (cellMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44
                                    radius: 12
                                    color: Qt.rgba(gridCellItem.iconCol.r, gridCellItem.iconCol.g, gridCellItem.iconCol.b, 0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(gridCellItem.iconCol.r, gridCellItem.iconCol.g, gridCellItem.iconCol.b, 0.25)

                                    Text {
                                        anchors.centerIn: parent
                                        text: view.iconFor(gridCellItem.model)
                                        color: gridCellItem.iconCol
                                        font { family: view.sys.fontFam; pixelSize: 22 }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: gridCellItem.model.eName
                                    color: gridCellItem.isSelected ? view.sys.colFg : (cellMa.containsMouse ? view.sys.colFg : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.88))
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 2
                                    wrapMode: Text.WrapAnywhere
                                    font {
                                        family: view.sys.fontBody
                                        pixelSize: view.sys.fontSize - 3
                                        bold: gridCellItem.isDir || gridCellItem.isSelected
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: !gridCellItem.isDir
                                    text: view.sizeText(gridCellItem.model)
                                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.40)
                                    horizontalAlignment: Text.AlignHCenter
                                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 5 }
                                }
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    var p = view.fullPath(gridCellItem.model.eName);
                                    view.current = gridCellItem.index;
                                    view.forceActiveFocus();
                                    if (mouse.button === Qt.RightButton) {
                                        if (!view.isSelected(p)) view.selectSingle(p, gridCellItem.index);
                                        var pos = mapToItem(view, mouse.x, mouse.y);
                                        view.openMenu(p, gridCellItem.model.eType === "d", pos.x, pos.y);
                                        return;
                                    }
                                    if (mouse.modifiers & Qt.ControlModifier) {
                                        view.toggleSelection(p, gridCellItem.index);
                                    } else if (mouse.modifiers & Qt.ShiftModifier) {
                                        view.selectRange(gridCellItem.index);
                                    } else {
                                        view.selectSingle(p, gridCellItem.index);
                                    }
                                }
                                onDoubleClicked: view.activate(gridCellItem.index)
                            }
                        }
                    }
                }
            }

            // BARRA DE ESTADO INFERIOR
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                spacing: 12

                Text {
                    text: entries.count + " " + view.sys.tr("elementos")
                    color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.40)
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }

                Text {
                    visible: view.selectedCount > 0
                    text: "•  " + view.selectedCount + " " + view.sys.tr("seleccionados")
                    color: view.sys.colOn
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4; bold: true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: view.status.length > 0
                    text: view.status
                    color: view.sys.colOn
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }
    }

    // =========================================================================
    // MODALES Y POPUPS
    // =========================================================================

    // MENÚ CONTEXTUAL NOTHING OS
    MouseArea {
        anchors.fill: parent
        z: 94
        visible: view.menuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: view.closeMenu()
    }

    Rectangle {
        id: contextMenu
        z: 95
        visible: view.menuOpen
        x: view.menuX
        y: view.menuY
        width: 200
        implicitHeight: menuCol.implicitHeight + 16
        radius: 14
        color: Qt.rgba(0.08, 0.08, 0.09, 0.98)
        border.width: 1
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.14)
        scale: view.menuOpen ? 1 : 0.95
        opacity: view.menuOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 110 } }

        component CtxItem: Rectangle {
            property string glyph: ""
            property string label: ""
            property bool danger: false
            property bool enabledItem: true
            signal chosen()

            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 8
            color: cMa.containsMouse && enabledItem
                   ? (danger ? Qt.rgba(0.94, 0.27, 0.27, 0.18) : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10))
                   : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            opacity: enabledItem ? 1 : 0.35

            scale: cMa.pressed && enabledItem ? 0.985 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            transform: Translate {
                x: cMa.containsMouse && enabledItem ? 2 : 0
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: parent.parent.glyph
                    color: parent.parent.danger ? view.sys.colCrit : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 13 }
                }
                Text {
                    Layout.fillWidth: true
                    text: parent.parent.label
                    color: parent.parent.danger ? view.sys.colCrit : view.sys.colFg
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                }
            }

            MouseArea {
                id: cMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.enabledItem
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.chosen()
            }
        }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            // Menú para papelera
            ColumnLayout {
                visible: view.menuKind === "trash"
                Layout.fillWidth: true
                spacing: 2
                CtxItem {
                    glyph: "󰩺"
                    label: view.sys.tr("Vaciar papelera")
                    danger: true
                    onChosen: view.emptyTrash()
                }
            }

            // Menú para archivo/carpeta
            ColumnLayout {
                visible: view.menuKind === "file"
                Layout.fillWidth: true
                spacing: 2

                CtxItem {
                    glyph: "󰅩"
                    label: view.sys.tr("Abrir")
                    onChosen: view.doOpen(view.menuPath)
                }
                CtxItem {
                    glyph: "󰒍"
                    label: view.sys.tr("Abrir con...")
                    onChosen: view.doOpenWith(view.menuPath)
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                CtxItem {
                    glyph: "󰆏"
                    label: view.sys.tr("Cortar")
                    onChosen: view.doCut(view.menuPath)
                }
                CtxItem {
                    glyph: "󰆐"
                    label: view.sys.tr("Copiar")
                    onChosen: view.doCopy(view.menuPath)
                }
                CtxItem {
                    glyph: "󰑕"
                    label: view.sys.tr("Renombrar")
                    onChosen: view.startRename(view.menuPath)
                }
                CtxItem {
                    glyph: "󰅍"
                    label: view.sys.tr("Copiar ruta")
                    onChosen: view.doCopyPath(view.menuPath)
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                CtxItem {
                    glyph: "󰋽"
                    label: view.sys.tr("Propiedades")
                    onChosen: view.showProps(view.menuPath)
                }
                CtxItem {
                    glyph: "󰩺"
                    label: view.sys.tr("A papelera")
                    danger: true
                    onChosen: view.doTrash(view.menuPath)
                }
            }

            // Menú para espacio vacío de la carpeta
            ColumnLayout {
                visible: view.menuKind === "folder"
                Layout.fillWidth: true
                spacing: 2

                CtxItem {
                    glyph: "󰉍"
                    label: view.sys.tr("Nueva carpeta")
                    onChosen: view.startMkdir()
                }
                CtxItem {
                    glyph: "󰆒"
                    label: view.sys.tr("Pegar aquí")
                    enabledItem: view.clipPaths.length > 0
                    onChosen: view.doPaste()
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                CtxItem {
                    glyph: "󰞷"
                    label: view.sys.tr("Abrir terminal")
                    onChosen: {
                        view.closeMenu();
                        view.sys.runDetached("kitty --directory " + JSON.stringify(view.dir));
                    }
                }
                CtxItem {
                    glyph: "󰒍"
                    label: view.sys.tr("Abrir en Thunar")
                    onChosen: {
                        view.closeMenu();
                        view.sys.runDetached("thunar " + JSON.stringify(view.dir));
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                CtxItem {
                    glyph: "󰋽"
                    label: view.sys.tr("Propiedades de carpeta")
                    onChosen: view.showProps(view.dir)
                }
            }
        }
    }

    // MODAL: RENOMBRAR / NUEVA CARPETA
    MouseArea {
        anchors.fill: parent
        z: 96
        visible: view.dialogMode.length > 0
        onClicked: view.cancelDialog()
    }

    Rectangle {
        id: renameDialog
        z: 97
        visible: view.dialogMode.length > 0
        anchors.centerIn: parent
        width: 380
        implicitHeight: dlgCol.implicitHeight + 32
        radius: 16
        color: Qt.rgba(0.08, 0.08, 0.09, 0.98)
        border.width: 1
        border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
        scale: view.dialogMode.length > 0 ? 1 : 0.95
        opacity: view.dialogMode.length > 0 ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        ColumnLayout {
            id: dlgCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: view.dialogMode === "rename" ? view.sys.tr("Renombrar") : view.sys.tr("Nueva carpeta")
                color: view.sys.colFg
                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize; bold: true }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.5)

                TextInput {
                    id: dialogField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    color: view.sys.colFg
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1 }
                    selectByMouse: true
                    onAccepted: view.confirmDialog()
                    Keys.onEscapePressed: view.cancelDialog()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.cancelDialog()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    radius: 8
                    color: view.sys.colOn
                    Text {
                        anchors.centerIn: parent
                        text: "Aceptar"
                        color: "#ffffff"
                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3; bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.confirmDialog()
                    }
                }
            }
        }
    }

    // MODAL: PROPIEDADES
    MouseArea {
        anchors.fill: parent
        z: 98
        visible: view.propsOpen
        onClicked: view.propsOpen = false
    }

    Rectangle {
        id: propsModal
        z: 99
        visible: view.propsOpen
        anchors.centerIn: parent
        width: 440
        implicitHeight: pCol.implicitHeight + 36
        radius: 18
        color: Qt.rgba(0.08, 0.08, 0.09, 0.98)
        border.width: 1
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.16)
        scale: view.propsOpen ? 1 : 0.95
        opacity: view.propsOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        component PRow: RowLayout {
            property string k: ""
            property string v: ""
            visible: v.length > 0
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.preferredWidth: 110
                text: k
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.40)
                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                text: v
                color: view.sys.colFg
                wrapMode: Text.WrapAnywhere
                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
            }
        }

        ColumnLayout {
            id: pCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF024B)
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 18 }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: String(view.propsData.name || "")
                    color: view.sys.colFg
                    elide: Text.ElideMiddle
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    text: "󰅖"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.propsOpen = false
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            PRow { k: "Tipo"; v: String(view.propsData.kind || "") }
            PRow { k: "Elementos"; v: view.propsData.items ? (view.propsData.items + " elementos") : "" }
            PRow { k: "Tamaño"; v: String(view.propsData.size_human || "") + (view.propsData.size_bytes ? " (" + view.propsData.size_bytes + " B)" : "") }
            PRow { k: "Modificado"; v: String(view.propsData.modified || "") }
            PRow { k: "Creado"; v: String(view.propsData.created || "") }
            PRow { k: "Permisos"; v: String(view.propsData.perms || "") }
            PRow { k: "Propietario"; v: String(view.propsData.owner || "") }
            PRow { k: "Ruta"; v: String(view.propsData.path || "") }
        }
    }
}
