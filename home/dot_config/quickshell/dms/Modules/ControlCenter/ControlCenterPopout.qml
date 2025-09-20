import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Details
import qs.Modules.ControlCenter.Details 1.0 as Details
import qs.Modules.TopBar
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    property string expandedSection: ""
    property bool powerOptionsExpanded: false
    property string triggerSection: "right"
    property var triggerScreen: null

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    function openWithSection(section) {
        if (shouldBeVisible) {
            close()
        } else {
            expandedSection = section
            open()
        }
    }

    function toggleSection(section) {
        if (expandedSection === section) {
            expandedSection = ""
        } else {
            expandedSection = section
        }
    }

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    popupWidth: 550
    popupHeight: Math.min((triggerScreen?.height ?? 1080) - 100, contentLoader.item && contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight + 20 : 400)
    triggerX: (triggerScreen?.width ?? 1920) - 600 - Theme.spacingL
    triggerY: Theme.barHeight - 4 + SettingsData.topBarSpacing + Theme.spacingXS
    triggerWidth: 80
    positioning: "center"
    screen: triggerScreen
    shouldBeVisible: false
    visible: shouldBeVisible

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            Qt.callLater(() => {
                NetworkService.autoRefreshEnabled = NetworkService.wifiEnabled
                if (UserInfoService)
                    UserInfoService.getUptime()
            })
        } else {
            Qt.callLater(() => {
                NetworkService.autoRefreshEnabled = false
                if (BluetoothService.adapter
                        && BluetoothService.adapter.discovering)
                    BluetoothService.adapter.discovering = false
            })
        }
    }

    content: Component {
        Rectangle {
            id: controlContent
            
            implicitHeight: mainColumn.implicitHeight + Theme.spacingM
            property alias bluetoothCodecSelector: bluetoothCodecSelector
            
            color: {
                const transparency = Theme.popupTransparency || 0.92
                const surface = Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1)
                return Qt.rgba(surface.r, surface.g, surface.b, transparency)
            }
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                  Theme.outline.b, 0.08)
            border.width: 1
            antialiasing: true
            smooth: true

            Column {
                id: mainColumn
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingS

                Rectangle {
                    width: parent.width
                    height: 90
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r,
                                   Theme.surfaceVariant.g,
                                   Theme.surfaceVariant.b,
                                   Theme.getContentBackgroundAlpha() * 0.4)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.08)
                    border.width: 1

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingL
                        anchors.rightMargin: Theme.spacingL
                        spacing: Theme.spacingL

                        Item {
                            id: avatarContainer

                            property bool hasImage: profileImageLoader.status === Image.Ready

                            width: 64
                            height: 64

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.color: Theme.primary
                                border.width: 1
                                visible: parent.hasImage
                            }

                            Image {
                                id: profileImageLoader

                                source: {
                                    if (PortalService.profileImage === "")
                                        return ""

                                    if (PortalService.profileImage.startsWith(
                                                "/"))
                                        return "file://" + PortalService.profileImage

                                    return PortalService.profileImage
                                }
                                smooth: true
                                asynchronous: true
                                mipmap: true
                                cache: true
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: profileImageLoader
                                maskEnabled: true
                                maskSource: circularMask
                                visible: avatarContainer.hasImage
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }

                            Item {
                                id: circularMask

                                width: 64 - 10
                                height: 64 - 10
                                layer.enabled: true
                                layer.smooth: true
                                visible: false

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "black"
                                    antialiasing: true
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.primary
                                visible: !parent.hasImage

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "person"
                                    size: Theme.iconSize + 8
                                    color: Theme.primaryText
                                }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "warning"
                                size: Theme.iconSize + 8
                                color: Theme.primaryText
                                visible: PortalService.profileImage !== ""
                                         && profileImageLoader.status === Image.Error
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: UserInfoService.fullName
                                      || UserInfoService.username || "User"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: (UserInfoService.uptime
                                                    || "Unknown")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                font.weight: Font.Normal
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Theme.spacingL
                        spacing: Theme.spacingS

                        Battery {
                            widgetHeight: 40
                            popupTarget: controlCenterBatteryPopout
                            parentScreen: root.triggerScreen
                            section: "right"
                            barHeight: 123
                            batteryPopupVisible: controlCenterBatteryPopout.shouldBeVisible
                            visible: BatteryService.batteryAvailable

                            onToggleBatteryPopup: {
                                if (controlCenterBatteryPopout.shouldBeVisible) {
                                    controlCenterBatteryPopout.close()
                                } else {
                                    controlCenterBatteryPopout.open()
                                }
                            }
                        }

                        DankActionButton {
                            buttonSize: 40
                            iconName: "lock"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.surfaceText
                            backgroundColor: Qt.rgba(
                                                 Theme.surfaceVariant.r,
                                                 Theme.surfaceVariant.g,
                                                 Theme.surfaceVariant.b,
                                                 0.5)
                            onClicked: {
                                root.close()
                                root.lockRequested()
                            }
                        }

                        DankActionButton {
                            buttonSize: 40
                            iconName: root.powerOptionsExpanded ? "expand_less" : "power_settings_new"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.surfaceText
                            backgroundColor: Qt.rgba(
                                                 Theme.surfaceVariant.r,
                                                 Theme.surfaceVariant.g,
                                                 Theme.surfaceVariant.b,
                                                 0.5)
                            onClicked: {
                                root.powerOptionsExpanded = !root.powerOptionsExpanded
                            }

                        }

                        DankActionButton {
                            buttonSize: 40
                            iconName: "settings"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.surfaceText
                            backgroundColor: Qt.rgba(
                                                 Theme.surfaceVariant.r,
                                                 Theme.surfaceVariant.g,
                                                 Theme.surfaceVariant.b,
                                                 0.5)
                            onClicked: {
                                root.close()
                                settingsModal.show()
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    implicitHeight: root.powerOptionsExpanded ? 60 : 0
                    height: implicitHeight
                    clip: true

                Rectangle {
                    width: parent.width
                    height: 60
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r,
                                   Theme.surfaceVariant.g,
                                   Theme.surfaceVariant.b,
                                   Theme.getContentBackgroundAlpha() * 0.4)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.08)
                    border.width: root.powerOptionsExpanded ? 1 : 0
                    opacity: root.powerOptionsExpanded ? 1 : 0
                    clip: true

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingL
                        visible: root.powerOptionsExpanded

                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: logoutButton.containsMouse ? Qt.rgba(
                                                                    Theme.primary.r,
                                                                    Theme.primary.g,
                                                                    Theme.primary.b,
                                                                    0.12) : Qt.rgba(
                                                                    Theme.surfaceVariant.r,
                                                                    Theme.surfaceVariant.g,
                                                                    Theme.surfaceVariant.b,
                                                                    0.5)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "logout"
                                    size: Theme.fontSizeSmall
                                    color: logoutButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Logout"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: logoutButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: logoutButton

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.powerOptionsExpanded = false
                                    root.close()
                                    root.powerActionRequested(
                                                "logout", "Logout",
                                                "Are you sure you want to logout?")
                                }
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: rebootButton.containsMouse ? Qt.rgba(
                                                                    Theme.primary.r,
                                                                    Theme.primary.g,
                                                                    Theme.primary.b,
                                                                    0.12) : Qt.rgba(
                                                                    Theme.surfaceVariant.r,
                                                                    Theme.surfaceVariant.g,
                                                                    Theme.surfaceVariant.b,
                                                                    0.5)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "restart_alt"
                                    size: Theme.fontSizeSmall
                                    color: rebootButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Restart"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: rebootButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: rebootButton

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.powerOptionsExpanded = false
                                    root.close()
                                    root.powerActionRequested(
                                                "reboot", "Restart",
                                                "Are you sure you want to restart?")
                                }
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: suspendButton.containsMouse ? Qt.rgba(
                                                                     Theme.primary.r,
                                                                     Theme.primary.g,
                                                                     Theme.primary.b,
                                                                     0.12) : Qt.rgba(
                                                                     Theme.surfaceVariant.r,
                                                                     Theme.surfaceVariant.g,
                                                                     Theme.surfaceVariant.b,
                                                                     0.5)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "bedtime"
                                    size: Theme.fontSizeSmall
                                    color: suspendButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Suspend"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: suspendButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: suspendButton

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.powerOptionsExpanded = false
                                    root.close()
                                    root.powerActionRequested(
                                                "suspend", "Suspend",
                                                "Are you sure you want to suspend?")
                                }
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: shutdownButton.containsMouse ? Qt.rgba(
                                                                      Theme.primary.r,
                                                                      Theme.primary.g,
                                                                      Theme.primary.b,
                                                                      0.12) : Qt.rgba(
                                                                      Theme.surfaceVariant.r,
                                                                      Theme.surfaceVariant.g,
                                                                      Theme.surfaceVariant.b,
                                                                      0.5)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "power_settings_new"
                                    size: Theme.fontSizeSmall
                                    color: shutdownButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Shutdown"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: shutdownButton.containsMouse ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: shutdownButton

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.powerOptionsExpanded = false
                                    root.close()
                                    root.powerActionRequested(
                                                "poweroff", "Shutdown",
                                                "Are you sure you want to shutdown?")
                                }
                            }
                        }
                    }
                }

                }

                Item {
                    width: parent.width
                    height: audioSliderRow.implicitHeight
                    
                    Row {
                        id: audioSliderRow
                        x: -Theme.spacingS
                        width: parent.width + Theme.spacingS * 2
                        spacing: Theme.spacingM

                        AudioSliderRow {
                            width: SettingsData.hideBrightnessSlider ? parent.width - Theme.spacingM : (parent.width - Theme.spacingM) / 2
                        }

                        Item {
                            width: (parent.width - Theme.spacingM) / 2
                            height: parent.height
                            visible: !SettingsData.hideBrightnessSlider
                            
                            BrightnessSliderRow {
                                width: parent.width
                                height: parent.height
                                x: -Theme.spacingS
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    NetworkPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "network"
                        onClicked: {
                            if (NetworkService.wifiToggling) {
                                return
                            }
                            if (NetworkService.networkStatus === "ethernet") {
                                if (NetworkService.ethernetConnected && !NetworkService.wifiEnabled) {
                                    NetworkService.toggleWifiRadio()
                                    return
                                }
                                root.toggleSection("network")
                                return
                            }
                            if (NetworkService.networkStatus === "wifi") {
                                if (NetworkService.ethernetConnected) {
                                    NetworkService.toggleWifiRadio()
                                    return
                                }
                                NetworkService.disconnectWifi()
                                return
                            }
                            if (!NetworkService.wifiEnabled) {
                                NetworkService.toggleWifiRadio()
                                return
                            }
                            if (NetworkService.wifiEnabled && NetworkService.networkStatus === "disconnected") {
                                root.toggleSection("network")
                            }
                        }
                        onExpandClicked: root.toggleSection("network")
                    }

                    BluetoothPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "bluetooth"
                        onClicked: {
                            if (!BluetoothService.available) return
                            if (BluetoothService.adapter)
                                BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                        }
                        onExpandClicked: {
                            if (!BluetoothService.available) return
                            root.toggleSection("bluetooth")
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: root.expandedSection === "network" || root.expandedSection === "bluetooth"
                    visible: active
                    sourceComponent: DetailView {
                        width: parent.width
                        isVisible: true
                        title: {
                            switch (root.expandedSection) {
                            case "network": return "Network Settings"
                            case "bluetooth": return "Bluetooth Settings"
                            default: return ""
                            }
                        }
                        content: {
                            switch (root.expandedSection) {
                            case "network": return networkDetailComponent
                            case "bluetooth": return bluetoothDetailComponent
                            default: return null
                            }
                        }
                        contentHeight: 250
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    AudioOutputPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "audio_output"
                        onClicked: {
                            if (AudioService.sink) {
                                AudioService.sink.audio.muted = !AudioService.sink.audio.muted
                            }
                        }
                        onExpandClicked: root.toggleSection("audio_output")
                    }

                    AudioInputPill {
                        width: (parent.width - Theme.spacingM) / 2
                        expanded: root.expandedSection === "audio_input"
                        onClicked: {
                            if (AudioService.source) {
                                AudioService.source.audio.muted = !AudioService.source.audio.muted
                            }
                        }
                        onExpandClicked: root.toggleSection("audio_input")
                    }
                }

                Loader {
                    width: parent.width
                    active: root.expandedSection === "audio_output" || root.expandedSection === "audio_input"
                    visible: active
                    sourceComponent: DetailView {
                        width: parent.width
                        isVisible: true
                        title: {
                            switch (root.expandedSection) {
                            case "audio_output": return "Audio Output"
                            case "audio_input": return "Audio Input"
                            default: return ""
                            }
                        }
                        content: {
                            switch (root.expandedSection) {
                            case "audio_output": return audioOutputDetailComponent
                            case "audio_input": return audioInputDetailComponent
                            default: return null
                            }
                        }
                        contentHeight: 250
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    ToggleButton {
                        width: (parent.width - Theme.spacingM) / 2
                        iconName: DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                        text: "Night Mode"
                        secondaryText: SessionData.nightModeAutoEnabled ? "Auto" : (DisplayService.nightModeEnabled ? "On" : "Off")
                        isActive: DisplayService.nightModeEnabled
                        enabled: DisplayService.automationAvailable
                        onClicked: DisplayService.toggleNightMode()

                        DankIcon {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            name: "schedule"
                            size: 12
                            color: Theme.primary
                            visible: SessionData.nightModeAutoEnabled
                            opacity: 0.8
                        }
                    }

                    ToggleButton {
                        width: (parent.width - Theme.spacingM) / 2
                        iconName: SessionData.isLightMode ? "light_mode" : "palette"
                        text: "Theme"
                        secondaryText: SessionData.isLightMode ? "Light" : "Dark"
                        isActive: true
                        onClicked: Theme.toggleLightMode()
                    }
                }
            }
            
            Details.BluetoothCodecSelector {
                id: bluetoothCodecSelector
                anchors.fill: parent
                z: 10000
            }
        }
    }

    BatteryPopout {
        id: controlCenterBatteryPopout
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {
            id: bluetoothDetail
            onShowCodecSelector: function(device) {
                if (contentLoader.item && contentLoader.item.bluetoothCodecSelector) {
                    contentLoader.item.bluetoothCodecSelector.show(device)
                    contentLoader.item.bluetoothCodecSelector.codecSelected.connect(function(deviceAddress, codecName) {
                        bluetoothDetail.updateDeviceCodecDisplay(deviceAddress, codecName)
                    })
                }
            }
        }
    }

    Component {
        id: audioOutputDetailComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputDetailComponent
        AudioInputDetail {}
    }
}
