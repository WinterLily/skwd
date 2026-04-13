import ".."
import "../services"
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Full-screen hex app launcher
Scope {
    id: appLauncher

    // External bindings
    property bool showing: false
    property string activeMonitor: Quickshell.screens[0]?.name ?? ""
    property bool _panelVisible: false
    // Expose service through appLauncher so it's reachable inside Component+Loader contexts
    property alias launcherService: service
    // Hex geometry
    property int hexRadius: Config.launcherHexRadius
    property int hexRows: Config.launcherHexRows
    property int hexCols: Config.launcherHexCols
    property int hexScrollStep: Config.launcherHexScrollStep
    property bool hexArc: Config.launcherHexArc
    property real hexArcIntensity: Config.launcherHexArcIntensity
    property int topBarHeight: 50
    property int cardWidth: {
        var r = hexRadius;
        var spacing = 14;
        return Math.round((hexCols + 1) * (1.5 * r + spacing) + 2 * r);
    }
    property int cardHeight: {
        var r = hexRadius;
        var rows = hexRows;
        var spacing = 14;
        var hexH = Math.ceil(r * 1.73205);
        var stepY = hexH + spacing;
        return (rows - 1) * stepY + hexH + Math.ceil(stepY / 2) + topBarHeight + 60;
    }
    property bool cardVisible: false

    function updateActiveMonitor() {
        var activeOutput = CompositorService.getActiveOutput();
        if (activeOutput && activeOutput !== "?")
            appLauncher.activeMonitor = activeOutput;

        var screens = Quickshell.screens;
        var matched = false;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === appLauncher.activeMonitor) {
                matched = true;
                break;
            }
        }
        if (!matched && screens.length > 0) {
            console.warn("AppLauncher: activeMonitor '" + appLauncher.activeMonitor + "' not found — falling back to '" + screens[0].name + "'");
            appLauncher.activeMonitor = screens[0].name;
        }
        appLauncher._panelVisible = true;
        cardShowTimer.restart();
    }

    onShowingChanged: {
        if (showing) {
            _panelVisible = false;
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
        terminal: Quickshell.env("TERMINAL") || "kitty"
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

            Connections {
                function onSearchTextChanged() {
                    if (searchPanel.searchText !== appLauncher.launcherService.searchText)
                        searchPanel.searchText = appLauncher.launcherService.searchText;

                }

                function onModelUpdated() {
                    hexGrid.resetToStart();
                }

                target: appLauncher.launcherService
            }

            Timer {
                id: focusTimer

                interval: 50
                onTriggered: hexGrid.forceActiveFocus()
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
                            service: appLauncher.launcherService
                        }

                    }

                    // Cache loading overlay with progress bar
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.95)
                        radius: 20
                        visible: appLauncher.launcherService.cacheLoading
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
                                width: appLauncher.launcherService.cacheTotal > 0 ? parent.width * (appLauncher.launcherService.cacheProgress / appLauncher.launcherService.cacheTotal) : 0
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
                            text: appLauncher.launcherService.cacheTotal > 0 ? "LOADING APPS... " + appLauncher.launcherService.cacheProgress + " / " + appLauncher.launcherService.cacheTotal : "SCANNING..."
                            color: Colors.tertiary
                            font.family: Style.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.letterSpacing: 0.5
                        }

                    }

                }

            }

            // Hex grid layout
            HexGrid {
                id: hexGrid

                function resetToStart() {
                    var colCount = Math.ceil(hexGrid._hexItems.length / Math.max(1, hexGrid.hexRows));
                    var startCol = Math.min(Math.floor(appLauncher.hexCols / 2), Math.max(0, colCount - 1));
                    hexGrid.currentIndex = startCol;
                }

                anchors.fill: parent
                service: appLauncher.launcherService
                hexRadius: appLauncher.hexRadius
                hexRows: appLauncher.hexRows
                hexCols: appLauncher.hexCols
                scrollStep: appLauncher.hexScrollStep
                arcEnabled: appLauncher.hexArc
                arcIntensity: appLauncher.hexArcIntensity
                topBarHeight: appLauncher.topBarHeight
                cardWidth: appLauncher.cardWidth
                cardVisible: appLauncher.cardVisible
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

    // One PanelWindow per screen — screen is fixed at Variants creation time.
    // isActive controls which one gets the full UI and keyboard focus.
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
