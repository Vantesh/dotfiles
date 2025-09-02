import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property bool isActive: false
    property bool enabled: true
    property string secondaryText: ""
    
    signal clicked()

    width: parent ? parent.width : 200
    height: 60
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.6)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: mouseArea.containsMouse ? 
               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
               "transparent"
        
        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingS

        DankIcon {
            name: root.iconName
            size: Theme.iconSize
            color: root.isActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.iconSize - Theme.spacingS
            spacing: 2

            StyledText {
                width: parent.width
                text: root.text
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
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}