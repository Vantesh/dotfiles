import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: battery

    property bool batteryPopupVisible: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal toggleBatteryPopup

    width: batteryContent.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = batteryArea.containsMouse
                        || batteryPopupVisible ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    visible: true

    Row {
        id: batteryContent
        anchors.centerIn: parent
        spacing: SettingsData.topBarNoBackground ? 1 : 2

        DankIcon {
            name: {
                if (!BatteryService.batteryAvailable)
                    return "power"

                if (BatteryService.isCharging) {
                    if (BatteryService.batteryLevel >= 90)
                        return "battery_charging_full"
                    if (BatteryService.batteryLevel >= 80)
                        return "battery_charging_90"
                    if (BatteryService.batteryLevel >= 60)
                        return "battery_charging_80"
                    if (BatteryService.batteryLevel >= 50)
                        return "battery_charging_60"
                    if (BatteryService.batteryLevel >= 30)
                        return "battery_charging_50"
                    if (BatteryService.batteryLevel >= 20)
                        return "battery_charging_30"
                    return "battery_charging_20"
                }

                // Check if plugged in but not charging (like at 80% charge limit)
                if (BatteryService.isPluggedIn) {
                    if (BatteryService.batteryLevel >= 90)
                        return "battery_charging_full"
                    if (BatteryService.batteryLevel >= 80)
                        return "battery_charging_90"
                    if (BatteryService.batteryLevel >= 60)
                        return "battery_charging_80"
                    if (BatteryService.batteryLevel >= 50)
                        return "battery_charging_60"
                    if (BatteryService.batteryLevel >= 30)
                        return "battery_charging_50"
                    if (BatteryService.batteryLevel >= 20)
                        return "battery_charging_30"
                    return "battery_charging_20"
                }

                // On battery power
                if (BatteryService.batteryLevel >= 95)
                    return "battery_full"
                if (BatteryService.batteryLevel >= 85)
                    return "battery_6_bar"
                if (BatteryService.batteryLevel >= 70)
                    return "battery_5_bar"
                if (BatteryService.batteryLevel >= 55)
                    return "battery_4_bar"
                if (BatteryService.batteryLevel >= 40)
                    return "battery_3_bar"
                if (BatteryService.batteryLevel >= 25)
                    return "battery_2_bar"
                return "battery_1_bar"
            }
            size: Theme.iconSize - 6
            color: {
                if (!BatteryService.batteryAvailable)
                    return Theme.surfaceText

                if (BatteryService.isLowBattery && !BatteryService.isCharging)
                    return Theme.error

                if (BatteryService.isCharging || BatteryService.isPluggedIn)
                    return Theme.primary

                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: BatteryService.batteryLevel + "%"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: {
                if (!BatteryService.batteryAvailable)
                    return Theme.surfaceText

                if (BatteryService.isLowBattery && !BatteryService.isCharging)
                    return Theme.error

                if (BatteryService.isCharging)
                    return Theme.primary

                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.batteryAvailable
        }
    }

    MouseArea {
        id: batteryArea

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
                            relativeX, barHeight + Theme.spacingXS,
                            width, section, currentScreen)
            }
            toggleBatteryPopup()
        }
    }

    Rectangle {
        id: batteryTooltip

        width: Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2)
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Theme.surfaceVariantAlpha
        border.width: 1
        visible: batteryArea.containsMouse && !batteryPopupVisible
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: batteryArea.containsMouse ? 1 : 0

        Column {
            anchors.centerIn: parent
            spacing: 2

            StyledText {
                id: tooltipText

                text: {
                    if (!BatteryService.batteryAvailable) {
                        if (typeof PowerProfiles === "undefined")
                            return "Power Management"

                        switch (PowerProfiles.profile) {
                        case PowerProfile.PowerSaver:
                            return "Power Profile: Power Saver"
                        case PowerProfile.Performance:
                            return "Power Profile: Performance"
                        default:
                            return "Power Profile: Balanced"
                        }
                    }
                    let status = BatteryService.batteryStatus
                    let level = BatteryService.batteryLevel + "%"
                    let time = BatteryService.formatTimeRemaining()
                    if (time !== "Unknown")
                        return status + " • " + level + " • " + time
                    else
                        return status + " • " + level
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
