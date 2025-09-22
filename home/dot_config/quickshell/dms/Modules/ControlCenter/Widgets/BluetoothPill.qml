import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property var primaryDevice: {
        if (!BluetoothService.adapter || !BluetoothService.adapter.devices) {
            return null
        }

        let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
        for (let device of devices) {
            if (device && device.connected) {
                return device
            }
        }
        return null
    }

    iconName: {
        if (!BluetoothService.available) {
            return "bluetooth_disabled"
        }
        if (!BluetoothService.adapter || !BluetoothService.adapter.enabled) {
            return "bluetooth_disabled"
        }
        if (primaryDevice) {
            return BluetoothService.getDeviceIcon(primaryDevice)
        }
        return "bluetooth"
    }

    isActive: !!(BluetoothService.available && BluetoothService.adapter && BluetoothService.adapter.enabled)
    showExpandArea: BluetoothService.available

    primaryText: {
        if (!BluetoothService.available) {
            return "Bluetooth"
        }
        if (!BluetoothService.adapter) {
            return "No adapter"
        }
        if (!BluetoothService.adapter.enabled) {
            return "Disabled"
        }
        return "Enabled"
    }

    secondaryText: {
        if (!BluetoothService.available) {
            return "No adapters"
        }
        if (!BluetoothService.adapter || !BluetoothService.adapter.enabled) {
            return "Off"
        }
        if (primaryDevice) {
            return primaryDevice.name || primaryDevice.alias || primaryDevice.deviceName || "Connected Device"
        }
        return "No devices"
    }

    onToggled: {
        if (BluetoothService.available && BluetoothService.adapter) {
            BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
        }
    }
}