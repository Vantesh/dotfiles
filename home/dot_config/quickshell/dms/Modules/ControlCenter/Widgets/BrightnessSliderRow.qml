import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    height: 40
    spacing: 0

    Rectangle {
        width: Theme.iconSize + Theme.spacingS * 2
        height: Theme.iconSize + Theme.spacingS * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingS * 2) / 2
        color: iconArea.containsMouse
               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
               : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration }
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: function(event) {
                if (DisplayService.devices.length > 1) {
                    if (deviceMenu.visible) {
                        deviceMenu.close()
                    } else {
                        deviceMenu.popup(iconArea, 0, iconArea.height + Theme.spacingXS)
                    }
                    event.accepted = true
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: {
                    if (!DisplayService.brightnessAvailable) return "brightness_low"

                    let brightness = DisplayService.brightnessLevel
                    if (brightness <= 33) return "brightness_low"
                    if (brightness <= 66) return "brightness_medium"
                    return "brightness_high"
                }
                size: Theme.iconSize
                color: DisplayService.brightnessAvailable && DisplayService.brightnessLevel > 0 ? Theme.primary : Theme.surfaceText
            }
        }
    }

    DankSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
        enabled: DisplayService.brightnessAvailable
        minimum: 1
        maximum: 100
        value: {
            let level = DisplayService.brightnessLevel
            if (level > 100) {
                let deviceInfo = DisplayService.getCurrentDeviceInfo()
                if (deviceInfo && deviceInfo.max > 0) {
                    return Math.round((level / deviceInfo.max) * 100)
                }
                return 50
            }
            return level
        }
        onSliderValueChanged: function(newValue) {
            if (DisplayService.brightnessAvailable) {
                DisplayService.setBrightness(newValue)
            }
        }
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
    }

    Menu {
        id: deviceMenu
        width: 200
        closePolicy: Popup.CloseOnEscape
        
        background: Rectangle {
            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }
        
        Instantiator {
            model: DisplayService.devices
            delegate: MenuItem {
                required property var modelData
                required property int index
                
                property string deviceName: modelData.name || ""
                property string deviceClass: modelData.class || ""
                
                text: deviceName
                font.pixelSize: Theme.fontSizeMedium
                height: 40
                
                indicator: Rectangle {
                    visible: DisplayService.currentDevice === parent.deviceName
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingS
                    width: 4
                    height: parent.height - Theme.spacingS * 2
                    radius: 2
                    color: Theme.primary
                }
                
                contentItem: StyledText {
                    text: parent.text
                    font: parent.font
                    color: DisplayService.currentDevice === parent.deviceName ? Theme.primary : Theme.surfaceText
                    leftPadding: Theme.spacingL
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                    radius: Theme.cornerRadius / 2
                }
                
                onTriggered: {
                    DisplayService.setCurrentDevice(deviceName, true)
                    deviceMenu.close()
                }
            }
            onObjectAdded: (index, object) => deviceMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => deviceMenu.removeItem(object)
        }
    }
}