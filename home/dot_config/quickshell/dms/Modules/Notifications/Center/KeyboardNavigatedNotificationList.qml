import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankListView {
    id: listView

    property var keyboardController: null
    property bool keyboardActive: false
    property bool autoScrollDisabled: false
    property alias count: listView.count
    property alias listContentHeight: listView.contentHeight

    clip: true
    model: NotificationService.groupedNotifications
    spacing: Theme.spacingL

    onIsUserScrollingChanged: {
        if (isUserScrolling && keyboardController && keyboardController.keyboardNavigationActive) {
            autoScrollDisabled = true
        }
    }

    function enableAutoScroll() {
        autoScrollDisabled = false
    }

    Timer {
        id: positionPreservationTimer
        interval: 200
        running: keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled
        repeat: true
        onTriggered: {
            if (keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled) {
                keyboardController.ensureVisible()
            }
        }
    }

    NotificationEmptyState {
        visible: listView.count === 0
        anchors.centerIn: parent
    }

    onModelChanged: {
        if (!keyboardController || !keyboardController.keyboardNavigationActive) {
            return
        }
        keyboardController.rebuildFlatNavigation()
        Qt.callLater(() => {
                         if (keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled) {
                             keyboardController.ensureVisible()
                         }
                     })
    }

    delegate: Item {
        required property var modelData
        required property int index

        readonly property bool isExpanded: (NotificationService.expandedGroups[modelData && modelData.key] || false)

        width: ListView.view.width
        height: notificationCard.height

        NotificationCard {
            id: notificationCard
            width: parent.width
            notificationGroup: modelData
            keyboardNavigationActive: listView.keyboardActive

            isGroupSelected: {
                if (!keyboardController || !keyboardController.keyboardNavigationActive || !listView.keyboardActive) {
                    return false
                }
                keyboardController.selectionVersion
                const selection = keyboardController.getCurrentSelection()
                return selection.type === "group" && selection.groupIndex === index
            }

            selectedNotificationIndex: {
                if (!keyboardController || !keyboardController.keyboardNavigationActive || !listView.keyboardActive) {
                    return -1
                }
                keyboardController.selectionVersion
                const selection = keyboardController.getCurrentSelection()
                return (selection.type === "notification" && selection.groupIndex === index) ? selection.notificationIndex : -1
            }
        }
    }

    Connections {
        target: NotificationService

        function onGroupedNotificationsChanged() {
            if (!keyboardController) {
                return
            }

            if (keyboardController.isTogglingGroup) {
                keyboardController.rebuildFlatNavigation()
                return
            }

            keyboardController.rebuildFlatNavigation()

            if (keyboardController.keyboardNavigationActive) {
                Qt.callLater(() => {
                                 if (!autoScrollDisabled) {
                                     keyboardController.ensureVisible()
                                 }
                             })
            }
        }

        function onExpandedGroupsChanged() {
            if (keyboardController && keyboardController.keyboardNavigationActive) {
                Qt.callLater(() => {
                                 if (!autoScrollDisabled) {
                                     keyboardController.ensureVisible()
                                 }
                             })
            }
        }

        function onExpandedMessagesChanged() {
            if (keyboardController && keyboardController.keyboardNavigationActive) {
                Qt.callLater(() => {
                                 if (!autoScrollDisabled) {
                                     keyboardController.ensureVisible()
                                 }
                             })
            }
        }
    }
}
