pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// HyprlandService: provides workspace, monitor, and window data sourced from Hyprland.
Singleton {
    id: root

    // Availability
    property bool hyprAvailable: false

    // Workspaces & monitors
    property var workspaces: ({})            // id -> workspace info
    property var allWorkspaces: []           // ordered list (by id)
    property var outputs: ({})               // monitor name -> info
    property string currentOutput: ""
    property var currentOutputWorkspaces: []
    property int focusedWorkspaceId: -1
    // Track active workspace ids across monitors (Hyprland has one active per monitor)
    property var activeWorkspaceIds: []

    // Windows
    property var windows: []
    property string focusedWindowAddress: ""  // hyprland client address
    property int focusedWindowIndex: -1
    property string focusedWindowTitle: "(No active window)"
    // Provide focusedWindowId for legacy references
    property string focusedWindowId: ""

    // Legacy custom signal retained only for specific callbacks (avoid name clashes with property notify signals)
    signal windowOpenedOrChanged(var window)

    Component.onCompleted: initialize()

    function initialize() {
        // Detect hyprland via event socket path (provided by Quickshell.Hyprland)
        try {
            if (Hyprland.eventSocketPath) {
                hyprAvailable = true;
                refreshAll();
                // Listen to raw events for incremental updates
                Hyprland.rawEvent.connect(handleHyprlandEvent);
            }
        } catch (e) {
            console.warn("HyprlandService: Hyprland not available", e);
            hyprAvailable = false;
        }
    }

    function refreshAll() {
        refreshWorkspaces();
        refreshMonitors();
        refreshWindows();
        refreshActiveWorkspace();
    }

    function refreshWorkspaces() {
        if (!hyprAvailable)
            return;
        workspacesProcess.running = true;
    }

    function refreshMonitors() {
        if (!hyprAvailable)
            return;
        monitorsProcess.running = true;
    }

    function refreshWindows() {
        if (!hyprAvailable)
            return;
        windowsProcess.running = true;
        activeWindowProcess.running = true;
    }

    function refreshActiveWorkspace() {
        if (!hyprAvailable)
            return;
        activeWorkspaceProcess.running = true;
    }

    function handleHyprlandEvent(ev) {
        if (!hyprAvailable || !ev)
            return;
        // Hyprland rawEvent may be a string or a HyprlandIpcEvent object; normalize to name string
        let name = "";
        try {
            if (typeof ev === "string") {
                // Expected raw format: 'eventname>>payload'
                let parts = ev.split(">>");
                name = parts[0];
            } else if (ev && typeof ev === "object") {
                // Probe common property candidates (guessing based on typical naming)
                if (ev.name)
                    name = ev.name;
                else if (ev.event)
                    name = ev.event;
                else if (ev.type)
                    name = ev.type;
                else if (ev.eventName)
                    name = ev.eventName;
                else if (ev.toString) {
                    const s = ev.toString();
                    if (s && typeof s === "string" && s.indexOf(">>") !== -1)
                        name = s.split(">>")[0];
                }
                // Final fallback: iterate enumerable keys for something that looks like an event name
                if (!name) {
                    for (let k in ev) {
                        if (!ev.hasOwnProperty || ev.hasOwnProperty(k)) {
                            if (k.toLowerCase().indexOf("event") !== -1 && typeof ev[k] === "string") {
                                name = ev[k];
                                break;
                            }
                        }
                    }
                }
            }
        } catch (e) {
            console.warn("HyprlandService: error normalizing event", e);
        }
        if (!name) {
            // Unknown event object: do a minimal focused window poll as a safe fallback
            activeWindowProcess.running = true;
            return;
        }
        switch (name) {
        case "activewindow":
            activeWindowProcess.running = true;
            break;
        case "openwindow":
        case "closewindow":
        case "movewindow":
        case "windowtitle":
        case "windowclass":
            windowsProcess.running = true;
            activeWindowProcess.running = true;
            break;
        case "createworkspace":
        case "destroyworkspace":
        case "workspace":
        case "renameworkspace":
            workspacesProcess.running = true;
            monitorsProcess.running = true;
            activeWorkspaceProcess.running = true;
            // Also refresh active window & clients because focus often changes with workspace switches
            activeWindowProcess.running = true;
            windowsProcess.running = true;
            break;
        case "focusedmon":
        case "monitoradded":
        case "monitorremoved":
            monitorsProcess.running = true;
            workspacesProcess.running = true;
            // Focus may shift when monitor focus changes
            activeWindowProcess.running = true;
            break;
        default:
            // Fallback minimal refresh for unknown events that might impact state
            // Poll active window in case focus changed
            activeWindowProcess.running = true;
            break;
        }
    }

    // Safety polling (in case some events aren't delivered as expected)
    Timer {
        interval: 2000
        running: root.hyprAvailable
        repeat: true
        onTriggered: {
            if (!activeWindowProcess.running)
                activeWindowProcess.running = true;
        }
    }

    // Processes to query hyprctl JSON output
    Process {
        id: workspacesProcess
        command: ["hyprctl", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const wsMap = {};
                    const wsList = [];
                    data.forEach(ws => {
                        if (ws.id >= 1) {
                            const item = {
                                id: ws.id,
                                idx: ws.id - 1,
                                name: ws.name || "",
                                output: ws.monitor || ws.monitorName || ws.monitorID || "",
                                // Hyprland workspaces JSON does not expose direct focused/active flags; derive via monitors
                                is_focused: false,
                                is_active: false,
                                monitor: ws.monitor || ws.monitorName || ws.monitorID || ""
                            };
                            wsMap[item.id] = item;
                            wsList.push(item);
                        }
                    });
                    wsList.sort((a, b) => a.id - b.id);
                    workspaces = wsMap;
                    allWorkspaces = wsList;
                    applyActiveWorkspaceFlags();
                    updateCurrentOutputWorkspaces();
                } catch (e) {
                    console.warn("HyprlandService: failed to parse workspaces JSON", e);
                }
            }
        }
    }

    Process {
        id: monitorsProcess
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const mMap = {};
                    const activeIds = [];
                    data.forEach(m => {
                        if (m.name)
                            mMap[m.name] = m;
                        if (m.activeWorkspace && (m.activeWorkspace.id !== undefined || m.activeWorkspace.ID !== undefined)) {
                            const wid = (m.activeWorkspace.id !== undefined) ? m.activeWorkspace.id : m.activeWorkspace.ID;
                            if (activeIds.indexOf(wid) === -1)
                                activeIds.push(wid);
                        }
                    });
                    outputs = mMap;
                    activeWorkspaceIds = activeIds;
                    applyActiveWorkspaceFlags();
                } catch (e) {
                    console.warn("HyprlandService: failed to parse monitors JSON", e);
                }
            }
        }
    }

    Process {
        id: windowsProcess
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    let list = [];
                    data.forEach(c => {
                        const item = {
                            id: c.pid,
                            address: c.address,
                            title: c.title || "",
                            app_id: c.class || c.initialClass || c.title || "",
                            workspace_id: (c.workspace && c.workspace.id !== undefined) ? c.workspace.id : (c.workspace && c.workspace.ID) ? c.workspace.ID : -1,
                            is_focused: false,
                            monitor: (c.monitor && c.monitor.name) ? c.monitor.name : (c.monitorName || "")
                        };
                        list.push(item);
                    });
                    list.sort((a, b) => a.workspace_id === b.workspace_id ? a.title.localeCompare(b.title) : a.workspace_id - b.workspace_id);
                    windows = list;
                } catch (e) {
                    console.warn("HyprlandService: failed to parse windows JSON", e);
                }
            }
        }
    }

    // Active window separate query
    Process {
        id: activeWindowProcess
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (!text || text.trim() === "null") {
                        focusedWindowIndex = -1;
                        focusedWindowId = "";
                        focusedWindowAddress = "";
                        focusedWindowTitle = "(No active window)";
                        return;
                    }
                    const aw = JSON.parse(text);
                    // Basic validation
                    if (!aw || typeof aw !== "object") {
                        focusedWindowIndex = -1;
                        focusedWindowId = "";
                        focusedWindowAddress = "";
                        focusedWindowTitle = "(No active window)";
                        return;
                    }
                    let idx = windows.findIndex(w => w.address === aw.address || w.id === aw.pid);
                    // If we didn't find the window, request a full clients refresh (will tag focused next cycle)
                    if (idx === -1) {
                        windowsProcess.running = true;
                        focusedWindowIndex = -1;
                    } else {
                        // Re-mark focused flag without rebuilding all objects (clone only if necessary)
                        const updated = [];
                        for (let i = 0; i < windows.length; i++) {
                            const w = windows[i];
                            if (w.is_focused !== (i === idx)) {
                                updated.push({
                                    id: w.id,
                                    address: w.address,
                                    title: w.title,
                                    app_id: w.app_id,
                                    workspace_id: w.workspace_id,
                                    is_focused: i === idx,
                                    monitor: w.monitor
                                });
                            } else {
                                updated.push(w);
                            }
                        }
                        windows = updated;
                        focusedWindowIndex = idx;
                    }

                    // Update focused window properties directly from aw (fallbacks applied)
                    focusedWindowId = aw.pid !== undefined ? String(aw.pid) : "";
                    focusedWindowAddress = aw.address || "";
                    focusedWindowTitle = (aw.title && aw.title.length) ? aw.title : "";
                } catch (e) {
                    console.warn("HyprlandService: failed to parse activewindow JSON", e);
                }
            }
        }
    }

    // Active workspace separate query - gets the actual focused workspace
    Process {
        id: activeWorkspaceProcess
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (!text || text.trim() === "null") {
                        return;
                    }
                    const aws = JSON.parse(text);
                    // Basic validation
                    if (!aws || typeof aws !== "object" || aws.id === undefined) {
                        return;
                    }
                    // Update the focused workspace ID to the actual active workspace
                    focusedWorkspaceId = aws.id;
                    // Update the current output based on the active workspace's monitor
                    if (aws.monitor) {
                        currentOutput = aws.monitor;
                    }
                    // Update workspace flags with the correct focused workspace
                    applyActiveWorkspaceFlags();
                    updateCurrentOutputWorkspaces();
                } catch (e) {
                    console.warn("HyprlandService: failed to parse activeworkspace JSON", e);
                }
            }
        }
    }

    function applyActiveWorkspaceFlags() {
        // Rebuild allWorkspaces with updated active/focused flags derived from activeWorkspaceIds
        if (!allWorkspaces || allWorkspaces.length === 0)
            return;
        if (!activeWorkspaceIds)
            activeWorkspaceIds = [];
        let updated = [];
        for (let i = 0; i < allWorkspaces.length; i++) {
            const ws = allWorkspaces[i];
            const isAct = activeWorkspaceIds.indexOf(ws.id) !== -1;
            const isFocused = ws.id === focusedWorkspaceId;
            const newWs = {
                id: ws.id,
                idx: ws.idx,
                name: ws.name,
                output: ws.output,
                is_focused: isFocused // use actual focused workspace, not just active
                ,
                is_active: isAct,
                monitor: ws.monitor
            };
            updated.push(newWs);
        }
        allWorkspaces = updated;

        // If focusedWorkspaceId is set (from activeWorkspaceProcess), update currentOutput
        if (focusedWorkspaceId !== -1) {
            const fw = updated.find(w => w.id === focusedWorkspaceId);
            if (fw && fw.output) {
                currentOutput = fw.output;
            }
        } else if (updated.length > 0) {
            // Fallback: if no focused workspace is set, use the first active one
            const firstActive = updated.find(w => w.is_active);
            if (firstActive) {
                focusedWorkspaceId = firstActive.id;
                currentOutput = firstActive.output;
            } else {
                // Last resort: use first workspace
                focusedWorkspaceId = updated[0].id;
                currentOutput = updated[0].output;
            }
        }
    }

    function updateCurrentOutputWorkspaces() {
        if (!currentOutput) {
            currentOutputWorkspaces = allWorkspaces;
            return;
        }
        currentOutputWorkspaces = allWorkspaces.filter(w => w.output === currentOutput);
    }

    function updateFocusedWindowTitle() {
        if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) {
            focusedWindowTitle = windows[focusedWindowIndex].title || "";
        } else {
            focusedWindowTitle = "(No active window)";
        }
    }

    // API parity helpers
    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.idx + 1);
    }

    function getCurrentWorkspaceNumber() {
        const ws = allWorkspaces.find(w => w.id === focusedWorkspaceId);
        return ws ? ws.idx + 1 : 1;
    }

    function switchToWorkspace(index0Based) { // expects 0-based like old service
        if (!hyprAvailable)
            return false;
        const target = allWorkspaces.find(w => w.idx === index0Based);
        const workspaceId = target ? target.id : (index0Based + 1);
        try {
            Hyprland.dispatch(`workspace ${workspaceId}`);
            return true;
        } catch (e) {
            console.warn("HyprlandService: failed to switch workspace", e);
            return false;
        }
    }

    function focusWindow(windowId) { // windowId persisted from list (pid-based)
        if (!hyprAvailable)
            return false;
        const win = windows.find(w => w.id === windowId);
        if (!win)
            return false;
        try {
            Hyprland.dispatch(`focuswindow address:${win.address}`);
            return true;
        } catch (e) {
            console.warn("HyprlandService: failed to focus window", e);
            return false;
        }
    }

    function closeWindow(windowId) {
        if (!hyprAvailable)
            return false;
        const win = windows.find(w => w.id === windowId);
        if (!win)
            return false;
        try {
            Hyprland.dispatch(`closewindow address:${win.address}`);
            return true;
        } catch (e) {
            console.warn("HyprlandService: failed to close window", e);
            return false;
        }
    }

    function quit() {
        if (!hyprAvailable)
            return false;
        try {
            Hyprland.dispatch("exit");
            return true;
        } catch (e) {
            console.warn("HyprlandService: failed to exit Hyprland", e);
            return false;
        }
    }

    function getWindowsByAppId(appId) {
        if (!appId)
            return [];
        return windows.filter(w => w.app_id && w.app_id.toLowerCase() === appId.toLowerCase());
    }

    function getRunningAppIds() {
        const set = new Set();
        windows.forEach(w => {
            if (w.app_id)
                set.add(w.app_id.toLowerCase());
        });
        return Array.from(set);
    }

    function getRunningAppIdsOrdered() {
        const seen = new Set();
        const ordered = [];
        windows.forEach(w => {
            if (w.app_id) {
                const lower = w.app_id.toLowerCase();
                if (!seen.has(lower)) {
                    ordered.push(lower);
                    seen.add(lower);
                }
            }
        });
        return ordered;
    }
}
