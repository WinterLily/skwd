pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: colorMode

    property bool isDark: true

    function toggle() {
        isDark = !isDark;
        _persist();
    }

    function _persist() {
        _modeFile.setText(isDark ? "dark" : "light");
    }

    onIsDarkChanged: _applySystemTheme()

    function _applySystemTheme() {
        var scheme = isDark ? "prefer-dark" : "prefer-light";
        var gtkTheme = isDark ? "adw-gtk3-dark" : "adw-gtk3";
        _systemThemeProcess.command = [
            "sh", "-c",
            "gsettings set org.gnome.desktop.interface color-scheme '" + scheme + "' && " +
            "gsettings set org.gnome.desktop.interface gtk-theme '" + gtkTheme + "'"
        ];
        _systemThemeProcess.running = true;
    }

    property var _systemThemeProcess: Process {}

    property var _modeFile: FileView {
        path: Config.cacheDir + "/colormode"
        preload: true
        onLoaded: {
            var txt = colorMode._modeFile.text().trim();
            colorMode.isDark = (txt !== "light");
        }
    }
}
