import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool hasUnread: false
    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null

    signal clicked

    width: 40
    height: 30
    radius: Theme.cornerRadius
    color: {
        const baseColor = notificationArea.containsMouse
                        || root.isActive ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }

    DankIcon {
        anchors.centerIn: parent
        name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
        size: Theme.iconSize - 6
        color: SessionData.doNotDisturb ? Theme.error : (notificationArea.containsMouse
                                                         || root.isActive ? Theme.primary : Theme.surfaceText)
    }

    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: Theme.error
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6
        anchors.topMargin: 6
        visible: root.hasUnread
    }

    MouseArea {
        id: notificationArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                var globalPos = mapToGlobal(0, 0)
                var currentScreen = parentScreen || Screen
                var screenX = currentScreen.x || 0
                var relativeX = globalPos.x - screenX
                popupTarget.setTriggerPosition(
                            relativeX, Theme.barHeight + Theme.spacingXS,
                            width, section, currentScreen)
            }
            root.clicked()
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
