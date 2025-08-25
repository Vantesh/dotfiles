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
                property int tabCount: tabRepeater.count
                property bool isActive: tabBar.currentIndex === index
                property bool hasIcon: tabBar.showIcons && modelData
                                       && ("icon" in modelData)
                                       && modelData.icon
                                       && modelData.icon.length > 0
                property bool hasText: modelData && ("text" in modelData)
                                       && modelData.text
                                       && modelData.text.length > 0

                width: tabBar.equalWidthTabs ? (tabBar.width - tabBar.spacing * (tabCount - 1))
                                               / tabCount : contentRow.implicitWidth
                                               + Theme.spacingM * 2
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
                        color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.parent.hasIcon
                    }

                    StyledText {
                        text: modelData.text || ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                        font.weight: parent.parent.isActive ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        visible: parent.parent.hasText
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
