import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Hyprland compositor service using native Quickshell bindings
QtObject {
    id: service

    // Required properties for the unified API
    property var windows: []
    property var workspaces: []
    property var outputs: []

    // Signals
    signal windowsUpdated
    signal workspacesUpdated

    // Internal data from Hyprland
    property var _hyprWindows: Hyprland.toplevels
    property var _hyprWorkspaces: Hyprland.workspaces
    property var _hyprOutputs: Hyprland.monitors

    // Initialize and bind to Hyprland data
    Component.onCompleted: {
        updateWindows()
        updateWorkspaces()
        updateOutputs()
    }

    // Watch for changes - Hyprland uses different property names
    on_HhyprWindowsChanged: {
        updateWindows()
        windowsUpdated()
    }

    on_HhyprWorkspacesChanged: {
        updateWorkspaces()
        workspacesUpdated()
    }

    on_HhyprOutputsChanged: {
        updateOutputs()
    }

    // Normalize Hyprland's window (toplevel) data to unified format
    function updateWindows() {
        if (!Hyprland.toplevels) {
            service.windows = []
            return
        }

        const normalized = []
        for (const w of Hyprland.toplevels.values) {
            // Hyprland uses 'address' as window ID
            normalized.push({
                id: w.address ?? "",
                title: w.title ?? "",
                appId: w.class ?? "",  // Hyprland uses 'class' not 'appId'
                workspaceId: w.workspace?.id ?? 0,
                isFocused: w.focused ?? false,
                isFloating: w.floating ?? false,
                monitor: w.monitor ?? ""
            })
        }
        service.windows = normalized
    }

    // Normalize Hyprland's workspace data to unified format
    function updateWorkspaces() {
        if (!Hyprland.workspaces) {
            service.workspaces = []
            return
        }

        const normalized = []
        for (const ws of Hyprland.workspaces.values) {
            normalized.push({
                id: ws.id ?? -99,  // Hyprland special workspace IDs can be negative
                name: ws.name ?? "",
                isActive: ws.id === Hyprland.activeWorkspace?.id,
                isEmpty: ws.windows === 0
            })
        }
        service.workspaces = normalized
    }

    // Normalize outputs (monitors in Hyprland)
    function updateOutputs() {
        if (!Hyprland.monitors) {
            service.outputs = []
            return
        }

        const normalized = []
        for (const m of Hyprland.monitors.values) {
            normalized.push({
                name: m.name ?? "",
                make: m.make ?? "",
                model: m.model ?? "",
                isActive: m.focused ?? false  // Hyprland tracks focused monitor
            })
        }
        service.outputs = normalized
    }

    // API: Focus a window by its address
    function focusWindow(window) {
        if (window && window.id) {
            Hyprland.dispatch(`focuswindow address:${window.id}`)
            // Also bring to top
            Hyprland.dispatch(`alterzorder top,address:${window.id}`)
        }
    }

    // API: Close a window by its address
    function closeWindow(window) {
        if (window && window.id) {
            Hyprland.dispatch(`killwindow address:${window.id}`)
        }
    }

    // API: Focus a workspace
    function focusWorkspace(workspace) {
        if (workspace && workspace.id !== undefined) {
            Hyprland.dispatch(`workspace ${workspace.id}`)
        }
    }

    // API: Focus an output (monitor)
    function focusOutput(output) {
        if (output && output.name) {
            Hyprland.dispatch(`focusmonitor ${output.name}`)
        }
    }

    // API: Get currently focused output
    function getActiveOutput() {
        if (!Hyprland.monitors) return null
        for (const m of Hyprland.monitors.values) {
            if (m.focused) return m.name
        }
        return null
    }
}
