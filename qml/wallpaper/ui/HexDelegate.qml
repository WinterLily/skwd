import ".."
import "../.."
import "../../components"
import "../services"
import QtMultimedia
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

HexItem {
    id: hexItem

    property var colors
    property var service
    property var itemData
    property bool isSelected: false
    property bool pulledOut: false
    property real parallaxX: 0
    property real parallaxY: 0
    // ── Geometry driven by caller ─────────────────────────────
    property real hexRadius: 140
    // ── Video preview ─────────────────────────────────────────
    property string videoPath: itemData && itemData.videoFile ? itemData.videoFile : ""
    property bool hasVideo: videoPath.length > 0 && Config.videoPreviewEnabled
    property bool videoActive: false

    signal flipRequested(var data, real gx, real gy, var sourceItem)
    signal hoverSelected()

    radius: hexRadius
    // ── Border & accent driven by colors ──────────────────────
    selectedBorderColor: colors ? colors.primary : Style.fallbackAccent
    borderColor: Qt.rgba(0, 0, 0, 0.5)
    accentColor: colors ? colors.primary : Style.fallbackAccent
    // ── Mouse ─────────────────────────────────────────────────
    onHovered: hexItem.hoverSelected()
    onClicked: (mouse) => {
        if (!itemData)
            return ;

        if (itemData.type === "we")
            service.applyWE(itemData.weId);
        else if (itemData.type === "video")
            service.applyVideo(itemData.path);
        else
            service.applyStatic(itemData.path);
    }
    onRightClicked: (mouse) => {
        if (!itemData)
            return ;

        var gp = hexItem.mapToItem(null, hexItem.cx, hexItem.cy);
        hexItem.flipRequested(itemData, gp.x, gp.y, hexItem);
    }
    onIsSelectedChanged: {
        if (isSelected && hasVideo) {
            _videoDelayTimer.restart();
        } else {
            _videoDelayTimer.stop();
            videoActive = false;
        }
    }

    Timer {
        id: _videoDelayTimer

        interval: 300
        onTriggered: hexItem.videoActive = true
    }

    // ── Wallpaper image (clipped to hex) ─────────────────────
    Item {
        anchors.fill: parent
        opacity: hexItem.pulledOut ? 0 : 1
        layer.enabled: true
        layer.smooth: true

        Image {
            id: thumbImage

            width: hexItem.width * 1.3
            height: hexItem.height * 1.3
            x: (hexItem.width - width) / 2 + hexItem.parallaxX
            y: (hexItem.height - height) / 2 + hexItem.parallaxY
            source: hexItem.itemData && hexItem.itemData.thumb ? ImageService.fileUrl(hexItem.itemData.thumb) : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            cache: false
            sourceSize.width: Math.ceil(hexItem.width * 1.3)
            sourceSize.height: Math.ceil(hexItem.height * 1.3)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animFast
            }

        }

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: hexItem.mask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
        }

    }

    // ── Video preview (clipped to hex) ────────────────────────
    Loader {
        id: _videoLoader

        width: hexItem.width
        height: hexItem.height
        active: hexItem.videoActive
        visible: false
        layer.enabled: active

        sourceComponent: Video {
            anchors.fill: parent
            source: ImageService.fileUrl(hexItem.videoPath)
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: true
            Component.onCompleted: play()
        }

    }

    Item {
        anchors.fill: parent
        visible: _videoLoader.active && _videoLoader.status === Loader.Ready
        opacity: hexItem.pulledOut ? 0 : 1
        layer.enabled: true
        layer.smooth: true

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: _videoLoader
            live: true
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animFast
            }

        }

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: hexItem.mask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
        }

    }

    // ── Pulled-out placeholder (dashed outline, no image) ────
    Shape {
        anchors.fill: parent
        visible: hexItem.pulledOut
        opacity: hexItem.pulledOut ? 1 : 0
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: hexItem.colors ? Qt.rgba(hexItem.colors.primary.r, hexItem.colors.primary.g, hexItem.colors.primary.b, 0.08) : Qt.rgba(1, 1, 1, 0.05)
            strokeColor: hexItem.colors ? Qt.rgba(hexItem.colors.primary.r, hexItem.colors.primary.g, hexItem.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            startX: hexItem.cx + hexItem.radius
            startY: hexItem.cy

            PathLine {
                x: hexItem.cx + hexItem.radius * hexItem._sin30
                y: hexItem.cy - hexItem.radius * hexItem._cos30
            }

            PathLine {
                x: hexItem.cx - hexItem.radius * hexItem._sin30
                y: hexItem.cy - hexItem.radius * hexItem._cos30
            }

            PathLine {
                x: hexItem.cx - hexItem.radius
                y: hexItem.cy
            }

            PathLine {
                x: hexItem.cx - hexItem.radius * hexItem._sin30
                y: hexItem.cy + hexItem.radius * hexItem._cos30
            }

            PathLine {
                x: hexItem.cx + hexItem.radius * hexItem._sin30
                y: hexItem.cy + hexItem.radius * hexItem._cos30
            }

            PathLine {
                x: hexItem.cx + hexItem.radius
                y: hexItem.cy
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animFast
            }

        }

    }

    // ── Color dots ────────────────────────────────────────────
    Row {
        property var _wpColors: {
            if (!hexItem.service || !hexItem.itemData)
                return undefined;

            var key = hexItem.itemData.weId ? hexItem.itemData.weId : ImageService.thumbKey(hexItem.itemData.thumb, hexItem.itemData.name);
            return key ? hexItem.service.matugenDb[key] : undefined;
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: hexItem.radius * 0.18
        spacing: 4
        z: 5
        visible: Config.wallpaperColorDots && _wpColors !== undefined

        Repeater {
            model: ["primary", "tertiary", "secondary"]

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: parent.parent._wpColors ? (parent.parent._wpColors[modelData] ?? "#888") : "#888"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.5)
            }

        }

    }

    // ── Type badge (PIC / VID / WE) ───────────────────────────
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hexItem.radius * 0.18
        width: _typeLabel.implicitWidth + 14
        height: 18
        radius: 9
        color: Qt.rgba(0, 0, 0, 0.75)
        border.width: 1
        border.color: hexItem.colors ? Qt.rgba(hexItem.colors.primary.r, hexItem.colors.primary.g, hexItem.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)
        z: 5

        Text {
            id: _typeLabel

            anchors.centerIn: parent
            text: hexItem.itemData ? (hexItem.itemData.type === "static" ? "PIC" : ((hexItem.itemData.type === "video" || hexItem.itemData.videoFile) ? "VID" : "WE")) : ""
            font.family: Style.fontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: hexItem.colors ? hexItem.colors.tertiary : "#8bceff"
        }

    }

    // ── Video-active indicator ────────────────────────────────
    Rectangle {
        x: hexItem.cx + hexItem.radius * hexItem._sin30 - width - 4
        y: hexItem.cy - hexItem.radius * hexItem._cos30 + 8
        width: 20
        height: 20
        radius: 10
        color: hexItem.videoActive ? (hexItem.colors ? hexItem.colors.primary : Style.fallbackAccent) : Qt.rgba(0, 0, 0, 0.7)
        border.width: 1
        border.color: hexItem.videoActive ? "transparent" : (hexItem.colors ? Qt.rgba(hexItem.colors.primary.r, hexItem.colors.primary.g, hexItem.colors.primary.b, 0.6) : Qt.rgba(1, 1, 1, 0.4))
        visible: hexItem.hasVideo
        z: 5

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            text: "▶"
            font.pixelSize: 8
            color: hexItem.videoActive ? (hexItem.colors ? hexItem.colors.primaryText : "#000") : (hexItem.colors ? hexItem.colors.primary : Style.fallbackAccent)
        }

        Behavior on color {
            ColorAnimation {
                duration: Style.animFast
            }

        }

    }

}
