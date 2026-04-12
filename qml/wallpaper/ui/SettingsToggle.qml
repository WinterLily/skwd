import ".."
import "../.."
import QtQuick
import QtQuick.Shapes

Row {
    id: root

    property string label: ""
    property bool checked: false
    property var onToggle
    property real _skew: 4

    width: parent ? parent.width : 0
    height: 28
    spacing: 8

    Item {
        id: track

        width: 40
        height: 20
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            anchors.fill: parent

            ShapePath {
                fillColor: root.checked ? (Colors.primary) : (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.6))
                strokeColor: root.checked ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.8)) : (Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3))
                strokeWidth: 1
                startX: root._skew
                startY: 0

                PathLine {
                    x: track.width
                    y: 0
                }

                PathLine {
                    x: track.width - root._skew
                    y: track.height
                }

                PathLine {
                    x: 0
                    y: track.height
                }

                PathLine {
                    x: root._skew
                    y: 0
                }

            }

        }

        Item {
            id: thumb

            width: 16
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3

            Shape {
                anchors.fill: parent

                ShapePath {
                    fillColor: root.checked ? (Colors.primaryText) : (Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7))
                    strokeWidth: 0
                    startX: root._skew * 0.6
                    startY: 0

                    PathLine {
                        x: thumb.width
                        y: 0
                    }

                    PathLine {
                        x: thumb.width - root._skew * 0.6
                        y: thumb.height
                    }

                    PathLine {
                        x: 0
                        y: thumb.height
                    }

                    PathLine {
                        x: root._skew * 0.6
                        y: 0
                    }

                }

            }

            Behavior on x {
                NumberAnimation {
                    duration: Style.animFast
                    easing.type: Easing.OutCubic
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.onToggle)
                    root.onToggle(!root.checked);

            }
        }

    }

    Text {
        text: root.label
        anchors.verticalCenter: parent.verticalCenter
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Colors.tertiary
    }

}
