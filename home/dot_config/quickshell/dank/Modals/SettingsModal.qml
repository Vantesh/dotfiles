import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets
pragma ComponentBehavior

DankModal {
    id: settingsModal

    property Component settingsContent

    signal closingModal

    function show() {
        open()
    }

    function hide() {
        close()
    }

    function toggle() {
        if (shouldBeVisible)
            hide()
        else
            show()
    }

    objectName: "settingsModal"
    width: 800
    height: 750
    visible: false
    onBackgroundClicked: hide()
    content: settingsContent

    IpcHandler {
        function open() {
            settingsModal.show()
            return "SETTINGS_OPEN_SUCCESS"
        }

        function close() {
            settingsModal.hide()
            return "SETTINGS_CLOSE_SUCCESS"
        }

        function toggle() {
            settingsModal.toggle()
            return "SETTINGS_TOGGLE_SUCCESS"
        }

        target: "settings"
    }

    settingsContent: Component {
        Item {
            anchors.fill: parent
            focus: true

            Column {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingM
                anchors.bottomMargin: Theme.spacingL
                spacing: 0

                Item {
                    width: parent.width
                    height: 35

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "settings"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Settings"
                            font.pixelSize: Theme.fontSizeXLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankActionButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        hoverColor: Theme.errorHover
                        onClicked: settingsModal.hide()
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 35
                    spacing: 0

                    Rectangle {
                        id: sidebarContainer

                        property int currentIndex: 0

                        width: 270
                        height: parent.height
                        color: Theme.surfaceContainer
                        radius: Theme.cornerRadius

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            anchors.topMargin: Theme.spacingM + 2
                            spacing: Theme.spacingXS

                            Rectangle {
                                width: parent.width - Theme.spacingS * 2
                                height: 110
                                radius: Theme.cornerRadius
                                color: "transparent"
                                border.width: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Item {
                                        id: profileImageContainer
                                        width: 80
                                        height: 80
                                        anchors.verticalCenter: parent.verticalCenter

                                        property bool hasImage: profileImageSource.status
                                                                === Image.Ready

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: "transparent"
                                            border.color: Theme.primary
                                            border.width: 1
                                            visible: parent.hasImage
                                        }

                                        Image {
                                            id: profileImageSource
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
                                            source: profileImageSource
                                            maskEnabled: true
                                            maskSource: profileCircularMask
                                            visible: profileImageContainer.hasImage
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1
                                        }

                                        Item {
                                            id: profileCircularMask
                                            width: 70
                                            height: 70
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
                                                size: Theme.iconSizeLarge
                                                color: Theme.primaryText
                                            }
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "warning"
                                            size: Theme.iconSizeLarge
                                            color: Theme.error
                                            visible: PortalService.profileImage !== ""
                                                     && profileImageSource.status === Image.Error
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.7)
                                            visible: profileMouseArea.containsMouse

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 4

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: Qt.rgba(255, 255,
                                                                   255, 0.9)

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: "edit"
                                                        size: 16
                                                        color: "black"
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            settingsModal.allowFocusOverride = true
                                                            settingsModal.shouldHaveFocus = false
                                                            profileBrowser.open(
                                                                        )
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: Qt.rgba(255, 255,
                                                                   255, 0.9)
                                                    visible: profileImageContainer.hasImage

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: "close"
                                                        size: 16
                                                        color: "black"
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            PortalService.setProfileImage(
                                                                        "")
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: profileMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            propagateComposedEvents: true
                                            acceptedButtons: Qt.NoButton
                                        }
                                    }

                                    Column {
                                        width: 120
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: UserInfoService.fullName
                                                  || "User"
                                            font.pixelSize: Theme.fontSizeLarge
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: DgopService.distribution
                                                  || "Linux"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - Theme.spacingS * 2
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            Item {
                                width: parent.width
                                height: Theme.spacingL
                            }

                            Repeater {
                                id: sidebarRepeater

                                model: [{
                                        "text": "Personalization",
                                        "icon": "person"
                                    }, {
                                        "text": "Time & Date",
                                        "icon": "schedule"
                                    }, {
                                        "text": "Weather",
                                        "icon": "cloud"
                                    }, {
                                        "text": "Top Bar",
                                        "icon": "toolbar"
                                    }, {
                                        "text": "Widgets",
                                        "icon": "widgets"
                                    }, {
                                        "text": "Dock",
                                        "icon": "dock_to_bottom"
                                    }, {
                                        "text": "Recent Apps",
                                        "icon": "history"
                                    }, {
                                        "text": "Theme & Colors",
                                        "icon": "palette"
                                    }, {
                                        "text": "About",
                                        "icon": "info"
                                    }]

                                Rectangle {
                                    property bool isActive: sidebarContainer.currentIndex === index

                                    width: parent.width - Theme.spacingS * 2
                                    height: 44
                                    radius: Theme.cornerRadius
                                    color: isActive ? Theme.surfaceContainerHigh : tabMouseArea.containsMouse ? Theme.surfaceHover : "transparent"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingM

                                        DankIcon {
                                            name: modelData.icon || ""
                                            size: Theme.iconSize - 2
                                            color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.text || ""
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                                            font.weight: parent.parent.isActive ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            sidebarContainer.currentIndex = index
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

                    Item {
                        width: parent.width - sidebarContainer.width
                        height: parent.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 0
                            anchors.rightMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingM
                            anchors.topMargin: 0
                            color: "transparent"

                            Loader {
                                id: personalizationLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 0
                                visible: active
                                asynchronous: true

                                sourceComponent: Component {
                                    PersonalizationTab {
                                        parentModal: settingsModal
                                    }
                                }
                            }

                            Loader {
                                id: timeLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 1
                                visible: active
                                asynchronous: true

                                sourceComponent: TimeTab {}
                            }

                            Loader {
                                id: weatherLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 2
                                visible: active
                                asynchronous: true

                                sourceComponent: WeatherTab {}
                            }

                            Loader {
                                id: topBarLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 3
                                visible: active
                                asynchronous: true

                                sourceComponent: TopBarTab {}
                            }

                            Loader {
                                id: widgetsLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 4
                                visible: active
                                asynchronous: true
                                sourceComponent: WidgetTweaksTab {}
                            }

                            Loader {
                                id: dockLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 5
                                visible: active
                                asynchronous: true

                                sourceComponent: Component {
                                    DockTab {}
                                }
                            }

                            Loader {
                                id: recentAppsLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 6
                                visible: active
                                asynchronous: true
                                sourceComponent: RecentAppsTab {}
                            }

                            Loader {
                                id: themeColorsLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 7
                                visible: active
                                asynchronous: true
                                sourceComponent: ThemeColorsTab {}
                            }

                            Loader {
                                id: aboutLoader

                                anchors.fill: parent
                                active: sidebarContainer.currentIndex === 8
                                visible: active
                                asynchronous: true
                                sourceComponent: AboutTab {}
                            }
                        }
                    }
                }

            }

        }
    }

    FileBrowserModal {
        id: profileBrowser

        browserTitle: "Select Profile Image"
        browserIcon: "person"
        browserType: "profile"
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
                            PortalService.setProfileImage(path)
                            close()
                        }
        onDialogClosed: {
            if (settingsModal) {
                settingsModal.allowFocusOverride = false
                settingsModal.shouldHaveFocus = Qt.binding(() => {
                                                               return settingsModal.shouldBeVisible
                                                           })
            }
        }
    }
}
