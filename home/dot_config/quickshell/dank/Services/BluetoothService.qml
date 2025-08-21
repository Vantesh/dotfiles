pragma Singleton
pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: (adapter && adapter.enabled) ?? false
    readonly property bool discovering: (adapter && adapter.discovering) ?? false
    readonly property var devices: adapter ? adapter.devices : null
    readonly property var pairedDevices: {
        if (!adapter || !adapter.devices)
            return [];

        return adapter.devices.values.filter(dev => {
            return dev && (dev.paired || dev.trusted);
        });
    }
    readonly property var allDevicesWithBattery: {
        if (!adapter || !adapter.devices)
            return [];

        return adapter.devices.values.filter(dev => {
            return dev && dev.batteryAvailable && dev.battery > 0;
        });
    }

    function sortDevices(devices) {
        return devices.sort((a, b) => {
            var aName = a.name || a.deviceName || "";
            var bName = b.name || b.deviceName || "";

            var aHasRealName = aName.includes(" ") && aName.length > 3;
            var bHasRealName = bName.includes(" ") && bName.length > 3;

            if (aHasRealName && !bHasRealName)
                return -1;
            if (!aHasRealName && bHasRealName)
                return 1;

            var aSignal = (a.signalStrength !== undefined && a.signalStrength > 0) ? a.signalStrength : 0;
            var bSignal = (b.signalStrength !== undefined && b.signalStrength > 0) ? b.signalStrength : 0;
            return bSignal - aSignal;
        });
    }

    function getDeviceIcon(device) {
        if (!device)
            return "bluetooth";

        var name = (device.name || device.deviceName || "").toLowerCase();
        var icon = (device.icon || "").toLowerCase();
        if (icon.includes("headset") || icon.includes("audio") || name.includes("headphone") || name.includes("airpod") || name.includes("headset") || name.includes("arctis"))
            return "headset";

        if (icon.includes("mouse") || name.includes("mouse"))
            return "mouse";

        if (icon.includes("keyboard") || name.includes("keyboard"))
            return "keyboard";

        if (icon.includes("phone") || name.includes("phone") || name.includes("iphone") || name.includes("android") || name.includes("samsung"))
            return "smartphone";

        if (icon.includes("watch") || name.includes("watch"))
            return "watch";

        if (icon.includes("speaker") || name.includes("speaker"))
            return "speaker";

        if (icon.includes("display") || name.includes("tv"))
            return "tv";

        return "bluetooth";
    }

    function canConnect(device) {
        if (!device)
            return false;

        return !device.paired && !device.pairing && !device.blocked;
    }

    function getSignalStrength(device) {
        if (!device || device.signalStrength === undefined || device.signalStrength <= 0)
            return "Unknown";

        var signal = device.signalStrength;
        if (signal >= 80)
            return "Excellent";

        if (signal >= 60)
            return "Good";

        if (signal >= 40)
            return "Fair";

        if (signal >= 20)
            return "Poor";

        return "Very Poor";
    }

    function getSignalIcon(device) {
        if (!device || device.signalStrength === undefined || device.signalStrength <= 0)
            return "signal_cellular_null";

        var signal = device.signalStrength;
        if (signal >= 80)
            return "signal_cellular_4_bar";

        if (signal >= 60)
            return "signal_cellular_3_bar";

        if (signal >= 40)
            return "signal_cellular_2_bar";

        if (signal >= 20)
            return "signal_cellular_1_bar";

        return "signal_cellular_0_bar";
    }

    function isDeviceBusy(device) {
        if (!device)
            return false;
        return device.pairing || device.state === BluetoothDeviceState.Disconnecting || device.state === BluetoothDeviceState.Connecting;
    }

    function connectDeviceWithTrust(device) {
        if (!device)
            return;
        device.trusted = true;
        device.connect();
    }

    function toggleAudioQuality(device) {
        if (!device || !device.connected) {
            console.warn("BluetoothService: No device provided or device not connected");
            return false;
        }

        var cardName = "bluez_card." + device.address.replace(/:/g, "_");

        // Create a process to check current profile and switch
        var command = ["sh", "-c", `current_profile=$(pactl list cards | grep -A25 '${cardName}' | grep 'Active Profile:' | awk '{print $3}'); ` + `if echo "$current_profile" | grep -q 'ldac\\|aptx'; then ` + `pactl set-card-profile ${cardName} a2dp-sink-aac; echo 'Switched to Balanced Quality (AAC)'; ` + `else ` + `pactl set-card-profile ${cardName} a2dp-sink || pactl set-card-profile ${cardName} a2dp-sink-aptx_hd || pactl set-card-profile ${cardName} a2dp-sink-aptx; echo 'Switched to High Quality (LDAC/aptX)'; ` + `fi`];

        // Note: In a real implementation, you'd use a Process object here
        // For now, this provides the logic structure
        console.log("BluetoothService: Toggling audio quality for", device.name);
        return true;
    }

    function getCurrentAudioCodec(device) {
        if (!device || !device.connected)
            return "Unknown";

        // This would need to query pactl in a real implementation
        // For now, return a placeholder
        return "AAC"; // Default assumption
    }

    // IPC function to test codec detection
    function listAudioCodecs(deviceAddress) {
        console.log("BluetoothService: Listing codecs for device", deviceAddress);

        // In a real implementation, this would use a Process to query pactl
        // For now, return mock data based on the known device
        if (deviceAddress === "48:73:CB:B8:57:BD") {
            return "Available codecs: LDAC (highest), AAC (balanced), SBC-XQ (enhanced), SBC (basic)";
        }

        return "No codec information available";
    }
}
