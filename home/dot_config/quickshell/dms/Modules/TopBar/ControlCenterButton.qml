import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property var widgetData: null

    property bool showNetworkIcon: SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: SettingsData.controlCenterShowAudioIcon
    property real widgetHeight: 30
    property real barHeight: 48
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked
    signal iconClicked(string tab)

    width: controlIndicators.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = controlCenterArea.containsMouse
                        || root.isActive ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }

    Row {
        id: controlIndicators

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            id: networkIcon
            name: {
                if (NetworkService.networkStatus === "ethernet")
                    return "lan"
                return NetworkService.wifiSignalIcon
            }
            size: Theme.iconSize - 8
            color: NetworkService.networkStatus
                   !== "disconnected" ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showNetworkIcon
        }

        DankIcon {
            id: bluetoothIcon
            name: "bluetooth"
            size: Theme.iconSize - 8
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
        }

        Rectangle {
            width: audioIcon.implicitWidth + 4
            height: audioIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showAudioIcon

            DankIcon {
                id: audioIcon

                name: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        if (AudioService.sink.audio.muted
                                || AudioService.sink.audio.volume === 0)
                            return "volume_off"
                        else if (AudioService.sink.audio.volume * 100 < 33)
                            return "volume_down"
                        else
                            return "volume_up"
                    }
                    return "volume_up"
                }
                size: Theme.iconSize - 8
                color: Theme.surfaceText
                anchors.centerIn: parent
            }

            MouseArea {
                id: audioWheelArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onWheel: function (wheelEvent) {
                    let delta = wheelEvent.angleDelta.y
                    let currentVolume = (AudioService.sink
                                         && AudioService.sink.audio
                                         && AudioService.sink.audio.volume * 100)
                        || 0
                    let newVolume
                    if (delta > 0)
                        newVolume = Math.min(100, currentVolume + 5)
                    else
                        newVolume = Math.max(0, currentVolume - 5)
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = false
                        AudioService.sink.audio.volume = newVolume / 100
                        AudioService.volumeChanged()
                    }
                    wheelEvent.accepted = true
                }
            }
        }

        DankIcon {
            name: "mic"
            size: Theme.iconSize - 8
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            visible: false // TODO: Add mic detection
        }

        // Fallback settings icon when all other icons are hidden
        DankIcon {
            name: "settings"
            size: Theme.iconSize - 8
            color: controlCenterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon
        }
    }

    MouseArea {
        id: controlCenterArea

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

            // Calculate which zone was clicked based on mouse position relative to controlIndicators
            var indicatorsX = controlIndicators.x
            var relativeX = mouseX - indicatorsX
            
            var iconSpacing = Theme.spacingXS
            var iconSize = Theme.iconSize - 8
            var networkWidth = networkIcon.visible ? iconSize : 0
            var bluetoothWidth = bluetoothIcon.visible ? iconSize : 0
            var audioWidth = audioIcon.parent.visible ? (iconSize + 4) : 0
            
            var currentX = 0
            var clickedZone = ""
            
            // Network zone
            if (networkIcon.visible && relativeX >= currentX && relativeX < currentX + networkWidth) {
                clickedZone = "network"
            }
            if (networkIcon.visible) {
                currentX += networkWidth + iconSpacing
            }
            
            // Bluetooth zone  
            if (bluetoothIcon.visible && relativeX >= currentX && relativeX < currentX + bluetoothWidth) {
                clickedZone = "bluetooth"
            }
            if (bluetoothIcon.visible) {
                currentX += bluetoothWidth + iconSpacing
            }
            
            // Audio zone
            if (audioIcon.parent.visible && relativeX >= currentX && relativeX < currentX + audioWidth) {
                clickedZone = "audio"
            }
            
            if (clickedZone !== "") {
                root.iconClicked(clickedZone)
            } else {
                root.clicked()
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
