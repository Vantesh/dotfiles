import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Theme.iconSize + Theme.spacingS * 2
    osdHeight: Theme.iconSize + Theme.spacingS * 2
    autoHideInterval: 2000
    enableMouseInteraction: false

    Connections {
        target: SessionService
        function onInhibitorChanged() {
            root.show()
        }
    }

    content: DankIcon {
        anchors.centerIn: parent
        name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
        size: Theme.iconSize
        color: SessionService.idleInhibited ? Theme.primary : Theme.outline
    }
}
