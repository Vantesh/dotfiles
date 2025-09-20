import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property string primaryText: ""
    property string secondaryText: ""
    property bool expanded: false
    property bool isActive: false
    property bool showExpandArea: true
    
    signal clicked()
    signal expandClicked()
    signal wheelEvent(var wheelEvent)

    width: parent ? parent.width : 200
    height: 60
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.6)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    Rectangle {
        id: mainArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - (root.showExpandArea ? expandArea.width : 0)
        topLeftRadius: Theme.cornerRadius
        bottomLeftRadius: Theme.cornerRadius
        topRightRadius: root.showExpandArea ? 0 : Theme.cornerRadius
        bottomRightRadius: root.showExpandArea ? 0 : Theme.cornerRadius
        color: showExpandArea && mainAreaMouse.containsMouse ? 
               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
               "transparent"
        
        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration }
        }
        
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingS
            spacing: Theme.spacingS

            DankIcon {
                name: root.iconName
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSize - Theme.spacingS
                spacing: 2

                StyledText {
                    width: parent.width
                    text: root.primaryText
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    width: parent.width
                    text: root.secondaryText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: text.length > 0
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }
        }
        
        MouseArea {
            id: mainAreaMouse
            visible: root.showExpandArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
            onWheel: function (wheelEvent) {
                root.wheelEvent(wheelEvent)
            }
        }
    }

    Rectangle {
        id: expandArea
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.iconSize + Theme.spacingM * 2
        visible: root.showExpandArea
        topLeftRadius: 0
        bottomLeftRadius: 0
        topRightRadius: Theme.cornerRadius
        bottomRightRadius: Theme.cornerRadius
        color: expandAreaMouse.containsMouse ? 
               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
               "transparent"
        
        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration }
        }
        
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }
        
        DankIcon {
            id: expandIcon
            anchors.centerIn: parent
            name: expanded ? "expand_less" : "expand_more"
            size: Theme.iconSize - 2
            color: Theme.surfaceVariantText
        }
        
        MouseArea {
            id: expandAreaMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandClicked()
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}