import QtQuick
import Quickshell.Io
import "../.."

Item {
    id: root

    signal clicked()

    // Exposed for WiFiDropdown
    readonly property string ssid: _info.ssid
    readonly property int signalStrength: _info.signalStrength

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight

    QtObject {
        id: _info
        property string ssid: ""
        property string pendingSsid: ""
        property int signalStrength: 0
        Component.onCompleted: _proc.running = true
    }

    Row {
        id: _row
        spacing: 4

        Text {
            text: {
                let s = _info.signalStrength;
                if (s < 25) return "󰤟";
                if (s < 50) return "󰤢";
                if (s < 75) return "󰤥";
                return "󰤨";
            }
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
        }
        Text {
            text: _info.ssid
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Process {
        id: _proc
        command: ["sh", "-c",
            "iwctl station " + Config.wifiInterface + " show 2>/dev/null | " +
            "awk '/Connected network/{print $3} /^[[:space:]]*RSSI/{gsub(/-| dBm/,\"\"); print $2}'"
        ]
        onExited: {
            _info.ssid = _info.pendingSsid !== "" ? _info.pendingSsid : "";
            _info.pendingSsid = "";
            _pollTimer.start();
        }
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed && !trimmed.match(/^-?[0-9]+$/)) {
                    _info.pendingSsid = trimmed;
                } else if (trimmed.match(/^-?[0-9]+$/)) {
                    let rssi = -parseInt(trimmed);
                    _info.signalStrength = Math.max(0, Math.min(100, (rssi + 90) * 100 / 60));
                }
            }
        }
    }

    Timer {
        id: _pollTimer
        interval: Config.wifiPollMs
        onTriggered: _proc.running = true
    }
}
