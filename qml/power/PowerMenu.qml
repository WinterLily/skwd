import ".."
import "../components"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Full-screen power menu with hexagonal buttons matching the app launcher style.
// Dims all monitors; the hex card renders on whichever monitor is active when opened —
// same active-monitor query pattern used by AppLauncher.
Scope {
    id: powerMenuScope

    property var colors
    property bool showing: false
    property bool hideLockOption: false
    // _panelVisible gates window visibility — stays false until the active-monitor
    // query completes, so we never show on the wrong screen.
    property bool _panelVisible: false
    property string activeMonitor: ""
    property bool cardVisible: false
    property int selectedIndex: 0
    property string iconFont: "Font Awesome 7 Free Solid"
    property var _commands: ({
        "lock": "loginctl lock-session",
        "logout": Config.scriptsDir + "/bash/wm-action quit",
        "reboot": "systemctl reboot",
        "poweroff": "systemctl poweroff"
    })
    property var _defaultOptions: [{
        "label": "Lock",
        "icon": "\uf023",
        "action": "lock"
    }, {
        "label": "Logout",
        "icon": "\uf2f5",
        "action": "logout"
    }, {
        "label": "Reboot",
        "icon": "\uf2f9",
        "action": "reboot"
    }, {
        "label": "Power off",
        "icon": "\uf011",
        "action": "poweroff"
    }]
    property var options: {
        var src = Config.powerMenuOptions.length > 0 ? Config.powerMenuOptions : _defaultOptions;
        var result = [];
        for (var i = 0; i < src.length; i++) {
            var opt = src[i];
            if (powerMenuScope.hideLockOption && opt.action === "lock")
                continue;

            var cmd = _commands[opt.action] || "";
            if (cmd)
                result.push({
                "label": opt.label || "",
                "icon": opt.icon || "",
                "command": cmd
            });

        }
        return result;
    }

    function executeOption(index) {
        Quickshell.execDetached(["sh", "-c", options[index].command]);
        showing = false;
    }

    onShowingChanged: {
        if (showing) {
            selectedIndex = 0;
            _panelVisible = false;
            cardVisible = false;
            _activeMonitorProcess.running = true;
        } else {
            _panelVisible = false;
            cardVisible = false;
        }
    }

    // Query the active monitor before making anything visible — mirrors AppLauncher exactly.
    Process {
        id: _activeMonitorProcess

        command: [Config.scriptsDir + "/bash/wm-action", "active-monitor"]
        onExited: {
            if (!powerMenuScope.showing)
                return ;
 // Validate the returned name against real screens; fall back to screens[0].
            var screens = Quickshell.screens;
            var matched = false;
            for (var i = 0; i < screens.length; i++) {
                if (screens[i].name === powerMenuScope.activeMonitor) {
                    matched = true;
                    break;
                }
            }
            if (!matched && screens.length > 0)
                powerMenuScope.activeMonitor = screens[0].name;

            powerMenuScope._panelVisible = true;
            cardShowTimer.restart();
        }

        stdout: SplitParser {
            onRead: (line) => {
                var name = line.trim();
                if (name && name !== "?")
                    powerMenuScope.activeMonitor = name;

            }
        }

    }

    Timer {
        id: cardShowTimer

        interval: 50
        onTriggered: powerMenuScope.cardVisible = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            // ── Hex button grid (active monitor only) ─────────────────────────────

            id: powerPanel

            property var modelData
            property bool isActive: modelData.name === powerMenuScope.activeMonitor

            screen: modelData
            visible: powerMenuScope._panelVisible
            color: "transparent"
            WlrLayershell.namespace: "powermenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (powerMenuScope._panelVisible && isActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.01)
            }

            // Dim shown on every monitor
            DimOverlay {
                active: powerMenuScope.cardVisible
                dimOpacity: 0.55
                onClicked: powerMenuScope.showing = false
            }

            // Keyboard nav — only the active monitor's window has focus
            Item {
                anchors.fill: parent
                focus: powerMenuScope._panelVisible && isActive
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        powerMenuScope.showing = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        powerMenuScope.selectedIndex = Math.max(0, powerMenuScope.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        powerMenuScope.selectedIndex = Math.min(powerMenuScope.options.length - 1, powerMenuScope.selectedIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        powerMenuScope.executeOption(powerMenuScope.selectedIndex);
                        event.accepted = true;
                    }
                }
            }

            // Items are laid out in columns of _rows, with odd columns shifted down
            // by stepY/2 — identical to AppLauncher's honeycomb pattern.
            // For 4 options this produces a 2-col × 2-row interlocked grid.
            Item {
                id: powerCard

                readonly property int _r: Config.hexRadius
                readonly property real _hexH: Math.ceil(_r * 1.73205)
                readonly property real _hexW: _r * 2
                readonly property real _gap: 14
                readonly property real _stepX: 1.5 * _r + _gap
                readonly property real _stepY: _hexH + _gap
                readonly property int _rows: 2
                readonly property int _cols: Math.ceil(Math.max(1, powerMenuScope.options.length) / _rows)
                readonly property real _labelH: 32

                visible: isActive && powerMenuScope.cardVisible
                // Width spans all columns; height covers the tallest (odd) column which
                // is offset an extra stepY/2 plus one full hex.
                width: (_cols - 1) * _stepX + _hexW
                height: (_rows - 1) * _stepY + _stepY / 2 + _hexH + _labelH
                anchors.centerIn: parent

                Repeater {
                    model: powerMenuScope.options

                    HexItem {
                        id: hexItem

                        readonly property int colIdx: Math.floor(index / powerCard._rows)
                        readonly property int rowIdx: index % powerCard._rows

                        radius: powerCard._r
                        x: colIdx * powerCard._stepX
                        // Odd columns shift down by half a step — this is what creates the interlock
                        y: rowIdx * powerCard._stepY + (colIdx % 2 !== 0 ? powerCard._stepY / 2 : 0)
                        isSelected: powerMenuScope.selectedIndex === index
                        selectedBorderColor: powerMenuScope.colors ? powerMenuScope.colors.primary : "#ffb4ab"
                        borderColor: Qt.rgba(0, 0, 0, 0.45)
                        accentColor: powerMenuScope.colors ? powerMenuScope.colors.primary : "#ffb4ab"
                        onHovered: powerMenuScope.selectedIndex = index
                        onClicked: powerMenuScope.executeOption(index)

                        // Background fill
                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true

                            Rectangle {
                                anchors.fill: parent
                                color: powerMenuScope.colors ? Qt.rgba(powerMenuScope.colors.surfaceContainer.r, powerMenuScope.colors.surfaceContainer.g, powerMenuScope.colors.surfaceContainer.b, 1) : "#2c1f1d"
                            }

                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: hexItem.mask
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                        }

                        // Icon
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: powerMenuScope.iconFont
                            font.pixelSize: hexItem.radius * 0.72
                            color: hexItem.isSelected ? (powerMenuScope.colors ? powerMenuScope.colors.primary : "#ffb4ab") : (powerMenuScope.colors ? powerMenuScope.colors.tertiary : "#8bceff")
                            scale: hexItem.isHovered ? 1.1 : 1
                            layer.enabled: true
                            layer.smooth: true

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }

                            }

                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: hexItem.mask
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                        }

                        // Dim overlay for unselected
                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, hexItem.isSelected ? 0 : (hexItem.isHovered ? 0.08 : 0.32))

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: hexItem.mask
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                        }

                        // Label
                        Text {
                            anchors.top: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 6
                            text: modelData.label
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: hexItem.isSelected ? (powerMenuScope.colors ? powerMenuScope.colors.primary : "#ffb4ab") : (powerMenuScope.colors ? Qt.rgba(powerMenuScope.colors.surfaceText.r, powerMenuScope.colors.surfaceText.g, powerMenuScope.colors.surfaceText.b, 0.7) : Qt.rgba(1, 1, 1, 0.6))

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
