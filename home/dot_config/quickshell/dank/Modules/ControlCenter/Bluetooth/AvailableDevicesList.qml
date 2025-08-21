import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    width: parent.width
    spacing: Theme.spacingM
    visible: BluetoothService.adapter && BluetoothService.adapter.enabled

    Row {
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: "Available Devices"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - scanButton.width - parent.spacing
                   - 150 // Spacer to push button right
            height: 1
        }

        Rectangle {
            id: scanButton

            width: Math.max(100, scanText.contentWidth + Theme.spacingL * 2)
            height: 32
            radius: Theme.cornerRadius
            color: scanArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                    Theme.primary.g,
                                                    Theme.primary.b,
                                                    0.12) : Qt.rgba(
                                                Theme.primary.r,
                                                Theme.primary.g,
                                                Theme.primary.b, 0.08)
            border.color: Theme.primary
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: BluetoothService.adapter
                          && BluetoothService.adapter.discovering ? "stop" : "bluetooth_searching"
                    size: Theme.iconSize - 6
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: scanText

                    text: BluetoothService.adapter
                          && BluetoothService.adapter.discovering ? "Stop Scanning" : "Scan"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: scanArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (BluetoothService.adapter)
                        BluetoothService.adapter.discovering = !BluetoothService.adapter.discovering
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: noteColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08)
        border.color: Qt.rgba(Theme.warning.r, Theme.warning.g,
                              Theme.warning.b, 0.2)
        border.width: 1

        Column {
            id: noteColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankIcon {
                    name: "info"
                    size: Theme.iconSize - 2
                    color: Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Pairing Limitation"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.warning
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "Quickshell does not support pairing devices that require pin or confirmation."
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.8)
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }
    }

    Repeater {
        model: {
            if (!BluetoothService.adapter
                    || !BluetoothService.adapter.discovering
                    || !Bluetooth.devices)
                return []

            var filtered = Bluetooth.devices.values.filter(dev => {
                                                               return dev
                                                               && !dev.paired
                                                               && !dev.pairing
                                                               && !dev.blocked
                                                               && (dev.signalStrength === undefined
                                                                   || dev.signalStrength > 0)
                                                           })
            return BluetoothService.sortDevices(filtered)
        }

        Rectangle {
            property bool canConnect: BluetoothService.canConnect(modelData)
            property bool isBusy: BluetoothService.isDeviceBusy(modelData)

            width: parent.width
            height: 70
            radius: Theme.cornerRadius
            color: {
                if (availableDeviceArea.containsMouse && !isBusy)
                    return Qt.rgba(Theme.primary.r, Theme.primary.g,
                                   Theme.primary.b, 0.08)

                if (modelData.pairing
                        || modelData.state === BluetoothDeviceState.Connecting)
                    return Qt.rgba(Theme.warning.r, Theme.warning.g,
                                   Theme.warning.b, 0.12)

                if (modelData.blocked)
                    return Qt.rgba(Theme.error.r, Theme.error.g,
                                   Theme.error.b, 0.08)

                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.08)
            }
            border.color: {
                if (modelData.pairing)
                    return Theme.warning

                if (modelData.blocked)
                    return Theme.error

                return Qt.rgba(Theme.outline.r, Theme.outline.g,
                               Theme.outline.b, 0.2)
            }
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: BluetoothService.getDeviceIcon(modelData)
                    size: Theme.iconSize
                    color: {
                        if (modelData.pairing)
                            return Theme.warning

                        if (modelData.blocked)
                            return Theme.error

                        return Theme.surfaceText
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: modelData.name || modelData.deviceName
                        font.pixelSize: Theme.fontSizeMedium
                        color: {
                            if (modelData.pairing)
                                return Theme.warning

                            if (modelData.blocked)
                                return Theme.error

                            return Theme.surfaceText
                        }
                        font.weight: modelData.pairing ? Font.Medium : Font.Normal
                    }

                    Row {
                        spacing: Theme.spacingXS

                        Row {
                            spacing: Theme.spacingS

                            StyledText {
                                text: {
                                    if (modelData.pairing)
                                        return "Pairing..."

                                    if (modelData.blocked)
                                        return "Blocked"

                                    return BluetoothService.getSignalStrength(
                                                modelData)
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: {
                                    if (modelData.pairing)
                                        return Theme.warning

                                    if (modelData.blocked)
                                        return Theme.error

                                    return Qt.rgba(Theme.surfaceText.r,
                                                   Theme.surfaceText.g,
                                                   Theme.surfaceText.b, 0.7)
                                }
                            }

                            DankIcon {
                                name: BluetoothService.getSignalIcon(modelData)
                                size: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r,
                                               Theme.surfaceText.g,
                                               Theme.surfaceText.b, 0.7)
                                visible: modelData.signalStrength !== undefined
                                         && modelData.signalStrength > 0
                                         && !modelData.pairing
                                         && !modelData.blocked
                            }

                            StyledText {
                                text: (modelData.signalStrength !== undefined
                                       && modelData.signalStrength
                                       > 0) ? modelData.signalStrength + "%" : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r,
                                               Theme.surfaceText.g,
                                               Theme.surfaceText.b, 0.5)
                                visible: modelData.signalStrength !== undefined
                                         && modelData.signalStrength > 0
                                         && !modelData.pairing
                                         && !modelData.blocked
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 80
                height: 28
                radius: Theme.cornerRadius
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.state !== BluetoothDeviceState.Connecting
                color: {
                    if (!canConnect && !isBusy)
                        return Qt.rgba(Theme.surfaceVariant.r,
                                       Theme.surfaceVariant.g,
                                       Theme.surfaceVariant.b, 0.3)

                    if (actionButtonArea.containsMouse && !isBusy)
                        return Qt.rgba(Theme.primary.r, Theme.primary.g,
                                       Theme.primary.b, 0.12)

                    return "transparent"
                }
                border.color: canConnect || isBusy ? Theme.primary : Qt.rgba(
                                                         Theme.outline.r,
                                                         Theme.outline.g,
                                                         Theme.outline.b, 0.2)
                border.width: 1
                opacity: canConnect || isBusy ? 1 : 0.5

                StyledText {
                    anchors.centerIn: parent
                    text: {
                        if (modelData.pairing)
                            return "Pairing..."

                        if (modelData.blocked)
                            return "Blocked"

                        return "Connect"
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: canConnect || isBusy ? Theme.primary : Qt.rgba(
                                                      Theme.surfaceText.r,
                                                      Theme.surfaceText.g,
                                                      Theme.surfaceText.b, 0.5)
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: actionButtonArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: canConnect
                                 && !isBusy ? Qt.PointingHandCursor : (isBusy ? Qt.BusyCursor : Qt.ArrowCursor)
                    enabled: canConnect && !isBusy
                    onClicked: {
                        if (modelData)
                            BluetoothService.connectDeviceWithTrust(modelData)
                    }
                }
            }

            MouseArea {
                id: availableDeviceArea

                anchors.fill: parent
                anchors.rightMargin: 90
                hoverEnabled: true
                cursorShape: canConnect
                             && !isBusy ? Qt.PointingHandCursor : (isBusy ? Qt.BusyCursor : Qt.ArrowCursor)
                enabled: canConnect && !isBusy
                onClicked: {
                    if (modelData)
                        BluetoothService.connectDeviceWithTrust(modelData)
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: {
            if (!BluetoothService.adapter
                    || !BluetoothService.adapter.discovering
                    || !Bluetooth.devices)
                return false

            var availableCount = Bluetooth.devices.values.filter(dev => {
                                                                     return dev
                                                                     && !dev.paired
                                                                     && !dev.pairing
                                                                     && !dev.blocked
                                                                     && (dev.signalStrength
                                                                         === undefined
                                                                         || dev.signalStrength > 0)
                                                                 }).length
            return availableCount === 0
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingM

            DankIcon {
                name: "sync"
                size: Theme.iconSizeLarge
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                RotationAnimation on rotation {
                    running: true
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 2000
                }
            }

            StyledText {
                text: "Scanning for devices..."
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            text: "Make sure your device is in pairing mode"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                           Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    StyledText {
        text: "No devices found. Put your device in pairing mode and click Start Scanning."
        font.pixelSize: Theme.fontSizeMedium
        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                       Theme.surfaceText.b, 0.7)
        visible: {
            if (!BluetoothService.adapter || !Bluetooth.devices)
                return true

            var availableCount = Bluetooth.devices.values.filter(dev => {
                                                                     return dev
                                                                     && !dev.paired
                                                                     && !dev.pairing
                                                                     && !dev.blocked
                                                                     && (dev.signalStrength
                                                                         === undefined
                                                                         || dev.signalStrength > 0)
                                                                 }).length
            return availableCount === 0 && !BluetoothService.adapter.discovering
        }
        wrapMode: Text.WordWrap
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }
}
