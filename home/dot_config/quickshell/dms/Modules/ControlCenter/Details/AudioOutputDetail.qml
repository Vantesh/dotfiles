import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    implicitHeight: headerRow.height + audioContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.6)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: 40
        
        StyledText {
            id: headerText
            text: "Audio Devices"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    
    DankFlickable {
        id: audioContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        contentHeight: audioColumn.height
        clip: true
        
        Column {
            id: audioColumn
            width: parent.width
            spacing: Theme.spacingS
            
            Repeater {
                model: Pipewire.nodes.values.filter(node => {
                    return node.audio && node.isSink && !node.isStream
                })
                
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: deviceMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                    border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: modelData === AudioService.sink ? 2 : 1
                    
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        
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
                            size: Theme.iconSize - 4
                            color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width - parent.parent.anchors.leftMargin - parent.spacing - Theme.iconSize - Theme.spacingM
                            
                            StyledText {
                                text: AudioService.displayName(modelData)
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                            
                            StyledText {
                                text: modelData === AudioService.sink ? "Active" : "Available"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                    
                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData) {
                                Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                    
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                }
            }
        }
    }
}