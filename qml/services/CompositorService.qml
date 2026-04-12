#pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: service

    // Detection state
    property bool isNiri: false
    property bool isHyprland: false
    readonly property string compositor: isNiri ? "niri" : (isHyprland ? "hyprland" : "unknown")
    readonly property bool ready: isNiri || isHyprland

    // Backend loader
    property var backend: null

    // Unified API properties - these map to backend properties
    property var windows: backend?.windows ?? []
    property var workspaces: backend?.workspaces ?? []
    property var outputs: backend?.outputs ?? []

    // Unified signals
    signal windowsUpdated
    signal workspacesUpdated
    signal windowActivated(var window)

    // Component factories for backends
    Component {
        id: niriComponent
        NiriService { }
    }

    Component {
        id: hyprlandComponent
        HyprlandService { }
    }

    Loader {
        id: backendLoader
        onLoaded: {
            service.backend = item
            // Connect backend signals to unified signals
            if (item.windowsChanged) {
                item.windowsChanged.connect(() => {
                    service.windowsUpdated()
                })
            }
            if (item.workspacesChanged) {
                item.workspacesChanged.connect(() => {
                    service.workspacesUpdated()
                })
            }
        }
    }

    // Auto-detect compositor at startup
    Component.onCompleted: detectCompositor()

    function detectCompositor() {
        const hyprlandSignature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        const niriSocket = Quickshell.env("NIRI_SOCKET")

        if (niriSocket && niriSocket.length > 0) {
            isNiri = true
            backendLoader.sourceComponent = niriComponent
        } else if (hyprlandSignature && hyprlandSignature.length > 0) {
            isHyprland = true
            backendLoader.sourceComponent = hyprlandComponent
        } else {
            console.warn("CompositorService: No supported compositor detected (niri/hyprland)")
        }
    }

    // Unified API methods
    function focusWindow(window) {
        if (backend && backend.focusWindow) {
            backend.focusWindow(window)
        } else {
            console.warn("CompositorService: No backend available for focusWindow")
        }
    }

    function closeWindow(window) {
        if (backend && backend.closeWindow) {
            backend.closeWindow(window)
        } else {
            console.warn("CompositorService: No backend available for closeWindow")
        }
    }

    function focusWorkspace(workspace) {
        if (backend && backend.focusWorkspace) {
            backend.focusWorkspace(workspace)
        } else {
            console.warn("CompositorService: No backend available for focusWorkspace")
        }
    }

    function focusOutput(output) {
        if (backend && backend.focusOutput) {
            backend.focusOutput(output)
        } else {
            console.warn("CompositorService: No backend available for focusOutput")
        }
    }

    function getActiveOutput() {
        if (backend && backend.getActiveOutput) {
            return backend.getActiveOutput()
        }
        return null
    }

    function quit() {
        if (isNiri) {
            // Niri uses IPC for quit
            Quickshell.execDetached(["sh", "-c", "niri msg action quit"])
        } else if (isHyprland) {
            // Hyprland dispatch exit
            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exit"])
        } else {
            console.warn("CompositorService: Cannot quit - no compositor detected")
        }
    }
}
