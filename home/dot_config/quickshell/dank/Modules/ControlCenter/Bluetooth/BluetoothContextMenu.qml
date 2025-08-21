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
    property bool menuVisible: false
    property var parentItem

    function show(x, y) {
        const menuWidth = 160;
        const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2;
        let finalX = x - menuWidth / 2;
        let finalY = y;
        finalX = Math.max(0, Math.min(finalX, parentItem.width - menuWidth));
        finalY = Math.max(0, Math.min(finalY, parentItem.height - menuHeight));
        root.x = finalX;
        root.y = finalY;
        root.visible = true;
        root.menuVisible = true;
    }

    function hide() {
        root.menuVisible = false;
        Qt.callLater(() => {
            root.visible = false;
        });
    }

    visible: false
    width: 160
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: Theme.popupBackground()
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    z: 1000
    opacity: menuVisible ? 1 : 0
    scale: menuVisible ? 1 : 0.85

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
        id: menuColumn

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 1

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: connectArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: root.deviceData && root.deviceData.connected ? "link_off" : "link"
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.deviceData && root.deviceData.connected ? "Disconnect" : "Connect"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: connectArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.deviceData) {
                        if (root.deviceData.connected)
                            root.deviceData.disconnect();
                        else
                            BluetoothService.connectDeviceWithTrust(root.deviceData);
                    }
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

        Rectangle {
            width: parent.width - Theme.spacingS * 2
            height: 5
            anchors.horizontalCenter: parent.horizontalCenter
            color: "transparent"
            visible: isAudioDevice()

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: codecArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
            visible: isAudioDevice() && root.deviceData && root.deviceData.connected

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "high_quality"
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Audio Quality"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: codecArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    openCodecSelection();
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

        Rectangle {
            width: parent.width - Theme.spacingS * 2
            height: 5
            anchors.horizontalCenter: parent.horizontalCenter
            color: "transparent"

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: forgetArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "delete"
                    size: Theme.iconSize - 2
                    color: forgetArea.containsMouse ? Theme.error : Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Forget Device"
                    font.pixelSize: Theme.fontSizeSmall
                    color: forgetArea.containsMouse ? Theme.error : Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: forgetArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.deviceData)
                        root.deviceData.forget();

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

    function isAudioDevice() {
        if (!root.deviceData)
            return false;

        var icon = BluetoothService.getDeviceIcon(root.deviceData);
        return icon === "headset" || icon === "speaker";
    }

    function openCodecSelection() {
        if (!root.deviceData || !root.deviceData.connected)
            return;
        console.log("BluetoothContextMenu: Opening codec selection for", root.deviceData.name);

        // Find the simple codec selection modal in the parent
        if (root.parentItem && root.parentItem.simpleCodecSelectionModal) {
            root.parentItem.simpleCodecSelectionModal.show(root.deviceData);
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
