import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property string imageSource: ""
    property string fallbackIcon: "notifications"
    property string fallbackText: ""
    property bool hasImage: imageSource !== ""
    property alias imageStatus: sourceImage.status
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real imageOpacity: 1.0

    width: 64
    height: 64

    Rectangle {
        id: background
        anchors.fill: parent
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
        radius: width * 0.5

        Image {
            id: sourceImage
            anchors.fill: parent
            anchors.margins: 2
            source: root.imageSource
            visible: false
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            asynchronous: true
            antialiasing: true
            cache: true

            Component.onCompleted: {
                sourceSize.width = 128
                sourceSize.height = 128
            }
        }

        ShaderEffect {
            anchors.fill: parent
            anchors.margins: 2
            visible: sourceImage.status === Image.Ready && root.imageSource !== ""

            property var source: ShaderEffectSource {
                sourceItem: sourceImage
                hideSource: true
                live: true
                recursive: false
                format: ShaderEffectSource.RGBA
            }

            property real imageOpacity: root.imageOpacity

            fragmentShader: Qt.resolvedUrl("../Shaders/qsb/circled_image.frag.qsb")
            supportsAtlasTextures: false
            blending: true
        }

        DankIcon {
            anchors.centerIn: parent
            name: root.fallbackIcon
            size: parent.width * 0.5
            color: Theme.surfaceVariantText
            visible: sourceImage.status !== Image.Ready && root.imageSource === "" && root.fallbackIcon !== ""
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.imageSource === "" && root.fallbackIcon === "" && root.fallbackText !== ""
            text: root.fallbackText
            font.pixelSize: Math.max(12, parent.width * 0.36)
            font.weight: Font.Bold
            color: Theme.primaryText
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: root.borderColor !== "transparent" ? root.borderColor : Theme.popupBackground()
            border.width: root.hasImage && sourceImage.status === Image.Ready ? (root.borderWidth > 0 ? root.borderWidth : 3) : 0
            antialiasing: true
        }
    }
}