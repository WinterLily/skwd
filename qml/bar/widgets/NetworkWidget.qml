import "../.."
import QtQuick
import Quickshell.Io

Item {
    id: root

    implicitWidth: _icon.implicitWidth
    implicitHeight: _icon.implicitHeight

    QtObject {
        id: _info

        property string type: "none" // "none" | "eth" | "wifi"
        property int signalStrength: 0

        Component.onCompleted: _proc.running = true
    }

    Text {
        id: _icon

        text: {
            if (_info.type === "eth")
                return "󰈀";

            if (_info.type === "wifi") {
                let s = _info.signalStrength;
                if (s < 25)
                    return "󰤟";

                if (s < 50)
                    return "󰤢";

                if (s < 75)
                    return "󰤥";

                return "󰤨";
            }
            return "󰤭";
        }
        font.pixelSize: 14
        font.family: Style.fontFamilyNerdIcons
        color: _info.type === "none" ? Colors.tertiary : Colors.primary

        Behavior on color {
            ColorAnimation {
                duration: 200
            }

        }

    }

    Process {
        id: _proc

        command: ["sh", "-c", ["for iface in $(ls /sys/class/net/ 2>/dev/null); do", "  [ \"$iface\" = lo ] && continue", "  [ \"$(cat /sys/class/net/$iface/operstate 2>/dev/null)\" = up ] || continue", "  if [ -d \"/sys/class/net/$iface/wireless\" ]; then", "    signal=$(iw dev \"$iface\" link 2>/dev/null | awk '/signal:/{print $2}')", "    [ -n \"$signal\" ] && printf 'wifi:%s\\n' \"$signal\" && exit 0", "  else", "    printf 'eth\\n' && exit 0", "  fi", "done", "printf 'none\\n'"].join("\n")]
        onExited: _pollTimer.start()

        stdout: SplitParser {
            onRead: (data) => {
                let trimmed = data.trim();
                if (trimmed.startsWith("wifi:")) {
                    _info.type = "wifi";
                    let rssi = parseInt(trimmed.split(":")[1] || "-90");
                    _info.signalStrength = Math.max(0, Math.min(100, (rssi + 90) * 100 / 60));
                } else if (trimmed === "eth") {
                    _info.type = "eth";
                    _info.signalStrength = 0;
                } else {
                    _info.type = "none";
                    _info.signalStrength = 0;
                }
            }
        }

    }

    Timer {
        id: _pollTimer

        interval: Config.wifiPollMs || 5000
        onTriggered: _proc.running = true
    }

}
