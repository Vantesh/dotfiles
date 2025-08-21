import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var deviceData: null
    property bool modalVisible: false
    property var parentItem
    property var availableCodecs: []
    property string currentCodec: ""
    property bool loadingCodecs: false

    property bool switchingCodec: false
    property string errorMessage: ""

    function show(device) {
        root.deviceData = device;
        root.loadingCodecs = true;
        root.visible = true;
        root.modalVisible = true;
        loadAvailableCodecs();
    }

    function hide() {
        root.modalVisible = false;
        Qt.callLater(() => {
            root.visible = false;
        });
    }

    visible: false
    width: 320
    height: codecColumn.height + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.popupBackground()
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1
    z: 2000
    opacity: modalVisible ? 1 : 0
    scale: modalVisible ? 1 : 0.9
    anchors.centerIn: parent

    // Drop shadow
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.leftMargin: 2
        anchors.rightMargin: -2
        anchors.bottomMargin: -4
        radius: parent.radius
        color: Qt.rgba(0, 0, 0, 0.15)
        z: parent.z - 1
    }

    Column {
        id: codecColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // Header
        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: deviceData ? BluetoothService.getDeviceIcon(deviceData) : "headset"
                size: Theme.iconSize + 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: deviceData ? (deviceData.name || deviceData.deviceName) : "Audio Device"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }

                StyledText {
                    text: "Select Audio Codec"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        }

        StyledText {
            text: loadingCodecs ? "Loading codecs..." : "Current: " + currentCodec
            font.pixelSize: Theme.fontSizeSmall
            color: loadingCodecs ? Theme.primary : Theme.surfaceText
            font.weight: Font.Medium
        }

        // Codec list
        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: !loadingCodecs

            Repeater {
                model: root.availableCodecs

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    color: {
                        if (modelData.name === root.currentCodec) {
                            return Theme.primary;
                        } else if (codecMouseArea.containsMouse) {
                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                        } else {
                            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.06);
                        }
                    }
                    border.color: modelData.name === root.currentCodec ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: {
                                switch (modelData.quality) {
                                case "highest":
                                    return "#4CAF50";
                                case "high":
                                    return "#FF9800";
                                case "medium":
                                    return "#2196F3";
                                case "low":
                                    return "#9E9E9E";
                                default:
                                    return Theme.primary;
                                }
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeMedium
                                color: modelData.name === root.currentCodec ? Theme.onPrimary : Theme.surfaceText
                                font.weight: modelData.name === root.currentCodec ? Font.Medium : Font.Normal
                            }

                            StyledText {
                                text: modelData.description
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.name === root.currentCodec ? Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.8) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            }
                        }
                    }

                    DankIcon {
                        name: "check"
                        size: Theme.iconSize - 4
                        color: Theme.onPrimary
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.name === root.currentCodec
                    }

                    MouseArea {
                        id: codecMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: modelData.name !== root.currentCodec && !switchingCodec

                        onClicked: switchToCodec(modelData.profile)
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                        }
                    }
                }
            }
        }

        StyledText {
            text: switchingCodec ? "Switching codec..." : errorMessage ? "Error: " + errorMessage : ""
            font.pixelSize: Theme.fontSizeSmall
            color: errorMessage ? Theme.error : Theme.primary
            visible: switchingCodec || errorMessage
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }

    function loadAvailableCodecs() {
        if (!deviceData)
            return;
        var cardName = "bluez_card." + deviceData.address.replace(/:/g, "_");
        codecInfoProcess.cardName = cardName;
        codecInfoProcess.running = true;
    }

    function switchToCodec(profile) {
        if (!deviceData || switchingCodec)
            return;
        switchingCodec = true;
        errorMessage = "";

        var cardName = "bluez_card." + deviceData.address.replace(/:/g, "_");
        codecSwitchProcess.cardName = cardName;
        codecSwitchProcess.profile = profile;
        codecSwitchProcess.running = true;
    }

    Process {
        id: codecInfoProcess
        property string cardName: ""
        property var parsedLines: []

        command: ["pactl", "list", "cards"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => parsedLines.push(data.trim())
        }

        onExited: function (exitCode, exitStatus) {
            root.loadingCodecs = false;
            if (exitCode === 0) {
                finalizeParsing();
            } else {
                root.errorMessage = "Failed to load codec information";
            }
        }

        function finalizeParsing() {
            var inTargetCard = false;
            var codecs = [];
            var currentProfile = "";

            for (var i = 0; i < parsedLines.length; i++) {
                var line = parsedLines[i];

                if (line.includes(codecInfoProcess.cardName)) {
                    inTargetCard = true;
                    continue;
                }

                if (inTargetCard && line.startsWith("Card #") && !line.includes(codecInfoProcess.cardName)) {
                    break;
                }

                if (inTargetCard) {
                    if (line.startsWith("Active Profile:")) {
                        currentProfile = line.split(": ")[1] || "";
                    }

                    if (line.includes("codec")) {
                        var parts = line.split(": ");
                        if (parts.length >= 2) {
                            var profile = parts[0].trim();
                            var description = parts[1];
                            var match = description.match(/codec ([^\)\s]+)/i);
                            var codecName = match ? match[1].toUpperCase() : "UNKNOWN";

                            var quality = "medium";
                            var displayDescription = "";

                            if (codecName === "LDAC") {
                                quality = "highest";
                                displayDescription = "Highest quality, more battery usage";
                            } else if (codecName === "APTX_HD") {
                                quality = "high";
                                displayDescription = "High quality, balanced battery";
                            } else if (codecName === "APTX") {
                                quality = "high";
                                displayDescription = "High quality, good compatibility";
                            } else if (codecName === "AAC") {
                                quality = "medium";
                                displayDescription = "Good quality, best battery life";
                            } else if (codecName === "SBC_XQ") {
                                quality = "medium";
                                displayDescription = "Enhanced SBC, wide compatibility";
                            } else if (codecName === "SBC") {
                                quality = "low";
                                displayDescription = "Basic quality, universal compatibility";
                            }

                            if (description.includes("available: yes")) {
                                codecs.push({
                                    name: codecName,
                                    profile: profile,
                                    description: displayDescription,
                                    quality: quality
                                });
                            }
                        }
                    }
                }
            }

            root.availableCodecs = codecs;
            if (currentProfile) {
                var active = codecs.find(c => currentProfile.includes(c.profile));
                if (active)
                    root.currentCodec = active.name;
            }
        }

        function getCodecNameFromProfile(profile) {
            var active = root.availableCodecs.find(c => profile.includes(c.profile));
            return active ? active.name : profile;
        }
    }

    Process {
        id: codecSwitchProcess
        property string cardName: ""
        property string profile: ""

        command: ["pactl", "set-card-profile", cardName, profile]

        onExited: function (exitCode, exitStatus) {
            root.switchingCodec = false;
            if (exitCode === 0) {
                root.currentCodec = codecInfoProcess.getCodecNameFromProfile(profile);
                ToastService.showToast("Switched to " + root.currentCodec + " codec", ToastService.levelInfo);
                Qt.callLater(root.hide);
            } else {
                root.errorMessage = "Failed to switch to selected codec";
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
