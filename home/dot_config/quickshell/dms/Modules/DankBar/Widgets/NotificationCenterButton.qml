import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool hasUnread: false
    property bool isActive: false
    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    width: widgetThickness
    height: widgetThickness

    MouseArea {
        id: notificationArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            root.clicked()
        }
    }

    Rectangle {
        id: notificationContent

        anchors.fill: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (SettingsData.dankBarNoBackground) {
                return "transparent"
            }

            const baseColor = notificationArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
        }

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
            size: Theme.iconSize - 6
            color: SessionData.doNotDisturb ? Theme.error : (notificationArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText)
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: Theme.error
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: SettingsData.dankBarNoBackground ? 0 : 6
            anchors.topMargin: SettingsData.dankBarNoBackground ? 0 : 6
            visible: root.hasUnread
        }
    }
}
