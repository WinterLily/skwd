import QtQuick
import Quickshell.Io

QtObject {
    id: service

    // External bindings
    required property string scriptsDir
    required property string compositor
    required property string configPath
    required property string homeDir
    required property string cacheDir
    // Window list and selection state
    property var windowList: []
    property int selectedIndex: 0
    property bool preserveIndex: false
    property int screenshotCounter: 0
    property string thumbDir: cacheDir + "/window-thumbs"
    // App config from apps.json (custom icons/names)
    property var appConfig: ({
    })
    property var _appConfigFile
    // Data model
    property var filteredModel
    // Processes
    property var _focusProcess
    property var _closeProcess
    property var _captureWindows
    property var _fetchWindows
    property var _refreshTimer

    // Signals to view for scroll/focus management
    signal modelBuilt(int focusIndex)

    function loadAppConfig() {
        try {
            service.appConfig = JSON.parse(_appConfigFile.text());
        } catch (e) {
            service.appConfig = {
            };
        }
    }

    function getAppConf(appId) {
        var lower = appId.toLowerCase();
        if (appConfig[lower])
            return appConfig[lower];

        for (var key in appConfig) {
            if (key.startsWith("_"))
                continue;

            if (lower.indexOf(key) !== -1 || key.indexOf(lower) !== -1) {
                if (typeof appConfig[key] === "object")
                    return appConfig[key];

            }
        }
        return {
        };
    }

    function getIcon(appId) {
        var conf = getAppConf(appId);
        if (conf.icon)
            return conf.icon;

        return "?";
    }

    function getName(appId) {
        var conf = getAppConf(appId);
        if (conf.displayName)
            return conf.displayName;

        return appId;
    }

    // Build filtered model from window list
    function buildModel() {
        var prevIdx = selectedIndex;
        filteredModel.clear();
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            filteredModel.append({
                "winId": w.id || 0,
                "title": w.title || "",
                "appId": w.app_id || "",
                "workspaceId": w.workspace_id || 0,
                "isFocused": w.is_focused || false,
                "isFloating": w.is_floating || false
            });
        }
        var idx = 0;
        if (filteredModel.count > 0) {
            if (preserveIndex) {
                idx = Math.min(prevIdx, filteredModel.count - 1);
                preserveIndex = false;
            } else {
                idx = filteredModel.count > 1 ? 1 : 0;
            }
        }
        modelBuilt(idx);
    }

    function captureAllWindows() {
        var cmds = ["mkdir -p " + thumbDir];
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (w.id)
                cmds.push(scriptsDir + "/bash/wm-action screenshot-window " + w.id + " " + thumbDir + "/" + w.id + ".png 2>/dev/null");

        }
        _captureWindows.command = ["sh", "-c", cmds.join("; ")];
        _captureWindows.running = true;
    }

    // Actions
    function open() {
        selectedIndex = 0;
        preserveIndex = false;
        loadAppConfig();
        _fetchWindows.buf = "";
        _fetchWindows.running = true;
    }

    function focusWindow(winId) {
        _focusProcess.command = [scriptsDir + "/bash/wm-action", "focus-window", winId.toString()];
        _focusProcess.running = true;
    }

    function closeWindow(winId) {
        _closeProcess.command = [scriptsDir + "/bash/wm-action", "close-window", winId.toString()];
        _closeProcess.running = true;
        preserveIndex = true;
        _refreshTimer.restart();
    }

    _appConfigFile: FileView {
        path: service.configPath
        preload: true
        watchChanges: true
        onFileChanged: _appConfigFile.reload()
    }

    filteredModel: ListModel {
    }

    _focusProcess: Process {
        command: ["true"]
    }

    _closeProcess: Process {
        command: ["true"]
    }

    _captureWindows: Process {
        command: ["sh", "-c", "true"]
        onExited: {
            service.screenshotCounter++;
        }
    }

    _fetchWindows: Process {
        id: fetchWindows

        property string buf: ""

        command: [service.scriptsDir + "/bash/wm-action", "list-windows"]
        running: false
        onExited: {
            try {
                // wm-action already outputs normalized field names for kwin
                // Just ensure focused window is sorted first for Alt+Tab ordering

                var windows = JSON.parse(fetchWindows.buf);
                var comp = service.compositor;
                if (comp === "hyprland") {
                    for (var i = 0; i < windows.length; i++) {
                        var w = windows[i];
                        w.id = w.address;
                        w.app_id = w.class || "";
                        w.workspace_id = w.workspace ? w.workspace.id : 0;
                        w.is_focused = w.focusHistoryID === 0;
                        w.is_floating = w.floating || false;
                    }
                    windows.sort(function(a, b) {
                        return (a.focusHistoryID || 0) - (b.focusHistoryID || 0);
                    });
                } else if (comp === "sway") {
                    for (var i = 0; i < windows.length; i++) {
                        var w = windows[i];
                        w.app_id = w.app_id || "";
                        w.workspace_id = w.num || 0;
                        w.is_focused = w.focused || false;
                        w.is_floating = w.type === "floating_con";
                    }
                } else if (comp === "kwin")
                    windows.sort(function(a, b) {
                    if (a.is_focused && !b.is_focused)
                        return -1;

                    if (!a.is_focused && b.is_focused)
                        return 1;

                    return 0;
                });
                else
                    windows.sort(function(a, b) {
                    var aTime = a.focus_timestamp ? (a.focus_timestamp.secs * 1e+09 + a.focus_timestamp.nanos) : 0;
                    var bTime = b.focus_timestamp ? (b.focus_timestamp.secs * 1e+09 + b.focus_timestamp.nanos) : 0;
                    return bTime - aTime;
                });
                service.windowList = windows;
            } catch (e) {
                service.windowList = [];
            }
            service.buildModel();
            if (service.compositor === "niri")
                service.captureAllWindows();

        }

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                fetchWindows.buf += data;
            }
        }

    }

    _refreshTimer: Timer {
        interval: 100
        onTriggered: {
            fetchWindows.buf = "";
            fetchWindows.running = true;
        }
    }

}
