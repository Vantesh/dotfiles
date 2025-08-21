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

    width: parent.width
    spacing: Theme.spacingM
    visible: BluetoothService.adapter && BluetoothService.adapter.enabled && connectedAudioDevices.length > 0

    property var connectedAudioDevices: {
        if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
            return [];

        return BluetoothService.adapter.devices.values.filter(dev => {
            return dev && dev.connected && (BluetoothService.getDeviceIcon(dev) === "headset" || BluetoothService.getDeviceIcon(dev) === "speaker");
        });
    }

    StyledText {
        text: "Bluetooth Audio Quality"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Audio Quality Mode"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                width: (parent.width - Theme.spacingS) / 2
                height: 80
                radius: Theme.cornerRadius
                color: qualityMode === "high" ? Theme.primary : highQualityButton.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                border.color: qualityMode === "high" ? "transparent" : Theme.outline
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "high_quality"
                        size: Theme.iconSize
                        color: qualityMode === "high" ? Theme.onPrimary : Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "High Quality"
                        font.pixelSize: Theme.fontSizeSmall
                        color: qualityMode === "high" ? Theme.onPrimary : Theme.surfaceText
                        font.weight: qualityMode === "high" ? Font.Medium : Font.Normal
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "aptX/LDAC"
                        font.pixelSize: Theme.fontSizeSmall
                        color: qualityMode === "high" ? Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.7) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: highQualityButton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: qualityMode !== "high" && !switchingMode

                    onClicked: {
                        setQualityMode("high");
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }

            Rectangle {
                width: (parent.width - Theme.spacingS) / 2
                height: 80
                radius: Theme.cornerRadius
                color: qualityMode === "balanced" ? Theme.primary : balancedButton.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                border.color: qualityMode === "balanced" ? "transparent" : Theme.outline
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "balance"
                        size: Theme.iconSize
                        color: qualityMode === "balanced" ? Theme.onPrimary : Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "Balanced"
                        font.pixelSize: Theme.fontSizeSmall
                        color: qualityMode === "balanced" ? Theme.onPrimary : Theme.surfaceText
                        font.weight: qualityMode === "balanced" ? Font.Medium : Font.Normal
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "AAC/SBC"
                        font.pixelSize: Theme.fontSizeSmall
                        color: qualityMode === "balanced" ? Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.7) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: balancedButton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: qualityMode !== "balanced" && !switchingMode

                    onClicked: {
                        setQualityMode("balanced");
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }
        }

        // Status text
        StyledText {
            text: switchingMode ? "Switching audio mode..." : errorMessage ? "Error: " + errorMessage : "Current device: " + (connectedAudioDevices.length > 0 ? connectedAudioDevices[0].name : "None")
            font.pixelSize: Theme.fontSizeSmall
            color: errorMessage ? Theme.error : switchingMode ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            opacity: 0.8
        }
    }

    property string qualityMode: "balanced"
    property bool switchingMode: false
    property string errorMessage: ""
    property string currentCodec: ""

    function setQualityMode(mode) {
        if (connectedAudioDevices.length === 0) {
            errorMessage = "No connected audio devices";
            return;
        }

        switchingMode = true;
        errorMessage = "";
        qualityMode = mode;

        // Use pactl to switch codec profiles, but do not hardcode LDAC for a2dp-sink
        codecSwitchProcess.mode = mode;
        codecSwitchProcess.running = true;
    }

    Process {
        id: codecSwitchProcess
        property string mode: ""

        command: {
            // Try to set the best available codec for each connected device
            let cmds = [];
            for (let i = 0; i < connectedAudioDevices.length; i++) {
                let dev = connectedAudioDevices[i];
                let cardName = "bluez_card." + dev.address.replace(/:/g, "_");
                if (mode === "high") {
                    cmds.push(`pactl set-card-profile ${cardName} a2dp-sink-ldac || pactl set-card-profile ${cardName} a2dp-sink-aptx_hd || pactl set-card-profile ${cardName} a2dp-sink-aptx || pactl set-card-profile ${cardName} a2dp-sink-aac`);
                } else {
                    cmds.push(`pactl set-card-profile ${cardName} a2dp-sink-aac || pactl set-card-profile ${cardName} a2dp-sink-sbc`);
                }
            }
            return ["sh", "-c", cmds.join("; ")];
        }

        onExited: function (exitCode, exitStatus) {
            switchingMode = false;
            if (exitCode !== 0) {
                errorMessage = "Failed to switch audio mode";
                // Revert quality mode
                qualityMode = qualityMode === "high" ? "balanced" : "high";
            } else {
                errorMessage = "";
                // Refresh codec info after switching
                detectCurrentMode();
            }
        }
    }

    Timer {
        interval: 3000
        running: errorMessage.length > 0
        onTriggered: errorMessage = ""
    }

    Component.onCompleted: {
        if (connectedAudioDevices.length > 0) {
            detectCurrentMode();
        }
    }

    function detectCurrentMode() {
        // Query pactl for the active profile and parse the codec from the description string
        codecDetectProcess.running = true;
    }

    Process {
        id: codecDetectProcess
        command: ["pactl", "list", "cards"]
        property var lines: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => codecDetectProcess.lines.push(data.trim())
        }
        onStarted: lines = []
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                let cardName = connectedAudioDevices.length > 0 ? "bluez_card." + connectedAudioDevices[0].address.replace(/:/g, "_") : "";
                let inTargetCard = false;
                let activeProfile = "";
                let foundCodec = "";
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    if (line.startsWith("Name: ") && line.indexOf(cardName) !== -1) {
                        inTargetCard = true;
                    } else if (inTargetCard && line.startsWith("Active Profile:")) {
                        activeProfile = line.split(": ")[1] || "";
                    } else if (inTargetCard && activeProfile && line.trim().startsWith(activeProfile + ":")) {
                        // Example: a2dp-sink: High Fidelity Playback (A2DP Sink, codec LDAC) ...
                        let desc = line.trim();
                        let codecMatch = desc.match(/codec ([^\)\s]+)/i);
                        foundCodec = codecMatch ? codecMatch[1].toUpperCase() : "UNKNOWN";
                        break;
                    } else if (inTargetCard && line.startsWith("Name: ")) {
                        // End of this card
                        break;
                    }
                }
                currentCodec = foundCodec;
                // Set qualityMode based on codec
                if (foundCodec === "LDAC" || foundCodec === "APTX" || foundCodec === "APTX_HD") {
                    qualityMode = "high";
                } else {
                    qualityMode = "balanced";
                }
            }
            lines = [];
        }
    }

    Connections {
        target: BluetoothService.adapter
        function onDevicesChanged() {
            if (connectedAudioDevices.length > 0) {
                detectCurrentMode();
            }
        }
    }
}
