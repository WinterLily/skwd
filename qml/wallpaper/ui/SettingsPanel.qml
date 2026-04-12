import ".."
import "../.."
import "../services"
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Io

Item {
    id: settingsPanel

    property var service
    property bool settingsOpen: false
    property string activeTab: "performance"
    property bool openDownward: false
    property string _lastConvertResult: ""
    property string _lastOptimizeResult: ""
    property int _tabSkew: 14

    signal closeRequested

    function _readConfig() {
        _selectorConfigFile.reload();
        try {
            return JSON.parse(_selectorConfigFile.text());
        } catch (e) {
            return {};
        }
    }

    function _cloneIntegrations() {
        return Config.integrations.map(function (e) {
            return JSON.parse(JSON.stringify(e));
        });
    }

    function _saveField(key, value) {
        var data = _readConfig();
        if (!data.components)
            data.components = {};

        if (typeof data.components.wallpaperSelector !== "object" || data.components.wallpaperSelector === null)
            data.components.wallpaperSelector = {
                "enabled": true
            };

        data.components.wallpaperSelector[key] = value;
        _selectorConfigFile.setText(JSON.stringify(data, null, 2) + "\n");
    }

    function _saveConfigKey(path, value) {
        var data = _readConfig();
        var parts = path.split(".");
        var obj = data;
        for (var i = 0; i < parts.length - 1; i++) {
            if (typeof obj[parts[i]] !== "object" || obj[parts[i]] === null)
                obj[parts[i]] = {};

            obj = obj[parts[i]];
        }
        obj[parts[parts.length - 1]] = value;
        _selectorConfigFile.setText(JSON.stringify(data, null, 2) + "\n");
    }

    function _applyPreset(expanded, sliceH, sliceW, visible, gap, skew) {
        var data = _readConfig();
        if (!data.components)
            data.components = {};

        if (typeof data.components.wallpaperSelector !== "object" || data.components.wallpaperSelector === null)
            data.components.wallpaperSelector = {
                "enabled": true
            };

        data.components.wallpaperSelector.expandedWidth = expanded;
        data.components.wallpaperSelector.visibleCount = visible;
        data.components.wallpaperSelector.skewOffset = skew;
        _selectorConfigFile.setText(JSON.stringify(data, null, 2) + "\n");
    }

    function _saveCustomPreset(slot) {
        var data = _readConfig();
        if (!data.components)
            data.components = {};

        if (typeof data.components.wallpaperSelector !== "object" || data.components.wallpaperSelector === null)
            data.components.wallpaperSelector = {
                "enabled": true
            };

        if (!data.components.wallpaperSelector.customPresets)
            data.components.wallpaperSelector.customPresets = {};

        var key = slot + "_" + Config.displayMode;
        var preset = {};
        if (Config.displayMode === "hex")
            preset = {
                "hexRadius": Config.hexRadius,
                "hexRows": Config.hexRows,
                "hexCols": Config.hexCols,
                "hexScrollStep": Config.hexScrollStep,
                "hexArc": Config.hexArc,
                "hexArcIntensity": Config.hexArcIntensity
            };
        data.components.wallpaperSelector.customPresets[key] = preset;
        _selectorConfigFile.setText(JSON.stringify(data, null, 2) + "\n");
    }

    function _loadCustomPreset(slot) {
        var key = slot + "_" + Config.displayMode;
        var p = Config.wallpaperCustomPresets[key];
        if (!p)
            return;
    }

    z: 102
    width: 580
    height: tabRow.height + contentLoader.height + 36
    visible: settingsOpen
    opacity: settingsOpen ? 1 : 0
    scale: settingsOpen ? 1 : 0.9
    transformOrigin: openDownward ? Item.Top : Item.Bottom
    Keys.onEscapePressed: closeRequested()
    focus: settingsOpen

    Connections {
        function onMatugenEnabledChanged() {
            if (!Config.matugenEnabled && settingsPanel.activeTab === "matugen")
                settingsPanel.activeTab = "performance";
        }

        function onSteamEnabledChanged() {
            if (!Config.steamEnabled && settingsPanel.activeTab === "steam")
                settingsPanel.activeTab = "performance";
        }

        function onWallhavenEnabledChanged() {
            if (!Config.wallhavenEnabled && settingsPanel.activeTab === "wallhaven")
                settingsPanel.activeTab = "performance";
        }

        target: Config
    }

    Connections {
        function onFinished(optimized, skippedCount, failed) {
            var parts = [];
            if (optimized > 0)
                parts.push(optimized + " optimized");

            if (skippedCount > 0)
                parts.push(skippedCount + " skipped");

            if (failed > 0)
                parts.push(failed + " failed");

            settingsPanel._lastOptimizeResult = parts.join(" · ") || "Nothing to optimize";
        }

        target: ImageOptimizeService
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                settingsPanel.closeRequested();
        }
    }

    FileView {
        id: _selectorConfigFile

        path: Config.configDir + "/data/config.json"
        preload: true
    }

    Row {
        id: tabRow

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        spacing: -settingsPanel._tabSkew
        z: 11

        Repeater {
            model: {
                var tabs = [
                    {
                        "key": "performance",
                        "label": "PERFORMANCE"
                    },
                    {
                        "key": "keybinds",
                        "label": "KEYBINDS"
                    }
                ];
                if (Config.wallhavenEnabled)
                    tabs.push({
                        "key": "wallhaven",
                        "label": "WALLHAVEN"
                    });

                if (Config.steamEnabled)
                    tabs.push({
                        "key": "steam",
                        "label": "STEAM"
                    });

                if (Config.matugenEnabled)
                    tabs.push({
                        "key": "matugen",
                        "label": "MATUGEN"
                    });

                return tabs;
            }

            FilterButton {
                label: modelData.label
                skew: settingsPanel._tabSkew
                height: 28
                isActive: settingsPanel.activeTab === modelData.key
                onClicked: settingsPanel.activeTab = modelData.key
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Style.animNormal
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"
                from: 0.8
                to: 1
                duration: Style.animNormal
                easing.type: Easing.OutCubic
            }
        }

        move: Transition {
            NumberAnimation {
                properties: "x"
                duration: Style.animNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: contentLoader

        anchors.top: tabRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        anchors.topMargin: 8
        height: {
            if (settingsPanel.activeTab === "wallhaven")
                return wallhavenContent.implicitHeight;

            if (settingsPanel.activeTab === "steam")
                return steamContent.implicitHeight;

            if (settingsPanel.activeTab === "performance")
                return performanceContent.implicitHeight;

            if (settingsPanel.activeTab === "matugen")
                return Math.min(_matugenInner.implicitHeight, 360);

            if (settingsPanel.activeTab === "keybinds")
                return keybindsContent.implicitHeight;

            return 0;
        }

        Row {
            id: wallhavenContent

            anchors.left: parent.left
            anchors.right: parent.right
            visible: settingsPanel.activeTab === "wallhaven"
            spacing: 12

            Column {
                width: (parent.width - parent.spacing * 2 - 1) * 0.5
                spacing: 6

                Text {
                    text: "GRID"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                SettingsInput {
                    label: "Columns"
                    value: Config.wallhavenColumns
                    min: 2
                    max: 12
                    onCommit: function (n) {
                        settingsPanel._saveField("wallhavenColumns", n);
                    }
                }

                SettingsInput {
                    label: "Rows"
                    value: Config.wallhavenRows
                    min: 1
                    max: 10
                    onCommit: function (n) {
                        settingsPanel._saveField("wallhavenRows", n);
                    }
                }

                Text {
                    text: "THUMBNAIL"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                    topPadding: 8
                }

                SettingsInput {
                    label: "Width"
                    value: Config.wallhavenThumbWidth
                    min: 100
                    max: 600
                    onCommit: function (n) {
                        settingsPanel._saveField("wallhavenThumbWidth", n);
                    }
                }

                SettingsInput {
                    label: "Height"
                    value: Config.wallhavenThumbHeight
                    min: 60
                    max: 600
                    onCommit: function (n) {
                        settingsPanel._saveField("wallhavenThumbHeight", n);
                    }
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Column {
                width: (parent.width - parent.spacing * 2 - 1) * 0.5
                spacing: 6

                Text {
                    text: "API"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                SettingsTextInput {
                    label: "API key"
                    value: Config.wallhavenApiKey
                    placeholder: "Wallhaven API key (for NSFW)"
                    onCommit: function (v) {
                        settingsPanel._saveConfigKey("wallhaven.apiKey", v);
                    }
                }
            }
        }

        Row {
            id: steamContent

            anchors.left: parent.left
            anchors.right: parent.right
            visible: settingsPanel.activeTab === "steam"
            spacing: 12

            Column {
                width: (parent.width - parent.spacing * 2 - 1) * 0.5
                spacing: 6

                Text {
                    text: "GRID"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                SettingsInput {
                    label: "Columns"
                    value: Config.steamColumns
                    min: 2
                    max: 12
                    onCommit: function (n) {
                        settingsPanel._saveField("steamColumns", n);
                    }
                }

                SettingsInput {
                    label: "Rows"
                    value: Config.steamRows
                    min: 1
                    max: 10
                    onCommit: function (n) {
                        settingsPanel._saveField("steamRows", n);
                    }
                }

                Text {
                    text: "THUMBNAIL"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                    topPadding: 8
                }

                SettingsInput {
                    label: "Width"
                    value: Config.steamThumbWidth
                    min: 100
                    max: 600
                    onCommit: function (n) {
                        settingsPanel._saveField("steamThumbWidth", n);
                    }
                }

                SettingsInput {
                    label: "Height"
                    value: Config.steamThumbHeight
                    min: 60
                    max: 600
                    onCommit: function (n) {
                        settingsPanel._saveField("steamThumbHeight", n);
                    }
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Column {
                width: (parent.width - parent.spacing * 2 - 1) * 0.5
                spacing: 6

                Text {
                    text: "API"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                SettingsTextInput {
                    label: "API key"
                    value: Config.steamApiKey
                    placeholder: "Steam API key"
                    onCommit: function (v) {
                        settingsPanel._saveConfigKey("steam.apiKey", v);
                    }
                }

                SettingsTextInput {
                    label: "Username"
                    value: Config.steamUsername
                    placeholder: "Steam username (for steamcmd)"
                    onCommit: function (v) {
                        settingsPanel._saveConfigKey("steam.username", v);
                    }
                }
            }
        }

        Row {
            id: performanceContent

            anchors.left: parent.left
            anchors.right: parent.right
            visible: settingsPanel.activeTab === "performance"
            spacing: 12

            Column {
                width: (parent.width - parent.spacing * 4 - 2) / 3
                spacing: 6

                Text {
                    text: "IMAGE OPTIMIZATION"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Text {
                    width: parent.width
                    text: "Converts PNG, JPEG, and GIF images to WebP format. Smaller file sizes with no visible quality loss. Steam Workshop assets are never modified."
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 0.2
                    color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                SettingsToggle {
                    label: "Auto-optimize new images"
                    checked: Config.autoOptimizeImages
                    onToggle: function (v) {
                        settingsPanel._saveConfigKey("performance.autoOptimizeImages", v);
                    }
                }

                SettingsCombo {
                    label: "Quality"
                    model: ["light", "balanced", "quality"]
                    value: Config.imageOptimizePreset
                    onSelect: function (v) {
                        settingsPanel._saveConfigKey("performance.imageOptimizePreset", v);
                    }
                }

                Repeater {
                    model: [
                        {
                            "key": "light",
                            "desc": "Q 82 · max compression"
                        },
                        {
                            "key": "balanced",
                            "desc": "Q 88 · good trade-off"
                        },
                        {
                            "key": "quality",
                            "desc": "Q 94 · visually lossless"
                        }
                    ]

                    Text {
                        text: (Config.imageOptimizePreset === modelData.key ? "▸ " : "  ") + modelData.key.toUpperCase() + ":  " + modelData.desc
                        font.family: Style.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 0.2
                        color: Config.imageOptimizePreset === modelData.key ? (Colors.primary) : (Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.7))
                    }
                }

                SettingsCombo {
                    label: "Max resolution"
                    model: ["1080p", "2k", "4k"]
                    value: Config.imageOptimizeResolution
                    onSelect: function (v) {
                        settingsPanel._saveConfigKey("performance.imageOptimizeResolution", v);
                    }
                }

                Text {
                    width: parent.width
                    text: "Images above the cap are downscaled. Smaller images are never upscaled."
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 0.2
                    color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Item {
                    width: 1
                    height: 2
                }

                Row {
                    spacing: 8

                    FilterButton {
                        label: ImageOptimizeService.running ? "CANCEL" : "OPTIMIZE ALL"
                        skew: 8
                        height: 28
                        isActive: ImageOptimizeService.running
                        onClicked: {
                            if (ImageOptimizeService.running)
                                ImageOptimizeService.cancel();
                            else
                                _optimizeConfirmPopup.open();
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !ImageOptimizeService.running && settingsPanel._lastOptimizeResult !== ""
                        text: settingsPanel._lastOptimizeResult
                        font.family: Style.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 0.2
                        color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                    }
                }
            }

            Rectangle {
                width: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.1)
            }

            Item {
                width: (parent.width - parent.spacing * 4 - 2) / 3
                height: _videoOptCol.implicitHeight

                Column {
                    id: _videoOptCol

                    width: parent.width
                    spacing: 6
                    opacity: 0.35
                    enabled: false

                    Text {
                        text: "VIDEO OPTIMIZATION  ·  WIP"
                        font.family: Style.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                        color: Colors.tertiary
                    }

                    Text {
                        width: parent.width
                        text: "Re-encodes video wallpapers to HEVC (H.265) for significantly smaller sizes. This feature is currently under development."
                        font.family: Style.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 0.2
                        color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }

                    SettingsToggle {
                        label: "Auto-convert new videos"
                        checked: false
                    }

                    SettingsCombo {
                        label: "Quality"
                        model: ["light", "balanced", "quality"]
                        value: Config.videoConvertPreset
                    }

                    Repeater {
                        model: [
                            {
                                "key": "light",
                                "desc": "CRF 28 · 6 Mbps"
                            },
                            {
                                "key": "balanced",
                                "desc": "CRF 26 · 10 Mbps"
                            },
                            {
                                "key": "quality",
                                "desc": "CRF 23 · 16 Mbps"
                            }
                        ]

                        Text {
                            text: (Config.videoConvertPreset === modelData.key ? "▸ " : "  ") + modelData.key.toUpperCase() + ":  " + modelData.desc
                            font.family: Style.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 0.2
                            color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.7)
                        }
                    }

                    SettingsCombo {
                        label: "Max resolution"
                        model: ["1080p", "2k", "4k"]
                        value: Config.videoConvertResolution
                    }

                    Item {
                        width: 1
                        height: 2
                    }

                    Row {
                        spacing: 8

                        FilterButton {
                            label: "OPTIMIZE ALL"
                            skew: 8
                            height: 28
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.1)
            }

            Column {
                width: (parent.width - parent.spacing * 4 - 2) / 3
                spacing: 6

                Text {
                    text: "VIDEO PREVIEWS"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Text {
                    width: parent.width
                    text: "Play animated thumbnails when hovering over video wallpapers."
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 0.2
                    color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                SettingsToggle {
                    label: "Video previews"
                    checked: Config.videoPreviewEnabled
                    onToggle: function (v) {
                        settingsPanel._saveConfigKey("features.videoPreview", v);
                    }
                }

                Item {
                    width: 1
                    height: 8
                }

                Text {
                    text: "TRASH"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Text {
                    width: parent.width
                    text: "Originals are moved to trash before optimization, so you can recover them if needed."
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 0.2
                    color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Item {
                    width: 1
                    height: 2
                }

                Text {
                    text: "IMAGES"
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: Colors.tertiary
                }

                SettingsInput {
                    label: "Retention (days)"
                    value: Config.imageTrashDays
                    min: 1
                    max: 365
                    onCommit: function (v) {
                        settingsPanel._saveConfigKey("performance.imageTrashDays", v);
                    }
                }

                SettingsToggle {
                    label: "Auto-delete after retention"
                    checked: Config.autoDeleteImageTrash
                    onToggle: function (v) {
                        settingsPanel._saveConfigKey("performance.autoDeleteImageTrash", v);
                    }
                }

                Item {
                    width: 1
                    height: 8
                }

                Text {
                    text: "CACHE"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Text {
                    width: parent.width
                    text: "Clear all cached thumbnails and regenerate from scratch."
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 0.2
                    color: Qt.rgba(Colors.surfaceVariantText.r, Colors.surfaceVariantText.g, Colors.surfaceVariantText.b, 0.8)
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Item {
                    width: 1
                    height: 2
                }

                Row {
                    spacing: 8

                    FilterButton {
                        label: WallpaperCacheService.running ? "RESCANNING..." : "FORCE FULL RESCAN"
                        skew: 8
                        height: 28
                        enabled: !WallpaperCacheService.running
                        onClicked: settingsPanel.service.forceRescan()
                    }
                }

                Item {
                    width: 1
                    height: 4
                }

                Item {
                    width: parent.width
                    height: _videoTrashCol.implicitHeight
                    opacity: 0.35
                    enabled: false

                    Column {
                        id: _videoTrashCol

                        width: parent.width
                        spacing: 6

                        Text {
                            text: "VIDEOS  ·  WIP"
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: Colors.tertiary
                        }

                        SettingsInput {
                            label: "Retention (days)"
                            value: Config.videoTrashDays
                            min: 1
                            max: 365
                        }

                        SettingsToggle {
                            label: "Auto-delete after retention"
                            checked: false
                        }
                    }
                }
            }
        }

        Flickable {
            id: matugenContent

            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height
            visible: settingsPanel.activeTab === "matugen"
            contentHeight: _matugenInner.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: _matugenInner

                width: parent.width
                spacing: 8

                Text {
                    text: "EXTERNAL MATUGEN CONFIG"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: Colors.tertiary
                }

                Text {
                    width: parent.width
                    text: "Path to an external matugen config file such as the one from your existing setup. This runs alongside Skwd-wall's internal Matugen configuration."
                    font.family: Style.fontFamily
                    font.pixelSize: 10
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    width: parent.width
                    height: 26
                    radius: 4
                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                    border.width: _defaultCfgInput.activeFocus ? 1 : 0
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

                    TextInput {
                        id: _defaultCfgInput

                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Style.fontFamilyCode
                        font.pixelSize: 11
                        color: Colors.tertiary
                        clip: true
                        selectByMouse: true
                        text: Config.defaultMatugenConfig
                        onEditingFinished: settingsPanel._saveConfigKey("defaultMatugenConfig", text)
                    }
                }

                Text {
                    text: "INTEGRATIONS"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Text {
                    width: parent.width
                    text: "Matugen colour-theming integrations. Each entry generates themed output from a template and optionally runs a reload command."
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: Config.integrations

                    Rectangle {
                        width: _matugenInner.width
                        height: _integRow.implicitHeight + 12
                        radius: 4
                        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.4)

                        Row {
                            id: _integRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Column {
                                width: (parent.width - _integRemoveBtn.width - parent.spacing * 2) * 0.2
                                spacing: 2

                                Text {
                                    text: "name"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 9
                                    color: Colors.tertiary
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 22
                                    radius: 3
                                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                                    border.width: _nameIn.activeFocus ? 1 : 0
                                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

                                    TextInput {
                                        id: _nameIn

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Style.fontFamilyCode
                                        font.pixelSize: 10
                                        color: Colors.surfaceText
                                        clip: true
                                        selectByMouse: true
                                        text: modelData.name || ""
                                        onEditingFinished: {
                                            var a = settingsPanel._cloneIntegrations();
                                            a[index].name = text;
                                            settingsPanel._saveConfigKey("integrations", a);
                                        }
                                    }
                                }
                            }

                            Column {
                                width: (parent.width - _integRemoveBtn.width - parent.spacing * 2) * 0.25
                                spacing: 2

                                Text {
                                    text: "template"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 9
                                    color: Colors.tertiary
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 22
                                    radius: 3
                                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                                    border.width: _tplIn.activeFocus ? 1 : 0
                                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

                                    TextInput {
                                        id: _tplIn

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Style.fontFamilyCode
                                        font.pixelSize: 10
                                        color: Colors.tertiary
                                        clip: true
                                        selectByMouse: true
                                        text: modelData.template || ""
                                        onEditingFinished: {
                                            var a = settingsPanel._cloneIntegrations();
                                            a[index].template = text;
                                            settingsPanel._saveConfigKey("integrations", a);
                                        }
                                    }
                                }
                            }

                            Column {
                                width: (parent.width - _integRemoveBtn.width - parent.spacing * 2) * 0.3
                                spacing: 2

                                Text {
                                    text: "output"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 9
                                    color: Colors.tertiary
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 22
                                    radius: 3
                                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                                    border.width: _outIn.activeFocus ? 1 : 0
                                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

                                    TextInput {
                                        id: _outIn

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Style.fontFamilyCode
                                        font.pixelSize: 10
                                        color: Colors.tertiary
                                        clip: true
                                        selectByMouse: true
                                        text: modelData.output || ""
                                        onEditingFinished: {
                                            var a = settingsPanel._cloneIntegrations();
                                            a[index].output = text;
                                            settingsPanel._saveConfigKey("integrations", a);
                                        }
                                    }
                                }
                            }

                            Column {
                                width: (parent.width - _integRemoveBtn.width - parent.spacing * 2) * 0.25
                                spacing: 2

                                Text {
                                    text: "reload"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 9
                                    color: Colors.tertiary
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 22
                                    radius: 3
                                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                                    border.width: _reloadIn.activeFocus ? 1 : 0
                                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)

                                    TextInput {
                                        id: _reloadIn

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Style.fontFamilyCode
                                        font.pixelSize: 10
                                        color: Colors.tertiary
                                        clip: true
                                        selectByMouse: true
                                        text: modelData.reload || ""
                                        onEditingFinished: {
                                            var a = settingsPanel._cloneIntegrations();
                                            a[index].reload = text || undefined;
                                            settingsPanel._saveConfigKey("integrations", a);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: _integRemoveBtn

                                width: 22
                                height: 22
                                radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: _integRemoveMa.containsMouse ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.family: Style.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Colors.primary
                                }

                                MouseArea {
                                    id: _integRemoveMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var a = settingsPanel._cloneIntegrations();
                                        a.splice(index, 1);
                                        settingsPanel._saveConfigKey("integrations", a);
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 150
                    height: 28
                    radius: 4
                    color: _addIntegMa.containsMouse ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)) : (Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6))

                    Text {
                        anchors.centerIn: parent
                        text: "+ ADD INTEGRATION"
                        font.family: Style.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Colors.primary
                    }

                    MouseArea {
                        id: _addIntegMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var a = settingsPanel._cloneIntegrations();
                            a.push({
                                "name": "",
                                "template": "",
                                "output": ""
                            });
                            settingsPanel._saveConfigKey("integrations", a);
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }
        }

        Rectangle {
            id: _matugenScrollTrack

            readonly property real _cH: matugenContent.contentHeight
            readonly property real _vH: matugenContent.height
            readonly property bool _overflow: _cH > _vH && _cH > 0

            x: matugenContent.x - 6
            width: 3
            radius: 1.5
            opacity: 0.5
            visible: matugenContent.visible
            color: Colors.primary
            height: _overflow ? Math.min(_vH * 0.5, Math.max(16, _vH * _vH / _cH)) : 0
            y: matugenContent.y + (_overflow ? matugenContent.contentY / (_cH - _vH) * (_vH - height) : 0)

            Behavior on height {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        Row {
            id: keybindsContent

            anchors.left: parent.left
            anchors.right: parent.right
            visible: settingsPanel.activeTab === "keybinds"
            spacing: 12

            Column {
                width: (parent.width - parent.spacing * 2 - 1) * 0.5
                spacing: 6

                Text {
                    text: "NAVIGATION"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Repeater {
                    model: [
                        {
                            "key": "← / →",
                            "action": "Navigate items"
                        },
                        {
                            "key": "↑ / ↓",
                            "action": "Navigate rows (hex/grid)"
                        },
                        {
                            "key": "Enter",
                            "action": "Apply wallpaper"
                        },
                        {
                            "key": "Escape",
                            "action": "Close panel / overlay"
                        },
                        {
                            "key": "Right-click",
                            "action": "Flip card (details)"
                        },
                        {
                            "key": "Scroll",
                            "action": "Browse wallpapers"
                        }
                    ]

                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.key
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.3
                            color: Colors.primary
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.action
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            color: Colors.surfaceText
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.1)
            }

            Column {
                width: (parent.width - parent.spacing * 2 - 1) * 0.5
                spacing: 6

                Text {
                    text: "FILTERS & TAGS"
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Colors.tertiary
                }

                Repeater {
                    model: [
                        {
                            "key": "Shift + ← / →",
                            "action": "Cycle colour filters"
                        },
                        {
                            "key": "Shift + ↓",
                            "action": "Toggle tag cloud"
                        },
                        {
                            "key": "Tab",
                            "action": "Auto-complete tag"
                        },
                        {
                            "key": "Enter",
                            "action": "Add tag (in tag input)"
                        },
                        {
                            "key": "Escape",
                            "action": "Clear search / close"
                        }
                    ]

                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.key
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.3
                            color: Colors.primary
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.action
                            font.family: Style.fontFamily
                            font.pixelSize: 11
                            color: Colors.surfaceText
                        }
                    }
                }
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Style.animFast
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: _deleteConfirmPopup

        function open() {
            _deleteConfirmInput.text = "";
            visible = true;
            _deleteConfirmInput.forceActiveFocus();
        }

        function close() {
            visible = false;
        }

        visible: false
        anchors.fill: parent
        z: 200
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        radius: 8

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{f0027}"
                font.family: Style.fontFamilyNerdIcons
                font.pixelSize: 28
                color: "#ef5350"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DELETE ALL TAGS?"
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Colors.surfaceText
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "This will erase every tag and re-analyse all wallpapers with the current model. This cannot be undone."
                font.family: Style.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 0.2
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Item {
                width: 1
                height: 2
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: 'Type "delete" to confirm'
                font.family: Style.fontFamily
                font.pixelSize: 11
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                height: 30
                radius: 15
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5)
                border.width: _deleteConfirmInput.activeFocus ? 1 : 0
                border.color: "#ef5350"

                TextInput {
                    id: _deleteConfirmInput

                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    font.family: Style.fontFamily
                    font.pixelSize: 12
                    font.letterSpacing: 0.5
                    color: Colors.surfaceText
                    clip: true
                    Keys.onEscapePressed: _deleteConfirmPopup.close()
                    Keys.onReturnPressed: {
                        if (_deleteConfirmInput.text.toLowerCase().trim() === "delete") {
                            WallpaperAnalysisService.regenerate();
                            _deleteConfirmPopup.close();
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                FilterButton {
                    label: "CANCEL"
                    skew: 8
                    height: 26
                    onClicked: _deleteConfirmPopup.close()
                }

                FilterButton {
                    id: _confirmDeleteBtn

                    property bool canConfirm: _deleteConfirmInput.text.toLowerCase().trim() === "delete"

                    label: "CONFIRM"
                    skew: 8
                    height: 26
                    hasActiveColor: true
                    activeColor: canConfirm ? "#c62828" : Qt.rgba(0.5, 0.5, 0.5, 0.3)
                    isActive: canConfirm
                    activeOpacity: canConfirm ? 1 : 0.4
                    onClicked: {
                        if (canConfirm) {
                            WallpaperAnalysisService.regenerate();
                            _deleteConfirmPopup.close();
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: _optimizeConfirmPopup

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        visible: false
        anchors.fill: parent
        z: 201
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        radius: 8

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{f03e}"
                font.family: Style.fontFamilyNerdIcons
                font.pixelSize: 28
                color: Colors.primary
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "OPTIMIZE ALL IMAGES?"
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Colors.surfaceText
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    var p = ImageOptimizeService.presets[Config.imageOptimizePreset];
                    var r = ImageOptimizeService.resolutions[Config.imageOptimizeResolution];
                    var fmts = p ? p.formats.join(", ").toUpperCase() : "?";
                    return "This will convert " + fmts + " images to WebP using the " + Config.imageOptimizePreset.toUpperCase() + " preset (quality " + (p ? p.quality : "?") + ", max " + (r ? r.maxW + "x" + r.maxH : "?") + "). Originals are moved to trash. Already optimized files will be skipped.";
                }
                font.family: Style.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 0.2
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Only images in your wallpaper directory are processed"
                font.family: Style.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 0.2
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                FilterButton {
                    label: "CANCEL"
                    skew: 8
                    height: 26
                    onClicked: _optimizeConfirmPopup.close()
                }

                FilterButton {
                    label: "OPTIMIZE"
                    skew: 8
                    height: 26
                    isActive: true
                    onClicked: {
                        _optimizeConfirmPopup.close();
                        ImageOptimizeService.optimize(Config.imageOptimizePreset, Config.imageOptimizeResolution);
                    }
                }
            }
        }
    }

    Rectangle {
        id: _convertConfirmPopup

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        visible: false
        anchors.fill: parent
        z: 200
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        radius: 8

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{f03d}"
                font.family: Style.fontFamilyNerdIcons
                font.pixelSize: 28
                color: Colors.primary
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "OPTIMIZE ALL VIDEOS?"
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Colors.surfaceText
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    var p = VideoConvertService.presets[Config.videoConvertPreset];
                    var r = VideoConvertService.resolutions[Config.videoConvertResolution];
                    return "This will convert all video wallpapers to HEVC (H.265) using the " + Config.videoConvertPreset.toUpperCase() + " preset (CRF " + (p ? p.crf : "?") + ", max " + (p ? p.maxrate : "?") + ", " + (r ? r.maxW + "x" + r.maxH : "?") + "). Originals are moved to trash. Already converted files will be skipped.";
                }
                font.family: Style.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 0.2
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "This may take a while depending on the number and size of videos."
                font.family: Style.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 0.2
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                FilterButton {
                    label: "CANCEL"
                    skew: 8
                    height: 26
                    onClicked: _convertConfirmPopup.close()
                }

                FilterButton {
                    label: "CONVERT"
                    skew: 8
                    height: 26
                    isActive: false
                    enabled: false
                    opacity: 0.35
                }
            }
        }
    }

    Rectangle {
        id: _restartWarningPopup

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        visible: false
        anchors.fill: parent
        z: 200
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        radius: 8

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{f0028}"
                font.family: Style.fontFamilyNerdIcons
                font.pixelSize: 28
                color: "#ffb74d"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RESTART REQUIRED"
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Colors.surfaceText
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Directory changes will take effect after restarting the app. Don't forget that includes the daemon!"
                font.family: Style.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 0.2
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            Item {
                width: 1
                height: 2
            }

            FilterButton {
                anchors.horizontalCenter: parent.horizontalCenter
                label: "OK"
                skew: 8
                height: 26
                isActive: true
                onClicked: _restartWarningPopup.close()
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Style.animFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Style.animFast
            easing.type: Easing.OutCubic
        }
    }
}
