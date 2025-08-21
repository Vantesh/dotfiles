import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: wifiCard

    property var refreshTimer

    width: parent.width
    height: 80
    radius: Theme.cornerRadius
    color: {
        if (wifiPreferenceArea.containsMouse && NetworkService.ethernetConnected
                && NetworkService.wifiEnabled
                && NetworkService.networkStatus !== "wifi")
            return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                           Theme.surfaceContainer.b, 0.8)

        return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                       Theme.surfaceContainer.b, 0.5)
    }
    border.color: NetworkService.networkStatus === "wifi" ? Theme.primary : Qt.rgba(
                                                                Theme.outline.r,
                                                                Theme.outline.g,
                                                                Theme.outline.b,
                                                                0.12)
    border.width: NetworkService.networkStatus === "wifi" ? 2 : 1
    visible: NetworkService.wifiAvailable

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: wifiToggle.left
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        DankIcon {
            name: NetworkService.wifiSignalIcon
            size: Theme.iconSize
            color: NetworkService.networkStatus === "wifi" ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: {
                    if (!NetworkService.wifiEnabled)
                        return "WiFi is off"
                    else if (NetworkService.wifiEnabled
                             && NetworkService.currentWifiSSID)
                        return NetworkService.currentWifiSSID || "Connected"
                    else
                        return "Not Connected"
                }
                font.pixelSize: Theme.fontSizeMedium
                color: NetworkService.networkStatus === "wifi" ? Theme.primary : Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            StyledText {
                text: {
                    if (!NetworkService.wifiEnabled)
                        return "Turn on WiFi to see networks"
                    else if (NetworkService.wifiEnabled
                             && NetworkService.currentWifiSSID)
                        return NetworkService.wifiIP || "Connected"
                    else
                        return "Select a network below"
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.7)
                elide: Text.ElideRight
            }
        }
    }

    DankIcon {
        id: wifiLoadingSpinner

        name: "refresh"
        size: Theme.iconSize - 4
        color: Theme.primary
        anchors.right: wifiToggle.left
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        visible: NetworkService.changingPreference
                 && NetworkService.targetPreference === "wifi"
        z: 10

        RotationAnimation {
            target: wifiLoadingSpinner
            property: "rotation"
            running: wifiLoadingSpinner.visible
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    DankToggle {
        id: wifiToggle

        checked: NetworkService.wifiEnabled
        enabled: true
        toggling: NetworkService.wifiToggling
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
            if (NetworkService.wifiEnabled) {
                NetworkService.currentWifiSSID = ""
                NetworkService.wifiSignalStrength = 100
                NetworkService.wifiNetworks = []
                NetworkService.savedWifiNetworks = []
                NetworkService.connectionStatus = ""
                NetworkService.connectingSSID = ""
                NetworkService.isScanning = false
                NetworkService.refreshNetworkStatus()
            }
            NetworkService.toggleWifiRadio()
            if (refreshTimer)
                refreshTimer.triggered = true
        }
    }

    MouseArea {
        id: wifiPreferenceArea

        anchors.fill: parent
        anchors.rightMargin: 60 // Exclude toggle area
        hoverEnabled: true
        cursorShape: (NetworkService.ethernetConnected
                      && NetworkService.wifiEnabled
                      && NetworkService.networkStatus
                      !== "wifi") ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: NetworkService.ethernetConnected && NetworkService.wifiEnabled
                 && NetworkService.networkStatus !== "wifi"
                 && !NetworkService.changingNetworkPreference
        onClicked: {
            if (NetworkService.ethernetConnected
                    && NetworkService.wifiEnabled) {

                if (NetworkService.networkStatus !== "wifi")
                    NetworkService.setNetworkPreference("wifi")
                else
                    NetworkService.setNetworkPreference("auto")
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
