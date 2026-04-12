import ".."
import "../.."
import QtQuick
import QtQuick.Controls

Item {
    id: btn

    property bool isActive: false
    property string icon: ""
    property string label: ""
    property bool useNerdFont: icon !== ""
    property string tooltip: ""
    property int skew: 10
    property color activeColor: "transparent"
    property bool hasActiveColor: false
    property real activeOpacity: 1
    readonly property bool isHovered: _mouse.containsMouse
    readonly property color _resolvedActiveColor: btn.hasActiveColor ? btn.activeColor : (Colors.primary)

    signal clicked()

    width: _label.implicitWidth + 24 + skew
    height: 24
    z: isActive ? 10 : (isHovered ? 5 : 1)
    opacity: btn.activeOpacity

    Canvas {
        id: _canvas

        property color fillColor: btn.isActive ? btn._resolvedActiveColor : (btn.isHovered ? (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.5)) : "transparent")
        property color strokeColor: btn.isActive ? Qt.rgba(btn._resolvedActiveColor.r, btn._resolvedActiveColor.g, btn._resolvedActiveColor.b, 0.6) : (btn.isHovered ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)) : "transparent")

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

    Text {
        id: _label

        anchors.centerIn: parent
        text: btn.icon || btn.label
        font.pixelSize: btn.useNerdFont ? 14 : 10
        font.family: btn.useNerdFont ? Style.fontFamilyNerdIcons : Style.fontFamily
        font.weight: btn.useNerdFont ? Font.Normal : Font.Bold
        font.letterSpacing: btn.useNerdFont ? 0 : 0.5
        color: btn.isActive ? (btn.hasActiveColor ? "#fff" : (Colors.primaryText)) : (Colors.tertiary)
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
