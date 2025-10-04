import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: pluginsTab

    property string expandedPluginId: ""


    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: headerColumn.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: headerColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "extension"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Plugin Management"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: "Manage and configure plugins for extending DMS functionality"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankButton {
                            text: "Scan for Plugins"
                            iconName: "refresh"
                            onClicked: {
                                PluginService.scanPlugins()
                                ToastService.showInfo("Scanning for plugins...")
                            }
                        }

                        DankButton {
                            text: "Create Plugin Directory"
                            iconName: "create_new_folder"
                            onClicked: {
                                PluginService.createPluginDirectory()
                                ToastService.showInfo("Created plugin directory: " + PluginService.pluginDirectory)
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: directoryColumn.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: directoryColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Plugin Directory"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: PluginService.pluginDirectory
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.family: "monospace"
                    }

                    StyledText {
                        text: "Place plugin directories here. Each plugin should have a plugin.json manifest file."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: Math.max(200, availableColumn.implicitHeight + Theme.spacingL * 2)
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                Column {
                    id: availableColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Available Plugins"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            id: pluginRepeater
                            model: PluginService.getAvailablePlugins()

                            StyledRect {
                                id: pluginDelegate
                                width: parent.width
                                height: pluginItemColumn.implicitHeight + Theme.spacingM * 2 + settingsContainer.height
                                radius: Theme.cornerRadius

                                property var pluginData: modelData
                                property string pluginId: pluginData ? pluginData.id : ""
                                property string pluginName: pluginData ? (pluginData.name || pluginData.id) : ""
                                property string pluginVersion: pluginData ? (pluginData.version || "1.0.0") : ""
                                property string pluginAuthor: pluginData ? (pluginData.author || "Unknown") : ""
                                property string pluginDescription: pluginData ? (pluginData.description || "") : ""
                                property string pluginIcon: pluginData ? (pluginData.icon || "extension") : "extension"
                                property string pluginSettingsPath: pluginData ? (pluginData.settingsPath || "") : ""
                                property var pluginPermissions: pluginData ? (pluginData.permissions || []) : []
                                property bool hasSettings: pluginData && pluginData.settings !== undefined && pluginData.settings !== ""
                                property bool isExpanded: pluginsTab.expandedPluginId === pluginId


                                color: pluginMouseArea.containsMouse ? Theme.surfacePressed : (isExpanded ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: 0

                                MouseArea {
                                    id: pluginMouseArea
                                    anchors.fill: parent
                                    anchors.bottomMargin: pluginDelegate.isExpanded ? settingsContainer.height : 0
                                    hoverEnabled: true
                                    cursorShape: pluginDelegate.hasSettings ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (pluginDelegate.hasSettings) {
                                            pluginsTab.expandedPluginId = pluginsTab.expandedPluginId === pluginDelegate.pluginId ? "" : pluginDelegate.pluginId
                                        }
                                    }
                                }

                                Column {
                                    id: pluginItemColumn
                                    width: parent.width
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        DankIcon {
                                            name: pluginDelegate.pluginIcon
                                            size: Theme.iconSize
                                            color: PluginService.isPluginLoaded(pluginDelegate.pluginId) ? Theme.primary : Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            width: parent.width - Theme.iconSize - Theme.spacingM - toggleRow.width - Theme.spacingM
                                            spacing: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter

                                            Row {
                                                spacing: Theme.spacingXS
                                                width: parent.width

                                                StyledText {
                                                    text: pluginDelegate.pluginName
                                                    font.pixelSize: Theme.fontSizeLarge
                                                    color: Theme.surfaceText
                                                    font.weight: Font.Medium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                DankIcon {
                                                    name: pluginDelegate.hasSettings ? (pluginDelegate.isExpanded ? "expand_less" : "expand_more") : ""
                                                    size: 16
                                                    color: pluginDelegate.hasSettings ? Theme.primary : "transparent"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: pluginDelegate.hasSettings
                                                }
                                            }

                                            StyledText {
                                                text: "v" + pluginDelegate.pluginVersion + " by " + pluginDelegate.pluginAuthor
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                width: parent.width
                                            }
                                        }

                                        Row {
                                            id: toggleRow
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingXS

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 14
                                                color: reloadArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                                visible: PluginService.isPluginLoaded(pluginDelegate.pluginId)

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "refresh"
                                                    size: 16
                                                    color: reloadArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                                }

                                                MouseArea {
                                                    id: reloadArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const currentPluginId = pluginDelegate.pluginId
                                                        const currentPluginName = pluginDelegate.pluginName
                                                        pluginsTab.isReloading = true
                                                        if (PluginService.reloadPlugin(currentPluginId)) {
                                                            ToastService.showInfo("Plugin reloaded: " + currentPluginName)
                                                        } else {
                                                            ToastService.showError("Failed to reload plugin: " + currentPluginName)
                                                            pluginsTab.isReloading = false
                                                        }
                                                    }
                                                }
                                            }

                                            DankToggle {
                                                id: pluginToggle
                                                anchors.verticalCenter: parent.verticalCenter
                                                checked: PluginService.isPluginLoaded(pluginDelegate.pluginId)
                                                onToggled: isChecked => {
                                                    const currentPluginId = pluginDelegate.pluginId
                                                    const currentPluginName = pluginDelegate.pluginName

                                                    if (isChecked) {
                                                        if (PluginService.enablePlugin(currentPluginId)) {
                                                            ToastService.showInfo("Plugin enabled: " + currentPluginName)
                                                        } else {
                                                            ToastService.showError("Failed to enable plugin: " + currentPluginName)
                                                            checked = false
                                                        }
                                                    } else {
                                                        if (PluginService.disablePlugin(currentPluginId)) {
                                                            ToastService.showInfo("Plugin disabled: " + currentPluginName)
                                                            if (pluginDelegate.isExpanded) {
                                                                pluginsTab.expandedPluginId = ""
                                                            }
                                                        } else {
                                                            ToastService.showError("Failed to disable plugin: " + currentPluginName)
                                                            checked = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: pluginDelegate.pluginDescription
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        visible: pluginDelegate.pluginDescription !== ""
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: pluginDelegate.pluginPermissions && Array.isArray(pluginDelegate.pluginPermissions) && pluginDelegate.pluginPermissions.length > 0

                                        Repeater {
                                            model: pluginDelegate.pluginPermissions

                                            Rectangle {
                                                height: 20
                                                width: permissionText.implicitWidth + Theme.spacingXS * 2
                                                radius: 10
                                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                                border.width: 1

                                                StyledText {
                                                    id: permissionText
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                    color: Theme.primary
                                                }
                                            }
                                        }
                                    }
                                }

                                // Settings container
                                Item {
                                    id: settingsContainer
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: pluginDelegate.isExpanded && pluginDelegate.hasSettings ? (settingsLoader.item ? settingsLoader.item.implicitHeight + Theme.spacingL * 2 : 0) : 0
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.surfaceContainerHighest
                                        radius: Theme.cornerRadius
                                        anchors.topMargin: Theme.spacingXS
                                        border.width: 0
                                    }

                                    Loader {
                                        id: settingsLoader
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingL
                                        active: pluginDelegate.isExpanded && pluginDelegate.hasSettings && PluginService.isPluginLoaded(pluginDelegate.pluginId)
                                        asynchronous: false

                                        source: {
                                            if (active && pluginDelegate.pluginSettingsPath) {
                                                var path = pluginDelegate.pluginSettingsPath
                                                if (!path.startsWith("file://")) {
                                                    path = "file://" + path
                                                }
                                                return path
                                            }
                                            return ""
                                        }

                                        onLoaded: {
                                            if (item && typeof PluginService !== "undefined") {
                                                item.pluginService = PluginService
                                            }
                                            if (item && typeof PopoutService !== "undefined") {
                                                item.popoutService = PopoutService
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: !PluginService.isPluginLoaded(pluginDelegate.pluginId) ?
                                              "Enable plugin to access settings" :
                                              (settingsLoader.status === Loader.Error ?
                                               "Failed to load settings" :
                                               "No configurable settings")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        visible: pluginDelegate.isExpanded && (!settingsLoader.active || settingsLoader.status === Loader.Error)
                                    }
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: "No plugins found.\nPlace plugins in " + PluginService.pluginDirectory
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            visible: pluginRepeater.model.length === 0
                        }
                    }
                }
            }
        }
    }

    property bool isReloading: false

    Connections {
        target: PluginService
        function onPluginLoaded() {
            pluginRepeater.model = PluginService.getAvailablePlugins()
            if (isReloading) {
                isReloading = false
            }
        }
        function onPluginUnloaded() {
            pluginRepeater.model = PluginService.getAvailablePlugins()
            if (!isReloading && pluginsTab.expandedPluginId !== "" && !PluginService.isPluginLoaded(pluginsTab.expandedPluginId)) {
                pluginsTab.expandedPluginId = ""
            }
        }
    }
}