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

    // Auto-switching settings
    property bool autoSwitchToBluetoothAudio: true
    property int monitoringErrorCount: 0
    property bool monitoringEnabled: true

    // Efficient monitoring - only when Bluetooth devices are present
    property bool hasConnectedBluetoothAudio: false
    property int idleMonitoringInterval: 5000    // Check every 5s when BT devices present
    property int discoveryMonitoringInterval: 15000  // Check every 15s to discover new devices

    // Audio signals
    signal volumeChanged
    signal volumeChangedViaIPC  // Only for IPC volume changes to show popup
    signal micMuteChanged
    signal audioDeviceAutoSwitched(string deviceName, string reason)

    function displayName(node) {
        if (!node)
            return "";

        try {
            if (node.properties && node.properties["device.description"]) {
                return node.properties["device.description"];
            }

            if (node.description && node.description !== node.name) {
                return node.description;
            }

            if (node.nickname && node.nickname !== node.name) {
                return node.nickname;
            }

            if (node.name) {
                if (node.name.includes("analog-stereo"))
                    return "Built-in Speakers";
                else if (node.name.includes("bluez"))
                    return "Bluetooth Audio";
                else if (node.name.includes("usb"))
                    return "USB Audio";
                else if (node.name.includes("hdmi"))
                    return "HDMI Audio";

                return node.name;
            }

            return "Unknown Audio Device";
        } catch (e) {
            console.warn("Error getting display name for node:", e);
            return "Audio Device";
        }
    }

    function subtitle(name) {
        if (!name)
            return "";

        if (name.includes('usb-')) {
            if (name.includes('SteelSeries')) {
                return "USB Gaming Headset";
            } else if (name.includes('Generic')) {
                return "USB Audio Device";
            }
            return "USB Audio";
        } else if (name.includes('pci-')) {
            if (name.includes('01_00.1') || name.includes('01:00.1')) {
                return "NVIDIA GPU Audio";
            }
            return "PCI Audio";
        } else if (name.includes('bluez')) {
            return "Bluetooth Audio";
        } else if (name.includes('analog')) {
            return "Built-in Audio";
        } else if (name.includes('hdmi')) {
            return "HDMI Audio";
        }

        return "";
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // Poll underlying pipewire nodes for external changes (hardware keys, other apps)
    Timer {
        id: pipewirePoll
        interval: 1000 // Check every second - simplified and efficient
        repeat: true
        running: true

        property int lastVolume: -1
        property bool lastSinkMuted: false
        property bool lastMicMuted: false

        onTriggered: {
            if (root.sink && root.sink.audio) {
                const nowVol = Math.round(root.sink.audio.volume * 100);
                const nowMuted = root.sink.audio.muted;
                if (nowVol !== lastVolume || nowMuted !== lastSinkMuted) {
                    lastVolume = nowVol;
                    lastSinkMuted = nowMuted;
                    root.volumeChanged();
                }
            }
            if (root.source && root.source.audio) {
                const nowMicMuted = root.source.audio.muted;
                if (nowMicMuted !== lastMicMuted) {
                    lastMicMuted = nowMicMuted;
                    root.micMuteChanged();
                }
            }
        }
    }

    // Monitor available audio devices for Bluetooth auto-switching
    // Smart Bluetooth audio monitoring - only runs when needed
    Timer {
        id: bluetoothAudioMonitor
        interval: root.hasConnectedBluetoothAudio ? root.idleMonitoringInterval : root.discoveryMonitoringInterval
        repeat: true
        running: root.autoSwitchToBluetoothAudio && root.monitoringEnabled

        property var lastAvailableBluetoothSinks: []

        onTriggered: {
            if (!Pipewire.ready || !Pipewire.nodes?.values)
                return;
            try {
                // Get all current Bluetooth audio sink nodes
                let bluetoothSinks = [];
                for (var i = 0; i < Pipewire.nodes.values.length; i++) {
                    let node = Pipewire.nodes.values[i];

                    // Skip invalid, unready, or stream nodes
                    if (!node || node.isStream || !node.ready)
                        continue;

                    // Skip nodes without basic properties
                    if (!node.name || !node.type)
                        continue;

                    // Skip nodes that might be in transitional states
                    if (node.device && !node.properties)
                        continue;

                    // Only process actual audio sink nodes
                    if ((node.type & PwNodeType.AudioSink) !== PwNodeType.AudioSink)
                        continue;

                    // Check for Bluetooth devices more safely
                    if (node.name.includes("bluez")) {
                        // Additional validation for Bluetooth nodes to avoid problematic ones
                        if (node.properties || node.description || node.nickname) {
                            bluetoothSinks.push(node);
                        }
                    }
                }

                // Update Bluetooth device presence tracking
                let previousHasDevices = root.hasConnectedBluetoothAudio;
                root.hasConnectedBluetoothAudio = bluetoothSinks.length > 0;

                // Update monitoring frequency based on device presence
                if (previousHasDevices !== root.hasConnectedBluetoothAudio) {
                    interval = root.hasConnectedBluetoothAudio ? root.idleMonitoringInterval : root.discoveryMonitoringInterval;
                }

                // Only do switching logic if we have Bluetooth devices
                if (bluetoothSinks.length > 0) {
                    // Check for newly connected Bluetooth audio devices
                    for (let newSink of bluetoothSinks) {
                        let wasAlreadyAvailable = lastAvailableBluetoothSinks.some(oldSink => oldSink && newSink && oldSink.id === newSink.id);

                        if (!wasAlreadyAvailable) {
                            // Auto-switch to newly connected Bluetooth device
                            try {
                                Pipewire.preferredDefaultAudioSink = newSink;
                                root.audioDeviceAutoSwitched(root.displayName(newSink), "Bluetooth device connected");
                            } catch (e) {
                                console.warn("Failed to switch to Bluetooth device:", e);
                            }
                            break;
                        }
                    }
                }

                lastAvailableBluetoothSinks = bluetoothSinks;

                // Reset error count on successful execution
                root.monitoringErrorCount = 0;
            } catch (e) {
                console.warn("Error in Bluetooth audio monitoring:", e);
                root.monitoringErrorCount++;

                // Disable monitoring if too many errors occur
                if (root.monitoringErrorCount >= 5) {
                    console.warn("Too many monitoring errors, disabling Bluetooth auto-switching");
                    root.monitoringEnabled = false;
                }
            }
        }
    }

    // Helper functions for auto-switching
    function isBluetoothAudioDevice(node) {
        if (!node)
            return false;

        try {
            // Check the node name first (most reliable)
            if (node.name && node.name.includes("bluez")) {
                return true;
            }

            // Check properties if available
            if (node.properties) {
                if (node.properties["device.bus"] === "bluetooth" || node.properties["device.subsystem"] === "bluetooth" || (node.properties["node.description"] && node.properties["node.description"].toLowerCase().includes("bluetooth"))) {
                    return true;
                }
            }

            // Check description/nickname as fallback
            if ((node.description && node.description.toLowerCase().includes("bluetooth")) || (node.nickname && node.nickname.toLowerCase().includes("bluetooth"))) {
                return true;
            }

            return false;
        } catch (e) {
            console.warn("Error checking if node is Bluetooth device:", e);
            return false;
        }
    }

    function enableBluetoothAutoSwitch(enabled) {
        root.autoSwitchToBluetoothAudio = enabled;
        return enabled ? "Bluetooth auto-switch enabled" : "Bluetooth auto-switch disabled";
    }

    // Volume control functions
    function setVolume(percentage) {
        if (root.sink && root.sink.audio) {
            const clampedVolume = Math.max(0, Math.min(100, percentage));
            root.sink.audio.volume = clampedVolume / 100;
            root.volumeChanged();
            return "Volume set to " + clampedVolume + "%";
        }
        return "No audio sink available";
    }

    // Volume control specifically for IPC calls (shows popup)
    function setVolumeViaIPC(percentage) {
        if (root.sink && root.sink.audio) {
            const clampedVolume = Math.max(0, Math.min(100, percentage));
            root.sink.audio.volume = clampedVolume / 100;
            root.volumeChanged();
            root.volumeChangedViaIPC();  // Trigger popup
            return "Volume set to " + clampedVolume + "%";
        }
        return "No audio sink available";
    }

    function toggleMute() {
        if (root.sink && root.sink.audio) {
            root.sink.audio.muted = !root.sink.audio.muted;
            // Emit so VolumeOSD shows on mute toggles triggered internally
            root.volumeChanged();
            return root.sink.audio.muted ? "Audio muted" : "Audio unmuted";
        }
        return "No audio sink available";
    }

    function setMicVolume(percentage) {
        if (root.source && root.source.audio) {
            const clampedVolume = Math.max(0, Math.min(100, percentage));
            root.source.audio.volume = clampedVolume / 100;
            return "Microphone volume set to " + clampedVolume + "%";
        }
        return "No audio source available";
    }

    function toggleMicMute() {
        if (root.source && root.source.audio) {
            root.source.audio.muted = !root.source.audio.muted;
            // Emit so MicMuteOSD shows on mic mute toggles triggered internally
            root.micMuteChanged();
            return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted";
        }
        return "No audio source available";
    }

    // IPC Handler for external control
    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            return root.setVolumeViaIPC(parseInt(percentage));
        }

        function increment(step: string): string {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted) {
                    root.sink.audio.muted = false;
                }
                const currentVolume = Math.round(root.sink.audio.volume * 100);
                const newVolume = Math.max(0, Math.min(100, currentVolume + parseInt(step || "5")));
                root.sink.audio.volume = newVolume / 100;
                root.volumeChanged();
                root.volumeChangedViaIPC();  // Trigger popup
                return "Volume increased to " + newVolume + "%";
            }
            return "No audio sink available";
        }

        function decrement(step: string): string {
            if (root.sink && root.sink.audio) {
                if (root.sink.audio.muted) {
                    root.sink.audio.muted = false;
                }
                const currentVolume = Math.round(root.sink.audio.volume * 100);
                const newVolume = Math.max(0, Math.min(100, currentVolume - parseInt(step || "5")));
                root.sink.audio.volume = newVolume / 100;
                root.volumeChanged();
                root.volumeChangedViaIPC();  // Trigger popup
                return "Volume decreased to " + newVolume + "%";
            }
            return "No audio sink available";
        }

        function mute(): string {
            const result = root.toggleMute();
            root.volumeChanged();
            return result;
        }

        function setmic(percentage: string): string {
            return root.setMicVolume(parseInt(percentage));
        }

        function micmute(): string {
            const result = root.toggleMicMute();
            root.micMuteChanged();
            return result;
        }

        function status(): string {
            let result = "Audio Status:\n";
            if (root.sink && root.sink.audio) {
                const volume = Math.round(root.sink.audio.volume * 100);
                result += "Output: " + volume + "%" + (root.sink.audio.muted ? " (muted)" : "") + "\n";
            } else {
                result += "Output: No sink available\n";
            }

            if (root.source && root.source.audio) {
                const micVolume = Math.round(root.source.audio.volume * 100);
                result += "Input: " + micVolume + "%" + (root.source.audio.muted ? " (muted)" : "");
            } else {
                result += "Input: No source available";
            }

            return result;
        }

        function enablebtautoswitch(enabled: string): string {
            return root.enableBluetoothAutoSwitch(enabled === "true" || enabled === "1");
        }

        function btautostatus(): string {
            let result = "Bluetooth Audio Auto-Switch Status:\n";
            result += "Auto-switch to Bluetooth: " + (root.autoSwitchToBluetoothAudio ? "Enabled" : "Disabled") + "\n";
            result += "Monitoring enabled: " + (root.monitoringEnabled ? "Yes" : "No") + "\n";
            result += "Has connected Bluetooth audio: " + (root.hasConnectedBluetoothAudio ? "Yes" : "No") + "\n";
            result += "Current monitoring interval: " + (root.hasConnectedBluetoothAudio ? root.idleMonitoringInterval : root.discoveryMonitoringInterval) + "ms\n";
            result += "Error count: " + root.monitoringErrorCount;

            return result;
        }

        function resetmonitoring(): string {
            root.monitoringEnabled = true;
            root.monitoringErrorCount = 0;
            return "Bluetooth monitoring reset and re-enabled";
        }
    }
}
