import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Services
import qs.Widgets

Item {
    id: displayTab

    property var brightnessDebounceTimer

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingL

            Loader {
                width: parent.width
                sourceComponent: brightnessComponent
            }

            Loader {
                width: parent.width
                sourceComponent: settingsComponent
            }
        }
    }

    Component {
        id: brightnessComponent

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: BrightnessService.brightnessAvailable

            StyledText {
                text: "Brightness"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
            }

            DankDropdown {
                id: deviceDropdown
                width: parent.width
                height: 40
                visible: BrightnessService.devices.length > 1
                text: "Device"
                description: {
                    const deviceInfo = BrightnessService.getCurrentDeviceInfo()
                    if (deviceInfo && deviceInfo.class === "ddc") {
                        return "DDC changes can be slow and unreliable"
                    }
                    return ""
                }
                currentValue: BrightnessService.currentDevice
                options: BrightnessService.devices.map(function (d) {
                    return d.name
                })
                optionIcons: BrightnessService.devices.map(function (d) {
                    if (d.class === "backlight")
                        return "desktop_windows"

                    if (d.class === "ddc")
                        return "tv"

                    if (d.name.includes("kbd"))
                        return "keyboard"

                    return "lightbulb"
                })
                onValueChanged: function (value) {
                    BrightnessService.setCurrentDevice(value, true)
                }

                Connections {
                    target: BrightnessService
                    function onDevicesChanged() {
                        if (BrightnessService.currentDevice) {
                            deviceDropdown.currentValue = BrightnessService.currentDevice
                        }

                        // Check if saved device is now available
                        const lastDevice = SessionData.lastBrightnessDevice
                                         || ""
                        if (lastDevice) {
                            const deviceExists = BrightnessService.devices.some(
                                                   d => d.name === lastDevice)
                            if (deviceExists
                                    && (!BrightnessService.currentDevice
                                        || BrightnessService.currentDevice !== lastDevice)) {
                                BrightnessService.setCurrentDevice(lastDevice,
                                                                   false)
                            }
                        }
                    }
                    function onDeviceSwitched() {
                        // Force update the description when device switches
                        deviceDropdown.description = Qt.binding(function () {
                            const deviceInfo = BrightnessService.getCurrentDeviceInfo()
                            if (deviceInfo && deviceInfo.class === "ddc") {
                                return "DDC changes can be slow and unreliable"
                            }
                            return ""
                        })
                    }
                }
            }

            DankSlider {
                id: brightnessSlider
                width: parent.width
                value: BrightnessService.brightnessLevel
                leftIcon: "brightness_low"
                rightIcon: "brightness_high"
                enabled: BrightnessService.brightnessAvailable
                         && BrightnessService.isCurrentDeviceReady()
                opacity: BrightnessService.isCurrentDeviceReady() ? 1.0 : 0.5
                onSliderValueChanged: function (newValue) {
                    brightnessDebounceTimer.pendingValue = newValue
                    brightnessDebounceTimer.restart()
                }
                onSliderDragFinished: function (finalValue) {
                    brightnessDebounceTimer.stop()
                    BrightnessService.setBrightnessInternal(
                                finalValue, BrightnessService.currentDevice)
                }

                Connections {
                    target: BrightnessService
                    function onBrightnessChanged() {
                        brightnessSlider.value = BrightnessService.brightnessLevel
                    }

                    function onDeviceSwitched() {
                        brightnessSlider.value = BrightnessService.brightnessLevel
                    }
                }
            }
        }
    }

    Component {
        id: settingsComponent

        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Display Settings"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 80
                    radius: Theme.cornerRadius
                    color: BrightnessService.nightModeActive ? Qt.rgba(
                                                                   Theme.primary.r,
                                                                   Theme.primary.g,
                                                                   Theme.primary.b,
                                                                   0.12) : (nightModeToggle.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                    border.color: BrightnessService.nightModeActive ? Theme.primary : "transparent"
                    border.width: BrightnessService.nightModeActive ? 1 : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: BrightnessService.nightModeActive ? "nightlight" : "dark_mode"
                            size: Theme.iconSizeLarge
                            color: BrightnessService.nightModeActive ? Theme.primary : Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: "Night Mode"
                            font.pixelSize: Theme.fontSizeMedium
                            color: BrightnessService.nightModeActive ? Theme.primary : Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: nightModeToggle

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BrightnessService.toggleNightMode()
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 80
                    radius: Theme.cornerRadius
                    color: SessionData.isLightMode ? Qt.rgba(
                                                   Theme.primary.r,
                                                   Theme.primary.g,
                                                   Theme.primary.b,
                                                   0.12) : (lightModeToggle.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                    border.color: SessionData.isLightMode ? Theme.primary : "transparent"
                    border.width: SessionData.isLightMode ? 1 : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: SessionData.isLightMode ? "light_mode" : "palette"
                            size: Theme.iconSizeLarge
                            color: SessionData.isLightMode ? Theme.primary : Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: SessionData.isLightMode ? "Light Mode" : "Dark Mode"
                            font.pixelSize: Theme.fontSizeMedium
                            color: SessionData.isLightMode ? Theme.primary : Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: lightModeToggle

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.toggleLightMode()
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }
    }

    brightnessDebounceTimer: Timer {
        property int pendingValue: 0

        interval: {
            // Use longer interval for DDC devices since ddcutil is slow
            const deviceInfo = BrightnessService.getCurrentDeviceInfo()
            return (deviceInfo && deviceInfo.class === "ddc") ? 100 : 50
        }
        repeat: false
        onTriggered: {
            BrightnessService.setBrightnessInternal(
                        pendingValue, BrightnessService.currentDevice)
        }
    }
}
