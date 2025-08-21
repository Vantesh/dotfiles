import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var contextMenu: null
    property var windowsMenu: null
    property bool requestDockShow: false
    property int pinnedAppCount: 0

    implicitWidth: row.width
    implicitHeight: row.height

    function movePinnedApp(fromIndex, toIndex) {
        if (fromIndex === toIndex)
            return;
        var currentPinned = [...(SessionData.pinnedApps || [])];
        if (fromIndex < 0 || fromIndex >= currentPinned.length || toIndex < 0 || toIndex >= currentPinned.length)
            return;
        var movedApp = currentPinned.splice(fromIndex, 1)[0];
        currentPinned.splice(toIndex, 0, movedApp);

        SessionData.setPinnedApps(currentPinned);
    }

    Row {
        id: row
        spacing: 2
        anchors.centerIn: parent
        height: 40

        Repeater {
            id: repeater
            model: ListModel {
                id: dockModel

                Component.onCompleted: updateModel()

                function updateModel() {
                    clear();

                    var items = [];
                    var pinnedApps = [...(SessionData.pinnedApps || [])];

                    // First section: Pinned apps (always visible, not representing running windows)
                    pinnedApps.forEach(appId => {
                        items.push({
                            "type": "pinned",
                            "appId": appId,
                            "windowId": -1,
                            "windowTitle"// Use -1 instead of null to avoid ListModel warnings
                            : "",
                            "workspaceId": -1,
                            "isPinned"// Use -1 instead of null
                            : true,
                            "isRunning": false,
                            "isFocused": false
                        });
                    });

                    root.pinnedAppCount = pinnedApps.length;

                    // Add separator between pinned and running if both exist
                    if (pinnedApps.length > 0 && HyprlandService.windows.length > 0) {
                        items.push({
                            "type": "separator",
                            "appId": "__SEPARATOR__",
                            "windowId": -1,
                            "windowTitle"// Use -1 instead of null
                            : "",
                            "workspaceId": -1,
                            "isPinned"// Use -1 instead of null
                            : false,
                            "isRunning": false,
                            "isFocused": false
                        });
                    }

                    // Second section: Running windows (sorted by display->workspace->position)
                    // HyprlandService.windows is already sorted by sortWindowsByLayout
                    HyprlandService.windows.forEach(window => {
                        // Limit window title length for tooltip
                        var title = window.title || "(Unnamed)";
                        if (title.length > 50) {
                            title = title.substring(0, 47) + "...";
                        }

                        // Check if this window is focused - compare as numbers
                        var isFocused = window.id == HyprlandService.focusedWindowId;

                        items.push({
                            "type": "window",
                            "appId": window.app_id || "",
                            "windowId": window.id || -1,
                            "windowTitle": title,
                            "workspaceId": window.workspace_id || -1,
                            "isPinned": false,
                            "isRunning": true,
                            "isFocused": isFocused
                        });
                    });

                    items.forEach(item => {
                        append(item);
                    });
                }
            }

            delegate: Item {
                id: delegateItem
                property alias dockButton: button

                width: model.type === "separator" ? 16 : 40
                height: 40

                Rectangle {
                    visible: model.type === "separator"
                    width: 2
                    height: 20
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    radius: 1
                    anchors.centerIn: parent
                }

                DockAppButton {
                    id: button
                    visible: model.type !== "separator"
                    anchors.centerIn: parent

                    width: 40
                    height: 40

                    appData: model
                    contextMenu: root.contextMenu
                    windowsMenu: root.windowsMenu
                    dockApps: root
                    index: model.index

                    // Override tooltip for windows to show window title
                    showWindowTitle: model.type === "window"
                    windowTitle: model.windowTitle || ""
                }
            }
        }
    }

    Connections {
        target: HyprlandService
        function onWindowsChanged() {
            dockModel.updateModel();
        }
        function onWindowOpenedOrChanged() {
            dockModel.updateModel();
        }
        function onFocusedWindowIdChanged() {
            dockModel.updateModel();
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            dockModel.updateModel();
        }
    }
}
