import "../.."
import QtQuick

Item {
    id: root

    required property var clock

    signal clicked()

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight

    Row {
        id: _row

        spacing: 0

        Text {
            text: Qt.formatTime(root.clock.date, "HH")
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.family: Style.fontFamily
            color: Colors.primary
        }

        Text {
            text: ":"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.family: Style.fontFamily
            color: Colors.tertiary
        }

        Text {
            text: Qt.formatTime(root.clock.date, "mm")
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.family: Style.fontFamily
            color: Colors.tertiary
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
