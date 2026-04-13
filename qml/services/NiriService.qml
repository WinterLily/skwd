import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int floatingWindowPosition: Number.MAX_SAFE_INTEGER
    property var windows: []
    property var workspaces: []
    property int focusedWindowIndex: -1
    property var outputCache: ({
    })
    property var workspaceCache: ({
    })

    signal workspaceChanged()
    signal activeWindowChanged()
    signal windowListChanged()

    function initialize() {
        niriEventStream.connected = true;
        niriCommandSocket.connected = true;
        startEventStream();
        updateOutputs();
        updateWorkspaces();
        updateWindows();
    }

    function sendSocketCommand(sock, command) {
        sock.write(JSON.stringify(command) + "\n");
        sock.flush();
    }

    function startEventStream() {
        sendSocketCommand(niriEventStream, "EventStream");
    }

    function updateOutputs() {
        sendSocketCommand(niriCommandSocket, "Outputs");
    }

    function updateWorkspaces() {
        sendSocketCommand(niriCommandSocket, "Workspaces");
    }

    function updateWindows() {
        sendSocketCommand(niriCommandSocket, "Windows");
    }

    function recollectOutputs(outputsData) {
        outputCache = {
        };
        for (const outputName in outputsData) {
            const output = outputsData[outputName];
            if (output && output.name) {
                const logical = output.logical || {
                };
                const currentModeIdx = output.current_mode || 0;
                const modes = output.modes || [];
                const currentMode = modes[currentModeIdx] || {
                };
                const outputData = {
                    "name": output.name,
                    "scale": logical.scale || 1,
                    "width": logical.width || 0,
                    "height": logical.height || 0,
                    "x": logical.x || 0,
                    "y": logical.y || 0,
                    "refresh_rate": currentMode.refresh_rate || 0
                };
                outputCache[output.name] = outputData;
            }
        }
    }

    function recollectWorkspaces(workspacesData) {
        const workspacesList = [];
        workspaceCache = {
        };
        for (const ws of workspacesData) {
            const wsData = {
                "id": ws.id,
                "idx": ws.idx,
                "name": ws.name || "",
                "output": ws.output || "",
                "isFocused": ws.is_focused === true,
                "isActive": ws.is_active === true,
                "isUrgent": ws.is_urgent === true,
                "isOccupied": ws.active_window_id ? true : false
            };
            workspacesList.push(wsData);
            workspaceCache[ws.id] = wsData;
        }
        workspacesList.sort((a, b) => {
            if (a.output !== b.output)
                return a.output.localeCompare(b.output);

            return a.idx - b.idx;
        });
        workspaces = workspacesList;
        workspaceChanged();
    }

    function getWindowPosition(layout) {
        if (layout && layout.pos_in_scrolling_layout)
            return {
            "x": layout.pos_in_scrolling_layout[0],
            "y": layout.pos_in_scrolling_layout[1]
        };

        return {
            "x": floatingWindowPosition,
            "y": floatingWindowPosition
        };
    }

    function getWindowOutput(win) {
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].id === win.workspace_id)
                return workspaces[i].output;

        }
        return null;
    }

    function getWindowData(win) {
        return {
            "id": win.id,
            "title": win.title || "",
            "appId": win.app_id || "",
            "workspaceId": win.workspace_id || -1,
            "isFocused": win.is_focused === true,
            "isFloating": false,
            "output": getWindowOutput(win) || "",
            "position": getWindowPosition(win.layout)
        };
    }

    function toSortedWindowList(windowList) {
        return windowList.map((win) => {
            const workspace = workspaceCache[win.workspaceId];
            const output = (workspace && workspace.output) ? outputCache[workspace.output] : null;
            return {
                "window": win,
                "workspaceIdx": workspace ? workspace.idx : 0,
                "outputX": output ? output.x : 0,
                "outputY": output ? output.y : 0
            };
        }).sort((a, b) => {
            if (a.outputX !== b.outputX)
                return a.outputX - b.outputX;

            if (a.outputY !== b.outputY)
                return a.outputY - b.outputY;

            if (a.workspaceIdx !== b.workspaceIdx)
                return a.workspaceIdx - b.workspaceIdx;

            if (a.window.position.x !== b.window.position.x)
                return a.window.position.x - b.window.position.x;

            if (a.window.position.y !== b.window.position.y)
                return a.window.position.y - b.window.position.y;

            return a.window.id - b.window.id;
        }).map((info) => {
            return info.window;
        });
    }

    function recollectWindows(windowsData) {
        const windowsList = [];
        for (const win of windowsData) {
            windowsList.push(getWindowData(win));
        }
        windows = toSortedWindowList(windowsList);
        windowListChanged();
        focusedWindowIndex = -1;
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].isFocused) {
                focusedWindowIndex = i;
                break;
            }
        }
        activeWindowChanged();
    }

    function handleWindowOpenedOrChanged(eventData) {
        try {
            const windowData = eventData.window;
            const existingIndex = windows.findIndex((w) => {
                return w.id === windowData.id;
            });
            const newWindow = getWindowData(windowData);
            const previouslyFocusedId = focusedWindowIndex >= 0 && focusedWindowIndex < windows.length ? windows[focusedWindowIndex].id : null;
            if (existingIndex >= 0)
                windows[existingIndex] = newWindow;
            else
                windows.push(newWindow);
            windows = toSortedWindowList(windows);
            if (newWindow.isFocused) {
                focusedWindowIndex = windows.findIndex((w) => {
                    return w.id === windowData.id;
                });
                if (previouslyFocusedId !== null && previouslyFocusedId !== windowData.id) {
                    const oldFocused = windows.find((w) => {
                        return w.id === previouslyFocusedId;
                    });
                    if (oldFocused)
                        oldFocused.isFocused = false;

                }
                activeWindowChanged();
            }
            windowListChanged();
        } catch (e) {
            console.warn("NiriService: Error handling WindowOpenedOrChanged:", e);
        }
    }

    function handleWindowClosed(eventData) {
        try {
            const windowId = eventData.id;
            const windowIndex = windows.findIndex((w) => {
                return w.id === windowId;
            });
            if (windowIndex >= 0) {
                if (windowIndex === focusedWindowIndex) {
                    focusedWindowIndex = -1;
                    activeWindowChanged();
                } else if (focusedWindowIndex > windowIndex) {
                    focusedWindowIndex--;
                }
                windows.splice(windowIndex, 1);
                windows = windows.slice(); // trigger change notification
                windowListChanged();
            }
        } catch (e) {
            console.warn("NiriService: Error handling WindowClosed:", e);
        }
    }

    function handleWindowsChanged(eventData) {
        try {
            recollectWindows(eventData.windows);
        } catch (e) {
            console.warn("NiriService: Error handling WindowsChanged:", e);
        }
    }

    function handleWindowFocusChanged(eventData) {
        try {
            const focusedId = eventData.id;
            if (windows[focusedWindowIndex])
                windows[focusedWindowIndex].isFocused = false;

            if (focusedId) {
                const newIndex = windows.findIndex((w) => {
                    return w.id === focusedId;
                });
                if (newIndex >= 0 && newIndex < windows.length)
                    windows[newIndex].isFocused = true;

                focusedWindowIndex = newIndex >= 0 ? newIndex : -1;
            } else {
                focusedWindowIndex = -1;
            }
            activeWindowChanged();
        } catch (e) {
            console.warn("NiriService: Error handling WindowFocusChanged:", e);
        }
    }

    function handleWindowLayoutsChanged(eventData) {
        try {
            for (const change of eventData.changes) {
                const windowId = change[0];
                const layout = change[1];
                const window = windows.find((w) => {
                    return w.id === windowId;
                });
                if (window)
                    window.position = getWindowPosition(layout);

            }
            windows = toSortedWindowList(windows);
            windowListChanged();
        } catch (e) {
            console.warn("NiriService: Error handling WindowLayoutsChanged:", e);
        }
    }

    function switchToWorkspace(workspace) {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", workspace.idx.toString()]);
        } catch (e) {
            console.warn("NiriService: Failed to switch workspace:", e);
        }
    }

    function focusWindow(window) {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", window.id.toString()]);
        } catch (e) {
            console.warn("NiriService: Failed to focus window:", e);
        }
    }

    function closeWindow(window) {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", window.id.toString()]);
        } catch (e) {
            console.warn("NiriService: Failed to close window:", e);
        }
    }

    function getActiveOutput() {
        // Return the output of the focused workspace
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].isFocused)
                return workspaces[i].output;

        }
        if (workspaces.length > 0)
            return workspaces[0].output;

        return null;
    }

    function logout() {
        Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
    }

    Socket {
        id: niriCommandSocket

        path: Quickshell.env("NIRI_SOCKET")
        connected: false

        parser: SplitParser {
            onRead: function(line) {
                try {
                    const data = JSON.parse(line);
                    if (data && data.Ok) {
                        const res = data.Ok;
                        if (res.Windows)
                            recollectWindows(res.Windows);
                        else if (res.Outputs)
                            recollectOutputs(res.Outputs);
                        else if (res.Workspaces)
                            recollectWorkspaces(res.Workspaces);
                    } else {
                        console.warn("NiriService: Niri returned an error:", data ? data.Err : "", line);
                    }
                } catch (e) {
                    console.warn("NiriService: Failed to parse data from socket:", e, line);
                }
            }
        }

    }

    Socket {
        id: niriEventStream

        path: Quickshell.env("NIRI_SOCKET")
        connected: false

        parser: SplitParser {
            onRead: (data) => {
                try {
                    const event = JSON.parse(data.trim());
                    if (event.WorkspacesChanged)
                        recollectWorkspaces(event.WorkspacesChanged.workspaces);
                    else if (event.WindowOpenedOrChanged)
                        handleWindowOpenedOrChanged(event.WindowOpenedOrChanged);
                    else if (event.WindowClosed)
                        handleWindowClosed(event.WindowClosed);
                    else if (event.WindowsChanged)
                        handleWindowsChanged(event.WindowsChanged);
                    else if (event.WorkspaceActivated)
                        updateWorkspaces();
                    else if (event.WindowFocusChanged)
                        handleWindowFocusChanged(event.WindowFocusChanged);
                    else if (event.WindowLayoutsChanged)
                        handleWindowLayoutsChanged(event.WindowLayoutsChanged);
                } catch (e) {
                    console.warn("NiriService: Error parsing event stream:", e, data);
                }
            }
        }

    }

}
