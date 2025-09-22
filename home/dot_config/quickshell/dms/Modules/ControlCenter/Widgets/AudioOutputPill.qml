import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
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

    isActive: defaultSink && !defaultSink.audio.muted

    primaryText: {
        if (!defaultSink) {
            return "No output device"
        }
        return defaultSink.description || "Audio Output"
    }

    secondaryText: {
        if (!defaultSink) {
            return "Select device"
        }
        if (defaultSink.audio.muted) {
            return "Muted"
        }
        return Math.round(defaultSink.audio.volume * 100) + "%"
    }

    onToggled: {
        if (defaultSink && defaultSink.audio) {
            defaultSink.audio.muted = !defaultSink.audio.muted
        }
    }

    onWheelEvent: function (wheelEvent) {
        if (!defaultSink || !defaultSink.audio) return
        let delta = wheelEvent.angleDelta.y
        let currentVolume = defaultSink.audio.volume * 100
        let newVolume
        if (delta > 0)
            newVolume = Math.min(100, currentVolume + 5)
        else
            newVolume = Math.max(0, currentVolume - 5)
        defaultSink.audio.muted = false
        defaultSink.audio.volume = newVolume / 100
        AudioService.volumeChanged()
        wheelEvent.accepted = true
    }
}