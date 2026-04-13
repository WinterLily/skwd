import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import ".."
import "../services"

PanelWindow {
    id: bottomBar

    required property var clock
    required property string weatherDesc
    required property string weatherTemp

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

            // Parallelogram: full width at bottom (screen edge), inset at top-left
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

        Item {
            id: weatherWidget
            implicitWidth: weatherRow.implicitWidth
            implicitHeight: weatherRow.implicitHeight
            visible: Config.weatherEnabled && bottomBar.weatherTemp !== "" && bottomBar.weatherTemp !== undefined

            Row {
                id: weatherRow
                spacing: 4
                Text {
                    text: {
                        let desc = bottomBar.weatherDesc.toLowerCase();
                        if (desc.includes("thunder")) return "󰙾";
                        if (desc.includes("blizzard") || desc.includes("blowing snow")) return "󰼶";
                        if (desc.includes("heavy snow")) return "󰼶";
                        if (desc.includes("snow")) return "󰖘";
                        if (desc.includes("ice pellet") || desc.includes("sleet")) return "󰙿";
                        if (desc.includes("torrential") || desc.includes("heavy rain")) return "󰖖";
                        if (desc.includes("freezing rain") || desc.includes("freezing drizzle")) return "󰙿";
                        if (desc.includes("rain") || desc.includes("drizzle") || desc.includes("shower")) return "󰖗";
                        if (desc.includes("fog") || desc.includes("mist")) return "󰖑";
                        if (desc.includes("overcast") || desc.includes("cloudy")) return "󰖐";
                        if (desc.includes("partly")) return "󰖕";
                        if (desc.includes("sunny") || desc.includes("clear")) return "󰖙";
                        return "󰖐";
                    }
                    font.pixelSize: 14
                    font.family: Style.fontFamilyNerdIcons
                    color: Colors.primary
                }
                Text {
                    text: bottomBar.weatherTemp
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: Style.fontFamily
                    color: Colors.tertiary
                }
            }
        }

        Item {
            id: bluetoothWidget
            implicitWidth: bluetoothRow.implicitWidth
            implicitHeight: bluetoothRow.implicitHeight
            visible: Config.bluetoothEnabled && bluetoothInfo.batteryText !== ""

            Row {
                id: bluetoothRow
                spacing: 4
                Text {
                    text: "󰂯"
                    font.pixelSize: 14
                    font.family: Style.fontFamilyNerdIcons
                    color: Colors.primary
                }
                Text {
                    text: bluetoothInfo.batteryText
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: Style.fontFamily
                    color: Colors.tertiary
                }
            }
        }

        Item {
            id: wifiWidget
            implicitWidth: wifiRow.implicitWidth
            implicitHeight: wifiRow.implicitHeight
            visible: Config.wifiEnabled && wifiInfo.ssid !== ""

            Row {
                id: wifiRow
                spacing: 4
                Text {
                    text: {
                        let s = wifiInfo.signalStrength;
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
                    text: wifiInfo.ssid
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: Style.fontFamily
                    color: Colors.tertiary
                }
            }

            QtObject {
                id: wifiInfo
                property string ssid: ""
                property int signalStrength: 0
                Component.onCompleted: wifiStatusProcess.running = true
            }

            Process {
                id: wifiStatusProcess
                property string pendingSsid: ""
                command: ["sh", "-c", "iwctl station " + Config.wifiInterface + " show 2>/dev/null | awk '/Connected network/{print $3} /^[[:space:]]*RSSI/{gsub(/-| dBm/,\"\"); print $2}'"]
                onExited: {
                    wifiInfo.ssid = pendingSsid !== "" ? pendingSsid : "";
                    pendingSsid = "";
                    wifiPollTimer.start();
                }
                stdout: SplitParser {
                    onRead: data => {
                        let trimmed = data.trim();
                        if (trimmed && !trimmed.match(/^-?[0-9]+$/)) {
                            wifiStatusProcess.pendingSsid = trimmed;
                        } else if (trimmed.match(/^-?[0-9]+$/)) {
                            let rssi = -parseInt(trimmed);
                            wifiInfo.signalStrength = Math.max(0, Math.min(100, (rssi + 90) * 100 / 60));
                        }
                    }
                }
            }

            Timer {
                id: wifiPollTimer
                interval: Config.wifiPollMs
                onTriggered: wifiStatusProcess.running = true
            }
        }

        Item {
            id: volumeWidget
            visible: Config.volumeEnabled
            implicitWidth: volumeRow.implicitWidth
            implicitHeight: volumeRow.implicitHeight

            Row {
                id: volumeRow
                spacing: 4
                Text {
                    text: {
                        let vol = Pipewire.defaultAudioSink?.audio?.volume ?? 0;
                        if (vol === 0) return "󰖁";
                        if (vol < 0.33) return "󰕿";
                        if (vol < 0.66) return "󰖀";
                        return "󰕾";
                    }
                    font.pixelSize: 14
                    font.family: Style.fontFamilyNerdIcons
                    color: Colors.primary
                    width: 16
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: Style.fontFamily
                    color: Colors.tertiary
                    width: Math.max(implicitWidth, 28)
                }
            }
        }

        Item {
            id: clockWidget
            visible: Config.calendarEnabled
            implicitWidth: clockRow.implicitWidth
            implicitHeight: clockRow.implicitHeight

            Row {
                id: clockRow
                spacing: 0
                Text {
                    text: Qt.formatTime(bottomBar.clock.date, "HH")
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.family: Style.fontFamily
                    color: Colors.primary
                }
                Text {
                    text: ":"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.family: Style.fontFamily
                    color: Colors.tertiary
                }
                Text {
                    text: Qt.formatTime(bottomBar.clock.date, "mm")
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.family: Style.fontFamily
                    color: Colors.tertiary
                }
            }
        }
    }

    } // cornerPanel
}
