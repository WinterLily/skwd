pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: config

    function _resolve(path) {
        return path ? path.replace("~", homeDir).replace(/\/+$/, "") : "";
    }

    readonly property string homeDir: Quickshell.env("HOME")

    readonly property string configDir: Quickshell.env("SKWD_CONFIG") || (Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")) + "/skwd"
    readonly property string installDir: Quickshell.env("SKWD_INSTALL") || configDir

    // ── TOML loading ─────────────────────────────────────────────────────────
    // Watch config.toml for changes and re-run the converter on each save.

    property var _tomlWatcher: FileView {
        path: configDir + "/config.toml"
        watchChanges: true
        onFileChanged: config._runConverter()
    }

    property var _rawParts: []
    property string _rawText: ""
    readonly property bool configLoaded: _rawText !== ""

    function _runConverter() {
        _rawParts = [];
        _tomlConverter.running = false;
        _tomlConverter.running = true;
    }

    property var _tomlConverter: Process {
        command: [
            "python3", "-c",
            "import tomllib,json,sys; f=open(sys.argv[1],'rb'); print(json.dumps(tomllib.load(f)))",
            config.configDir + "/config.toml"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => config._rawParts.push(data)
        }
        onExited: {
            if (exitCode === 0)
                config._rawText = config._rawParts.join("");
            config._rawParts = [];
        }
    }

    Component.onCompleted: _runConverter()

    property var _data: {
        var raw = _rawText;
        if (!raw)
            return {};
        try {
            return JSON.parse(raw);
        } catch (e) {
            return {};
        }
    }

    // ---------------------------------------------------------------------------
    // Shell settings
    // ---------------------------------------------------------------------------

    readonly property string scriptsDir: _resolve(_data.paths?.scripts) || (installDir + "/scripts")
    readonly property string cacheDir: _resolve(_data.paths?.cache) || Quickshell.env("SKWD_CACHE") || (Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")) + "/skwd"
    readonly property string colorFilePath: _resolve(_data.paths?.colors_file) || (cacheDir + "/colors.json")

    readonly property int weatherPollMs: _data.intervals?.weather_poll_ms ?? 0
    readonly property int wifiPollMs: _data.intervals?.wifi_poll_ms ?? 0
    readonly property int smartHomePollMs: _data.intervals?.smart_home_poll_ms ?? 0
    readonly property int notificationExpireMs: _data.intervals?.notification_expire_ms ?? 0

    property var _bar: _data.bar ?? {}
    readonly property bool barEnabled: _bar.enabled !== false
    readonly property string weatherCity: Quickshell.env("SKWD_WEATHER_CITY") || (_bar.weather?.city ?? "")
    readonly property bool weatherEnabled: _bar.weather !== undefined && _bar.weather !== false && _bar.weather?.enabled !== false
    readonly property string wifiInterface: _bar.wifi?.interface ?? ""
    readonly property bool wifiEnabled: _bar.wifi !== undefined && _bar.wifi !== false && _bar.wifi?.enabled !== false
    readonly property bool bluetoothEnabled: _bar.widgets?.bluetooth !== false
    readonly property bool volumeEnabled: _bar.widgets?.volume !== false
    readonly property bool calendarEnabled: _bar.widgets?.calendar !== false
    readonly property bool musicEnabled: _bar.music !== undefined && _bar.music !== false && _bar.music?.enabled !== false
    readonly property string preferredPlayer: _bar.music?.preferred_player ?? "spotify"
    readonly property string visualizerTheme: _bar.music?.visualizer ?? "wave"
    readonly property bool visualizerTop: (_bar.music?.visualizer_top !== false)
    readonly property bool visualizerBottom: (_bar.music?.visualizer_bottom !== false)
    readonly property bool musicAutohide: (_bar.music?.autohide !== false)
    readonly property bool accentEdges: _bar.accent_edges !== false

    readonly property bool appLauncherEnabled: _data.launcher?.enabled !== false
    readonly property int launcherHexRadius: _data.launcher?.hex_radius ?? 56
    readonly property int launcherHexRows: _data.launcher?.hex_rows ?? 4
    readonly property int launcherHexCols: _data.launcher?.hex_cols ?? 9

    readonly property bool wallpaperSelectorEnabled: _data.wallpaper_selector?.enabled !== false
    readonly property bool windowSwitcherEnabled: _data.window_switcher?.enabled !== false
    readonly property bool powerMenuEnabled: _data.power_menu?.enabled !== false
    readonly property var powerMenuOptions: _data.power_menu?.items ?? []
    readonly property bool notificationsEnabled: _data.notifications?.enabled !== false
    readonly property bool lockscreenEnabled: _data.lockscreen?.enabled === true
    readonly property bool smartHomeEnabled: _data.smart_home?.enabled === true

    // ---------------------------------------------------------------------------
    // Wallpaper settings
    // ---------------------------------------------------------------------------

    readonly property string wallCacheDir: cacheDir + "/wallpaper"
    readonly property string wallScriptsDir: scriptsDir
    readonly property string wallTemplateDir: installDir + "/ext/matugen/templates"

    readonly property string wallpaperDir: _resolve(_data.paths?.wallpaper) || (homeDir + "/Pictures/Wallpapers")
    readonly property string videoDir: _resolve(_data.paths?.video_wallpaper) || wallpaperDir
    readonly property string weDir: _resolve(_data.paths?.steam_workshop) || _detectWeDir()
    function _detectWeDir() {
        var steamRoot = _resolve(_data.paths?.steam) || (homeDir + "/.local/share/Steam");
        return steamRoot + "/steamapps/workshop/content/431960";
    }
    readonly property string weAssetsDir: _resolve(_data.paths?.steam_we_assets)
    readonly property string steamDir: _resolve(_data.paths?.steam)

    readonly property bool wallpaperMute: _data.wallpaper_mute !== false

    readonly property bool matugenEnabled: _data.features?.matugen !== false
    readonly property bool steamEnabled: _data.steam?.enabled !== false
    readonly property bool wallhavenEnabled: _data.wallhaven?.enabled !== false
    readonly property bool videoPreviewEnabled: _data.features?.video_preview !== false

    readonly property string videoConvertPreset: _data.performance?.video_convert_preset ?? "balanced"
    readonly property string videoConvertResolution: _data.performance?.video_convert_resolution ?? "2k"
    readonly property string imageOptimizePreset: _data.performance?.image_optimize_preset ?? "balanced"
    readonly property string imageOptimizeResolution: _data.performance?.image_optimize_resolution ?? "2k"
    readonly property bool autoOptimizeImages: _data.performance?.auto_optimize_images === true
    readonly property bool autoConvertVideos: _data.performance?.auto_convert_videos === true
    readonly property int imageTrashDays: _data.performance?.image_trash_days ?? 7
    readonly property int videoTrashDays: _data.performance?.video_trash_days ?? 7
    readonly property bool autoDeleteImageTrash: _data.performance?.auto_delete_image_trash === true
    readonly property bool autoDeleteVideoTrash: _data.performance?.auto_delete_video_trash === true

    readonly property string matugenConfig: wallCacheDir + "/matugen-config.toml"
    readonly property string defaultMatugenConfig: _resolve(_data.paths?.matugen_config ?? "~/.config/matugen/config.toml")

    readonly property var integrations: _data.integrations ?? []
    onIntegrationsChanged: _generateMatugenConfig()

    property var _matugenConfigWriter: FileView {
        id: matugenConfigWriter
    }
    function _generateMatugenConfig() {
        if (!matugenEnabled)
            return;
        var ints = integrations;
        if (!ints || ints.length === 0)
            return;
        var tDir = wallTemplateDir;
        var lines = ["[config]", "reload_apps = false", ""];
        for (var i = 0; i < ints.length; i++) {
            var integ = ints[i];
            if (!integ.template)
                continue;
            var inputPath = integ.template.indexOf("/") >= 0 ? _resolve(integ.template) : tDir + "/" + integ.template;
            var outputPath = integ.output ? (integ.output.indexOf("/") >= 0 ? _resolve(integ.output) : cacheDir + "/" + integ.output) : "";
            if (!outputPath)
                continue;
            var safe = (integ.name || "integration_" + i).replace(/[^a-zA-Z0-9_-]/g, "_");
            lines.push("[templates." + safe + "]");
            lines.push('input_path = "' + inputPath + '"');
            lines.push('output_path = "' + outputPath + '"');
            lines.push("");
        }
        matugenConfigWriter.path = matugenConfig;
        matugenConfigWriter.setText(lines.join("\n"));
    }

    readonly property var postProcessing: _data.post_processing?.scripts ?? []
    readonly property bool postProcessOnRestore: _data.post_processing?.on_restore === true

    readonly property string wallhavenApiKey: Quickshell.env("WALLHAVEN_API_KEY") || (_data.wallhaven?.api_key ?? "")
    readonly property string steamApiKey: Quickshell.env("STEAM_API_KEY") || (_data.steam?.api_key ?? "")
    readonly property string steamUsername: _data.steam?.username ?? ""

    // Wallpaper selector UI dimensions
    property var _wallSel: _data.wallpaper_selector ?? {}
    property var _wallHex: _wallSel.hex ?? {}
    property var _wallSlices: _wallSel.slices ?? {}
    property var _wallGrid: _wallSel.grid ?? {}

    readonly property var _screen: Quickshell.screens[0] ?? null
    readonly property int _screenW: _screen ? _screen.width : 1920
    readonly property int _screenH: _screen ? _screen.height : 1080
    readonly property bool _isSmallScreen: _screenW <= 1600

    readonly property bool wallpaperColorDots: _wallSel.show_color_dots !== false
    readonly property int wallpaperSliceHeight: _wallSlices.height ?? (_isSmallScreen ? 360 : 520)
    readonly property int wallpaperVisibleCount: _wallSlices.visible_count ?? (_isSmallScreen ? 8 : 12)
    readonly property int wallpaperExpandedWidth: _wallSlices.expanded_width ?? (_isSmallScreen ? 600 : 924)
    readonly property int wallpaperSliceWidth: _wallSlices.slice_width ?? (_isSmallScreen ? 90 : 135)
    readonly property int wallpaperSliceSpacing: _wallSlices.slice_spacing ?? -30
    readonly property int wallpaperSkewOffset: _wallSlices.skew_offset ?? (_isSmallScreen ? 25 : 35)

    readonly property string displayMode: _wallSel.display_mode ?? "slices"
    readonly property int hexRadius: _wallHex.radius ?? (_isSmallScreen ? 100 : 140)
    readonly property int hexRows: _wallHex.rows ?? 3
    readonly property int hexCols: _wallHex.cols ?? (_isSmallScreen ? 5 : 7)
    readonly property int hexScrollStep: _wallHex.scroll_step ?? 1
    readonly property bool hexArc: _wallHex.arc !== false
    readonly property real hexArcIntensity: _wallHex.arc_intensity ?? 1.2

    readonly property int gridColumns: _wallGrid.columns ?? (_isSmallScreen ? 4 : 6)
    readonly property int gridRows: _wallGrid.rows ?? 3
    readonly property int gridThumbWidth: _wallGrid.thumb_width ?? (_isSmallScreen ? 220 : 300)
    readonly property int gridThumbHeight: _wallGrid.thumb_height ?? (_isSmallScreen ? 124 : 169)

    readonly property int wallhavenColumns: _data.wallhaven?.columns ?? (_isSmallScreen ? 4 : 6)
    readonly property int wallhavenRows: _data.wallhaven?.rows ?? 3
    readonly property int wallhavenThumbWidth: _data.wallhaven?.thumb_width ?? (_isSmallScreen ? 220 : 300)
    readonly property int wallhavenThumbHeight: _data.wallhaven?.thumb_height ?? (_isSmallScreen ? 124 : 169)

    readonly property int steamColumns: _data.steam?.columns ?? (_isSmallScreen ? 4 : 6)
    readonly property int steamRows: _data.steam?.rows ?? 3
    readonly property int steamThumbWidth: _data.steam?.thumb_width ?? (_isSmallScreen ? 220 : 300)
    readonly property int steamThumbHeight: _data.steam?.thumb_height ?? (_isSmallScreen ? 124 : 169)
}
