import "../services"
import QtQuick
import Quickshell
import Quickshell.Io

// Window switcher service - uses CompositorService for native WM bindings
QtObject {
    id: service

    // External bindings (reduced - compositor handled by CompositorService)
    required property string configPath
    required property string homeDir
    required property string cacheDir
    // Window list and selection state
    property var windowList: CompositorService.windows
    property int selectedIndex: 0
    property bool preserveIndex: false
    // App config from apps.json (custom icons/names)
    property var appConfig: ({
    })
    property var _appConfigFile
    // Data model
    property var filteredModel
    // Screenshot capture process (only used for niri screenshots)
    property var _captureWindows

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

    // Build filtered model from window list (already normalized by CompositorService)
    function buildModel() {
        var prevIdx = selectedIndex;
        filteredModel.clear();
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            filteredModel.append({
                "winId": w.id || "",
                "title": w.title || "",
                "appId": w.appId || "",
                "workspaceId": w.workspaceId || 0,
                "isFocused": w.isFocused || false,
                "isFloating": w.isFloating || false
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
        // Only niri supports window screenshots
        if (!CompositorService.isNiri)
            return ;

        var cmds = ["mkdir -p " + thumbDir];
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (w.id)
                cmds.push("niri msg action screenshot-window --id " + w.id + " --path " + thumbDir + "/" + w.id + ".png 2>/dev/null");

        }
        _captureWindows.command = ["sh", "-c", cmds.join("; ")];
        _captureWindows.running = true;
    }

    // Actions
    function open() {
        selectedIndex = 0;
        preserveIndex = false;
        loadAppConfig();
        // Windows are already available via CompositorService.windows (reactive)
        buildModel();
        if (CompositorService.isNiri)
            captureAllWindows();

    }

    function focusWindow(winId) {
        // Find window in list and use CompositorService
        for (var i = 0; i < windowList.length; i++) {
            if (windowList[i].id === winId) {
                CompositorService.focusWindow(windowList[i]);
                return ;
            }
        }
    }

    function closeWindow(winId) {
        // Find window in list and use CompositorService
        for (var i = 0; i < windowList.length; i++) {
            if (windowList[i].id === winId) {
                CompositorService.closeWindow(windowList[i]);
                preserveIndex = true;
                break;
            }
        }
    }

    // Rebuild model when window list changes
    onWindowListChanged: {
        buildModel();
    }

    _appConfigFile: FileView {
        path: service.configPath
        preload: true
        watchChanges: true
        onFileChanged: _appConfigFile.reload()
    }

    filteredModel: ListModel {
    }

    _captureWindows: Process {
        command: ["sh", "-c", "true"]
        onExited: {
            service.screenshotCounter++;
        }
    }

}
