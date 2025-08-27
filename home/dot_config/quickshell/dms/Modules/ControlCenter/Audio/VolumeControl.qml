import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    width: parent.width
    spacing: Theme.spacingM

    StyledText {
        text: "Volume"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
    }

    DankSlider {
        id: volumeSlider

        width: parent.width
        minimum: 0
        maximum: 100
        value: AudioService.sink.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0
        leftIcon: (AudioService.sink.audio && AudioService.sink.audio.muted) ? "volume_off" : "volume_down"
        rightIcon: "volume_up"
        enabled: !(AudioService.sink.audio && AudioService.sink.audio.muted)
        showValue: true
        unit: "%"

        onSliderValueChanged: newValue => {
            if (AudioService.sink?.ready && AudioService.sink.audio) {
                AudioService.sink.audio.volume = newValue / 100
            }
        }

        MouseArea {
            x: 0
            y: 0
            width: Theme.iconSize
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (AudioService.sink?.ready && AudioService.sink.audio) {
                    AudioService.sink.audio.muted = !AudioService.sink.audio.muted
                }
            }
        }
    }
}
