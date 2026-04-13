import ".."
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Hexagonal grid view for app launcher.
// Mirrors WallpaperHexView — same ListView column pattern, arc effect and
// fade zones.  Only apps that have a non-empty iconPath are displayed.
Item {
    id: root

    // ── inputs ───────────────────────────────────────────────────────────────
    property var service
    property int hexRadius: 56
    property int hexRows: 4
    property int hexCols: 8
    property int topBarHeight: 50
    property int cardWidth: 800
    property bool cardVisible: false
    property int scrollStep: 1
    property bool arcEnabled: true
    property real arcIntensity: 1.2
    // ── read-write alias so AppLauncher can call resetToStart ────────────────
    property alias currentIndex: _hexListView.currentIndex
    // ── filtered item list (only apps with a non-empty iconPath) ──────────────
    property var _hexItems: []

    // ── signals ───────────────────────────────────────────────────────────────
    signal escapePressed()
    signal appLaunched()
    signal searchInputRequested(string text)
    signal backspaceRequested()

    // ── public functions ──────────────────────────────────────────────────────
    function forceActiveFocus() {
        _hexListView.forceActiveFocus();
    }

    function _rebuildHexItems() {
        var fm = root.service ? root.service.filteredModel : null;
        if (!fm) {
            root._hexItems = [];
            return ;
        }
        var arr = [];
        for (var i = 0; i < fm.count; i++) {
            var item = fm.get(i);
            if (item.iconPath)
                arr.push({
                "name": item.name,
                "exec": item.exec,
                "terminal": item.terminal,
                "iconPath": item.iconPath
            });

        }
        root._hexItems = arr;
    }

    onServiceChanged: root._rebuildHexItems()
    onCardVisibleChanged: {
        if (cardVisible && root._hexItems.length === 0)
            root._rebuildHexItems();

    }
    anchors.fill: parent

    // ── primary rebuild trigger: listen for modelUpdated signal ───────────────
    Connections {
        function onModelUpdated() { root._rebuildHexItems() }
        target: root.service
    }

    ListView {
        id: _hexListView

        // ── geometry ──────────────────────────────────────────────────────────
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
        // ── selection state ───────────────────────────────────────────────────
        property int _selectedCol: currentIndex
        property int _selectedRow: 0

        // ── positioning: centered on screen, below the filter bar ─────────────
        x: (parent.width - root.cardWidth) / 2
        y: root.topBarHeight + 15
        width: root.cardWidth
        height: parent.height - root.topBarHeight - 35
        visible: root.cardVisible
        orientation: ListView.Horizontal
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1500
        maximumFlickVelocity: 3000
        cacheBuffer: _stepX * 2
        spacing: 0
        model: root.cardVisible ? Math.ceil(root._hexItems.length / Math.max(1, _rows)) : 0
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 350
        preferredHighlightBegin: (width - _hexW) / 2
        preferredHighlightEnd: (width + _hexW) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        onVisibleChanged: {
            if (visible) {
                var startCol = Math.min(Math.floor(root.hexCols / 2), count - 1);
                if (startCol >= 0) {
                    currentIndex = startCol;
                    _selectedCol = startCol;
                    _selectedRow = 0;
                }
            }
        }
        onCountChanged: {
            if (count > 0 && visible) {
                var startCol = Math.min(Math.floor(root.hexCols / 2), count - 1);
                if (startCol >= 0) {
                    currentIndex = startCol;
                    _selectedCol = startCol;
                    _selectedRow = 0;
                }
            }
        }
        // ── keyboard ──────────────────────────────────────────────────────────
        Keys.onEscapePressed: root.escapePressed()
        Keys.onReturnPressed: {
            var flatIdx = _selectedCol * _rows + _selectedRow;
            if (flatIdx >= 0 && flatIdx < root._hexItems.length) {
                var app = root._hexItems[flatIdx];
                root.service.launchApp(app.exec, app.terminal, app.name);
                root.appLaunched();
            }
        }
        Keys.onPressed: function(event) {
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
            if (event.key === Qt.Key_Up) {
                if (_selectedRow > 0)
                    _selectedRow--;

                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Down) {
                var maxRow = Math.min(_rows, root._hexItems.length - _selectedCol * _rows) - 1;
                if (_selectedRow < maxRow)
                    _selectedRow++;

                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Backspace) {
                root.backspaceRequested();
                event.accepted = true;
                return ;
            }
            if (event.text && event.text.length > 0 && !event.modifiers) {
                var c = event.text.charCodeAt(0);
                if (c >= 32 && c < 127) {
                    root.searchInputRequested(event.text);
                    event.accepted = true;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function(wheel) {
                var direction = (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) ? -1 : 1;
                _hexListView.currentIndex = Math.max(0, Math.min(_hexListView.count - 1, _hexListView.currentIndex + direction * root.scrollStep));
                _hexListView._selectedCol = _hexListView.currentIndex;
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

        // ── column delegate ───────────────────────────────────────────────────
        delegate: Item {
            id: hexCol

            property int colIdx: index
            readonly property real _colCenter: (x - _hexListView.contentX) + width * 0.5
            readonly property bool _insideView: _colCenter > -_hexListView._hexW && _colCenter < _hexListView.width + _hexListView._hexW
            readonly property bool _nearEdge: _colCenter < _hexListView._fadeZone || _colCenter > (_hexListView.width - _hexListView._fadeZone)
            readonly property bool _nearLeft: _colCenter < _hexListView.width / 2
            readonly property bool _visible: _insideView && !_nearEdge
            property real _colScale: _visible ? 1 : 0
            property real _arcFactor: root.arcEnabled ? root.arcIntensity : 0
            readonly property real _arcOffset: {
                if (_arcFactor === 0)
                    return 0;
                var viewCenterX = _hexListView.width / 2;
                var normalized = (_colCenter - viewCenterX) / Math.max(1, viewCenterX);
                return -normalized * normalized * _hexListView._r * _arcFactor;
            }

            Behavior on _arcFactor {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            width: _hexListView._stepX
            height: _hexListView.height
            clip: false

            Repeater {
                model: Math.max(0, Math.min(_hexListView._rows, root._hexItems.length - hexCol.colIdx * _hexListView._rows))

                Item {
                    id: hexItem

                    property int rowIdx: index
                    property int flatIdx: hexCol.colIdx * _hexListView._rows + rowIdx
                    property var appData: (flatIdx >= 0 && flatIdx < root._hexItems.length) ? root._hexItems[flatIdx] : null
                    property bool isSelected: hexCol.colIdx === _hexListView._selectedCol && rowIdx === _hexListView._selectedRow
                    property bool isHovered: hexMouse.containsMouse
                    readonly property real _r: _hexListView._r
                    readonly property real _cx: _r
                    readonly property real _cy: height / 2
                    readonly property real _cos30: 0.866025
                    readonly property real _sin30: 0.5

                    width: _hexListView._hexW
                    height: _hexListView._hexH
                    x: 0
                    y: _hexListView._yOffset + rowIdx * _hexListView._stepY + (hexCol.colIdx % 2 !== 0 ? _hexListView._stepY / 2 : 0) + hexCol._arcOffset
                    scale: hexCol._colScale
                    transformOrigin: hexCol._nearLeft ? Item.Left : Item.Right
                    opacity: hexCol._colScale < 0.01 ? 0 : 1

                    // ── hex mask (shared by image and dim overlays) ────────────
                    Item {
                        id: hexMask

                        width: parent.width
                        height: parent.height
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

                    // ── icon image ────────────────────────────────────────────
                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                        }

                        Image {
                            id: hexIcon

                            anchors.centerIn: parent
                            width: hexItem._r * 1.1
                            height: hexItem._r * 1.1
                            source: hexItem.appData ? "file://" + hexItem.appData.iconPath : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: hexMask
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }

                    }

                    // ── dimming overlay ───────────────────────────────────────
                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, hexItem.isSelected ? 0 : (hexItem.isHovered ? 0.1 : 0.35))

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: hexMask
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }

                    }

                    // ── hex border ────────────────────────────────────────────
                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: hexItem.isSelected ? Colors.primary : Qt.rgba(0, 0, 0, 0.5)
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
                                    duration: 100
                                }

                            }

                        }

                    }

                    // ── accent rim (bottom-left + bottom edges) ───────────────
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

                    // ── app name label ────────────────────────────────────────
                    Text {
                        anchors.top: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 4
                        text: hexItem.appData ? hexItem.appData.name : ""
                        font.family: Style.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: hexItem.isSelected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        width: _hexListView._hexW + _hexListView._gridSpacing
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // ── mouse interaction ─────────────────────────────────────
                    MouseArea {
                        id: hexMouse

                        function contains(point) {
                            var dx = Math.abs(point.x - hexItem._cx);
                            var dy = Math.abs(point.y - hexItem._cy);
                            return dy <= hexItem._cos30 * hexItem._r && dx <= hexItem._r - dy * 0.57735;
                        }

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                _hexListView._selectedCol = hexCol.colIdx;
                                _hexListView._selectedRow = rowIdx;
                            }
                        }
                        onClicked: {
                            if (hexItem.appData) {
                                root.service.launchApp(hexItem.appData.exec, hexItem.appData.terminal, hexItem.appData.name);
                                root.appLaunched();
                            }
                        }
                    }

                }

            }

            Behavior on _colScale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.5
                }

            }

        }

    }

}
