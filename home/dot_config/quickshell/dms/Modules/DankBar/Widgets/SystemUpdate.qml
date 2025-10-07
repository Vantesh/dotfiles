import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))
    readonly property bool hasUpdates: SystemUpdateService.updateCount > 0
    readonly property bool isChecking: SystemUpdateService.isChecking

    signal clicked()

    width: isVertical ? widgetThickness : (updaterIcon.width + horizontalPadding * 2)
    height: isVertical ? widgetThickness : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = updaterArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    DankIcon {
        id: statusIcon

        anchors.centerIn: parent
        visible: root.isVertical
        name: {
            if (isChecking) return "refresh";
            if (SystemUpdateService.hasError) return "error";
            if (hasUpdates) return "system_update_alt";
            return "check_circle";
        }
        size: Theme.barIconSize(barThickness, -4)
        color: {
            if (SystemUpdateService.hasError) return Theme.error;
            if (hasUpdates) return Theme.primary;
            return (updaterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText);
        }

        RotationAnimation {
            id: rotationAnimation
            target: statusIcon
            property: "rotation"
            from: 0
            to: 360
            duration: 1000
            running: isChecking
            loops: Animation.Infinite

            onRunningChanged: {
                if (!running) {
                    statusIcon.rotation = 0
                }
            }
        }
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
        visible: root.isVertical && root.hasUpdates && !root.isChecking
    }

    Row {
        id: updaterIcon

        anchors.centerIn: parent
        spacing: Theme.spacingXS
        visible: !root.isVertical

        DankIcon {
            id: statusIconHorizontal

            anchors.verticalCenter: parent.verticalCenter
            name: {
                if (isChecking) return "refresh";
                if (SystemUpdateService.hasError) return "error";
                if (hasUpdates) return "system_update_alt";
                return "check_circle";
            }
            size: Theme.barIconSize(barThickness, -4)
            color: {
                if (SystemUpdateService.hasError) return Theme.error;
                if (hasUpdates) return Theme.primary;
                return (updaterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText);
            }

            RotationAnimation {
                id: rotationAnimationHorizontal
                target: statusIconHorizontal
                property: "rotation"
                from: 0
                to: 360
                duration: 1000
                running: isChecking
                loops: Animation.Infinite

                onRunningChanged: {
                    if (!running) {
                        statusIconHorizontal.rotation = 0
                    }
                }
            }
        }

        StyledText {
            id: countText

            anchors.verticalCenter: parent.verticalCenter
            text: SystemUpdateService.updateCount.toString()
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            visible: hasUpdates && !isChecking
        }
    }

    MouseArea {
        id: updaterArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            root.clicked();
        }
    }

}