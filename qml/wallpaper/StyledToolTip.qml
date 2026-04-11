import QtQuick
import QtQuick.Controls

ToolTip {
    id: root

    property int maxWidth: 300

    contentWidth: Math.min(Math.ceil(metrics.advanceWidth), maxWidth)

    TextMetrics {
        id: metrics

        text: root.text
        font: root.font
    }

    contentItem: Text {
        text: root.text
        font: root.font
        wrapMode: Text.WordWrap
        color: root.palette.toolTipText
    }

}
