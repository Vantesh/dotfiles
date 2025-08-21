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

    function resetHideTimer() {
        if (root.shouldBeVisible)
            root.hideTimer.restart();
    }

    Connections {
        target: AudioService

        function onVolumeChangedViaIPC() {
            root.show();
        }

        function onSinkChanged() {
            if (root.shouldBeVisible)
                root.show();
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
                    name: AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.muted ? "volume_off" : "volume_up"
                    size: Theme.iconSize
                    color: muteButton.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: muteButton

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AudioService.toggleMute();
                        root.resetHideTimer();
                    }
                }
            }

            DankSlider {
                id: volumeSlider

                width: parent.width - Theme.iconSize - parent.gap * 3
                height: 40
                x: parent.gap * 2 + Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                minimum: 0
                maximum: 100
                enabled: AudioService.sink && AudioService.sink.audio
                showValue: true
                unit: "%"

                Component.onCompleted: {
                    if (AudioService.sink && AudioService.sink.audio)
                        value = Math.round(AudioService.sink.audio.volume * 100);
                }

                onSliderValueChanged: function (newValue) {
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.volume = newValue / 100;
                        root.resetHideTimer();
                    }
                }

                Connections {
                    target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

                    function onVolumeChanged() {
                        if (volumeSlider && !volumeSlider.pressed)
                            volumeSlider.value = Math.round(AudioService.sink.audio.volume * 100);
                    }
                }
            }
        }
    }

    onOsdShown: {
        if (AudioService.sink && AudioService.sink.audio && contentLoader.item) {
            let slider = contentLoader.item.children[0].children[1];
            if (slider)
                slider.value = Math.round(AudioService.sink.audio.volume * 100);
        }
    }
}
