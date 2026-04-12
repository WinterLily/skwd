import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Niri

// Niri compositor service using native Quickshell bindings
QtObject {
    id: service

    // Required properties for the unified API
    property var windows: []
    property var workspaces: []
    property var outputs: []

    // Signals
    signal windowsUpdated
    signal workspacesUpdated

    // Internal data from Niri
    property var _niriWindows: Niri.windows
    property var _niriWorkspaces: Niri.workspaces
    property var _niriOutputs: Niri.outputs

    // Initialize and bind to Niri data
    Component.onCompleted: {
        updateWindows()
        updateWorkspaces()
        updateOutputs()
    }

    // Watch for changes
    on_NniriWindowsChanged: {
        updateWindows()
        windowsUpdated()
    }

    on_NniriWorkspacesChanged: {
        updateWorkspaces()
        workspacesUpdated()
    }

    on_NniriOutputsChanged: {
        updateOutputs()
    }

    // Normalize Niri's window data to unified format
    function updateWindows() {
        if (!Niri.windows) {
            service.windows = []
            return
        }

        const normalized = []
        for (const w of Niri.windows.values) {
            normalized.push({
                id: w.id ?? "",
                title: w.title ?? "",
                appId: w.appId ?? "",
                workspaceId: w.workspace?.id ?? 0,
                isFocused: w.isFocused ?? false,
                isFloating: false,  // Niri doesn't have traditional floating
                output: w.output?.name ?? ""
            })
        }
        service.windows = normalized
    }

    // Normalize Niri's workspace data to unified format
    function updateWorkspaces() {
        if (!Niri.workspaces) {
            service.workspaces = []
            return
        }

        const normalized = []
        for (const ws of Niri.workspaces.values) {
            normalized.push({
                id: ws.id ?? 0,
                name: ws.name ?? "",
                isActive: ws.isActive ?? false,
                isEmpty: ws.isEmpty ?? true
            })
        }
        service.workspaces = normalized
    }

    // Normalize outputs
    function updateOutputs() {
        if (!Niri.outputs) {
            service.outputs = []
            return
        }

        const normalized = []
        for (const o of Niri.outputs.values) {
            normalized.push({
                name: o.name ?? "",
                make: o.make ?? "",
                model: o.model ?? "",
                isActive: true  // Niri outputs are always "active" if present
            })
        }
        service.outputs = normalized
    }

    // API: Focus a window by its ID
    function focusWindow(window) {
        if (window && window.id) {
            Niri.dispatch(`focus-window --id ${window.id}`)
        }
    }

    // API: Close a window by its ID
    function closeWindow(window) {
        if (window && window.id) {
            Niri.dispatch(`close-window --id ${window.id}`)
        }
    }

    // API: Focus a workspace
    function focusWorkspace(workspace) {
        if (workspace && workspace.id !== undefined) {
            Niri.dispatch(`focus-workspace ${workspace.id}`)
        }
    }

    // API: Focus an output
    function focusOutput(output) {
        if (output && output.name) {
            Niri.dispatch(`focus-monitor ${output.name}`)
        }
    }

    // API: Get currently focused output
    function getActiveOutput() {
        // Niri doesn't track "focused output" directly, return first output
        if (service.outputs.length > 0) {
            return service.outputs[0].name
        }
        return null
    }
}
