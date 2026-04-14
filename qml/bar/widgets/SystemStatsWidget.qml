import QtQuick
import "../../services"
import "../.."

Item {
    id: root

    property bool showCpu: true
    property bool showGpu: true
    property bool showMemory: true

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight

    Row {
        id: _row
        spacing: 8

        Row {
            visible: root.showCpu
            spacing: 4
            Text {
                text: "󰻠"
                font.pixelSize: 14
                font.family: Style.fontFamilyNerdIcons
                color: Colors.primary
            }
            Text {
                text: Math.round(SystemStatService.cpuUsage) + "%"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: Style.fontFamily
                color: Colors.tertiary
            }
            Text {
                text: Math.round(SystemStatService.cpuTemp) + "°"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: Style.fontFamily
                color: Colors.tertiary
            }
        }

        Row {
            visible: root.showMemory
            spacing: 4
            Text {
                text: "󰍛"
                font.pixelSize: 14
                font.family: Style.fontFamilyNerdIcons
                color: Colors.primary
            }
            Text {
                text: Math.round(SystemStatService.memUsage) + "%"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: Style.fontFamily
                color: Colors.tertiary
            }
        }
    }
}
