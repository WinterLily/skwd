import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

PanelWindow {
    id: sideBar

    // "left" or "right"
    required property string side

    screen: Quickshell.screens[0]
    WlrLayershell.namespace: "frame-" + side
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: side === "left"
        right: side === "right"
    }

    implicitWidth: Config.frameThickness
    color: "transparent"

    // Surface fill
    Rectangle {
        anchors.fill: parent
        color: Colors.surface
    }

    // Accent line on the screen-center-facing edge
    Rectangle {
        visible: Config.accentEdges
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: sideBar.side === "left" ? parent.right : undefined
        anchors.left: sideBar.side === "right" ? parent.left : undefined
        width: 1.5
        color: Colors.primary
    }
}
