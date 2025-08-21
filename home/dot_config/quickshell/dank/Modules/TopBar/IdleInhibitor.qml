import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null

    width: 40
    height: 30
    radius: Theme.cornerRadius
    color: {
        const baseColor = mouseArea.containsMouse ? Theme.primaryPressed : (IdleInhibitorService.idleInhibited ? Theme.primaryHover : Theme.secondaryHover)
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }

    DankIcon {
        anchors.centerIn: parent
        name: IdleInhibitorService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
        size: Theme.iconSize - 6
        color: Theme.surfaceText
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            IdleInhibitorService.toggleIdleInhibit()
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
