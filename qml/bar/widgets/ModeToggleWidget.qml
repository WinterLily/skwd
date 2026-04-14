import "../.."
import QtQuick

Item {
    id: root

    implicitWidth: _icon.implicitWidth
    implicitHeight: _icon.implicitHeight

    Text {
        id: _icon

        text: ColorMode.isDark ? "󰖔" : "󰖙"
        font.pixelSize: 16
        font.family: Style.fontFamilyNerdIcons
        color: Colors.primary

        Behavior on color {
            ColorAnimation {
                duration: 200
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ColorMode.toggle()
    }

}
