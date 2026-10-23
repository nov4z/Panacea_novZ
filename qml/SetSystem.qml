import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// System. Слева от характеристик машины стоит живой опрос: память, нагрузка,
// температура и число процессов. Опрашиваем раз в две секунды одной командой
// — отдельные процессы на каждую строку стоили бы дороже самих данных.
ColumnLayout {
    id: page

    property var sys

    property string osName: ""
    property string kernel: ""
    property string wm: ""
    property string cpuName: ""
    property string gpuName: ""
    property string host: ""
    property string uptime: ""

    // живые показатели
    property real memUsed: 0      // ГиБ
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real load1: 0
    property int  procs: 0
    property real tempCpu: -1
    property real tempGpu: -1
    property real diskUsed: 0
    property real diskTotal: 0
    property real selfMb: 0       // сколько занимает сама оболочка, МиБ

    function stepName(st) {
        return st === "download"   ? page.sys.tr("скачивание")
             : st === "clean"      ? page.sys.tr("очистка")
             : st === "selfupdate" ? page.sys.tr("обновление обновлятора")
             : st === "backup"   ? page.sys.tr("сохранение настроек")
             : st === "install"  ? page.sys.tr("установка")
             : st === "restore"  ? page.sys.tr("возврат настроек")
             : st === "restart"  ? page.sys.tr("перезапуск")
             : "";
    }

    // кнопка сброса взведена и ждёт подтверждения
    property bool armed: false
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = false }

    // Состояние чистой переустановки: 0 - покой, 1 - первое подтверждение, 2 - второе подтверждение
    property int reinstallStep: 0
    property int reinstallCooldown: 0

    Timer {
        id: reinstallTimer
        interval: 1000
        repeat: true
        running: page.reinstallCooldown > 0
        onTriggered: {
            if (page.reinstallCooldown > 0)
                page.reinstallCooldown -= 1;
        }
    }

    Timer {
        id: reinstallDisarmTimer
        interval: 35000
        repeat: false
        running: page.reinstallStep > 0 && !page.sys.updBusy
        onTriggered: page.cancelReinstall()
    }

    function cancelReinstall() {
        page.reinstallStep = 0;
        page.reinstallCooldown = 0;
        reinstallDisarmTimer.stop();
    }

    Component.onDestruction: page.cancelReinstall()

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: {
        pInfo.running = true;
        pLive.running = true;
        if (page.sys && !page.sys.updStatus && !page.sys.updChecking)
            page.sys.checkUpdate();
    }

    Process {
        id: pInfo
        command: ["sh", "-c",
            "wm_ver=\"\"; " +
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then " +
            "  wm_ver=\"niri $(niri --version 2>/dev/null | awk '{print $2}')\"; " +
            "else " +
            "  wm_ver=\"${XDG_CURRENT_DESKTOP:-Hyprland} $(hyprctl version -j 2>/dev/null | sed -n 's/.*\\\"tag\\\": *\\\"\\([^\\\"]*\\)\\\".*/\\1/p')\"; " +
            "fi; " +
            "cpu_n=$(sed -n 's/^model name[ \\t]*: //p' /proc/cpuinfo 2>/dev/null | head -1); " +
            "[ -z \"$cpu_n\" ] && cpu_n=$(sed -n 's/^Model[ \\t]*: //p' /proc/cpuinfo 2>/dev/null | head -1); " +
            "[ -z \"$cpu_n\" ] && cpu_n=$(lscpu 2>/dev/null | sed -n 's/^Model name:[ \\t]*//p' | head -1); " +
            "gpu_n=$(lspci 2>/dev/null | sed -n 's/.*\\(VGA compatible controller\\|3D controller\\): //p' | head -1); " +
            "printf '%s\\n' \"$(. /etc/os-release 2>/dev/null; echo $PRETTY_NAME)\" " +
            "\"$(uname -r)\" \"$wm_ver\" " +
            "\"${cpu_n:-Generic Processor}\" " +
            "\"${gpu_n:-Generic Graphics}\" " +
            "\"$(cat /etc/hostname 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.split("\n");
                page.osName  = (a[0] || "").trim();
                page.kernel  = (a[1] || "").trim();
                page.wm      = (a[2] || "").trim();
                page.cpuName = (a[3] || "").trim();
                page.gpuName = (a[4] || "").trim();
                page.host    = (a[5] || "").trim();
            }
        }
    }

    // Monitoreo de hardware universal en vivo:
    // Lee directamente /proc/meminfo para asegurar memoria y swap sin depender del idioma/locale.
    // Detección universal de CPU/GPU en sysfs hwmon y thermal_zone para cualquier distribución/PC.
    Process {
        id: pLive
        command: ["sh", "-c",
            // 0: Memoria | 1: Swap | 2: Carga CPU 1m | 3: Procesos | 4: Temp CPU | 5: Temp GPU | 6: Disco | 7: Uptime | 8: RSS Panacea
            "awk '/MemTotal:/{mt=$2} /MemAvailable:/{ma=$2} /SwapTotal:/{st=$2} /SwapFree:/{sf=$2} END{printf \"%d %d|%d %d|\", (mt-ma), mt, (st-sf), st}' /proc/meminfo 2>/dev/null || printf '0 0|0 0|'; " +
            "awk '{printf \"%s|\", $1}' /proc/loadavg 2>/dev/null || printf '0|'; " +
            "ls -d /proc/[0-9]* 2>/dev/null | wc -l | tr -d '\\n'; printf '|'; " +
            "cpu_t=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in k10temp|coretemp|zenpower|cpu_thermal|cpu-thermal|soc_thermal|acpitz_cpu|thinkpad|asus|dell_smm) " +
            "for tf in $h/temp1_input $h/temp2_input $h/temp*_input; do [ -r \"$tf\" ] && { cpu_t=$(cat \"$tf\" 2>/dev/null); [ -n \"$cpu_t\" ] && break 2; }; done;; esac; done; " +
            "if [ -z \"$cpu_t\" ]; then for z in /sys/class/thermal/thermal_zone*; do " +
            "zt=$(cat $z/type 2>/dev/null); case $zt in *cpu*|*CPU*|*pkg*|*PKG*|x86_pkg_temp|acpitz) " +
            "zv=$(cat $z/temp 2>/dev/null); if [ -n \"$zv\" ] && [ \"$zv\" -gt 0 ] 2>/dev/null; then cpu_t=\"$zv\"; break; fi;; esac; done; fi; " +
            "printf '%s|' \"$cpu_t\"; " +
            "gpu=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in amdgpu|nouveau|radeon|i915|nvidia|xe) " +
            "for tf in $h/temp1_input $h/temp*_input; do [ -r \"$tf\" ] && { gpu=$(cat \"$tf\" 2>/dev/null); [ -n \"$gpu\" ] && break 2; }; done;; esac; done; " +
            "if [ -z \"$gpu\" ] && command -v nvidia-smi >/dev/null 2>&1; then " +
            "c=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '); " +
            "case \"$c\" in [0-9]*) gpu=$((c * 1000));; esac; fi; " +
            "if [ -z \"$gpu\" ]; then for z in /sys/class/thermal/thermal_zone*; do " +
            "zt=$(cat $z/type 2>/dev/null); case $zt in SEN4|SEN5|*gpu*|*GPU*|*dGPU*) " +
            "zv=$(cat $z/temp 2>/dev/null); if [ -n \"$zv\" ] && [ \"$zv\" -gt 0 ] 2>/dev/null; then gpu=\"$zv\"; break; fi;; esac; done; fi; " +
            "printf '%s|' \"$gpu\"; " +
            "dsk=$(LC_ALL=C df -k --output=used,size / 2>/dev/null | tail -1 | tr -s ' ' | sed 's/^ //'); " +
            "[ -z \"$dsk\" ] && dsk=$(LC_ALL=C df -k / 2>/dev/null | awk 'END{print $3, $2}'); " +
            "printf '%s|' \"$dsk\"; " +
            "uptime -p 2>/dev/null | tr -d '\\n'; printf '|'; " +
            "rss=$(awk '/VmRSS/{print $2}' /proc/$PPID/status 2>/dev/null); " +
            "if [ -z \"$rss\" ] || [ \"$rss\" -le 0 ] 2>/dev/null; then " +
            "rss=$(ps -C qs,quickshell -o rss= 2>/dev/null | head -1 | tr -d ' '); fi; " +
            "printf '%s@' \"${rss:-0}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var recs = text.split("@").filter(r => r.indexOf("|") > 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].trim().split("|");
                var mem = (a[0] || "").trim().split(/\s+/);
                var swp = (a[1] || "").trim().split(/\s+/);
                var dsk = (a[6] || "").trim().split(/\s+/);
                page.memUsed  = (+mem[0] || 0) / 1048576;
                page.memTotal = (+mem[1] || 0) / 1048576;
                page.swapUsed  = (+swp[0] || 0) / 1048576;
                page.swapTotal = (+swp[1] || 0) / 1048576;
                page.load1  = +a[2] || 0;
                page.procs  = +a[3] || 0;
                page.tempCpu = (+a[4] > 0) ? (+a[4] / 1000) : -1;
                page.tempGpu = (+a[5] > 0) ? (+a[5] / 1000) : -1;
                page.diskUsed  = (+dsk[0] || 0) / 1048576;
                page.diskTotal = (+dsk[1] || 0) / 1048576;
                page.uptime = (a[7] || "").trim();
                page.selfMb = (+a[8] || 0) / 1024;
            }
        }
    }

    // Опрос перезапускаем через сброс: присваивание running = true, когда
    // процесс ещё не отметился завершённым, ничего не делает — показания
    // замирали на первом снимке.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { pLive.running = false; pLive.running = true; }
    }

    Process { id: pOpen; property string url: ""; command: ["xdg-open", pOpen.url] }

    // ------------------------------------------------------------- автор
    // Ссылка стоит первой и во всю ширину: это лицо страницы, а не сноска.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 18
        color: ghMa.containsMouse
               ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
               : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.045)
        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Text {
                text: String.fromCodePoint(0xF02A4)   // логотип GitHub
                color: page.sys.colFg
                font { family: page.sys.fontFam; pixelSize: 26 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "github.com/EnsixD"
                    color: page.sys.colFg
                    font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize + 1 }
                }
                Text {
                    text: page.sys.tr("Автор оболочки — профиль на GitHub")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
            Text {
                text: String.fromCodePoint(0xF0327)   // стрелка наружу
                color: page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
            }
        }

        MouseArea {
            id: ghMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { pOpen.url = "https://github.com/EnsixD"; pOpen.running = false; pOpen.running = true; }
        }
    }

    // ------------------------------------------------------------- perfil novZ (Panacea novZ)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 18
        color: ghNovZMa.containsMouse
               ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
               : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.045)
        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Text {
                text: String.fromCodePoint(0xF02A4)   // логотип GitHub
                color: page.sys.colFg
                font { family: page.sys.fontFam; pixelSize: 26 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "github.com/nov4z"
                    color: page.sys.colFg
                    font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize + 1 }
                }
                Text {
                    text: page.sys.tr("Perfil en GitHub de novZ (Panacea novZ)")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
            Text {
                text: String.fromCodePoint(0xF0327)   // стрелка наружу
                color: page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
            }
        }

        MouseArea {
            id: ghNovZMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { pOpen.url = "https://github.com/nov4z/Panacea_novZ"; pOpen.running = false; pOpen.running = true; }
        }
    }

    // ------------------------------------------------------------- personalización
    SetCard {
        id: customCard
        sys: page.sys

        property bool largeOpen: false

        readonly property color accentColor: {
            if (page.sys && page.sys.themeMaterial) {
                if (page.sys.matugenColors && page.sys.matugenColors.primary && page.sys.matugenColors.primary.dark) {
                    return page.sys.matugenColors.primary.dark.color;
                }
                return page.sys.colOn;
            }
            return "#ff2825";
        }

        // Cabecera del panel
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: customCard.accentColor
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                text: page.sys.tr("PERSONALIZACIÓN")
                color: page.sys.colFg
                font {
                    family: page.sys.fontFam
                    pixelSize: page.sys.fontSize - 3
                    letterSpacing: 1.8
                    bold: true
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: customCard.largeOpen ? page.sys.tr("VISTA AMPLIADA") : page.sys.tr("PANACEA novZ")
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 5; letterSpacing: 1.2 }
            }
        }

        // Contenido principal (Modo Normal)
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            // Columna Izquierda: Información en Texto del Sistema
            ColumnLayout {
                spacing: 12

                // 1. SISTEMA
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: page.sys.tr("SISTEMA")
                        color: page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; letterSpacing: 1.4; bold: true }
                    }
                    Text {
                        text: page.osName.length > 0 ? page.osName : "Linux"
                        color: page.sys.colFg
                        font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize; bold: true }
                    }
                }

                // 2. KERNEL
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: page.sys.tr("KERNEL")
                        color: page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; letterSpacing: 1.4; bold: true }
                    }
                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: customCard.accentColor
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        Text {
                            text: page.kernel.length > 0 ? page.kernel : "Linux"
                            color: page.sys.colFg
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1 }
                        }
                    }
                }

                // 3. SHELL
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: page.sys.tr("SHELL")
                        color: page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; letterSpacing: 1.4; bold: true }
                    }
                    Text {
                        text: "Panacea" + (page.sys.version ? " v" + page.sys.version : "")
                        color: page.sys.colFg
                        font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize - 1; bold: true }
                    }
                }

                // 4. COMPILACIÓN: novZ
                ColumnLayout {
                    spacing: 4
                    Text {
                        text: page.sys.tr("COMPILACIÓN")
                        color: page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; letterSpacing: 1.4; bold: true }
                    }
                    Rectangle {
                        Layout.preferredWidth: customBuildRow.implicitWidth + 20
                        Layout.preferredHeight: 28
                        radius: 8
                        color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12)

                        RowLayout {
                            id: customBuildRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: customCard.accentColor
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Text {
                                text: "novZ"
                                color: "#ffffff"
                                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize + 1; bold: true; letterSpacing: 1.5 }
                            }
                        }
                    }
                }
            }

            // Espaciador flexible para empujar el logo completamente a la derecha
            Item {
                Layout.fillWidth: true
            }

            // Columna Derecha: Ficha 3D que gira siempre hacia la derecha y frena suavemente al pasar el cursor mostrando la otra cara
            Item {
                id: logoBadge
                width: 96
                height: 96
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 70

                property real spinAngle: 0
                readonly property real normAngle: (spinAngle % 360 + 360) % 360
                readonly property bool showFront: (normAngle < 90 || normAngle >= 270)
                readonly property bool showBack: !showFront

                // Giro continuo permanente por defecto hacia la derecha
                NumberAnimation {
                    id: ambientAnim
                    target: logoBadge
                    property: "spinAngle"
                    from: 0
                    to: 360
                    duration: 2600
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                }

                Component.onCompleted: ambientAnim.start()

                // Frenado gradual cinético hasta detenerse en la cara con la info (180°)
                NumberAnimation {
                    id: brakeAnim
                    target: logoBadge
                    property: "spinAngle"
                    easing.type: Easing.OutCubic
                    onFinished: {
                        logoBadge.spinAngle = 180;
                    }
                }

                // Reanudación al retirar el cursor (acelera suavemente sin corte con el giro base)
                NumberAnimation {
                    id: resumeAnim
                    target: logoBadge
                    property: "spinAngle"
                    easing.type: Easing.InQuad
                    onFinished: {
                        logoBadge.spinAngle = 0;
                        if (!badgeMa.containsMouse) {
                            ambientAnim.start();
                        }
                    }
                }

                function onHoverEntered() {
                    ambientAnim.stop();
                    resumeAnim.stop();
                    brakeAnim.stop();

                    var current = (logoBadge.spinAngle % 360 + 360) % 360;
                    var dist = 0;
                    if (current <= 180) {
                        dist = 180 - current;
                        if (dist < 45) dist += 360;
                    } else {
                        dist = 540 - current;
                        if (dist < 45) dist += 360;
                    }

                    brakeAnim.from = current;
                    brakeAnim.to = current + dist;
                    brakeAnim.duration = Math.max(750, (dist / 360) * 1400);
                    brakeAnim.start();
                }

                function onHoverExited() {
                    brakeAnim.stop();
                    resumeAnim.stop();

                    var current = (logoBadge.spinAngle % 360 + 360) % 360;
                    var dist = 360 - current;
                    if (dist <= 0) dist += 360;

                    resumeAnim.from = current;
                    resumeAnim.to = current + dist;
                    // Duración calibrada cinemáticamente con Easing.InQuad para que la velocidad final coincida exactamente con la velocidad del giro base (sin sobreaceleración ni corte)
                    resumeAnim.duration = Math.round((dist / 180) * 2600);
                    resumeAnim.start();
                }

                // Contenedor que rota en 3D como una ficha
                Item {
                    id: coinBody
                    anchors.fill: parent

                    // Cara frontal: LOGO
                    Item {
                        anchors.fill: parent
                        visible: logoBadge.showFront

                        transform: Rotation {
                            origin.x: 48; origin.y: 48
                            axis { x: 0; y: 1; z: 0 }
                            angle: logoBadge.spinAngle
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 74
                            height: 74
                            source: Qt.resolvedUrl("assets/panacea_bw.svg")
                            sourceSize.width: 148
                            sourceSize.height: 148
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    // Cara trasera: INFO (Panacea Config novZ)
                    Item {
                        anchors.fill: parent
                        visible: logoBadge.showBack

                        transform: Rotation {
                            origin.x: 48; origin.y: 48
                            axis { x: 0; y: 1; z: 0 }
                            angle: logoBadge.spinAngle - 180
                        }

                        // Separador central en el ecuador exacto de la ficha (96x96)
                        Rectangle {
                            id: coinSep
                            anchors.centerIn: parent
                            width: 44
                            height: 1
                            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.20)
                        }

                        // Arriba: PANACEA con su viñeta de acento
                        RowLayout {
                            anchors {
                                bottom: coinSep.top
                                bottomMargin: 9
                                horizontalCenter: parent.horizontalCenter
                            }
                            spacing: 4

                            Rectangle {
                                width: 5; height: 5; radius: 2.5
                                color: customCard.accentColor
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Text {
                                text: "PANACEA"
                                color: "#ffffff"
                                font {
                                    family: page.sys.fontFam
                                    pixelSize: 9
                                    bold: true
                                    letterSpacing: 1.2
                                }
                            }
                        }

                        // Abajo: CONFIG novZ
                        ColumnLayout {
                            anchors {
                                top: coinSep.bottom
                                topMargin: 7
                                horizontalCenter: parent.horizontalCenter
                            }
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "CONFIG"
                                color: page.sys.colMuted
                                font {
                                    family: page.sys.fontBody
                                    pixelSize: 7
                                    letterSpacing: 1.4
                                    bold: true
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "novZ"
                                color: customCard.accentColor
                                Behavior on color { ColorAnimation { duration: 200 } }
                                font {
                                    family: page.sys.fontFam
                                    pixelSize: 11
                                    bold: true
                                    letterSpacing: 1.5
                                }
                            }
                        }
                    }
                }

                // MouseArea estática sin rotación para captura de eventos perfecta
                MouseArea {
                    id: badgeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: logoBadge.onHoverEntered()
                    onExited: logoBadge.onHoverExited()
                    onClicked: {
                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        customCard.largeOpen = !customCard.largeOpen;
                    }
                }
            }
        }

        // ================= VISTA EN GRANDE EXPANDIDA (Logo Panacea B&W con Giro Continuo + Panel con Más Info Resumida) =================
        Item {
            id: largeLogoArea
            Layout.fillWidth: true
            implicitHeight: customCard.largeOpen ? (largeContentCol.implicitHeight + 16) : 0
            opacity: customCard.largeOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            clip: true

            Behavior on implicitHeight {
                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 260; easing.type: Easing.OutQuad }
            }

            ColumnLayout {
                id: largeContentCol
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 8

                // Escaparate del Logo en Grande con Giro Continuo (Panacea Nothing OS B&W)
                Item {
                    id: largeLogoContainer
                    Layout.alignment: Qt.AlignHCenter
                    width: 210
                    height: 210

                    // Logo Vectorial en Blanco y Negro (Panacea Nothing OS B&W) con giro continuo infinito
                    Image {
                        id: largeLogoImg
                        anchors.centerIn: parent
                        width: 180
                        height: 180
                        source: Qt.resolvedUrl("assets/panacea_bw.svg")
                        sourceSize.width: 360
                        sourceSize.height: 360
                        fillMode: Image.PreserveAspectFit
                        transformOrigin: Item.Center

                        scale: customCard.largeOpen ? (largeLogoMa.containsMouse ? 1.08 : 1.0) : 0.45
                        Behavior on scale {
                            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                        }

                        // Giro continuo infinito fluido del logo Panacea
                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 6000
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                            running: true
                        }
                    }

                    MouseArea {
                        id: largeLogoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                            customCard.largeOpen = false;
                        }
                    }
                }

                // Panel Resumido de Diferencias Técnicas del Sistema (Nothing OS Style)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: diffGrid.implicitHeight + 24
                    radius: 14
                    color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.025)
                    border.width: 1
                    border.color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)

                    GridLayout {
                        id: diffGrid
                        anchors.fill: parent
                        anchors.margins: 14
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 20

                        // 1. DISTRO BASE
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 5; height: 5; radius: 2.5; color: customCard.accentColor; Behavior on color { ColorAnimation { duration: 200 } } }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: page.sys.tr("SISTEMA BASE")
                                    color: page.sys.colMuted
                                    font { family: page.sys.fontBody; pixelSize: 8; letterSpacing: 1.2; bold: true }
                                }
                                Text {
                                    text: page.osName.length > 0 ? page.osName : "Linux"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }
                        }

                        // 2. KERNEL BORE
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 5; height: 5; radius: 2.5; color: customCard.accentColor; Behavior on color { ColorAnimation { duration: 200 } } }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: page.sys.tr("PLANIFICADOR KERNEL")
                                    color: page.sys.colMuted
                                    font { family: page.sys.fontBody; pixelSize: 8; letterSpacing: 1.2; bold: true }
                                }
                                Text {
                                    text: page.sys && page.sys.tr ? page.sys.tr("BORE (Baja Latencia)") : "BORE (Baja Latencia)"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }
                        }

                        // 3. SHELL DESKTOP
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 5; height: 5; radius: 2.5; color: customCard.accentColor; Behavior on color { ColorAnimation { duration: 200 } } }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: page.sys.tr("SHELL DESKTOP")
                                    color: page.sys.colMuted
                                    font { family: page.sys.fontBody; pixelSize: 8; letterSpacing: 1.2; bold: true }
                                }
                                Text {
                                    text: "Panacea (Nothing OS UI)"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }
                        }

                        // 4. CONFIG NOVZ
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 5; height: 5; radius: 2.5; color: customCard.accentColor; Behavior on color { ColorAnimation { duration: 200 } } }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: page.sys.tr("CONFIGURACIÓN")
                                    color: page.sys.colMuted
                                    font { family: page.sys.fontBody; pixelSize: 8; letterSpacing: 1.2; bold: true }
                                }
                                Text {
                                    text: page.sys && page.sys.tr ? page.sys.tr("novZ Personalizada") : "novZ Personalizada"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }
                        }

                        // 5. COMPOSITOR WAYLAND
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 5; height: 5; radius: 2.5; color: customCard.accentColor; Behavior on color { ColorAnimation { duration: 200 } } }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: page.sys.tr("COMPOSITOR")
                                    color: page.sys.colMuted
                                    font { family: page.sys.fontBody; pixelSize: 8; letterSpacing: 1.2; bold: true }
                                }
                                Text {
                                    text: "Hyprland Wayland"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }
                        }

                        // 6. PLATAFORMA / GPU
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 5; height: 5; radius: 2.5; color: customCard.accentColor; Behavior on color { ColorAnimation { duration: 200 } } }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: page.sys.tr("PLATAFORMA")
                                    color: page.sys.colMuted
                                    font { family: page.sys.fontBody; pixelSize: 8; letterSpacing: 1.2; bold: true }
                                }
                                Text {
                                    text: "i7-13650HX • RTX 5060"
                                    color: page.sys.colFg
                                    font { family: page.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }
                        }
                    }
                }

                // Botón de Cerrar Vista
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 30
                    radius: 8
                    color: closeBtnMa.containsMouse ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.12)
                                                    : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.05)
                    border.width: 1
                    border.color: closeBtnMa.containsMouse ? customCard.accentColor : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.15)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰅖"
                            color: customCard.accentColor
                            font { family: page.sys.fontFam; pixelSize: 11 }
                        }
                        Text {
                            text: page.sys.tr("CERRAR DETALLES")
                            color: "#ffffff"
                            font { family: page.sys.fontBody; pixelSize: 9; bold: true; letterSpacing: 1.3 }
                        }
                    }

                    MouseArea {
                        id: closeBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                            customCard.largeOpen = false;
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- обновление
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Версия") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: page.sys.updBusy
                          ? (page.sys.updIsReinstall ? page.sys.tr("Переустановка…") : page.sys.tr("Обновление…")) + " " + page.stepName(page.sys.updStep)
                          : page.sys.updChecking ? page.sys.tr("Проверка…")
                          : page.sys.updateAvailable ? page.sys.tr("Доступна новая версия")
                          : page.sys.updStatus === "current" ? page.sys.tr("Установлена последняя версия")
                          : page.sys.updStatus === "offline" ? page.sys.tr("Нет связи с GitHub")
                          : page.sys.updStatus === "unknown" ? page.sys.tr("Версия неизвестна: ставили не установщиком")
                          : page.sys.tr("Проверка…")
                    color: page.sys.updateAvailable ? page.sys.colOn : page.sys.colFg
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1 }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: page.sys.updError.length ? page.sys.updErrorText
                        : page.sys.updateAvailable ? page.sys.updSubject
                        : "Panacea " + page.sys.version
                          + (page.sys.updCurrent.length
                             ? " · " + page.sys.tr("сборка") + " " + page.sys.updCurrent.substring(0, 7) : "")
                    color: page.sys.updError.length ? page.sys.colCrit : page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            // Проверить · Reinstalar · Обновить
            Rectangle {
                // Ширина по содержимому, но не уже прежней
                Layout.preferredWidth: Math.max(104, checkRow.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                visible: !page.sys.updBusy
                opacity: (page.reinstallStep > 0) ? 0.4 : 1
                Behavior on opacity { NumberAnimation { duration: page.sys.animFade } }
                color: checkMa.containsMouse
                       ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                       : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06)
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                RowLayout {
                    id: checkRow
                    anchors.centerIn: parent
                    spacing: 6

                    Glyph {
                        id: checkSpin
                        visible: page.sys.updChecking
                        glyph: String.fromCodePoint(0xF0450)   // md-refresh
                        color: page.sys.colOn
                        fontFam: page.sys.fontFam
                        size: 13

                        RotationAnimator {
                            target: checkSpin
                            running: page.sys.updChecking
                            from: 0; to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                        onVisibleChanged: if (!visible) checkSpin.rotation = 0
                    }

                    Text {
                        text: page.sys.updChecking ? page.sys.tr("Проверка…")
                                                   : page.sys.tr("Проверить")
                        color: page.sys.updChecking ? page.sys.colFg : page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                    }
                }
                MouseArea {
                    id: checkMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.sys.updChecking && page.reinstallStep === 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: page.sys.checkUpdate()
                }
            }

            // Reinstalar con 2 confirmaciones consecutivas y cooldown obligatorio de 5s por confirmación
            Rectangle {
                id: reinstallBtn
                visible: !page.sys.updBusy
                Layout.preferredWidth: Math.max(110, reinstallRow.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                color: {
                    if (page.reinstallStep === 2 && page.reinstallCooldown === 0) {
                        return reinstallMa.containsMouse
                               ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b, 0.40)
                               : Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b, 0.25);
                    }
                    if (page.reinstallStep > 0) {
                        return (reinstallMa.containsMouse && page.reinstallCooldown === 0)
                               ? Qt.rgba(page.sys.colWarn.r, page.sys.colWarn.g, page.sys.colWarn.b, 0.35)
                               : Qt.rgba(page.sys.colWarn.r, page.sys.colWarn.g, page.sys.colWarn.b, 0.16);
                    }
                    return reinstallMa.containsMouse
                           ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                           : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06);
                }
                border.width: page.reinstallStep > 0 ? 1 : 0
                border.color: page.reinstallStep === 2 ? page.sys.colCrit : page.sys.colWarn
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                RowLayout {
                    id: reinstallRow
                    anchors.centerIn: parent
                    spacing: 6

                    Glyph {
                        id: reinstallIcon
                        visible: page.reinstallStep === 0 || page.reinstallCooldown === 0
                        glyph: page.reinstallStep === 2
                               ? String.fromCodePoint(0xF0026) // md-alert
                               : String.fromCodePoint(0xF0450) // md-refresh
                        color: page.reinstallStep === 2
                               ? page.sys.colCrit
                               : (page.reinstallStep === 1 ? page.sys.colWarn : page.sys.colMuted)
                        fontFam: page.sys.fontFam
                        size: 13
                    }

                    Text {
                        text: {
                            if (page.reinstallStep === 0)
                                return page.sys.tr("Reinstalar");
                            if (page.reinstallCooldown > 0)
                                return page.sys.tr("Espera %1s…").arg(page.reinstallCooldown);
                            if (page.reinstallStep === 1)
                                return page.sys.tr("Confirmar (1/2)");
                            return page.sys.tr("Confirmar y reinstalar");
                        }
                        color: {
                            if (page.reinstallStep === 2 && page.reinstallCooldown === 0)
                                return page.sys.colFg;
                            if (page.reinstallStep > 0 && page.reinstallCooldown > 0)
                                return page.sys.colMuted;
                            if (page.reinstallStep === 1 && page.reinstallCooldown === 0)
                                return page.sys.colWarn;
                            return page.sys.colMuted;
                        }
                        font {
                            family: page.sys.fontBody
                            pixelSize: page.sys.fontSize - 3
                            bold: page.reinstallStep > 0 && page.reinstallCooldown === 0
                        }
                    }
                }

                MouseArea {
                    id: reinstallMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.sys.updBusy && (page.reinstallStep === 0 || page.reinstallCooldown === 0)
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (page.reinstallStep === 0) {
                            page.reinstallStep = 1;
                            page.reinstallCooldown = 5;
                            reinstallDisarmTimer.restart();
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        } else if (page.reinstallStep === 1 && page.reinstallCooldown === 0) {
                            page.reinstallStep = 2;
                            page.reinstallCooldown = 5;
                            reinstallDisarmTimer.restart();
                            if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                        } else if (page.reinstallStep === 2 && page.reinstallCooldown === 0) {
                            page.reinstallStep = 0;
                            page.cancelReinstall();
                            if (page.sys && page.sys.playSound) page.sys.playSound("lowbatt");
                            page.sys.applyReinstall();
                        }
                    }
                }
            }

            // Botón cancelar confirmación de reinstalación
            Rectangle {
                id: cancelReinstallBtn
                visible: !page.sys.updBusy && page.reinstallStep > 0
                Layout.preferredWidth: Math.max(88, cancelRow.implicitWidth + 20)
                Layout.preferredHeight: 32
                radius: 10
                color: cancelMa.containsMouse
                       ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                       : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06)
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                RowLayout {
                    id: cancelRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: page.sys.tr("Cancelar")
                        color: page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                    }
                }

                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.cancelReinstall();
                        if (page.sys && page.sys.playSound) page.sys.playSound("tock");
                    }
                }
            }

            Rectangle {
                // Ширина по содержимому, но не уже прежней: надпись задана числом
                // только на глаз, и на другом языке или крупном шрифте она вылезала
                // за края плашки.
                Layout.preferredWidth: Math.max(120, updRow.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                visible: !page.sys.updIsReinstall && (page.sys.updateAvailable || page.sys.updBusy)
                opacity: page.sys.updBusy ? 0.6 : 1
                color: updMa.containsMouse && !page.sys.updBusy
                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.34)
                       : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                border.width: 1
                border.color: page.sys.colOn
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: page.sys.updBusy ? page.sys.tr("Идёт…") : page.sys.tr("Обновить")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                }
                MouseArea {
                    id: updMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.sys.updBusy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.sys.applyUpdate()
                }
            }
        }

        // Banner de advertencia de reinstalación limpia
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: page.reinstallStep > 0 && !page.sys.updBusy
            radius: 10
            color: Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b, 0.12)
            border.width: 1
            border.color: page.reinstallStep === 2 ? page.sys.colCrit : page.sys.colWarn
            implicitHeight: reinstallWarnCol.implicitHeight + 20

            ColumnLayout {
                id: reinstallWarnCol
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 12
                }
                spacing: 4

                RowLayout {
                    spacing: 8
                    Glyph {
                        glyph: String.fromCodePoint(0xF0026)
                        color: page.reinstallStep === 2 ? page.sys.colCrit : page.sys.colWarn
                        fontFam: page.sys.fontFam
                        size: 15
                    }
                    Text {
                        text: page.reinstallStep === 1
                              ? page.sys.tr("Шаг 1 из 2: Будет выполнена чистая переустановка Panacea_novZ")
                              : page.sys.tr("Шаг 2 из 2: Требуется окончательное подтверждение")
                        color: page.reinstallStep === 2 ? page.sys.colCrit : page.sys.colWarn
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: true }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: page.reinstallStep === 1
                          ? page.sys.tr("Внимание! Panacea_novZ будет переустановлен с нуля. Все локальные настройки будут удалены, а кэш (~/.cache/panacea) очищен для чистой установки.")
                          : page.sys.tr("Это действие загрузит последнюю версию из GitHub, удалит текущие настройки и перезапустит окружение.")
                    color: page.sys.colFg
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }

        // Ход обновления: полоса и этапы.
        //
        // Байты не считаем — update.sh их не знает. Зато знает свои этапы, и их
        // ровно столько, сколько есть: полоса идёт по ним, а не по времени.
        // Ползти вслепую по таймеру было бы враньём — на медленной сети она
        // добралась бы до конца задолго до самого обновления.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: page.sys.updBusy
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * page.sys.updStepPercent / 100
                    color: page.sys.colOn
                    Behavior on width {
                        NumberAnimation { duration: page.sys.animMs; easing.type: Easing.OutQuint }
                    }
                }
            }

            // Этапы подписью, а не только процентом: «скачивание» и «установка»
            // объясняют паузу, а «73%» — нет.
            RowLayout {
                    id: updRow
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: page.stepName(page.sys.updStep)
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
                Text {
                    text: page.sys.updStepPercent + "%"
                    color: page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: page.reinstallStep === 0 && !page.sys.updIsReinstall
            text: page.sys.tr("Настройки, сочетания клавиш и обои остаются на месте: перед установкой они уносятся в сторону и возвращаются после.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }


    // ------------------------------------------------------------- нагрузка
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сейчас") }

        component Meter: ColumnLayout {
            property string label: ""
            property string value: ""
            property real frac: 0
            property color tint: page.sys.colOn

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: label
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
                Text {
                    text: value
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, frac))
                    height: parent.height
                    radius: parent.radius
                    color: tint
                    Behavior on width { NumberAnimation { duration: page.sys.animFade } }
                }
            }
        }

        // Показания системные, а не оболочкины: в них попадают браузер,
        // мессенджеры и всё остальное. Сколько занимает сама Panacea —
        // отдельной строкой ниже, иначе шесть гигабайт читаются как её вина.
        Meter {
            label: page.sys.tr("Оперативная память системы")
            value: page.memUsed.toFixed(1) + " / " + page.memTotal.toFixed(1) + " GiB"
            frac: page.memTotal > 0 ? page.memUsed / page.memTotal : 0
        }

        Meter {
            visible: page.swapTotal > 0
            label: page.sys.tr("Подкачка")
            value: page.swapUsed.toFixed(1) + " / " + page.swapTotal.toFixed(1) + " GiB"
            frac: page.swapTotal > 0 ? page.swapUsed / page.swapTotal : 0
        }

        Meter {
            label: page.sys.tr("Диск /")
            value: page.diskUsed.toFixed(0) + " / " + page.diskTotal.toFixed(0) + " GiB"
            frac: page.diskTotal > 0 ? page.diskUsed / page.diskTotal : 0
        }

        Meter {
            visible: page.tempCpu >= 0
            label: page.sys.tr("Температура процессора")
            value: page.tempCpu.toFixed(0) + " °C"
            // шкала до 100 °C: выше 80 столбик становится тревожным
            frac: page.tempCpu / 100
            tint: page.tempCpu >= 80 ? page.sys.colCrit : page.sys.colOn
        }

        Meter {
            visible: page.tempGpu >= 0
            label: page.sys.tr("Температура видео")
            value: page.tempGpu.toFixed(0) + " °C"
            frac: page.tempGpu / 100
            tint: page.tempGpu >= 85 ? page.sys.colCrit : page.sys.colOn
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Text {
                text: page.sys.tr("Нагрузка") + ": " + page.load1.toFixed(2)
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: "Panacea: " + page.selfMb.toFixed(0) + " MiB"
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: page.sys.tr("Процессов") + ": " + page.procs
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Item { Layout.fillWidth: true }
        }
    }

    // ------------------------------------------------------------- машина
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Машина") }

        component Fact: RowLayout {
            property string k: ""
            property string v: ""

            Layout.fillWidth: true
            visible: v.length > 0
            spacing: 12

            Text {
                text: k
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: v
                color: page.sys.colFg
                elide: Text.ElideRight
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }

        Fact { k: page.sys.tr("Система");    v: page.osName }
        Fact { k: page.sys.tr("Ядро");       v: page.kernel }
        Fact { k: page.sys.tr("Композитор"); v: page.wm }
        Fact { k: page.sys.tr("Процессор");  v: page.cpuName }
        Fact { k: page.sys.tr("Видео");      v: page.gpuName }
        Fact { k: page.sys.tr("Имя машины"); v: page.host }
        Fact { k: page.sys.tr("Аптайм");     v: page.uptime }
        Fact { k: page.sys.tr("Оболочка");   v: "Panacea " + page.sys.version }
    }

    // ------------------------------------------------------------- сброс
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сброс") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.armed
                      ? page.sys.tr("Нажмите ещё раз — все настройки вернутся к заводским.")
                      : page.sys.tr("Вернуть все настройки к заводским. Сочетания клавиш останутся как есть.")
                color: page.armed ? page.sys.colCrit : page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            Rectangle {
                // Ширина по надписи, но не уже прежней: «Точно сбросить» и
                // «Сбросить всё» разной длины, а по-английски обе длиннее —
                // на глаз подобранные 140 их уже не вмещали.
                Layout.preferredWidth: Math.max(140, resetLabel.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                color: page.armed
                       ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b,
                                 resetMa.containsMouse ? 0.40 : 0.26)
                       : (resetMa.containsMouse
                          ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                          : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06))
                border.width: page.armed ? 1 : 0
                border.color: page.sys.colCrit
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: page.armed ? page.sys.tr("Точно сбросить") : page.sys.tr("Сбросить всё")
                    color: page.armed ? page.sys.colFg : page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }

                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Сброс в два нажатия: одно случайное движение мышью не
                    // должно стирать всю настроенную оболочку.
                    onClicked: {
                        if (page.armed) { page.sys.resetCfg(); page.armed = false; }
                        else { page.armed = true; disarm.restart(); }
                    }
                }
            }
        }
    }

}
