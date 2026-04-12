import "../.."
import QtQuick
import Quickshell.Io

Rectangle {
    id: root

    // Dropdown animation state
    property bool active: false
    property string wifiSsid: ""
    property int wifiSignalStrength: 0
    readonly property real animatedHeight: _animatedHeight
    readonly property real windowHeight: _windowHeight
    property real diagSlant: 28
    property real _targetHeight: 0
    property real _animatedHeight: _targetHeight
    property real _windowHeight: 0

    height: _animatedHeight
    visible: _animatedHeight > 0
    color: "transparent"
    onAnimatedHeightChanged: {
        if (animatedHeight === 0 && !active)
            _windowHeight = 0;

    }
    // Expand/collapse and scan trigger
    onActiveChanged: {
        if (active) {
            _targetHeight = wifiColumn.implicitHeight + 46;
            _windowHeight = _targetHeight;
            wifiColumn.networkList = [];
            wifiScanProcess.running = true;
        } else {
            _targetHeight = 0;
        }
    }

    Canvas {
        id: dropdownBg

        anchors.fill: parent
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width, height);
            ctx.lineTo(root.diagSlant, height);
            ctx.lineTo(0, height - root.diagSlant);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1);
            ctx.fill();
            if (Config.accentEdges) {
                ctx.beginPath();
                ctx.moveTo(0, height - root.diagSlant);
                ctx.lineTo(root.diagSlant, height);
                ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1);
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }
        }

        Connections {
            function onSurfaceChanged() {
                dropdownBg.requestPaint();
            }

            function onPrimaryChanged() {
                dropdownBg.requestPaint();
            }

            target: Colors
        }

    }

    // Bottom accent bar
    Rectangle {
        property real animatedWidth: root.visible ? parent.width - root.diagSlant : 0

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        height: 2
        color: Colors.primary
        width: animatedWidth

        Behavior on animatedWidth {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }

        }

    }

    // WiFi content column
    Column {
        id: wifiColumn

        property var networkList: []

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        spacing: 6
        width: parent.width - 24
        // Content fade-in and slide-up transition
        opacity: root.active && root._animatedHeight > (wifiColumn.implicitHeight * 0.5) ? 1 : 0
        onImplicitHeightChanged: {
            if (root.active) {
                root._targetHeight = implicitHeight + 46;
                root._windowHeight = root._targetHeight;
            }
        }

        // WiFi network scanner
        Process {
            id: wifiScanProcess

            command: [Config.scriptsDir + "/bash/wifi-list"]
            onExited: {
                try {
                    let networks = JSON.parse(wifiNetworkParser.parts.join("\n").trim());
                    wifiColumn.networkList = networks;
                } catch (e) {
                    console.log("WiFi list parse error:", e);
                }
                wifiNetworkParser.parts = [];
            }

            stdout: SplitParser {
                id: wifiNetworkParser

                property var parts: []

                onRead: (data) => {
                    parts.push(data);
                }
            }

        }

        // WiFi connect process
        Process {
            id: wifiConnectProcess

            property string targetSsid: ""

            command: ["iwctl", "station", Config.wifiInterface, "connect", targetSsid]
        }

        // Section header
        Text {
            text: "WIFI"
            color: Colors.primary
            font.pixelSize: 14
            font.family: Style.fontFamily
            font.weight: Font.DemiBold
        }

        // Current connection status
        Row {
            spacing: 8
            visible: root.wifiSsid !== ""

            Text {
                text: "󰤨"
                font.pixelSize: 12
                font.family: Style.fontFamilyNerdIcons
                color: Colors.primary
                width: 14
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: root.wifiSsid || "Not connected"
                color: Colors.primary
                font.pixelSize: 12
                font.family: Style.fontFamily
                font.weight: Font.DemiBold
            }

            Text {
                text: root.wifiSignalStrength + "%"
                color: Colors.tertiary
                font.pixelSize: 12
                font.family: Style.fontFamily
                font.weight: Font.Medium
                width: 28
                horizontalAlignment: Text.AlignRight
            }

        }

        // Section divider
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
        }

        // Available networks header
        Text {
            text: "AVAILABLE"
            color: Colors.tertiary
            font.pixelSize: 10
            font.family: Style.fontFamily
            font.weight: Font.DemiBold
        }

        // Scanning placeholder
        Text {
            visible: wifiColumn.networkList.length === 0
            text: "Scanning..."
            color: Colors.tertiary
            font.pixelSize: 11
            font.family: Style.fontFamily
            font.italic: true
        }

        // Network list with signal icons and security indicators
        Repeater {
            model: wifiColumn.networkList

            delegate: Item {
                property bool isConnected: modelData.connected || modelData.ssid === root.wifiSsid

                width: netRow.implicitWidth
                height: netRow.implicitHeight

                Row {
                    id: netRow

                    spacing: 8

                    Text {
                        text: {
                            let s = modelData.signal || 0;
                            if (s <= 25)
                                return "󰤟";

                            if (s <= 50)
                                return "󰤢";

                            if (s <= 75)
                                return "󰤥";

                            return "󰤨";
                        }
                        font.pixelSize: 12
                        font.family: Style.fontFamilyNerdIcons
                        color: isConnected ? Colors.primary : Colors.tertiary
                        width: 14
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: modelData.ssid
                        color: isConnected ? Colors.primary : Colors.backgroundText
                        font.pixelSize: 12
                        font.family: Style.fontFamily
                        font.weight: isConnected ? Font.DemiBold : Font.Medium
                        width: 120
                        elide: Text.ElideRight
                    }

                    Text {
                        text: {
                            let sec = modelData.security || "";
                            if (sec === "psk")
                                return "󰌆";

                            if (sec === "open")
                                return "󰌊";

                            if (sec === "8021x")
                                return "󰌆";

                            return sec !== "" ? "󰌆" : "";
                        }
                        font.pixelSize: 11
                        font.family: Style.fontFamilyNerdIcons
                        color: Colors.tertiary
                        width: 14
                        horizontalAlignment: Text.AlignHCenter
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!isConnected) {
                            wifiConnectProcess.targetSsid = modelData.ssid;
                            wifiConnectProcess.running = true;
                        }
                    }
                }

            }

        }

        transform: Translate {
            y: root.active && root._animatedHeight > (wifiColumn.implicitHeight * 0.5) ? 0 : -15
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on _animatedHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }

    }

}
