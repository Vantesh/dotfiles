import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    property int screenWidth: parent.width
    property int screenHeight: parent.height

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Rectangle {
        x: parent.width * 0.7
        y: -parent.height * 0.3
        width: parent.width * 0.8
        height: parent.height * 1.5
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
        rotation: 35
    }

    Rectangle {
        x: parent.width * 0.85
        y: -parent.height * 0.2
        width: parent.width * 0.4
        height: parent.height * 1.2
        color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12)
        rotation: 35
    }


    Item {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingXL * 2
        anchors.bottomMargin: Theme.spacingXL * 2
        
        opacity: 0.25
        
        StyledText {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: `
██████╗  █████╗ ███╗   ██╗██╗  ██╗
██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝
██║  ██║███████║██╔██╗ ██║█████╔╝
██║  ██║██╔══██║██║╚██╗██║██╔═██╗
██████╔╝██║  ██║██║ ╚████║██║  ██╗
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝`
            isMonospace: true
            font.pixelSize: Theme.fontSizeLarge * 1.2
            color: Theme.primary
        }
    }
}