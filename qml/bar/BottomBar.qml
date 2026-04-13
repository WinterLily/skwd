import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import ".."

PanelWindow {
    id: bottomBar

    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "bottombar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
        left: true
        right: true
    }

    property real barHeight: 32
    property real diagSlant: 28

    implicitHeight: barHeight
    exclusiveZone: barHeight
    color: "transparent"

    mask: Region {
        x: bottomBar.width - cornerPanel.width
        y: 0
        width: cornerPanel.width
        height: bottomBar.barHeight
    }

    QtObject {
        id: bluetoothInfo
        property var connectedDevices: {
            if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.devices)
                return [];
            return Bluetooth.defaultAdapter.devices.values.filter(dev => dev && dev.connected);
        }
        property string batteryText: {
            let batteries = connectedDevices.filter(d => d.batteryAvailable && d.battery > 0).map(d => Math.round(d.battery * 100) + "%");
            return batteries.length > 0 ? batteries[0] : "";
        }
    }

    Item {
        id: cornerPanel
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: rightContent.implicitWidth + bottomBar.diagSlant + 24

        Canvas {
            id: bg
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.beginPath();
                ctx.moveTo(bottomBar.diagSlant, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1.0);
                ctx.fill();

                if (Config.accentEdges) {
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    ctx.lineTo(bottomBar.diagSlant, 0);
                    ctx.lineTo(width, 0);
                    ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1.0);
                    ctx.lineWidth = 1.5;
                    ctx.lineJoin = "miter";
                    ctx.stroke();
                }
            }
            Connections {
                target: Colors
                function onSurfaceChanged() { bg.requestPaint(); }
                function onPrimaryChanged() { bg.requestPaint(); }
            }
        }

        Row {
            id: rightContent
            anchors.horizontalCenter: cornerPanel.horizontalCenter
            anchors.horizontalCenterOffset: bottomBar.diagSlant / 2
            anchors.verticalCenter: cornerPanel.verticalCenter
            spacing: 14

            // Light / dark mode toggle
            Item {
                id: modeToggle
                implicitWidth: modeIcon.implicitWidth
                implicitHeight: modeIcon.implicitHeight
                visible: Config.bottomModeToggleEnabled

                Text {
                    id: modeIcon
                    text: ColorMode.isDark ? "󰖔" : "󰖙"
                    font.pixelSize: 16
                    font.family: Style.fontFamilyNerdIcons
                    color: Colors.primary

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ColorMode.toggle()
                }
            }

            Item {
                id: bluetoothWidget
                implicitWidth: bluetoothRow.implicitWidth
                implicitHeight: bluetoothRow.implicitHeight
                visible: Config.bottomBluetoothEnabled

                Row {
                    id: bluetoothRow
                    spacing: 4
                    Text {
                        text: "󰂯"
                        font.pixelSize: 14
                        font.family: Style.fontFamilyNerdIcons
                        color: bluetoothInfo.batteryText !== "" ? Colors.primary : Colors.tertiary

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }
                    Text {
                        text: bluetoothInfo.batteryText
                        visible: bluetoothInfo.batteryText !== ""
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: Style.fontFamily
                        color: Colors.tertiary
                    }
                }
            }

            Item {
                id: networkWidget
                implicitWidth: networkIcon.implicitWidth
                implicitHeight: networkIcon.implicitHeight
                visible: Config.bottomNetworkEnabled

                QtObject {
                    id: networkInfo
                    property string type: "none"  // "none", "eth", "wifi"
                    property int signalStrength: 0
                    Component.onCompleted: networkProcess.running = true
                }

                Text {
                    id: networkIcon
                    text: {
                        if (networkInfo.type === "eth") return "󰈀";
                        if (networkInfo.type === "wifi") {
                            let s = networkInfo.signalStrength;
                            if (s < 25) return "󰤟";
                            if (s < 50) return "󰤢";
                            if (s < 75) return "󰤥";
                            return "󰤨";
                        }
                        return "󰤭";
                    }
                    font.pixelSize: 14
                    font.family: Style.fontFamilyNerdIcons
                    color: networkInfo.type === "none" ? Colors.tertiary : Colors.primary

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                Process {
                    id: networkProcess
                    command: ["sh", "-c", [
                        "for iface in $(ls /sys/class/net/ 2>/dev/null); do",
                        "  [ \"$iface\" = lo ] && continue",
                        "  [ \"$(cat /sys/class/net/$iface/operstate 2>/dev/null)\" = up ] || continue",
                        "  if [ -d \"/sys/class/net/$iface/wireless\" ]; then",
                        "    signal=$(iw dev \"$iface\" link 2>/dev/null | awk '/signal:/{print $2}')",
                        "    [ -n \"$signal\" ] && printf 'wifi:%s\\n' \"$signal\" && exit 0",
                        "  else",
                        "    printf 'eth\\n' && exit 0",
                        "  fi",
                        "done",
                        "printf 'none\\n'"
                    ].join("\n")]
                    onExited: networkPollTimer.start()
                    stdout: SplitParser {
                        onRead: data => {
                            let trimmed = data.trim();
                            if (trimmed.startsWith("wifi:")) {
                                networkInfo.type = "wifi";
                                let rssi = parseInt(trimmed.split(":")[1] || "-90");
                                networkInfo.signalStrength = Math.max(0, Math.min(100, (rssi + 90) * 100 / 60));
                            } else if (trimmed === "eth") {
                                networkInfo.type = "eth";
                                networkInfo.signalStrength = 0;
                            } else {
                                networkInfo.type = "none";
                                networkInfo.signalStrength = 0;
                            }
                        }
                    }
                }

                Timer {
                    id: networkPollTimer
                    interval: Config.wifiPollMs || 5000
                    onTriggered: networkProcess.running = true
                }
            }

            // System battery
            Item {
                id: batteryWidget
                implicitWidth: batteryRow.implicitWidth
                implicitHeight: batteryRow.implicitHeight
                visible: Config.bottomBatteryEnabled && batteryInfo.present

                QtObject {
                    id: batteryInfo
                    property bool present: false
                    property int percent: 0
                    property string status: "Unknown"  // "Charging", "Discharging", "Full", "Not charging"
                    Component.onCompleted: batteryProcess.running = true
                }

                Row {
                    id: batteryRow
                    spacing: 4
                    Text {
                        text: {
                            let p = batteryInfo.percent;
                            let charging = batteryInfo.status === "Charging";
                            let full = batteryInfo.status === "Full" || (batteryInfo.status === "Not charging" && p >= 98);
                            if (full)     return "󰁹";
                            if (charging) return p < 10 ? "󰢟" : p < 20 ? "󰢜" : p < 30 ? "󰂼" : p < 40 ? "󰂽" : p < 50 ? "󰂾" : p < 60 ? "󰂿" : p < 70 ? "󰃀" : p < 80 ? "󰃁" : p < 90 ? "󰃂" : "󰃃";
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
                            if (batteryInfo.status === "Charging") return Colors.primary;
                            if (batteryInfo.percent < 20) return "#e06c75";
                            return Colors.primary;
                        }

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }
                    Text {
                        text: batteryInfo.percent + "%"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: Style.fontFamily
                        color: batteryInfo.percent < 20 && batteryInfo.status === "Discharging"
                            ? "#e06c75" : Colors.tertiary

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }
                }

                Process {
                    id: batteryProcess
                    command: ["sh", "-c", [
                        "bat=$(ls /sys/class/power_supply/ 2>/dev/null | grep -i 'bat\\|BAT' | head -1)",
                        "[ -z \"$bat\" ] && exit 0",
                        "cap=$(cat /sys/class/power_supply/$bat/capacity 2>/dev/null)",
                        "sts=$(cat /sys/class/power_supply/$bat/status 2>/dev/null)",
                        "printf '%s:%s\\n' \"$sts\" \"$cap\""
                    ].join("\n")]
                    onExited: batteryPollTimer.start()
                    stdout: SplitParser {
                        onRead: data => {
                            let trimmed = data.trim();
                            if (!trimmed) return;
                            let parts = trimmed.split(":");
                            batteryInfo.present = true;
                            batteryInfo.status = parts[0] || "Unknown";
                            batteryInfo.percent = parseInt(parts[1] || "0");
                        }
                    }
                }

                Timer {
                    id: batteryPollTimer
                    interval: 30000
                    onTriggered: batteryProcess.running = true
                }
            }

        }
    }
}
