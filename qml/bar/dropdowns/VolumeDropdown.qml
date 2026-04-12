import Quickshell.Services.Pipewire
import QtQuick
import "../.."

Rectangle {
  id: root


  // Dropdown animation state
  property bool active: false
  readonly property real animatedHeight: _animatedHeight
  readonly property real windowHeight: _windowHeight
  property real diagSlant: 28

  property real _targetHeight: 0
  property real _animatedHeight: _targetHeight
  property real _windowHeight: 0
  Behavior on _animatedHeight {
    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
  }

  height: _animatedHeight
  visible: _animatedHeight > 0
  color: "transparent"

  Canvas {
    id: dropdownBg
    anchors.fill: parent
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.beginPath()
      ctx.moveTo(0, 0)
      ctx.lineTo(width, 0)
      ctx.lineTo(width, height)
      ctx.lineTo(root.diagSlant, height)
      ctx.lineTo(0, height - root.diagSlant)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1.0)
      ctx.fill()

      if (Config.accentEdges) {
        ctx.beginPath()
        ctx.moveTo(0, height - root.diagSlant)
        ctx.lineTo(root.diagSlant, height)
        ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1.0)
        ctx.lineWidth = 1.5
        ctx.stroke()
      }
    }
    Connections {
      target: Colors
      function onSurfaceChanged() { dropdownBg.requestPaint() }
      function onPrimaryChanged() { dropdownBg.requestPaint() }
    }
  }

  onAnimatedHeightChanged: {
    if (animatedHeight === 0 && !active) _windowHeight = 0
  }

  // Expand/collapse on toggle
  onActiveChanged: {
    if (active) {
      _targetHeight = volumeColumn.implicitHeight + 46
      _windowHeight = _targetHeight
    } else {
      _targetHeight = 0
    }
  }

  // Bottom accent bar
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    height: 2
    color: Colors.primary
    property real animatedWidth: root.visible ? parent.width - root.diagSlant : 0
    width: animatedWidth
    Behavior on animatedWidth {
      NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
  }

  // Volume content column
  Column {
    id: volumeColumn
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 34
    spacing: 10
    width: parent.width - 24

    onImplicitHeightChanged: {
      if (root.active) {
        root._targetHeight = implicitHeight + 46
        root._windowHeight = root._targetHeight
      }
    }

    // Content fade-in and slide-up transition
    opacity: root.active && root._animatedHeight > (volumeColumn.implicitHeight * 0.5) ? 1 : 0
    transform: Translate {
      y: root.active && root._animatedHeight > (volumeColumn.implicitHeight * 0.5) ? 0 : -15
    }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Output section header
    Text {
      text: "OUTPUT"
      color: Colors.primary
      font.pixelSize: 14
      font.family: Style.fontFamily
      font.weight: Font.DemiBold
    }

    // Output sink devices (click to set as default)
    Repeater {
      model: Pipewire.nodes.values.filter(n => n && n.isSink && !n.isStream && n.audio)

      delegate: Item {
        width: sinkRow.implicitWidth
        height: sinkRow.implicitHeight

        Row {
          id: sinkRow
          spacing: 12

          Text {
            text: modelData === Pipewire.defaultAudioSink ? "󰕾" : "󰖀"
            font.pixelSize: 12
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
            width: 14
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            text: modelData.description || modelData.name || "Unknown Output"
            color: Colors.backgroundText
            font.pixelSize: 12
            font.family: Style.fontFamily
            font.weight: Font.Medium
            width: 120
            elide: Text.ElideRight
          }

          Text {
            text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
            color: Colors.tertiary
            font.pixelSize: 12
            font.family: Style.fontFamily
            font.weight: Font.Medium
            width: 32
            horizontalAlignment: Text.AlignRight
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Pipewire.preferredDefaultAudioSink = modelData
          }
        }
      }
    }

    // Input section header
    Text {
      text: "INPUT"
      color: Colors.primary
      font.pixelSize: 14
      font.family: Style.fontFamily
      font.weight: Font.DemiBold
      topPadding: 8
    }

    // Input source devices (click to set as default)
    Repeater {
      model: Pipewire.nodes.values.filter(n => n && !n.isSink && !n.isStream && n.audio)

      delegate: Item {
        width: sourceRow.implicitWidth
        height: sourceRow.implicitHeight

        Row {
          id: sourceRow
          spacing: 12

          Text {
            text: modelData === Pipewire.defaultAudioSource ? "󰍬" : "󰍭"
            font.pixelSize: 12
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
            width: 14
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            text: modelData.description || modelData.name || "Unknown Input"
            color: Colors.backgroundText
            font.pixelSize: 12
            font.family: Style.fontFamily
            font.weight: Font.Medium
            width: 120
            elide: Text.ElideRight
          }

          Text {
            text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
            color: Colors.tertiary
            font.pixelSize: 12
            font.family: Style.fontFamily
            font.weight: Font.Medium
            width: 32
            horizontalAlignment: Text.AlignRight
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Pipewire.preferredDefaultAudioSource = modelData
          }
        }
      }
    }
  }
}
