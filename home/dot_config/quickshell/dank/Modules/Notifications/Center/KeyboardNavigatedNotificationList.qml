import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankListView {
    id: listView

    property var keyboardController: null
    property bool keyboardActive: false
    property bool autoScrollDisabled: false

    onIsUserScrollingChanged: {
        if (isUserScrolling && keyboardController
                && keyboardController.keyboardNavigationActive) {
            autoScrollDisabled = true
        }
    }

    function enableAutoScroll() {
        autoScrollDisabled = false
    }

    property alias count: listView.count
    property alias listContentHeight: listView.contentHeight

    clip: true
    model: NotificationService.groupedNotifications
    spacing: Theme.spacingL

    Timer {
        id: positionPreservationTimer
        interval: 200
        running: keyboardController
                 && keyboardController.keyboardNavigationActive
                 && !autoScrollDisabled
        repeat: true
        onTriggered: {
            if (keyboardController
                    && keyboardController.keyboardNavigationActive
                    && !autoScrollDisabled) {
                keyboardController.ensureVisible()
            }
        }
    }

    NotificationEmptyState {
        visible: listView.count === 0
        anchors.centerIn: parent
    }

    onModelChanged: {
        if (keyboardController && keyboardController.keyboardNavigationActive) {
            keyboardController.rebuildFlatNavigation()
            Qt.callLater(function () {
                if (keyboardController
                        && keyboardController.keyboardNavigationActive
                        && !autoScrollDisabled) {
                    keyboardController.ensureVisible()
                }
            })
        }
    }

    delegate: Item {
        required property var modelData
        required property int index

        readonly property bool isExpanded: NotificationService.expandedGroups[modelData?.key]
                                           || false

        width: ListView.view.width
        height: notificationCardWrapper.height

        Item {
            id: notificationCardWrapper
            width: parent.width
            height: notificationCard.height

            NotificationCard {
                id: notificationCard
                width: parent.width
                notificationGroup: modelData

                isGroupSelected: {
                    if (!keyboardController
                            || !keyboardController.keyboardNavigationActive)
                        return false
                    keyboardController.selectionVersion
                    if (!listView.keyboardActive)
                        return false
                    const selection = keyboardController.getCurrentSelection()
                    return selection.type === "group"
                            && selection.groupIndex === index
                }
                selectedNotificationIndex: {
                    if (!keyboardController
                            || !keyboardController.keyboardNavigationActive)
                        return -1
                    keyboardController.selectionVersion
                    if (!listView.keyboardActive)
                        return -1
                    const selection = keyboardController.getCurrentSelection()
                    return (selection.type === "notification"
                            && selection.groupIndex === index) ? selection.notificationIndex : -1
                }
                keyboardNavigationActive: listView.keyboardActive
            }
        }
    }

    Connections {
        function onGroupedNotificationsChanged() {
            if (keyboardController) {
                if (keyboardController.isTogglingGroup) {
                    keyboardController.rebuildFlatNavigation()
                    return
                }

                keyboardController.rebuildFlatNavigation()

                if (keyboardController.keyboardNavigationActive) {
                    Qt.callLater(function () {
                        if (!autoScrollDisabled) {
                            keyboardController.ensureVisible()
                        }
                    })
                }
            }
        }

        function onExpandedGroupsChanged() {
            if (keyboardController
                    && keyboardController.keyboardNavigationActive) {
                Qt.callLater(function () {
                    if (!autoScrollDisabled) {
                        keyboardController.ensureVisible()
                    }
                })
            }
        }

        function onExpandedMessagesChanged() {
            if (keyboardController
                    && keyboardController.keyboardNavigationActive) {
                Qt.callLater(function () {
                    if (!autoScrollDisabled) {
                        keyboardController.ensureVisible()
                    }
                })
            }
        }

        target: NotificationService
    }
}
