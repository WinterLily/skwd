import "../.."
import QtQuick
import Quickshell.Io
pragma Singleton

QtObject {
    id: service

    property var metadataDb: ({
    })
    property bool loaded: false
    property var _probing: ({
    })
    property var _queue: []
    property bool _running: false
    property var _current: null
    property var _probeProcess

    signal metadataReady(string key)

    function getMetadata(key) {
        return metadataDb[key] || null;
    }

    function probeIfNeeded(key, path, type) {
        if (!path || metadataDb[key] || _probing[key])
            return ;

        _probing[key] = true;
        _queue.push({
            "key": key,
            "path": path,
            "type": type
        });
        _startNext();
    }

    function formatSize(bytes) {
        if (bytes >= 1.07374e+09)
            return (bytes / 1.07374e+09).toFixed(1) + " GB";

        if (bytes >= 1.04858e+06)
            return (bytes / 1.04858e+06).toFixed(1) + " MB";

        if (bytes >= 1024)
            return (bytes / 1024).toFixed(0) + " KB";

        return bytes + " B";
    }

    function formatExt(name) {
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(dot + 1).toUpperCase() : "";
    }

    function _startNext() {
        if (_running || _queue.length === 0)
            return ;

        _running = true;
        _current = _queue.shift();
        var p = DbService.shellQuote(_current.path);
        var cmd;
        if (_current.type === "video")
            cmd = "s=$(stat -c '%s' " + p + " 2>/dev/null) && " + "d=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 " + p + " 2>/dev/null | head -1) && " + "printf '%s\\t%s\\n' \"$s\" \"$(echo \"$d\" | tr ',' $'\\t')\"";
        else
            cmd = "s=$(stat -c '%s' " + p + " 2>/dev/null) && " + "d=$(magick identify -format $'%w\\t%h' " + DbService.shellQuote(_current.path + "[0]") + " 2>/dev/null) && " + "printf '%s\\t%s\\n' \"$s\" \"$d\"";
        _probeProcess.command = ["sh", "-c", cmd];
        _probeProcess.running = true;
    }

    Component.onCompleted: {
        var rows = DbService.query("SELECT key,filesize,width,height FROM meta WHERE filesize IS NOT NULL");
        for (var i = 0; i < rows.length; i++) {
            metadataDb[rows[i].key] = {
                "filesize": rows[i].filesize || 0,
                "width": rows[i].width || 0,
                "height": rows[i].height || 0
            };
        }
        metadataDb = metadataDb;
        loaded = true;
    }

    _probeProcess: Process {
        property string _out: ""

        onStarted: {
            _out = "";
        }
        onExited: {
            var cur = service._current;
            service._running = false;
            service._current = null;
            if (_out) {
                var parts = _out.split("\t");
                if (parts.length >= 3) {
                    var meta = {
                        "filesize": parseInt(parts[0]) || 0,
                        "width": parseInt(parts[1]) || 0,
                        "height": parseInt(parts[2]) || 0
                    };
                    var db = service.metadataDb;
                    db[cur.key] = meta;
                    service.metadataDb = db;
                    DbService.exec("UPDATE meta SET filesize=" + meta.filesize + ",width=" + meta.width + ",height=" + meta.height + " WHERE key=" + DbService.sqlStr(cur.key) + ";");
                    service.metadataReady(cur.key);
                }
            }
            delete service._probing[cur.key];
            service._startNext();
        }

        stdout: SplitParser {
            onRead: (data) => {
                return _probeProcess._out = data.trim();
            }
        }

    }

}
