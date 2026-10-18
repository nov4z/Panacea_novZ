import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Página de Copias de Seguridad (Backup & Restauración) para Panacea Shell.
// Permite guardar instantáneas de settings.json, restaurar el estado original del sistema
// antes del rediseño, exportar/importar configuraciones y gestionar puntos de guardado.
ColumnLayout {
    id: page

    property var sys
    Layout.fillWidth: true
    spacing: 14

    property var backups: []
    property string statusMsg: ""
    property color statusCol: page.sys.colOk
    property string newBackupTag: ""

    // Diálogo de confirmación inline
    property bool confirming: false
    property string confirmAction: "" // "restore", "restore_baseline", "delete", "factory"
    property string confirmFile: ""
    property string confirmTitle: ""
    property string confirmDesc: ""

    Timer {
        id: statusClearTimer
        interval: 4000
        onTriggered: page.statusMsg = ""
    }

    function setStatus(msg, isError) {
        page.statusMsg = msg;
        page.statusCol = isError ? page.sys.colCrit : page.sys.colOk;
        statusClearTimer.restart();
    }

    // Listar backups
    Process {
        id: pList
        command: ["sh", page.sys.scriptDir + "/backup_manager.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.backups = JSON.parse(text.trim());
                } catch (e) {
                    page.backups = [];
                }
            }
        }
    }

    // Crear backup
    Process {
        id: pCreate
        property string tag: ""
        command: ["sh", page.sys.scriptDir + "/backup_manager.sh", "create", pCreate.tag]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text.trim());
                    if (res.status === "ok") {
                        page.setStatus("Copia de seguridad guardada: " + res.file, false);
                        if (page.sys && page.sys.playSound) page.sys.playSound("pop");
                        pList.running = true;
                        page.newBackupTag = "";
                    } else {
                        page.setStatus("Error al crear copia: " + (res.message || "desconocido"), true);
                    }
                } catch (e) {
                    page.setStatus("Error en proceso de copia", true);
                }
            }
        }
    }

    // Restaurar backup
    Process {
        id: pRestore
        property string file: ""
        command: ["sh", page.sys.scriptDir + "/backup_manager.sh", "restore", pRestore.file]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text.trim());
                    if (res.status === "ok") {
                        page.setStatus("Configuración restaurada con éxito desde " + res.file, false);
                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        pList.running = true;
                    } else {
                        page.setStatus("Error al restaurar: " + (res.message || "desconocido"), true);
                    }
                } catch (e) {
                    page.setStatus("Error al restaurar archivo", true);
                }
            }
        }
    }

    // Eliminar backup
    Process {
        id: pDelete
        property string file: ""
        command: ["sh", page.sys.scriptDir + "/backup_manager.sh", "delete", pDelete.file]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text.trim());
                    if (res.status === "ok") {
                        page.setStatus("Copia de seguridad eliminada", false);
                        pList.running = true;
                    } else {
                        page.setStatus("Error al eliminar: " + (res.message || "desconocido"), true);
                    }
                } catch (e) {
                    page.setStatus("Error al eliminar", true);
                }
            }
        }
    }

    // Exportar a portapapeles
    Process {
        id: pExport
        command: ["sh", "-c", "cat \"$1\" | wl-copy", "_", Quickshell.env("HOME") + "/.config/panacea/settings.json"]
        onExited: {
            page.setStatus("Configuración JSON copiada al portapapeles (wl-copy)", false);
            if (page.sys && page.sys.playSound) page.sys.playSound("pop");
        }
    }

    // Importar desde portapapeles
    Process {
        id: pImport
        command: ["sh", "-c", "wl-paste | \"" + page.sys.scriptDir + "/backup_manager.sh\" import"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text.trim());
                    if (res.status === "ok") {
                        page.setStatus("Configuración importada exitosamente desde el portapapeles", false);
                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        pList.running = true;
                    } else {
                        page.setStatus("El contenido del portapapeles no es JSON válido", true);
                    }
                } catch (e) {
                    page.setStatus("Error al importar desde el portapapeles", true);
                }
            }
        }
    }

    function refresh() {
        pList.running = false;
        pList.running = true;
    }

    Component.onCompleted: refresh()

    // ------------------------------------------------------------- Mensaje de Estado / Notificación
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 12
        visible: page.statusMsg.length > 0
        color: Qt.rgba(page.statusCol.r, page.statusCol.g, page.statusCol.b, 0.16)
        border.color: Qt.rgba(page.statusCol.r, page.statusCol.g, page.statusCol.b, 0.45)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Glyph {
                glyph: String.fromCodePoint(page.statusCol === page.sys.colCrit ? 0xF0026 : 0xF012C)
                color: page.statusCol
                size: 16
            }

            Text {
                Layout.fillWidth: true
                text: page.statusMsg
                color: page.sys.colFg
                elide: Text.ElideRight
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
            }
        }
    }

    // ------------------------------------------------------------- Diálogo de Confirmación
    Rectangle {
        Layout.fillWidth: true
        visible: page.confirming
        radius: 16
        color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)
        border.color: page.sys.colOn
        border.width: 1.5
        implicitHeight: confirmCol.implicitHeight + 24

        ColumnLayout {
            id: confirmCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Glyph {
                    glyph: String.fromCodePoint(0xF0026)
                    color: page.sys.colWarn
                    size: 20
                }

                Text {
                    Layout.fillWidth: true
                    text: page.confirmTitle
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
            }

            Text {
                Layout.fillWidth: true
                text: page.confirmDesc
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                SetButton {
                    sys: page.sys
                    text: page.sys.tr("Cancelar")
                    onClicked: { page.confirming = false; }
                }

                SetButton {
                    sys: page.sys
                    text: page.sys.tr("Confirmar y Restaurar")
                    primary: true
                    onClicked: {
                        page.confirming = false;
                        if (page.confirmAction === "restore" || page.confirmAction === "restore_baseline") {
                            pRestore.file = page.confirmFile;
                            pRestore.running = true;
                        } else if (page.confirmAction === "delete") {
                            pDelete.file = page.confirmFile;
                            pDelete.running = true;
                        } else if (page.confirmAction === "factory") {
                            page.sys.resetCfg();
                            page.setStatus("Configuración restablecida a valores por defecto de fábrica", false);
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        }
                    }
                }
            }
        }
    }

    // ============================================================= 1. TARJETA DESTACADA: ESTADO ORIGINAL
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: 14
                color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.20)
                border.color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.50)
                border.width: 1

                Glyph {
                    anchors.centerIn: parent
                    glyph: String.fromCodePoint(0xF09BF) // backup-restore
                    color: page.sys.colOn
                    size: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    spacing: 8
                    Text {
                        text: page.sys.tr("Estado Original Garantizado")
                        color: page.sys.colFg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize; bold: true }
                    }

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 18
                        radius: 9
                        color: Qt.rgba(page.sys.colOk.r, page.sys.colOk.g, page.sys.colOk.b, 0.20)
                        border.color: page.sys.colOk
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "PROTEGIDO"
                            color: page.sys.colOk
                            font { family: page.sys.fontBody; pixelSize: 9; bold: true }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: page.sys.tr("Copia de seguridad base (baseline_current.json) creada antes de comenzar el nuevo rediseño. Permite regresar instantáneamente al estado exacto que tenías.")
                    color: page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Restaurar Original")
                primary: true
                onClicked: {
                    page.confirmTitle = "Restaurar Estado Original";
                    page.confirmDesc = "¿Deseas restaurar la configuración exacta guardada al inicio (baseline_current.json)? Tus ajustes volverán al estado previo al rediseño.";
                    page.confirmAction = "restore_baseline";
                    page.confirmFile = "baseline_current.json";
                    page.confirming = true;
                }
            }
        }
    }

    // ============================================================= 2. CREAR NUEVA COPIA DE SEGURIDAD
    SetCard {
        sys: page.sys

        SetLabel {
            sys: page.sys
            text: page.sys.tr("Crear nueva instantánea")
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Guarda todos los ajustes actuales de temas, animaciones, atajos y menús en un punto de restauración con fecha y hora.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 10
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06)
                border.color: tagInput.activeFocus ? page.sys.colOn : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Glyph {
                        glyph: String.fromCodePoint(0xF0187) // tag
                        color: tagInput.activeFocus ? page.sys.colOn : page.sys.colMuted
                        size: 15
                    }

                    TextInput {
                        id: tagInput
                        Layout.fillWidth: true
                        color: page.sys.colFg
                        text: page.newBackupTag
                        onTextChanged: page.newBackupTag = text
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: parent.text.length === 0
                            text: page.sys.tr("Etiqueta o nombre opcional (ej: favorito, antes_de_cambios)")
                            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.35)
                            font: parent.font
                        }

                        Keys.onReturnPressed: {
                            pCreate.tag = page.newBackupTag;
                            pCreate.running = true;
                        }
                    }
                }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Guardar Copia")
                primary: true
                onClicked: {
                    pCreate.tag = page.newBackupTag;
                    pCreate.running = true;
                }
            }
        }
    }

    // ============================================================= 3. HISTORIAL DE COPIAS
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SetLabel {
                sys: page.sys
                text: page.sys.tr("Historial de Copias Guardadas")
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: refreshMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12) : "transparent"

                Glyph {
                    anchors.centerIn: parent
                    glyph: String.fromCodePoint(0xF0450) // refresh
                    color: page.sys.colMuted
                    size: 16
                }

                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.refresh()
                }
            }
        }

        Text {
            visible: page.backups.length === 0
            text: page.sys.tr("No se han encontrado copias de seguridad guardadas.")
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: page.backups.length > 0

            Repeater {
                model: page.backups

                Rectangle {
                    id: backupRow
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 12
                    color: bMa.containsMouse
                           ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)
                           : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.04)
                    border.color: backupRow.modelData.isBaseline
                                  ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.35)
                                  : (bMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.15) : "transparent")
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12

                        Glyph {
                            glyph: String.fromCodePoint(backupRow.modelData.isBaseline ? 0xF09BF : 0xF0219)
                            color: backupRow.modelData.isBaseline ? page.sys.colOn : page.sys.colMuted
                            size: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: backupRow.modelData.label
                                    color: page.sys.colFg
                                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: true }
                                }
                                Rectangle {
                                    visible: !!backupRow.modelData.isBaseline
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 16
                                    radius: 8
                                    color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "ORIGINAL"
                                        color: page.sys.colOn
                                        font { family: page.sys.fontBody; pixelSize: 8; bold: true }
                                    }
                                }
                            }

                            Text {
                                text: backupRow.modelData.desc + " · " + backupRow.modelData.date + " (" + backupRow.modelData.size + ")"
                                color: page.sys.colMuted
                                elide: Text.ElideRight
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            }
                        }

                        // Botón Restaurar
                        Rectangle {
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 28
                            radius: 8
                            color: resMa.containsMouse ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.35)
                                                       : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.20)
                            border.color: page.sys.colOn
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: page.sys.tr("Restaurar")
                                color: page.sys.colFg
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                            }

                            MouseArea {
                                id: resMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.confirmTitle = "Restaurar Copia: " + backupRow.modelData.label;
                                    page.confirmDesc = "¿Deseas restaurar la configuración desde '" + backupRow.modelData.file + "'? Tu shell actualizará sus parámetros inmediatamente.";
                                    page.confirmAction = "restore";
                                    page.confirmFile = backupRow.modelData.file;
                                    page.confirming = true;
                                }
                            }
                        }

                        // Botón Eliminar (no para baseline)
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            visible: !backupRow.modelData.isBaseline
                            color: delMa.containsMouse ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b, 0.25) : "transparent"

                            Glyph {
                                anchors.centerIn: parent
                                glyph: String.fromCodePoint(0xF01B4) // delete
                                color: delMa.containsMouse ? page.sys.colCrit : page.sys.colMuted
                                size: 16
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.confirmTitle = "Eliminar Copia de Seguridad";
                                    page.confirmDesc = "¿Seguro que deseas eliminar permanentemente el archivo '" + backupRow.modelData.file + "'?";
                                    page.confirmAction = "delete";
                                    page.confirmFile = backupRow.modelData.file;
                                    page.confirming = true;
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: bMa
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                    }
                }
            }
        }
    }

    // ============================================================= 4. EXPORTAR / IMPORTAR / RESTABLECER
    SetCard {
        sys: page.sys

        SetLabel {
            sys: page.sys
            text: page.sys.tr("Gestión Avanzada y Exportación")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.tr("Exportar / Importar Configuración")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: true }
                }
                Text {
                    text: page.sys.tr("Copia el contenido íntegro de settings.json al portapapeles o importa un JSON existente.")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Copiar JSON")
                onClicked: pExport.running = true
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Pegar e Importar")
                onClicked: pImport.running = true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: page.sys.tr("Restablecer a Valores de Fábrica")
                    color: page.sys.colCrit
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: true }
                }
                Text {
                    text: page.sys.tr("Reinicia todos los ajustes a los valores iniciales por defecto de Panacea.")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Restablecer")
                onClicked: {
                    page.confirmTitle = "Restablecer a Valores de Fábrica";
                    page.confirmDesc = "¿Estás completamente seguro de restablecer todos los ajustes a los valores predeterminados? Se creará una copia de seguridad automática antes de proceder.";
                    page.confirmAction = "factory";
                    page.confirmFile = "";
                    page.confirming = true;
                }
            }
        }
    }
}
