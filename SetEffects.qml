import QtQuick
import QtQuick.Layouts

// Panel de Ajustes: Micro-animaciones y Efectos de Detalle
// Permite configurar de forma granular y opcional los efectos visuales,
// micro-interacciones y animaciones en iconos, tarjetas y listas.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 14

    // Encabezado descriptivo
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: page.sys.tr("Efectos & Micro-animaciones")
            color: page.sys.colFg
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize + 2; bold: true }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Personaliza las animaciones opcionales de los elementos de la interfaz. Todas vienen activadas por defecto para una experiencia suave y orgánica.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }
    }

    // -------------------------------------------------- 1. Menú de Apagado
    SetCard {
        sys: page.sys

        Text {
            text: page.sys.tr("Menú de Apagado")
            color: page.sys.colFg
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Animaciones en iconos de apagado")
            sub: page.sys.tr("Flotación en Suspender, empuje en Cerrar sesión, giro de 360° en Reiniciar y latido en Apagar.")
            on: page.sys.cfg.animPowerIcons
            onToggled: v => { page.sys.cfg.animPowerIcons = v; page.sys.saveCfg(); }
        }
    }

    // -------------------------------------------------- 2. Centro de Control
    SetCard {
        sys: page.sys

        Text {
            text: page.sys.tr("Centro de Control y Tarjetas")
            color: page.sys.colFg
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Rotación en botón de opciones (󰇙)")
            sub: page.sys.tr("Giro suave de 90° con escala al pasar el ratón sobre el botón de tres puntos de las tarjetas.")
            on: page.sys.cfg.animTileRotate
            onToggled: v => { page.sys.cfg.animTileRotate = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Micro-escala en tarjetas principales")
            sub: page.sys.tr("Presencia visual y brillo de borde al posar el cursor sobre Wi-Fi, Bluetooth y accesos rápidos.")
            on: page.sys.cfg.animTileHover
            onToggled: v => { page.sys.cfg.animTileHover = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Indicadores de navegación (󰅂)")
            sub: page.sys.tr("Desplazamiento horizontal fluido (+2px) del chevron al posar el cursor en tarjetas con submenú.")
            on: page.sys.cfg.animChevronSlide
            onToggled: v => { page.sys.cfg.animChevronSlide = v; page.sys.saveCfg(); }
        }
    }

    // -------------------------------------------------- 3. Listas y Deslizadores
    SetCard {
        sys: page.sys

        Text {
            text: page.sys.tr("Listas, Deslizadores y Estados")
            color: page.sys.colFg
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Desplazamiento lateral en listas")
            sub: page.sys.tr("Micro-desplazamiento suave (+2px/+3px) al posar el cursor en audio, portapapeles, lanzador y redes.")
            on: page.sys.cfg.animMenuSlide
            onToggled: v => { page.sys.cfg.animMenuSlide = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Brillo dinámico en deslizadores")
            sub: page.sys.tr("Aumento de luminosidad en la pista de volumen y brillo al interactuar con el puntero.")
            on: page.sys.cfg.animSlidersGlow
            onToggled: v => { page.sys.cfg.animSlidersGlow = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Micro-elevación en hover de tarjetas")
            sub: page.sys.tr("Elevación vertical (-2px) y respuesta táctil en botones de acción y controles.")
            on: page.sys.cfg.animCardLift
            onToggled: v => { page.sys.cfg.animCardLift = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Respiración en puntos de estado")
            sub: page.sys.tr("Pulsación continua y suave en indicadores de grabación activa y estado del sistema.")
            on: page.sys.cfg.animStatusPulse
            onToggled: v => { page.sys.cfg.animStatusPulse = v; page.sys.saveCfg(); }
        }
    }
}
