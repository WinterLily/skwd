pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: config

    function _resolve(path) { return path ? path.replace("~", homeDir).replace(/\/+$/, "") : "" }

    readonly property string homeDir: Quickshell.env("HOME")

    readonly property string configDir: Quickshell.env("SKWD_CONFIG")
        || (Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")) + "/skwd"
    readonly property string installDir: Quickshell.env("SKWD_INSTALL") || configDir

    property var _configFile: FileView {
        path: configDir + "/data/config.json"
        preload: true
        watchChanges: true
        onFileChanged: _configFile.reload()
    }
    property string _rawText: _configFile.__text ?? ""
    readonly property bool configLoaded: _rawText !== ""
    property var _data: {
        var raw = _rawText
        if (!raw) return {}
        try { return JSON.parse(raw) }
        catch (e) { return {} }
    }

    // ---------------------------------------------------------------------------
    // Shell settings
    // ---------------------------------------------------------------------------

    readonly property string scriptsDir: _resolve(_data.paths?.scripts) || (installDir + "/scripts")
    readonly property string cacheDir: _resolve(_data.paths?.cache)
        || Quickshell.env("SKWD_CACHE")
        || (Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")) + "/skwd"
    readonly property string colorFilePath: _resolve(_data.paths?.colorsFile) || (cacheDir + "/colors.json")

    readonly property string compositor: _data.compositor ?? "niri"

    readonly property bool allMonitors: _data.monitor === "all"
    readonly property var monitorList: {
        if (!_data.monitor || _data.monitor === "all") return []
        if (Array.isArray(_data.monitor)) return _data.monitor
        return [_data.monitor]
    }
    readonly property string mainMonitor: _data.monitor ?? ""
    readonly property string ollamaUrl: Quickshell.env("SKWD_OLLAMA_URL") || (_data.ollama?.url ?? "")
    readonly property string ollamaModel: _data.ollama?.model ?? ""
    readonly property int weatherPollMs: _data.intervals?.weatherPollMs ?? 0
    readonly property int wifiPollMs: _data.intervals?.wifiPollMs ?? 0
    readonly property int smartHomePollMs: _data.intervals?.smartHomePollMs ?? 0
    readonly property int ollamaStatusPollMs: _data.intervals?.ollamaStatusPollMs ?? 0
    readonly property int notificationExpireMs: _data.intervals?.notificationExpireMs ?? 0

    readonly property string terminal: _data.terminal ?? "kitty"

    property var _bar: _data.components?.bar ?? {}
    readonly property bool barEnabled: _bar.enabled !== false
    readonly property string weatherCity: Quickshell.env("SKWD_WEATHER_CITY") || (_bar.weather?.city ?? "")
    readonly property bool weatherEnabled: _bar.weather !== undefined && _bar.weather !== false && _bar.weather?.enabled !== false
    readonly property string wifiInterface: _bar.wifi?.interface ?? ""
    readonly property bool wifiEnabled: _bar.wifi !== undefined && _bar.wifi !== false && _bar.wifi?.enabled !== false
    readonly property bool bluetoothEnabled: _bar.bluetooth !== false
    readonly property bool volumeEnabled: _bar.volume !== false
    readonly property bool calendarEnabled: _bar.calendar !== false
    readonly property bool musicEnabled: _bar.music !== undefined && _bar.music !== false && _bar.music?.enabled !== false
    readonly property string preferredPlayer: _bar.music?.preferredPlayer ?? "spotify"
    readonly property string visualizerTheme: _bar.music?.visualizer ?? "wave"
    readonly property bool visualizerTop: (_bar.music?.visualizerTop !== false)
    readonly property bool visualizerBottom: (_bar.music?.visualizerBottom !== false)
    readonly property bool musicAutohide: (_bar.music?.autohide !== false)
    readonly property bool accentEdges: _bar.accentEdges !== false

    property var _components: _data.components ?? {}
    readonly property bool appLauncherEnabled: _components.appLauncher !== false
    property var _appLauncher: (typeof _components.appLauncher === "object" && _components.appLauncher !== null) ? _components.appLauncher : {}
    readonly property string launcherDisplayMode: _appLauncher.displayMode ?? "slices"
    readonly property int launcherHexRadius: _appLauncher.hexRadius ?? 56
    readonly property int launcherHexRows: _appLauncher.hexRows ?? 4
    readonly property int launcherHexCols: _appLauncher.hexCols ?? 9
    readonly property bool wallpaperSelectorEnabled: _components.wallpaperSelector !== false && _components.wallpaperSelector?.enabled !== false
    readonly property bool windowSwitcherEnabled: _components.windowSwitcher !== false
    readonly property bool powerMenuEnabled: _components.powerMenu !== false && _components.powerMenu?.enabled !== false
    readonly property var powerMenuOptions: _components.powerMenu?.items ?? (Array.isArray(_components.powerMenu) ? _components.powerMenu : [])
    readonly property bool notificationsEnabled: _components.notifications !== false
    readonly property bool lockscreenEnabled: _components.lockscreen !== false
    readonly property bool smartHomeEnabled: _components.smartHome === true

    // ---------------------------------------------------------------------------
    // Wallpaper settings (share the same config.json, overlapping keys shared)
    // ---------------------------------------------------------------------------

    readonly property string wallCacheDir: cacheDir + "/wallpaper"
    readonly property string wallScriptsDir: scriptsDir
    readonly property string wallTemplateDir: installDir + "/ext/matugen/templates"

    readonly property string wallpaperDir: _resolve(_data.paths?.wallpaper) || (homeDir + "/Pictures/Wallpapers")
    readonly property string videoDir: _resolve(_data.paths?.videoWallpaper) || wallpaperDir
    readonly property string weDir: _resolve(_data.paths?.steamWorkshop) || _detectWeDir()
    function _detectWeDir() {
        var steamRoot = _resolve(_data.paths?.steam) || (homeDir + "/.local/share/Steam")
        return steamRoot + "/steamapps/workshop/content/431960"
    }
    readonly property string weAssetsDir: _resolve(_data.paths?.steamWeAssets)
    readonly property string steamDir: _resolve(_data.paths?.steam)

    readonly property bool wallpaperMute: _data.wallpaperMute !== false

    readonly property bool matugenEnabled: _data.features?.matugen !== false
    readonly property bool ollamaEnabled: _data.features?.ollama !== false
    readonly property bool steamEnabled: _data.features?.steam !== false
    readonly property bool wallhavenEnabled: _data.features?.wallhaven !== false
    readonly property bool videoPreviewEnabled: _data.features?.videoPreview !== false

    readonly property string videoConvertPreset: _data.performance?.videoConvertPreset ?? "balanced"
    readonly property string videoConvertResolution: _data.performance?.videoConvertResolution ?? "2k"
    readonly property string imageOptimizePreset: _data.performance?.imageOptimizePreset ?? "balanced"
    readonly property string imageOptimizeResolution: _data.performance?.imageOptimizeResolution ?? "2k"
    readonly property bool autoOptimizeImages: _data.performance?.autoOptimizeImages === true
    readonly property bool autoConvertVideos: _data.performance?.autoConvertVideos === true
    readonly property int imageTrashDays: _data.performance?.imageTrashDays ?? 7
    readonly property int videoTrashDays: _data.performance?.videoTrashDays ?? 7
    readonly property bool autoDeleteImageTrash: _data.performance?.autoDeleteImageTrash === true
    readonly property bool autoDeleteVideoTrash: _data.performance?.autoDeleteVideoTrash === true

    readonly property string colorSource: _data.colorSource ?? "ollama"
    readonly property string matugenConfig: wallCacheDir + "/matugen-config.toml"
    readonly property string defaultMatugenConfig: _resolve(_data.defaultMatugenConfig ?? "~/.config/matugen/config.toml")

    readonly property var integrations: _data.integrations ?? []
    onIntegrationsChanged: _generateMatugenConfig()

    property var _matugenConfigWriter: FileView { id: matugenConfigWriter }
    function _generateMatugenConfig() {
        if (!matugenEnabled) return
        var ints = integrations
        if (!ints || ints.length === 0) return
        var tDir = wallTemplateDir
        var lines = ["[config]", "reload_apps = false", ""]
        for (var i = 0; i < ints.length; i++) {
            var integ = ints[i]
            if (!integ.template) continue
            var inputPath = integ.template.indexOf("/") >= 0
                ? _resolve(integ.template)
                : tDir + "/" + integ.template
            var outputPath = integ.output
                ? (integ.output.indexOf("/") >= 0
                    ? _resolve(integ.output)
                    : cacheDir + "/" + integ.output)
                : ""
            if (!outputPath) continue
            var safe = (integ.name || "integration_" + i).replace(/[^a-zA-Z0-9_-]/g, "_")
            lines.push("[templates." + safe + "]")
            lines.push('input_path = "' + inputPath + '"')
            lines.push('output_path = "' + outputPath + '"')
            lines.push("")
        }
        matugenConfigWriter.path = matugenConfig
        matugenConfigWriter.setText(lines.join("\n"))
    }

    readonly property var postProcessing: _data.postProcessing ?? []
    readonly property bool postProcessOnRestore: _data.postProcessOnRestore === true

    readonly property bool isKDE: {
        var desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
        return desktop.indexOf("kde") >= 0 || desktop.indexOf("plasma") >= 0
    }
    readonly property string kdeVideoPlugin: "luisbocanegra.smart.video.wallpaper.reborn"

    readonly property string wallhavenApiKey: Quickshell.env("WALLHAVEN_API_KEY") || (_data.wallhaven?.apiKey ?? "")
    readonly property string steamApiKey: Quickshell.env("STEAM_API_KEY") || (_data.steam?.apiKey ?? "")
    readonly property string steamUsername: _data.steam?.username ?? ""

    // Wallpaper selector UI dimensions
    property var _wallSel: (typeof _components.wallpaperSelector === "object" && _components.wallpaperSelector !== null) ? _components.wallpaperSelector : {}

    readonly property var _screen: Quickshell.screens[0] ?? null
    readonly property int _screenW: _screen ? _screen.width : 1920
    readonly property int _screenH: _screen ? _screen.height : 1080
    readonly property bool _isSmallScreen: _screenW <= 1600

    readonly property bool wallpaperColorDots: _wallSel.showColorDots !== false
    readonly property int wallpaperSliceHeight: _wallSel.sliceHeight ?? (_isSmallScreen ? 360 : 520)
    readonly property int wallpaperVisibleCount: _wallSel.visibleCount ?? (_isSmallScreen ? 8 : 12)
    readonly property int wallpaperExpandedWidth: _wallSel.expandedWidth ?? (_isSmallScreen ? 600 : 924)
    readonly property int wallpaperSliceWidth: _wallSel.sliceWidth ?? (_isSmallScreen ? 90 : 135)
    readonly property int wallpaperSliceSpacing: _wallSel.sliceSpacing ?? -30
    readonly property int wallpaperSkewOffset: _wallSel.skewOffset ?? (_isSmallScreen ? 25 : 35)
    readonly property var wallpaperCustomPresets: _wallSel.customPresets ?? {}

    readonly property string displayMode: _wallSel.displayMode ?? "slices"
    readonly property int hexRadius: _wallSel.hexRadius ?? (_isSmallScreen ? 100 : 140)
    readonly property int hexRows: _wallSel.hexRows ?? 3
    readonly property int hexCols: _wallSel.hexCols ?? (_isSmallScreen ? 5 : 7)
    readonly property int hexScrollStep: _wallSel.hexScrollStep ?? 1
    readonly property bool hexArc: _wallSel.hexArc !== false
    readonly property real hexArcIntensity: _wallSel.hexArcIntensity ?? 1.2

    readonly property int gridColumns: _wallSel.gridColumns ?? (_isSmallScreen ? 4 : 6)
    readonly property int gridRows: _wallSel.gridRows ?? 3
    readonly property int gridThumbWidth: _wallSel.gridThumbWidth ?? (_isSmallScreen ? 220 : 300)
    readonly property int gridThumbHeight: _wallSel.gridThumbHeight ?? (_isSmallScreen ? 124 : 169)

    readonly property int wallhavenColumns: _wallSel.wallhavenColumns ?? (_isSmallScreen ? 4 : 6)
    readonly property int wallhavenRows: _wallSel.wallhavenRows ?? 3
    readonly property int wallhavenThumbWidth: _wallSel.wallhavenThumbWidth ?? (_isSmallScreen ? 220 : 300)
    readonly property int wallhavenThumbHeight: _wallSel.wallhavenThumbHeight ?? (_isSmallScreen ? 124 : 169)

    readonly property int steamColumns: _wallSel.steamColumns ?? (_isSmallScreen ? 4 : 6)
    readonly property int steamRows: _wallSel.steamRows ?? 3
    readonly property int steamThumbWidth: _wallSel.steamThumbWidth ?? (_isSmallScreen ? 220 : 300)
    readonly property int steamThumbHeight: _wallSel.steamThumbHeight ?? (_isSmallScreen ? 124 : 169)
}
