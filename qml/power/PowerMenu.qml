import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."
import "../components"


// Full-screen power menu with hexagonal buttons matching the app launcher style.
// Dims all monitors; the hex card renders on whichever monitor is active when opened —
// same active-monitor query pattern used by AppLauncher.
Scope {
  id: powerMenuScope

  property var colors
  property bool showing: false

  // _panelVisible gates window visibility — stays false until the active-monitor
  // query completes, so we never show on the wrong screen.
  property bool _panelVisible: false
  property string activeMonitor: ""
  property bool cardVisible: false
  property int selectedIndex: 0

  property string iconFont: "Font Awesome 7 Free Solid"

  property var _commands: ({
    "lock":     "loginctl lock-session",
    "logout":   Config.scriptsDir + "/bash/wm-action quit",
    "reboot":   "systemctl reboot",
    "poweroff": "systemctl poweroff"
  })

  property var _defaultOptions: [
    { label: "Lock",      icon: "\uf023", action: "lock"     },
    { label: "Logout",    icon: "\uf2f5", action: "logout"   },
    { label: "Reboot",    icon: "\uf2f9", action: "reboot"   },
    { label: "Power off", icon: "\uf011", action: "poweroff" }
  ]

  property var options: {
    var src = Config.powerMenuOptions.length > 0 ? Config.powerMenuOptions : _defaultOptions
    var result = []
    for (var i = 0; i < src.length; i++) {
      var opt = src[i]
      var cmd = _commands[opt.action] || ""
      if (cmd) result.push({ label: opt.label || "", icon: opt.icon || "", command: cmd })
    }
    return result
  }

  onShowingChanged: {
    if (showing) {
      selectedIndex = 0
      _panelVisible = false
      cardVisible = false
      _activeMonitorProcess.running = true
    } else {
      _panelVisible = false
      cardVisible = false
    }
  }

  // Query the active monitor before making anything visible — mirrors AppLauncher exactly.
  Process {
    id: _activeMonitorProcess
    command: [Config.scriptsDir + "/bash/wm-action", "active-monitor"]
    stdout: SplitParser {
      onRead: line => {
        var name = line.trim()
        if (name && name !== "?") powerMenuScope.activeMonitor = name
      }
    }
    onExited: {
      if (!powerMenuScope.showing) return
      // Validate the returned name against real screens; fall back to screens[0].
      var screens = Quickshell.screens
      var matched = false
      for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === powerMenuScope.activeMonitor) { matched = true; break }
      }
      if (!matched && screens.length > 0)
        powerMenuScope.activeMonitor = screens[0].name
      powerMenuScope._panelVisible = true
      cardShowTimer.restart()
    }
  }

  Timer {
    id: cardShowTimer
    interval: 50
    onTriggered: powerMenuScope.cardVisible = true
  }

  function executeOption(index) {
    Quickshell.execDetached(["sh", "-c", options[index].command])
    showing = false
  }


  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: powerPanel
      property var modelData
      property bool isActive: modelData.name === powerMenuScope.activeMonitor

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }

      visible: powerMenuScope._panelVisible
      color: "transparent"

      WlrLayershell.namespace: "powermenu"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: (powerMenuScope._panelVisible && isActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      exclusionMode: ExclusionMode.Ignore

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
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            powerMenuScope.showing = false
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            powerMenuScope.selectedIndex = Math.max(0, powerMenuScope.selectedIndex - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            powerMenuScope.selectedIndex = Math.min(powerMenuScope.options.length - 1, powerMenuScope.selectedIndex + 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            powerMenuScope.executeOption(powerMenuScope.selectedIndex)
            event.accepted = true
          }
        }
      }


      // ── Hex button grid (active monitor only) ─────────────────────────────
      //
      // Items are laid out in columns of _rows, with odd columns shifted down
      // by stepY/2 — identical to AppLauncher's honeycomb pattern.
      // For 4 options this produces a 2-col × 2-row interlocked grid.
      Item {
        id: powerCard
        visible: isActive && powerMenuScope.cardVisible

        readonly property int   _r:      90
        readonly property real  _hexH:   Math.ceil(_r * 1.73205)
        readonly property real  _hexW:   _r * 2
        readonly property real  _gap:    6
        readonly property real  _stepX:  1.5 * _r + _gap
        readonly property real  _stepY:  _hexH + _gap
        readonly property int   _rows:   2
        readonly property int   _cols:   Math.ceil(Math.max(1, powerMenuScope.options.length) / _rows)
        readonly property real  _labelH: 32

        // Width spans all columns; height covers the tallest (odd) column which
        // is offset an extra stepY/2 plus one full hex.
        width:  (_cols - 1) * _stepX + _hexW
        height: (_rows - 1) * _stepY + _stepY / 2 + _hexH + _labelH

        anchors.centerIn: parent

        Repeater {
          model: powerMenuScope.options

          Item {
            id: hexItem

            readonly property int  colIdx: Math.floor(index / powerCard._rows)
            readonly property int  rowIdx: index % powerCard._rows

            readonly property int  _r:     powerCard._r
            readonly property real _cx:    _r
            readonly property real _cy:    powerCard._hexH / 2
            readonly property real _cos30: 0.866025
            readonly property real _sin30: 0.5

            width:  powerCard._hexW
            height: powerCard._hexH
            x:      colIdx * powerCard._stepX
            // Odd columns shift down by half a step — this is what creates the interlock
            y:      rowIdx * powerCard._stepY + (colIdx % 2 !== 0 ? powerCard._stepY / 2 : 0)

            property bool isSelected: powerMenuScope.selectedIndex === index
            property bool isHovered:  hexMouse.containsMouse

            // Hex clip mask
            Item {
              id: hexMaskLayer
              anchors.fill: parent
              visible: false
              layer.enabled: true
              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "white"; strokeColor: "transparent"
                  startX: hexItem._cx + hexItem._r;                        startY: hexItem._cy
                  PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx - hexItem._r;                  y: hexItem._cy }
                  PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx + hexItem._r;                  y: hexItem._cy }
                }
              }
            }

            // Background fill
            Item {
              anchors.fill: parent
              Rectangle {
                anchors.fill: parent
                color: powerMenuScope.colors
                  ? Qt.rgba(powerMenuScope.colors.surfaceContainer.r,
                            powerMenuScope.colors.surfaceContainer.g,
                            powerMenuScope.colors.surfaceContainer.b, 1.0)
                  : "#2c1f1d"
              }
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: hexMaskLayer
                maskThresholdMin: 0.3
                maskSpreadAtMin:  0.3
              }
            }

            // Icon
            Text {
              anchors.centerIn: parent
              text: modelData.icon
              font.family: powerMenuScope.iconFont
              font.pixelSize: hexItem._r * 0.72
              color: hexItem.isSelected
                ? (powerMenuScope.colors ? powerMenuScope.colors.primary  : "#ffb4ab")
                : (powerMenuScope.colors ? powerMenuScope.colors.tertiary : "#8bceff")
              Behavior on color { ColorAnimation { duration: 150 } }
              scale: hexItem.isHovered ? 1.1 : 1.0
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: hexMaskLayer
                maskThresholdMin: 0.3
                maskSpreadAtMin:  0.3
              }
            }

            // Dim overlay for unselected
            Item {
              anchors.fill: parent
              Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, hexItem.isSelected ? 0 : (hexItem.isHovered ? 0.08 : 0.32))
                Behavior on color { ColorAnimation { duration: 120 } }
              }
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: hexMaskLayer
                maskThresholdMin: 0.3
                maskSpreadAtMin:  0.3
              }
            }

            // Hex outline
            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: hexItem.isSelected
                  ? (powerMenuScope.colors ? powerMenuScope.colors.primary : "#ffb4ab")
                  : Qt.rgba(0, 0, 0, 0.45)
                Behavior on strokeColor { ColorAnimation { duration: 120 } }
                strokeWidth: hexItem.isSelected ? 3 : 1.5
                startX: hexItem._cx + hexItem._r;                        startY: hexItem._cy
                PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx - hexItem._r;                  y: hexItem._cy }
                PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                PathLine { x: hexItem._cx + hexItem._r;                  y: hexItem._cy }
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
              color: hexItem.isSelected
                ? (powerMenuScope.colors ? powerMenuScope.colors.primary : "#ffb4ab")
                : (powerMenuScope.colors
                    ? Qt.rgba(powerMenuScope.colors.surfaceText.r,
                              powerMenuScope.colors.surfaceText.g,
                              powerMenuScope.colors.surfaceText.b, 0.7)
                    : Qt.rgba(1, 1, 1, 0.6))
              Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Mouse area with hex-accurate hit testing
            MouseArea {
              id: hexMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              function contains(point) {
                var dx = Math.abs(point.x - hexItem._cx)
                var dy = Math.abs(point.y - hexItem._cy)
                return dy <= hexItem._cos30 * hexItem._r && dx <= hexItem._r - dy * 0.57735
              }
              onContainsMouseChanged: {
                if (containsMouse) powerMenuScope.selectedIndex = index
              }
              onClicked: powerMenuScope.executeOption(index)
            }
          }
        }
      }
    }
  }
}
