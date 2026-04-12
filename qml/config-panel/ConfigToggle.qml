import ".."
import QtQuick

Item {
    property string label
    property bool checked

    signal toggled(bool v)

    width: parent ? parent.width : 400
    height: 36

    Row {
        anchors.fill: parent
        spacing: 12

        Text {
            width: 160
            text: label
            font.family: Style.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Colors.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }

        Item {
            width: 48
            height: 24
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: toggleBg

                property bool isOn: checked
                property color fillColor: isOn ? (Colors.primary) : (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.5))

                anchors.fill: parent
                onFillColorChanged: requestPaint()
                onIsOnChanged: requestPaint()
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
                }
            }

            Canvas {
                id: toggleKnob

                property color knobColor: checked ? (Colors.primaryText) : (Colors.surfaceText)

                width: 22
                height: 18
                y: 3
                x: checked ? parent.width - width - 4 : 4
                onKnobColorChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var sk = 5;
                    ctx.fillStyle = knobColor;
                    ctx.beginPath();
                    ctx.moveTo(sk, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width - sk, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggled(!checked)
            }

        }

    }

}
