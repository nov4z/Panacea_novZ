import QtQuick
import QtQuick.Layouts

// Media. Настроек здесь немного: плеер либо есть, либо нет, а всё остальное
// — что именно он показывает в свёрнутом острове.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Плеер") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Страница медиа")
            sub: page.sys.tr("Обложка, перемотка и переключение источника звука.")
            on: page.sys.cfg.featMedia
            onToggled: v => { page.sys.cfg.featMedia = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Что играет — в свёрнутом острове")
            on: page.sys.cfg.featPlayer
            onToggled: v => { page.sys.cfg.featPlayer = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Звук") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Громкость и устройства")
            on: page.sys.cfg.featAudio
            onToggled: v => { page.sys.cfg.featAudio = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Показывать всплеск при смене громкости")
            sub: page.sys.tr("Полоска поверх экрана на клавиши громкости и яркости.")
            on: page.sys.cfg.featOsd
            onToggled: v => { page.sys.cfg.featOsd = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Efectos Visuales de Portada & Ondas") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Pulsación de carátula (Cover Bounce)")
            sub: page.sys.tr("La carátula reacciona dinámicamente al ritmo y graves de la música.")
            on: page.sys.cfg.musicCoverBounce !== false
            onToggled: v => { page.sys.cfg.musicCoverBounce = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Onda acústica tras la carátula (Cover Ripple)")
            sub: page.sys.tr("Emite anillos luminosos reactivos alrededor de la portada durante la reproducción.")
            on: page.sys.cfg.musicCoverRipple !== false
            onToggled: v => { page.sys.cfg.musicCoverRipple = v; page.sys.saveCfg(); }
        }

        SetSelect {
            sys: page.sys
            enabled: page.sys.cfg.musicCoverRipple !== false
            opacity: enabled ? 1.0 : 0.4
            label: page.sys.tr("Forma de la onda tras la carátula")
            options: [
                { id: "0", text: page.sys.tr("Circular") },
                { id: "1", text: page.sys.tr("Silueta") },
                { id: "2", text: page.sys.tr("Recta") }
            ]
            value: String(page.sys.cfg.musicCoverRippleShape !== undefined ? page.sys.cfg.musicCoverRippleShape : 0)
            onPicked: id => {
                page.sys.cfg.musicCoverRippleShape = parseInt(id) || 0;
                page.sys.saveCfg();
            }
        }
    }

    // Настроек записи здесь нет намеренно: частота кадров, звук системы
    // и микрофон правятся прямо на странице записи, где их и видно во время
    // работы. Дубль в настройках только расходился бы с ней.
}
