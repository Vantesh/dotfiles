import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modules.ControlCenter.Bluetooth
import qs.Services
import qs.Widgets

Item {
    id: bluetoothTab

    property alias bluetoothContextMenuWindow: bluetoothContextMenuWindow
    property alias simpleCodecSelectionModal: simpleCodecSelectionModal

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingL

            Loader {
                width: parent.width
                sourceComponent: toggleComponent
            }

            Loader {
                width: parent.width
                sourceComponent: pairedComponent
            }

            Loader {
                width: parent.width
                sourceComponent: availableComponent
            }
        }
    }

    BluetoothContextMenu {
        id: bluetoothContextMenuWindow
        parentItem: bluetoothTab
    }

    SimpleCodecSelectionModal {
        id: simpleCodecSelectionModal
        parentItem: bluetoothTab
    }

    MouseArea {
        anchors.fill: parent
        visible: bluetoothContextMenuWindow.visible
        onClicked: {
            bluetoothContextMenuWindow.hide();
        }

        MouseArea {
            x: bluetoothContextMenuWindow.x
            y: bluetoothContextMenuWindow.y
            width: bluetoothContextMenuWindow.width
            height: bluetoothContextMenuWindow.height
            onClicked: {}
        }
    }

    Component {
        id: toggleComponent
        BluetoothToggle {
            width: parent.width
        }
    }

    Component {
        id: pairedComponent
        PairedDevicesList {
            width: parent.width
        }
    }

    Component {
        id: availableComponent
        AvailableDevicesList {
            width: parent.width
        }
    }
}
