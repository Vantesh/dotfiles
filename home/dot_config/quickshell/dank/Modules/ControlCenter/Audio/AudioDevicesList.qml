import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property string currentSinkDisplayName: AudioService.sink ? AudioService.displayName(
                                                                    AudioService.sink) : ""

    width: parent.width
    spacing: Theme.spacingM

    StyledText {
        text: "Output Device"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
    }

    Rectangle {
        width: parent.width
        height: 35
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g,
                              Theme.primary.b, 0.3)
        border.width: 1
        visible: AudioService.sink !== null

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankIcon {
                name: "check_circle"
                size: Theme.iconSize - 4
                color: Theme.primary
            }

            StyledText {
                text: "Current: " + (root.currentSinkDisplayName || "None")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.primary
                font.weight: Font.Medium
            }
        }
    }

    Repeater {
        model: {
            if (!Pipewire.ready || !Pipewire.nodes || !Pipewire.nodes.values)
                return []

            let sinks = []
            for (var i = 0; i < Pipewire.nodes.values.length; i++) {
                let node = Pipewire.nodes.values[i]
                if (!node || node.isStream)
                    continue

                if ((node.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
                    sinks.push(node)
            }
            return sinks
        }

        Rectangle {
            width: parent.width
            height: 50
            radius: Theme.cornerRadius
            color: deviceArea.containsMouse ? Qt.rgba(
                                                  Theme.primary.r, Theme.primary.g,
                                                  Theme.primary.b, 0.08) : (modelData === AudioService.sink ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
            border.color: modelData === AudioService.sink ? Theme.primary : "transparent"
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: {
                        if (modelData.name.includes("bluez"))
                            return "headset"
                        else if (modelData.name.includes("hdmi"))
                            return "tv"
                        else if (modelData.name.includes("usb"))
                            return "headset"
                        else
                            return "speaker"
                    }
                    size: Theme.iconSize
                    color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: AudioService.displayName(modelData)
                        font.pixelSize: Theme.fontSizeMedium
                        color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                        font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                    }

                    StyledText {
                        text: {
                            if (AudioService.subtitle(modelData.name)
                                    && AudioService.subtitle(
                                        modelData.name) !== "")
                                return AudioService.subtitle(modelData.name)
                                        + (modelData === AudioService.sink ? " • Selected" : "")
                            else
                                return modelData === AudioService.sink ? "Selected" : ""
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r,
                                       Theme.surfaceText.g,
                                       Theme.surfaceText.b, 0.7)
                        visible: text !== ""
                    }
                }
            }

            MouseArea {
                id: deviceArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData)
                        Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }
}
