import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    isActive: {
        if (NetworkService.wifiToggling) {
            return false
        }
        if (NetworkService.networkStatus === "ethernet") {
            return true
        }
        if (NetworkService.networkStatus === "wifi") {
            return true
        }
        return NetworkService.wifiEnabled
    }

    iconName: {
        if (NetworkService.wifiToggling) {
            return "sync"
        }
        if (NetworkService.networkStatus === "ethernet") {
            return "settings_ethernet"
        }
        if (NetworkService.networkStatus === "wifi") {
            return NetworkService.wifiSignalIcon
        }
        if (NetworkService.wifiEnabled) {
            return "wifi_off"
        }
        return "wifi_off"
    }

    primaryText: {
        if (NetworkService.wifiToggling) {
            return NetworkService.wifiEnabled ? "Disabling WiFi..." : "Enabling WiFi..."
        }
        if (NetworkService.networkStatus === "ethernet") {
            return "Ethernet"
        }
        if (NetworkService.networkStatus === "wifi" && NetworkService.currentWifiSSID) {
            return NetworkService.currentWifiSSID
        }
        if (NetworkService.wifiEnabled) {
            return "Not connected"
        }
        return "WiFi off"
    }

    secondaryText: {
        if (NetworkService.wifiToggling) {
            return "Please wait..."
        }
        if (NetworkService.networkStatus === "ethernet") {
            return "Connected"
        }
        if (NetworkService.networkStatus === "wifi") {
            return NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : "Connected"
        }
        if (NetworkService.wifiEnabled) {
            return "Select network"
        }
        return ""
    }

    onToggled: {
        if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling) {
            NetworkService.toggleWifiRadio()
        }
    }
}