import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    required property var screen
    property string screenName: screen ? screen.name : ""

    readonly property real hexRadius: 8
    readonly property real hexW: hexRadius * 2
    readonly property real hexH: Math.ceil(hexRadius * 1.73205)

    readonly property real hexGap: 10
    readonly property real colStep: hexW + hexGap
    readonly property real rowStep: hexH / 2
    readonly property real rowOffset: colStep / 2

    readonly property real hPad: 4
    readonly property real vPad: 2

    // Hyprland
    property var wsMap: {
        var map = {};
        var list = CompositorService.workspaces;
        for (var i = 0; i < list.length; i++) {
            var ws = list[i];
            if (ws && ws.idx !== undefined)
                map[ws.idx] = ws;
        }
        return map;
    }

    // Niri
    property var niriWorkspaces: {
        if (!CompositorService.isNiri)
            return [];
        var list = CompositorService.workspaces;
        var result = [];
        for (var i = 0; i < list.length; i++) {
            var ws = list[i];
            if (ws && ws.output === root.screenName)
                result.push(ws);
        }
        result.sort(function (a, b) {
            return a.idx - b.idx;
        });
        return result;
    }

    implicitWidth: CompositorService.isHyprland ? (4 * colStep + rowOffset + hexW + hPad * 2) : CompositorService.isNiri ? Math.max(0, niriWorkspaces.length * colStep - hexGap + hPad * 2) : 0

    implicitHeight: CompositorService.isHyprland ? (rowStep + hexH + vPad * 2) : (hexH + vPad * 2)

    // Hyprland
    Repeater {
        model: CompositorService.isHyprland ? 10 : 0

        delegate: HexItem {
            id: hyprHex

            readonly property int wsIdx: index + 1
            readonly property int col: index % 5
            readonly property int wsRow: Math.floor(index / 5)
            readonly property var wsData: root.wsMap[wsIdx] ?? null

            // Active only if this workspace is the focused one on THIS monitor
            readonly property bool wsIsActive: wsData ? (wsData.isActive && wsData.output === root.screenName) : false
            readonly property bool wsIsOnScreen: wsData ? (wsData.output === root.screenName) : false
            readonly property bool wsIsOccupied: wsData ? wsData.isOccupied : false

            readonly property color fillColor: {
                if (wsIsActive)
                    return Colors.secondary;
                if (wsIsOnScreen)
                    return Colors.tertiary;
                if (wsIsOccupied)
                    return Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.45);
                return "transparent";
            }

            radius: root.hexRadius
            x: col * root.colStep + wsRow * root.rowOffset + root.hPad
            y: wsRow * root.rowStep + root.vPad

            borderColor: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)
            selectedBorderColor: Colors.secondary
            isSelected: wsIsActive

            Item {
                id: hyprFill
                anchors.fill: parent
                visible: hyprHex.fillColor !== "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: hyprHex.fillColor

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: hyprHex.mask
                    maskThresholdMin: 0.3
                    maskSpreadAtMin: 0.3
                }
            }

            Text {
                anchors.centerIn: parent
                text: hyprHex.wsIdx.toString()
                font.pixelSize: 11
                font.weight: Font.Medium
                font.family: Style.fontFamily
                color: {
                    if (hyprHex.wsIsActive)
                        return Colors.secondaryText;
                    if (hyprHex.wsIsOnScreen)
                        return Colors.tertiaryText;
                    return Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.65);
                }
                z: 1
            }

            onClicked: {
                if (wsData) {
                    CompositorService.focusWorkspace(wsData);
                } else {
                    CompositorService.focusWorkspace({
                        idx: wsIdx,
                        id: wsIdx
                    });
                }
            }
        }
    }

    // Niri
    Repeater {
        model: CompositorService.isNiri ? root.niriWorkspaces.length : 0

        delegate: HexItem {
            id: niriHex

            readonly property var wsData: root.niriWorkspaces[index] ?? null
            readonly property bool wsIsActive: wsData ? (wsData.isActive || wsData.isFocused) : false
            readonly property color fillColor: wsIsActive ? Colors.secondary : Colors.tertiary

            radius: root.hexRadius
            x: index * root.colStep + root.hPad
            y: root.vPad
            borderColor: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)
            selectedBorderColor: Colors.secondary
            isSelected: wsIsActive

            Item {
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: niriHex.fillColor

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: niriHex.mask
                    maskThresholdMin: 0.3
                    maskSpreadAtMin: 0.3
                }
            }

            Text {
                anchors.centerIn: parent
                text: niriHex.wsData ? niriHex.wsData.idx.toString() : ""
                font.pixelSize: 6
                font.weight: Font.Medium
                font.family: Style.fontFamily
                color: niriHex.wsIsActive ? Colors.secondaryText : Colors.tertiaryText
                z: 1
            }

            onClicked: {
                if (wsData)
                    CompositorService.focusWorkspace(wsData);
            }
        }
    }
}
