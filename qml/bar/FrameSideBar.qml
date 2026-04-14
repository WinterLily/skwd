import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland

// One thin frame edge — instantiate once per side: "top" | "bottom" | "left" | "right".
// All four live on WlrLayer.Bottom so they sit behind the bar windows. The bar windows
// are transparent in the centre, letting the frame line show through there, while the
// opaque corner panels naturally cover the line at the screen corners.
PanelWindow {
    id: frameEdge

    property string side: "left"
    readonly property bool isHorizontal: side === "top" || side === "bottom"

    WlrLayershell.namespace: "frame-" + side
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // The non-anchored dimension determines the panel thickness.
    implicitWidth: isHorizontal ? 1 : Math.ceil(Config.frameThickness)
    implicitHeight: isHorizontal ? Math.ceil(Config.frameThickness) : 1
    color: "transparent"

    anchors {
        top: side !== "bottom"
        bottom: side !== "top"
        left: side !== "right"
        right: side !== "left"
    }

    // normal style: surface fill behind the accent line
    Rectangle {
        visible: Config.frameStyle === "normal"
        anchors.fill: parent
        color: Colors.surface
    }

    // accent-only: solid accent fill
    Rectangle {
        visible: Config.frameStyle !== "normal"
        anchors.fill: parent
        color: Colors.primary
    }

    // normal style: 1.5 px accent line on the inner (screen-content-facing) edge
    Rectangle {
        visible: Config.frameStyle === "normal"
        color: Colors.primary
        // x/y: place at the inner edge
        x: side === "left" ? parent.width - 1.5 : 0
        y: side === "top" ? parent.height - 1.5 : 0
        width: frameEdge.isHorizontal ? parent.width : 1.5
        height: frameEdge.isHorizontal ? 1.5 : parent.height
    }

}
