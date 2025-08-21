import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property var modelData

    screen: modelData
    visible: ToastService.toastVisible
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Rectangle {
        id: toast

        property bool expanded: false

        Connections {
            target: ToastService
            function onResetToastState() {
                toast.expanded = false
            }
        }

        width: ToastService.hasDetails ? 380 : messageText.implicitWidth + Theme.iconSize
                                         + Theme.spacingM * 3 + Theme.spacingL * 2
        height: toastContent.height + Theme.spacingL * 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight - 4 + SettingsData.topBarSpacing + 2
        color: {
            switch (ToastService.currentLevel) {
            case ToastService.levelError:
                return Theme.error
            case ToastService.levelWarn:
                return Theme.warning
            case ToastService.levelInfo:
                return Theme.primary
            default:
                return Theme.primary
            }
        }
        radius: Theme.cornerRadius
        layer.enabled: true
        opacity: ToastService.toastVisible ? 0.9 : 0

        Column {
            id: toastContent

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Theme.spacingL
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: Theme.iconSize + 8

                DankIcon {
                    id: statusIcon
                    name: {
                        switch (ToastService.currentLevel) {
                        case ToastService.levelError:
                            return "error"
                        case ToastService.levelWarn:
                            return "warning"
                        case ToastService.levelInfo:
                            return "info"
                        default:
                            return "info"
                        }
                    }
                    size: Theme.iconSize
                    color: Theme.background
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: messageText
                    text: ToastService.currentMessage
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.background
                    font.weight: Font.Medium
                    anchors.left: statusIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.NoWrap
                }

                DankActionButton {
                    iconName: toast.expanded ? "expand_less" : "expand_more"
                    iconSize: Theme.iconSize
                    iconColor: Theme.background
                    buttonSize: Theme.iconSize + 8
                    anchors.right: closeButton.left
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ToastService.hasDetails

                    onClicked: {
                        toast.expanded = !toast.expanded
                        if (toast.expanded) {
                            ToastService.stopTimer()
                        } else {
                            ToastService.restartTimer()
                        }
                    }
                }

                DankActionButton {
                    id: closeButton
                    iconName: "close"
                    iconSize: Theme.iconSize
                    iconColor: Theme.background
                    buttonSize: Theme.iconSize + 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ToastService.hasDetails

                    onClicked: {
                        ToastService.hideToast()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: detailsText.height + Theme.spacingS * 2
                color: Qt.rgba(0, 0, 0, 0.2)
                radius: Theme.cornerRadius / 2
                visible: toast.expanded && ToastService.hasDetails
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    id: detailsText
                    text: ToastService.currentDetails
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.background
                    isMonospace: true
                    anchors.left: parent.left
                    anchors.right: copyButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    wrapMode: Text.Wrap
                }

                DankActionButton {
                    id: copyButton
                    iconName: "content_copy"
                    iconSize: Theme.iconSizeSmall
                    iconColor: Theme.background
                    buttonSize: Theme.iconSizeSmall + 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Theme.spacingS

                    property bool showTooltip: false

                    onClicked: {
                        Quickshell.execDetached(
                                    ["wl-copy", ToastService.currentDetails])
                        showTooltip = true
                        tooltipTimer.start()
                    }

                    Timer {
                        id: tooltipTimer
                        interval: 1500
                        onTriggered: copyButton.showTooltip = false
                    }

                    Rectangle {
                        visible: copyButton.showTooltip
                        width: tooltipLabel.implicitWidth + 16
                        height: tooltipLabel.implicitHeight + 8
                        color: Theme.surfaceContainer
                        radius: Theme.cornerRadius
                        border.width: 1
                        border.color: Theme.outlineMedium
                        y: -height - 4
                        x: -width / 2 + copyButton.width / 2

                        StyledText {
                            id: tooltipLabel
                            anchors.centerIn: parent
                            text: "Copied!"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: !ToastService.hasDetails
            onClicked: ToastService.hideToast()
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 0.8
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowOpacity: 0.3
        }

        transform: Translate {
            y: ToastService.toastVisible ? 0 : -20
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on height {
            enabled: ToastService.toastVisible
            NumberAnimation {
                duration: Anims.durShort
                easing.type: Easing.Linear
            }
        }

        Behavior on width {
            enabled: false
        }
    }

    mask: Region {
        item: toast
    }
}
