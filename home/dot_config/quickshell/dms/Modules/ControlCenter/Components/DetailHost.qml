import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Details

Item {
    id: root

    property string expandedSection: ""

    Loader {
        width: parent.width
        height: 250
        y: Theme.spacingS
        active: parent.height > 0
        sourceComponent: {
            switch (root.expandedSection) {
            case "network":
            case "wifi": return networkDetailComponent
            case "bluetooth": return bluetoothDetailComponent
            case "audioOutput": return audioOutputDetailComponent
            case "audioInput": return audioInputDetailComponent
            case "battery": return batteryDetailComponent
            default: return null
            }
        }
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {}
    }

    Component {
        id: audioOutputDetailComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputDetailComponent
        AudioInputDetail {}
    }

    Component {
        id: batteryDetailComponent
        BatteryDetail {}
    }
}