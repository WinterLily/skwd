import ".."
import QtQuick
import QtQuick.Controls

// Search panel with source filters and search input
// Note: Keyboard handling is kept in AppLauncher.qml since it needs
// to coordinate between search input and grid navigation
Row {
    id: root

    // External bindings
    property var service
    property alias searchText: searchInput.text
    readonly property alias searchInputItem: searchInput

    spacing: 16

    // Source filter buttons
    Row {
        id: sourceFilterRow

        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: [{
                "filter": "",
                "icon": "󰄶",
                "label": "All"
            }, {
                "filter": "desktop",
                "icon": "󰀻",
                "label": "Apps"
            }, {
                "filter": "game",
                "icon": "󰊗",
                "label": "Games"
            }, {
                "filter": "steam",
                "icon": "󰓓",
                "label": "Steam"
            }]

            Item {
                property bool isSelected: root.service ? root.service.sourceFilter === modelData.filter : false
                property bool isHovered: sourceMouseArea.containsMouse
                readonly property int skew: 9

                width: 32 + skew
                height: 24

                Canvas {
                    property color fillColor: parent.isSelected ? Colors.primary : (parent.isHovered ? Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.5) : "transparent")
                    property color strokeColor: parent.isSelected ? "transparent" : (parent.isHovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : "transparent")

                    anchors.fill: parent
                    onFillColorChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var sk = parent.skew;
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

                    Behavior on fillColor {
                        ColorAnimation {
                            duration: 100
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.pixelSize: 14
                    font.family: Style.fontFamilyIcons
                    color: parent.isSelected ? Colors.primaryText : Colors.tertiary
                }

                MouseArea {
                    id: sourceMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.isSelected)
                            root.service.sourceFilter = "";
                        else
                            root.service.sourceFilter = modelData.filter;
                    }
                }

                ToolTip {
                    visible: sourceMouseArea.containsMouse
                    text: modelData.label
                    delay: 500
                    contentWidth: implicitContentWidth
                }

            }

        }

    }

    Rectangle {
        width: 1
        height: 20
        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: "󰍉"
        font.family: Style.fontFamilyIcons
        font.pixelSize: 18
        color: Colors.tertiary
        anchors.verticalCenter: parent.verticalCenter
    }

    TextInput {
        id: searchInput

        width: 200
        font.family: Style.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        onTextChanged: root.service.searchText = text

        Text {
            anchors.fill: parent
            text: "Search..."
            font: searchInput.font
            color: Qt.rgba(Colors.primaryText.r, Colors.primaryText.g, Colors.primaryText.b, 0.4)
            visible: !searchInput.text
        }

    }

}
