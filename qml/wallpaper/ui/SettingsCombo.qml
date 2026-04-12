import ".."
import "../.."
import QtQuick

Column {
    id: root

    property string label: ""
    property string value: ""
    property var model: []
    property var onSelect

    width: parent ? parent.width : 0
    spacing: 2

    Text {
        text: root.label
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Colors.tertiary
    }

    Flow {
        width: parent.width
        spacing: 4

        Repeater {
            model: root.model

            Item {
                property bool _comboIsActive: root.value === modelData

                width: _comboLabel.implicitWidth + 24 + 8
                height: 26
                z: _comboIsActive ? 10 : (_comboMouse.containsMouse ? 5 : 1)

                Canvas {
                    id: _comboCanvas

                    property color fillColor: parent._comboIsActive ? (Colors.primary) : (_comboMouse.containsMouse ? (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.6)) : (Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.85)))
                    property color strokeColor: parent._comboIsActive ? Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.6) : (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15))

                    anchors.fill: parent
                    onFillColorChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var sk = 8;
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
                    id: _comboLabel

                    anchors.centerIn: parent
                    text: modelData
                    font.family: Style.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: parent._comboIsActive ? (Colors.primaryText) : (Colors.tertiary)
                }

                MouseArea {
                    id: _comboMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.onSelect)
                            root.onSelect(modelData);

                    }
                }

            }

        }

    }

}
