import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    // °C

    id: root

    // ──────────────────────────────────────────────────
    // Public values
    // ──────────────────────────────────────────────────
    property real cpuUsage: 0
    // percent 0–100
    property real memUsage: 0
    // percent 0–100
    property real gpuUsage: 0
    // percent 0–100 (AMD sysfs)
    property real cpuTemp: 0
    // °C
    property real gpuTemp: 0
    // ──────────────────────────────────────────────────
    // CPU usage — /proc/stat delta
    // ──────────────────────────────────────────────────
    property real _prevIdle: 0
    property real _prevTotal: 0
    property var _cpuTimer

    _cpuTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: cpuStatFile.reload()
    }

    property var cpuStatFile

    cpuStatFile: FileView {
        id: cpuStatFile

        path: "/proc/stat"
        onLoaded: {
            var line = text().split("\n")[0];
            var parts = line.trim().split(/\s+/);
            var user = parseFloat(parts[1]) || 0;
            var nice = parseFloat(parts[2]) || 0;
            var system = parseFloat(parts[3]) || 0;
            var idle = parseFloat(parts[4]) || 0;
            var iowait = parseFloat(parts[5]) || 0;
            var irq = parseFloat(parts[6]) || 0;
            var softirq = parseFloat(parts[7]) || 0;
            var steal = parseFloat(parts[8]) || 0;
            var total = user + nice + system + idle + iowait + irq + softirq + steal;
            var dIdle = idle - root._prevIdle;
            var dTotal = total - root._prevTotal;
            if (dTotal > 0)
                root.cpuUsage = Math.round((dTotal - dIdle) * 100 / dTotal);

            root._prevIdle = idle;
            root._prevTotal = total;
        }
    }

    // ──────────────────────────────────────────────────
    // Memory usage — /proc/meminfo
    // ──────────────────────────────────────────────────
    property var _memTimer

    _memTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: memInfoFile.reload()
    }

    property var memInfoFile

    memInfoFile: FileView {
        id: memInfoFile

        path: "/proc/meminfo"
        onLoaded: {
            var lines = text().split("\n");
            var total = 0, available = 0;
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i];
                if (l.startsWith("MemTotal:"))
                    total = parseInt(l.split(/\s+/)[1]) || 0;
                else if (l.startsWith("MemAvailable:"))
                    available = parseInt(l.split(/\s+/)[1]) || 0;
            }
            if (total > 0)
                root.memUsage = Math.round((total - available) * 100 / total);

        }
    }

    // ──────────────────────────────────────────────────
    // CPU temperature — probe hwmon0..15 for k10temp / zenpower / coretemp
    // ──────────────────────────────────────────────────
    readonly property var _cpuSensorNames: ["k10temp", "zenpower", "coretemp"]
    property string _cpuTempPath: ""
    property var cpuHwmonNameProbe

    cpuHwmonNameProbe: FileView {
        id: cpuHwmonNameProbe

        property int idx: 0

        function probe() {
            path = "/sys/class/hwmon/hwmon" + idx + "/name";
            reload();
        }

        printErrors: false
        onLoaded: {
            var name = text().trim();
            if (root._cpuSensorNames.indexOf(name) >= 0) {
                root._cpuTempPath = "/sys/class/hwmon/hwmon" + idx + "/temp1_input";
                cpuTempPollTimer.start();
            } else {
                idx++;
                if (idx < 16)
                    Qt.callLater(probe);

            }
        }
        onLoadFailed: {
            idx++;
            if (idx < 16)
                Qt.callLater(probe);

        }
    }

    property var cpuTempPollTimer

    cpuTempPollTimer: Timer {
        id: cpuTempPollTimer

        interval: 5000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: cpuTempFile.reload()
    }

    property var cpuTempFile

    cpuTempFile: FileView {
        id: cpuTempFile

        path: root._cpuTempPath
        printErrors: false
        onLoaded: root.cpuTemp = Math.round(parseInt(text().trim()) / 1000)
    }

    // ──────────────────────────────────────────────────
    // GPU — AMD sysfs only (amdgpu hwmon for temp, drm for utilization)
    // ──────────────────────────────────────────────────
    property string _gpuTempPath: ""
    property string _gpuBusyPath: ""
    property var gpuHwmonNameProbe

    gpuHwmonNameProbe: FileView {
        id: gpuHwmonNameProbe

        property int idx: 0

        function probe() {
            path = "/sys/class/hwmon/hwmon" + idx + "/name";
            reload();
        }

        printErrors: false
        onLoaded: {
            if (text().trim() === "amdgpu") {
                root._gpuTempPath = "/sys/class/hwmon/hwmon" + idx + "/temp1_input";
                amdBusyProbe.probe(0);
                gpuTempPollTimer.start();
            } else {
                idx++;
                if (idx < 16)
                    Qt.callLater(probe);

            }
        }
        onLoadFailed: {
            idx++;
            if (idx < 16)
                Qt.callLater(probe);

        }
    }

    // Scan drm/card0..3 for gpu_busy_percent
    property var amdBusyProbe

    amdBusyProbe: FileView {
        id: amdBusyProbe

        property int cardIdx: 0

        function probe(i) {
            cardIdx = i;
            path = "/sys/class/drm/card" + i + "/device/gpu_busy_percent";
            reload();
        }

        printErrors: false
        onLoaded: {
            root._gpuBusyPath = path;
            gpuBusyPollTimer.start();
        }
        onLoadFailed: {
            var next = cardIdx + 1;
            if (next < 4)
                probe(next);

        }
    }

    property var gpuTempPollTimer

    gpuTempPollTimer: Timer {
        id: gpuTempPollTimer

        interval: 5000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: gpuTempFile.reload()
    }

    property var gpuTempFile

    gpuTempFile: FileView {
        id: gpuTempFile

        path: root._gpuTempPath
        printErrors: false
        onLoaded: root.gpuTemp = Math.round(parseInt(text().trim()) / 1000)
    }

    property var gpuBusyPollTimer

    gpuBusyPollTimer: Timer {
        id: gpuBusyPollTimer

        interval: 3000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: gpuBusyFile.reload()
    }

    property var gpuBusyFile

    gpuBusyFile: FileView {
        id: gpuBusyFile

        path: root._gpuBusyPath
        printErrors: false
        onLoaded: root.gpuUsage = parseInt(text().trim()) || 0
    }

    // ──────────────────────────────────────────────────
    Component.onCompleted: {
        cpuHwmonNameProbe.probe();
        gpuHwmonNameProbe.probe();
    }
}
