import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var device: null
    property bool modalVisible: false
    property var parentItem
    property var availableCodecs: []
    property string currentCodec: ""
    property bool isLoading: false
    property bool parsingTargetCard: false

    function show(bluetoothDevice) {
        device = bluetoothDevice;
        isLoading = true;
        availableCodecs = [];
        currentCodec = "";
        visible = true;
        modalVisible = true;
        queryCodecs();
        Qt.callLater(() => {
            focusScope.forceActiveFocus();
        });
    }

    function hide() {
        modalVisible = false;
        Qt.callLater(() => {
            visible = false;
        });
    }

    function queryCodecs() {
        if (!device)
            return ;

        codecQueryProcess.cardName = BluetoothService.getCardName(device);
        codecQueryProcess.running = true;
    }

    function selectCodec(profileName) {
        if (!device || isLoading)
            return ;

        isLoading = true;
        codecSwitchProcess.cardName = BluetoothService.getCardName(device);
        codecSwitchProcess.profile = profileName;
        codecSwitchProcess.running = true;
    }

    function parseCodecLine(line) {
        if (!codecQueryProcess.cardName)
            return ;

        if (line.includes(`Name: ${codecQueryProcess.cardName}`)) {
            parsingTargetCard = true;
            return ;
        }
        if (parsingTargetCard && line.startsWith("Name: ") && !line.includes(codecQueryProcess.cardName)) {
            parsingTargetCard = false;
            return ;
        }
        if (parsingTargetCard) {
            if (line.startsWith("Active Profile:")) {
                let profile = line.split(": ")[1] || "";
                let activeCodec = availableCodecs.find((c) => {
                    return c.profile === profile;
                });
                if (activeCodec)
                    currentCodec = activeCodec.name;

                return ;
            }
            if (line.includes("codec") && line.includes("available: yes")) {
                let parts = line.split(": ");
                if (parts.length >= 2) {
                    let profile = parts[0].trim();
                    let description = parts[1];
                    let codecMatch = description.match(/codec ([^\)\s]+)/i);
                    let codecName = codecMatch ? codecMatch[1].toUpperCase() : "UNKNOWN";
                    let codecInfo = BluetoothService.getCodecInfo(codecName);
                    if (codecInfo && !availableCodecs.some((c) => {
                        return c.profile === profile;
                    })) {
                        let newCodecs = availableCodecs.slice();
                        newCodecs.push({
                            "name": codecInfo.name,
                            "profile": profile,
                            "description": codecInfo.description,
                            "qualityColor": codecInfo.qualityColor
                        });
                        availableCodecs = newCodecs;
                    }
                }
            }
        }
    }

    visible: false
    anchors.fill: parent
    color: "transparent"
    z: 2000
    opacity: modalVisible ? 1 : 0

    FocusScope {
        id: focusScope

        anchors.fill: parent
        focus: root.visible
        enabled: root.visible

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
            onWheel: (wheel) => {
                return wheel.accepted = true;
            }
        }

    }

    Rectangle {
        anchors.centerIn: parent
        width: 320
        height: Math.min(contentColumn.implicitHeight + Theme.spacingL * 2, 400)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        opacity: modalVisible ? 1 : 0
        scale: modalVisible ? 1 : 0.9

        MouseArea {
            anchors.fill: parent
            onClicked: {
            }
        }

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: device ? BluetoothService.getDeviceIcon(device) : "headset"
                    size: Theme.iconSize + 4
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: device ? (device.name || device.deviceName) : ""
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: "Audio Codec Selection"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
            }

            StyledText {
                text: isLoading ? "Loading codecs..." : `Current: ${currentCodec}`
                font.pixelSize: Theme.fontSizeSmall
                color: isLoading ? Theme.primary : Theme.surfaceTextMedium
                font.weight: Font.Medium
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: !isLoading

                Repeater {
                    model: availableCodecs

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: {
                            if (modelData.name === currentCodec)
                                return Theme.surfaceContainerHigh;
                            else if (codecMouseArea.containsMouse)
                                return Theme.surfaceHover;
                            else
                                return "transparent";
                        }
                        border.color: "transparent"
                        border.width: 1

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: modelData.qualityColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: modelData.name === currentCodec ? Theme.primary : Theme.surfaceText
                                    font.weight: modelData.name === currentCodec ? Font.Medium : Font.Normal
                                }

                                StyledText {
                                    text: modelData.description
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceTextMedium
                                }

                            }

                        }

                        DankIcon {
                            name: "check"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.name === currentCodec
                        }

                        MouseArea {
                            id: codecMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: modelData.name !== currentCodec && !isLoading
                            onClicked: {
                                selectCodec(modelData.profile);
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
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
        id: codecQueryProcess

        property string cardName: ""

        command: ["pactl", "list", "cards"]
        onExited: function(exitCode, exitStatus) {
            isLoading = false;
            if (exitCode !== 0)
                console.warn("Failed to query codecs:", exitCode);

        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                return parseCodecLine(data.trim());
            }
        }

    }

    Process {
        id: codecSwitchProcess

        property string cardName: ""
        property string profile: ""

        command: ["pactl", "set-card-profile", cardName, profile]
        onExited: function(exitCode, exitStatus) {
            isLoading = false;
            if (exitCode === 0) {
                queryCodecs();
                ToastService.showToast("Codec switched successfully", ToastService.levelInfo);
                Qt.callLater(root.hide);
            } else {
                ToastService.showToast("Failed to switch codec", ToastService.levelError);
                console.warn("Failed to switch codec:", exitCode);
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }

    }

}
