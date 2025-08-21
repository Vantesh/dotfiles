import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Notifications.Center

DankPopout {
    id: root

    property bool notificationHistoryVisible: false
    property string triggerSection: "right"
    property var triggerScreen: null

    NotificationKeyboardController {
        id: keyboardController
        listView: null
        isOpen: notificationHistoryVisible
        onClose: function () {
            notificationHistoryVisible = false
        }
    }

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    popupWidth: 400
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 400
    triggerX: Screen.width - 400 - Theme.spacingL
    triggerY: Theme.barHeight - 4 + SettingsData.topBarSpacing + Theme.spacingXS
    triggerWidth: 40
    positioning: "center"
    WlrLayershell.namespace: "quickshell-notifications"
    screen: triggerScreen
    shouldBeVisible: notificationHistoryVisible
    visible: shouldBeVisible

    onNotificationHistoryVisibleChanged: {
        if (notificationHistoryVisible) {
            open()
        } else {
            close()
        }
    }

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            NotificationService.disablePopups(true)
            // Set up keyboard controller when content is loaded
            Qt.callLater(function () {
                if (contentLoader.item) {
                    contentLoader.item.externalKeyboardController = keyboardController

                    // Find the notification list and set up the connection
                    var notificationList = findChild(contentLoader.item,
                                                     "notificationList")
                    var notificationHeader = findChild(contentLoader.item,
                                                       "notificationHeader")

                    if (notificationList) {
                        keyboardController.listView = notificationList
                        notificationList.keyboardController = keyboardController
                    }
                    if (notificationHeader) {
                        notificationHeader.keyboardController = keyboardController
                    }

                    keyboardController.reset()
                    keyboardController.rebuildFlatNavigation()
                }
            })
        } else {
            NotificationService.disablePopups(false)
            // Reset keyboard state when closing
            keyboardController.keyboardNavigationActive = false
        }
    }

    function findChild(parent, objectName) {
        if (parent.objectName === objectName) {
            return parent
        }
        for (var i = 0; i < parent.children.length; i++) {
            var child = parent.children[i]
            var result = findChild(child, objectName)
            if (result) {
                return result
            }
        }
        return null
    }

    content: Component {
        Rectangle {
            id: notificationContent

            property var externalKeyboardController: null
            property real cachedHeaderHeight: 32

            implicitHeight: {
                let baseHeight = Theme.spacingL * 2
                baseHeight += cachedHeaderHeight
                baseHeight += (notificationSettings.expanded ? notificationSettings.contentHeight : 0)
                baseHeight += Theme.spacingM * 2
                let listHeight = notificationList.listContentHeight
                if (NotificationService.groupedNotifications.length === 0)
                    listHeight = 200
                baseHeight += Math.min(listHeight, 600)
                return Math.max(
                            300, Math.min(
                                baseHeight,
                                root.screen ? root.screen.height * 0.8 : Screen.height * 0.8))
            }

            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                  Theme.outline.b, 0.08)
            border.width: 1
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible)
                    forceActiveFocus()
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                } else if (externalKeyboardController) {
                    externalKeyboardController.handleKey(event)
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible)
                        Qt.callLater(function () {
                            notificationContent.forceActiveFocus()
                        })
                    else
                        notificationContent.focus = false
                }
                target: root
            }

            FocusScope {
                id: contentColumn

                anchors.fill: parent
                anchors.margins: Theme.spacingL
                focus: true

                Column {
                    id: contentColumnInner
                    anchors.fill: parent
                    spacing: Theme.spacingM

                    NotificationHeader {
                        id: notificationHeader
                        objectName: "notificationHeader"
                        onHeightChanged: notificationContent.cachedHeaderHeight = height
                    }

                    NotificationSettings {
                        id: notificationSettings
                        expanded: notificationHeader.showSettings
                    }

                    KeyboardNavigatedNotificationList {
                        id: notificationList
                        objectName: "notificationList"

                        width: parent.width
                        height: parent.height - notificationContent.cachedHeaderHeight
                                - notificationSettings.height - contentColumnInner.spacing * 2
                    }
                }
            }

            NotificationKeyboardHints {
                id: keyboardHints
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                showHints: externalKeyboardController ? externalKeyboardController.showKeyboardHints : false
                z: 200
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutQuart
                }
            }
        }
    }
}
