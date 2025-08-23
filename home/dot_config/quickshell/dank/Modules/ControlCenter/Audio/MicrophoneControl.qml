import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property real micLevel: Math.min(100, (AudioService.source && AudioService.source.audio && AudioService.source.audio.volume * 100) || 0)
    property bool micMuted: (AudioService.source && AudioService.source.audio && AudioService.source.audio.muted) || false

    width: parent.width
    spacing: Theme.spacingM

    StyledText {
        text: "Microphone Level"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        DankIcon {
            name: root.micMuted ? "mic_off" : "mic"
            size: Theme.iconSize
            color: root.micMuted ? Theme.error : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (AudioService.source && AudioService.source.audio)
                        AudioService.source.audio.muted = !AudioService.source.audio.muted;
                }
            }
        }

        Item {
            id: micSliderContainer

            width: parent.width - 80
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: micSliderTrack

                width: parent.width
                height: 8
                radius: 4
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: micSliderFill

                    width: parent.width * (root.micLevel / 100)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: Anims.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anims.standardDecel
                        }
                    }
                }

                Rectangle {
                    id: micHandle

                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.primary
                    border.color: Qt.lighter(Theme.primary, 1.3)
                    border.width: 2
                    x: Math.max(0, Math.min(parent.width - width, micSliderFill.width - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    scale: micMouseArea.containsMouse || micMouseArea.pressed ? 1.2 : 1

                    Rectangle {
                        id: micTooltip

                        width: tooltipText.contentWidth + Theme.spacingS * 2
                        height: tooltipText.contentHeight + Theme.spacingXS * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer
                        border.color: Theme.outline
                        border.width: 1
                        anchors.bottom: parent.top
                        anchors.bottomMargin: Theme.spacingS
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: (micMouseArea.containsMouse && !root.micMuted) || micMouseArea.isDragging
                        opacity: visible ? 1 : 0

                        StyledText {
                            id: tooltipText

                            text: Math.round(root.micLevel) + "%"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.centerIn: parent
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Anims.durShort
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anims.standard
                        }
                    }
                }
            }

            MouseArea {
                id: micMouseArea

                property bool isDragging: false

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: mouse => {
                    isDragging = true;
                    let ratio = Math.max(0, Math.min(1, mouse.x / micSliderTrack.width));
                    let newMicLevel = Math.round(ratio * 100);
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.source.audio.muted = false;
                        AudioService.source.audio.volume = newMicLevel / 100;
                    }
                }
                onReleased: {
                    isDragging = false;
                }
                onPositionChanged: mouse => {
                    if (pressed && isDragging) {
                        let ratio = Math.max(0, Math.min(1, mouse.x / micSliderTrack.width));
                        let newMicLevel = Math.max(0, Math.min(100, Math.round(ratio * 100)));
                        if (AudioService.source && AudioService.source.audio) {
                            AudioService.source.audio.muted = false;
                            AudioService.source.audio.volume = newMicLevel / 100;
                        }
                    }
                }
                onClicked: mouse => {
                    let ratio = Math.max(0, Math.min(1, mouse.x / micSliderTrack.width));
                    let newMicLevel = Math.round(ratio * 100);
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.source.audio.muted = false;
                        AudioService.source.audio.volume = newMicLevel / 100;
                    }
                }
            }

            MouseArea {
                id: micGlobalMouseArea

                x: 0
                y: 0
                width: root.parent ? root.parent.width : 0
                height: root.parent ? root.parent.height : 0
                enabled: micMouseArea.isDragging
                visible: false
                preventStealing: true
                onPositionChanged: mouse => {
                    if (micMouseArea.isDragging) {
                        let globalPos = mapToItem(micSliderTrack, mouse.x, mouse.y);
                        let ratio = Math.max(0, Math.min(1, globalPos.x / micSliderTrack.width));
                        let newMicLevel = Math.max(0, Math.min(100, Math.round(ratio * 100)));
                        if (AudioService.source && AudioService.source.audio) {
                            AudioService.source.audio.muted = false;
                            AudioService.source.audio.volume = newMicLevel / 100;
                        }
                    }
                }
                onReleased: {
                    micMouseArea.isDragging = false;
                }
            }
        }

        DankIcon {
            name: "mic"
            size: Theme.iconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
