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

    property var defaultSource: AudioService.source

    iconName: {
        if (!defaultSource) return "mic_off"

        let volume = defaultSource.audio.volume
        let muted = defaultSource.audio.muted

        if (muted || volume === 0.0) return "mic_off"
        return "mic"
    }

    isActive: defaultSource && !defaultSource.audio.muted

    primaryText: {
        if (!defaultSource) {
            return "No input device"
        }
        return defaultSource.description || "Audio Input"
    }

    secondaryText: {
        if (!defaultSource) {
            return "Select device"
        }
        if (defaultSource.audio.muted) {
            return "Muted"
        }
        return Math.round(defaultSource.audio.volume * 100) + "%"
    }

    onToggled: {
        if (defaultSource && defaultSource.audio) {
            defaultSource.audio.muted = !defaultSource.audio.muted
        }
    }

    onWheelEvent: function (wheelEvent) {
        if (!defaultSource || !defaultSource.audio) return
        let delta = wheelEvent.angleDelta.y
        let currentVolume = defaultSource.audio.volume * 100
        let newVolume
        if (delta > 0)
            newVolume = Math.min(100, currentVolume + 5)
        else
            newVolume = Math.max(0, currentVolume - 5)
        defaultSource.audio.muted = false
        defaultSource.audio.volume = newVolume / 100
        wheelEvent.accepted = true
    }
}