import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."
import "widgets"

PanelWindow {
    id: bottomBar

    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "bottombar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
        left: true
        right: true
    }

    property real barHeight: 32
    required property var clock

    implicitHeight: barHeight
    exclusiveZone: barHeight
    color: "transparent"

    mask: Region {
        // Bottom-right corner panel
        x: bottomBar.width - brPanel.width
        y: 0
        width: brPanel.width
        height: bottomBar.barHeight

        // Bottom-left corner panel (when any widget is enabled, or framed mode)
        Region {
            x: 0
            y: 0
            width: (Config.blAnyEnabled || Config.frameMode) ? blPanel.width : 0
            height: bottomBar.barHeight
        }
    }

    // Bottom-right corner panel
    CornerPanel {
        id: brPanel
        corner: "bottom-right"
        anchors.right: parent.right
        anchors.top: parent.top
        height: bottomBar.barHeight

        WorkspaceWidget { visible: Config.brWorkspace; screen: bottomBar.screen }
        ModeToggleWidget { visible: Config.brModeToggle }
        BluetoothWidget  { visible: Config.brBluetooth }
        NetworkWidget    { visible: Config.brNetwork }
        BatteryWidget    { visible: Config.brBattery }
        VolumeWidget     { visible: Config.brVolume }
        WifiWidget       { id: brWifiWidget; visible: Config.brWifi && brWifiWidget.ssid !== "" }
        ClockWidget      { visible: Config.brCalendar; clock: bottomBar.clock }
    }

    // Bottom-left corner panel (hidden by default; always shown in framed mode)
    CornerPanel {
        id: blPanel
        corner: "bottom-left"
        anchors.left: parent.left
        anchors.top: parent.top
        height: bottomBar.barHeight
        visible: Config.blAnyEnabled || Config.frameMode

        WorkspaceWidget { visible: Config.blWorkspace; screen: bottomBar.screen }
        ModeToggleWidget { visible: Config.blModeToggle }
        BluetoothWidget  { visible: Config.blBluetooth }
        NetworkWidget    { visible: Config.blNetwork }
        BatteryWidget    { visible: Config.blBattery }
        VolumeWidget     { visible: Config.blVolume }
        WifiWidget       { id: blWifiWidget; visible: Config.blWifi && blWifiWidget.ssid !== "" }
        ClockWidget      { visible: Config.blCalendar; clock: bottomBar.clock }
    }

}
