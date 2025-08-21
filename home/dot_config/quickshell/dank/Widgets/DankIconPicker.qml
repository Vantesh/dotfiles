import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string currentIcon: ""
    property string currentText: ""
    property string iconType: "icon" // "icon" or "text"

    signal iconSelected(string iconName, string iconType)

    width: 240
    height: 32
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer
    border.color: dropdownLoader.active ? Theme.primary : (mouseArea.containsMouse ? Theme.outline : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5))
    border.width: 1

    property var iconCategories: [{
            "name": "Workspace",
            "icons": ["work", "laptop", "desktop_windows", "code", "terminal", "build", "settings", "folder", "view_module", "dashboard", "apps", "grid_view"]
        }, {
            "name": "Development",
            "icons": ["code", "terminal", "bug_report", "build", "engineering", "integration_instructions", "data_object", "schema", "api", "webhook"]
        }, {
            "name": "Communication",
            "icons": ["chat", "mail", "forum", "message", "video_call", "call", "contacts", "group", "notifications", "campaign"]
        }, {
            "name": "Media",
            "icons": ["music_note", "headphones", "mic", "videocam", "photo", "movie", "library_music", "album", "radio", "volume_up"]
        }, {
            "name": "System",
            "icons": ["memory", "storage", "developer_board", "monitor", "keyboard", "mouse", "battery_std", "wifi", "bluetooth", "security"]
        }, {
            "name": "Navigation",
            "icons": ["home", "arrow_forward", "arrow_back", "expand_more", "expand_less", "menu", "close", "search", "filter_list", "sort"]
        }, {
            "name": "Actions",
            "icons": ["add", "remove", "edit", "delete", "save", "download", "upload", "share", "content_copy", "content_paste", "content_cut", "undo", "redo"]
        }, {
            "name": "Status",
            "icons": ["check", "close", "error", "warning", "info", "done", "pending", "schedule", "update", "sync", "offline_bolt"]
        }, {
            "name": "Fun",
            "icons": ["celebration", "cake", "star", "favorite", "pets", "sports_esports", "local_fire_department", "bolt", "auto_awesome", "diamond"]
        }]

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            dropdownLoader.active = !dropdownLoader.active
        }
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingS
        spacing: Theme.spacingS

        DankIcon {
            name: root.iconType === "icon"
                  && root.currentIcon ? root.currentIcon : (root.iconType
                                                            === "text" ? "text_fields" : "add")
            size: 16
            color: root.currentIcon
                   || root.currentText ? Theme.surfaceText : Theme.outline
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (root.iconType === "text" && root.currentText)
                    return root.currentText
                if (root.iconType === "icon" && root.currentIcon)
                    return root.currentIcon
                return "Choose icon or text"
            }
            font.pixelSize: Theme.fontSizeSmall
            color: root.currentIcon
                   || root.currentText ? Theme.surfaceText : Theme.outline
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            elide: Text.ElideRight
        }
    }

    DankIcon {
        name: dropdownLoader.active ? "expand_less" : "expand_more"
        size: 16
        color: Theme.outline
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
    }

    Loader {
        id: dropdownLoader
        active: false
        asynchronous: true

        sourceComponent: PanelWindow {
            id: dropdownPopup

            visible: true
            implicitWidth: 320
            implicitHeight: Math.min(500, dropdownContent.implicitHeight + 32)
            color: "transparent"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: dropdownLoader.active = false
            }

            Rectangle {
                width: 320
                height: Math.min(500, dropdownContent.implicitHeight + 32)
                x: {
                    // Get the root picker's position relative to the screen
                    var pickerPos = root.mapToItem(null, 0, 0)
                    return Math.max(16, Math.min(pickerPos.x,
                                                 parent.width - width - 16))
                }
                y: {
                    // Position below the picker button
                    var pickerPos = root.mapToItem(null, 0, root.height + 4)
                    return Math.max(16, Math.min(pickerPos.y,
                                                 parent.height - height - 16))
                }
                radius: Theme.cornerRadius
                color: Theme.surface
                border.color: Theme.outline
                border.width: 1

                // Prevent this from closing the dropdown when clicked
                MouseArea {
                    anchors.fill: parent
                    // Don't propagate clicks to parent
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadowDark
                    shadowBlur: 0.8
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 4
                }

                DankFlickable {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    contentHeight: dropdownContent.height
                    clip: true

                    Column {
                        id: dropdownContent
                        width: parent.width
                        spacing: Theme.spacingM

                        // Custom text section
                        Rectangle {
                            width: parent.width
                            height: customTextSection.implicitHeight + Theme.spacingS * 2
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceVariant.r,
                                           Theme.surfaceVariant.g,
                                           Theme.surfaceVariant.b, 0.3)

                            Column {
                                id: customTextSection
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                StyledText {
                                    text: "Custom Text"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainer
                                    border.color: customTextInput.activeFocus ? Theme.primary : Theme.outline
                                    border.width: 1

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Theme.spacingS
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: "text_fields"
                                            size: 14
                                            color: Theme.outline
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        TextInput {
                                            id: customTextInput
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 200
                                            text: root.iconType === "text" ? root.currentText : ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            selectByMouse: true

                                            onEditingFinished: {
                                                var trimmedText = text.trim()
                                                if (trimmedText) {
                                                    root.iconSelected(
                                                                trimmedText,
                                                                "text")
                                                    dropdownLoader.active = false
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingS + 14 + Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "1-2 characters"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.outline
                                        opacity: 0.6
                                        visible: customTextInput.text === ""
                                    }
                                }
                            }
                        }

                        // Icon categories
                        Repeater {
                            model: root.iconCategories

                            Column {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: modelData.icons

                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: Theme.cornerRadius
                                            color: iconMouseArea.containsMouse ? Theme.primaryHover : "transparent"
                                            border.color: root.currentIcon === modelData ? Theme.primary : "transparent"
                                            border.width: 2

                                            DankIcon {
                                                name: modelData
                                                size: 20
                                                color: root.currentIcon === modelData ? Theme.primary : Theme.surfaceText
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                id: iconMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.iconSelected(
                                                                modelData,
                                                                "icon")
                                                    dropdownLoader.active = false
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
                    }
                }
            }
        }
    }

    function setIcon(iconName, type) {
        if (type === "text") {
            root.currentText = iconName
            root.currentIcon = ""
            root.iconType = "text"
        } else {
            root.currentIcon = iconName
            root.currentText = ""
            root.iconType = "icon"
        }
    }
}
