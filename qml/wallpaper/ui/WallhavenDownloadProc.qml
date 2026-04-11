import QtQuick
import Quickshell.Io

Process {
    id: dlProc

    property string whId
    property string dest
    property var _verifyProc

    _verifyProc: Process {
        property string _output: ""

        command: ["file", "--brief", "--mime-type", dlProc.dest]
        onExited: function(exitCode, exitStatus) {
            var mime = _output.toLowerCase();
            if (exitCode === 0 && mime.indexOf("image/") === 0)
                dlProc.done(dlProc.whId, true);
            else
                _cleanupProc.running = true;
        }

        stdout: SplitParser {
            onRead: (data) => {
                dlProc._verifyProc._output = data.trim();
            }
        }

    }

    property var _cleanupProc

    _cleanupProc: Process {
        command: ["rm", "-f", dlProc.dest]
        onExited: function() {
            dlProc.done(dlProc.whId, false);
        }
    }

    signal progressUpdate(string id, real pct)
    signal done(string id, bool success)

    onExited: function(exitCode, exitStatus) {
        if (exitCode === 0) {
            dlProc.progressUpdate(dlProc.whId, 1);
            _verifyProc.running = true;
        } else {
            dlProc.done(dlProc.whId, false);
        }
    }

    stderr: SplitParser {
        splitMarker: "\r"
        onRead: (data) => {
            var match = data.match(/([\d.]+)\s*%/);
            if (match)
                dlProc.progressUpdate(dlProc.whId, parseFloat(match[1]) / 100);

        }
    }

}
