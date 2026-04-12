import ".."
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Hexagonal grid view for app launcher
Item {
    id: root

    // External bindings (must be provided by parent)
    property var service
    property int hexRadius: 55
    property int hexRows: 4
    property int hexCols: 8
    property int topBarHeight: 50
    property int cardWidth: 800
    property bool cardVisible: false

    // Signals for parent to handle
    signal escapePressed()
    signal appLaunched()
    signal searchInputRequested(string text)  // When user types while grid is focused
    signal backspaceRequested()

    // Read-only outputs for parent
    readonly property alias currentIndex: hexListView.currentIndex
    readonly property alias selectedRow: hexListView._selectedRow
    readonly property alias selectedCol: hexListView._selectedCol
    readonly property int _rows: hexListView._rows

    // Public function to forward focus to the ListView
    function forceActiveFocus() {
        hexListView.forceActiveFocus();
    }

    // Internal geometry calculations
    property real _r: hexRadius
    property real _hexW: _r * 2
    property real _hexH: Math.ceil(_r * 1.73205)
    property real _gridSpacing: 14
    property real _stepX: 1.5 * _r + _gridSpacing
    property real _stepY: _hexH + _gridSpacing
    property real _gridContentH: (hexRows - 1) * _stepY + _hexH + _stepY / 2

    anchors.fill: parent

    ListView {
        id: hexListView

        property int _rows: root.hexRows
        property real _yOffset: Math.max(0, (height - root._gridContentH) / 2)
        property int _selectedCol: 0
        property int _selectedRow: 0

        anchors.top: parent.top
        anchors.topMargin: root.topBarHeight + 15
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cardWidth - 40
        orientation: ListView.Horizontal
        clip: false
        visible: root.cardVisible
        model: Math.ceil(root.service.filteredModel.count / Math.max(1, _rows))
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1500
        maximumFlickVelocity: 3000
        spacing: 0
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 350
        preferredHighlightBegin: (width - root._hexW) / 2
        preferredHighlightEnd: (width + root._hexW) / 2
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

        Keys.onEscapePressed: root.escapePressed()

        Keys.onReturnPressed: {
            var flatIdx = _selectedCol * _rows + _selectedRow;
            if (flatIdx >= 0 && flatIdx < root.service.filteredModel.count) {
                var app = root.service.filteredModel.get(flatIdx);
                root.service.launchApp(app.exec, app.terminal, app.name);
                root.appLaunched();
            }
        }

        Keys.onLeftPressed: {
            if (currentIndex > 0) {
                currentIndex--;
                _selectedCol = currentIndex;
            }
        }

        Keys.onRightPressed: {
            if (currentIndex < count - 1) {
                currentIndex++;
                _selectedCol = currentIndex;
            }
        }

        Keys.onUpPressed: {
            if (_selectedRow > 0)
                _selectedRow--;
        }

        Keys.onDownPressed: {
            var maxRow = Math.min(_rows, root.service.filteredModel.count - _selectedCol * _rows) - 1;
            if (_selectedRow < maxRow)
                _selectedRow++;
        }

        Keys.onPressed: function(event) {
            if (event.text && event.text.length > 0 && !event.modifiers) {
                var c = event.text.charCodeAt(0);
                if (c >= 32 && c < 127) {
                    root.searchInputRequested(event.text);
                    event.accepted = true;
                }
            }
            if (event.key === Qt.Key_Backspace) {
                root.backspaceRequested();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onWheel: function(wheel) {
                var delta = (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) ? -1 : 1;
                hexListView.currentIndex = Math.max(0, Math.min(hexListView.count - 1, hexListView.currentIndex + delta));
                hexListView._selectedCol = hexListView.currentIndex;
            }
            onPressed: function(mouse) { mouse.accepted = false; }
            onReleased: function(mouse) { mouse.accepted = false; }
            onClicked: function(mouse) { mouse.accepted = false; }
        }

        highlight: Item {}

        header: Item {
            width: (hexListView.width - root._hexW) / 2
        }

        footer: Item {
            width: (hexListView.width - root._hexW) / 2
        }

        delegate: Item {
            id: hexCol

            property int colIdx: index
            readonly property real _colCenter: (x - hexListView.contentX) + width * 0.5
            readonly property bool _nearEdge: _colCenter < root._stepX || _colCenter > (hexListView.width - root._stepX)
            readonly property bool _nearLeft: _colCenter < hexListView.width / 2
            property real _colScale: !_nearEdge ? 1 : 0
            readonly property real _arcOffset: {
                var viewCenterX = hexListView.width / 2;
                var normalized = (_colCenter - viewCenterX) / Math.max(1, viewCenterX);
                return -normalized * normalized * root._r * 1.2;
            }

            width: root._stepX
            height: hexListView.height
            clip: false

            Repeater {
                model: Math.max(0, Math.min(hexListView._rows, root.service.filteredModel.count - hexCol.colIdx * hexListView._rows))

                Item {
                    id: hexItem

                    property int rowIdx: index
                    property int flatIdx: hexCol.colIdx * hexListView._rows + rowIdx
                    property var appData: flatIdx < root.service.filteredModel.count ? root.service.filteredModel.get(flatIdx) : null
                    property bool isSelected: hexCol.colIdx === hexListView._selectedCol && rowIdx === hexListView._selectedRow
                    property bool isHovered: hexItemMouse.containsMouse
                    readonly property real _r: root._r
                    readonly property real _cx: _r
                    readonly property real _cy: height / 2
                    readonly property real _cos30: 0.866025
                    readonly property real _sin30: 0.5

                    width: root._hexW
                    height: root._hexH
                    x: 0
                    y: hexListView._yOffset + rowIdx * root._stepY + (hexCol.colIdx % 2 !== 0 ? root._stepY / 2 : 0) + hexCol._arcOffset
                    scale: hexCol._colScale
                    transformOrigin: hexCol._nearLeft ? Item.Left : Item.Right
                    opacity: hexCol._colScale < 0.01 ? 0 : 1

                    Item {
                        id: hexItemMask
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

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                        }

                        Image {
                            id: hexIconImg
                            anchors.centerIn: parent
                            width: hexItem._r * 1.1
                            height: hexItem._r * 1.1
                            source: hexItem.appData && hexItem.appData.iconPath ? "file://" + hexItem.appData.iconPath : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: hexItem.appData ? hexItem.appData.name.substring(0, 1).toUpperCase() : "?"
                            font.pixelSize: hexItem._r * 0.65
                            font.weight: Font.Bold
                            color: Colors.primary
                            visible: hexIconImg.status !== Image.Ready
                        }

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: hexItemMask
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }
                    }

                    // Dimming overlay when not selected
                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, hexItem.isSelected ? 0 : (hexItem.isHovered ? 0.1 : 0.35))

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                        }

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: hexItemMask
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }
                    }

                    // Hexagon border
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
                                ColorAnimation { duration: 100 }
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
                        width: root._hexW + root._gridSpacing
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: hexItemMouse

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
                                hexListView._selectedCol = hexCol.colIdx;
                                hexListView._selectedRow = rowIdx;
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
