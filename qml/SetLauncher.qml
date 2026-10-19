import QtQuick
import QtQuick.Layouts

// Launcher y Menús. Configuraciones del lanzador de aplicaciones, calculadora, historial y páginas vecinas.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Lanzador de Aplicaciones") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Activar lanzador de aplicaciones")
            sub: page.sys.tr("Búsqueda instantánea de aplicaciones y accesos directos (Super+Espacio).")
            on: page.sys.cfg.featLauncher
            onToggled: v => { page.sys.cfg.featLauncher = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Filas visibles máximas")
            from: 4
            to: 12
            step: 1
            value: page.sys.cfg.launcherMaxRows !== undefined ? page.sys.cfg.launcherMaxRows : 6
            suffix: "filas"
            onMoved: v => { page.sys.cfg.launcherMaxRows = Math.round(v); page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Evaluación matemática instantánea")
            sub: page.sys.tr("Calcula operaciones y fórmulas directamente desde la barra de búsqueda.")
            on: page.sys.cfg.launcherCalc !== false
            onToggled: v => { page.sys.cfg.launcherCalc = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Historial de aplicaciones recientes")
            sub: page.sys.tr("Muestra las aplicaciones utilizadas con mayor frecuencia antes de buscar.")
            on: page.sys.cfg.launcherRecent !== false
            onToggled: v => { page.sys.cfg.launcherRecent = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Barra de filtros por categoría")
            sub: page.sys.tr("Filtros rápidos (Todas, Recientes, Internet, Multimedia, Sistema).")
            on: page.sys.cfg.launcherCategories !== false
            onToggled: v => { page.sys.cfg.launcherCategories = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Páginas y Herramientas Integradas") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Historial del Portapapeles")
            sub: page.sys.tr("Acceso a clips de texto e imágenes copiadas (Super+V).")
            on: page.sys.cfg.featClipboard
            onToggled: v => { page.sys.cfg.featClipboard = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Gestor de Contraseñas (Vault)")
            sub: page.sys.tr("Bóveda cifrada para almacenar claves de forma segura.")
            on: page.sys.cfg.featVault
            onToggled: v => { page.sys.cfg.featVault = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Captura inteligente de contraseñas")
            sub: page.sys.tr("Ofrecer guardar automáticamente claves copiadas en el portapapeles.")
            on: page.sys.cfg.vaultCapture
            onToggled: v => { page.sys.cfg.vaultCapture = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Explorador de Archivos")
            sub: page.sys.tr("Navegador de archivos Nothing OS integrado (Super+E).")
            on: page.sys.cfg.featFiles
            onToggled: v => { page.sys.cfg.featFiles = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Explorador en ventana independiente")
            sub: page.sys.tr("Abre el explorador como ventana flotante de Hyprland en vez de en el notch.")
            on: page.sys.cfg.filesWindow
            onToggled: v => { page.sys.cfg.filesWindow = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Calendario")
            sub: page.sys.tr("Agenda, fecha y reloj de zona horaria.")
            on: page.sys.cfg.featCalendar
            onToggled: v => { page.sys.cfg.featCalendar = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Fondos de Pantalla y Temas")
            sub: page.sys.tr("Selector visual con extracción de paletas dinámicas.")
            on: page.sys.cfg.featThemes
            onToggled: v => { page.sys.cfg.featThemes = v; page.sys.saveCfg(); }
        }
    }
}
