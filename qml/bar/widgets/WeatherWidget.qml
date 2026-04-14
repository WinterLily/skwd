import "../.."
import QtQuick

Item {
    id: root

    property string weatherDesc: ""
    property string weatherTemp: ""
    readonly property bool hasData: weatherTemp !== "" && weatherTemp !== undefined

    signal clicked()

    implicitWidth: _row.implicitWidth
    implicitHeight: _row.implicitHeight

    Row {
        id: _row

        spacing: 4

        Text {
            text: {
                let desc = root.weatherDesc.toLowerCase();
                if (desc.includes("thunder"))
                    return "󰙾";

                if (desc.includes("blizzard") || desc.includes("blowing snow"))
                    return "󰼶";

                if (desc.includes("heavy snow"))
                    return "󰼶";

                if (desc.includes("snow"))
                    return "󰖘";

                if (desc.includes("ice pellet") || desc.includes("sleet"))
                    return "󰙿";

                if (desc.includes("torrential") || desc.includes("heavy rain"))
                    return "󰖖";

                if (desc.includes("freezing rain") || desc.includes("freezing drizzle"))
                    return "󰙿";

                if (desc.includes("rain") || desc.includes("drizzle") || desc.includes("shower"))
                    return "󰖗";

                if (desc.includes("fog") || desc.includes("mist"))
                    return "󰖑";

                if (desc.includes("overcast") || desc.includes("cloudy"))
                    return "󰖐";

                if (desc.includes("partly"))
                    return "󰖕";

                if (desc.includes("sunny") || desc.includes("clear"))
                    return "󰖙";

                return "󰖐";
            }
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            color: Colors.primary
        }

        Text {
            text: root.weatherTemp
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
