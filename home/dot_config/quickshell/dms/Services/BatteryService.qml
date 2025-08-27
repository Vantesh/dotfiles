pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool batteryAvailable: device && device.ready
                                             && device.isLaptopBattery
    readonly property real batteryLevel: batteryAvailable ? Math.round(
                                                                device.percentage * 100) : 0
    readonly property bool isCharging: batteryAvailable
                                       && device.state === UPowerDeviceState.Charging
                                       && device.changeRate > 0
    readonly property bool isPluggedIn: batteryAvailable
                                        && (device.state !== UPowerDeviceState.Discharging
                                            && device.state !== UPowerDeviceState.Empty)
    readonly property bool isLowBattery: batteryAvailable && batteryLevel <= 20
    readonly property string batteryHealth: {
        if (!batteryAvailable)
        return "N/A"

        if (device.healthSupported && device.healthPercentage > 0)
        return Math.round(device.healthPercentage) + "%"

        // Calculate health from energy capacity vs design capacity
        if (device.energyCapacity > 0 && device.energy > 0) {
            // energyCapacity is current full capacity, we need design capacity
            // Use a rough estimate based on typical battery degradation patterns
            var healthPercent = (device.energyCapacity / 90.0045)
            * 100 // your design capacity from upower
            return Math.round(healthPercent) + "%"
        }

        return "N/A"
    }
    readonly property real batteryCapacity: batteryAvailable
                                            && device.energyCapacity > 0 ? device.energyCapacity : 0
    readonly property string batteryStatus: {
        if (!batteryAvailable)
        return "No Battery"

        if (device.state === UPowerDeviceState.Charging
            && device.changeRate <= 0)
        return "Plugged In"

        return UPowerDeviceState.toString(device.state)
    }
    readonly property bool suggestPowerSaver: batteryAvailable && isLowBattery
                                              && UPower.onBattery
                                              && (typeof PowerProfiles !== "undefined"
                                                  && PowerProfiles.profile
                                                  !== PowerProfile.PowerSaver)

    readonly property var bluetoothDevices: {
        var btDevices = []
        for (var i = 0; i < UPower.devices.count; i++) {
            var dev = UPower.devices.get(i)
            if (dev
                && dev.ready && (dev.type === UPowerDeviceType.BluetoothGeneric || dev.type
                                 === UPowerDeviceType.Headphones || dev.type
                                 === UPowerDeviceType.Headset || dev.type
                                 === UPowerDeviceType.Keyboard || dev.type
                                 === UPowerDeviceType.Mouse || dev.type
                                 === UPowerDeviceType.Speakers)) {
                btDevices.push({
                                   "name": dev.model
                                           || UPowerDeviceType.toString(
                                               dev.type),
                                   "percentage": Math.round(dev.percentage),
                                   "type": dev.type
                               })
            }
        }
        return btDevices
    }

    function formatTimeRemaining() {
        if (!batteryAvailable)
            return "Unknown"

        var timeSeconds = isCharging ? device.timeToFull : device.timeToEmpty

        if (!timeSeconds || timeSeconds <= 0 || timeSeconds > 86400)
            return "Unknown"

        var hours = Math.floor(timeSeconds / 3600)
        var minutes = Math.floor((timeSeconds % 3600) / 60)

        if (hours > 0)
            return hours + "h " + minutes + "m"
        else
            return minutes + "m"
    }
}
