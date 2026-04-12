import ".."
import "../.."
import "../services"
import "../../services"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Top-level orchestrator.
// Owns all shared state, services, and the PanelWindow shell.
// The three display modes live in WallpaperSliceView, WallpaperHexView, and
// WallpaperGridView; each is responsible for its own view and any overlays
// that belong to it.
Scope {
    // ── private helpers ───────────────────────────────────────────────────────
    // sliceView exposes positionAt(); index 0 will be handled on next model update
    // ── lifecycle ─────────────────────────────────────────────────────────────
    // ── services ──────────────────────────────────────────────────────────────
    // ── timers ────────────────────────────────────────────────────────────────
    // ── panel window ──────────────────────────────────────────────────────────
    // ── animated layout property behaviors ───────────────────────────────────

    id: wallpaperSelector

    // ── public API ────────────────────────────────────────────────────────────
    property bool showing: false
    property alias selectedColorFilter: service.selectedColorFilter
    property alias selectorService: service
    property alias swService: swService
    // ── monitor tracking ──────────────────────────────────────────────────────
    property string mainMonitor: Config.mainMonitor
    property string activeMonitor: mainMonitor
    property bool _panelVisible: false
    // ── layout dimensions (all animate via Behaviors at bottom) ───────────────
    property int sliceWidth: Config.wallpaperSliceWidth
    property int expandedWidth: Config.wallpaperExpandedWidth
    property int sliceHeight: Config.wallpaperSliceHeight
    property int skewOffset: Config.wallpaperSkewOffset
    property int sliceSpacing: Config.wallpaperSliceSpacing
    property int topBarHeight: 50
    property int hexRadius: Config.hexRadius
    property int hexRows: Config.hexRows
    property int hexCols: Config.hexCols
    property real _gridCellW: Config.gridThumbWidth + 8
    property real _gridCellH: Config.gridThumbHeight + 8
    property real _gridTotalW: _gridCellW * Config.gridColumns
    property int _gridTotalH: _gridCellH * Config.gridRows
    // ── display mode flags ────────────────────────────────────────────────────
    property bool isHexMode: Config.displayMode === "hex"
    property bool isGridMode: Config.displayMode === "wall"
    // ── card geometry ─────────────────────────────────────────────────────────
    property bool anyBrowserOpen: wallhavenBrowserOpen || steamWorkshopBrowserOpen
    property int cardHeight: anyBrowserOpen ? 0 : (isHexMode ? hexGridHeight : (isGridMode ? _gridTotalH + topBarHeight + 35 : sliceHeight + topBarHeight + 60))
    property int hexCardWidth: {
        var r = hexRadius;
        var spacing = 14;
        var stepX = 1.5 * r + spacing;
        var cellW = 2 * r;
        return Math.round((hexCols + 1) * stepX + cellW);
    }
    property int _sliceListW: Config.wallpaperExpandedWidth + (Config.wallpaperVisibleCount - 1) * (Config.wallpaperSliceWidth + Config.wallpaperSliceSpacing)
    property int cardWidth: isHexMode ? hexCardWidth : (isGridMode ? _gridTotalW + 20 : Math.max(_sliceListW + 40, 600))
    property int hexGridHeight: {
        var rows = hexRows;
        var r = hexRadius;
        var spacing = 14;
        var hexH = Math.ceil(r * 1.73205);
        var stepY = hexH + spacing;
        var contentH = (rows - 1) * stepY + hexH + stepY / 2;
        return contentH + topBarHeight + 60;
    }
    // ── UI state ──────────────────────────────────────────────────────────────
    property bool wallhavenBrowserOpen: false
    property bool steamWorkshopBrowserOpen: false
    property bool settingsOpen: false
    property bool cardVisible: false
    property real _settingsShift: {
        if (!settingsOpen)
            return 0;

        var base = settingsPanelItem.height - 4;
        var naturalCardY = (selectorPanel.height - cardHeight) / 2;
        var settingsY = naturalCardY + base / 2 + filterBarBg.y - settingsPanelItem.height - 8;
        if (settingsY < 8) {
            var extra = 2 * (8 - settingsY);
            return base + extra;
        }
        return base;
    }
    // Scroll restore state
    property real lastContentX: 0
    property int lastIndex: 0
    property bool _restorePending: false
    property int _preCommitIndex: -1

    // ── signals ───────────────────────────────────────────────────────────────
    signal wallpaperChanged
    signal uiReady

    // Get active monitor via CompositorService
    function updateActiveMonitor() {
        // Get active output from CompositorService
        var activeOutput = CompositorService.getActiveOutput();
        if (activeOutput && activeOutput !== "?")
            wallpaperSelector.activeMonitor = activeOutput;

        // Verify activeMonitor resolves to a real screen; fall back to first screen
        var screens = Quickshell.screens;
        var matched = false;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === wallpaperSelector.activeMonitor) {
                matched = true;
                break;
            }
        }
        if (!matched && screens.length > 0)
            wallpaperSelector.activeMonitor = screens[0].name;

        wallpaperSelector._panelVisible = true;
        cardShowTimer.restart();
    }

    function resetScroll() {
        lastContentX = 0;
        lastIndex = 0;
    }

    function _focusActiveList() {
        hexView.focusList();
    }

    onShowingChanged: {
        if (showing) {
            _panelVisible = false;
            activeMonitor = mainMonitor;
            updateActiveMonitor();
            _restorePending = true;
            service.startCacheCheck();
        } else {
            _panelVisible = false;
            cardShowTimer.stop();
            cardVisible = false;
            settingsOpen = false;
            gc();
        }
    }

    WallhavenService {
        id: whService

        wallpaperDir: Config.wallpaperDir
        apiKey: Config.wallhavenApiKey
    }

    SteamWorkshopService {
        id: swService

        weDir: Config.weDir
        apiKey: Config.steamApiKey
    }

    WallpaperSelectorService {
        id: service

        scriptsDir: Config.wallScriptsDir
        homeDir: Config.homeDir
        wallpaperDir: Config.wallpaperDir
        videoDir: Config.videoDir
        cacheBaseDir: Config.wallCacheDir
        weDir: Config.weDir
        weAssetsDir: Config.weAssetsDir
        showing: wallpaperSelector.showing
        onModelUpdated: {
            if (wallpaperSelector.showing && !wallpaperSelector.cardVisible) {
                wallpaperSelector.cardVisible = true;
            }
            if (service.filteredModel.count > 0) {
                var idx = 0;
                if (wallpaperSelector._restorePending) {
                    wallpaperSelector._restorePending = false;
                    idx = Math.min(wallpaperSelector.lastIndex, service.filteredModel.count - 1);
                } else if (wallpaperSelector.showing && wallpaperSelector._preCommitIndex >= 0) {
                    idx = Math.min(wallpaperSelector._preCommitIndex, service.filteredModel.count - 1);
                }
                wallpaperSelector._preCommitIndex = -1;
            }
        }
        onWallpaperApplied: wallpaperSelector.wallpaperChanged()
    }

    Connections {
        function onRequestFilterUpdate() {
            // Fast path: no crossfade (hex/grid/browser modes, empty model, or flag)
            if (service._skipCrossfade || service.filteredModel.count === 0 || !wallpaperSelector.cardVisible || wallpaperSelector.anyBrowserOpen || wallpaperSelector.isHexMode || wallpaperSelector.isGridMode) {
                service._skipCrossfade = false;
                service.filterTransitioning = false;
                service.commitFilteredModel();
                return;
            }
            // Slow path: crossfade snapshot in slice view
            service.filterTransitioning = true;
        }

        target: service
    }

    Timer {
        id: cardShowTimer

        interval: 4000
        onTriggered: wallpaperSelector.cardVisible = true
    }

    Timer {
        id: focusTimer

        interval: 50
        onTriggered: wallpaperSelector._focusActiveList()
    }

    PanelWindow {
        // ── display mode views ────────────────────────────────────────────────

        id: selectorPanel

        screen: Quickshell.screens.find(s => {
            return s.name === wallpaperSelector.activeMonitor;
        }) ?? Quickshell.screens[0]
        visible: wallpaperSelector._panelVisible
        color: "transparent"
        WlrLayershell.namespace: "wallpaper-selector-parallel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: wallpaperSelector.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        margins {
            top: 0
            bottom: 0
            left: 0
            right: 0
        }

        // Dim background
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: wallpaperSelector.cardVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animMedium
                }
            }
        }

        // Click outside to dismiss / close browsers
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                if (wallpaperSelector.anyBrowserOpen) {
                    wallpaperSelector.wallhavenBrowserOpen = false;
                    wallpaperSelector.steamWorkshopBrowserOpen = false;
                } else {
                    wallpaperSelector.showing = false;
                }
            }
        }

        // Card container (filter bar + cache progress indicator)
        Item {
            id: cardContainer

            property bool animateIn: wallpaperSelector.cardVisible

            width: wallpaperSelector.cardWidth
            height: wallpaperSelector.cardHeight
            anchors.centerIn: parent
            anchors.verticalCenterOffset: wallpaperSelector._settingsShift / 2
            visible: wallpaperSelector.cardVisible
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
                duration: Style.animSlow
                easing.type: Easing.OutCubic
                onFinished: wallpaperSelector.uiReady()
            }

            // Absorb clicks inside the card so they don't dismiss
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Item {
                anchors.fill: parent

                FilterBar {
                    id: filterBarBg

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 30
                    maxWidth: parent.width - 20
                    z: 10
                    service: service
                    settingsOpen: wallpaperSelector.settingsOpen
                    cacheLoading: service.cacheLoading
                    cacheProgress: service.cacheProgress
                    cacheTotal: service.cacheTotal
                    matugenRunning: MatugenCacheService.running
                    matugenProgress: MatugenCacheService.progress
                    matugenTotal: MatugenCacheService.total
                    videoConvertRunning: VideoConvertService.running
                    videoConvertProgress: VideoConvertService.progress
                    videoConvertTotal: VideoConvertService.total
                    videoConvertFile: VideoConvertService.currentFile
                    imageOptimizeRunning: ImageOptimizeService.running
                    imageOptimizeProgress: ImageOptimizeService.progress
                    imageOptimizeTotal: ImageOptimizeService.total
                    imageOptimizeFile: ImageOptimizeService.currentFile
                    wallhavenBrowserOpen: wallpaperSelector.wallhavenBrowserOpen
                    steamWorkshopBrowserOpen: wallpaperSelector.steamWorkshopBrowserOpen
                    visible: !wallpaperSelector.anyBrowserOpen
                    opacity: wallpaperSelector.anyBrowserOpen ? 0 : 1
                    onSettingsToggled: {
                        wallpaperSelector.settingsOpen = !wallpaperSelector.settingsOpen;
                        if (!wallpaperSelector.settingsOpen)
                            wallpaperSelector._focusActiveList();
                    }
                    onWallhavenToggled: {
                        wallpaperSelector.settingsOpen = false;
                        wallpaperSelector.steamWorkshopBrowserOpen = false;
                        wallpaperSelector.wallhavenBrowserOpen = !wallpaperSelector.wallhavenBrowserOpen;
                    }
                    onSteamWorkshopToggled: {
                        wallpaperSelector.settingsOpen = false;
                        wallpaperSelector.wallhavenBrowserOpen = false;
                        wallpaperSelector.steamWorkshopBrowserOpen = !wallpaperSelector.steamWorkshopBrowserOpen;
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.animNormal
                        }
                    }
                }
            }

            CacheProgressBar {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 30
                cacheLoading: service.cacheLoading
                cacheProgress: service.cacheProgress
                cacheTotal: service.cacheTotal
            }
        }

        SettingsPanel {
            id: settingsPanelItem

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(8, cardContainer.y + filterBarBg.y - height - 8)
            z: 999
            service: service
            settingsOpen: wallpaperSelector.settingsOpen
            onCloseRequested: {
                wallpaperSelector.settingsOpen = false;
                wallpaperSelector._focusActiveList();
            }
        }

        WallhavenBrowser {
            anchors.centerIn: parent
            width: cardContainer.width - 20
            z: 6
            whService: whService
            browserVisible: wallpaperSelector.wallhavenBrowserOpen
            onEscapePressed: {
                wallpaperSelector.wallhavenBrowserOpen = false;
                wallpaperSelector._focusActiveList();
            }
        }

        SteamWorkshopBrowser {
            anchors.centerIn: parent
            width: cardContainer.width - 20
            z: 6
            swService: swService
            browserVisible: wallpaperSelector.steamWorkshopBrowserOpen
            onEscapePressed: {
                wallpaperSelector.steamWorkshopBrowserOpen = false;
                wallpaperSelector._focusActiveList();
            }
        }

        WallpaperHexView {
            id: hexView

            service: service
            containerItem: cardContainer
            hexRadius: wallpaperSelector.hexRadius
            hexRows: wallpaperSelector.hexRows
            hexCols: wallpaperSelector.hexCols
            topBarHeight: wallpaperSelector.topBarHeight
            cardVisible: wallpaperSelector.cardVisible
            anyBrowserOpen: wallpaperSelector.anyBrowserOpen
            isHexMode: wallpaperSelector.isHexMode
            showing: wallpaperSelector.showing
            onEscapePressed: wallpaperSelector.showing = false
            onFocusRequested: wallpaperSelector._focusActiveList()
        }
    }

    Behavior on sliceWidth {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on expandedWidth {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on sliceHeight {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on skewOffset {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on sliceSpacing {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on hexRadius {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on hexRows {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on hexCols {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on _gridCellW {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on _gridCellH {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }

    Behavior on _gridTotalW {
        NumberAnimation {
            duration: Style.animExpand
            easing.type: Easing.OutCubic
        }
    }
}
