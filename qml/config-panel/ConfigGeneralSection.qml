import ".."
import QtQuick

Column {
    id: root

    property var panel

    width: parent.width
    spacing: 8

    ConfigSectionTitle {
        text: "GENERAL"
    }

    ConfigTextField {
        label: "Compositor"
        value: panel.getNested(panel.configData, ["compositor"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["compositor"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Terminal"
        value: panel.getNested(panel.configData, ["terminal"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["terminal"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Monitor"
        value: panel.getNested(panel.configData, ["monitor"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["monitor"], v);
            panel.configDataChanged();
        }
    }

    ConfigToggle {
        label: "Mute wallpaper audio"
        checked: panel.getNested(panel.configData, ["wallpaperMute"], true)
        onToggled: (v) => {
            panel.setNested(panel.configData, ["wallpaperMute"], v);
            panel.configDataChanged();
        }
    }

    ConfigSectionTitle {
        text: "PATHS"
        topPad: 16
    }

    ConfigTextField {
        label: "Scripts"
        value: panel.getNested(panel.configData, ["paths", "scripts"], "")
        placeholder: "(default: install dir)"
        onEdited: (v) => {
            panel.setNested(panel.configData, ["paths", "scripts"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Cache"
        value: panel.getNested(panel.configData, ["paths", "cache"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["paths", "cache"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Wallpaper"
        value: panel.getNested(panel.configData, ["paths", "wallpaper"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["paths", "wallpaper"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Steam workshop"
        value: panel.getNested(panel.configData, ["paths", "steamWorkshop"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["paths", "steamWorkshop"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Steam WE assets"
        value: panel.getNested(panel.configData, ["paths", "steamWeAssets"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["paths", "steamWeAssets"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "Steam"
        value: panel.getNested(panel.configData, ["paths", "steam"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["paths", "steam"], v);
            panel.configDataChanged();
        }
    }

    ConfigSectionTitle {
        text: "MATUGEN"
        topPad: 16
    }

    ConfigTextField {
        label: "Scheme type"
        value: panel.getNested(panel.configData, ["matugen", "schemeType"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["matugen", "schemeType"], v);
            panel.configDataChanged();
        }
    }

    ConfigTextField {
        label: "KDE color scheme"
        value: panel.getNested(panel.configData, ["matugen", "kdeColorScheme"], "")
        onEdited: (v) => {
            panel.setNested(panel.configData, ["matugen", "kdeColorScheme"], v);
            panel.configDataChanged();
        }
    }

}
