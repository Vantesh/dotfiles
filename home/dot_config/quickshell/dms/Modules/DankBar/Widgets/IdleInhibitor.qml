import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    width: isVertical ? widgetThickness : (idleIcon.width + horizontalPadding * 2)
    height: isVertical ? (idleIcon.height + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = mouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    DankIcon {
        id: idleIcon

        anchors.centerIn: parent
        name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
        size: Theme.iconSize - 6
        color: Theme.surfaceText
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            SessionService.toggleIdleInhibit();
        }
    }


}
