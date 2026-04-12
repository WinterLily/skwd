import "../.."
import QtQuick

// Slice (parallax strip) display mode.
// Owns the horizontal ListView, the snapshot crossfade for filter transitions,
// and the position-restore timer.  Communication upward is via signals.
Item {
    id: root

    anchors.fill: parent

    // ── inputs ───────────────────────────────────────────────────────────────
    property var  service
    property Item containerItem          // reference to cardContainer in selectorPanel

    property int  expandedWidth
    property int  sliceWidth
    property int  skewOffset
    property int  sliceSpacing
    property int  topBarHeight

    property bool cardVisible
    property bool anyBrowserOpen
    property bool isHexMode
    property bool isGridMode
    property bool tagCloudVisible
    property bool showing
    property bool suppressWidthAnim
    property bool restorePending         // WallpaperSelector sets true; read in onCountChanged

    // ── read-only outputs ─────────────────────────────────────────────────────
    readonly property alias currentIndex: _listView.currentIndex
    readonly property alias scrollX:      _listView.contentX

    // ── signals ───────────────────────────────────────────────────────────────
    signal escapePressed
    signal tagCloudToggleRequested
    signal focusRequested

    // ── public functions ──────────────────────────────────────────────────────

    function focusList() {
        _listView.forceActiveFocus();
    }

    function positionAt(idx) {
        _listView.currentIndex = idx;
        _positionTimer.posIdx = idx;
        _positionTimer.restart();
    }

    // Called by WallpaperSelector when it decides to do the slow crossfade path.
    // onCommit() must call service.commitFilteredModel() — passed in so the caller
    // controls exactly when that happens.
    function beginFilterTransition(onCommit) {
        _snapshotCommitFallback.pendingCallback = onCommit;
        _snapshotCommitFallback.restart();
        _listView.grabToImage(function(result) {
            _snapshotCommitFallback.stop();
            _snapshotImage.source = result.url;
            _snapshotImage.visible = true;
            _snapshotImage.opacity = 1;
            _listView.cacheBuffer = 0;
            onCommit();
        });
    }

    // Called by WallpaperSelector when a new filter request interrupts an in-progress transition.
    function abortFilterTransition() {
        _snapshotFadeOut.stop();
        _snapshotImage.visible = false;
        _snapshotImage.source = "";
    }

    // Called by WallpaperSelector from service.onModelUpdated when filterTransitioning is set.
    function startSnapshotFade() {
        _snapshotFadeOut.start();
    }

    // ── internals ─────────────────────────────────────────────────────────────

    NumberAnimation {
        id: _snapshotFadeOut

        target: _snapshotImage
        property: "opacity"
        from: 1
        to: 0
        duration: Style.animNormal
        easing.type: Easing.OutCubic
        onFinished: {
            _snapshotImage.visible = false;
            _snapshotImage.source = "";
            root.service.filterTransitioning = false;
            _listView.cacheBuffer = Math.round(root.expandedWidth / 2);
        }
    }

    Timer {
        id: _snapshotCommitFallback

        property var pendingCallback: null

        interval: 150
        onTriggered: {
            if (root.service.filterTransitioning) {
                _snapshotImage.visible = false;
                _snapshotImage.source = "";
                root.service.filterTransitioning = false;
                _listView.cacheBuffer = Math.round(root.expandedWidth / 2);
                if (pendingCallback)
                    pendingCallback();
            }
        }
    }

    Timer {
        id: _positionTimer

        property int posIdx: 0

        interval: 0
        onTriggered: {
            _listView.positionViewAtIndex(posIdx, ListView.Center);
            root.suppressWidthAnim = false;
        }
    }

    ListView {
        id: _listView

        property int  visibleCount: Config.wallpaperVisibleCount
        property bool keyboardNavActive: false

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
        cacheBuffer: root.showing ? Math.round(root.expandedWidth / 2) : 0
        visible: root.cardVisible && !root.anyBrowserOpen && !root.isHexMode && !root.isGridMode
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Style.animExpand
        preferredHighlightBegin: (width - root.expandedWidth) / 2
        preferredHighlightEnd: (width + root.expandedWidth) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        focus: root.showing && !root.tagCloudVisible
        onVisibleChanged: {
            if (visible && !root.tagCloudVisible && !root.isHexMode)
                forceActiveFocus();
        }
        onCountChanged: {
            if (count > 0 && root.showing && !root.restorePending)
                currentIndex = Math.min(currentIndex, count - 1);
        }

        Keys.onEscapePressed: root.escapePressed()
        Keys.onReturnPressed: {
            if (currentIndex >= 0 && currentIndex < root.service.filteredModel.count) {
                const item = root.service.filteredModel.get(currentIndex);
                if (item.type === "we")
                    root.service.applyWE(item.weId);
                else if (item.type === "video")
                    root.service.applyVideo(item.path);
                else
                    root.service.applyStatic(item.path);
            }
        }
        Keys.onPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
                if (event.key === Qt.Key_Down) {
                    root.tagCloudToggleRequested();
                    event.accepted = true;
                    return;
                } else if (event.key === Qt.Key_Left) {
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
                } else if (event.key === Qt.Key_Right) {
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
            }
            if (event.key === Qt.Key_Left && !(event.modifiers & Qt.ShiftModifier)) {
                keyboardNavActive = true;
                if (currentIndex > 0)
                    currentIndex--;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Right && !(event.modifiers & Qt.ShiftModifier)) {
                keyboardNavActive = true;
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

        Behavior on width {
            NumberAnimation {
                duration: Style.animExpand
                easing.type: Easing.OutCubic
            }
        }

        highlight: Item {}

        add: Transition {
            enabled: !root.service.filterTransitioning

            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale";   from: 0.85; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
        }

        remove: Transition {
            enabled: !root.service.filterTransitioning

            NumberAnimation { property: "opacity"; to: 0; duration: Style.animNormal; easing.type: Easing.InCubic }
        }

        displaced: Transition {
            enabled: !root.service.filterTransitioning

            NumberAnimation { properties: "x,y"; duration: Style.animMedium; easing.type: Easing.OutCubic }
        }

        move: Transition {
            enabled: !root.service.filterTransitioning

            NumberAnimation { properties: "x,y"; duration: Style.animMedium; easing.type: Easing.OutCubic }
        }

        header: Item {
            width: (_listView.width - root.expandedWidth) / 2
            height: 1
        }

        footer: Item {
            width: (_listView.width - root.expandedWidth) / 2
            height: 1
        }

        delegate: SliceDelegate {
            expandedWidth:     root.expandedWidth
            sliceWidth:        root.sliceWidth
            skewOffset:        root.skewOffset
            service:           root.service
            suppressWidthAnim: root.suppressWidthAnim
        }
    }

    Image {
        id: _snapshotImage

        anchors.fill: _listView
        visible: false
        opacity: 0
        z: _listView.z + 1
    }
}
