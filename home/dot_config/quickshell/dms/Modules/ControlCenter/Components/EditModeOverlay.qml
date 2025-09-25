import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool editMode: false
    property var widgetData: null
    property int widgetIndex: -1
    property bool showSizeControls: true
    property bool isSlider: false

    signal removeWidget(int index)
    signal toggleWidgetSize(int index)
    signal moveWidget(int fromIndex, int toIndex)

    // Delete button in top-right
    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Theme.error
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -4
        visible: editMode
        z: 10

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 12
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.removeWidget(widgetIndex)
        }
    }

    // Size control buttons in bottom-right
    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: -8
        spacing: 4
        visible: editMode && showSizeControls
        z: 10

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: (widgetData?.width || 50) === 25 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 0
            visible: !isSlider

            StyledText {
                anchors.centerIn: parent
                text: "25"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 25 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 25
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: (widgetData?.width || 50) === 50 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 0

            StyledText {
                anchors.centerIn: parent
                text: "50"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 50 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 50
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: (widgetData?.width || 50) === 75 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 0
            visible: !isSlider

            StyledText {
                anchors.centerIn: parent
                text: "75"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 75 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 75
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: (widgetData?.width || 50) === 100 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 0

            StyledText {
                anchors.centerIn: parent
                text: "100"
                font.pixelSize: 9
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 100 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 100
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }
    }

    // Arrow buttons for reordering in top-left
    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 4
        spacing: 2
        visible: editMode
        z: 20

        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 0

            DankIcon {
                anchors.centerIn: parent
                name: "keyboard_arrow_left"
                size: 12
                color: Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                enabled: widgetIndex > 0
                opacity: enabled ? 1.0 : 0.5
                onClicked: root.moveWidget(widgetIndex, widgetIndex - 1)
            }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 0

            DankIcon {
                anchors.centerIn: parent
                name: "keyboard_arrow_right"
                size: 12
                color: Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                enabled: widgetIndex < ((SettingsData.controlCenterWidgets?.length ?? 0) - 1)
                opacity: enabled ? 1.0 : 0.5
                onClicked: root.moveWidget(widgetIndex, widgetIndex + 1)
            }
        }
    }

    // Border highlight
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
        radius: Theme.cornerRadius
        border.color: Theme.primary
        border.width: editMode ? 1 : 0
        visible: editMode
        z: -1

        Behavior on border.width {
            NumberAnimation { duration: Theme.shortDuration }
        }
    }
}