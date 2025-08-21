import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var deviceData: null
    property bool modalVisible: false
    property var parentItem
    property var supportedCodecs: []

    function show(device) {
        deviceData = device;
        supportedCodecs = [];
        modalVisible = true;
        visible = true;
        loadSupportedCodecs();
    }

    function hide() {
        modalVisible = false;
        Qt.callLater(() => {
            visible = false;
        });
    }

    function loadSupportedCodecs() {
        if (!deviceData)
            return;
        var cardName = "bluez_card." + deviceData.address.replace(/:/g, "_");
        console.log("Loading supported codecs for", cardName);

        codecListProcess.cardName = cardName;
        codecListProcess.running = true;
    }

    function selectCodec(profile, name) {
        if (!deviceData)
            return;
        var cardName = "bluez_card." + deviceData.address.replace(/:/g, "_");
        console.log("Selecting codec:", profile, "for", cardName);

        codecSwitchProcess.cardName = cardName;
        codecSwitchProcess.profile = profile;
        codecSwitchProcess.codecName = name;
        codecSwitchProcess.running = true;
    }

    visible: false
    anchors.fill: parent
    z: 2000

    // Background overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        visible: root.modalVisible

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    // Modal content
    Rectangle {
        id: modalRect
        anchors.centerIn: parent
        width: 380
        height: Math.min(codecColumn.implicitHeight + 40, 500)
        radius: Theme.cornerRadius * 1.5
        color: Theme.popupBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        opacity: modalVisible ? 1 : 0
        scale: modalVisible ? 1 : 0.9

        DankFlickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: codecColumn.implicitHeight
            clip: true

            Column {
                id: codecColumn
                width: parent.width
                spacing: 16

                // Header
                Row {
                    width: parent.width
                    spacing: 12

                    DankIcon {
                        name: "high_quality"
                        size: 24
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: "Select Audio Codec"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: deviceData ? deviceData.name : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            opacity: 0.7
                        }
                    }
                }

                // Supported codecs list
                Column {
                    width: parent.width
                    spacing: 8

                    StyledText {
                        text: supportedCodecs.length > 0 ? "Available Codecs:" : "Loading codecs..."
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        visible: supportedCodecs.length > 0 || supportedCodecs.length === 0
                    }

                    Repeater {
                        model: supportedCodecs

                        Rectangle {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius
                            color: codecMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.06)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: modelData.qualityColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankIcon {
                                    name: modelData.icon
                                    size: 24
                                    color: Theme.surfaceText
                                    opacity: 0.8
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }

                                    StyledText {
                                        text: modelData.description
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        opacity: 0.7
                                    }
                                }
                            }

                            MouseArea {
                                id: codecMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectCodec(modelData.profile, modelData.name);
                                    root.hide();
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    Process {
        id: codecListProcess
        property string cardName: ""

        command: ["sh", "-c", `pactl list cards | grep -A50 'Name: ${cardName}' | grep -E 'a2dp-sink.*:.*available: yes' | head -10`]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim()) {
                    parseCodecProfile(data.trim());
                }
            }
        }

        onExited: function (exitCode, exitStatus) {
            console.log("Codec list process finished with code:", exitCode);
        }
    }

    Process {
        id: codecSwitchProcess
        property string cardName: ""
        property string profile: ""
        property string codecName: ""

        command: ["pactl", "set-card-profile", cardName, profile]

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                ToastService.showToast("Switched to " + codecName + " codec", ToastService.levelInfo);
            } else {
                ToastService.showToast("Failed to switch to " + codecName + " codec", ToastService.levelError);
            }
        }
    }

    function parseCodecProfile(line) {
        console.log("Parsing codec line:", line);

        // Extract profile name (before the colon)
        var profileMatch = line.match(/^\s*([^:]+):/);
        if (!profileMatch)
            return;
        var profile = profileMatch[1].trim();

        // Extract codec name from description (e.g., (A2DP Sink, codec LDAC))
        var codecMatch = line.match(/codec ([^\)\s]+)/i);
        var codec = codecMatch ? codecMatch[1].toUpperCase() : "UNKNOWN";

        var codecInfo = getCodecInfo(profile, codec, line);

        if (codecInfo) {
            // Check if already exists
            var exists = false;
            for (var i = 0; i < supportedCodecs.length; i++) {
                if (supportedCodecs[i].profile === profile) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                var newCodecs = supportedCodecs.slice(); // Copy array
                newCodecs.push(codecInfo);
                supportedCodecs = newCodecs;
                console.log("Added codec:", codecInfo.name, "profile:", profile, "codec:", codec);
            }
        }
    }

    function getCodecInfo(profile, codec, line) {
        // Map codec names to display info
        // Normalize codec name to match map keys (replace '-' with '_')
        var normalizedCodec = ((codec || "") + "").replace(/-/g, "_");
        var codecMap = {
            "LDAC": {
                name: "LDAC",
                description: "Highest quality • More battery usage",
                qualityColor: "#4CAF50",
                icon: "high_quality"
            },
            "APTX_HD": {
                name: "aptX HD",
                description: "High quality • Balanced battery usage",
                qualityColor: "#FF9800",
                icon: "hd"
            },
            "APTX": {
                name: "aptX",
                description: "Good quality • Low latency",
                qualityColor: "#FF9800",
                icon: "volume_up"
            },
            "AAC": {
                name: "AAC",
                description: "Balanced quality and battery usage",
                qualityColor: "#2196F3",
                icon: "equalizer"
            },
            "SBC_XQ": {
                name: "SBC-XQ",
                description: "Enhanced SBC • Better than standard SBC",
                qualityColor: "#2196F3",
                icon: "music_note"
            },
            "SBC": {
                name: "SBC",
                description: "Basic quality • Universal compatibility",
                qualityColor: "#9E9E9E",
                icon: "music_note"
            }
        };

        var info = codecMap[normalizedCodec] || {
            name: codec,
            description: "Unknown codec",
            qualityColor: "#9E9E9E",
            icon: "music_note"
        };

        return {
            name: info.name,
            profile: profile,
            description: info.description,
            qualityColor: info.qualityColor,
            icon: info.icon
        };
    }
}
