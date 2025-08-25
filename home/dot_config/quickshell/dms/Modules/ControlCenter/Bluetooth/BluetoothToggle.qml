import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    width: parent.width
    height: 60
    radius: Theme.cornerRadius
    color: bluetoothToggle.containsMouse ? Qt.rgba(
                                               Theme.primary.r, Theme.primary.g,
                                               Theme.primary.b, 0.12) : (BluetoothService.adapter
                                                                         && BluetoothService.adapter.enabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12))
    border.color: BluetoothService.adapter
                  && BluetoothService.adapter.enabled ? Theme.primary : "transparent"
    border.width: 2

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        DankIcon {
            name: "bluetooth"
            size: Theme.iconSizeLarge
            color: BluetoothService.adapter
                   && BluetoothService.adapter.enabled ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "Bluetooth"
                font.pixelSize: Theme.fontSizeLarge
                color: BluetoothService.adapter
                       && BluetoothService.adapter.enabled ? Theme.primary : Theme.surfaceText
                font.weight: Font.Medium
            }

            StyledText {
                text: BluetoothService.adapter
                      && BluetoothService.adapter.enabled ? "Enabled" : "Disabled"
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.7)
            }
        }
    }

    MouseArea {
        id: bluetoothToggle

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (BluetoothService.adapter)
                BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
        }
    }
}
