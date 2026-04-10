import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Shapes
import ".."

// Full-screen app launcher with parallelogram slice UI
Scope {
  id: appLauncher

  // External bindings
  property var colors
  property bool showing: false

  property string mainMonitor: Config.mainMonitor
  property string activeMonitor: mainMonitor
  property bool _panelVisible: false

  // Query the active monitor when the launcher opens.
  // _panelVisible stays false until this completes so the panels
  // become visible with isActive already correct.
  property var _activeMonitorProcess: Process {
    command: [Config.scriptsDir + "/bash/wm-action", "active-monitor"]
    running: false
    stdout: SplitParser {
      onRead: line => {
        var name = line.trim()
        if (name && name !== "?")
          appLauncher.activeMonitor = name
      }
    }
    onExited: (code, status) => {
      if (appLauncher.showing) {
        // Verify activeMonitor resolves to a real screen; fall back to first screen
        var screens = Quickshell.screens
        var matched = false
        for (var i = 0; i < screens.length; i++) {
          if (screens[i].name === appLauncher.activeMonitor) {
            matched = true
            break
          }
        }
        if (!matched && screens.length > 0) {
          console.warn("AppLauncher: activeMonitor '" + appLauncher.activeMonitor
            + "' not found in Quickshell.screens — falling back to '" + screens[0].name + "'")
          appLauncher.activeMonitor = screens[0].name
        }
        appLauncher._panelVisible = true
        cardShowTimer.restart()
      }
    }
  }

  // Service handles all data, search, caching, and launch logic
  AppLauncherService {
    id: service
    scriptsDir: Config.scriptsDir
    homeDir: Config.homeDir
    cacheDir: Config.cacheDir
    configDir: Config.configDir
    terminal: Config.terminal
  }

  // Show/hide lifecycle
  onShowingChanged: {
    if (showing) {
      _panelVisible = false
      activeMonitor = mainMonitor
      _activeMonitorProcess.running = true
      service.searchText = ""
      service.loadFreqData()
      service.start()
    } else {
      _panelVisible = false
      cardVisible = false
      service.searchText = ""
    }
  }

  Timer {
    id: cardShowTimer
    interval: 50
    onTriggered: appLauncher.cardVisible = true
  }

  // Slice geometry constants
  property int sliceWidth: 135
  property int expandedWidth: 924
  property int sliceHeight: 520
  property int skewOffset: 35
  property int sliceSpacing: -22

  // Hex mode
  property bool isHexMode: Config.launcherDisplayMode === "hex"
  property int hexRadius: Config.hexRadius
  property int hexRows: Config.launcherHexRows
  property int hexCols: Config.launcherHexCols

  // Card dimensions
  property int topBarHeight: 50
  property int cardWidth: isHexMode ? _hexCardWidth : 1600
  property int cardHeight: isHexMode ? _hexCardHeight : (sliceHeight + topBarHeight + 60)
  property int _hexCardWidth: {
    var r = hexRadius; var spacing = 14
    return Math.round((hexCols + 1) * (1.5 * r + spacing) + 2 * r)
  }
  property int _hexCardHeight: {
    var r = hexRadius; var rows = hexRows; var spacing = 14
    var hexH = Math.ceil(r * 1.73205); var stepY = hexH + spacing
    return (rows - 1) * stepY + hexH + Math.ceil(stepY / 2) + topBarHeight + 60
  }

  property bool cardVisible: false

  property int lastContentX: 0
  property int lastIndex: 0

  function resetScroll() {
    lastContentX = 0
    lastIndex = 0
  }


  // Full launcher UI — defined once, instantiated only on the active screen
  Component {
    id: launcherUIComponent

    Item {
      anchors.fill: parent

      // Sync service search text → input, and reset list on model change
      Connections {
        target: service
        function onSearchTextChanged() {
          if (searchInput.text !== service.searchText)
            searchInput.text = service.searchText
        }
        function onModelUpdated() {
          if (service.filteredModel.count > 0) {
            sliceListView.currentIndex = 0
            sliceListView.positionViewAtIndex(0, ListView.Beginning)
            hexListView.currentIndex = 0
            hexListView._selectedCol = 0
            hexListView._selectedRow = 0
          }
        }
      }

      Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
          if (appLauncher.isHexMode) hexListView.forceActiveFocus()
          else searchInput.forceActiveFocus()
        }
      }


      // Card container with fade-in animation
      Item {
        id: cardContainer
        width: appLauncher.cardWidth
        height: appLauncher.cardHeight
        anchors.centerIn: parent
        visible: appLauncher.cardVisible

        opacity: 0
        property bool animateIn: appLauncher.cardVisible

        onAnimateInChanged: {
          fadeInAnim.stop()
          if (animateIn) {
            opacity = 0
            fadeInAnim.start()
            focusTimer.restart()
          }
        }

        NumberAnimation {
          id: fadeInAnim
          target: cardContainer
          property: "opacity"
          from: 0; to: 1
          duration: 400
          easing.type: Easing.OutCubic
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }


        Item {
          id: backgroundRect
          anchors.fill: parent

          Item {
            id: filterBarBg
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            width: topFilterBar.width + 30
            height: topFilterBar.height + 14
            z: 10

            Canvas {
              anchors.fill: parent
              readonly property int _sk: 14
              property color fillColor: appLauncher.colors
                ? Qt.rgba(appLauncher.colors.surfaceContainer.r, appLauncher.colors.surfaceContainer.g, appLauncher.colors.surfaceContainer.b, 1.0)
                : Qt.rgba(0.1, 0.12, 0.18, 1.0)
              property color accentColor: appLauncher.colors
                ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.6)
                : Qt.rgba(1, 1, 1, 0.3)
              onFillColorChanged: requestPaint()
              onAccentColorChanged: requestPaint()
              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var sk = _sk
                ctx.fillStyle = fillColor
                ctx.beginPath()
                ctx.moveTo(sk, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width - sk, height)
                ctx.lineTo(0, height)
                ctx.closePath()
                ctx.fill()
                ctx.strokeStyle = accentColor
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(sk, 0)
                ctx.lineTo(0, height)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(width, 0)
                ctx.lineTo(width - sk, height)
                ctx.stroke()
              }
            }
          }

          // Top filter bar (source filters, search input)
          Row {
            id: topFilterBar
            anchors.centerIn: filterBarBg
            spacing: 16
            z: 11

            Row {
              id: sourceFilterRow
              spacing: 4
              anchors.verticalCenter: parent.verticalCenter

              Repeater {
                model: [
                  { filter: "", icon: "󰄶", label: "All" },
                  { filter: "desktop", icon: "󰀻", label: "Apps" },
                  { filter: "game", icon: "󰊗", label: "Games" },
                  { filter: "steam", icon: "󰓓", label: "Steam" }
                ]

                Rectangle {
                  width: 32
                  height: 24
                  radius: 4
                  property bool isSelected: service.sourceFilter === modelData.filter
                  property bool isHovered: sourceMouseArea.containsMouse

                  color: isSelected
                    ? (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7")
                    : (isHovered
                      ? (appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceVariant.r, appLauncher.colors.surfaceVariant.g, appLauncher.colors.surfaceVariant.b, 0.5) : Qt.rgba(1, 1, 1, 0.15))
                      : "transparent")

                  border.width: isSelected ? 0 : 1
                  border.color: isHovered ? (appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)) : "transparent"

                  Behavior on color { ColorAnimation { duration: 100 } }

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.pixelSize: 14
                    font.family: Style.fontFamilyIcons
                    color: parent.isSelected
                      ? (appLauncher.colors ? appLauncher.colors.primaryText : "#000")
                      : (appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff")
                  }

                  MouseArea {
                    id: sourceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (parent.isSelected) {
                        service.sourceFilter = ""
                      } else {
                        service.sourceFilter = modelData.filter
                      }
                    }
                  }

                  ToolTip {
                    visible: sourceMouseArea.containsMouse
                    text: modelData.label
                    delay: 500
                    contentWidth: implicitContentWidth
                  }
                }
              }
            }

            Rectangle {
              width: 1; height: 20
              color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.2)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "󰍉"
              font.family: Style.fontFamilyIcons
              font.pixelSize: 18
              color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchInput
              width: 200
              font.family: Style.fontFamily
              font.pixelSize: 14
              font.weight: Font.Medium
              color: "#ffffff"
              anchors.verticalCenter: parent.verticalCenter
              clip: true
              onTextChanged: service.searchText = text
              onAccepted: {
                if (appLauncher.isHexMode) {
                  var flatIdx = hexListView._selectedCol * hexListView._rows + hexListView._selectedRow
                  if (flatIdx >= 0 && flatIdx < service.filteredModel.count) {
                    var app = service.filteredModel.get(flatIdx)
                    service.launchApp(app.exec, app.terminal, app.name)
                    appLauncher.showing = false
                  }
                } else {
                  if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < service.filteredModel.count) {
                    var app = service.filteredModel.get(sliceListView.currentIndex)
                    service.launchApp(app.exec, app.terminal, app.name)
                    appLauncher.showing = false
                  }
                }
              }
              Keys.onEscapePressed: appLauncher.showing = false
              Keys.onLeftPressed: {
                if (appLauncher.isHexMode) {
                  if (hexListView.currentIndex > 0) { hexListView.currentIndex--; hexListView._selectedCol = hexListView.currentIndex }
                } else {
                  if (sliceListView.currentIndex > 0) { sliceListView.keyboardNavActive = true; sliceListView.currentIndex-- }
                }
                event.accepted = true
              }
              Keys.onRightPressed: {
                if (appLauncher.isHexMode) {
                  if (hexListView.currentIndex < hexListView.count - 1) { hexListView.currentIndex++; hexListView._selectedCol = hexListView.currentIndex }
                } else {
                  if (sliceListView.currentIndex < service.filteredModel.count - 1) { sliceListView.keyboardNavActive = true; sliceListView.currentIndex++ }
                }
                event.accepted = true
              }
              Keys.onUpPressed: {
                if (appLauncher.isHexMode && hexListView._selectedRow > 0) hexListView._selectedRow--
                event.accepted = appLauncher.isHexMode
              }
              Keys.onDownPressed: {
                if (appLauncher.isHexMode) {
                  var maxRow = Math.min(hexListView._rows, service.filteredModel.count - hexListView._selectedCol * hexListView._rows) - 1
                  if (hexListView._selectedRow < maxRow) hexListView._selectedRow++
                  event.accepted = true
                }
              }

              Text {
                anchors.fill: parent
                text: ""
                font: searchInput.font
                color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primaryText.r, appLauncher.colors.primaryText.g, appLauncher.colors.primaryText.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)
                visible: !searchInput.text
              }
            }

            Text {
              text: ""
              font.family: Style.fontFamily
              font.pixelSize: 11
              font.weight: Font.Medium
              color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primaryText.r, appLauncher.colors.primaryText.g, appLauncher.colors.primaryText.b, 0.5) : Qt.rgba(1, 1, 1, 0.5)
              anchors.verticalCenter: parent.verticalCenter
            }
          }


          // Cache loading overlay with progress bar
          Rectangle {
            anchors.fill: parent
            color: appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceContainer.r,
                                                 appLauncher.colors.surfaceContainer.g,
                                                 appLauncher.colors.surfaceContainer.b, 0.95)
                                      : Qt.rgba(0.08, 0.1, 0.14, 0.95)
            radius: 20
            visible: service.cacheLoading
            z: 50

            Rectangle {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: 12
              width: 300
              height: 4
              radius: 2
              color: Qt.rgba(1, 1, 1, 0.1)

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 2
                width: service.cacheTotal > 0
                  ? parent.width * (service.cacheProgress / service.cacheTotal)
                  : 0
                color: appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7"
                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
              }
            }

            Text {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: -12
              text: service.cacheTotal > 0
                ? "LOADING APPS... " + service.cacheProgress + " / " + service.cacheTotal
                : "SCANNING..."
              color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
              font.family: Style.fontFamily
              font.pixelSize: 12
              font.weight: Font.Medium
              font.letterSpacing: 0.5
            }
          }
        }
      }


      // Horizontal parallelogram slice list view
      ListView {
        id: sliceListView
        anchors.top: cardContainer.top
        anchors.topMargin: appLauncher.topBarHeight + 15
        anchors.bottom: cardContainer.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        property int visibleCount: 12
        width: appLauncher.expandedWidth + (visibleCount - 1) * (appLauncher.sliceWidth + appLauncher.sliceSpacing)

        orientation: ListView.Horizontal
        model: service.filteredModel
        clip: false
        spacing: appLauncher.sliceSpacing

        flickDeceleration: 1500
        maximumFlickVelocity: 3000
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: appLauncher.expandedWidth * 4

        visible: appLauncher.cardVisible && !appLauncher.isHexMode

        property bool keyboardNavActive: false
        property real lastMouseX: -1
        property real lastMouseY: -1

        highlightFollowsCurrentItem: true
        highlightMoveDuration: 350
        highlight: Item {}
        preferredHighlightBegin: (width - appLauncher.expandedWidth) / 2
        preferredHighlightEnd: (width + appLauncher.expandedWidth) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        header: Item { width: (sliceListView.width - appLauncher.expandedWidth) / 2; height: 1 }
        footer: Item { width: (sliceListView.width - appLauncher.expandedWidth) / 2; height: 1 }

        onVisibleChanged: {
          if (visible) searchInput.forceActiveFocus()
        }

        Connections {
          target: appLauncher
          function onShowingChanged() {
            if (appLauncher.showing && !appLauncher.isHexMode)
              searchInput.forceActiveFocus()
          }
        }

        MouseArea {
          anchors.fill: parent
          propagateComposedEvents: true
          onWheel: function(wheel) {
            var step = 1
            if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
              sliceListView.currentIndex = Math.max(0, sliceListView.currentIndex - step)
            } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
              sliceListView.currentIndex = Math.min(service.filteredModel.count - 1, sliceListView.currentIndex + step)
            }
          }
          onPressed: function(mouse) { mouse.accepted = false }
          onReleased: function(mouse) { mouse.accepted = false }
          onClicked: function(mouse) { mouse.accepted = false }
        }

        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            appLauncher.showing = false
            event.accepted = true
            return
          }

          if (event.text && event.text.length > 0 && !event.modifiers) {
            var c = event.text.charCodeAt(0)
            if (c >= 32 && c < 127) {
              searchInput.text += event.text
              searchInput.forceActiveFocus()
              event.accepted = true
              return
            }
          }

          if (event.key === Qt.Key_Backspace) {
            if (searchInput.text.length > 0)
              searchInput.text = searchInput.text.slice(0, -1)
            event.accepted = true
            return
          }

          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < service.filteredModel.count) {
              var app = service.filteredModel.get(sliceListView.currentIndex)
              service.launchApp(app.exec, app.terminal, app.name)
              appLauncher.showing = false
            }
            event.accepted = true
            return
          }

          sliceListView.keyboardNavActive = true

          if (event.key === Qt.Key_Left) {
            if (currentIndex > 0) currentIndex--
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Right) {
            if (currentIndex < service.filteredModel.count - 1) currentIndex++
            event.accepted = true
            return
          }
        }


        // Parallelogram slice delegate
        delegate: Item {
          id: delegateItem
          width: isCurrent ? appLauncher.expandedWidth : appLauncher.sliceWidth
          height: sliceListView.height
          property bool isCurrent: ListView.isCurrentItem
          property bool isHovered: itemMouseArea.containsMouse
          z: isCurrent ? 100 : (isHovered ? 90 : 50 - Math.min(Math.abs(index - sliceListView.currentIndex), 50))
          property real viewX: x - sliceListView.contentX
          property real fadeZone: appLauncher.sliceWidth * 1.5
          property real edgeOpacity: {
            if (fadeZone <= 0) return 1.0
            var center = viewX + width * 0.5
            var leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone))
            var rightFade = Math.min(1.0, Math.max(0.0, (sliceListView.width - center) / fadeZone))
            return Math.min(leftFade, rightFade)
          }
          opacity: edgeOpacity
          Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
          }


          // Parallelogram hit-testing mask
          containmentMask: Item {
            id: hitMask
            function contains(point) {
              var w = delegateItem.width
              var h = delegateItem.height
              var sk = appLauncher.skewOffset
              if (h <= 0 || w <= 0) return false
              var leftX = sk * (1.0 - point.y / h)
              var rightX = w - sk * (point.y / h)
              return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h
            }
          }


          // Drop shadow canvas behind slice
          Canvas {
            id: shadowCanvas
            z: -1
            anchors.fill: parent
            anchors.margins: -10
            property real shadowOffsetX: delegateItem.isCurrent ? 4 : 2
            property real shadowOffsetY: delegateItem.isCurrent ? 10 : 5
            property real shadowAlpha: delegateItem.isCurrent ? 0.6 : 0.4
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onShadowAlphaChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var ox = 10
              var oy = 10
              var w = delegateItem.width
              var h = delegateItem.height
              var sk = appLauncher.skewOffset
              var sx = shadowOffsetX
              var sy = shadowOffsetY
              var layers = [
                { dx: sx, dy: sy, alpha: shadowAlpha * 0.5 },
                { dx: sx * 0.6, dy: sy * 0.6, alpha: shadowAlpha * 0.3 },
                { dx: sx * 1.4, dy: sy * 1.4, alpha: shadowAlpha * 0.2 }
              ]
              for (var i = 0; i < layers.length; i++) {
                var l = layers[i]
                ctx.globalAlpha = l.alpha
                ctx.fillStyle = "#000000"
                ctx.beginPath()
                ctx.moveTo(ox + sk + l.dx, oy + l.dy)
                ctx.lineTo(ox + w + l.dx, oy + l.dy)
                ctx.lineTo(ox + w - sk + l.dx, oy + h + l.dy)
                ctx.lineTo(ox + l.dx, oy + h + l.dy)
                ctx.closePath()
                ctx.fill()
              }
            }
          }


          // Image container (background, thumbnail, parallelogram mask)
          Item {
            id: imageContainer
            anchors.fill: parent

            Image {
              id: bgImage
              anchors.fill: parent
              source: model.background ? "file://" + model.background : ""
              fillMode: Image.PreserveAspectCrop
              smooth: true
              asynchronous: true
              visible: status === Image.Ready
              sourceSize.width: appLauncher.expandedWidth
              sourceSize.height: appLauncher.sliceHeight
            }

            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0.0; color: appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceContainer.r, appLauncher.colors.surfaceContainer.g, appLauncher.colors.surfaceContainer.b, 1) : "#1a1c2e" }
                GradientStop { position: 1.0; color: appLauncher.colors ? Qt.rgba(appLauncher.colors.surface.r, appLauncher.colors.surface.g, appLauncher.colors.surface.b, 1) : "#0e1018" }
              }
              visible: !bgImage.visible
            }

            Text {
              anchors.centerIn: parent
              text: model.customIcon || ""
              font.family: Style.fontFamilyIcons
              font.pixelSize: 48
              color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.7) : Qt.rgba(1, 1, 1, 0.5)
              visible: model.customIcon !== "" && !bgImage.visible
            }

            Image {
              id: thumbImage
              anchors.fill: parent
              source: model.thumb ? "file://" + model.thumb : ""
              fillMode: model.source === "steam" ? Image.PreserveAspectCrop : Image.Pad
              horizontalAlignment: Image.AlignHCenter
              verticalAlignment: Image.AlignVCenter
              smooth: true
              asynchronous: true
              sourceSize.width: appLauncher.expandedWidth
              sourceSize.height: appLauncher.sliceHeight
              visible: model.thumb !== "" && !bgImage.visible
            }

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.4))
              Behavior on color { ColorAnimation { duration: 200 } }
            }

            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: ShaderEffectSource {
                sourceItem: Item {
                  width: imageContainer.width
                  height: imageContainer.height
                  layer.enabled: true
                  layer.smooth: true
                  layer.samples: 8
                  Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                      fillColor: "white"
                      strokeColor: "transparent"
                      startX: appLauncher.skewOffset
                      startY: 0
                      PathLine { x: delegateItem.width; y: 0 }
                      PathLine { x: delegateItem.width - appLauncher.skewOffset; y: delegateItem.height }
                      PathLine { x: 0; y: delegateItem.height }
                      PathLine { x: appLauncher.skewOffset; y: 0 }
                    }
                  }
                }
              }
              maskThresholdMin: 0.3
              maskSpreadAtMin: 0.3
            }
          }


          // Parallelogram glow border
          Shape {
            id: glowBorder
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            opacity: 1.0
            ShapePath {
              fillColor: "transparent"
              strokeColor: delegateItem.isCurrent
                ? (appLauncher.colors ? appLauncher.colors.primary : "#8BC34A")
                : (delegateItem.isHovered
                  ? Qt.rgba(appLauncher.colors ? appLauncher.colors.primary.r : 0.5, appLauncher.colors ? appLauncher.colors.primary.g : 0.76, appLauncher.colors ? appLauncher.colors.primary.b : 0.29, 0.4)
                  : Qt.rgba(0, 0, 0, 0.6))
              Behavior on strokeColor { ColorAnimation { duration: 200 } }
              strokeWidth: delegateItem.isCurrent ? 3 : 1
              startX: appLauncher.skewOffset
              startY: 0
              PathLine { x: delegateItem.width; y: 0 }
              PathLine { x: delegateItem.width - appLauncher.skewOffset; y: delegateItem.height }
              PathLine { x: 0; y: delegateItem.height }
              PathLine { x: appLauncher.skewOffset; y: 0 }
            }
          }


          Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            width: 22
            height: 22
            radius: 11
            color: model.source === "steam"
              ? (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7")
              : Qt.rgba(0, 0, 0, 0.7)
            border.width: 1
            border.color: model.source === "steam"
              ? "transparent"
              : (appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.6) : Qt.rgba(1, 1, 1, 0.4))
            visible: model.source === "steam"
            z: 10

            Text {
              anchors.centerIn: parent
              text: "󰓓"
              font.family: Style.fontFamilyIcons
              font.pixelSize: 12
              color: model.source === "steam"
                ? (appLauncher.colors ? appLauncher.colors.primaryText : "#000")
                : (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7")
            }
          }


          // App name label (visible when selected)
          Rectangle {
            id: nameLabel
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            width: nameText.width + 24
            height: 32
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.75)
            border.width: 1
            border.color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.2)
            visible: delegateItem.isCurrent
            opacity: delegateItem.isCurrent ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Text {
              id: nameText
              anchors.centerIn: parent
              text: (model.displayName || model.name).toUpperCase()
              font.family: Style.fontFamily
              font.pixelSize: 12
              font.weight: Font.Bold
              font.letterSpacing: 0.5
              color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
              elide: Text.ElideMiddle
              maximumLineCount: 1
              width: Math.min(implicitWidth, delegateItem.width - 60)
            }
          }


          // Category type badge (bottom-right)
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: appLauncher.skewOffset + 8
            width: typeBadgeText.width + 8
            height: 16
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.75)
            border.width: 1
            border.color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)
            z: 10

            Text {
              id: typeBadgeText
              anchors.centerIn: parent
              text: model.source === "steam" ? "STEAM"
                : model.categories.indexOf("Game") !== -1 ? "GAME"
                : model.categories.indexOf("Development") !== -1 ? "DEV"
                : model.categories.indexOf("Graphics") !== -1 ? "GFX"
                : (model.categories.indexOf("AudioVideo") !== -1 || model.categories.indexOf("Audio") !== -1 || model.categories.indexOf("Video") !== -1) ? "MEDIA"
                : model.categories.indexOf("Network") !== -1 ? "NET"
                : model.categories.indexOf("Office") !== -1 ? "OFFICE"
                : model.categories.indexOf("System") !== -1 ? "SYS"
                : model.categories.indexOf("Settings") !== -1 ? "CFG"
                : model.categories.indexOf("Utility") !== -1 ? "UTIL"
                : "APP"
              font.family: Style.fontFamily
              font.pixelSize: 9
              font.weight: Font.Bold
              font.letterSpacing: 0.5
              color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
            }
          }


          // Mouse interaction (hover selects, click launches)
          MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              var globalPos = mapToItem(sliceListView, mouse.x, mouse.y)
              var dx = Math.abs(globalPos.x - sliceListView.lastMouseX)
              var dy = Math.abs(globalPos.y - sliceListView.lastMouseY)
              if (dx > 2 || dy > 2) {
                sliceListView.lastMouseX = globalPos.x
                sliceListView.lastMouseY = globalPos.y
                sliceListView.keyboardNavActive = false
                sliceListView.currentIndex = index
              }
            }
            onClicked: function(mouse) {
              if (delegateItem.isCurrent) {
                service.launchApp(model.exec, model.terminal, model.name)
                appLauncher.showing = false
              } else {
                sliceListView.currentIndex = index
              }
            }
          }
        }
      }

      // Hex grid layout
      ListView {
        id: hexListView
        anchors.top: cardContainer.top
        anchors.topMargin: appLauncher.topBarHeight + 15
        anchors.bottom: cardContainer.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: appLauncher._hexCardWidth - 40

        orientation: ListView.Horizontal
        clip: false
        visible: appLauncher.cardVisible && appLauncher.isHexMode

        property int _rows: appLauncher.hexRows
        property real _r: appLauncher.hexRadius
        property real _gridSpacing: 14
        property real _hexW: _r * 2
        property real _hexH: Math.ceil(_r * 1.73205)
        property real _stepX: 1.5 * _r + _gridSpacing
        property real _stepY: _hexH + _gridSpacing
        property real _gridContentH: (_rows - 1) * _stepY + _hexH + _stepY / 2
        property real _yOffset: Math.max(0, (height - _gridContentH) / 2)
        property int _selectedCol: 0
        property int _selectedRow: 0

        model: Math.ceil(service.filteredModel.count / Math.max(1, _rows))

        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1500
        maximumFlickVelocity: 3000
        spacing: 0

        highlightFollowsCurrentItem: true
        highlightMoveDuration: 350
        highlight: Item {}
        preferredHighlightBegin: (width - _hexW) / 2
        preferredHighlightEnd: (width + _hexW) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange

        header: Item { width: (hexListView.width - hexListView._hexW) / 2 }
        footer: Item { width: (hexListView.width - hexListView._hexW) / 2 }

        onVisibleChanged: {
          if (visible) {
            var startCol = Math.min(Math.floor(appLauncher.hexCols / 2), count - 1)
            if (startCol >= 0) { currentIndex = startCol; _selectedCol = startCol; _selectedRow = 0 }
            if (!appLauncher.isHexMode) searchInput.forceActiveFocus()
          }
        }

        MouseArea {
          anchors.fill: parent
          propagateComposedEvents: true
          onWheel: function(wheel) {
            var delta = (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) ? -1 : 1
            hexListView.currentIndex = Math.max(0, Math.min(hexListView.count - 1, hexListView.currentIndex + delta))
            hexListView._selectedCol = hexListView.currentIndex
          }
          onPressed: function(mouse) { mouse.accepted = false }
          onReleased: function(mouse) { mouse.accepted = false }
          onClicked: function(mouse) { mouse.accepted = false }
        }

        Keys.onEscapePressed: appLauncher.showing = false
        Keys.onReturnPressed: {
          var flatIdx = _selectedCol * _rows + _selectedRow
          if (flatIdx >= 0 && flatIdx < service.filteredModel.count) {
            var app = service.filteredModel.get(flatIdx)
            service.launchApp(app.exec, app.terminal, app.name)
            appLauncher.showing = false
          }
        }
        Keys.onLeftPressed: { if (currentIndex > 0) { currentIndex--; _selectedCol = currentIndex } }
        Keys.onRightPressed: { if (currentIndex < count - 1) { currentIndex++; _selectedCol = currentIndex } }
        Keys.onUpPressed: { if (_selectedRow > 0) _selectedRow-- }
        Keys.onDownPressed: {
          var maxRow = Math.min(_rows, service.filteredModel.count - _selectedCol * _rows) - 1
          if (_selectedRow < maxRow) _selectedRow++
        }
        Keys.onPressed: function(event) {
          if (event.text && event.text.length > 0 && !event.modifiers) {
            var c = event.text.charCodeAt(0)
            if (c >= 32 && c < 127) {
              searchInput.text += event.text
              searchInput.forceActiveFocus()
              event.accepted = true
            }
          }
          if (event.key === Qt.Key_Backspace) {
            if (searchInput.text.length > 0) searchInput.text = searchInput.text.slice(0, -1)
            event.accepted = true
          }
        }

        delegate: Item {
          id: hexCol
          width: hexListView._stepX
          height: hexListView.height
          clip: false
          property int colIdx: index

          readonly property real _colCenter: (x - hexListView.contentX) + width * 0.5
          readonly property bool _nearEdge: _colCenter < hexListView._stepX || _colCenter > (hexListView.width - hexListView._stepX)
          readonly property bool _nearLeft: _colCenter < hexListView.width / 2
          property real _colScale: !_nearEdge ? 1 : 0
          Behavior on _colScale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

          readonly property real _arcOffset: {
            var viewCenterX = hexListView.width / 2
            var normalized = (_colCenter - viewCenterX) / Math.max(1, viewCenterX)
            return -normalized * normalized * hexListView._r * 1.2
          }

          Repeater {
            model: Math.max(0, Math.min(hexListView._rows, service.filteredModel.count - hexCol.colIdx * hexListView._rows))

            Item {
              id: hexItem
              property int rowIdx: index
              property int flatIdx: hexCol.colIdx * hexListView._rows + rowIdx
              property var appData: flatIdx < service.filteredModel.count ? service.filteredModel.get(flatIdx) : null
              property bool isSelected: hexCol.colIdx === hexListView._selectedCol && rowIdx === hexListView._selectedRow
              property bool isHovered: hexItemMouse.containsMouse

              width: hexListView._hexW
              height: hexListView._hexH
              x: 0
              y: hexListView._yOffset + rowIdx * hexListView._stepY + (hexCol.colIdx % 2 !== 0 ? hexListView._stepY / 2 : 0) + hexCol._arcOffset

              scale: hexCol._colScale
              transformOrigin: hexCol._nearLeft ? Item.Left : Item.Right
              opacity: hexCol._colScale < 0.01 ? 0 : 1

              readonly property real _r: hexListView._r
              readonly property real _cx: _r
              readonly property real _cy: height / 2
              readonly property real _cos30: 0.866025
              readonly property real _sin30: 0.5

              Item {
                id: hexItemMask
                width: parent.width; height: parent.height
                visible: false
                layer.enabled: true
                Shape {
                  anchors.fill: parent
                  antialiasing: true
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath {
                    fillColor: "white"; strokeColor: "transparent"
                    startX: hexItem._cx + hexItem._r;               startY: hexItem._cy
                    PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                    PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                    PathLine { x: hexItem._cx - hexItem._r;                  y: hexItem._cy }
                    PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                    PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                    PathLine { x: hexItem._cx + hexItem._r;                  y: hexItem._cy }
                  }
                }
              }

              Item {
                anchors.fill: parent
                Rectangle {
                  anchors.fill: parent
                  color: appLauncher.colors
                    ? Qt.rgba(appLauncher.colors.surfaceContainer.r, appLauncher.colors.surfaceContainer.g, appLauncher.colors.surfaceContainer.b, 1.0)
                    : Qt.rgba(0.1, 0.12, 0.18, 1.0)
                }
                Image {
                  id: hexIconImg
                  anchors.centerIn: parent
                  width: hexItem._r * 1.1; height: hexItem._r * 1.1
                  source: hexItem.appData && hexItem.appData.iconPath ? "file://" + hexItem.appData.iconPath : ""
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  asynchronous: true
                }
                Text {
                  anchors.centerIn: parent
                  text: hexItem.appData ? hexItem.appData.name.substring(0, 1).toUpperCase() : "?"
                  font.pixelSize: hexItem._r * 0.65
                  font.weight: Font.Bold
                  color: appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7"
                  visible: hexIconImg.status !== Image.Ready
                }
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                  maskEnabled: true
                  maskSource: hexItemMask
                  maskThresholdMin: 0.3
                  maskSpreadAtMin: 0.3
                }
              }

              // Dimming overlay when not selected
              Item {
                anchors.fill: parent
                Rectangle {
                  anchors.fill: parent
                  color: Qt.rgba(0, 0, 0, hexItem.isSelected ? 0 : (hexItem.isHovered ? 0.1 : 0.35))
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                  maskEnabled: true
                  maskSource: hexItemMask
                  maskThresholdMin: 0.3
                  maskSpreadAtMin: 0.3
                }
              }

              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "transparent"
                  strokeColor: hexItem.isSelected
                    ? (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7")
                    : Qt.rgba(0, 0, 0, 0.5)
                  Behavior on strokeColor { ColorAnimation { duration: 100 } }
                  strokeWidth: hexItem.isSelected ? 3 : 1.5
                  startX: hexItem._cx + hexItem._r;               startY: hexItem._cy
                  PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy - hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx - hexItem._r;                  y: hexItem._cy }
                  PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx + hexItem._r;                  y: hexItem._cy }
                }
              }

              // Accent colour rim: bottom-left and bottom edges
              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "transparent"
                  strokeColor: appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7"
                  strokeWidth: 3
                  capStyle: ShapePath.RoundCap
                  joinStyle: ShapePath.RoundJoin
                  startX: hexItem._cx - hexItem._r;               startY: hexItem._cy
                  PathLine { x: hexItem._cx - hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                  PathLine { x: hexItem._cx + hexItem._r * hexItem._sin30; y: hexItem._cy + hexItem._r * hexItem._cos30 }
                }
              }

              Text {
                anchors.top: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 4
                text: hexItem.appData ? hexItem.appData.name : ""
                font.family: Style.fontFamily
                font.pixelSize: 9
                font.weight: Font.Medium
                color: hexItem.isSelected
                  ? (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7")
                  : (appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceText.r, appLauncher.colors.surfaceText.g, appLauncher.colors.surfaceText.b, 0.7) : Qt.rgba(1, 1, 1, 0.6))
                maximumLineCount: 1
                elide: Text.ElideRight
                width: hexListView._hexW + hexListView._gridSpacing
                horizontalAlignment: Text.AlignHCenter
              }

              MouseArea {
                id: hexItemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function contains(point) {
                  var dx = Math.abs(point.x - hexItem._cx)
                  var dy = Math.abs(point.y - hexItem._cy)
                  return dy <= hexItem._cos30 * hexItem._r && dx <= hexItem._r - dy * 0.57735
                }
                onContainsMouseChanged: {
                  if (containsMouse) {
                    hexListView._selectedCol = hexCol.colIdx
                    hexListView._selectedRow = rowIdx
                  }
                }
                onClicked: {
                  if (hexItem.appData) {
                    service.launchApp(hexItem.appData.exec, hexItem.appData.terminal, hexItem.appData.name)
                    appLauncher.showing = false
                  }
                }
              }
            }
          }
        }
      }
    }
  }


  // One PanelWindow per screen — screen is fixed at Variants creation time,
  // never reassigned. isActive controls which one gets the full UI and keyboard focus.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: screenPanel
      property var modelData
      property bool isActive: modelData.name === appLauncher.activeMonitor

      screen: modelData

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      visible: appLauncher._panelVisible
      color: "transparent"

      WlrLayershell.namespace: "app-launcher"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      exclusionMode: ExclusionMode.Ignore

      // Dim overlay shown on all screens
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: appLauncher.cardVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }

      // Click anywhere on any screen to close
      MouseArea {
        anchors.fill: parent
        onClicked: appLauncher.showing = false
      }

      // Full launcher UI — only instantiated on the active screen
      Loader {
        anchors.fill: parent
        active: isActive
        sourceComponent: launcherUIComponent
      }
    }
  }
}
