import "../.."
import "../services"
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Hexagonal grid display mode.
// Owns the column-based ListView (each column is a Repeater of HexDelegate),
// and the full-screen flip-card detail overlay (hexBackOverlay).
Item {
    // ── public functions ──────────────────────────────────────────────────────
    // ── hex list view ─────────────────────────────────────────────────────────
    // ── hex detail card overlay ───────────────────────────────────────────────

    id: root

    // ── inputs ───────────────────────────────────────────────────────────────
    property var service
    property Item containerItem // reference to cardContainer in selectorPanel
    property int hexRadius
    property int hexRows
    property int hexCols
    property int topBarHeight
    property bool cardVisible
    property bool anyBrowserOpen
    property bool isHexMode
    property bool tagCloudVisible
    property bool showing

    // ── signals ───────────────────────────────────────────────────────────────
    signal escapePressed()
    signal tagCloudToggleRequested()
    signal focusRequested()

    function focusList() {
        _hexListView.forceActiveFocus();
    }

    anchors.fill: parent

    ListView {
        id: _hexListView

        property int _rows: root.hexRows
        property real _r: root.hexRadius
        property real _gridSpacing: 14
        property real _hexW: _r * 2
        property real _hexH: Math.ceil(_r * 1.73205)
        property real _stepX: 1.5 * _r + _gridSpacing
        property real _stepY: _hexH + _gridSpacing
        property real _gridContentH: (_rows - 1) * _stepY + _hexH + _stepY / 2
        property real _yOffset: Math.max(0, (height - _gridContentH) / 2)
        property real _fadeZone: _stepX
        property int _selectedCol: currentIndex
        property int _selectedRow: 0

        x: root.containerItem.x
        y: root.containerItem.y + root.topBarHeight + 15
        width: root.containerItem.width
        height: root.containerItem.height - root.topBarHeight - 35
        visible: root.cardVisible && !root.anyBrowserOpen && root.isHexMode
        orientation: ListView.Horizontal
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1500
        maximumFlickVelocity: 3000
        cacheBuffer: _stepX * 2
        focus: root.showing && root.isHexMode && !root.tagCloudVisible
        onVisibleChanged: {
            if (visible && !root.tagCloudVisible)
                forceActiveFocus();

            if (visible) {
                var startCol = Math.min(Math.floor(root.hexCols / 2), count - 1);
                if (startCol >= 0) {
                    currentIndex = startCol;
                    _selectedCol = startCol;
                    _selectedRow = 0;
                }
            }
        }
        model: root.showing ? Math.ceil((root.service.filteredModel ? root.service.filteredModel.count : 0) / Math.max(1, _rows)) : 0
        onCountChanged: {
            if (count > 0 && visible && !root.tagCloudVisible) {
                var startCol = Math.min(Math.floor(root.hexCols / 2), count - 1);
                if (startCol >= 0) {
                    currentIndex = startCol;
                    _selectedCol = startCol;
                    _selectedRow = 0;
                }
            }
        }
        spacing: 0
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Style.animExpand
        preferredHighlightBegin: (width - _hexW) / 2
        preferredHighlightEnd: (width + _hexW) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        Keys.onEscapePressed: root.escapePressed()
        Keys.onReturnPressed: {
            var flatIdx = _selectedCol * _rows + _selectedRow;
            if (flatIdx >= 0 && flatIdx < root.service.filteredModel.count) {
                var item = root.service.filteredModel.get(flatIdx);
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
                    return ;
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
                    return ;
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
                    return ;
                }
            }
            if (event.key === Qt.Key_Left && !(event.modifiers & Qt.ShiftModifier)) {
                if (currentIndex > 0) {
                    currentIndex--;
                    _selectedCol = currentIndex;
                }
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Right && !(event.modifiers & Qt.ShiftModifier)) {
                if (currentIndex < count - 1) {
                    currentIndex++;
                    _selectedCol = currentIndex;
                }
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Up && !(event.modifiers & Qt.ShiftModifier)) {
                if (_selectedRow > 0)
                    _selectedRow--;

                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Down && !(event.modifiers & Qt.ShiftModifier)) {
                var maxRow = Math.min(_rows, root.service.filteredModel.count - _selectedCol * _rows) - 1;
                if (_selectedRow < maxRow)
                    _selectedRow++;

                event.accepted = true;
                return ;
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function(wheel) {
                var step = Config.hexScrollStep;
                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                    _hexListView.currentIndex = Math.max(0, _hexListView.currentIndex - step);
                    _hexListView._selectedCol = _hexListView.currentIndex;
                } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
                    _hexListView.currentIndex = Math.min(_hexListView.count - 1, _hexListView.currentIndex + step);
                    _hexListView._selectedCol = _hexListView.currentIndex;
                }
            }
            onPressed: function(mouse) {
                mouse.accepted = false;
            }
            onReleased: function(mouse) {
                mouse.accepted = false;
            }
            onClicked: function(mouse) {
                mouse.accepted = false;
            }
        }

        highlight: Item {
        }

        header: Item {
            width: (_hexListView.width - _hexListView._hexW) / 2
        }

        footer: Item {
            width: (_hexListView.width - _hexListView._hexW) / 2
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Style.animEnter
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1
                duration: Style.animEnter
                easing.type: Easing.OutCubic
            }

        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Style.animNormal
                easing.type: Easing.InCubic
            }

        }

        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Style.animMedium
                easing.type: Easing.OutCubic
            }

        }

        delegate: Item {
            id: hexCol

            property int colIdx: index
            readonly property real _colCenter: (x - _hexListView.contentX) + width * 0.5
            readonly property bool _insideView: _colCenter > -_hexListView._hexW && _colCenter < _hexListView.width + _hexListView._hexW
            readonly property bool _nearEdge: _colCenter < _hexListView._fadeZone || _colCenter > (_hexListView.width - _hexListView._fadeZone)
            readonly property bool _nearLeft: _colCenter < _hexListView.width / 2
            readonly property bool _visible: _insideView && !_nearEdge
            property real _colScale: _visible ? 1 : 0
            property real _arcFactor: Config.hexArc ? Config.hexArcIntensity : 0
            readonly property real _arcOffset: {
                if (_arcFactor === 0)
                    return 0;

                var viewCenterX = _hexListView.width / 2;
                var normalized = (_colCenter - viewCenterX) / Math.max(1, viewCenterX);
                return -normalized * normalized * _hexListView._r * _arcFactor;
            }

            width: _hexListView._stepX
            height: _hexListView.height
            clip: false

            Repeater {
                model: Math.max(0, Math.min(_hexListView._rows, root.service.filteredModel.count - hexCol.colIdx * _hexListView._rows))

                HexDelegate {
                    property int rowIdx: index
                    property int flatIdx: hexCol.colIdx * _hexListView._rows + rowIdx

                    hexRadius: _hexListView._r
                    service: root.service
                    itemData: root.service.filteredModel.get(flatIdx)
                    isSelected: hexCol.colIdx === _hexListView._selectedCol && rowIdx === _hexListView._selectedRow
                    x: 0
                    y: _hexListView._yOffset + rowIdx * _hexListView._stepY + (hexCol.colIdx % 2 !== 0 ? _hexListView._stepY / 2 : 0) + hexCol._arcOffset
                    parallaxX: {
                        var viewCenterX = _hexListView.width / 2;
                        var normalized = (hexCol._colCenter - viewCenterX) / Math.max(1, viewCenterX);
                        return -normalized * _hexListView._r * 0.6;
                    }
                    parallaxY: {
                        var viewCenterY = _hexListView.height / 2;
                        var hexCenterY = y + height / 2;
                        var normalized = (hexCenterY - viewCenterY) / Math.max(1, viewCenterY);
                        return -normalized * _hexListView._r * 0.6;
                    }
                    scale: hexCol._colScale
                    transformOrigin: hexCol._nearLeft ? Item.Left : Item.Right
                    opacity: hexCol._colScale < 0.01 ? 0 : 1
                    pulledOut: _hexOverlay.overlayItemKey !== "" && _hexOverlay.overlayItemKey === ((itemData && ((itemData.weId || "") !== "")) ? itemData.weId : (itemData ? itemData.name : ""))
                    onFlipRequested: function(data, gx, gy, sourceItem) {
                        _hexOverlay.show(data, gx, gy, sourceItem);
                    }
                    onHoverSelected: {
                        _hexListView._selectedCol = hexCol.colIdx;
                        _hexListView._selectedRow = rowIdx;
                    }
                }

            }

            Behavior on _colScale {
                NumberAnimation {
                    duration: Style.animExpand
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.5
                }

            }

            Behavior on _arcFactor {
                NumberAnimation {
                    duration: Style.animExpand
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    Item {
        // ── flip card ─────────────────────────────────────────────────────────

        id: _hexOverlay

        property var overlayData: null
        property string overlayItemKey: ""
        property var _sourceItem: null
        property real sourceX: 0
        property real sourceY: 0
        property real _openContentX: 0
        property bool overlayOpen: false
        property var _hexMeta: null
        readonly property real bigR: root.hexRadius * 3
        readonly property real bigW: bigR * 2
        readonly property real bigH: Math.ceil(bigR * 1.73205)
        readonly property real _cos30: 0.866025
        readonly property real _sin30: 0.5

        function show(data, gx, gy, sourceItem) {
            overlayTagField.text = "";
            overlayTagField._sessionTags = [];
            overlayData = data;
            overlayItemKey = (data.weId || "") !== "" ? data.weId : data.name;
            _sourceItem = sourceItem || null;
            _openContentX = _hexListView.contentX;
            var local = _hexOverlay.mapFromItem(null, gx, gy);
            sourceX = local.x;
            sourceY = local.y;
            visible = true;
            overlayOpen = true;
        }

        function hide() {
            var scrollDelta = _hexListView.contentX - _openContentX;
            sourceX -= scrollDelta;
            _openContentX = _hexListView.contentX;
            overlayOpen = false;
        }

        anchors.fill: parent
        visible: false
        z: 200
        onOverlayOpenChanged: {
            if (overlayOpen && overlayData && overlayData.type !== "we") {
                var key = ImageService.thumbKey(overlayData.thumb, overlayData.name);
                _hexMeta = FileMetadataService.getMetadata(key);
                if (!_hexMeta)
                    FileMetadataService.probeIfNeeded(key, overlayData.path, overlayData.type === "video" ? "video" : "image");

            }
        }
        states: [
            State {
                name: "hidden"
                when: !_hexOverlay.overlayOpen

                PropertyChanges {
                    target: _hexCard
                    x: _hexOverlay.sourceX - _hexCard.width / 2
                    y: _hexOverlay.sourceY - _hexCard.height / 2
                    scale: root.hexRadius / _hexOverlay.bigR
                    opacity: 0
                }

                PropertyChanges {
                    target: _cardRotation
                    angle: 0
                }

            },
            State {
                name: "visible"
                when: _hexOverlay.overlayOpen

                PropertyChanges {
                    target: _hexCard
                    x: (_hexOverlay.width - _hexCard.width) / 2
                    y: (_hexOverlay.height - _hexCard.height) / 2
                    scale: 1
                    opacity: 1
                }

                PropertyChanges {
                    target: _cardRotation
                    angle: 180
                }

            }
        ]
        transitions: [
            Transition {
                from: "hidden"
                to: "visible"

                SequentialAnimation {
                    PropertyAction {
                        target: _hexOverlay
                        property: "visible"
                        value: true
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: _hexCard
                            properties: "x,y,scale,opacity"
                            duration: Style.animSlow
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: _cardRotation
                            property: "angle"
                            duration: Style.animSlow
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

            },
            Transition {
                from: "visible"
                to: "hidden"

                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation {
                            target: _hexCard
                            properties: "x,y,scale"
                            duration: Style.animSlow
                            easing.type: Easing.InOutCubic
                        }

                        NumberAnimation {
                            target: _cardRotation
                            property: "angle"
                            duration: Style.animSlow
                            easing.type: Easing.InOutQuad
                        }

                        SequentialAnimation {
                            PauseAnimation {
                                duration: Style.animSlow * 0.7
                            }

                            NumberAnimation {
                                target: _hexCard
                                property: "opacity"
                                duration: Style.animSlow * 0.3
                                easing.type: Easing.InQuad
                            }

                        }

                    }

                    PropertyAction {
                        target: _hexOverlay
                        property: "visible"
                        value: false
                    }

                    PropertyAction {
                        target: _hexOverlay
                        property: "overlayItemKey"
                        value: ""
                    }

                    PropertyAction {
                        target: _hexOverlay
                        property: "_sourceItem"
                        value: null
                    }

                }

            }
        ]

        Connections {
            function onMetadataReady(key) {
                if (!_hexOverlay.overlayData)
                    return ;

                var myKey = ImageService.thumbKey(_hexOverlay.overlayData.thumb, _hexOverlay.overlayData.name);
                if (key === myKey)
                    _hexOverlay._hexMeta = FileMetadataService.getMetadata(key);

            }

            target: FileMetadataService
            enabled: _hexOverlay.overlayOpen
        }

        // dim background
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, _hexOverlay.overlayOpen ? 0.55 : 0)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: _hexOverlay.hide()
            }

            Behavior on color {
                ColorAnimation {
                    duration: Style.animNormal
                }

            }

        }

        Item {
            id: _hexCard

            width: _hexOverlay.bigW
            height: _hexOverlay.bigH
            transformOrigin: Item.Center

            // Hex mask shape (used by both front and back face via layer.effect)
            Item {
                id: _bigHexMask

                width: _hexCard.width
                height: _hexCard.height
                visible: false
                layer.enabled: true

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "white"
                        strokeColor: "transparent"
                        startX: _hexOverlay.bigR * 2
                        startY: _hexCard.height / 2

                        PathLine {
                            x: _hexOverlay.bigR + _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 - _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR - _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 - _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: 0
                            y: _hexCard.height / 2
                        }

                        PathLine {
                            x: _hexOverlay.bigR - _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 + _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR + _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 + _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR * 2
                            y: _hexCard.height / 2
                        }

                    }

                }

            }

            // Front face: thumbnail image clipped to hex
            Item {
                id: _frontFace

                anchors.fill: parent
                visible: _cardRotation.angle < 90

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true

                    Image {
                        anchors.fill: parent
                        source: _hexOverlay.overlayData && _hexOverlay.overlayData.thumb ? ImageService.fileUrl(_hexOverlay.overlayData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        cache: false
                        sourceSize.width: _hexOverlay.bigW
                        sourceSize.height: _hexOverlay.bigH
                    }

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: _bigHexMask
                        maskThresholdMin: 0.3
                        maskSpreadAtMin: 0.3
                    }

                }

                // Hex outline
                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.primary
                        strokeWidth: 2
                        startX: _hexOverlay.bigR * 2
                        startY: _hexCard.height / 2

                        PathLine {
                            x: _hexOverlay.bigR + _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 - _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR - _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 - _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: 0
                            y: _hexCard.height / 2
                        }

                        PathLine {
                            x: _hexOverlay.bigR - _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 + _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR + _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 + _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR * 2
                            y: _hexCard.height / 2
                        }

                    }

                }

            }

            // Back face: metadata + actions (mirrored so it reads correctly after flip)
            Item {
                id: _backFace

                anchors.fill: parent
                visible: _cardRotation.angle >= 90

                Item {
                    id: _backClip

                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        z: -1
                        onClicked: _hexOverlay.hide()
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Colors.surfaceContainer
                    }

                    Image {
                        anchors.fill: parent
                        source: _hexOverlay.overlayData && _hexOverlay.overlayData.thumb ? ImageService.fileUrl(_hexOverlay.overlayData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.08
                        sourceSize.width: 120
                        sourceSize.height: 104
                        asynchronous: true
                        cache: false
                    }

                    Column {
                        anchors.centerIn: parent
                        width: _hexOverlay.bigR * 1.6
                        spacing: 4

                        // Title
                        Text {
                            width: parent.width
                            text: _hexOverlay.overlayData ? _hexOverlay.overlayData.name.replace(/\.[^/.]+$/, "").toUpperCase() : ""
                            color: Colors.tertiary
                            font.family: Style.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }

                        // Metadata row (ext · resolution · size)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 0
                            visible: _hexOverlay.overlayData && _hexOverlay.overlayData.type !== "we"

                            Text {
                                text: _hexOverlay.overlayData ? FileMetadataService.formatExt(_hexOverlay.overlayData.name) : ""
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.6)
                                font.family: Style.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                            }

                            Text {
                                text: "  \u2022  "
                                color: Qt.rgba(1, 1, 1, 0.15)
                                font.family: Style.fontFamily
                                font.pixelSize: 11
                            }

                            Text {
                                text: _hexOverlay._hexMeta ? (_hexOverlay._hexMeta.width + " \u00d7 " + _hexOverlay._hexMeta.height) : "\u2013"
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.6)
                                font.family: Style.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 0.5
                            }

                            Text {
                                text: "  \u2022  "
                                color: Qt.rgba(1, 1, 1, 0.15)
                                font.family: Style.fontFamily
                                font.pixelSize: 11
                            }

                            Text {
                                text: _hexOverlay._hexMeta ? FileMetadataService.formatSize(_hexOverlay._hexMeta.filesize) : "\u2013"
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.6)
                                font.family: Style.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 0.5
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Favourite toggle
                        Item {
                            width: parent.width
                            height: 26

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "FAVOURITE"
                                color: Colors.tertiary
                                font.family: Style.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                font.letterSpacing: 0.5
                            }

                            Item {
                                id: _overlayFavToggle

                                property bool checked: false

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 22

                                Connections {
                                    function onOverlayOpenChanged() {
                                        if (_hexOverlay.overlayOpen && _hexOverlay.overlayData) {
                                            var key = (_hexOverlay.overlayData.weId || "") !== "" ? _hexOverlay.overlayData.weId : _hexOverlay.overlayData.name;
                                            _overlayFavToggle.checked = root.service ? !!root.service.favouritesDb[key] : false;
                                        }
                                    }

                                    target: _hexOverlay
                                }

                                // Track background
                                Canvas {
                                    property bool isOn: _overlayFavToggle.checked
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
                                        ctx.moveTo(sk, 0);
                                        ctx.lineTo(width, 0);
                                        ctx.lineTo(width - sk, height);
                                        ctx.lineTo(0, height);
                                        ctx.closePath();
                                        ctx.fill();
                                    }
                                }

                                // Knob
                                Canvas {
                                    property color knobColor: _overlayFavToggle.checked ? Colors.primaryText : Colors.surfaceText

                                    width: 20
                                    height: 16
                                    y: 3
                                    x: _overlayFavToggle.checked ? parent.width - width - 3 : 3
                                    onKnobColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        var sk = 4;
                                        ctx.fillStyle = knobColor;
                                        ctx.beginPath();
                                        ctx.moveTo(sk, 0);
                                        ctx.lineTo(width, 0);
                                        ctx.lineTo(width - sk, height);
                                        ctx.lineTo(0, height);
                                        ctx.closePath();
                                        ctx.fill();
                                    }

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Style.animFast
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!_hexOverlay.overlayData)
                                            return ;

                                        _overlayFavToggle.checked = !_overlayFavToggle.checked;
                                        root.service.toggleFavourite(_hexOverlay.overlayData.name, _hexOverlay.overlayData.weId || "");
                                    }
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Tag input field
                        Item {
                            width: parent.width
                            height: 24

                            Rectangle {
                                anchors.fill: parent
                                color: overlayTagField.activeFocus ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5) : "transparent"
                                border.width: 1
                                border.color: overlayTagField.activeFocus ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Style.animVeryFast
                                    }

                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Style.animVeryFast
                                    }

                                }

                            }

                            TextInput {
                                id: overlayTagField

                                property var _sessionTags: []
                                property bool _syncing: false

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Style.fontFamily
                                font.pixelSize: 11
                                font.letterSpacing: 0.3
                                color: Colors.surfaceText
                                clip: true
                                onTextChanged: {
                                    if (_syncing || !_hexOverlay.overlayData)
                                        return ;

                                    var raw = text.toLowerCase();
                                    var words = raw.split(/\s+/).filter(function(w) {
                                        return w.length > 0;
                                    });
                                    var wpTags = root.service.getWallpaperTags(_overlayTagsSection.wpName, _overlayTagsSection.wpWeId).slice();
                                    var changed = false;
                                    for (var i = 0; i < words.length; i++) {
                                        if (_sessionTags.indexOf(words[i]) === -1)
                                            _sessionTags.push(words[i]);

                                        if (wpTags.indexOf(words[i]) === -1) {
                                            wpTags.push(words[i]);
                                            changed = true;
                                        }
                                    }
                                    var toRemove = [];
                                    for (var k = 0; k < _sessionTags.length; k++) {
                                        if (words.indexOf(_sessionTags[k]) === -1)
                                            toRemove.push(_sessionTags[k]);

                                    }
                                    for (var r = 0; r < toRemove.length; r++) {
                                        var si = _sessionTags.indexOf(toRemove[r]);
                                        if (si !== -1)
                                            _sessionTags.splice(si, 1);

                                        var wi = wpTags.indexOf(toRemove[r]);
                                        if (wi !== -1) {
                                            wpTags.splice(wi, 1);
                                            changed = true;
                                        }
                                    }
                                    if (changed)
                                        root.service.setWallpaperTags(_overlayTagsSection.wpName, _overlayTagsSection.wpWeId, wpTags);

                                }
                                Keys.onReturnPressed: function(event) {
                                    event.accepted = true;
                                }
                                Keys.onEscapePressed: {
                                    text = "";
                                    _sessionTags = [];
                                    _hexOverlay.hide();
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "+ ADD TAG"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                                    visible: !parent.text && !parent.activeFocus
                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                z: -1
                                onClicked: overlayTagField.forceActiveFocus()
                            }

                        }

                        // Current tags
                        Item {
                            id: _overlayTagsSection

                            property string wpName: _hexOverlay.overlayData ? _hexOverlay.overlayData.name : ""
                            property string wpWeId: _hexOverlay.overlayData ? (_hexOverlay.overlayData.weId || "") : ""
                            property var currentTags: {
                                if (!_hexOverlay.overlayOpen)
                                    return [];

                                var db = root.service ? root.service.tagsDb : null;
                                if (!db)
                                    return [];

                                var key = _overlayTagsSection.wpWeId ? _overlayTagsSection.wpWeId : ImageService.thumbKey(_hexOverlay.overlayData ? _hexOverlay.overlayData.thumb : "", _overlayTagsSection.wpName);
                                return db[key] || [];
                            }

                            width: parent.width
                            height: Math.min(Math.max(30, _overlayTagsFlow.implicitHeight + 10), _hexOverlay.bigR * 0.5)
                            clip: true

                            Flickable {
                                anchors.fill: parent
                                contentHeight: _overlayTagsFlow.implicitHeight
                                clip: true
                                flickableDirection: Flickable.VerticalFlick
                                boundsBehavior: Flickable.StopAtBounds

                                Flow {
                                    id: _overlayTagsFlow

                                    width: parent.width
                                    spacing: 5

                                    Repeater {
                                        model: _overlayTagsSection.currentTags

                                        Rectangle {
                                            property bool hovered: _tagMa.containsMouse

                                            width: _tagTxt.implicitWidth + 30
                                            height: 28
                                            radius: 4
                                            color: hovered ? Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.5) : "transparent"
                                            border.width: 1
                                            border.color: hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.7) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)

                                            Text {
                                                id: _tagTxt

                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.toUpperCase()
                                                color: Colors.tertiary
                                                font.family: Style.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                font.letterSpacing: 0.5
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "\u{f0156}"
                                                font.family: Style.fontFamilyNerdIcons
                                                font.pixelSize: 11
                                                color: parent.hovered ? Colors.primary : Qt.rgba(1, 1, 1, 0.25)

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: Style.animVeryFast
                                                    }

                                                }

                                            }

                                            MouseArea {
                                                id: _tagMa

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var tags = root.service.getWallpaperTags(_overlayTagsSection.wpName, _overlayTagsSection.wpWeId).slice();
                                                    var idx = tags.indexOf(modelData);
                                                    if (idx !== -1)
                                                        tags.splice(idx, 1);

                                                    root.service.setWallpaperTags(_overlayTagsSection.wpName, _overlayTagsSection.wpWeId, tags);
                                                }
                                            }

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Style.animVeryFast
                                                }

                                            }

                                            Behavior on border.color {
                                                ColorAnimation {
                                                    duration: Style.animVeryFast
                                                }

                                            }

                                            transform: Matrix4x4 {
                                                matrix: Qt.matrix4x4(1, -0.08, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                            }

                                        }

                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                visible: _overlayTagsSection.currentTags.length === 0
                                text: "NO TAGS"
                                color: Qt.rgba(1, 1, 1, 0.15)
                                font.family: Style.fontFamily
                                font.pixelSize: 12
                                font.letterSpacing: 2
                            }

                        }

                        // Action buttons
                        Row {
                            width: parent.width
                            height: 32
                            spacing: 8

                            ActionButton {
                                width: _hexOverlay.overlayData && _hexOverlay.overlayData.type === "we" ? (parent.width - parent.spacing * 2) / 3 : (parent.width - parent.spacing) / 2
                                icon: "\u{f0208}"
                                label: "VIEW"
                                onClicked: {
                                    if (!_hexOverlay.overlayData)
                                        return ;

                                    var p = _hexOverlay.overlayData.path;
                                    Qt.openUrlExternally(ImageService.fileUrl(p.substring(0, p.lastIndexOf("/"))));
                                    _hexOverlay.hide();
                                }
                            }

                            ActionButton {
                                width: _hexOverlay.overlayData && _hexOverlay.overlayData.type === "we" ? (parent.width - parent.spacing * 2) / 3 : (parent.width - parent.spacing) / 2
                                icon: "\u{f0a79}"
                                label: "DELETE"
                                danger: true
                                onClicked: {
                                    if (!_hexOverlay.overlayData)
                                        return ;

                                    root.service.deleteWallpaperItem(_hexOverlay.overlayData.type, _hexOverlay.overlayData.name, _hexOverlay.overlayData.weId || "");
                                    _hexOverlay.hide();
                                }
                            }

                            ActionButton {
                                visible: _hexOverlay.overlayData && _hexOverlay.overlayData.type === "we"
                                width: visible ? (parent.width - parent.spacing * 2) / 3 : 0
                                icon: "\u{f0bef}"
                                label: "STEAM"
                                onClicked: {
                                    root.service.openSteamPage(_hexOverlay.overlayData.weId || "");
                                    _hexOverlay.hide();
                                }
                            }

                        }

                    }

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: _bigHexMask
                        maskThresholdMin: 0.3
                        maskSpreadAtMin: 0.3
                    }

                }

                // Hex outline on back face
                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.primary
                        strokeWidth: 2.5
                        startX: _hexOverlay.bigR * 2
                        startY: _hexCard.height / 2

                        PathLine {
                            x: _hexOverlay.bigR + _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 - _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR - _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 - _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: 0
                            y: _hexCard.height / 2
                        }

                        PathLine {
                            x: _hexOverlay.bigR - _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 + _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR + _hexOverlay.bigR * _hexOverlay._sin30
                            y: _hexCard.height / 2 + _hexOverlay.bigR * _hexOverlay._cos30
                        }

                        PathLine {
                            x: _hexOverlay.bigR * 2
                            y: _hexCard.height / 2
                        }

                    }

                }

                transform: Rotation {
                    origin.x: _backFace.width / 2
                    origin.y: _backFace.height / 2
                    angle: 180

                    axis {
                        x: 0
                        y: 1
                        z: 0
                    }

                }

            }

            transform: Rotation {
                id: _cardRotation

                origin.x: _hexCard.width / 2
                origin.y: _hexCard.height / 2
                angle: 0

                axis {
                    x: 0
                    y: 1
                    z: 0
                }

            }

        }

    }

}
