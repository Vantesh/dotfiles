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
            const deviceInfo = DisplayService.getCurrentDeviceInfo()
            return (deviceInfo && deviceInfo.class === "ddc") ? 200 : 50
        }
        repeat: false
        onTriggered: {
            DisplayService.setBrightnessInternal(pendingValue, DisplayService.lastIpcDevice)
        }
    }

    Connections {
        target: DisplayService
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
                        const deviceInfo = DisplayService.getCurrentDeviceInfo()
                        if (!deviceInfo || deviceInfo.class === "backlight" || deviceInfo.class === "ddc") {
                            return "brightness_medium"
                        } else if (deviceInfo.name.includes("kbd")) {
                            return "keyboard"
                        } else {
                            return "lightbulb"
                        }
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
                enabled: DisplayService.brightnessAvailable
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                Component.onCompleted: {
                    if (DisplayService.brightnessAvailable) {
                        value = DisplayService.brightnessLevel
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (DisplayService.brightnessAvailable) {
                                              root.brightnessDebounceTimer.pendingValue = newValue
                                              root.brightnessDebounceTimer.restart()
                                              resetHideTimer()
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse)
                }

                onSliderDragFinished: finalValue => {
                                          if (DisplayService.brightnessAvailable) {
                                              root.brightnessDebounceTimer.stop()
                                              DisplayService.setBrightnessInternal(finalValue, DisplayService.lastIpcDevice)
                                          }
                                      }

                Connections {
                    target: DisplayService

                    function onBrightnessChanged() {
                        if (!brightnessSlider.pressed) {
                            brightnessSlider.value = DisplayService.brightnessLevel
                        }
                    }

                    function onDeviceSwitched() {
                        if (!brightnessSlider.pressed) {
                            brightnessSlider.value = DisplayService.brightnessLevel
                        }
                    }
                }
            }
        }
    }

    onOsdShown: {
        if (DisplayService.brightnessAvailable && contentLoader.item) {
            const slider = contentLoader.item.children[0].children[1]
            if (slider) {
                slider.value = DisplayService.brightnessLevel
            }
        }
    }
}
