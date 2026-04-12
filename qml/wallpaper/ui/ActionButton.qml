import ".."
import "../.."
import QtQuick

Item {
    id: btn

    property string icon: ""
    property string label: ""
    property int skew: 5
    property bool danger: false
    property string tooltip: ""
    readonly property bool isHovered: _mouse.containsMouse

    signal clicked()

    height: 30
    implicitWidth: _contentRow.implicitWidth + 20 + skew
    implicitHeight: 30

    Canvas {
        id: _canvas

        property color fillColor: btn.isHovered ? (btn.danger ? Qt.rgba(1, 0.3, 0.3, 0.25) : (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.5))) : (Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.7))
        property color strokeColor: btn.isHovered ? (btn.danger ? Qt.rgba(1, 0.3, 0.3, 0.4) : (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4))) : (Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2))

        anchors.fill: parent
        onFillColorChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var sk = btn.skew;
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

    Row {
        id: _contentRow

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: btn.icon
            font.family: Style.fontFamilyNerdIcons
            font.pixelSize: 12
            color: btn.danger && btn.isHovered ? "#ff6b6b" : (Colors.tertiary)
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                ColorAnimation {
                    duration: Style.animVeryFast
                }

            }

        }

        Text {
            text: btn.label
            font.family: Style.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: btn.danger && btn.isHovered ? "#ff6b6b" : (Colors.tertiary)
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                ColorAnimation {
                    duration: Style.animVeryFast
                }

            }

        }

    }

    MouseArea {
        id: _mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    StyledToolTip {
        visible: btn.tooltip !== "" && _mouse.containsMouse
        text: btn.tooltip
        delay: Style.tooltipDelay
    }

}
