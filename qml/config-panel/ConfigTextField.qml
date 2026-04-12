import ".."
import QtQuick

Item {
    property string label
    property string value
    property string placeholder: ""

    signal edited(string v)

    width: parent ? parent.width : 400
    height: 36

    Row {
        anchors.fill: parent
        spacing: 12

        Text {
            width: 160
            text: label
            font.family: Style.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Colors.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width - 172
            height: 30
            radius: 6
            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
            border.width: fieldInput.activeFocus ? 1 : 0
            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

            TextInput {
                id: fieldInput

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Style.fontFamilyCode
                font.pixelSize: 11
                color: Colors.tertiary
                clip: true
                text: value
                selectByMouse: true
                selectionColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                onTextEdited: edited(text)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: placeholder
                    font: parent.font
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                    visible: !parent.text && !parent.activeFocus
                }

            }

        }

    }

}
