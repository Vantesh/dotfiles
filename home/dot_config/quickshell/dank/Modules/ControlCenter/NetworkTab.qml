import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Network

Item {
    id: networkTab

    property var wifiPasswordModalRef: {
        wifiPasswordModalLoader.active = true
        return wifiPasswordModalLoader.item
    }
    property var networkInfoModalRef: {
        networkInfoModalLoader.active = true
        return networkInfoModalLoader.item
    }

    property var sortedWifiNetworks: {
        if (!NetworkService.wifiAvailable || !NetworkService.wifiEnabled) {
            return []
        }

        var allNetworks = NetworkService.wifiNetworks
        var savedNetworks = NetworkService.savedWifiNetworks
        var currentSSID = NetworkService.currentWifiSSID
        var signalStrength = NetworkService.wifiSignalStrengthStr
        var refreshTrigger = forceRefresh

        // Force recalculation
        var networks = [...allNetworks]

        networks.forEach(function (network) {
            network.connected = (network.ssid === currentSSID)
            network.saved = savedNetworks.some(function (saved) {
                return saved.ssid === network.ssid
            })
            if (network.connected && signalStrength) {
                network.signalStrength = signalStrength
            }
        })

        networks.sort(function (a, b) {
            if (a.connected && !b.connected)
                return -1
            if (!a.connected && b.connected)
                return 1
            return b.signal - a.signal
        })

        return networks
    }

    property int forceRefresh: 0

    Connections {
        target: NetworkService
        function onNetworksUpdated() {
            forceRefresh++
        }
    }

    Component.onCompleted: {
        NetworkService.addRef()
        if (NetworkService.wifiEnabled)
            NetworkService.scanWifi()
    }

    Component.onDestruction: {
        NetworkService.removeRef()
    }

    Row {
        anchors.fill: parent
        spacing: Theme.spacingM

        Column {
            width: (parent.width - Theme.spacingM) / 2
            height: parent.height
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentWidth: width
                contentHeight: wifiContent.height
                boundsBehavior: Flickable.DragAndOvershootBounds
                // Qt 6.9+ scrolling: flickDeceleration/maximumFlickVelocity only affect touch now
                flickDeceleration: 1500
                maximumFlickVelocity: 2000

                // Custom wheel handler for Qt 6.9+ responsive mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                                 let delta = event.pixelDelta.y
                                 !== 0 ? event.pixelDelta.y * 1.8 : event.angleDelta.y / 120 * 60
                                 let newY = parent.contentY - delta
                                 newY = Math.max(
                                     0, Math.min(
                                         parent.contentHeight - parent.height,
                                         newY))
                                 parent.contentY = newY
                                 event.accepted = true
                             }
                }

                Column {
                    id: wifiContent
                    width: parent.width
                    spacing: Theme.spacingM

                    WiFiCard {}
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }

        Column {
            width: (parent.width - Theme.spacingM) / 2
            height: parent.height
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentWidth: width
                contentHeight: ethernetContent.height
                boundsBehavior: Flickable.StopAtBounds
                // Qt 6.9+ scrolling: flickDeceleration/maximumFlickVelocity only affect touch now
                flickDeceleration: 1500
                maximumFlickVelocity: 2000

                // Custom wheel handler for Qt 6.9+ responsive mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                                 let delta = event.pixelDelta.y
                                 !== 0 ? event.pixelDelta.y * 1.8 : event.angleDelta.y / 120 * 60
                                 let newY = parent.contentY - delta
                                 newY = Math.max(
                                     0, Math.min(
                                         parent.contentHeight - parent.height,
                                         newY))
                                 parent.contentY = newY
                                 event.accepted = true
                             }
                }

                Column {
                    id: ethernetContent
                    width: parent.width
                    spacing: Theme.spacingM

                    EthernetCard {}
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"
        visible: !NetworkService.wifiEnabled

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "wifi_off"
                size: 48
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.3)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "WiFi is turned off"
                font.pixelSize: Theme.fontSizeLarge
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.6)
                font.weight: Font.Medium
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn on WiFi to see networks"
                font.pixelSize: Theme.fontSizeMedium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.4)
            }
        }
    }

    WiFiNetworksList {
        wifiContextMenuWindow: wifiContextMenuWindow
        sortedWifiNetworks: networkTab.sortedWifiNetworks
        wifiPasswordModalRef: networkTab.wifiPasswordModalRef
    }

    Connections {
        target: NetworkService
        function onWifiEnabledChanged() {
            if (NetworkService.wifiEnabled && visible) {
                // Trigger a scan when WiFi is enabled
                NetworkService.scanWifi()
            }
        }
    }

    onVisibleChanged: {
        if (visible && NetworkService.wifiEnabled
                && NetworkService.wifiNetworks.length === 0) {
            // Scan when tab becomes visible if we don't have networks cached
            NetworkService.scanWifi()
        }
    }

    WiFiContextMenu {
        id: wifiContextMenuWindow
        parentItem: networkTab
        wifiPasswordModalRef: networkTab.wifiPasswordModalRef
        networkInfoModalRef: networkTab.networkInfoModalRef
    }

    MouseArea {
        anchors.fill: parent
        visible: wifiContextMenuWindow.visible
        onClicked: {
            wifiContextMenuWindow.hide()
        }

        MouseArea {
            x: wifiContextMenuWindow.x
            y: wifiContextMenuWindow.y
            width: wifiContextMenuWindow.width
            height: wifiContextMenuWindow.height
            onClicked: {

            }
        }
    }
}
