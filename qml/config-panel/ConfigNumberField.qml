import ".."
import QtQuick

Item {
    property string label
    property int value

    signal edited(int v)

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
            width: 140
            height: 30
            radius: 6
            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
            border.width: numInput.activeFocus ? 1 : 0
            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

            TextInput {
                id: numInput

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Style.fontFamilyCode
                font.pixelSize: 11
                color: Colors.tertiary
                clip: true
                text: value.toString()
                selectByMouse: true
                selectionColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                onTextEdited: {
                    var n = parseInt(text);
                    if (!isNaN(n))
                        edited(n);

                }

                validator: IntValidator {
                    bottom: 0
                }

            }

        }

    }

}
