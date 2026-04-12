import "../.."
import "../services"
import QtMultimedia
import QtQuick
import QtQuick.Controls

// Thumbnail grid display mode.
// Owns the GridView, its inline delegate (thumbnail + video preview + badges),
// and the full-screen flip-card detail overlay (gridBackOverlay).
Item {
    id: root

    anchors.fill: parent

    // ── inputs ───────────────────────────────────────────────────────────────
    property var  service
    property Item containerItem           // reference to cardContainer in selectorPanel

    property real gridCellW
    property real gridCellH
    property real gridTotalW
    property int  topBarHeight

    property bool cardVisible
    property bool anyBrowserOpen
    property bool isGridMode
    property bool tagCloudVisible
    property bool showing

    // ── signals ───────────────────────────────────────────────────────────────
    signal escapePressed
    signal tagCloudToggleRequested
    signal focusRequested

    // ── public functions ──────────────────────────────────────────────────────

    function focusList() {
        _thumbGrid.forceActiveFocus();
    }

    // ── lifecycle ─────────────────────────────────────────────────────────────

    onShowingChanged: {
        if (!showing && _gridOverlay.overlayOpen) {
            _gridOverlay.overlayOpen = false;
            _gridOverlay.visible = false;
            _gridOverlay.overlayItemKey = "";
        }
    }

    // ── grid view ─────────────────────────────────────────────────────────────

    GridView {
        id: _thumbGrid

        property real _scrollTarget: 0
        property int  hoveredIdx: currentIndex

        function _snapScroll(delta) {
            if (!_gridScrollAnim.running)
                _scrollTarget = contentY;
            var step = cellHeight;
            _scrollTarget += (delta > 0 ? -step : step);
            var maxY = contentHeight - height;
            _scrollTarget = Math.max(0, Math.min(_scrollTarget, maxY));
            _gridScrollAnim.stop();
            _gridScrollAnim.from = contentY;
            _gridScrollAnim.to = _scrollTarget;
            _gridScrollAnim.start();
        }

        function _ensureVisible(idx) {
            var row = Math.floor(idx / Config.gridColumns);
            var rowTop = row * cellHeight;
            var rowBottom = rowTop + cellHeight;
            if (rowTop < contentY)
                _snapScrollTo(rowTop);
            else if (rowBottom > contentY + height)
                _snapScrollTo(rowBottom - height);
        }

        function _snapScrollTo(target) {
            var maxY = contentHeight - height;
            _scrollTarget = Math.max(0, Math.min(target, maxY));
            _gridScrollAnim.stop();
            _gridScrollAnim.from = contentY;
            _gridScrollAnim.to = _scrollTarget;
            _gridScrollAnim.start();
        }

        x: (parent.width - width) / 2
        y: root.containerItem.y + root.topBarHeight + 15
        height: root.containerItem.height - root.topBarHeight - 35
        width: root.gridTotalW
        clip: true
        cellWidth: root.gridCellW
        cellHeight: root.gridCellH
        model: root.showing ? root.service.filteredModel : null
        cacheBuffer: root.showing ? 300 : 0
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        onContentYChanged: {
            if (!_gridScrollAnim.running)
                _scrollTarget = contentY;
        }
        visible: root.cardVisible && !root.anyBrowserOpen && root.isGridMode
        focus: root.showing && root.isGridMode && !root.tagCloudVisible
        onVisibleChanged: {
            if (visible && !root.tagCloudVisible)
                forceActiveFocus();
        }

        Keys.onEscapePressed: {
            if (_gridOverlay.overlayOpen)
                _gridOverlay.hide();
            else
                root.escapePressed();
        }
        Keys.onReturnPressed: {
            if (hoveredIdx >= 0 && hoveredIdx < root.service.filteredModel.count) {
                var item = root.service.filteredModel.get(hoveredIdx);
                if (item.type === "we")
                    root.service.applyWE(item.weId);
                else if (item.type === "video")
                    root.service.applyVideo(item.path);
                else
                    root.service.applyStatic(item.path);
            }
        }
        Keys.onUpPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; return; }
            var newIdx = currentIndex - Config.gridColumns;
            if (newIdx >= 0) { currentIndex = newIdx; hoveredIdx = newIdx; _ensureVisible(newIdx); }
        }
        Keys.onDownPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
                root.tagCloudToggleRequested();
                event.accepted = true;
                return;
            }
            var newIdx = currentIndex + Config.gridColumns;
            if (newIdx < count) { currentIndex = newIdx; hoveredIdx = newIdx; _ensureVisible(newIdx); }
        }
        Keys.onLeftPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.service.selectedColorFilter === -1)
                    root.service.selectedColorFilter = 99;
                else if (root.service.selectedColorFilter === 99)
                    root.service.selectedColorFilter = 11;
                else if (root.service.selectedColorFilter === 0)
                    root.service.selectedColorFilter = 99;
                else
                    root.service.selectedColorFilter--;
                event.accepted = true;
                return;
            }
            if (currentIndex > 0) { currentIndex--; hoveredIdx = currentIndex; _ensureVisible(currentIndex); }
        }
        Keys.onRightPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.service.selectedColorFilter === -1)
                    root.service.selectedColorFilter = 0;
                else if (root.service.selectedColorFilter === 11)
                    root.service.selectedColorFilter = 99;
                else if (root.service.selectedColorFilter === 99)
                    root.service.selectedColorFilter = 0;
                else
                    root.service.selectedColorFilter++;
                event.accepted = true;
                return;
            }
            if (currentIndex < count - 1) { currentIndex++; hoveredIdx = currentIndex; _ensureVisible(currentIndex); }
        }

        highlightMoveDuration: Style.animNormal

        NumberAnimation {
            id: _gridScrollAnim
            target: _thumbGrid
            property: "contentY"
            duration: 400
            easing.type: Easing.OutCubic
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function(wheel) {
                _thumbGrid._snapScroll(wheel.angleDelta.y);
                if (!root.tagCloudVisible)
                    _thumbGrid.forceActiveFocus();
            }
            onPressed:  function(mouse) { mouse.accepted = false; }
            onReleased: function(mouse) { mouse.accepted = false; }
            onClicked:  function(mouse) { mouse.accepted = false; }
        }

        Behavior on width     { NumberAnimation { duration: Style.animExpand; easing.type: Easing.OutCubic } }
        Behavior on cellWidth  { NumberAnimation { duration: Style.animExpand; easing.type: Easing.OutCubic } }
        Behavior on cellHeight { NumberAnimation { duration: Style.animExpand; easing.type: Easing.OutCubic } }

        highlight: Item {}

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)
            }
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale";   from: 0.85; to: 1; duration: Style.animEnter; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Style.animVeryFast; easing.type: Easing.InCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Style.animFast; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: _gridThumb

            required property int index
            required property var model

            property string videoPath:   model.videoFile ? model.videoFile : ""
            property bool   hasVideo:    videoPath.length > 0 && Config.videoPreviewEnabled
            property bool   videoActive: false
            property real   _entryOpacity: 0.8

            readonly property real entryViewY:  y - _thumbGrid.contentY
            readonly property bool entryInView: entryViewY + height > 0 && entryViewY < _thumbGrid.height

            width: _thumbGrid.cellWidth
            height: _thumbGrid.cellHeight

            onVisibleChanged: {
                if (!visible) {
                    _videoDelay.stop();
                    videoActive = false;
                }
            }
            opacity: _entryOpacity
            onEntryInViewChanged: _entryOpacity = entryInView ? 1 : 0.8
            Component.onCompleted: { if (entryInView) _entryOpacity = 1; }

            Connections {
                target: _thumbGrid
                function onHoveredIdxChanged() {
                    if (_thumbGrid.hoveredIdx === _gridThumb.index && _gridThumb.hasVideo)
                        _videoDelay.restart();
                    else { _videoDelay.stop(); _gridThumb.videoActive = false; }
                }
            }

            Timer {
                id: _videoDelay
                interval: 600
                onTriggered: _gridThumb.videoActive = true
            }

            Rectangle {
                id: _cardRect

                property bool _pulledOut: _gridOverlay.overlayItemKey !== "" && _gridOverlay.overlayItemKey === ((_gridThumb.model.weId || "") !== "" ? _gridThumb.model.weId : _gridThumb.model.name)

                anchors.fill: parent
                anchors.margins: 4
                radius: 6
                color: "transparent"
                border.width: _thumbGrid.hoveredIdx === _gridThumb.index ? 2 : 0
                border.color: Colors.primary
                visible: !_pulledOut

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: _cardRect.border.width
                    radius: 5
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
                    clip: true

                    Image {
                        id: _thumbImg

                        anchors.fill: parent
                        source: _gridThumb.model.thumb ? ImageService.fileUrl(_gridThumb.model.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        cache: false
                        sourceSize.width: Config.gridThumbWidth
                        sourceSize.height: Config.gridThumbHeight
                    }

                    // Video preview (loaded lazily on hover)
                    Loader {
                        id: _videoLoader

                        anchors.fill: parent
                        active: _gridThumb.videoActive
                        visible: false
                        layer.enabled: active

                        sourceComponent: Video {
                            anchors.fill: parent
                            source: ImageService.fileUrl(_gridThumb.videoPath)
                            fillMode: VideoOutput.PreserveAspectCrop
                            loops: MediaPlayer.Infinite
                            muted: true
                            Component.onCompleted: play()
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: _videoLoader.active && _videoLoader.status === Loader.Ready

                        ShaderEffectSource {
                            anchors.fill: parent
                            sourceItem: _videoLoader
                            live: true
                        }
                    }

                    // Skeleton / shimmer while loading
                    Rectangle {
                        id: _skeleton

                        anchors.fill: parent
                        radius: 6
                        visible: _thumbImg.status !== Image.Ready
                        color: Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.8)

                        Rectangle {
                            width: parent.width * 0.5; height: parent.height; radius: 6; opacity: 0.35
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0;   color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) }
                                GradientStop { position: 1;   color: "transparent" }
                            }
                            NumberAnimation on x {
                                from: -parent.width; to: _skeleton.width
                                duration: 1200; loops: Animation.Infinite; running: _skeleton.visible
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f0553}"
                            font.family: Style.fontFamilyNerdIcons; font.pixelSize: 22
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                        }
                    }

                    MouseArea {
                        id: _thumbMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onContainsMouseChanged: {
                            if (containsMouse) {
                                _thumbGrid.hoveredIdx = _gridThumb.index;
                                if (!root.tagCloudVisible)
                                    _thumbGrid.forceActiveFocus();
                            }
                        }
                        onClicked: function(mouse) {
                            if (!root.tagCloudVisible)
                                _thumbGrid.forceActiveFocus();
                            if (mouse.button === Qt.RightButton) {
                                var gpos = _gridThumb.mapToItem(null, _gridThumb.width / 2, _gridThumb.height / 2);
                                var d = _gridThumb.model;
                                _gridOverlay.show({
                                    "name":      d.name,
                                    "path":      d.path,
                                    "thumb":     d.thumb,
                                    "type":      d.type,
                                    "weId":      d.weId || "",
                                    "favourite": d.favourite,
                                    "videoFile": d.videoFile || ""
                                }, gpos.x, gpos.y, _gridThumb);
                            } else {
                                var d = _gridThumb.model;
                                if (d.type === "we")
                                    root.service.applyWE(d.weId);
                                else if (d.type === "video" || d.videoFile)
                                    root.service.applyVideo(d.path);
                                else
                                    root.service.applyStatic(d.path);
                            }
                        }
                    }

                    // Type badge (VID / PIC / WE)
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 4
                        width: _typeBadge.implicitWidth + 6; height: 14; radius: 3
                        color: Qt.rgba(0, 0, 0, 0.6)

                        Text {
                            id: _typeBadge
                            anchors.centerIn: parent
                            text: (_gridThumb.model.type === "video" || _gridThumb.model.videoFile) ? "VID" : (_gridThumb.model.type === "static" ? "PIC" : "WE")
                            font.family: Style.fontFamily; font.pixelSize: 8; font.weight: Font.Bold
                            color: Colors.primary
                        }
                    }

                    // Video indicator dot
                    Rectangle {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 4
                        width: 18; height: 18; radius: 9
                        color: _gridThumb.videoActive ? Colors.primary : Qt.rgba(0, 0, 0, 0.7)
                        border.width: 1
                        border.color: _gridThumb.videoActive ? "transparent" : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)
                        visible: _gridThumb.hasVideo
                        z: 5

                        Text {
                            anchors.centerIn: parent; anchors.horizontalCenterOffset: 1
                            text: "\u25b6"; font.pixelSize: 7
                            color: _gridThumb.videoActive ? Colors.primaryText : Colors.primary
                        }

                        Behavior on color { ColorAnimation { duration: Style.animFast } }
                    }

                    // Favourite star
                    Text {
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                        text: "\u{f0134}"
                        font.family: Style.fontFamilyNerdIcons; font.pixelSize: 14
                        color: Colors.primary
                        visible: _gridThumb.model.favourite === true
                    }
                }

                Behavior on border.width { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutQuad } }
            }

            Behavior on _entryOpacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
        }
    }

    // ── grid detail card overlay ──────────────────────────────────────────────

    Item {
        id: _gridOverlay

        property var    overlayData:    null
        property string overlayItemKey: ""
        property var    _sourceItem:    null
        property real   sourceX:        0
        property real   sourceY:        0
        property real   _openContentY:  0
        property bool   overlayOpen:    false
        property var    _gridMeta:      null

        readonly property real bigW: Math.min(Config.gridThumbWidth * 2.5, 600)
        readonly property real bigH: Math.min(Config.gridThumbHeight * 2.5, 500)

        function show(data, gx, gy, sourceItem) {
            _gridTagField.text = "";
            _gridTagField._sessionTags = [];
            overlayData = data;
            overlayItemKey = (data.weId || "") !== "" ? data.weId : data.name;
            _sourceItem = sourceItem || null;
            _openContentY = _thumbGrid.contentY;
            var local = _gridOverlay.mapFromItem(null, gx, gy);
            sourceX = local.x;
            sourceY = local.y;
            visible = true;
            overlayOpen = true;
        }

        function hide() {
            var scrollDelta = _thumbGrid.contentY - _openContentY;
            sourceY -= scrollDelta;
            _openContentY = _thumbGrid.contentY;
            overlayOpen = false;
        }

        anchors.fill: parent
        visible: false
        z: 200

        onOverlayOpenChanged: {
            if (overlayOpen && overlayData && overlayData.type !== "we") {
                var key = ImageService.thumbKey(overlayData.thumb, overlayData.name);
                _gridMeta = FileMetadataService.getMetadata(key);
                if (!_gridMeta)
                    FileMetadataService.probeIfNeeded(key, overlayData.path, overlayData.type === "video" ? "video" : "image");
            }
        }

        states: [
            State {
                name: "hidden"
                when: !_gridOverlay.overlayOpen

                PropertyChanges {
                    target: _gridCard
                    x: _gridOverlay.sourceX - _gridCard.width / 2
                    y: _gridOverlay.sourceY - _gridCard.height / 2
                    scale: Config.gridThumbWidth / _gridOverlay.bigW
                    opacity: 0
                }
                PropertyChanges { target: _gridCardRotation; angle: 0 }
            },
            State {
                name: "visible"
                when: _gridOverlay.overlayOpen

                PropertyChanges {
                    target: _gridCard
                    x: (_gridOverlay.width - _gridCard.width) / 2
                    y: (_gridOverlay.height - _gridCard.height) / 2
                    scale: 1
                    opacity: 1
                }
                PropertyChanges { target: _gridCardRotation; angle: 180 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"
                to: "visible"

                SequentialAnimation {
                    PropertyAction { target: _gridOverlay; property: "visible"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: _gridCard; properties: "x,y,scale,opacity"; duration: Style.animSlow; easing.type: Easing.OutCubic }
                        NumberAnimation { target: _gridCardRotation; property: "angle"; duration: Style.animSlow; easing.type: Easing.InOutQuad }
                    }
                }
            },
            Transition {
                from: "visible"
                to: "hidden"

                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: _gridCard; properties: "x,y,scale"; duration: Style.animSlow; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: _gridCardRotation; property: "angle"; duration: Style.animSlow; easing.type: Easing.InOutQuad }
                        SequentialAnimation {
                            PauseAnimation { duration: Style.animSlow * 0.7 }
                            NumberAnimation { target: _gridCard; property: "opacity"; duration: Style.animSlow * 0.3; easing.type: Easing.InQuad }
                        }
                    }
                    PropertyAction { target: _gridOverlay; property: "visible";        value: false }
                    PropertyAction { target: _gridOverlay; property: "overlayItemKey"; value: "" }
                    PropertyAction { target: _gridOverlay; property: "_sourceItem";    value: null }
                }
            }
        ]

        Connections {
            target: FileMetadataService
            enabled: _gridOverlay.overlayOpen
            function onMetadataReady(key) {
                if (!_gridOverlay.overlayData) return;
                var myKey = ImageService.thumbKey(_gridOverlay.overlayData.thumb, _gridOverlay.overlayData.name);
                if (key === myKey)
                    _gridOverlay._gridMeta = FileMetadataService.getMetadata(key);
            }
        }

        // Dim background
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, _gridOverlay.overlayOpen ? 0.55 : 0)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: _gridOverlay.hide()
            }

            Behavior on color { ColorAnimation { duration: Style.animNormal } }
        }

        // ── flip card ─────────────────────────────────────────────────────────

        Item {
            id: _gridCard

            width: _gridOverlay.bigW
            height: _gridOverlay.bigH
            transformOrigin: Item.Center

            // Front face: thumbnail
            Item {
                id: _gridFrontFace

                anchors.fill: parent
                visible: _gridCardRotation.angle < 90

                Rectangle {
                    anchors.fill: parent; radius: 12; color: Colors.surfaceContainer; clip: true

                    Image {
                        anchors.fill: parent
                        source: _gridOverlay.overlayData && _gridOverlay.overlayData.thumb ? ImageService.fileUrl(_gridOverlay.overlayData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true; asynchronous: true; cache: false
                        sourceSize.width: _gridOverlay.bigW
                        sourceSize.height: _gridOverlay.bigH
                    }
                }

                Rectangle {
                    anchors.fill: parent; radius: 12; color: "transparent"
                    border.width: 2; border.color: Colors.primary
                }
            }

            // Back face: metadata + actions
            Item {
                id: _gridBackFace

                anchors.fill: parent
                visible: _gridCardRotation.angle >= 90

                Rectangle {
                    anchors.fill: parent; radius: 12; color: Colors.surfaceContainer; clip: true

                    MouseArea {
                        anchors.fill: parent; acceptedButtons: Qt.RightButton; z: -1
                        onClicked: _gridOverlay.hide()
                    }

                    Image {
                        anchors.fill: parent
                        source: _gridOverlay.overlayData && _gridOverlay.overlayData.thumb ? ImageService.fileUrl(_gridOverlay.overlayData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop; opacity: 0.08
                        sourceSize.width: 120; sourceSize.height: 68
                        asynchronous: true; cache: false
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        spacing: 6

                        // Title
                        Text {
                            width: parent.width
                            text: _gridOverlay.overlayData ? _gridOverlay.overlayData.name.replace(/\.[^/.]+$/, "").toUpperCase() : ""
                            color: Colors.tertiary
                            font.family: Style.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 1.2
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2
                        }

                        // Metadata row (ext · resolution · size)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 0
                            visible: _gridOverlay.overlayData && _gridOverlay.overlayData.type !== "we"

                            Text {
                                text: _gridOverlay.overlayData ? FileMetadataService.formatExt(_gridOverlay.overlayData.name) : ""
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.6)
                                font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.8
                            }
                            Text { text: "  \u2022  "; color: Qt.rgba(1, 1, 1, 0.15); font.family: Style.fontFamily; font.pixelSize: 11 }
                            Text {
                                text: _gridOverlay._gridMeta ? (_gridOverlay._gridMeta.width + " \u00d7 " + _gridOverlay._gridMeta.height) : "\u2013"
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.6)
                                font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.5
                            }
                            Text { text: "  \u2022  "; color: Qt.rgba(1, 1, 1, 0.15); font.family: Style.fontFamily; font.pixelSize: 11 }
                            Text {
                                text: _gridOverlay._gridMeta ? FileMetadataService.formatSize(_gridOverlay._gridMeta.filesize) : "\u2013"
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.6)
                                font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.5
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                        // Favourite toggle
                        Item {
                            width: parent.width
                            height: 26

                            Text {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: "FAVOURITE"; color: Colors.tertiary
                                font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 0.5
                            }

                            Item {
                                id: _gridFavToggle

                                property bool checked: false

                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 44; height: 22

                                Connections {
                                    target: _gridOverlay
                                    function onOverlayOpenChanged() {
                                        if (_gridOverlay.overlayOpen && _gridOverlay.overlayData) {
                                            var key = (_gridOverlay.overlayData.weId || "") !== "" ? _gridOverlay.overlayData.weId : _gridOverlay.overlayData.name;
                                            _gridFavToggle.checked = root.service ? !!root.service.favouritesDb[key] : false;
                                        }
                                    }
                                }

                                Canvas {
                                    property bool  isOn:      _gridFavToggle.checked
                                    property color fillColor: isOn ? Colors.primary : Qt.rgba(1, 1, 1, 0.15)
                                    anchors.fill: parent
                                    onFillColorChanged: requestPaint()
                                    onIsOnChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        var sk = 6;
                                        ctx.fillStyle = fillColor;
                                        ctx.beginPath();
                                        ctx.moveTo(sk, 0); ctx.lineTo(width, 0);
                                        ctx.lineTo(width - sk, height); ctx.lineTo(0, height);
                                        ctx.closePath(); ctx.fill();
                                    }
                                }

                                Canvas {
                                    property color knobColor: _gridFavToggle.checked ? Colors.primaryText : Colors.surfaceText
                                    width: 20; height: 16; y: 3
                                    x: _gridFavToggle.checked ? parent.width - width - 3 : 3
                                    onKnobColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        var sk = 4;
                                        ctx.fillStyle = knobColor;
                                        ctx.beginPath();
                                        ctx.moveTo(sk, 0); ctx.lineTo(width, 0);
                                        ctx.lineTo(width - sk, height); ctx.lineTo(0, height);
                                        ctx.closePath(); ctx.fill();
                                    }
                                    Behavior on x { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!_gridOverlay.overlayData) return;
                                        _gridFavToggle.checked = !_gridFavToggle.checked;
                                        root.service.toggleFavourite(_gridOverlay.overlayData.name, _gridOverlay.overlayData.weId || "");
                                    }
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                        // Tag input field
                        Item {
                            width: parent.width
                            height: 24

                            Rectangle {
                                anchors.fill: parent
                                color: _gridTagField.activeFocus ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5) : "transparent"
                                border.width: 1
                                border.color: _gridTagField.activeFocus ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                                Behavior on color       { ColorAnimation { duration: Style.animVeryFast } }
                                Behavior on border.color { ColorAnimation { duration: Style.animVeryFast } }
                            }

                            TextInput {
                                id: _gridTagField

                                property var  _sessionTags: []
                                property bool _syncing:     false

                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Style.fontFamily; font.pixelSize: 11; font.letterSpacing: 0.3
                                color: Colors.surfaceText; clip: true

                                onTextChanged: {
                                    if (_syncing || !_gridOverlay.overlayData) return;
                                    var raw = text.toLowerCase();
                                    var words = raw.split(/\s+/).filter(function(w) { return w.length > 0; });
                                    var wpTags = root.service.getWallpaperTags(_gridTagsSection.wpName, _gridTagsSection.wpWeId).slice();
                                    var changed = false;
                                    for (var i = 0; i < words.length; i++) {
                                        if (_sessionTags.indexOf(words[i]) === -1) _sessionTags.push(words[i]);
                                        if (wpTags.indexOf(words[i]) === -1) { wpTags.push(words[i]); changed = true; }
                                    }
                                    var toRemove = [];
                                    for (var k = 0; k < _sessionTags.length; k++) {
                                        if (words.indexOf(_sessionTags[k]) === -1) toRemove.push(_sessionTags[k]);
                                    }
                                    for (var r = 0; r < toRemove.length; r++) {
                                        var si = _sessionTags.indexOf(toRemove[r]);
                                        if (si !== -1) _sessionTags.splice(si, 1);
                                        var wi = wpTags.indexOf(toRemove[r]);
                                        if (wi !== -1) { wpTags.splice(wi, 1); changed = true; }
                                    }
                                    if (changed)
                                        root.service.setWallpaperTags(_gridTagsSection.wpName, _gridTagsSection.wpWeId, wpTags);
                                }
                                Keys.onReturnPressed: function(event) { event.accepted = true; }
                                Keys.onEscapePressed: { text = ""; _sessionTags = []; _gridOverlay.hide(); }

                                Text {
                                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                    text: "+ ADD TAG"
                                    font.family: Style.fontFamily; font.pixelSize: 11; font.letterSpacing: 1
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                                    visible: !parent.text && !parent.activeFocus
                                }
                            }

                            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; z: -1; onClicked: _gridTagField.forceActiveFocus() }
                        }

                        // Current tags
                        Item {
                            id: _gridTagsSection

                            property string wpName:  _gridOverlay.overlayData ? _gridOverlay.overlayData.name : ""
                            property string wpWeId:  _gridOverlay.overlayData ? (_gridOverlay.overlayData.weId || "") : ""
                            property var currentTags: {
                                if (!_gridOverlay.overlayOpen) return [];
                                var db = root.service ? root.service.tagsDb : null;
                                if (!db) return [];
                                var key = _gridTagsSection.wpWeId ? _gridTagsSection.wpWeId : ImageService.thumbKey(_gridOverlay.overlayData ? _gridOverlay.overlayData.thumb : "", _gridTagsSection.wpName);
                                return db[key] || [];
                            }

                            width: parent.width
                            height: Math.min(Math.max(30, _gridTagsFlow.implicitHeight + 10), _gridOverlay.bigH * 0.3)
                            clip: true

                            Flickable {
                                anchors.fill: parent
                                contentHeight: _gridTagsFlow.implicitHeight
                                clip: true; flickableDirection: Flickable.VerticalFlick; boundsBehavior: Flickable.StopAtBounds

                                Flow {
                                    id: _gridTagsFlow
                                    width: parent.width; spacing: 5

                                    Repeater {
                                        model: _gridTagsSection.currentTags

                                        Rectangle {
                                            property bool hovered: _gridTagMa.containsMouse

                                            width: _gridTagTxt.implicitWidth + 30; height: 28; radius: 4
                                            color: hovered ? Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.5) : "transparent"
                                            border.width: 1
                                            border.color: hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.7) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)

                                            Text {
                                                id: _gridTagTxt
                                                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.toUpperCase(); color: Colors.tertiary
                                                font.family: Style.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 0.5
                                            }
                                            Text {
                                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                                text: "\u{f0156}"; font.family: Style.fontFamilyNerdIcons; font.pixelSize: 11
                                                color: parent.hovered ? Colors.primary : Qt.rgba(1, 1, 1, 0.25)
                                                Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
                                            }
                                            MouseArea {
                                                id: _gridTagMa
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var tags = root.service.getWallpaperTags(_gridTagsSection.wpName, _gridTagsSection.wpWeId).slice();
                                                    var idx = tags.indexOf(modelData);
                                                    if (idx !== -1) tags.splice(idx, 1);
                                                    root.service.setWallpaperTags(_gridTagsSection.wpName, _gridTagsSection.wpWeId, tags);
                                                }
                                            }
                                            Behavior on color       { ColorAnimation { duration: Style.animVeryFast } }
                                            Behavior on border.color { ColorAnimation { duration: Style.animVeryFast } }
                                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.08, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: _gridTagsSection.currentTags.length === 0
                                text: "NO TAGS"; color: Qt.rgba(1, 1, 1, 0.15)
                                font.family: Style.fontFamily; font.pixelSize: 12; font.letterSpacing: 2
                            }
                        }

                        // Action buttons
                        Row {
                            width: parent.width; height: 32; spacing: 8

                            ActionButton {
                                width: _gridOverlay.overlayData && _gridOverlay.overlayData.type === "we" ? (parent.width - parent.spacing * 2) / 3 : (parent.width - parent.spacing) / 2
                                icon: "\u{f0208}"; label: "VIEW"
                                onClicked: {
                                    if (!_gridOverlay.overlayData) return;
                                    var p = _gridOverlay.overlayData.path;
                                    Qt.openUrlExternally(ImageService.fileUrl(p.substring(0, p.lastIndexOf("/"))));
                                    _gridOverlay.hide();
                                }
                            }
                            ActionButton {
                                width: _gridOverlay.overlayData && _gridOverlay.overlayData.type === "we" ? (parent.width - parent.spacing * 2) / 3 : (parent.width - parent.spacing) / 2
                                icon: "\u{f0a79}"; label: "DELETE"; danger: true
                                onClicked: {
                                    if (!_gridOverlay.overlayData) return;
                                    root.service.deleteWallpaperItem(_gridOverlay.overlayData.type, _gridOverlay.overlayData.name, _gridOverlay.overlayData.weId || "");
                                    _gridOverlay.hide();
                                }
                            }
                            ActionButton {
                                visible: _gridOverlay.overlayData && _gridOverlay.overlayData.type === "we"
                                width: visible ? (parent.width - parent.spacing * 2) / 3 : 0
                                icon: "\u{f0bef}"; label: "STEAM"
                                onClicked: {
                                    root.service.openSteamPage(_gridOverlay.overlayData.weId || "");
                                    _gridOverlay.hide();
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 12; color: "transparent"
                        border.width: 2.5; border.color: Colors.primary
                    }

                    transform: Rotation {
                        origin.x: _gridBackFace.width / 2
                        origin.y: _gridBackFace.height / 2
                        angle: 180
                        axis { x: 0; y: 1; z: 0 }
                    }
                }

                transform: Rotation {
                    id: _gridCardRotation
                    origin.x: _gridCard.width / 2
                    origin.y: _gridCard.height / 2
                    angle: 0
                    axis { x: 0; y: 1; z: 0 }
                }
            }
        }
    }
}
