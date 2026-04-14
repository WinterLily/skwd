import "../.."
import QtQuick
import Quickshell.Bluetooth

Item {
    id: root

    readonly property var connectedDevices: {
        if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.devices)
            return [];

        return Bluetooth.defaultAdapter.devices.values.filter((d) => {
            return d && d.connected;
        });
    }
    readonly property string batteryText: {
        let bats = connectedDevices.filter((d) => {
            return d.batteryAvailable && d.battery > 0;
        }).map((d) => {
            return Math.round(d.battery * 100) + "%";
        });
        return bats.length > 0 ? bats[0] : "";
    }

    signal clicked()

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight

    Row {
        id: _row

        spacing: 4

        Text {
            text: "󰂯"
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: root.batteryText !== "" ? Colors.primary : Colors.tertiary

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }

            }

        }

        Text {
            text: root.batteryText
            visible: root.batteryText !== ""
            font.pixelSize: 12
            font.weight: Font.Medium
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
