import ".."
import QtQuick

Text {
    property int topPad: 0
    property var colors

    topPadding: topPad
    font.family: Style.fontFamily
    font.pixelSize: 13
    font.weight: Font.Bold
    font.letterSpacing: 1
    color: colors ? colors.primary : "#4fc3f7"
}
