import ".."
import "../.."
import QtQuick

Column {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property var onCommit
    property var onFocused

    width: parent ? parent.width : 0
    spacing: 2

    Text {
        text: root.label
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Colors.tertiary
    }

    Rectangle {
        width: parent.width
        height: 26
        radius: 4
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
        border.width: inputField.activeFocus ? 1 : 0
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

        TextInput {
            id: inputField

            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.fontFamilyCode
            font.pixelSize: 11
            color: Colors.tertiary
            clip: true
            selectByMouse: true
            text: root.value
            onActiveFocusChanged: {
                if (activeFocus && root.onFocused)
                    root.onFocused();

            }
            onEditingFinished: {
                if (root.onCommit)
                    root.onCommit(text);

            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                font: parent.font
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                text: root.placeholder
                visible: !inputField.text && !inputField.activeFocus
            }

        }

    }

}
