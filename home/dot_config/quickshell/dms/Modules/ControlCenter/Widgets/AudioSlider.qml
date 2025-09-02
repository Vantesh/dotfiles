import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

SimpleSlider {
    id: root

    property var defaultSink: AudioService.sink

    iconName: {
        if (!defaultSink) return "volume_off"
        
        let volume = defaultSink.audio.volume
        let muted = defaultSink.audio.muted
        
        if (muted || volume === 0.0) return "volume_off"
        if (volume <= 0.33) return "volume_down"
        if (volume <= 0.66) return "volume_up"
        return "volume_up"
    }

    iconColor: defaultSink && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText

    enabled: defaultSink !== null
    allowIconClick: defaultSink !== null

    value: defaultSink ? defaultSink.audio.volume : 0.0
    maximumValue: 1.0
    minimumValue: 0.0

    onSliderValueChanged: function(newValue) {
        if (defaultSink) {
            defaultSink.audio.volume = newValue
            if (newValue > 0 && defaultSink.audio.muted) {
                defaultSink.audio.muted = false
            }
        }
    }

    onIconClicked: function() {
        if (defaultSink) {
            defaultSink.audio.muted = !defaultSink.audio.muted
        }
    }
}