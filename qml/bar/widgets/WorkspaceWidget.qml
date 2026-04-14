// WorkspaceWidget — workspace switcher for Hyprland and Niri.
//
// Hyprland: a fixed 2×5 hex grid showing workspaces 1-10.
//   • secondary  — the active workspace on any monitor (currently displayed)
//   • tertiary   — workspaces assigned to this bar's screen (but not active)
//   • outline    — workspaces occupied elsewhere (have windows, different screen)
//   • transparent fill — empty workspaces (border only)
//
// Niri: a single row of hexes, one per workspace on this screen.
//   • secondary — the currently focused workspace
//   • tertiary  — other in-use workspaces

import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    // The screen this bar instance lives on — used to colour-code per-monitor state.
    required property var screen
    property string screenName: screen ? screen.name : ""

    // ── Hex geometry ──────────────────────────────────────────────────────────
    readonly property real hexRadius:  8
    readonly property real hexW:       hexRadius * 2                       // 16 px
    readonly property real hexH:       Math.ceil(hexRadius * 1.73205)      // 14 px
    readonly property real hexGap:     2                                    // gap between same-row hexes
    readonly property real rowStep:    hexW + hexGap                       // 18 px
    // Row 1 is offset right by half a hex + half a gap for the stagger
    readonly property real staggerX:   hexW / 2 + hexGap / 2              // 9 px

    // ── Padding ────────────────────────────────────────────────────────────────
    readonly property real hPad: 4   // left + right breathing room
    readonly property real vPad: 2   // top + bottom (centres 2-row grid in 32 px bar)

    // ── Hyprland workspace map  (idx → workspace object) ─────────────────────
    property var wsMap: {
        var map = {}
        var list = CompositorService.workspaces
        for (var i = 0; i < list.length; i++) {
            var ws = list[i]
            if (ws && ws.idx !== undefined)
                map[ws.idx] = ws
        }
        return map
    }

    // ── Niri: workspaces for this screen, sorted by idx ───────────────────────
    property var niriWorkspaces: {
        if (!CompositorService.isNiri) return []
        var list = CompositorService.workspaces
        var result = []
        for (var i = 0; i < list.length; i++) {
            var ws = list[i]
            if (ws && ws.output === root.screenName)
                result.push(ws)
        }
        result.sort(function(a, b) { return a.idx - b.idx })
        return result
    }

    // ── Size ──────────────────────────────────────────────────────────────────
    //
    // Hyprland grid (2 rows × 5 cols, row 1 staggered):
    //   Row 0:  x = col * rowStep,              cols 0-4  → right edge = 4*18+16 = 88
    //   Row 1:  x = staggerX + col * rowStep,   cols 0-4  → right edge = 9+4*18+16 = 97
    //   Total width  = 97
    //   Total height = hexH * 2 = 28
    //
    // Niri row:
    //   width  = n * rowStep - hexGap   (no trailing gap)
    //   height = hexH
    implicitWidth:  CompositorService.isHyprland ? (staggerX + 5 * rowStep - hexGap + hPad * 2)
                  : CompositorService.isNiri      ? Math.max(0, niriWorkspaces.length * rowStep - hexGap + hPad * 2)
                  : 0

    implicitHeight: CompositorService.isHyprland ? (hexH * 2 + vPad * 2)
                  : (hexH + vPad * 2)

    // ── Hyprland: 10 hexes in a 2×5 staggered grid ───────────────────────────
    Repeater {
        model: CompositorService.isHyprland ? 10 : 0

        delegate: HexItem {
            id: hyprHex

            readonly property int wsIdx:  index + 1            // 1 … 10
            readonly property int col:    index % 5
            readonly property int wsRow:  Math.floor(index / 5)
            readonly property var wsData: root.wsMap[wsIdx] ?? null

            // Workspace state flags
            readonly property bool wsIsActive:     wsData ? wsData.isActive      : false
            readonly property bool wsIsOnScreen:   wsData ? (wsData.output === root.screenName) : false
            readonly property bool wsIsOccupied:   wsData ? wsData.isOccupied    : false

            // Fill colour (priority: active > on-this-screen > occupied-elsewhere > empty)
            readonly property color fillColor: {
                if (wsIsActive)                          return Colors.secondary
                if (wsIsOnScreen)                        return Colors.tertiary
                if (wsIsOccupied)                        return Qt.rgba(
                    Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.45)
                return "transparent"
            }

            radius:       root.hexRadius
            x:            col * root.rowStep + wsRow * root.staggerX + root.hPad
            y:            wsRow * root.hexH + root.vPad
            borderColor:  Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)
            selectedBorderColor: Colors.secondary
            isSelected:   wsIsActive

            // ── Hex fill (masked rectangle) ───────────────────────────────
            Item {
                id: hyprFill
                anchors.fill: parent
                visible:      hyprHex.fillColor !== "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: hyprHex.fillColor

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled:        true
                    maskSource:         hyprHex.mask
                    maskThresholdMin:   0.3
                    maskSpreadAtMin:    0.3
                }
            }

            // ── Workspace number ──────────────────────────────────────────
            Text {
                anchors.centerIn: parent
                text:             hyprHex.wsIdx.toString()
                font.pixelSize:   6
                font.weight:      Font.Medium
                font.family:      Style.fontFamily
                color: {
                    if (hyprHex.wsIsActive)    return Colors.secondaryText
                    if (hyprHex.wsIsOnScreen)  return Colors.tertiaryText
                    return Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.65)
                }
                z: 1
            }

            onClicked: {
                if (wsData) {
                    CompositorService.focusWorkspace(wsData)
                } else {
                    // Workspace not yet created — dispatch a Hyprland switch which
                    // will create it on the fly.
                    CompositorService.focusWorkspace({ idx: wsIdx, id: wsIdx })
                }
            }
        }
    }

    // ── Niri: one hex per workspace on this screen ────────────────────────────
    Repeater {
        model: CompositorService.isNiri ? root.niriWorkspaces.length : 0

        delegate: HexItem {
            id: niriHex

            readonly property var wsData:      root.niriWorkspaces[index] ?? null
            readonly property bool wsIsActive: wsData ? (wsData.isActive || wsData.isFocused) : false
            readonly property color fillColor: wsIsActive ? Colors.secondary : Colors.tertiary

            radius:       root.hexRadius
            x:            index * root.rowStep + root.hPad
            y:            root.vPad
            borderColor:  Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)
            selectedBorderColor: Colors.secondary
            isSelected:   wsIsActive

            Item {
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: niriHex.fillColor

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled:        true
                    maskSource:         niriHex.mask
                    maskThresholdMin:   0.3
                    maskSpreadAtMin:    0.3
                }
            }

            // ── Workspace number ──────────────────────────────────────────
            Text {
                anchors.centerIn: parent
                text:             niriHex.wsData ? niriHex.wsData.idx.toString() : ""
                font.pixelSize:   6
                font.weight:      Font.Medium
                font.family:      Style.fontFamily
                color:            niriHex.wsIsActive ? Colors.secondaryText
                                                     : Colors.tertiaryText
                z: 1
            }

            onClicked: {
                if (wsData) CompositorService.focusWorkspace(wsData)
            }
        }
    }
}
