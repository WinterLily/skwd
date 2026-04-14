import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland
import "dropdowns"
import "lyrics"
import "widgets"

PanelWindow {
    // ── Main bar container ────────────────────────────────────────────────────
    // ── Dropdowns (stacked below the right panel) ─────────────────────────────

    id: bar

    // Required properties from shell root
    required property var clock
    required property bool barVisible
    required property var activePlayer
    required property string weatherDesc
    required property string weatherTemp
    required property string weatherCity
    required property var weatherForecast
    required property var lyricsService
    property real barHeight: 32
    property real topMargin: -1
    property real waveformHeight: 14
    property real slideOffset: barVisible ? 0 : -(barHeight + topMargin)
    property real animatedBarHeight: barHeight + topMargin + slideOffset
    // Active dropdown name; "" means none open
    property string activeDropdown: ""
    // Dropdown height tracking (animated — for visuals, mask, and y positions)
    property real _wifiH: Config.trWifi ? wifiDropdown.animatedHeight : 0
    property real _volumeH: Config.trVolume ? volumeDropdown.animatedHeight : 0
    property real _calendarH: Config.trCalendar ? calendarDropdown.animatedHeight : 0
    property real _bluetoothH: Config.trBluetooth ? bluetoothDropdown.animatedHeight : 0
    property real _weatherH: Config.trWeather ? weatherDropdown.animatedHeight : 0
    property real totalDropdownHeight: _wifiH + _volumeH + _calendarH + _bluetoothH + _weatherH
    property real dropdownGap: 6
    // Window height (non-animated — jumps to final size to avoid per-frame surface resize)
    property real _wifiWH: Config.trWifi ? wifiDropdown.windowHeight : 0
    property real _volumeWH: Config.trVolume ? volumeDropdown.windowHeight : 0
    property real _calendarWH: Config.trCalendar ? calendarDropdown.windowHeight : 0
    property real _bluetoothWH: Config.trBluetooth ? bluetoothDropdown.windowHeight : 0
    property real _weatherWH: Config.trWeather ? weatherDropdown.windowHeight : 0
    property real totalWindowDropdownHeight: _wifiWH + _volumeWH + _calendarWH + _bluetoothWH + _weatherWH
    property bool _lyricsPlaying: Config.musicEnabled ? lyricsIsland.musicPlaying : false

    function closeAllDropdowns() {
        activeDropdown = "";
    }

    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "topbar"
    WlrLayershell.keyboardFocus: activeDropdown !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitHeight: Math.max(1, animatedBarHeight) + totalWindowDropdownHeight + (_lyricsPlaying ? waveformHeight : 0)
    exclusiveZone: barVisible ? barHeight + topMargin : 0
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    FocusScope {
        anchors.fill: parent
        focus: bar.activeDropdown !== ""
        Keys.onEscapePressed: bar.closeAllDropdowns()
    }

    Item {
        id: barRoot

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: bar.slideOffset + bar.topMargin
        height: bar.barHeight

        // Top-left corner panel
        CornerPanel {
            id: leftPanel

            corner: "top-left"
            anchors.left: parent.left
            anchors.top: parent.top
            height: bar.barHeight

            WorkspaceWidget {
                visible: Config.tlWorkspace
                screen: bar.screen
            }

            SystemStatsWidget {
                showCpu: Config.tlCpu
                showGpu: Config.tlGpu
                showMemory: Config.tlMemory
                visible: Config.tlCpu || Config.tlGpu || Config.tlMemory
            }

            WeatherWidget {
                id: tlWeatherWidget

                visible: Config.tlWeather && tlWeatherWidget.hasData
                weatherDesc: bar.weatherDesc
                weatherTemp: bar.weatherTemp
            }

            BluetoothWidget {
                id: tlBtWidget

                visible: Config.tlBluetooth
            }

            WifiWidget {
                id: tlWifiWidget

                visible: Config.tlWifi && tlWifiWidget.ssid !== ""
            }

            VolumeWidget {
                visible: Config.tlVolume
            }

            BatteryWidget {
                visible: Config.tlBattery
            }

            NetworkWidget {
                visible: Config.tlNetwork
            }

            ClockWidget {
                visible: Config.tlCalendar
                clock: bar.clock
                onClicked: bar.activeDropdown = bar.activeDropdown === "clock" ? "" : "clock"
            }

            ModeToggleWidget {
                visible: Config.tlModeToggle
            }

        }

        // Center — lyrics island
        LyricsIsland {
            id: lyricsIsland

            visible: Config.musicEnabled && (!Config.musicAutohide || (bar.activePlayer && bar.activePlayer.isPlaying))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            diagSlant: leftPanel.diagSlant
            barHeight: bar.barHeight
            waveformHeight: bar.waveformHeight
            service: bar.lyricsService
            activePlayer: bar.activePlayer
        }

        // Top-right corner panel — status widgets
        CornerPanel {
            id: rightPanel

            corner: "top-right"
            z: 1
            anchors.right: parent.right
            anchors.top: parent.top
            height: bar.barHeight

            WorkspaceWidget {
                visible: Config.trWorkspace
                screen: bar.screen
            }

            WeatherWidget {
                id: weatherWidget

                visible: Config.trWeather && weatherWidget.hasData
                weatherDesc: bar.weatherDesc
                weatherTemp: bar.weatherTemp
                onClicked: bar.activeDropdown = bar.activeDropdown === "weather" ? "" : "weather"
            }

            BluetoothWidget {
                id: btWidget

                visible: Config.trBluetooth
                onClicked: bar.activeDropdown = bar.activeDropdown === "bluetooth" ? "" : "bluetooth"
            }

            WifiWidget {
                id: wifiWidget

                visible: Config.trWifi && wifiWidget.ssid !== ""
                onClicked: bar.activeDropdown = bar.activeDropdown === "wifi" ? "" : "wifi"
            }

            VolumeWidget {
                id: volumeWidget

                visible: Config.trVolume
                onClicked: bar.activeDropdown = bar.activeDropdown === "volume" ? "" : "volume"
            }

            BatteryWidget {
                visible: Config.trBattery
            }

            ClockWidget {
                visible: Config.trCalendar
                clock: bar.clock
                onClicked: bar.activeDropdown = bar.activeDropdown === "clock" ? "" : "clock"
            }

        }

    }

    WiFiDropdown {
        id: wifiDropdown

        anchors.right: parent.right
        y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap
        width: rightPanel.width
        active: Config.trWifi && bar.activeDropdown === "wifi"
        wifiSsid: wifiWidget.ssid
        wifiSignalStrength: wifiWidget.signalStrength
    }

    VolumeDropdown {
        id: volumeDropdown

        anchors.right: parent.right
        y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH
        width: rightPanel.width
        active: Config.trVolume && bar.activeDropdown === "volume"
    }

    CalendarDropdown {
        id: calendarDropdown

        anchors.right: parent.right
        y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH + bar._volumeH
        width: Math.max(rightPanel.width, 256)
        active: Config.trCalendar && bar.activeDropdown === "clock"
        clock: bar.clock
    }

    BluetoothDropdown {
        id: bluetoothDropdown

        anchors.right: parent.right
        y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH + bar._volumeH + bar._calendarH
        width: rightPanel.width
        active: Config.trBluetooth && bar.activeDropdown === "bluetooth"
        connectedDevices: btWidget.connectedDevices
    }

    WeatherDropdown {
        id: weatherDropdown

        anchors.right: parent.right
        y: bar.slideOffset + bar.topMargin + bar.barHeight + bar.dropdownGap + bar._wifiH + bar._volumeH + bar._calendarH + bar._bluetoothH
        width: rightPanel.width
        active: Config.trWeather && bar.activeDropdown === "weather"
        weatherCity: bar.weatherCity
        weatherForecast: bar.weatherForecast
    }

    Behavior on slideOffset {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }

    }

    mask: Region {
        width: bar.width
        height: Math.max(1, bar.animatedBarHeight) + (bar._lyricsPlaying ? bar.waveformHeight : 0)

        Region {
            x: bar.width - rightPanel.width
            y: Math.max(1, bar.animatedBarHeight)
            width: rightPanel.width
            height: bar.totalDropdownHeight
        }

    }

}
