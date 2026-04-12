import ".."
import "../.."
import QtQuick
import QtQuick.Controls

Item {
    id: dropdown

    property string label: ""
    property string value: ""
    property string displayValue: ""
    property var model: []
    property int skew: 8
    readonly property bool isHovered: _mouse.containsMouse
    property bool _popupOpen: false

    signal selected(string key)

    width: _btnLabel.implicitWidth + _arrow.implicitWidth + 28 + skew
    height: 24
    z: _popupOpen ? 100 : (isHovered ? 5 : 1)

    Canvas {
        id: _canvas

        property color fillColor: dropdown._popupOpen ? (Colors.primary) : (dropdown.value !== "" ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)) : (dropdown.isHovered ? (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.6)) : (Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.85))))
        property color strokeColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)

        anchors.fill: parent
        onFillColorChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var sk = dropdown.skew;
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
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: _btnLabel

            text: dropdown.displayValue || dropdown.label
            font.family: Style.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: dropdown._popupOpen ? (Colors.primaryText) : (Colors.tertiary)
        }

        Text {
            id: _arrow

            text: dropdown._popupOpen ? "▲" : "▼"
            font.pixelSize: 7
            color: _btnLabel.color
            anchors.verticalCenter: parent.verticalCenter
        }

    }

    MouseArea {
        id: _mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: _popup.open()
    }

    Popup {
        id: _popup

        x: 0
        y: dropdown.height + 4
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpenedChanged: dropdown._popupOpen = opened

        background: Rectangle {
            radius: 4
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.95)
            border.width: 1
            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
        }

        contentItem: Column {
            spacing: 1

            Repeater {
                model: dropdown.model

                Rectangle {
                    property bool _itemIsActive: dropdown.value === modelData.key

                    width: Math.max(_itemLabel.implicitWidth + 20, 80)
                    height: 22
                    radius: 2
                    color: _itemIsActive ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)) : (_itemMouse.containsMouse ? (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.4)) : "transparent")

                    Text {
                        id: _itemLabel

                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Style.fontFamily
                        font.pixelSize: 10
                        font.weight: parent._itemIsActive ? Font.Bold : Font.Medium
                        font.letterSpacing: 0.3
                        color: parent._itemIsActive ? (Colors.primary) : (Colors.surfaceText)
                    }

                    MouseArea {
                        id: _itemMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dropdown.selected(modelData.key);
                            _popup.close();
                        }
                    }

                }

            }

        }

    }

}
