import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: wifiContextMenuWindow

    property var networkData: null
    property bool menuVisible: false
    property var parentItem
    property var wifiPasswordModalRef
    property var networkInfoModalRef

    function show(x, y) {
        const menuWidth = 160
        wifiContextMenuWindow.visible = true
        Qt.callLater(() => {
                         const menuHeight = wifiMenuColumn.implicitHeight + Theme.spacingS * 2
                         let finalX = x - menuWidth / 2
                         let finalY = y + 4
                         finalX = Math.max(
                             Theme.spacingS, Math.min(
                                 finalX,
                                 parentItem.width - menuWidth - Theme.spacingS))
                         finalY = Math.max(
                             Theme.spacingS, Math.min(
                                 finalY,
                                 parentItem.height - menuHeight - Theme.spacingS))
                         if (finalY + menuHeight > parentItem.height - Theme.spacingS) {
                             finalY = y - menuHeight - 4
                             finalY = Math.max(Theme.spacingS, finalY)
                         }
                         wifiContextMenuWindow.x = finalX
                         wifiContextMenuWindow.y = finalY
                         wifiContextMenuWindow.menuVisible = true
                     })
    }

    function hide() {
        wifiContextMenuWindow.menuVisible = false
        Qt.callLater(() => {
                         wifiContextMenuWindow.visible = false
                     })
    }

    visible: false
    width: 160
    height: wifiMenuColumn.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: Theme.popupBackground()
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                          Theme.outline.b, 0.08)
    border.width: 1
    z: 1000
    opacity: menuVisible ? 1 : 0
    scale: menuVisible ? 1 : 0.85
    Component.onCompleted: {
        menuVisible = false
        visible = false
    }

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
        id: wifiMenuColumn

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 1

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: connectWifiArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                           Theme.primary.g,
                                                           Theme.primary.b,
                                                           0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: wifiContextMenuWindow.networkData
                          && wifiContextMenuWindow.networkData.connected ? "wifi_off" : "wifi"
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: wifiContextMenuWindow.networkData
                          && wifiContextMenuWindow.networkData.connected ? "Disconnect" : "Connect"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: connectWifiArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wifiContextMenuWindow.networkData) {
                        if (wifiContextMenuWindow.networkData.connected) {
                            NetworkService.disconnectWifi()
                        } else {
                            if (wifiContextMenuWindow.networkData.saved) {
                                NetworkService.connectToWifi(
                                            wifiContextMenuWindow.networkData.ssid)
                            } else if (wifiContextMenuWindow.networkData.secured) {
                                if (wifiPasswordModalRef) {
                                    wifiPasswordModalRef.show(
                                                wifiContextMenuWindow.networkData.ssid)
                                }
                            } else {
                                NetworkService.connectToWifi(
                                            wifiContextMenuWindow.networkData.ssid)
                            }
                        }
                    }
                    wifiContextMenuWindow.hide()
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
                color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                               Theme.outline.b, 0.2)
            }
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: forgetWifiArea.containsMouse ? Qt.rgba(Theme.error.r,
                                                          Theme.error.g,
                                                          Theme.error.b,
                                                          0.12) : "transparent"
            visible: wifiContextMenuWindow.networkData
                     && (wifiContextMenuWindow.networkData.saved
                         || wifiContextMenuWindow.networkData.connected)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "delete"
                    size: Theme.iconSize - 2
                    color: forgetWifiArea.containsMouse ? Theme.error : Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Forget Network"
                    font.pixelSize: Theme.fontSizeSmall
                    color: forgetWifiArea.containsMouse ? Theme.error : Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: forgetWifiArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wifiContextMenuWindow.networkData)
                        NetworkService.forgetWifiNetwork(
                                    wifiContextMenuWindow.networkData.ssid)

                    wifiContextMenuWindow.hide()
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
            width: parent.width
            height: 32
            radius: Theme.cornerRadius
            color: infoWifiArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                        Theme.primary.g,
                                                        Theme.primary.b,
                                                        0.12) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "info"
                    size: Theme.iconSize - 2
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Network Info"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: infoWifiArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wifiContextMenuWindow.networkData
                            && networkInfoModalRef)
                        networkInfoModalRef.showNetworkInfo(
                                    wifiContextMenuWindow.networkData.ssid,
                                    wifiContextMenuWindow.networkData)

                    wifiContextMenuWindow.hide()
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
