import ".."
import QtQuick

Rectangle {
    id: root

    property var panel

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 52
    color: "transparent"

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        height: 1
        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Item {
            width: discardCanvas.width + 4
            height: 34
            opacity: root.panel.hasUnsavedChanges ? 1 : 0.3

            Canvas {
                id: discardCanvas

                property bool hovered: discardMouse.containsMouse
                property color fillColor: hovered ? (Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2)) : "transparent"
                property color strokeColor: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.5)

                anchors.centerIn: parent
                width: 120
                height: 30
                onFillColorChanged: requestPaint()
                onStrokeColorChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var sk = root.panel.skewOffset;
                    ctx.fillStyle = fillColor;
                    ctx.beginPath();
                    ctx.moveTo(sk, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width - sk, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();
                    ctx.strokeStyle = strokeColor;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }

            Text {
                anchors.centerIn: discardCanvas
                text: "DISCARD"
                font.family: Style.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 0.5
                color: Colors.error
            }

            MouseArea {
                id: discardMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.panel.hasUnsavedChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.panel.hasUnsavedChanges)
                        root.panel.discardChanges();

                }
            }

        }

        Item {
            width: saveCanvas.width + 4
            height: 34
            opacity: root.panel.hasUnsavedChanges ? 1 : 0.3

            Canvas {
                id: saveCanvas

                property bool hovered: saveMouse.containsMouse
                property color fillColor: hovered ? (Colors.primary) : (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2))
                property color strokeColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)

                anchors.centerIn: parent
                width: 120
                height: 30
                onFillColorChanged: requestPaint()
                onStrokeColorChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var sk = root.panel.skewOffset;
                    ctx.fillStyle = fillColor;
                    ctx.beginPath();
                    ctx.moveTo(sk, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width - sk, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();
                    ctx.strokeStyle = strokeColor;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }

            Text {
                anchors.centerIn: saveCanvas
                text: "SAVE"
                font.family: Style.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 0.5
                color: saveMouse.containsMouse ? (Colors.primaryText) : (Colors.primary)
            }

            MouseArea {
                id: saveMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.panel.hasUnsavedChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.panel.hasUnsavedChanges)
                        root.panel.saveAll();

                }
            }

        }

    }

}
