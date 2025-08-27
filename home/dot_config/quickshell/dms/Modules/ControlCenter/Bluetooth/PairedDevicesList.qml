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

    function findBluetoothContextMenu() {
        var p = parent
        while (p) {
            if (p.bluetoothContextMenuWindow)
                return p.bluetoothContextMenuWindow
            p = p.parent
        }
        return null
    }

    width: parent.width
    spacing: Theme.spacingM
    visible: BluetoothService.adapter && BluetoothService.adapter.enabled

    StyledText {
        text: "Paired Devices"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
    }

    Repeater {
        model: BluetoothService.adapter
               && BluetoothService.adapter.devices ? BluetoothService.adapter.devices.values.filter(
                                                         dev => {
                                                             return dev
                                                             && (dev.paired
                                                                 || dev.trusted)
                                                         }) : []

        Rectangle {
            width: parent.width
            height: 60
            radius: Theme.cornerRadius
            color: btDeviceArea.containsMouse ? Qt.rgba(
                                                    Theme.primary.r,
                                                    Theme.primary.g,
                                                    Theme.primary.b,
                                                    0.08) : (modelData.connected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
            border.color: modelData.connected ? Theme.primary : "transparent"
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: BluetoothService.getDeviceIcon(modelData)
                    size: Theme.iconSize
                    color: modelData.connected ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: modelData.name || modelData.deviceName
                        font.pixelSize: Theme.fontSizeMedium
                        color: modelData.connected ? Theme.primary : Theme.surfaceText
                        font.weight: modelData.connected ? Font.Medium : Font.Normal
                    }

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: BluetoothDeviceState.toString(modelData.state)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                        }

                        StyledText {
                            id: btBatteryText
                            text: {
                                if (modelData.batteryAvailable
                                        && modelData.battery > 0)
                                    return "• " + Math.round(
                                                modelData.battery * 100) + "%"

                                var btBattery = BatteryService.bluetoothDevices.find(
                                            dev => {
                                                return dev.name === (modelData.name
                                                                     || modelData.deviceName)
                                                || dev.name.toLowerCase(
                                                    ).includes(
                                                    (modelData.name
                                                     || modelData.deviceName).toLowerCase(
                                                        ))
                                                || (modelData.name
                                                    || modelData.deviceName).toLowerCase(
                                                    ).includes(
                                                    dev.name.toLowerCase())
                                            })
                                return btBattery ? "• " + btBattery.percentage + "%" : ""
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                            visible: text.length > 0
                        }

                        StyledText {
                            id: codecText
                            text: {
                                return (codecSelector.currentCodec && codecSelector.currentCodec.length > 0) ? ("• " + codecSelector.currentCodec) : ""
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r,
                                           Theme.surfaceText.g,
                                           Theme.surfaceText.b, 0.7)
                            visible: text.length > 0 && modelData.connected
                        }

                        // hidden per-device selector that queries codecs for this device
                        BluetoothCodecSelector {
                            id: codecSelector
                            device: modelData
                            visible: false

                            Component.onCompleted: {
                                if (modelData.connected)
                                    queryCodecs();
                            }

                            Connections {
                                target: modelData
                                function onConnectedChanged() {
                                    if (modelData.connected)
                                        codecSelector.queryCodecs();
                                    else
                                        codecSelector.currentCodec = "";
                                }
                            }
                        }

                    }
                }
            }

            Rectangle {
                id: btMenuButton

                width: 32
                height: 32
                radius: Theme.cornerRadius
                color: btMenuButtonArea.containsMouse ? Qt.rgba(
                                                            Theme.surfaceText.r,
                                                            Theme.surfaceText.g,
                                                            Theme.surfaceText.b,
                                                            0.08) : "transparent"
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "more_vert"
                    size: Theme.iconSize
                    color: Theme.surfaceText
                    opacity: 0.6
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: btMenuButtonArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var contextMenu = root.findBluetoothContextMenu()
                        if (contextMenu) {
                            contextMenu.deviceData = modelData
                            let localPos = btMenuButtonArea.mapToItem(
                                    contextMenu.parentItem,
                                    btMenuButtonArea.width / 2,
                                    btMenuButtonArea.height)
                            contextMenu.show(localPos.x, localPos.y)
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }

            MouseArea {
                id: btDeviceArea

                anchors.fill: parent
                anchors.rightMargin: 40
                hoverEnabled: true
                enabled: !BluetoothService.isDeviceBusy(modelData)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.BusyCursor
                onClicked: {
                    if (modelData.connected)
                        modelData.disconnect()
                    else
                        BluetoothService.connectDeviceWithTrust(modelData)
                }
            }
        }
    }
}
