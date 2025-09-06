import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: tabBar

    property alias model: tabRepeater.model
    property int currentIndex: 0
    property int spacing: Theme.spacingXS
    property int tabHeight: 36
    property bool showIcons: true
    property bool equalWidthTabs: true

    signal tabClicked(int index)

    height: tabHeight

    Row {
        id: tabRow

        anchors.fill: parent
        spacing: tabBar.spacing

        Repeater {
            id: tabRepeater

            Rectangle {
                property bool isActive: tabBar.currentIndex === index
                property bool hasIcon: tabBar.showIcons && modelData && modelData.icon && modelData.icon.length > 0
                property bool hasText: modelData && modelData.text && modelData.text.length > 0

                width: tabBar.equalWidthTabs ? (tabBar.width - tabBar.spacing * (tabRepeater.count - 1)) / tabRepeater.count : contentRow.implicitWidth + Theme.spacingM * 2
                height: tabBar.tabHeight
                radius: Theme.cornerRadius
                color: isActive ? Theme.primaryPressed : tabArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                Row {
                    id: contentRow

                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: modelData.icon || ""
                        size: Theme.iconSize - 4
                        color: isActive ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hasIcon
                    }

                    StyledText {
                        text: modelData.text || ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: isActive ? Theme.primary : Theme.surfaceText
                        font.weight: isActive ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        visible: hasText
                    }
                }

                MouseArea {
                    id: tabArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tabBar.currentIndex = index
                        tabBar.tabClicked(index)
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
