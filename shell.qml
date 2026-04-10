// Imports
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qt.labs.platform
import "qml"
import "qml/bar"
import "qml/bar/lyrics"
import "qml/wallpaper" as Wallpaper
import "qml/wallpaper/services"


ShellRoot {
  id: root

  property string homeDir: Config.homeDir

  // IPC command listener (reads from FIFO pipe)
  // Supports: lock, powermenu, launcher, toggleBar, wallpaper,
  //   smarthome, switcherOpen/Next/Prev/Confirm/Cancel/Close,
  //   notifications, config
  Process {
    id: ipcListener
    running: true
    command: [Config.scriptsDir + "/bash/ipc-listener"]
    onExited: ipcRestartTimer.start()
    stdout: SplitParser {
      onRead: message => {
        var cmd = message.trim()
        console.log("IPC received:", cmd)
        if (cmd === "lock") {
          if (root.lockscreenInstance) root.lockscreenInstance.showing = true
        } else if (cmd === "powermenu") {
          if (root.powerMenuInstance) root.powerMenuInstance.showing = !root.powerMenuInstance.showing
        } else if (cmd === "launcher" || cmd === "applauncher") {
          if (root.appLauncherInstance) root.appLauncherInstance.showing = !root.appLauncherInstance.showing
        } else if (cmd === "toggleBar") {
          root.barVisible = !root.barVisible
        } else if (cmd === "wallpaper") {
          wallpaperSelectorLoader.active = !wallpaperSelectorLoader.active
        } else if (cmd === "smarthome") {
          if (root.smartHomeInstance) root.smartHomeInstance.toggle()
        } else if (cmd === "switcherOpen") {
          if (root.windowSwitcherInstance) root.windowSwitcherInstance.open()
        } else if (cmd === "switcherNext") {
          if (root.windowSwitcherInstance) {
            if (!root.windowSwitcherInstance.showing) {
              root.windowSwitcherInstance.open()
            } else {
              root.windowSwitcherInstance.next()
            }
          }
        } else if (cmd === "switcherPrev") {
          if (root.windowSwitcherInstance) {
            if (!root.windowSwitcherInstance.showing) {
              root.windowSwitcherInstance.open()
            } else {
              root.windowSwitcherInstance.prev()
            }
          }
        } else if (cmd === "switcherConfirm") {
          if (root.windowSwitcherInstance) root.windowSwitcherInstance.confirm()
        } else if (cmd === "switcherCancel") {
          if (root.windowSwitcherInstance) root.windowSwitcherInstance.cancel()
        } else if (cmd === "switcherClose") {
          if (root.windowSwitcherInstance) root.windowSwitcherInstance.closeSelected()
        } else if (cmd === "notifications") {
          if (root.notificationInstance) root.notificationInstance.toggleCenter()
        } else if (cmd === "config") {
          if (root.configPanelInstance) root.configPanelInstance.showing = !root.configPanelInstance.showing
        }
      }
    }
  }

  // IPC auto-restart (reconnect after 1s if pipe closes)
  Timer {
    id: ipcRestartTimer
    interval: 1000
    onTriggered: ipcListener.running = true
  }

  // Notification server
  NotificationServer {
    id: notificationServer
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    actionsSupported: true
    keepOnReload: true

    onNotification: notification => {

      var app = (notification.appName || "").toLowerCase()
      var summary = (notification.summary || "").toLowerCase()
      if ((app === "niri" || app === "hyprland" || app === "sway" || app === "kwin") && summary.indexOf("screenshot") !== -1) {
        notification.dismiss()
        return
      }
      notification.tracked = true
    }
  }


  // Tracked notification state
  property var notifications: notificationServer.trackedNotifications
  property int notificationCount: notifications ? notifications.values.length : 0
  property bool hasNotifications: notificationCount > 0

  // Color theme (loaded from matugen-generated palette)
  Colors {
    id: colors
  }
  property var colorsRef: colors


  // MPRIS music player detection - uses preferred player if active
  property var activePlayer: {
    if (!Mpris.players) return null
    let preferredPlaying = null
    let preferredAny = null
    let fallbackPlaying = null
    let fallbackAny = null
    for (let i = 0; i < Mpris.players.values.length; i++) {
      let player = Mpris.players.values[i]
      if (!player) continue
      let id = (player.identity || "").toLowerCase()

      let preferred = Config.preferredPlayer.toLowerCase()
      if (id.includes(preferred)) {
        if (player.isPlaying) preferredPlaying = player
        else if (!preferredAny) preferredAny = player
      }

      if (player.isPlaying && !fallbackPlaying) fallbackPlaying = player
      if (!fallbackAny) fallbackAny = player
    }

    return preferredPlaying || fallbackPlaying || preferredAny || fallbackAny
  }


  // Bar visibility state (persisted to cache file)
  property bool barVisible: true
  property bool stateLoaded: false

  FileView {
    id: barStateFile
    path: Config.cacheDir + "/bar-state"
    preload: true
    onFileChanged: {
      if (!root.stateLoaded) {
        var text = barStateFile.text().trim()
        if (text) root.barVisible = (text === "true")
        root.stateLoaded = true
      }
    }
  }


  // Load saved bar state on startup
  Component.onCompleted: {
    var text = barStateFile.text().trim()
    if (text) {
      root.barVisible = (text === "true")
      root.stateLoaded = true
    }
  }

  // Persist bar state on change
  onBarVisibleChanged: {
    if (root.stateLoaded) {
      barStateFile.setText(root.barVisible ? "true" : "false")
    }
  }

  // ---------------------------------------------------------------------------
  // Wallpaper subsystem
  // ---------------------------------------------------------------------------

  Wallpaper.Colors {
    id: wallpaperColors
  }

  // Restore last wallpaper once bootstrap has created the config dir
  Connections {
    target: BootstrapService
    function onReadyChanged() {
      if (BootstrapService.ready && Config.wallpaperSelectorEnabled)
        WallpaperApplyService.restore()
    }
  }

  // Start cache/optimize services once the wallpaper config file is readable
  property bool _wallServicesStarted: false
  Connections {
    target: Config
    function onConfigLoadedChanged() {
      if (Config.configLoaded && !root._wallServicesStarted)
        Qt.callLater(root._startWallServices)
    }
  }
  function _startWallServices() {
    if (!Config.wallpaperSelectorEnabled || _wallServicesStarted) return
    _wallServicesStarted = true
    WallpaperCacheService.rebuild()
    ImageOptimizeService.cleanTrash()
    VideoConvertService.cleanTrash()
  }

  // Wire watcher → cache
  Connections {
    target: WatcherService
    function onFileAdded(name, path, type) {
      WallpaperCacheService.processFiles([{name: name, src: path, type: type}])
    }
    function onFileRemoved(name, type) {
      WallpaperCacheService.removeFiles([{name: name, type: type}])
    }
    function onWeItemAdded(weId, weDir) {
      WallpaperCacheService.processWeItem(weId, weDir)
    }
    function onWeItemRemoved(weId) {
      WallpaperCacheService.removeFiles([{name: weId, type: "we"}])
    }
  }

  // Wire cache updates → selector UI + auto-optimize trigger
  Connections {
    target: WallpaperCacheService
    function onCacheReady(result) {
      WatcherService.start()
      _wallAutoOptimizeTimer.restart()
    }
    function onFileProcessed(key, entry) {
      if (wallpaperSelectorLoader.item?.selectorService)
        wallpaperSelectorLoader.item.selectorService.refreshFromDb()
      _wallAutoOptimizeTimer.restart()
    }
    function onFileRemoved(key) {
      if (wallpaperSelectorLoader.item?.selectorService)
        wallpaperSelectorLoader.item.selectorService.refreshFromDb()
    }
  }

  Connections {
    target: ImageOptimizeService
    function onFinished(optimized, skippedCount, failed) {
      if (optimized > 0 && wallpaperSelectorLoader.item?.selectorService)
        wallpaperSelectorLoader.item.selectorService.refreshFromDb()
    }
  }

  Connections {
    target: SteamDownloadService
    function onStateChanged() {
      if (wallpaperSelectorLoader.item?.swService)
        wallpaperSelectorLoader.item.swService.refreshDownloadStatus()
    }
    function onDownloadFinished(workshopId) {
      WallpaperCacheService.processWeItem(workshopId, Config.weDir + "/" + workshopId)
    }
  }

  Timer {
    id: _wallAutoOptimizeTimer
    interval: 5000
    onTriggered: {
      if (Config.autoOptimizeImages && !ImageOptimizeService.running)
        ImageOptimizeService.optimize(Config.imageOptimizePreset, Config.imageOptimizeResolution)
    }
  }

  // Wallpaper selector UI — loaded on demand, unloaded when closed
  Loader {
    id: wallpaperSelectorLoader
    active: false
    source: "qml/wallpaper/ui/WallpaperSelector.qml"
    onLoaded: {
      item.colors = Qt.binding(() => wallpaperColors)
      item.showing = true
    }
  }
  Connections {
    target: wallpaperSelectorLoader.item
    function onShowingChanged() {
      if (wallpaperSelectorLoader.item && !wallpaperSelectorLoader.item.showing)
        wallpaperSelectorLoader.active = false
    }
  }

  // quickshell-ipc handlers (for external scripts targeting this instance)
  IpcHandler {
    target: "wallpaper"
    function toggle() { wallpaperSelectorLoader.active = !wallpaperSelectorLoader.active }
    function open()   { wallpaperSelectorLoader.active = true }
    function close()  { wallpaperSelectorLoader.active = false }
  }

  IpcHandler {
    target: "steam-download"
    function download() { SteamDownloadService.pickUpRequest() }
    function retry()    { SteamDownloadService.retryAuthFailed() }
  }

  // ---------------------------------------------------------------------------
  // Lazy-loaded UI components (activated by Config flags)
  // ---------------------------------------------------------------------------

  Loader {
    id: appLauncherLoader
    active: Config.appLauncherEnabled
    source: "qml/launcher/AppLauncher.qml"
    onLoaded: item.colors = Qt.binding(() => colors)
  }

  Loader {
    id: lockscreenLoader
    active: Config.lockscreenEnabled
    source: "qml/lock/Lockscreen.qml"
    onLoaded: item.colors = Qt.binding(() => colors)
  }

  Loader {
    id: powerMenuLoader
    active: Config.powerMenuEnabled
    source: "qml/power/PowerMenu.qml"
    onLoaded: item.colors = Qt.binding(() => colors)
  }

  Loader {
    id: windowSwitcherLoader
    active: Config.windowSwitcherEnabled
    source: "qml/switcher/WindowSwitcher.qml"
    onLoaded: item.colors = Qt.binding(() => colors)
  }

  Loader {
    id: smartHomeLoader
    active: Config.smartHomeEnabled
    source: "qml/smarthome/SmartHome.qml"
    onLoaded: item.colors = Qt.binding(() => colors)
  }

  Loader {
    id: notificationLoader
    active: Config.notificationsEnabled
    source: "qml/notifications/NotificationPopup.qml"
    onLoaded: {
      item.colors = Qt.binding(() => colors)
      item.notifications = Qt.binding(() => root.notifications)
      item.barVisible = Qt.binding(() => root.barVisible)
    }
  }

  Loader {
    id: configPanelLoader
    active: true
    source: "qml/config-panel/ConfigPanel.qml"
    onLoaded: item.colors = Qt.binding(() => colors)
  }

  // Component instance references (null until loaded)
  property var appLauncherInstance: appLauncherLoader.item ?? null
  property var lockscreenInstance: lockscreenLoader.item ?? null
  property var powerMenuInstance: powerMenuLoader.item ?? null
  property var windowSwitcherInstance: windowSwitcherLoader.item ?? null
  property var smartHomeInstance: smartHomeLoader.item ?? null
  property var notificationInstance: notificationLoader.item ?? null
  property var configPanelInstance: configPanelLoader.item ?? null

  // System clock and audio sink tracking
  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }
  property var clockRef: clock

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }


  // System stats (single long-running process)
  // Format: cpu:N|mem:N|gpu:N|ct:N|gt:N|st:USAGE|USED|TOTAL|AVAIL
  property real cpuUsage: 0
  property real memUsage: 0
  property real gpuUsage: 0
  property real cpuTemp: 0
  property real gpuTemp: 0
  property real storageUsage: 0
  property string storageUsed: "0G"
  property string storageTotal: "0G"
  property string storageAvail: "0G"

  property var lyricsServiceRef: lyricsService

  LyricsIslandService {
    id: lyricsService
    installDir: Config.installDir
  }

  Process {
    id: sysStatsProcess
    command: [Config.scriptsDir + "/bash/system-stats"]
    running: Config.barEnabled
    onExited: sysStatsRestart.start()
    stdout: SplitParser {
      onRead: line => {

        var parts = line.trim().split("|")
        for (var i = 0; i < parts.length; i++) {
          var kv = parts[i].split(":")
          if (kv.length < 2) continue
          var key = kv[0]
          var val = kv.slice(1).join(":")
          if (key === "cpu") root.cpuUsage = parseFloat(val) || 0
          else if (key === "mem") root.memUsage = parseFloat(val) || 0
          else if (key === "gpu") root.gpuUsage = parseFloat(val) || 0
          else if (key === "ct") root.cpuTemp = parseFloat(val) || 0
          else if (key === "gt") root.gpuTemp = parseFloat(val) || 0
          else if (key === "st") {

            root.storageUsage = parseFloat(val) || 0
            if (i + 1 < parts.length) root.storageUsed = parts[i + 1] || "0G"
            if (i + 2 < parts.length) root.storageTotal = parts[i + 2] || "0G"
            if (i + 3 < parts.length) root.storageAvail = parts[i + 3] || "0G"
            break
          }
        }
      }
    }
  }
  Timer {
    id: sysStatsRestart
    interval: 2000
    onTriggered: sysStatsProcess.running = true
  }



  // Weather data (fetched from wttr.in)
  property string weatherCity: Config.weatherCity
  property string weatherTemp: "--"
  property string weatherDesc: ""
  property var weatherForecast: []
  property var weatherParts: []

  Process {
    id: weatherProcess
    command: ["curl", "-s", "wttr.in/" + root.weatherCity + "?format=j1"]
    running: Config.weatherEnabled
    onRunningChanged: {
      if (running) root.weatherParts = []
    }
    onExited: {
      weatherTimer.start()
      if (root.weatherParts.length === 0) return

      try {
        let json = JSON.parse(root.weatherParts.join(""))
        if (!json) return

        if (json.current_condition && json.current_condition[0]) {
          let curr = json.current_condition[0]
          root.weatherTemp = curr.temp_C + "°"
          root.weatherDesc = curr.weatherDesc[0].value
        }

        if (json.weather) {
          let forecast = []
          for (let i = 0; i < Math.min(3, json.weather.length); i++) {
            let day = json.weather[i]
            let date = new Date(day.date)
            let dayName = i === 0 ? "Today" : date.toLocaleDateString('en-US', {weekday: 'short'})
            forecast.push({
              day: dayName,
              high: day.maxtempC + "°",
              low: day.mintempC + "°",
              desc: day.hourly[4].weatherDesc[0].value.trim()
            })
          }
          root.weatherForecast = forecast
        }
      } catch (e) {
        console.log("Weather parse error:", e)
      }
    }
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => {
        root.weatherParts.push(data)
      }
    }
  }
  Timer {
    id: weatherTimer
    interval: Config.weatherPollMs
    onTriggered: weatherProcess.running = true
  }


  // Top bar instantiation
  property string barTheme: "minimal"

  Variants {
    model: {
      if (!Config.barEnabled || root.barTheme !== "minimal") return []
      return Array.from({length: Quickshell.screens.length}, (_, i) => i)
    }

    TopBar {
      property var modelData
      screen: Quickshell.screens[modelData] ?? Quickshell.screens[0]
      visible: !(root.lockscreenInstance && root.lockscreenInstance.showing)
      colors: root.colorsRef
      clock: root.clockRef
      barVisible: root.barVisible
      activePlayer: root.activePlayer
      cpuUsage: root.cpuUsage
      memUsage: root.memUsage
      gpuUsage: root.gpuUsage
      cpuTemp: root.cpuTemp
      gpuTemp: root.gpuTemp
      weatherDesc: root.weatherDesc
      weatherTemp: root.weatherTemp
      weatherCity: root.weatherCity
      weatherForecast: root.weatherForecast
      lyricsService: root.lyricsServiceRef
    }
  }
}
