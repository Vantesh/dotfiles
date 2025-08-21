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

    // Map of device.address -> codec string (e.g. "LDAC")
    property var deviceCodecs: ({})

    // Parse active profiles for all bluez cards once per interval / on demand
    function refreshCodecs() {
        if (codecProcess.running)
            return;
        codecProcess.running = true;
    }

    function codecNameFromProfile(profile, description) {
        // Extract codec from description string if available
        var codecMatch = description ? description.match(/codec ([^\)\s]+)/i) : null;
        if (codecMatch)
            return codecMatch[1].toUpperCase();
        if (!profile)
            return "";
        if (profile.includes("ldac") || profile === "a2dp-sink")
            return "LDAC";
        if (profile.includes("aptx_hd"))
            return "aptX HD";
        if (profile.includes("aptx"))
            return "aptX";
        if (profile.includes("aac"))
            return "AAC";
        if (profile.includes("sbc_xq"))
            return "SBC-XQ";
        if (profile.includes("sbc"))
            return "SBC";
        return profile;
    }

    Timer {
        interval: 15000
        running: BluetoothService.adapter && BluetoothService.adapter.devices && BluetoothService.adapter.devices.values.some(d => d && d.connected)
        repeat: true
        onTriggered: refreshCodecs()
    }

    Component.onCompleted: refreshCodecs()

    Process {
        id: codecProcess
        command: ["pactl", "list", "cards"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => codecProcess.lines.push(data.trim())
        }
        property var lines: []
        onStarted: lines = []
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                var cardActive = {}; // cardName -> active profile
                var currentCard = "";
                // Parse codec from description string for each card/profile
                var cardProfiles = {}; // cardName -> { profile, description }
                var currentCard = "";
                var inProfiles = false;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.startsWith("Card #")) {
                        currentCard = "";
                        inProfiles = false;
                        continue;
                    }
                    if (line.startsWith("Name: ")) {
                        var n = line.substring(6).trim();
                        currentCard = n.startsWith("bluez_card.") ? n : "";
                        continue;
                    }
                    if (currentCard && line.trim() === "Profiles:") {
                        inProfiles = true;
                        continue;
                    }
                    if (currentCard && inProfiles && /^\s*[^:]+:/.test(line)) {
                        // Profile line
                        var prof = line.split(":")[0].trim();
                        var desc = line.trim();
                        if (!cardProfiles[currentCard])
                            cardProfiles[currentCard] = {};
                        cardProfiles[currentCard][prof] = desc;
                    }
                    if (currentCard && inProfiles && line.trim() === "Ports:") {
                        inProfiles = false;
                    }
                }
                var cardActive = {}; // cardName -> active profile
                currentCard = "";
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.startsWith("Card #")) {
                        currentCard = "";
                        continue;
                    }
                    if (line.startsWith("Name: ")) {
                        var n = line.substring(6).trim();
                        currentCard = n.startsWith("bluez_card.") ? n : "";
                        continue;
                    }
                    if (currentCard && line.startsWith("Active Profile:")) {
                        cardActive[currentCard] = (line.split(": ")[1] || "");
                    }
                }
                var map = {};
                if (BluetoothService.adapter && BluetoothService.adapter.devices) {
                    var devs = BluetoothService.adapter.devices.values;
                    for (var j = 0; j < devs.length; j++) {
                        var dev = devs[j];
                        if (!dev || !dev.connected)
                            continue;
                        var cardName = "bluez_card." + dev.address.replace(/:/g, "_");
                        var activeProfile = cardActive[cardName];
                        var desc = cardProfiles[cardName] && cardProfiles[cardName][activeProfile] ? cardProfiles[cardName][activeProfile] : "";
                        if (activeProfile)
                            map[dev.address] = codecNameFromProfile(activeProfile, desc);
                    }
                }
                deviceCodecs = map;
            }
            lines = [];
        }
    }

    function findBluetoothContextMenu() {
        var p = parent;
        while (p) {
            if (p.bluetoothContextMenuWindow)
                return p.bluetoothContextMenuWindow;
            p = p.parent;
        }
        return null;
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
        model: BluetoothService.adapter && BluetoothService.adapter.devices ? BluetoothService.adapter.devices.values.filter(dev => {
            return dev && (dev.paired || dev.trusted);
        }) : []

        Rectangle {
            id: deviceRect
            width: parent.width
            height: 60
            radius: Theme.cornerRadius
            color: btDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : (modelData.connected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
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
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        }

                        StyledText {
                            text: {
                                if (modelData.batteryAvailable && modelData.battery > 0)
                                    return "• " + Math.round(modelData.battery * 100) + "%";

                                var btBattery = BatteryService.bluetoothDevices.find(dev => {
                                    return dev.name === (modelData.name || modelData.deviceName) || dev.name.toLowerCase().includes((modelData.name || modelData.deviceName).toLowerCase()) || (modelData.name || modelData.deviceName).toLowerCase().includes(dev.name.toLowerCase());
                                });
                                return btBattery ? "• " + btBattery.percentage + "%" : "";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            visible: text.length > 0
                        }

                        // Current audio codec (if available)
                        StyledText {
                            text: modelData.connected && deviceCodecs[modelData.address] ? "• " + deviceCodecs[modelData.address] : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            visible: text.length > 0
                        }
                    }
                }
            }

            Rectangle {
                id: btMenuButton

                width: 32
                height: 32
                radius: Theme.cornerRadius
                color: btMenuButtonArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : "transparent"
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
                        var contextMenu = root.findBluetoothContextMenu();
                        if (contextMenu) {
                            contextMenu.deviceData = modelData;
                            let localPos = btMenuButtonArea.mapToItem(contextMenu.parentItem, btMenuButtonArea.width / 2, btMenuButtonArea.height);
                            contextMenu.show(localPos.x, localPos.y);
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
                        modelData.disconnect();
                    else
                        BluetoothService.connectDeviceWithTrust(modelData);
                }
            }
        }
    }
}
