import ".."
import "../.."
import QtQuick

Rectangle {
    id: root

    property bool cacheLoading: false
    property int cacheProgress: 0
    property int cacheTotal: 0

    width: 400
    height: 40
    radius: 20
    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.9)
    visible: cacheLoading
    opacity: cacheLoading ? 1 : 0

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 16
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 2
            width: root.cacheTotal > 0 ? parent.width * (root.cacheProgress / root.cacheTotal) : 0
            color: Colors.primary

            Behavior on width {
                NumberAnimation {
                    duration: Style.animVeryFast
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -12
        text: root.cacheTotal > 0 ? "PROCESSING WALLPAPERS... " + root.cacheProgress + " / " + root.cacheTotal : "PROCESSING EXISTING WALLPAPERS... PLEASE WAIT"
        color: Colors.tertiary
        font.family: Style.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 0.5
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Style.animNormal
        }

    }

}
