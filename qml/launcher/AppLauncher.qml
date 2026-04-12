import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Full-screen app launcher with parallelogram slice UI
Scope {
    id: appLauncher

    // External bindings
    property bool showing: false
    property string mainMonitor: Config.mainMonitor
    property string activeMonitor: mainMonitor
    property bool _panelVisible: false
    // Slice geometry constants
    property int sliceWidth: 135
    property int expandedWidth: 924
    property int sliceHeight: 520
    property int skewOffset: 35
    property int sliceSpacing: -22
    // Hex mode
    property bool isHexMode: Config.launcherDisplayMode === "hex"
    property int hexRadius: Config.hexRadius
    property int hexRows: Config.launcherHexRows
    property int hexCols: Config.launcherHexCols
    // Card dimensions
    property int topBarHeight: 50
    property int cardWidth: isHexMode ? _hexCardWidth : 1600
    property int cardHeight: isHexMode ? _hexCardHeight : (sliceHeight + topBarHeight + 60)
    property int _hexCardWidth: {
        var r = hexRadius;
        var spacing = 14;
        return Math.round((hexCols + 1) * (1.5 * r + spacing) + 2 * r);
    }
    property int _hexCardHeight: {
        var r = hexRadius;
        var rows = hexRows;
        var spacing = 14;
        var hexH = Math.ceil(r * 1.73205);
        var stepY = hexH + spacing;
        return (rows - 1) * stepY + hexH + Math.ceil(stepY / 2) + topBarHeight + 60;
    }
    property bool cardVisible: false
    property int lastContentX: 0
    property int lastIndex: 0

    // Get active monitor via CompositorService when the launcher opens.
    function updateActiveMonitor() {
        // Get active output from CompositorService
        var activeOutput = CompositorService.getActiveOutput();
        if (activeOutput && activeOutput !== "?")
            appLauncher.activeMonitor = activeOutput;

        // Verify activeMonitor resolves to a real screen; fall back to first screen
        var screens = Quickshell.screens;
        var matched = false;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === appLauncher.activeMonitor) {
                matched = true;
                break;
            }
        }
        if (!matched && screens.length > 0) {
            console.warn("AppLauncher: activeMonitor '" + appLauncher.activeMonitor + "' not found in Quickshell.screens — falling back to '" + screens[0].name + "'");
            appLauncher.activeMonitor = screens[0].name;
        }
        appLauncher._panelVisible = true;
        cardShowTimer.restart();
    }

    function resetScroll() {
        lastContentX = 0;
        lastIndex = 0;
    }

    // Show/hide lifecycle
    onShowingChanged: {
        if (showing) {
            _panelVisible = false;
            activeMonitor = mainMonitor;
            updateActiveMonitor();
            service.searchText = "";
            service.loadFreqData();
            service.start();
        } else {
            _panelVisible = false;
            cardVisible = false;
            service.searchText = "";
        }
    }

    // Service handles all data, search, caching, and launch logic
    AppLauncherService {
        id: service

        scriptsDir: Config.scriptsDir
        homeDir: Config.homeDir
        cacheDir: Config.cacheDir
        configDir: Config.configDir
        terminal: Config.terminal
    }

    Timer {
        id: cardShowTimer

        interval: 50
        onTriggered: appLauncher.cardVisible = true
    }

    // Full launcher UI — defined once, instantiated only on the active screen
    Component {
        id: launcherUIComponent

        Item {
            anchors.fill: parent

            // Sync service search text → input, and reset list on model change
            Connections {
                function onSearchTextChanged() {
                    if (searchPanel.searchText !== service.searchText)
                        searchPanel.searchText = service.searchText;

                }

                function onModelUpdated() {
                    if (service.filteredModel.count > 0) {
                        sliceListView.currentIndex = 0;
                        sliceListView.positionViewAtIndex(0, ListView.Beginning);
                        hexGrid.resetToStart();
                    }
                }

                target: service
            }

            Timer {
                id: focusTimer

                interval: 50
                onTriggered: {
                    if (appLauncher.isHexMode)
                        hexGrid.forceActiveFocus();
                    else
                        searchPanel.searchInputItem.forceActiveFocus();
                }
            }

            // Card container with fade-in animation
            Item {
                id: cardContainer

                property bool animateIn: appLauncher.cardVisible

                width: appLauncher.cardWidth
                height: appLauncher.cardHeight
                anchors.centerIn: parent
                visible: appLauncher.cardVisible
                opacity: 0
                onAnimateInChanged: {
                    fadeInAnim.stop();
                    if (animateIn) {
                        opacity = 0;
                        fadeInAnim.start();
                        focusTimer.restart();
                    }
                }

                NumberAnimation {
                    id: fadeInAnim

                    target: cardContainer
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 400
                    easing.type: Easing.OutCubic
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                Item {
                    id: backgroundRect

                    anchors.fill: parent

                    Item {
                        id: filterBarBg

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        width: searchPanel.width + 30
                        height: searchPanel.height + 14
                        z: 10

                        Canvas {
                            readonly property int _sk: 14
                            property color fillColor: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 1)
                            property color accentColor: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)

                            anchors.fill: parent
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

                        // Search panel (source filters + search input)
                        SearchPanel {
                            id: searchPanel

                            anchors.centerIn: parent
                            service: appLauncher.service
                        }

                    }

                    // Cache loading overlay with progress bar
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.95)
                        radius: 20
                        visible: service.cacheLoading
                        z: 50

                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 12
                            width: 300
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: 2
                                width: service.cacheTotal > 0 ? parent.width * (service.cacheProgress / service.cacheTotal) : 0
                                color: Colors.primary

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -12
                            text: service.cacheTotal > 0 ? "LOADING APPS... " + service.cacheProgress + " / " + service.cacheTotal : "SCANNING..."
                            color: Colors.tertiary
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.letterSpacing: 0.5
                        }

                    }

                }

            }

            // Horizontal parallelogram slice list view
            ListView {
                id: sliceListView

                property int visibleCount: 12
                property bool keyboardNavActive: false
                property real lastMouseX: -1
                property real lastMouseY: -1

                anchors.top: cardContainer.top
                anchors.topMargin: appLauncher.topBarHeight + 15
                anchors.bottom: cardContainer.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: appLauncher.expandedWidth + (visibleCount - 1) * (appLauncher.sliceWidth + appLauncher.sliceSpacing)
                orientation: ListView.Horizontal
                model: service.filteredModel
                clip: false
                spacing: appLauncher.sliceSpacing
                flickDeceleration: 1500
                maximumFlickVelocity: 3000
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: appLauncher.expandedWidth * 4
                visible: appLauncher.cardVisible && !appLauncher.isHexMode
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 350
                preferredHighlightBegin: (width - appLauncher.expandedWidth) / 2
                preferredHighlightEnd: (width + appLauncher.expandedWidth) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                onVisibleChanged: {
                    if (visible)
                        searchPanel.searchInputItem.forceActiveFocus();

                }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        appLauncher.showing = false;
                        event.accepted = true;
                        return ;
                    }
                    if (event.text && event.text.length > 0 && !event.modifiers) {
                        var c = event.text.charCodeAt(0);
                        if (c >= 32 && c < 127) {
                            searchPanel.searchText += event.text;
                            searchPanel.searchInputItem.forceActiveFocus();
                            event.accepted = true;
                            return ;
                        }
                    }
                    if (event.key === Qt.Key_Backspace) {
                        if (searchPanel.searchText.length > 0)
                            searchPanel.searchText = searchPanel.searchText.slice(0, -1);

                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < service.filteredModel.count) {
                            var app = service.filteredModel.get(sliceListView.currentIndex);
                            service.launchApp(app.exec, app.terminal, app.name);
                            appLauncher.showing = false;
                        }
                        event.accepted = true;
                        return ;
                    }
                    sliceListView.keyboardNavActive = true;
                    if (event.key === Qt.Key_Left) {
                        if (currentIndex > 0)
                            currentIndex--;

                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Right) {
                        if (currentIndex < service.filteredModel.count - 1)
                            currentIndex++;

                        event.accepted = true;
                        return ;
                    }
                }

                Connections {
                    function onShowingChanged() {
                        if (appLauncher.showing && !appLauncher.isHexMode)
                            searchPanel.searchInputItem.forceActiveFocus();

                    }

                    target: appLauncher
                }

                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onWheel: function(wheel) {
                        var step = 1;
                        if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0)
                            sliceListView.currentIndex = Math.max(0, sliceListView.currentIndex - step);
                        else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0)
                            sliceListView.currentIndex = Math.min(service.filteredModel.count - 1, sliceListView.currentIndex + step);
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
                    width: (sliceListView.width - appLauncher.expandedWidth) / 2
                    height: 1
                }

                footer: Item {
                    width: (sliceListView.width - appLauncher.expandedWidth) / 2
                    height: 1
                }

                // Parallelogram slice delegate
                delegate: Item {
                    id: delegateItem

                    property bool isCurrent: ListView.isCurrentItem
                    property bool isHovered: itemMouseArea.containsMouse
                    property real viewX: x - sliceListView.contentX
                    property real fadeZone: appLauncher.sliceWidth * 1.5
                    property real edgeOpacity: {
                        if (fadeZone <= 0)
                            return 1;

                        var center = viewX + width * 0.5;
                        var leftFade = Math.min(1, Math.max(0, center / fadeZone));
                        var rightFade = Math.min(1, Math.max(0, (sliceListView.width - center) / fadeZone));
                        return Math.min(leftFade, rightFade);
                    }

                    width: isCurrent ? appLauncher.expandedWidth : appLauncher.sliceWidth
                    height: sliceListView.height
                    z: isCurrent ? 100 : (isHovered ? 90 : 50 - Math.min(Math.abs(index - sliceListView.currentIndex), 50))
                    opacity: edgeOpacity

                    // Drop shadow canvas behind slice
                    Canvas {
                        id: shadowCanvas

                        property real shadowOffsetX: delegateItem.isCurrent ? 4 : 2
                        property real shadowOffsetY: delegateItem.isCurrent ? 10 : 5
                        property real shadowAlpha: delegateItem.isCurrent ? 0.6 : 0.4

                        z: -1
                        anchors.fill: parent
                        anchors.margins: -10
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onShadowAlphaChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var ox = 10;
                            var oy = 10;
                            var w = delegateItem.width;
                            var h = delegateItem.height;
                            var sk = appLauncher.skewOffset;
                            var sx = shadowOffsetX;
                            var sy = shadowOffsetY;
                            var layers = [{
                                "dx": sx,
                                "dy": sy,
                                "alpha": shadowAlpha * 0.5
                            }, {
                                "dx": sx * 0.6,
                                "dy": sy * 0.6,
                                "alpha": shadowAlpha * 0.3
                            }, {
                                "dx": sx * 1.4,
                                "dy": sy * 1.4,
                                "alpha": shadowAlpha * 0.2
                            }];
                            for (var i = 0; i < layers.length; i++) {
                                var l = layers[i];
                                ctx.globalAlpha = l.alpha;
                                ctx.fillStyle = "#000000";
                                ctx.beginPath();
                                ctx.moveTo(ox + sk + l.dx, oy + l.dy);
                                ctx.lineTo(ox + w + l.dx, oy + l.dy);
                                ctx.lineTo(ox + w - sk + l.dx, oy + h + l.dy);
                                ctx.lineTo(ox + l.dx, oy + h + l.dy);
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
                        layer.smooth: true
                        layer.samples: 4

                        Image {
                            id: bgImage

                            anchors.fill: parent
                            source: model.background ? "file://" + model.background : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            visible: status === Image.Ready
                            sourceSize.width: appLauncher.expandedWidth
                            sourceSize.height: appLauncher.sliceHeight
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
                            verticalAlignment: Image.AlignVCenter
                            smooth: true
                            asynchronous: true
                            sourceSize.width: appLauncher.expandedWidth
                            sourceSize.height: appLauncher.sliceHeight
                            visible: model.thumb !== "" && !bgImage.visible
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.4))

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }

                            }

                        }

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3

                            maskSource: ShaderEffectSource {

                                sourceItem: Item {
                                    width: imageContainer.width
                                    height: imageContainer.height
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.samples: 8

                                    Shape {
                                        anchors.fill: parent
                                        antialiasing: true
                                        preferredRendererType: Shape.CurveRenderer

                                        ShapePath {
                                            fillColor: "white"
                                            strokeColor: "transparent"
                                            startX: appLauncher.skewOffset
                                            startY: 0

                                            PathLine {
                                                x: delegateItem.width
                                                y: 0
                                            }

                                            PathLine {
                                                x: delegateItem.width - appLauncher.skewOffset
                                                y: delegateItem.height
                                            }

                                            PathLine {
                                                x: 0
                                                y: delegateItem.height
                                            }

                                            PathLine {
                                                x: appLauncher.skewOffset
                                                y: 0
                                            }

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
                            fillColor: "transparent"
                            strokeColor: delegateItem.isCurrent ? (Colors.primary) : (delegateItem.isHovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : Qt.rgba(0, 0, 0, 0.6))
                            strokeWidth: delegateItem.isCurrent ? 3 : 1
                            startX: appLauncher.skewOffset
                            startY: 0

                            PathLine {
                                x: delegateItem.width
                                y: 0
                            }

                            PathLine {
                                x: delegateItem.width - appLauncher.skewOffset
                                y: delegateItem.height
                            }

                            PathLine {
                                x: 0
                                y: delegateItem.height
                            }

                            PathLine {
                                x: appLauncher.skewOffset
                                y: 0
                            }

                            Behavior on strokeColor {
                                ColorAnimation {
                                    duration: 200
                                }

                            }

                        }

                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        width: 22
                        height: 22
                        radius: 11
                        color: model.source === "steam" ? (Colors.primary) : Qt.rgba(0, 0, 0, 0.7)
                        border.width: 1
                        border.color: model.source === "steam" ? "transparent" : (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6))
                        visible: model.source === "steam"
                        z: 10

                        Text {
                            anchors.centerIn: parent
                            text: "󰓓"
                            font.family: Style.fontFamilyIcons
                            font.pixelSize: 12
                            color: model.source === "steam" ? (Colors.primaryText) : (Colors.primary)
                        }

                    }

                    // App name label (visible when selected)
                    Rectangle {
                        id: nameLabel

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 40
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: nameText.width + 24
                        height: 32
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.75)
                        border.width: 1
                        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                        visible: delegateItem.isCurrent
                        opacity: delegateItem.isCurrent ? 1 : 0

                        Text {
                            id: nameText

                            anchors.centerIn: parent
                            text: (model.displayName || model.name).toUpperCase()
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                            color: Colors.tertiary
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, delegateItem.width - 60)
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }

                        }

                    }

                    // Category type badge (bottom-right)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: appLauncher.skewOffset + 8
                        width: typeBadgeText.width + 8
                        height: 16
                        radius: 4
                        color: Qt.rgba(0, 0, 0, 0.75)
                        border.width: 1
                        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)
                        z: 10

                        Text {
                            id: typeBadgeText

                            anchors.centerIn: parent
                            text: model.source === "steam" ? "STEAM" : model.categories.indexOf("Game") !== -1 ? "GAME" : model.categories.indexOf("Development") !== -1 ? "DEV" : model.categories.indexOf("Graphics") !== -1 ? "GFX" : (model.categories.indexOf("AudioVideo") !== -1 || model.categories.indexOf("Audio") !== -1 || model.categories.indexOf("Video") !== -1) ? "MEDIA" : model.categories.indexOf("Network") !== -1 ? "NET" : model.categories.indexOf("Office") !== -1 ? "OFFICE" : model.categories.indexOf("System") !== -1 ? "SYS" : model.categories.indexOf("Settings") !== -1 ? "CFG" : model.categories.indexOf("Utility") !== -1 ? "UTIL" : "APP"
                            font.family: Style.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
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
                            var globalPos = mapToItem(sliceListView, mouse.x, mouse.y);
                            var dx = Math.abs(globalPos.x - sliceListView.lastMouseX);
                            var dy = Math.abs(globalPos.y - sliceListView.lastMouseY);
                            if (dx > 2 || dy > 2) {
                                sliceListView.lastMouseX = globalPos.x;
                                sliceListView.lastMouseY = globalPos.y;
                                sliceListView.keyboardNavActive = false;
                                sliceListView.currentIndex = index;
                            }
                        }
                        onClicked: function(mouse) {
                            if (delegateItem.isCurrent) {
                                service.launchApp(model.exec, model.terminal, model.name);
                                appLauncher.showing = false;
                            } else {
                                sliceListView.currentIndex = index;
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
                            var w = delegateItem.width;
                            var h = delegateItem.height;
                            var sk = appLauncher.skewOffset;
                            if (h <= 0 || w <= 0)
                                return false;

                            var leftX = sk * (1 - point.y / h);
                            var rightX = w - sk * (point.y / h);
                            return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h;
                        }

                    }

                }

            }

            // Hex grid layout
            HexGrid {
                id: hexGrid

                function resetToStart() {
                    var startCol = Math.min(Math.floor(appLauncher.hexCols / 2), hexGrid.currentIndex);
                    if (startCol >= 0)
                        hexGrid.currentIndex = startCol;

                }

                service: appLauncher.service
                hexRadius: appLauncher.hexRadius
                hexRows: appLauncher.hexRows
                hexCols: appLauncher.hexCols
                topBarHeight: appLauncher.topBarHeight
                cardWidth: appLauncher.cardWidth
                cardVisible: appLauncher.cardVisible && appLauncher.isHexMode
                onEscapePressed: appLauncher.showing = false
                onAppLaunched: appLauncher.showing = false
                onSearchInputRequested: (text) => {
                    searchPanel.searchText += text;
                    searchPanel.searchInputItem.forceActiveFocus();
                }
                onBackspaceRequested: {
                    if (searchPanel.searchText.length > 0)
                        searchPanel.searchText = searchPanel.searchText.slice(0, -1);

                }
            }

        }

    }

    // One PanelWindow per screen — screen is fixed at Variants creation time,
    // never reassigned. isActive controls which one gets the full UI and keyboard focus.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: screenPanel

            property var modelData
            property bool isActive: modelData.name === appLauncher.activeMonitor

            screen: modelData
            visible: appLauncher._panelVisible
            color: "transparent"
            WlrLayershell.namespace: "app-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Dim overlay shown on all screens
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                opacity: appLauncher.cardVisible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }

                }

            }

            // Click anywhere on any screen to close
            MouseArea {
                anchors.fill: parent
                onClicked: appLauncher.showing = false
            }

            // Full launcher UI — only instantiated on the active screen
            Loader {
                anchors.fill: parent
                active: isActive
                sourceComponent: launcherUIComponent
            }

        }

    }

}
