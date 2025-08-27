pragma Singleton

pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    signal volumeChanged
    signal micMuteChanged

    function displayName(node) {
        if (!node)
            return ""

        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"]
        }

        if (node.description && node.description !== node.name) {
            return node.description
        }

        if (node.nickname && node.nickname !== node.name) {
            return node.nickname
        }

        if (node.name.includes("analog-stereo"))
            return "Built-in Speakers"
        else if (node.name.includes("bluez"))
            return "Bluetooth Audio"
        else if (node.name.includes("usb"))
            return "USB Audio"
        else if (node.name.includes("hdmi"))
            return "HDMI Audio"

        return node.name
    }

    function subtitle(name) {
        if (!name)
            return ""

        if (name.includes('usb-')) {
            if (name.includes('SteelSeries')) {
                return "USB Gaming Headset"
            } else if (name.includes('Generic')) {
                return "USB Audio Device"
            }
            return "USB Audio"
        } else if (name.includes('pci-')) {
            if (name.includes('01_00.1') || name.includes('01:00.1')) {
                return "NVIDIA GPU Audio"
            }
            return "PCI Audio"
        } else if (name.includes('bluez')) {
            return "Bluetooth Audio"
        } else if (name.includes('analog')) {
            return "Built-in Audio"
        } else if (name.includes('hdmi')) {
            return "HDMI Audio"
        }

        return ""
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(
            node => node.audio && !node.isStream
        )
    }

    // Volume control functions
    function setVolume(percentage) {
        if (root.sink && root.sink.audio) {
            const clampedVolume = Math.max(0, Math.min(100, percentage))
            root.sink.audio.volume = clampedVolume / 100
            root.volumeChanged()
            return "Volume set to " + clampedVolume + "%"
        }
        return "No audio sink available"
    }

    function toggleMute() {
        if (root.sink && root.sink.audio) {
            root.sink.audio.muted = !root.sink.audio.muted
            return root.sink.audio.muted ? "Audio muted" : "Audio unmuted"
        }
        return "No audio sink available"
    }

    function setMicVolume(percentage) {
        if (root.source && root.source.audio) {
            const clampedVolume = Math.max(0, Math.min(100, percentage))
            root.source.audio.volume = clampedVolume / 100
            return "Microphone volume set to " + clampedVolume + "%"
        }
        return "No audio source available"
    }

    function toggleMicMute() {
        if (root.source && root.source.audio) {
            root.source.audio.muted = !root.source.audio.muted
            return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted"
        }
        return "No audio source available"
    }

    // IPC Handler for external control
    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            return root.setVolume(parseInt(percentage))
        }

        function increment(step: string): string {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted) {
                    root.sink.audio.muted = false
                }
                const currentVolume = Math.round(root.sink.audio.volume * 100)
                const newVolume = Math.max(0, Math.min(100,
                                                       currentVolume + parseInt(
                                                           step || "5")))
                root.sink.audio.volume = newVolume / 100
                root.volumeChanged()
                return "Volume increased to " + newVolume + "%"
            }
            return "No audio sink available"
        }

        function decrement(step: string): string {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted) {
                    root.sink.audio.muted = false
                }
                const currentVolume = Math.round(root.sink.audio.volume * 100)
                const newVolume = Math.max(0, Math.min(100,
                                                       currentVolume - parseInt(
                                                           step || "5")))
                root.sink.audio.volume = newVolume / 100
                root.volumeChanged()
                return "Volume decreased to " + newVolume + "%"
            }
            return "No audio sink available"
        }

        function mute(): string {
            const result = root.toggleMute()
            root.volumeChanged()
            return result
        }

        function setmic(percentage: string): string {
            return root.setMicVolume(parseInt(percentage))
        }

        function micmute(): string {
            const result = root.toggleMicMute()
            root.micMuteChanged()
            return result
        }

        function status(): string {
            let result = "Audio Status:\n"
            if (root.sink && root.sink.audio) {
                const volume = Math.round(root.sink.audio.volume * 100)
                result += "Output: " + volume + "%"
                        + (root.sink.audio.muted ? " (muted)" : "") + "\n"
            } else {
                result += "Output: No sink available\n"
            }

            if (root.source && root.source.audio) {
                const micVolume = Math.round(root.source.audio.volume * 100)
                result += "Input: " + micVolume + "%" + (root.source.audio.muted ? " (muted)" : "")
            } else {
                result += "Input: No source available"
            }

            return result
        }
    }
}
