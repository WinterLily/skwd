import "../.."
import QtQuick

Rectangle {
    id: root

    // Dropdown animation state
    property bool active: false
    property string weatherCity: ""
    property var weatherForecast: []
    readonly property real animatedHeight: _animatedHeight
    readonly property real windowHeight: _windowHeight
    property real diagSlant: 28
    property real _targetHeight: 0
    property real _animatedHeight: _targetHeight
    property real _windowHeight: 0

    height: _animatedHeight
    visible: _animatedHeight > 0
    color: "transparent"
    onAnimatedHeightChanged: {
        if (animatedHeight === 0 && !active)
            _windowHeight = 0;

    }
    // Expand/collapse on toggle
    onActiveChanged: {
        if (active) {
            _targetHeight = forecastColumn.implicitHeight + 46;
            _windowHeight = _targetHeight;
        } else {
            _targetHeight = 0;
        }
    }

    Canvas {
        id: dropdownBg

        anchors.fill: parent
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width, height);
            ctx.lineTo(root.diagSlant, height);
            ctx.lineTo(0, height - root.diagSlant);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1);
            ctx.fill();
            if (Config.accentEdges) {
                ctx.beginPath();
                ctx.moveTo(0, height - root.diagSlant);
                ctx.lineTo(root.diagSlant, height);
                ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1);
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }
        }

        Connections {
            function onSurfaceChanged() {
                dropdownBg.requestPaint();
            }

            function onPrimaryChanged() {
                dropdownBg.requestPaint();
            }

            target: Colors
        }

    }

    // Bottom accent bar
    Rectangle {
        property real animatedWidth: root.visible ? parent.width - root.diagSlant : 0

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        height: 2
        color: Colors.primary
        width: animatedWidth

        Behavior on animatedWidth {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }

        }

    }

    // Forecast list (3-day)
    Column {
        id: forecastColumn

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        spacing: 10
        width: parent.width - 24
        onImplicitHeightChanged: {
            if (root.active) {
                root._targetHeight = implicitHeight + 46;
                root._windowHeight = root._targetHeight;
            }
        }
        // Content fade-in and slide-up transition
        opacity: root.active && root._animatedHeight > (forecastColumn.implicitHeight * 0.5) ? 1 : 0

        // City name header
        Text {
            text: root.weatherCity.toUpperCase()
            color: Colors.primary
            font.pixelSize: 14
            font.family: Style.fontFamily
            font.weight: Font.DemiBold
        }

        // Forecast day delegate (day name, high/low temps, description)
        Repeater {
            model: root.weatherForecast.slice(0, 3)

            delegate: Row {
                spacing: 12

                Text {
                    text: modelData.day
                    color: Colors.backgroundText
                    font.pixelSize: 12
                    font.family: Style.fontFamily
                    font.weight: Font.Medium
                    width: 60
                }

                Row {
                    spacing: 6

                    Text {
                        text: "H: " + modelData.high
                        color: Colors.primary
                        font.pixelSize: 12
                        font.family: Style.fontFamily
                        font.weight: Font.Medium
                    }

                    Text {
                        text: "L: " + modelData.low
                        color: Colors.tertiary
                        font.pixelSize: 12
                        font.family: Style.fontFamily
                        font.weight: Font.Medium
                    }

                }

                Text {
                    text: modelData.desc
                    color: Colors.backgroundText
                    font.pixelSize: 12
                    font.family: Style.fontFamily
                    opacity: 0.85
                    elide: Text.ElideRight
                }

            }

        }

        transform: Translate {
            y: root.active && root._animatedHeight > (forecastColumn.implicitHeight * 0.5) ? 0 : -15
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on _animatedHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }

    }

}
