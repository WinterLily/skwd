import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property var windows: []
    property var workspaces: []
    property int focusedWindowIndex: -1
    property bool initialized: false

    signal workspaceChanged
    signal activeWindowChanged
    signal windowListChanged

    Timer {
        id: updateTimer
        interval: 50
        repeat: false
        onTriggered: {
            safeUpdateWindows()
        }
    }

    function initialize() {
        if (initialized) return
        try {
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            Qt.callLater(() => {
                safeUpdateWorkspaces()
                safeUpdateWindows()
            })
            initialized = true
        } catch (e) {
            console.warn("HyprlandService: Failed to initialize:", e)
        }
    }

    function safeUpdateWorkspaces() {
        try {
            if (!Hyprland.workspaces || !Hyprland.workspaces.values) return

            const hlWorkspaces = Hyprland.workspaces.values
            const occupiedIds = getOccupiedWorkspaceIds()
            const normalized = []

            for (var i = 0; i < hlWorkspaces.length; i++) {
                const ws = hlWorkspaces[i]
                if (!ws || ws.id < 1) continue
                normalized.push({
                    "id": ws.id,
                    "idx": ws.id,
                    "name": ws.name || "",
                    "output": (ws.monitor && ws.monitor.name) ? ws.monitor.name : "",
                    "isActive": ws.active === true,
                    "isFocused": ws.focused === true,
                    "isUrgent": ws.urgent === true,
                    "isOccupied": occupiedIds[ws.id] === true
                })
            }

            workspaces = normalized
            workspaceChanged()
        } catch (e) {
            console.warn("HyprlandService: Error updating workspaces:", e)
        }
    }

    function getOccupiedWorkspaceIds() {
        const occupiedIds = {}
        try {
            if (!Hyprland.toplevels || !Hyprland.toplevels.values) return occupiedIds
            const hlToplevels = Hyprland.toplevels.values
            for (var i = 0; i < hlToplevels.length; i++) {
                const toplevel = hlToplevels[i]
                if (!toplevel) continue
                try {
                    const wsId = toplevel.workspace ? toplevel.workspace.id : null
                    if (wsId !== null && wsId !== undefined) occupiedIds[wsId] = true
                } catch (e) {}
            }
        } catch (e) {}
        return occupiedIds
    }

    function safeUpdateWindows() {
        try {
            if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
                windows = []
                focusedWindowIndex = -1
                windowListChanged()
                return
            }

            const hlToplevels = Hyprland.toplevels.values
            const windowsList = []
            let newFocusedIndex = -1

            for (var i = 0; i < hlToplevels.length; i++) {
                const toplevel = hlToplevels[i]
                if (!toplevel) continue
                const windowData = extractWindowData(toplevel)
                if (windowData) {
                    windowsList.push(windowData)
                    if (windowData.isFocused) {
                        newFocusedIndex = windowsList.length - 1
                    }
                }
            }

            windows = windowsList

            if (newFocusedIndex !== focusedWindowIndex) {
                focusedWindowIndex = newFocusedIndex
                activeWindowChanged()
            }
            windowListChanged()
        } catch (e) {
            console.warn("HyprlandService: Error updating windows:", e)
        }
    }

    function extractWindowData(toplevel) {
        if (!toplevel) return null
        try {
            const windowId = safeGetProperty(toplevel, "address", "")
            if (!windowId) return null

            const appId = getAppId(toplevel)
            const title = getAppTitle(toplevel)
            const wsId = toplevel.workspace ? toplevel.workspace.id : null
            const focused = toplevel.activated === true
            const output = toplevel.monitor?.name || ""

            return {
                "id": windowId,
                "title": title,
                "appId": appId,
                "workspaceId": wsId || -1,
                "isFocused": focused,
                "isFloating": toplevel.floating === true,
                "output": output
            }
        } catch (e) {
            return null
        }
    }

    function getAppTitle(toplevel) {
        try {
            const title = toplevel.wayland.title
            if (title) return title
        } catch (e) {}
        return safeGetProperty(toplevel, "title", "")
    }

    function getAppId(toplevel) {
        if (!toplevel) return ""
        try {
            const appId = toplevel.wayland.appId
            if (appId) return appId
        } catch (e) {}
        const directClass = safeGetProperty(toplevel, "class", "")
        if (directClass) return directClass
        return safeGetProperty(toplevel, "initialClass", "")
    }

    function safeGetProperty(obj, prop, defaultValue) {
        try {
            const value = obj[prop]
            if (value !== undefined && value !== null) return String(value)
        } catch (e) {}
        return defaultValue
    }

    Connections {
        target: Hyprland.workspaces
        enabled: initialized
        function onValuesChanged() {
            safeUpdateWorkspaces()
        }
    }

    Connections {
        target: Hyprland.toplevels
        enabled: initialized
        function onValuesChanged() {
            updateTimer.restart()
        }
    }

    Connections {
        target: Hyprland
        enabled: initialized
        function onRawEvent(event) {
            Hyprland.refreshWorkspaces()
            safeUpdateWorkspaces()
            updateTimer.restart()
        }
    }

    function switchToWorkspace(workspace) {
        try {
            Hyprland.dispatch(`workspace ${workspace.idx}`)
        } catch (e) {
            console.warn("HyprlandService: Failed to switch workspace:", e)
        }
    }

    function focusWindow(window) {
        try {
            if (!window || !window.id) return
            const windowId = window.id.toString()
            Hyprland.dispatch(`focuswindow address:0x${windowId}`)
            Hyprland.dispatch(`alterzorder top,address:0x${windowId}`)
        } catch (e) {
            console.warn("HyprlandService: Failed to focus window:", e)
        }
    }

    function closeWindow(window) {
        try {
            Hyprland.dispatch(`killwindow address:0x${window.id}`)
        } catch (e) {
            console.warn("HyprlandService: Failed to close window:", e)
        }
    }

    function getActiveOutput() {
        try {
            if (!Hyprland.monitors) return null
            for (const m of Hyprland.monitors.values) {
                if (m.focused) return m.name
            }
        } catch (e) {}
        return null
    }

    function logout() {
        Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
    }
}
