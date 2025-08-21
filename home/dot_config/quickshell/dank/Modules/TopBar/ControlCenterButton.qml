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

    signal clicked

    width: Math.max(80, controlIndicators.implicitWidth + Theme.spacingS * 2)
    height: 30
    radius: Theme.cornerRadius
    color: {
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
            name: {
                if (NetworkService.networkStatus === "ethernet")
                    return "lan"
                return NetworkService.wifiSignalIcon
            }
            size: Theme.iconSize - 8
            color: NetworkService.networkStatus
                   !== "disconnected" ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: true
        }

        DankIcon {
            name: "bluetooth"
            size: Theme.iconSize - 8
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: BluetoothService.available && BluetoothService.enabled
        }

        Rectangle {
            width: audioIcon.implicitWidth + 4
            height: audioIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter

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
                color: audioWheelArea.containsMouse
                       || controlCenterArea.containsMouse
                       || root.isActive ? Theme.primary : Theme.surfaceText
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
                            relativeX, Theme.barHeight + Theme.spacingXS,
                            width, section, currentScreen)
            }
            root.clicked()
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
