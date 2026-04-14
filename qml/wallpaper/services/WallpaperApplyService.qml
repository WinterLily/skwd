import "../.."
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: service

    readonly property string wallpaperDir: Config.wallpaperDir
    readonly property string videoDir: Config.videoDir
    readonly property string weDir: Config.weDir
    readonly property string weAssetsDir: Config.weAssetsDir
    readonly property string cacheDir: Config.wallCacheDir
    readonly property string mainMonitor: Quickshell.screens[0]?.name ?? ""
    property string matugenScheme: "scheme-fidelity"
    property bool wallpaperMute: true
    readonly property string _matugenConfig: cacheDir + "/matugen-config.toml"
    property bool _stateFileLoaded: false
    property var _stateFile
    property bool _restoring: false
    property bool _restoreRequested: false
    property var _pendingAction: null
    property var _killProcess
    property bool _weKilling: false
    property var _awwwStderr: []
    property var _awwwProcess
    property var _mpvProcess
    property var _awwwDaemonProcess
    property var _weStderr: []
    property var _weStdout: []
    property var _weProcess
    property string _pendingWeId: ""
    property var _weProjectStdout: []
    property var _weReadProject
    property var _symLinkProcess
    property string _wePreviewStdout: ""
    property var _wePreviewFallbackProc
    property var _videoThumbStdout: []
    property var _videoThumbProcess
    property var _weFindPreviewStdout: []
    property var _weFindPreview
    property var _copyAndTheme
    property bool _copyAndThemeMode: true
    property var reloadComponent
    property var _reapplyProcess
    property bool _requestedMode: true
    property bool _reapplyRunning: false

    signal wallpaperApplied(string type, string name, string path)

    function applyStatic(path) {
        console.log("WallpaperApplyService.applyStatic:", path, "wallpaperDir:", wallpaperDir);
        _weKilling = true;
        weProcess.running = false;
        _saveState("static", path, "");
        awwwProcess.command = ["sh", "-c", "pkill mpvpaper 2>/dev/null; " + "pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null; " + "rm -f " + JSON.stringify(videoDir + "/lockscreen-video.mp4") + "; " + "if ! pgrep -x awww-daemon >/dev/null; then " + "  setsid awww-daemon >/dev/null 2>&1 & disown; " + "  for i in 1 2 3 4 5; do sleep 0.3; pgrep -x awww-daemon >/dev/null && break; done; " + "fi; " + "awww img " + JSON.stringify(path) + " --transition-type wipe --transition-angle 45 --transition-duration 0.5"];
        awwwProcess.running = true;
        _extractAndTheme(path);
        wallpaperApplied("static", _basename(path), path);
    }

    function applyVideo(path) {
        _weKilling = true;
        weProcess.running = false;
        _saveState("video", path, "");
        mpvProcess.command = ["sh", "-c", "pkill awww 2>/dev/null; pkill awww-daemon 2>/dev/null; " + "pkill mpvpaper 2>/dev/null; " + "pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null; " + "rm -f " + JSON.stringify(videoDir + "/lockscreen-video.mp4") + "; " + "nohup setsid mpvpaper -o 'loop --hwdec=vaapi --vo=dmabuf-wayland --vf=fps=30" + (wallpaperMute ? " --mute=yes" : "") + "' '*' " + JSON.stringify(path) + " </dev/null >/dev/null 2>&1 &"];
        mpvProcess.running = true;
        _extractVideoThumb(path);
        wallpaperApplied("video", _basename(path), path);
    }

    function applyWE(weId) {
        console.log("WallpaperApplyService.applyWE:", weId);
        _saveState("we", "", weId);
        _pendingAction = function _pendingAction() {
            _launchWE(weId);
            _extractWEThumb(weId);
            wallpaperApplied("we", weId, weDir + "/" + weId);
        };
        _killAll();
    }

    function restore() {
        _restoreRequested = true;
        _tryRestore();
    }

    function _tryRestore() {
        if (!_restoreRequested || !_stateFileLoaded)
            return ;

        _restoreRequested = false;
        var text = _stateFile.text().trim();
        if (!text)
            return ;

        _restoring = true;
        try {
            var state = JSON.parse(text);
            if (state.type === "static" && state.path)
                applyStatic(state.path);
            else if (state.type === "video" && state.path)
                applyVideo(state.path);
            else if (state.type === "we" && state.we_id)
                applyWE(state.we_id);
            else
                _restoring = false;
        } catch (e) {
            console.log("WallpaperApplyService: restore failed:", e);
            _restoring = false;
        }
    }

    function _saveState(type, path, weId) {
        var obj = {
            "type": type
        };
        if (path)
            obj.path = path;

        if (weId)
            obj.we_id = weId;

        _stateFile.setText(JSON.stringify(obj));
    }

    function _killAll() {
        _weKilling = true;
        weProcess.running = false;
        killProcess.command = ["sh", "-c", "pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null; " + "pkill mpvpaper 2>/dev/null; " + "pkill awww 2>/dev/null; " + "pkill awww-daemon 2>/dev/null; " + "rm -f " + JSON.stringify(videoDir + "/lockscreen-video.mp4") + "; " + "sleep 2; true"];
        killProcess.running = true;
    }

    function _launchWE(weId) {
        _weProjectStdout = [];
        _weReadProject.command = ["cat", weDir + "/" + weId + "/project.json"];
        _weReadProject.running = true;
        _pendingWeId = weId;
    }

    function _launchWEScene(weId) {
        // Clear kill guard — we're about to start a new scene, not kill one
        _weKilling = false;
        var mons = Quickshell.screens.map(function(s) {
            return s.name;
        });
        // Build the actual linux-wallpaperengine argument list
        var weArgs = ["linux-wallpaperengine"];
        if (service.wallpaperMute)
            weArgs.push("--silent");

        weArgs.push("--no-fullscreen-pause", "--noautomute");
        for (var i = 0; i < mons.length; i++) {
            weArgs.push("--scaling", "fill");
            weArgs.push("--screen-root", mons[i]);
        }
        if (service.weAssetsDir)
            weArgs.push("--assets-dir", service.weAssetsDir);

        weArgs.push(weId);
        console.log("WallpaperApplyService: launching WE scene id=" + weId + " args=" + weArgs.join(" "));
        weProcess.command = ["bash", "--login", "-c", 'exec "$@"', "--"].concat(weArgs);
        weProcess.running = true;
    }

    function _applyWePreviewFallback(weId) {
        var basePath = weDir + "/" + weId;
        _wePreviewFallbackProc.command = ["sh", "-c", "for p in " + JSON.stringify(basePath) + "/preview.jpg " + JSON.stringify(basePath) + "/preview.png " + JSON.stringify(basePath) + "/preview.gif; do " + "[ -f \"$p\" ] && echo \"$p\" && exit 0; done; exit 1"];
        _wePreviewFallbackProc.running = true;
    }

    function _extractAndTheme(path) {
        _reapplyProcess.running = false;
        _copyAndTheme.running = false;
        _copyAndThemeMode = ColorMode.isDark;
        _requestedMode = ColorMode.isDark;
        _copyAndTheme.command = ["sh", "-c", "cp " + JSON.stringify(path) + " " + JSON.stringify(wallpaperDir + "/wallpaper.jpg") + " 2>/dev/null; " + _matugenCmd(path)];
        _copyAndTheme.running = true;
    }

    function _extractVideoThumb(videoPath) {
        var name = _basename(videoPath).replace(/\.[^.]+$/, "") + ".jpg";
        var thumbDir = cacheDir + "/wallpaper/video-thumbs";
        var thumbPath = thumbDir + "/" + name;
        _reapplyProcess.running = false;
        _videoThumbProcess.running = false;
        _copyAndThemeMode = ColorMode.isDark;
        _requestedMode = ColorMode.isDark;
        _videoThumbProcess.command = ["sh", "-c", "mkdir -p " + JSON.stringify(thumbDir) + "; " + "[ -f " + JSON.stringify(thumbPath) + " ] || " + ImageService.videoThumbnailCmd(JSON.stringify(videoPath), JSON.stringify(thumbPath), 0) + "; " + "cp " + JSON.stringify(thumbPath) + " " + JSON.stringify(wallpaperDir + "/wallpaper.jpg") + " 2>/dev/null; " + _matugenCmd(thumbPath)];
        _videoThumbProcess.running = true;
    }

    function _extractWEThumb(weId) {
        _weFindPreviewStdout = [];
        _weFindPreview.command = ["find", weDir + "/" + weId, "-maxdepth", "1", "-iname", "preview.*", "-type", "f"];
        _weFindPreview.running = true;
    }

    function reapplyTheme() {
        if (!Config.matugenEnabled)
            return ;
        if (_reapplyRunning)
            return ;

        var text = _stateFile.text().trim();
        if (!text)
            return ;

        try {
            var state = JSON.parse(text);
            var path = state.path || (Config.wallpaperDir + "/wallpaper.jpg");
            _reapplyRunning = true;
            _requestedMode = ColorMode.isDark;
            _reapplyProcess.running = false;
            _reapplyProcess.command = ["sh", "-c", _matugenCmd(path)];
            _reapplyProcess.running = true;
        } catch (e) {
            console.log("WallpaperApplyService.reapplyTheme: failed to read state:", e);
            _reapplyRunning = false;
        }
    }

    function _matugenCmd(imagePath) {
        if (!Config.matugenEnabled)
            return "true";

        var mode = ColorMode.isDark ? "dark" : "light";
        var imgArg = " image -t " + JSON.stringify(matugenScheme) + " --mode " + mode + " $(matugen --version 2>/dev/null | grep -qE '^matugen [4-9]' && echo '--source-color-index 0') " + JSON.stringify(imagePath);
        var defaultCfg = Config.defaultMatugenConfig;
        var matugen = "command -v matugen >/dev/null && { " + "matugen -c " + JSON.stringify(_matugenConfig) + imgArg + "; " + (defaultCfg ? "[ -f " + JSON.stringify(defaultCfg) + " ] && matugen -c " + JSON.stringify(defaultCfg) + imgArg + "; " : "") + "true; } || true";
        return matugen;
    }

    function _propagateColors() {
        if (!Config.matugenEnabled)
            return ;

        var integrations = Config.integrations;
        console.log("propagateColors: running", integrations.length, "integrations");
        for (var i = 0; i < integrations.length; i++) {
            var reload = integrations[i].reload;
            if (!reload)
                continue;

            var resolved = Config._resolve(reload);
            if (resolved.indexOf("/") >= 0 && resolved.indexOf(" ") < 0)
                _runReload("sh " + JSON.stringify(resolved));
            else
                _runReload(resolved);
        }
        _runReload("command -v notify-send >/dev/null && notify-send 'Wallpaper Changed' || true");
        // Force-reload Colors.qml by path — inotify misses atomic (rename-based) writes
        Colors.colorFileView.reload();
    }

    function _runReload(cmd) {
        console.log("runReload:", cmd);
        var proc = reloadComponent.createObject(service);
        proc.command = ["sh", "-c", cmd];
        proc.exited.connect(function() {
            proc.destroy();
        });
        proc.running = true;
    }

    function _runPostProcessing(type, name, path) {
        if (_restoring && !Config.postProcessOnRestore)
            return ;

        var cmds = Config.postProcessing;
        if (!cmds || cmds.length === 0)
            return ;

        for (var i = 0; i < cmds.length; i++) {
            var cmd = cmds[i];
            if (!cmd)
                continue;

            cmd = cmd.replace(/%type%/g, type).replace(/%name%/g, name).replace(/%path%/g, path);
            _runDetached(cmd);
        }
    }

    function _runDetached(cmd) {
        console.log("runDetached:", cmd);
        var proc = reloadComponent.createObject(service);
        proc.command = ["sh", "-c", "nohup setsid sh -c " + JSON.stringify(cmd) + " </dev/null >/dev/null 2>&1 &"];
        proc.exited.connect(function() {
            proc.destroy();
        });
        proc.running = true;
    }

    function _basename(path) {
        var parts = path.split("/");
        return parts[parts.length - 1];
    }

    Component.onCompleted: {
        var data = Config._data;
        if (data.matugen) {
            if (data.matugen.scheme_type)
                matugenScheme = data.matugen.scheme_type;

        }
        if (data.wallpaper_mute !== undefined)
            wallpaperMute = data.wallpaper_mute;

        ColorMode.isDarkChanged.connect(reapplyTheme);
    }
    onWallpaperApplied: function(type, name, path) {
        _runPostProcessing(type, name, path);
        _restoring = false;
    }

    _stateFile: FileView {
        path: service.cacheDir + "/last-wallpaper.json"
        preload: true
        onLoaded: {
            service._stateFileLoaded = true;
            service._tryRestore();
        }
    }

    _killProcess: Process {
        id: killProcess

        onExited: {
            if (service._pendingAction) {
                var action = service._pendingAction;
                service._pendingAction = null;
                action();
            }
        }
    }

    _awwwProcess: Process {
        id: awwwProcess

        onExited: function(code, status) {
            console.log("WallpaperApplyService: awww exited code=" + code + " status=" + status);
            if (_awwwStderr.length > 0)
                console.log("WallpaperApplyService: awww stderr:", _awwwStderr.join(""));

            _awwwStderr = [];
        }

        stderr: SplitParser {
            onRead: (data) => {
                return service._awwwStderr.push(data);
            }
        }

    }

    _mpvProcess: Process {
        id: mpvProcess
    }

    _awwwDaemonProcess: Process {
        id: awwwDaemonProcess
    }

    _weProcess: Process {
        id: weProcess

        onExited: function(code, status) {
            var wasKilling = service._weKilling;
            service._weKilling = false;
            var out = service._weStdout.join("").trim();
            var err = service._weStderr.join("").trim();
            service._weStdout = [];
            service._weStderr = [];
            if (wasKilling)
                return ;

            if (out)
                console.log("WallpaperApplyService: WE stdout:", out);

            if (err)
                console.log("WallpaperApplyService: WE stderr:", err);

            if (code !== 0 && service._pendingWeId) {
                console.log("WallpaperApplyService: WE scene exited code=" + code + " for id=" + service._pendingWeId + ", falling back to preview image");
                service._applyWePreviewFallback(service._pendingWeId);
            } else if (code === 0 && service._pendingWeId) {
                console.log("WallpaperApplyService: WE scene exited cleanly (code=0) for id=" + service._pendingWeId);
            }
        }

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                return service._weStdout.push(data);
            }
        }

        stderr: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                return service._weStderr.push(data);
            }
        }

    }

    _weReadProject: Process {
        id: weReadProject

        onExited: {
            var text = _weProjectStdout.join("");
            try {
                var proj = JSON.parse(text);
                var weType = (proj.type || "scene").toLowerCase();
                var weFile = proj.file || "";
                var id = service._pendingWeId;
                var basePath = service.weDir + "/" + id;
                console.log("WallpaperApplyService: WE project id=" + id + " type=" + weType + " file=" + weFile);
                if (weType === "video" && weFile) {
                    var videoPath = basePath + "/" + weFile;
                    console.log("WallpaperApplyService: WE video path:", videoPath);
                    _symLinkProcess.command = ["ln", "-sf", videoPath, service.videoDir + "/lockscreen-video.mp4"];
                    _symLinkProcess.running = true;
                    weProcess.command = ["sh", "-c", "pkill mpvpaper 2>/dev/null; " + "nohup setsid mpvpaper -o 'loop --hwdec=vaapi --vo=dmabuf-wayland --vf=fps=30" + (service.wallpaperMute ? " --mute=yes" : "") + "' '*' " + JSON.stringify(videoPath) + " </dev/null >/dev/null 2>&1 &"];
                    weProcess.running = true;
                } else {
                    _launchWEScene(id);
                }
            } catch (e) {
                console.log("WallpaperApplyService: failed to parse project.json for id=" + service._pendingWeId + " error=" + e);
                service._launchWEScene(service._pendingWeId);
            }
        }

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                return _weProjectStdout.push(data);
            }
        }

    }

    _symLinkProcess: Process {
        id: symLinkProcess
    }

    _wePreviewFallbackProc: Process {
        onExited: function(code) {
            var preview = service._wePreviewStdout.trim();
            service._wePreviewStdout = "";
            if (code === 0 && preview) {
                console.log("WallpaperApplyService: applying WE preview fallback:", preview);
                service.applyStatic(preview);
            }
        }

        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                return service._wePreviewStdout += data;
            }
        }

    }

    _videoThumbProcess: Process {
        id: videoThumbProcess

        onExited: function(code, status) {
            if (status !== 0)
                return ;
            service._propagateColors();
        }
    }

    _weFindPreview: Process {
        id: weFindPreview

        onExited: {
            var preview = _weFindPreviewStdout.join("").trim().split("\n")[0];
            if (preview) {
                service._reapplyProcess.running = false;
                service._copyAndTheme.running = false;
                service._copyAndThemeMode = ColorMode.isDark;
                service._requestedMode = ColorMode.isDark;
                _copyAndTheme.command = ["sh", "-c", "cp " + JSON.stringify(preview) + " " + JSON.stringify(service.wallpaperDir + "/wallpaper.jpg") + " 2>/dev/null; " + service._matugenCmd(preview)];
                _copyAndTheme.running = true;
            }
        }

        stdout: SplitParser {
            onRead: (data) => {
                return _weFindPreviewStdout.push(data);
            }
        }

    }

    _copyAndTheme: Process {
        id: copyAndThemeProcess

        onExited: function(code, status) {
            if (status !== 0)
                return ;
            service._propagateColors();
        }
    }

    _reapplyProcess: Process {
        id: reapplyProcess

        onExited: function(code, status) {
            service._reapplyRunning = false;
            if (status !== 0)
                return ;
            service._propagateColors();
        }
    }

    reloadComponent: Component {
        Process {
        }

    }

}
