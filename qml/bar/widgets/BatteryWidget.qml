import QtQuick
import Quickshell.Io
import "../.."

Item {
    id: root

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight
    visible: _info.present

    QtObject {
        id: _info
        property bool present: false
        property int percent: 0
        property string status: "Unknown"
        Component.onCompleted: _proc.running = true
    }

    Row {
        id: _row
        spacing: 4

        Text {
            text: {
                let p = _info.percent;
                let charging = _info.status === "Charging";
                let full = _info.status === "Full" || (_info.status === "Not charging" && p >= 98);
                if (full)     return "󰁹";
                if (charging) return p < 10 ? "󰢟" : p < 20 ? "󰢜" : p < 30 ? "󰂼" : p < 40 ? "󰂽" :
                                     p < 50 ? "󰂾" : p < 60 ? "󰂿" : p < 70 ? "󰃀" : p < 80 ? "󰃁" :
                                     p < 90 ? "󰃂" : "󰃃";
                if (p < 10)  return "󰂎";
                if (p < 20)  return "󰁺";
                if (p < 30)  return "󰁻";
                if (p < 40)  return "󰁼";
                if (p < 50)  return "󰁽";
                if (p < 60)  return "󰁾";
                if (p < 70)  return "󰁿";
                if (p < 80)  return "󰂀";
                if (p < 90)  return "󰂁";
                return "󰂂";
            }
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: {
                if (_info.status === "Charging") return Colors.primary;
                if (_info.percent < 20) return "#e06c75";
                return Colors.primary;
            }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
            text: _info.percent + "%"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: _info.percent < 20 && _info.status === "Discharging" ? "#e06c75" : Colors.tertiary
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Process {
        id: _proc
        command: ["sh", "-c", [
            "bat=$(ls /sys/class/power_supply/ 2>/dev/null | grep -i 'bat\\|BAT' | head -1)",
            "[ -z \"$bat\" ] && exit 0",
            "cap=$(cat /sys/class/power_supply/$bat/capacity 2>/dev/null)",
            "sts=$(cat /sys/class/power_supply/$bat/status 2>/dev/null)",
            "printf '%s:%s\\n' \"$sts\" \"$cap\""
        ].join("\n")]
        onExited: _pollTimer.start()
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (!trimmed) return;
                let parts = trimmed.split(":");
                _info.present = true;
                _info.status = parts[0] || "Unknown";
                _info.percent = parseInt(parts[1] || "0");
            }
        }
    }

    Timer {
        id: _pollTimer
        interval: 30000
        onTriggered: _proc.running = true
    }
}
