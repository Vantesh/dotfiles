import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isActive: false
    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "left"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    width: widgetThickness
    height: widgetThickness

    MouseArea {
        id: launcherArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            root.clicked();
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width);
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen);
            }
        }
    }

    Rectangle {
        id: launcherContent

        anchors.fill: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (SettingsData.dankBarNoBackground) {
                return "transparent";
            }

            const baseColor = launcherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }

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
