import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modules.ProcessList
import qs.Services

ColumnLayout {
    id: processesTab

    property var contextMenu: null

    anchors.fill: parent
    spacing: Theme.spacingM

    SystemOverview {
        Layout.fillWidth: true
    }

    ProcessListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contextMenu: processesTab.contextMenu
    }

    ProcessContextMenu {
        id: localContextMenu
    }
}
