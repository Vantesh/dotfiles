import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool powerOptionsExpanded: false
    property bool editMode: false

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested()
    signal editModeToggled()

    implicitHeight: 70
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                          Theme.outline.b, 0.08)
    border.width: 0

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingM

        DankCircularImage {
            id: avatarContainer

            width: 60
            height: 60
            imageSource: {
                if (PortalService.profileImage === "")
                    return ""

                if (PortalService.profileImage.startsWith("/"))
                    return "file://" + PortalService.profileImage

                return PortalService.profileImage
            }
            fallbackIcon: "person"
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Typography {
                text: UserInfoService.fullName
                      || UserInfoService.username || "User"
                style: Typography.Style.Subtitle
                color: Theme.surfaceText
            }

            Typography {
                text: (UserInfoService.uptime || "Unknown")
                style: Typography.Style.Caption
                color: Theme.surfaceVariantText
            }
        }
    }

    Row {
        id: actionButtonsRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingXS
        spacing: Theme.spacingXS

        DankActionButton {
            buttonSize: 36
            iconName: "lock"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: {
                root.lockRequested()
            }
        }

        DankActionButton {
            buttonSize: 36
            iconName: root.powerOptionsExpanded ? "expand_less" : "power_settings_new"
            iconSize: Theme.iconSize - 4
            iconColor: root.powerOptionsExpanded ? Theme.primary : Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: {
                root.powerOptionsExpanded = !root.powerOptionsExpanded
            }
        }

        DankActionButton {
            buttonSize: 36
            iconName: "settings"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: {
                settingsModal.show()
            }
        }

        DankActionButton {
            buttonSize: 36
            iconName: editMode ? "done" : "edit"
            iconSize: Theme.iconSize - 4
            iconColor: editMode ? Theme.primary : Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: root.editModeToggled()
        }
    }
}