import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Popup {
    id: root

    property var allWidgets: []
    property string targetSection: ""
    property bool isOpening: false

    signal widgetSelected(string widgetId, string targetSection)

    function safeOpen() {
        if (!isOpening && !visible) {
            isOpening = true
            open()
        }
    }

    width: 400
    height: 450
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: {
        isOpening = false
    }
    onClosed: {
        isOpening = false
        allWidgets = []
        targetSection = ""
    }

    background: Rectangle {
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                       Theme.surfaceContainer.b, 1)
        border.color: Theme.primarySelected
        border.width: 1
        radius: Theme.cornerRadius
    }

    contentItem: Item {
        anchors.fill: parent

        DankActionButton {
            iconName: "close"
            iconSize: Theme.iconSize - 2
            iconColor: Theme.outline
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            onClicked: root.close()
        }

        Column {
            id: contentColumn

            spacing: Theme.spacingM
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            anchors.topMargin: Theme.spacingL + 30 // Space for close button

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: "add_circle"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Add Widget to " + root.targetSection + " Section"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "Select a widget to add to the " + root.targetSection.toLowerCase(
                          ) + " section of the top bar. You can add multiple instances of the same widget if needed."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.outline
                width: parent.width
                wrapMode: Text.WordWrap
            }

            DankListView {
                id: widgetList

                width: parent.width
                height: parent.height - y
                spacing: Theme.spacingS
                model: root.allWidgets
                clip: true

                delegate: Rectangle {
                    width: widgetList.width
                    height: 60
                    radius: Theme.cornerRadius
                    color: widgetArea.containsMouse ? Theme.primaryHover : Qt.rgba(
                                                            Theme.surfaceVariant.r,
                                                            Theme.surfaceVariant.g,
                                                            Theme.surfaceVariant.b,
                                                            0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                            Theme.outline.b, 0.2)
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon {
                            name: modelData.icon
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - Theme.iconSize - Theme.spacingM * 3

                            StyledText {
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: modelData.description
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.outline
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }

                        DankIcon {
                            name: "add"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: widgetArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.widgetSelected(modelData.id,
                                                root.targetSection)
                            root.close()
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
