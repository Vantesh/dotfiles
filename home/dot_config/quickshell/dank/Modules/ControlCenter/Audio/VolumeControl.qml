import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property real volumeLevel: Math.min(
                                   100,
                                   (AudioService.sink && AudioService.sink.audio
                                    && AudioService.sink.audio.volume * 100)
                                   || 0)
    property bool volumeMuted: (AudioService.sink && AudioService.sink.audio
                                && AudioService.sink.audio.muted) || false

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
        leftIcon: root.volumeMuted ? "volume_off" : "volume_down"
        rightIcon: "volume_up"
        enabled: !root.volumeMuted
        showValue: true
        unit: "%"

        Connections {
            target: AudioService.sink
                    && AudioService.sink.audio ? AudioService.sink.audio : null
            function onVolumeChanged() {
                volumeSlider.value = Math.round(
                            AudioService.sink.audio.volume * 100)
            }
        }

        Component.onCompleted: {
            if (AudioService.sink && AudioService.sink.audio) {
                value = Math.round(AudioService.sink.audio.volume * 100)
            }

            let leftIconItem = volumeSlider.children[0].children[0]
            if (leftIconItem) {
                let mouseArea = Qt.createQmlObject(
                        'import QtQuick; import qs.Services; MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (AudioService.sink && AudioService.sink.audio) AudioService.sink.audio.muted = !AudioService.sink.audio.muted; } }',
                        leftIconItem, "dynamicMouseArea")
            }
        }

        onSliderValueChanged: newValue => {
                                  if (AudioService.sink
                                      && AudioService.sink.audio) {
                                      AudioService.sink.audio.muted = false
                                      AudioService.sink.audio.volume = newValue / 100
                                  }
                              }
    }
}
