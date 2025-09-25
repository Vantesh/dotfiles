import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Details

Item {
    id: root

    property string expandedSection: ""
    property var expandedWidgetData: null

    Loader {
        width: parent.width
        height: 250
        y: Theme.spacingS
        active: parent.height > 0
        property string sectionKey: root.expandedSection
        sourceComponent: {
            switch (root.expandedSection) {
            case "network":
            case "wifi": return networkDetailComponent
            case "bluetooth": return bluetoothDetailComponent
            case "audioOutput": return audioOutputDetailComponent
            case "audioInput": return audioInputDetailComponent
            case "battery": return batteryDetailComponent
            default:
                if (root.expandedSection.startsWith("diskUsage_")) {
                    return diskUsageDetailComponent
                }
                return null
            }
        }
        onSectionKeyChanged: {
            active = false
            active = true
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

    Component {
        id: diskUsageDetailComponent
        DiskUsageDetail {
            currentMountPath: root.expandedWidgetData?.mountPath || "/"
            instanceId: root.expandedWidgetData?.instanceId || ""


            onMountPathChanged: (newMountPath) => {
                if (root.expandedWidgetData && root.expandedWidgetData.id === "diskUsage") {
                    const widgets = SettingsData.controlCenterWidgets || []
                    const newWidgets = widgets.map(w => {
                        if (w.id === "diskUsage" && w.instanceId === root.expandedWidgetData.instanceId) {
                            const updatedWidget = Object.assign({}, w)
                            updatedWidget.mountPath = newMountPath
                            return updatedWidget
                        }
                        return w
                    })
                    SettingsData.setControlCenterWidgets(newWidgets)
                }
            }
        }
    }
}