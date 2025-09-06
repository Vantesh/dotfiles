import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var contextMenu: null
    property bool requestDockShow: false
    property int pinnedAppCount: 0

    implicitWidth: row.width
    implicitHeight: row.height

    function movePinnedApp(fromIndex, toIndex) {
        if (fromIndex === toIndex) {
            return
        }

        const currentPinned = [...(SessionData.pinnedApps || [])]
        if (fromIndex < 0 || fromIndex >= currentPinned.length || toIndex < 0 || toIndex >= currentPinned.length) {
            return
        }

        const movedApp = currentPinned.splice(fromIndex, 1)[0]
        currentPinned.splice(toIndex, 0, movedApp)

        SessionData.setPinnedApps(currentPinned)
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
                    clear()

                    const items = []
                    const pinnedApps = [...(SessionData.pinnedApps || [])]

                    pinnedApps.forEach(appId => {
                                           items.push({
                                                          "type": "pinned",
                                                          "appId": appId,
                                                          "windowId": -1,
                                                          "windowTitle": "",
                                                          "workspaceId": -1,
                                                          "isPinned": true,
                                                          "isRunning": false
                                                      })
                                       })

                    root.pinnedAppCount = pinnedApps.length

                    const sortedToplevels = CompositorService.sortedToplevels

                    if (pinnedApps.length > 0 && sortedToplevels.length > 0) {
                        items.push({
                                       "type": "separator",
                                       "appId": "__SEPARATOR__",
                                       "windowId": -1,
                                       "windowTitle": "",
                                       "workspaceId": -1,
                                       "isPinned": false,
                                       "isRunning": false,
                                       "isFocused": false
                                   })
                    }

                    sortedToplevels.forEach((toplevel, index) => {
                                                const title = toplevel.title || "(Unnamed)"
                                                const truncatedTitle = title.length > 50 ? title.substring(0, 47) + "..." : title
                                                const uniqueId = toplevel.title + "|" + (toplevel.appId || "") + "|" + index

                                                items.push({
                                                               "type": "window",
                                                               "appId": toplevel.appId,
                                                               "windowId": index,
                                                               "windowTitle": truncatedTitle,
                                                               "workspaceId": -1,
                                                               "isPinned": false,
                                                               "isRunning": true,
                                                               "uniqueId": uniqueId
                                                           })
                                            })

                    items.forEach(item => append(item))
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
        target: CompositorService
        function onSortedToplevelsChanged() {
            dockModel.updateModel()
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            dockModel.updateModel()
        }
    }
}
