import QtQuick
import Quickshell
pragma Singleton

Item {
    id: service

    property bool isNiri: false
    property bool isHyprland: false
    readonly property string compositor: isNiri ? "niri" : (isHyprland ? "hyprland" : "unknown")
    property var windows: []
    property var workspaces: []
    property var backend: null

    function detectCompositor() {
        const niriSocket = Quickshell.env("NIRI_SOCKET");
        const hyprSig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        if (niriSocket && niriSocket.length > 0) {
            isNiri = true;
            backend = niriComp.createObject(service);
            setupConnections();
            backend.initialize();
        } else if (hyprSig && hyprSig.length > 0) {
            isHyprland = true;
            backend = hyprComp.createObject(service);
            setupConnections();
            backend.initialize();
        } else {
            console.warn("CompositorService: No supported compositor detected (niri/hyprland)");
        }
    }

    function setupConnections() {
        if (!backend)
            return ;

        backend.windowListChanged.connect(() => {
            service.windows = backend.windows;
        });
        backend.workspaceChanged.connect(() => {
            service.workspaces = backend.workspaces;
        });
    }

    function focusWindow(window) {
        if (backend && backend.focusWindow)
            backend.focusWindow(window);

    }

    function closeWindow(window) {
        if (backend && backend.closeWindow)
            backend.closeWindow(window);

    }

    function focusWorkspace(workspace) {
        if (backend && backend.switchToWorkspace)
            backend.switchToWorkspace(workspace);

    }

    function getActiveOutput() {
        if (backend && backend.getActiveOutput)
            return backend.getActiveOutput();

        return null;
    }

    function quit() {
        if (backend && backend.logout)
            backend.logout();

    }

    Component.onCompleted: detectCompositor()

    Component {
        id: niriComp

        NiriService {
        }

    }

    Component {
        id: hyprComp

        HyprlandService {
        }

    }

}
