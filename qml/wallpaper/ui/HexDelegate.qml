import ".."
import "../.."
import "../services"
import QtMultimedia
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: hexItem

    property var service
    property int hexRadius: 140
    property var itemData
    property bool isSelected: false
    property bool isHovered: hexMouse.containsMouse
    property bool pulledOut: false
    property real parallaxX: 0
    property real parallaxY: 0
    property string videoPath: itemData && itemData.videoFile ? itemData.videoFile : ""
    property bool hasVideo: videoPath.length > 0 && Config.videoPreviewEnabled
    property bool videoActive: false
    readonly property real _r: hexRadius
    readonly property real _cx: _r
    readonly property real _cy: height / 2
    readonly property real _cos30: 0.866025
    readonly property real _sin30: 0.5

    signal flipRequested(var data, real gx, real gy, var sourceItem)
    signal hoverSelected()

    onIsSelectedChanged: {
        if (isSelected && hasVideo) {
            _videoDelayTimer.restart();
        } else {
            _videoDelayTimer.stop();
            videoActive = false;
        }
    }
    width: hexRadius * 2
    height: Math.ceil(hexRadius * 1.73205)

    Timer {
        id: _videoDelayTimer

        interval: 300
        onTriggered: hexItem.videoActive = true
    }

    Item {
        id: hexMask

        width: hexItem.width
        height: hexItem.height
        visible: false
        layer.enabled: true

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: hexItem._cx + hexItem._r
                startY: hexItem._cy

                PathLine {
                    x: hexItem._cx + hexItem._r * hexItem._sin30
                    y: hexItem._cy - hexItem._r * hexItem._cos30
                }

                PathLine {
                    x: hexItem._cx - hexItem._r * hexItem._sin30
                    y: hexItem._cy - hexItem._r * hexItem._cos30
                }

                PathLine {
                    x: hexItem._cx - hexItem._r
                    y: hexItem._cy
                }

                PathLine {
                    x: hexItem._cx - hexItem._r * hexItem._sin30
                    y: hexItem._cy + hexItem._r * hexItem._cos30
                }

                PathLine {
                    x: hexItem._cx + hexItem._r * hexItem._sin30
                    y: hexItem._cy + hexItem._r * hexItem._cos30
                }

                PathLine {
                    x: hexItem._cx + hexItem._r
                    y: hexItem._cy
                }

            }

        }

    }

    Item {
        id: imageContainer

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
            maskSource: hexMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
        }

    }

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
        id: videoOverlay

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
            maskSource: hexMask
            maskThresholdMin: 0.3
            maskSpreadAtMin: 0.3
        }

    }

    Shape {
        anchors.fill: parent
        visible: hexItem.pulledOut
        opacity: hexItem.pulledOut ? 1 : 0
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
            strokeColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            startX: hexItem._cx + hexItem._r
            startY: hexItem._cy

            PathLine {
                x: hexItem._cx + hexItem._r * hexItem._sin30
                y: hexItem._cy - hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx - hexItem._r * hexItem._sin30
                y: hexItem._cy - hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx - hexItem._r
                y: hexItem._cy
            }

            PathLine {
                x: hexItem._cx - hexItem._r * hexItem._sin30
                y: hexItem._cy + hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx + hexItem._r * hexItem._sin30
                y: hexItem._cy + hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx + hexItem._r
                y: hexItem._cy
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animFast
            }

        }

    }

    Shape {
        id: hexBorder

        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: hexItem.isSelected ? (Colors.primary) : Qt.rgba(0, 0, 0, 0.5)
            strokeWidth: hexItem.isSelected ? 3 : 1.5
            startX: hexItem._cx + hexItem._r
            startY: hexItem._cy

            PathLine {
                x: hexItem._cx + hexItem._r * hexItem._sin30
                y: hexItem._cy - hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx - hexItem._r * hexItem._sin30
                y: hexItem._cy - hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx - hexItem._r
                y: hexItem._cy
            }

            PathLine {
                x: hexItem._cx - hexItem._r * hexItem._sin30
                y: hexItem._cy + hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx + hexItem._r * hexItem._sin30
                y: hexItem._cy + hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx + hexItem._r
                y: hexItem._cy
            }

            Behavior on strokeColor {
                ColorAnimation {
                    duration: Style.animFast
                }

            }

        }

    }

    // Accent colour rim: bottom-left and bottom edges
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.primary
            strokeWidth: 3
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: hexItem._cx - hexItem._r
            startY: hexItem._cy

            PathLine {
                x: hexItem._cx - hexItem._r * hexItem._sin30
                y: hexItem._cy + hexItem._r * hexItem._cos30
            }

            PathLine {
                x: hexItem._cx + hexItem._r * hexItem._sin30
                y: hexItem._cy + hexItem._r * hexItem._cos30
            }

        }

    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hexItem._r * 0.18
        width: typeBadgeLabel.implicitWidth + 14
        height: 18
        radius: 9
        color: Qt.rgba(0, 0, 0, 0.75)
        border.width: 1
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)
        z: 5

        Text {
            id: typeBadgeLabel

            anchors.centerIn: parent
            text: hexItem.itemData ? (hexItem.itemData.type === "static" ? "PIC" : ((hexItem.itemData.type === "video" || hexItem.itemData.videoFile) ? "VID" : "WE")) : ""
            font.family: Style.fontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: Colors.tertiary
        }

    }

    Row {
        property var _wpColors: {
            if (!hexItem.service)
                return undefined;

            if (!hexItem.itemData)
                return undefined;

            var key = hexItem.itemData.weId ? hexItem.itemData.weId : ImageService.thumbKey(hexItem.itemData.thumb, hexItem.itemData.name);
            if (!key)
                return undefined;

            return hexItem.service.matugenDb[key];
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: hexItem._r * 0.18
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

    Rectangle {
        x: hexItem._cx + hexItem._r * hexItem._sin30 - width - 4
        y: hexItem._cy - hexItem._r * hexItem._cos30 + 8
        width: 20
        height: 20
        radius: 10
        color: hexItem.videoActive ? (Colors.primary) : Qt.rgba(0, 0, 0, 0.7)
        border.width: 1
        border.color: hexItem.videoActive ? "transparent" : (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6))
        visible: hexItem.hasVideo
        z: 5

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            text: "▶"
            font.pixelSize: 8
            color: hexItem.videoActive ? (Colors.primaryText) : (Colors.primary)
        }

        Behavior on color {
            ColorAnimation {
                duration: Style.animFast
            }

        }

    }

    MouseArea {
        id: hexMouse

        function contains(point) {
            var dx = Math.abs(point.x - hexItem._cx);
            var dy = Math.abs(point.y - hexItem._cy);
            return dy <= hexItem._cos30 * hexItem._r && dx <= hexItem._r - dy * 0.57735;
        }

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse)
                hexItem.hoverSelected();

        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && hexItem.itemData) {
                var gp = hexItem.mapToItem(null, hexItem._cx, hexItem._cy);
                hexItem.flipRequested(hexItem.itemData, gp.x, gp.y, hexItem);
            } else if (mouse.button === Qt.LeftButton && hexItem.itemData) {
                if (hexItem.itemData.type === "we")
                    hexItem.service.applyWE(hexItem.itemData.weId);
                else if (hexItem.itemData.type === "video")
                    hexItem.service.applyVideo(hexItem.itemData.path);
                else
                    hexItem.service.applyStatic(hexItem.itemData.path);
            }
        }
    }

}
