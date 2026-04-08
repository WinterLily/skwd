import Quickshell.Io
import QtQuick

QtObject {
  id: service

  required property string installDir

  property var audioBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0]

  property var _cavaProcess: Process {
    id: cavaProcess
    command: ["cava", "-p", service.installDir + "/ext/cava/cava-bar.conf"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        let raw = data.trim()
        if (!raw) return
        let vals = raw.split(";").filter(s => s !== "").map(s => parseInt(s) || 0)
        if (vals.length > 0) service.audioBars = vals
      }
    }
    onExited: cavaRestartTimer.start()
  }

  property var _cavaRestartTimer: Timer {
    id: cavaRestartTimer
    interval: 2000
    onTriggered: { if (!cavaProcess.running) cavaProcess.running = true }
  }
}
