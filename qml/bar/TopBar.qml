// Imports
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "lyrics"
import "dropdowns"


PanelWindow {
  id: bar


  // Required properties from parent
  required property var clock
  required property bool barVisible
  required property var activePlayer
  required property string weatherDesc
  required property string weatherTemp
  required property string weatherCity
  required property var weatherForecast
  required property var lyricsService
  screen: Quickshell.screens.find(s => s.name === Config.mainMonitor) ?? Quickshell.screens[0]
  WlrLayershell.namespace: "topbar"
  WlrLayershell.keyboardFocus: {
    if (activeDropdown !== "") {
      return WlrKeyboardFocus.Exclusive
    }
    return WlrKeyboardFocus.None
  }

  anchors {
    top: true
    left: true
    right: true
  }

  // Bar dimensions and slide animation
  property real barHeight: 32
  property real topMargin: -1
  property real waveformHeight: 14
  property real slideOffset: barVisible ? 0 : -(barHeight + topMargin)


  // Dropdown state management
  property string activeDropdown: ""

  function closeAllDropdowns() {
    activeDropdown = ""
  }


  FocusScope {
    anchors.fill: parent
    focus: bar.activeDropdown !== ""
    Keys.onEscapePressed: {
      bar.closeAllDropdowns()
    }
  }

  property real animatedBarHeight: barHeight + topMargin + slideOffset

  // Dropdown height calculations for stacking (animated — used for visuals, mask, and y positions)
  property real _wifiH: Config.wifiEnabled ? wifiDropdown.animatedHeight : 0
  property real _volumeH: Config.volumeEnabled ? volumeDropdown.animatedHeight : 0
  property real _calendarH: Config.calendarEnabled ? calendarDropdown.animatedHeight : 0
  property real _bluetoothH: Config.bluetoothEnabled ? bluetoothDropdown.animatedHeight : 0
  property real _weatherH: Config.weatherEnabled ? weatherDropdown.animatedHeight : 0
  property real totalDropdownHeight: _wifiH + _volumeH + _calendarH + _bluetoothH + _weatherH
  property real dropdownGap: 6

  // Window height calculations (non-animated — jumps to final size immediately to avoid per-frame surface resize)
  property real _wifiWH: Config.wifiEnabled ? wifiDropdown.windowHeight : 0
  property real _volumeWH: Config.volumeEnabled ? volumeDropdown.windowHeight : 0
  property real _calendarWH: Config.calendarEnabled ? calendarDropdown.windowHeight : 0
  property real _bluetoothWH: Config.bluetoothEnabled ? bluetoothDropdown.windowHeight : 0
  property real _weatherWH: Config.weatherEnabled ? weatherDropdown.windowHeight : 0
  property real totalWindowDropdownHeight: _wifiWH + _volumeWH + _calendarWH + _bluetoothWH + _weatherWH

  property bool _lyricsPlaying: Config.musicEnabled ? lyricsIsland.musicPlaying : false
  implicitHeight: Math.max(1, animatedBarHeight) + totalWindowDropdownHeight + (_lyricsPlaying ? waveformHeight : 0)
  exclusiveZone: barVisible ? barHeight + topMargin : 0
  color: "transparent"


  // Workspace focus dispatcher
  Process {
    id: wsDispatcher
    command: ["true"]
    function focusWorkspace(wsId) {
      command = [Config.scriptsDir + "/bash/wm-action", "focus-workspace", wsId.toString()]
      running = true
    }
  }

  mask: Region {
    // Bar area (full width, includes waveform for lyrics)
    width: bar.width
    height: Math.max(1, bar.animatedBarHeight) + (bar._lyricsPlaying ? bar.waveformHeight : 0)

    // Dropdown + right panel area (right-aligned)
    Region {
      x: bar.width - rightPanel.width
      y: Math.max(1, bar.animatedBarHeight)
      width: rightPanel.width
      height: bar.totalDropdownHeight
    }
  }

  Behavior on slideOffset {
    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
  }


  // Shape slant angle for parallelogram panels
  property real diagSlant: 28


  // Bluetooth device and battery info
  QtObject {
    id: bluetoothInfo
    property var connectedDevices: {
      if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.devices) return []
      return Bluetooth.defaultAdapter.devices.values.filter(dev => dev && dev.connected)
    }
    property string batteryText: {
      let batteries = connectedDevices
        .filter(d => d.batteryAvailable && d.battery > 0)
        .map(d => Math.round(d.battery * 100) + "%")
      return batteries.length > 0 ? batteries[0] : ""
    }
  }


  // Main bar layout container
  Item {
    id: barRoot
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: bar.slideOffset + bar.topMargin
    height: bar.barHeight


    // Left panel (CPU, GPU, memory stats)
    Item {
      id: leftPanel
      visible: true
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: leftContent.implicitWidth + bar.diagSlant + 24

      Canvas {
        id: leftBg
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)

          ctx.beginPath()
          ctx.moveTo(0, 0)
          ctx.lineTo(width, 0)
          ctx.lineTo(width - bar.diagSlant, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1.0)
          ctx.fill()

          if (Config.accentEdges) {
            ctx.beginPath()
            ctx.moveTo(0, height)
            ctx.lineTo(width - bar.diagSlant, height)
            ctx.lineTo(width, 0)
            ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1.0)
            ctx.lineWidth = 1.5
            ctx.lineJoin = "miter"
            ctx.stroke()
          }
        }
        Connections {
          target: Colors
          function onSurfaceChanged() { leftBg.requestPaint() }
          function onPrimaryChanged() { leftBg.requestPaint() }
        }
      }


      Row {
        id: leftContent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -bar.diagSlant / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8


        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Text {
            text: "󰻠"
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
          }
          Text {
            text: Math.round(SystemStatService.cpuUsage) + "%"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
          }
          Text {
            text: Math.round(SystemStatService.cpuTemp) + "°"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
          }
        }


        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Text {
            text: "󰢮"
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
          }
          Text {
            text: Math.round(SystemStatService.gpuUsage) + "%"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
          }
          Text {
            text: Math.round(SystemStatService.gpuTemp) + "°"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
          }
        }


        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Text {
            text: "󰍛"
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
          }
          Text {
            text: Math.round(SystemStatService.memUsage) + "%"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
          }
        }

      }
    }


    // Center panel (lyrics island)
    LyricsIsland {
      id: lyricsIsland
      visible: Config.musicEnabled && (!Config.musicAutohide || (bar.activePlayer && bar.activePlayer.isPlaying))
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      diagSlant: bar.diagSlant
      barHeight: bar.barHeight
      waveformHeight: bar.waveformHeight
      service: bar.lyricsService
      activePlayer: bar.activePlayer
    }
  }


    // Right panel (weather, bluetooth, wifi, volume, clock)
    Item {
      id: rightPanel
      z: 1
      anchors.right: parent.right
      anchors.top: parent.top
      height: bar.barHeight
      width: rightContent.implicitWidth + bar.diagSlant + 24

      Canvas {
        id: rightBg
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)

          ctx.beginPath()
          ctx.moveTo(0, 0)
          ctx.lineTo(width, 0)
          ctx.lineTo(width, height)
          ctx.lineTo(0 + bar.diagSlant, height)
          ctx.closePath()
          ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1.0)
          ctx.fill()

          if (Config.accentEdges) {
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(bar.diagSlant, height)
            ctx.lineTo(width, height)
            ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1.0)
            ctx.lineWidth = 1.5
            ctx.lineJoin = "miter"
            ctx.stroke()
          }
        }
        Connections {
          target: Colors
          function onSurfaceChanged() { rightBg.requestPaint() }
          function onPrimaryChanged() { rightBg.requestPaint() }
        }
      }


      Row {
        id: rightContent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: bar.diagSlant / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14


        // Weather widget with condition icon
        Item {
          id: weatherWidget
          implicitWidth: weatherRow.implicitWidth
          implicitHeight: weatherRow.implicitHeight
          visible: Config.weatherEnabled && bar.weatherTemp !== "" && bar.weatherTemp !== undefined

          Row {
            id: weatherRow
            spacing: 4
            Text {
              text: {
                let desc = bar.weatherDesc.toLowerCase()
                if (desc.includes("thunder")) return "󰙾"
                if (desc.includes("blizzard") || desc.includes("blowing snow")) return "󰼶"
                if (desc.includes("heavy snow")) return "󰼶"
                if (desc.includes("snow")) return "󰖘"
                if (desc.includes("ice pellet") || desc.includes("sleet")) return "󰙿"
                if (desc.includes("torrential") || desc.includes("heavy rain")) return "󰖖"
                if (desc.includes("freezing rain") || desc.includes("freezing drizzle")) return "󰙿"
                if (desc.includes("rain") || desc.includes("drizzle") || desc.includes("shower")) return "󰖗"
                if (desc.includes("fog") || desc.includes("mist")) return "󰖑"
                if (desc.includes("overcast") || desc.includes("cloudy")) return "󰖐"
                if (desc.includes("partly")) return "󰖕"
                if (desc.includes("sunny") || desc.includes("clear")) return "󰖙"
                return "󰖐"
              }
              font.pixelSize: 14
              font.family: Style.fontFamilyNerdIcons
              color: Colors.primary
            }
            Text {
              text: bar.weatherTemp
              font.pixelSize: 12
              font.weight: Font.Medium
              font.family: Style.fontFamily
              color: Colors.tertiary
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              bar.activeDropdown = bar.activeDropdown === "weather" ? "" : "weather"
            }
          }
        }


        // Bluetooth widget with battery level
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

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              bar.activeDropdown = bar.activeDropdown === "bluetooth" ? "" : "bluetooth"
            }
          }
        }


        // WiFi widget with signal strength
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
                let s = wifiInfo.signalStrength
                if (s < 25) return "󰤟"
                if (s < 50) return "󰤢"
                if (s < 75) return "󰤥"
                return "󰤨"
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

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              bar.activeDropdown = bar.activeDropdown === "wifi" ? "" : "wifi"
            }
          }
          Process {
            id: wifiStatusProcess
            property string pendingSsid: ""
            command: ["sh", "-c", "iwctl station " + Config.wifiInterface + " show 2>/dev/null | awk '/Connected network/{print $3} /^[[:space:]]*RSSI/{gsub(/-| dBm/,\"\"); print $2}'"]
            onExited: {
              wifiInfo.ssid = pendingSsid !== "" ? pendingSsid : ""
              pendingSsid = ""
              wifiPollTimer.start()
            }
            stdout: SplitParser {
              onRead: data => {
                let trimmed = data.trim()
                if (trimmed && !trimmed.match(/^-?[0-9]+$/)) {
                  wifiStatusProcess.pendingSsid = trimmed
                } else if (trimmed.match(/^-?[0-9]+$/)) {
                  let rssi = -parseInt(trimmed)
                  wifiInfo.signalStrength = Math.max(0, Math.min(100, (rssi + 90) * 100 / 60))
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


        // Volume widget with level icon
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
                let vol = Pipewire.defaultAudioSink?.audio?.volume ?? 0
                if (vol === 0) return "󰖁"
                if (vol < 0.33) return "󰕿"
                if (vol < 0.66) return "󰖀"
                return "󰕾"
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

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              bar.activeDropdown = bar.activeDropdown === "volume" ? "" : "volume"
            }
          }
        }


        // Clock widget
        Item {
          id: clockWidget
          visible: Config.calendarEnabled
          implicitWidth: clockRow.implicitWidth
          implicitHeight: clockRow.implicitHeight

          Row {
            id: clockRow
            spacing: 0
            Text {
              text: Qt.formatTime(bar.clock.date, "HH")
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
              text: Qt.formatTime(bar.clock.date, "mm")
              font.pixelSize: 13
              font.weight: Font.DemiBold
              font.family: Style.fontFamily
              color: Colors.tertiary
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              bar.activeDropdown = bar.activeDropdown === "clock" ? "" : "clock"
            }
          }
        }

      }
    }

  // Dropdown panel instances (stacked below the bar)
  WiFiDropdown {
    id: wifiDropdown
    anchors.right: parent.right
    y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap
    width: rightPanel.width
    active: Config.wifiEnabled && bar.activeDropdown === "wifi"
    wifiSsid: wifiInfo.ssid
    wifiSignalStrength: wifiInfo.signalStrength
  }

  VolumeDropdown {
    id: volumeDropdown
    anchors.right: parent.right
    y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH
    width: rightPanel.width
    active: Config.volumeEnabled && bar.activeDropdown === "volume"
  }

  CalendarDropdown {
    id: calendarDropdown
    anchors.right: parent.right
    y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH + bar._volumeH
    width: Math.max(rightPanel.width, 256)
    active: Config.calendarEnabled && bar.activeDropdown === "clock"
    clock: bar.clock
  }

  BluetoothDropdown {
    id: bluetoothDropdown
    anchors.right: parent.right
    y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH + bar._volumeH + bar._calendarH
    width: rightPanel.width
    active: Config.bluetoothEnabled && bar.activeDropdown === "bluetooth"
    connectedDevices: bluetoothInfo.connectedDevices
  }

  WeatherDropdown {
    id: weatherDropdown
    anchors.right: parent.right
    y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH + bar._volumeH + bar._calendarH + bar._bluetoothH
    width: rightPanel.width
    active: Config.weatherEnabled && bar.activeDropdown === "weather"
    weatherCity: bar.weatherCity
    weatherForecast: bar.weatherForecast
  }
}
