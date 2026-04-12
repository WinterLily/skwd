import ".."
import "../.."
import "../services"
import QtQuick
import QtQuick.Controls

Item {
    id: filterBar

    property var service
    property bool settingsOpen: false
    property bool wallhavenBrowserOpen: false
    property bool steamWorkshopBrowserOpen: false
    property bool cacheLoading: false
    property int cacheProgress: 0
    property int cacheTotal: 0
    property bool matugenRunning: false
    property int matugenProgress: 0
    property int matugenTotal: 0
    property bool videoConvertRunning: false
    property int videoConvertProgress: 0
    property int videoConvertTotal: 0
    property string videoConvertFile: ""
    property bool imageOptimizeRunning: false
    property int imageOptimizeProgress: 0
    property int imageOptimizeTotal: 0
    property string imageOptimizeFile: ""
    property bool tagCloudOpen: false
    readonly property int _skew: 14
    readonly property int _padH: 15
    readonly property int _padV: 7
    property real maxWidth: 99999

    signal settingsToggled()
    signal wallhavenToggled()
    signal steamWorkshopToggled()
    signal tagCloudToggled()

    width: Math.min(filterRow.width + _padH * 2, maxWidth)
    height: filterRow.height + _padV * 2 + (filterFlick.contentWidth > filterFlick.width ? 10 : 0)

    Canvas {
        id: _bgCanvas

        readonly property int _sk: 14
        property color fillColor: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
        property color accentColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)

        x: 0
        y: 0
        width: parent.width
        height: filterRow.height + filterBar._padV * 2
        z: -1
        onFillColorChanged: requestPaint()
        onAccentColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var sk = _sk;
            ctx.fillStyle = fillColor;
            ctx.beginPath();
            ctx.moveTo(sk, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width - sk, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fill();
            ctx.strokeStyle = accentColor;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(sk, 0);
            ctx.lineTo(0, height);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(width, 0);
            ctx.lineTo(width - sk, height);
            ctx.stroke();
        }
    }

    Flickable {
        id: filterFlick

        x: filterBar._padH
        y: filterBar._padV
        width: filterBar.width - filterBar._padH * 2
        height: filterRow.height
        contentWidth: filterRow.width
        contentHeight: filterRow.height
        clip: contentWidth > width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: filterRow

            spacing: -_skew

            Repeater {
                model: [{
                    "type": "",
                    "label": "ALL"
                }, {
                    "type": "static",
                    "label": "PIC"
                }, {
                    "type": "video",
                    "label": "VID"
                }, {
                    "type": "we",
                    "label": "WE"
                }]

                FilterButton {
                    label: modelData.label
                    skew: filterBar._skew
                    isActive: filterBar.service ? filterBar.service.selectedTypeFilter === modelData.type : false
                    onClicked: {
                        if (isActive)
                            filterBar.service.selectedTypeFilter = "";
                        else
                            filterBar.service.selectedTypeFilter = modelData.type;
                    }
                }

            }

            Repeater {
                model: [{
                    "mode": "date",
                    "icon": "󰃰",
                    "label": "Newest"
                }, {
                    "mode": "color",
                    "icon": "󰏘",
                    "label": "Color"
                }]

                FilterButton {
                    icon: modelData.icon
                    tooltip: modelData.label
                    skew: filterBar._skew
                    isActive: filterBar.service ? filterBar.service.sortMode === modelData.mode : false
                    onClicked: {
                        filterBar.service.sortMode = modelData.mode;
                        filterBar.service.updateFilteredModel();
                    }
                }

            }

            FilterButton {
                icon: "󰋑"
                tooltip: "Favourites"
                skew: filterBar._skew
                isActive: filterBar.service ? filterBar.service.favouriteFilterActive : false
                onClicked: filterBar.service.favouriteFilterActive = !filterBar.service.favouriteFilterActive
            }

            Repeater {
                model: 13

                Item {
                    readonly property int filterValue: index < 12 ? index : 99
                    readonly property bool isSelected: filterBar.service ? filterBar.service.selectedColorFilter === filterValue : false
                    readonly property color hueColor: index === 12 ? Qt.hsla(0, 0, 0.45, 1) : Qt.hsla(index / 12, 0.65, 0.45, 1)
                    readonly property color hueBright: index === 12 ? Qt.hsla(0, 0, 0.6, 1) : Qt.hsla(index / 12, 0.75, 0.55, 1)
                    readonly property bool isHovered: _colorMouse.containsMouse

                    width: 28
                    height: 24
                    z: isSelected ? 10 : (isHovered ? 5 : 1)

                    Canvas {
                        id: _colorCanvas

                        property color cFill: parent.isSelected ? parent.hueBright : parent.hueColor
                        property color bgCol: Colors.surfaceContainer
                        property bool sel: parent.isSelected
                        property bool hov: parent.isHovered

                        anchors.fill: parent
                        scale: parent.isSelected ? 1.15 : 1
                        onCFillChanged: requestPaint()
                        onSelChanged: requestPaint()
                        onHovChanged: requestPaint()
                        onBgColChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var sk = filterBar._skew;
                            ctx.fillStyle = bgCol;
                            ctx.beginPath();
                            ctx.moveTo(sk, 0);
                            ctx.lineTo(width, 0);
                            ctx.lineTo(width - sk, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fill();
                            var inset = 1;
                            var iSk = sk * (height - 2 * inset) / height;
                            ctx.fillStyle = hov ? Qt.lighter(cFill, 1.2) : cFill;
                            ctx.beginPath();
                            ctx.moveTo(iSk + inset, inset);
                            ctx.lineTo(width - inset, inset);
                            ctx.lineTo(width - inset - iSk, height - inset);
                            ctx.lineTo(inset, height - inset);
                            ctx.closePath();
                            ctx.fill();
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Style.animVeryFast
                                easing.type: Easing.OutBack
                            }

                        }

                    }

                    MouseArea {
                        id: _colorMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (parent.isSelected)
                                filterBar.service.selectedColorFilter = -1;
                            else
                                filterBar.service.selectedColorFilter = parent.filterValue;
                        }
                    }

                }

            }

            FilterButton {
                icon: "\u{f0349}"
                tooltip: "Tags"
                skew: filterBar._skew
                isActive: filterBar.tagCloudOpen
                onClicked: filterBar.tagCloudToggled()
            }

            FilterButton {
                visible: Config.wallhavenEnabled
                icon: "\u{f01da}"
                tooltip: "Browse wallhaven.cc"
                skew: filterBar._skew
                isActive: filterBar.wallhavenBrowserOpen
                onClicked: filterBar.wallhavenToggled()
            }

            FilterButton {
                visible: Config.steamEnabled
                icon: "󰓓"
                tooltip: "Browse Steam Workshop"
                skew: filterBar._skew
                isActive: filterBar.steamWorkshopBrowserOpen
                onClicked: filterBar.steamWorkshopToggled()
            }

            FilterButton {
                icon: "\u{f0493}"
                tooltip: "Settings"
                skew: filterBar._skew
                isActive: filterBar.settingsOpen
                onClicked: filterBar.settingsToggled()
            }

            Item {
                width: _countLabel.implicitWidth + 24 + filterBar._skew
                height: 24

                Canvas {
                    property color fillColor: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                    property color strokeColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)

                    anchors.fill: parent
                    onFillColorChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var sk = filterBar._skew;
                        ctx.fillStyle = fillColor;
                        ctx.strokeStyle = strokeColor;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(sk, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width - sk, height);
                        ctx.lineTo(0, height);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();
                    }
                }

                Text {
                    id: _countLabel

                    anchors.centerIn: parent
                    text: {
                        if (!filterBar.service)
                            return "0";

                        var fc = filterBar.service.filteredModel.count;
                        var tc = filterBar.service._wallpaperData.length;
                        return fc + (fc !== tc ? "/" + tc : "");
                    }
                    font.family: Style.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                }

            }

            Item {
                visible: filterBar.cacheLoading || filterBar.matugenRunning || filterBar.videoConvertRunning || filterBar.imageOptimizeRunning
                width: visible ? (_statusRow.width + 24 + filterBar._skew) : 0
                height: 24

                Canvas {
                    property color fillColor: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                    property color strokeColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)

                    anchors.fill: parent
                    visible: parent.visible
                    onFillColorChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var sk = filterBar._skew;
                        ctx.fillStyle = fillColor;
                        ctx.strokeStyle = strokeColor;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(sk, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width - sk, height);
                        ctx.lineTo(0, height);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();
                    }
                }

                Row {
                    id: _statusRow

                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰔟"
                        font.pixelSize: 11
                        font.family: Style.fontFamilyNerdIcons
                        color: Colors.primary
                        anchors.verticalCenter: parent.verticalCenter

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1200
                            loops: Animation.Infinite
                            running: filterBar.cacheLoading || filterBar.matugenRunning || filterBar.videoConvertRunning || filterBar.imageOptimizeRunning
                        }

                    }

                    Text {
                        text: {
                            var parts = [];
                            if (filterBar.cacheLoading) {
                                if (filterBar.cacheTotal > 0)
                                    parts.push("CACHE " + filterBar.cacheProgress + "/" + filterBar.cacheTotal);
                                else
                                    parts.push("PROCESSING");
                            }
                            if (filterBar.matugenRunning) {
                                if (filterBar.matugenTotal > 0)
                                    parts.push("MATUGEN " + filterBar.matugenProgress + "/" + filterBar.matugenTotal);
                                else
                                    parts.push("MATUGEN");
                            }
                            if (filterBar.videoConvertRunning) {
                                if (filterBar.videoConvertTotal > 0)
                                    parts.push("CONVERT " + filterBar.videoConvertProgress + "/" + filterBar.videoConvertTotal);
                                else
                                    parts.push("CONVERT");
                            }
                            if (filterBar.imageOptimizeRunning) {
                                if (filterBar.imageOptimizeTotal > 0)
                                    parts.push("OPTIMIZE " + filterBar.imageOptimizeProgress + "/" + filterBar.imageOptimizeTotal);
                                else
                                    parts.push("OPTIMIZE");
                            }
                            return parts.join(" · ");
                        }
                        font.family: Style.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.8)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

            }

            Item {
                visible: (filterBar.videoConvertRunning && filterBar.videoConvertFile !== "") || (filterBar.imageOptimizeRunning && filterBar.imageOptimizeFile !== "")
                width: visible ? (180 + 24 + filterBar._skew) : 0
                height: 24

                Canvas {
                    property color fillColor: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                    property color strokeColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)

                    anchors.fill: parent
                    visible: parent.visible
                    onFillColorChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var sk = filterBar._skew;
                        ctx.fillStyle = fillColor;
                        ctx.strokeStyle = strokeColor;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(sk, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width - sk, height);
                        ctx.lineTo(0, height);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();
                    }
                }

                Text {
                    id: _convertLogText

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 180)
                    text: filterBar.imageOptimizeRunning ? filterBar.imageOptimizeFile : filterBar.videoConvertFile
                    font.family: Style.fontFamilyCode
                    font.pixelSize: 8
                    font.letterSpacing: 0.3
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Style.animFast
                    }

                }

            }

        }

        ScrollBar.horizontal: ScrollBar {
            id: filterScrollBar

            y: filterFlick.height + 4
            height: 4
            visible: filterFlick.contentWidth > filterFlick.width
            policy: ScrollBar.AlwaysOn

            contentItem: Rectangle {
                implicitHeight: 4
                radius: 2
                color: Colors.primary
            }

            background: Rectangle {
                implicitHeight: 4
                radius: 2
                color: Colors.surfaceContainer
            }

        }

    }

}
