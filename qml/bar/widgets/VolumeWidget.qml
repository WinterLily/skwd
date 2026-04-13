import QtQuick
import Quickshell.Services.Pipewire
import "../.."

Item {
    id: root

    signal clicked()

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight

    Row {
        id: _row
        spacing: 4

        Text {
            text: {
                let vol = Pipewire.defaultAudioSink?.audio?.volume ?? 0;
                if (vol === 0)    return "󰖁";
                if (vol < 0.33)  return "󰕿";
                if (vol < 0.66)  return "󰖀";
                return "󰕾";
            }
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
            width: 16
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: Style.fontFamily
            color: Colors.tertiary
            width: Math.max(implicitWidth, 28)
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
