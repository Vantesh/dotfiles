import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Math.min(260, Screen.width - Theme.spacingM * 2)
    osdHeight: 40 + Theme.spacingS * 2
    autoHideInterval: 3000
    enableMouseInteraction: true

    property var brightnessDebounceTimer: Timer {
        property int pendingValue: 0

        interval: {
            const deviceInfo = BrightnessService.getCurrentDeviceInfo()
            return (deviceInfo && deviceInfo.class === "ddc") ? 200 : 50
        }
        repeat: false
        onTriggered: {
            BrightnessService.setBrightnessInternal(pendingValue, BrightnessService.lastIpcDevice)
        }
    }


    Connections {
        target: BrightnessService
        function onBrightnessChanged() {
            root.show()
        }
    }

    content: Item {
        anchors.fill: parent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            width: parent.width - Theme.spacingS * 2
            height: 40

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: {
                        const deviceInfo = BrightnessService.getCurrentDeviceInfo()
                        if (!deviceInfo || deviceInfo.class === "backlight" || deviceInfo.class === "ddc")
                            return "brightness_medium"
                        else if (deviceInfo.name.includes("kbd"))
                            return "keyboard"
                        else
                            return "lightbulb"
                    }
                    size: Theme.iconSize
                    color: Theme.primary
                }
            }

            DankSlider {
                id: brightnessSlider

                width: parent.width - Theme.iconSize - parent.gap * 3
                height: 40
                x: parent.gap * 2 + Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                minimum: 1
                maximum: 100
                enabled: BrightnessService.brightnessAvailable
                showValue: true
                unit: "%"

                Component.onCompleted: {
                    if (BrightnessService.brightnessAvailable)
                        value = BrightnessService.brightnessLevel
                }

                onSliderValueChanged: function(newValue) {
                    if (BrightnessService.brightnessAvailable) {
                        root.brightnessDebounceTimer.pendingValue = newValue
                        root.brightnessDebounceTimer.restart()
                        resetHideTimer()
                    }
                }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse)
                }

                onSliderDragFinished: function(finalValue) {
                    if (BrightnessService.brightnessAvailable) {
                        root.brightnessDebounceTimer.stop()
                        BrightnessService.setBrightnessInternal(finalValue, BrightnessService.lastIpcDevice)
                    }
                }

                Connections {
                    target: BrightnessService

                    function onBrightnessChanged() {
                        if (!brightnessSlider.pressed)
                            brightnessSlider.value = BrightnessService.brightnessLevel
                    }

                    function onDeviceSwitched() {
                        if (!brightnessSlider.pressed)
                            brightnessSlider.value = BrightnessService.brightnessLevel
                    }
                }
            }
        }
    }

    onOsdShown: {
        if (BrightnessService.brightnessAvailable && contentLoader.item) {
            let slider = contentLoader.item.children[0].children[1]
            if (slider)
                slider.value = BrightnessService.brightnessLevel
        }
    }
}