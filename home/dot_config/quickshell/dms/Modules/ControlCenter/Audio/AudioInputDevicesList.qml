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

    property string currentSourceDisplayName: AudioService.source ? AudioService.displayName(
                                                                        AudioService.source) : ""

    width: parent.width
    spacing: Theme.spacingM

    StyledText {
        text: "Input Device"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
    }



    Repeater {
        model: Pipewire.nodes.values.filter(node => {
            return  node.audio && !node.isSink && !node.isStream
        })

        Rectangle {
            width: parent.width
            height: 50
            radius: Theme.cornerRadius
            color: sourceArea.containsMouse ? Qt.rgba(
                                                  Theme.primary.r, Theme.primary.g,
                                                  Theme.primary.b, 0.08) : (modelData === AudioService.source ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
            border.color: modelData === AudioService.source ? Theme.primary : "transparent"
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: {
                        if (modelData.name.includes("bluez"))
                            return "headset_mic"
                        else if (modelData.name.includes("usb"))
                            return "headset_mic"
                        else
                            return "mic"
                    }
                    size: Theme.iconSize
                    color: modelData === AudioService.source ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - parent.spacing - Theme.iconSize
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: AudioService.displayName(modelData)
                        font.pixelSize: Theme.fontSizeMedium
                        color: modelData === AudioService.source ? Theme.primary : Theme.surfaceText
                        font.weight: modelData === AudioService.source ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    StyledText {
                        width: parent.width
                        text: {
                            if (AudioService.subtitle(modelData.name)
                                    && AudioService.subtitle(
                                        modelData.name) !== "")
                                return AudioService.subtitle(modelData.name)
                                        + (modelData === AudioService.source ? " • Selected" : "")
                            else
                                return modelData === AudioService.source ? "Selected" : ""
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r,
                                       Theme.surfaceText.g,
                                       Theme.surfaceText.b, 0.7)
                        visible: text !== ""
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }
            }

            MouseArea {
                id: sourceArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData)
                        Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }
}
