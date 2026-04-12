import ".."
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Horizontal parallelogram slice list view for AppLauncher.
// Owns the ListView, its delegate, keyboard nav, and mouse handling.
Item {
    id: root

    anchors.fill: parent

    // ── inputs ────────────────────────────────────────────────────────────────
    property var  service
    property Item containerItem
    property Item searchInputItem

    property int  expandedWidth
    property int  sliceWidth
    property int  sliceHeight
    property int  skewOffset
    property int  sliceSpacing
    property int  topBarHeight

    property bool cardVisible
    property bool isHexMode
    property bool showing

    // ── read-only outputs ─────────────────────────────────────────────────────
    readonly property alias currentIndex: _listView.currentIndex

    // ── signals ───────────────────────────────────────────────────────────────
    signal escapePressed

    // ── public functions ──────────────────────────────────────────────────────

    function focusList() {
        _listView.forceActiveFocus();
    }

    function resetToStart() {
        _listView.currentIndex = 0;
        _listView.positionViewAtIndex(0, ListView.Beginning);
    }

    function navigateLeft() {
        _listView.keyboardNavActive = true;
        if (_listView.currentIndex > 0)
            _listView.currentIndex--;
    }

    function navigateRight() {
        _listView.keyboardNavActive = true;
        if (_listView.currentIndex < root.service.filteredModel.count - 1)
            _listView.currentIndex++;
    }

    // ── internals ─────────────────────────────────────────────────────────────

    onShowingChanged: {
        if (root.showing && !root.isHexMode)
            root.searchInputItem.forceActiveFocus();
    }

    ListView {
        id: _listView

        property int  visibleCount: 12
        property bool keyboardNavActive: false
        property real lastMouseX: -1
        property real lastMouseY: -1

        x: (parent.width - width) / 2
        y: root.containerItem.y + root.topBarHeight + 15
        height: root.containerItem.height - root.topBarHeight - 35
        width: root.expandedWidth + (visibleCount - 1) * (root.sliceWidth + root.sliceSpacing)
        orientation: ListView.Horizontal
        model: root.showing ? root.service.filteredModel : null
        clip: false
        spacing: root.sliceSpacing
        flickDeceleration: 1500
        maximumFlickVelocity: 3000
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: root.expandedWidth * 4
        visible: root.cardVisible && !root.isHexMode
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 350
        preferredHighlightBegin: (width - root.expandedWidth) / 2
        preferredHighlightEnd: (width + root.expandedWidth) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange

        onVisibleChanged: {
            if (visible)
                root.searchInputItem.forceActiveFocus();
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.escapePressed();
                event.accepted = true;
                return;
            }
            if (event.text && event.text.length > 0 && !event.modifiers) {
                var c = event.text.charCodeAt(0);
                if (c >= 32 && c < 127) {
                    root.searchInputItem.text += event.text;
                    root.searchInputItem.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
            }
            if (event.key === Qt.Key_Backspace) {
                if (root.searchInputItem.text.length > 0)
                    root.searchInputItem.text = root.searchInputItem.text.slice(0, -1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (_listView.currentIndex >= 0 && _listView.currentIndex < root.service.filteredModel.count) {
                    var app = root.service.filteredModel.get(_listView.currentIndex);
                    root.service.launchApp(app.exec, app.terminal, app.name);
                    root.escapePressed();
                }
                event.accepted = true;
                return;
            }
            keyboardNavActive = true;
            if (event.key === Qt.Key_Left) {
                if (currentIndex > 0)
                    currentIndex--;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Right) {
                if (currentIndex < root.service.filteredModel.count - 1)
                    currentIndex++;
                event.accepted = true;
                return;
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function(wheel) {
                var step = 1;
                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0)
                    _listView.currentIndex = Math.max(0, _listView.currentIndex - step);
                else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0)
                    _listView.currentIndex = Math.min(root.service.filteredModel.count - 1, _listView.currentIndex + step);
            }
            onPressed:  function(mouse) { mouse.accepted = false; }
            onReleased: function(mouse) { mouse.accepted = false; }
            onClicked:  function(mouse) { mouse.accepted = false; }
        }

        highlight: Item {}

        header: Item {
            width: (_listView.width - root.expandedWidth) / 2
            height: 1
        }

        footer: Item {
            width: (_listView.width - root.expandedWidth) / 2
            height: 1
        }

        delegate: Item {
            id: delegateItem

            property bool isCurrent: ListView.isCurrentItem
            property bool isHovered: itemMouseArea.containsMouse
            property real viewX: x - _listView.contentX
            property real fadeZone: root.sliceWidth * 1.5
            property real edgeOpacity: {
                if (fadeZone <= 0)
                    return 1;
                var center = viewX + width * 0.5;
                var leftFade  = Math.min(1, Math.max(0, center / fadeZone));
                var rightFade = Math.min(1, Math.max(0, (_listView.width - center) / fadeZone));
                return Math.min(leftFade, rightFade);
            }

            width:   isCurrent ? root.expandedWidth : root.sliceWidth
            height:  _listView.height
            z:       isCurrent ? 100 : (isHovered ? 90 : 50 - Math.min(Math.abs(index - _listView.currentIndex), 50))
            opacity: edgeOpacity

            // Drop shadow canvas behind slice
            Canvas {
                id: shadowCanvas

                property real shadowOffsetX: delegateItem.isCurrent ? 4 : 2
                property real shadowOffsetY: delegateItem.isCurrent ? 10 : 5
                property real shadowAlpha:   delegateItem.isCurrent ? 0.6 : 0.4

                z: -1
                anchors.fill: parent
                anchors.margins: -10
                onWidthChanged:       requestPaint()
                onHeightChanged:      requestPaint()
                onShadowAlphaChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var ox = 10;
                    var oy = 10;
                    var w  = delegateItem.width;
                    var h  = delegateItem.height;
                    var sk = root.skewOffset;
                    var sx = shadowOffsetX;
                    var sy = shadowOffsetY;
                    var layers = [
                        { "dx": sx,       "dy": sy,       "alpha": shadowAlpha * 0.5 },
                        { "dx": sx * 0.6, "dy": sy * 0.6, "alpha": shadowAlpha * 0.3 },
                        { "dx": sx * 1.4, "dy": sy * 1.4, "alpha": shadowAlpha * 0.2 }
                    ];
                    for (var i = 0; i < layers.length; i++) {
                        var l = layers[i];
                        ctx.globalAlpha = l.alpha;
                        ctx.fillStyle = "#000000";
                        ctx.beginPath();
                        ctx.moveTo(ox + sk + l.dx,     oy + l.dy);
                        ctx.lineTo(ox + w  + l.dx,     oy + l.dy);
                        ctx.lineTo(ox + w - sk + l.dx, oy + h + l.dy);
                        ctx.lineTo(ox + l.dx,          oy + h + l.dy);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }

            // Image container (background, thumbnail, parallelogram mask)
            Item {
                id: imageContainer

                anchors.fill: parent
                layer.enabled: true
                layer.smooth:  true
                layer.samples: 4

                Image {
                    id: bgImage

                    anchors.fill: parent
                    source: model.background ? "file://" + model.background : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready
                    sourceSize.width:  root.expandedWidth
                    sourceSize.height: root.sliceHeight
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !bgImage.visible

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: model.customIcon || ""
                    font.family: Style.fontFamilyIcons
                    font.pixelSize: 48
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.7)
                    visible: model.customIcon !== "" && !bgImage.visible
                }

                Image {
                    id: thumbImage

                    anchors.fill: parent
                    source: model.thumb ? "file://" + model.thumb : ""
                    fillMode: model.source === "steam" ? Image.PreserveAspectCrop : Image.Pad
                    horizontalAlignment: Image.AlignHCenter
                    verticalAlignment:   Image.AlignVCenter
                    smooth: true
                    asynchronous: true
                    sourceSize.width:  root.expandedWidth
                    sourceSize.height: root.sliceHeight
                    visible: model.thumb !== "" && !bgImage.visible
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.4))

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.3
                    maskSpreadAtMin: 0.3

                    maskSource: ShaderEffectSource {
                        sourceItem: Item {
                            width:  imageContainer.width
                            height: imageContainer.height
                            layer.enabled: true
                            layer.smooth:  true
                            layer.samples: 8

                            Shape {
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor:   "white"
                                    strokeColor: "transparent"
                                    startX: root.skewOffset
                                    startY: 0

                                    PathLine { x: delegateItem.width;                 y: 0 }
                                    PathLine { x: delegateItem.width - root.skewOffset; y: delegateItem.height }
                                    PathLine { x: 0;                                 y: delegateItem.height }
                                    PathLine { x: root.skewOffset;                   y: 0 }
                                }
                            }
                        }
                    }
                }
            }

            // Parallelogram glow border
            Shape {
                id: glowBorder

                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                opacity: 1

                ShapePath {
                    fillColor:   "transparent"
                    strokeColor: delegateItem.isCurrent ? Colors.primary : (delegateItem.isHovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : Qt.rgba(0, 0, 0, 0.6))
                    strokeWidth: delegateItem.isCurrent ? 3 : 1
                    startX: root.skewOffset
                    startY: 0

                    PathLine { x: delegateItem.width;                 y: 0 }
                    PathLine { x: delegateItem.width - root.skewOffset; y: delegateItem.height }
                    PathLine { x: 0;                                 y: delegateItem.height }
                    PathLine { x: root.skewOffset;                   y: 0 }

                    Behavior on strokeColor {
                        ColorAnimation { duration: 200 }
                    }
                }
            }

            // Steam badge (top-right)
            Rectangle {
                anchors.top:        parent.top
                anchors.topMargin:  10
                anchors.right:      parent.right
                anchors.rightMargin: 10
                width:   22
                height:  22
                radius:  11
                color:        model.source === "steam" ? Colors.primary : Qt.rgba(0, 0, 0, 0.7)
                border.width: 1
                border.color: model.source === "steam" ? "transparent" : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)
                visible: model.source === "steam"
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "󰓓"
                    font.family: Style.fontFamilyIcons
                    font.pixelSize: 12
                    color: model.source === "steam" ? Colors.primaryText : Colors.primary
                }
            }

            // App name label (visible when selected)
            Rectangle {
                id: nameLabel

                anchors.bottom:           parent.bottom
                anchors.bottomMargin:     40
                anchors.horizontalCenter: parent.horizontalCenter
                width:  nameText.width + 24
                height: 32
                radius: 6
                color:        Qt.rgba(0, 0, 0, 0.75)
                border.width: 1
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                visible: delegateItem.isCurrent
                opacity: delegateItem.isCurrent ? 1 : 0

                Text {
                    id: nameText

                    anchors.centerIn: parent
                    text: (model.displayName || model.name).toUpperCase()
                    font.family:      Style.fontFamily
                    font.pixelSize:   12
                    font.weight:      Font.Bold
                    font.letterSpacing: 0.5
                    color: Colors.tertiary
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, delegateItem.width - 60)
                }

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            // Category type badge (bottom-right)
            Rectangle {
                anchors.bottom:       parent.bottom
                anchors.bottomMargin: 8
                anchors.right:        parent.right
                anchors.rightMargin:  root.skewOffset + 8
                width:  typeBadgeText.width + 8
                height: 16
                radius: 4
                color:        Qt.rgba(0, 0, 0, 0.75)
                border.width: 1
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)
                z: 10

                Text {
                    id: typeBadgeText

                    anchors.centerIn: parent
                    text: model.source === "steam" ? "STEAM"
                        : model.categories.indexOf("Game")        !== -1 ? "GAME"
                        : model.categories.indexOf("Development") !== -1 ? "DEV"
                        : model.categories.indexOf("Graphics")    !== -1 ? "GFX"
                        : (model.categories.indexOf("AudioVideo") !== -1 || model.categories.indexOf("Audio") !== -1 || model.categories.indexOf("Video") !== -1) ? "MEDIA"
                        : model.categories.indexOf("Network")     !== -1 ? "NET"
                        : model.categories.indexOf("Office")      !== -1 ? "OFFICE"
                        : model.categories.indexOf("System")      !== -1 ? "SYS"
                        : model.categories.indexOf("Settings")    !== -1 ? "CFG"
                        : model.categories.indexOf("Utility")     !== -1 ? "UTIL"
                        : "APP"
                    font.family:      Style.fontFamily
                    font.pixelSize:   9
                    font.weight:      Font.Bold
                    font.letterSpacing: 0.5
                    color: Colors.tertiary
                }
            }

            // Mouse interaction (hover selects, click launches)
            MouseArea {
                id: itemMouseArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: function(mouse) {
                    var globalPos = mapToItem(_listView, mouse.x, mouse.y);
                    var dx = Math.abs(globalPos.x - _listView.lastMouseX);
                    var dy = Math.abs(globalPos.y - _listView.lastMouseY);
                    if (dx > 2 || dy > 2) {
                        _listView.lastMouseX = globalPos.x;
                        _listView.lastMouseY = globalPos.y;
                        _listView.keyboardNavActive = false;
                        _listView.currentIndex = index;
                    }
                }
                onClicked: function(mouse) {
                    if (delegateItem.isCurrent) {
                        root.service.launchApp(model.exec, model.terminal, model.name);
                        root.escapePressed();
                    } else {
                        _listView.currentIndex = index;
                    }
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            // Parallelogram hit-testing mask
            containmentMask: Item {
                id: hitMask

                function contains(point) {
                    var w  = delegateItem.width;
                    var h  = delegateItem.height;
                    var sk = root.skewOffset;
                    if (h <= 0 || w <= 0)
                        return false;
                    var leftX  = sk * (1 - point.y / h);
                    var rightX = w - sk * (point.y / h);
                    return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h;
                }
            }
        }
    }
}
