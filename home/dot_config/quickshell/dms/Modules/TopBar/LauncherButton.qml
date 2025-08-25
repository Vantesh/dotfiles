import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isActive: false
    property string section: "left"
    property var popupTarget: null
    property var parentScreen: null

    signal clicked

    width: 40
    height: 30

    MouseArea {
        id: launcherArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

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

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceTextHover.r, Theme.surfaceTextHover.g,
                       Theme.surfaceTextHover.b,
                       Theme.surfaceTextHover.a * Theme.widgetTransparency)

        SystemLogo {
            visible: SettingsData.useOSLogo
            anchors.centerIn: parent
            width: Theme.iconSize - 3
            height: Theme.iconSize - 3
            colorOverride: SettingsData.osLogoColorOverride
            brightnessOverride: SettingsData.osLogoBrightness
            contrastOverride: SettingsData.osLogoContrast
        }

        DankIcon {
            visible: !SettingsData.useOSLogo
            anchors.centerIn: parent
            name: "apps"
            size: Theme.iconSize - 6
            color: Theme.surfaceText
        }
    }
}
