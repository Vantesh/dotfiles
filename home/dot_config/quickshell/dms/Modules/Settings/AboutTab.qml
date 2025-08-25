import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Widgets

Item {
    id: aboutTab

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            // ASCII Art Header
            StyledRect {
                width: parent.width
                height: asciiSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: asciiSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Item {
                        width: parent.width
                        height: asciiText.implicitHeight

                        StyledText {
                            id: asciiText

                            text: "██████╗  █████╗ ███╗   ██╗██╗  ██╗\n██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝\n██║  ██║███████║██╔██╗ ██║█████╔╝ \n██║  ██║██╔══██║██║╚██╗██║██╔═██╗ \n██████╔╝██║  ██║██║ ╚████║██║  ██╗\n╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
                            isMonospace: true
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primary
                            anchors.centerIn: parent
                        }
                    }

                    Row {
                        id: communityIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingL

                        // Only GitHub button remains
                        Item {
                            id: githubButton
                            width: 30
                            height: 24

                            property bool hovered: false
                            property string tooltipText: "Dank GitHub"

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/github.svg"
                                sourceSize: Qt.size(28, 18)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true

                                layer.effect: MultiEffect {
                                    colorization: 1
                                    colorizationColor: Theme.surfaceText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally("https://github.com/AvengeMedia/DankMaterialShell")
                            }
                        }
                    }
                }
            }

            // Project Information
            StyledRect {
                width: parent.width
                height: projectSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: projectSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "info"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "About"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: `Dank is a modern desktop inspired by <a href="https://m3.material.io/" style="text-decoration:none; color:${Theme.primary};">MUI 3</a>.
                        <br /><br/>The goal is to provide a high level of functionality and customization so that it can be a suitable replacement for complete desktop environments like Gnome, KDE, or Cosmic.
                        `
                        textFormat: Text.RichText
                        font.pixelSize: Theme.fontSizeMedium
                        linkColor: Theme.primary
                        onLinkActivated: url => Qt.openUrlExternally(url)
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                        }
                    }
                }
            }

            // Technical Details
            StyledRect {
                width: parent.width
                height: techSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: techSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "code"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Technical Details"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingS

                        StyledText {
                            text: "Framework:"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: `<a href="https://quickshell.org" style="text-decoration:none; color:${Theme.primary};">Quickshell</a>`
                            linkColor: Theme.primary
                            textFormat: Text.RichText
                            onLinkActivated: url => Qt.openUrlExternally(url)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                            }
                        }

                        StyledText {
                            text: "Language:"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "QML (Qt Modeling Language)"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: "Compositor:"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://hypr.land/" style="text-decoration:none; color:${Theme.primary};">Hyprland</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                color: Theme.surfaceVariantText
                                onLinkActivated: url => Qt.openUrlExternally(url)
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
                            }
                        }

                        StyledText {
                            text: "Github:"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://github.com/AvengeMedia/DankMaterialShell" style="text-decoration:none; color:${Theme.primary};">Dank</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                onLinkActivated: url => Qt.openUrlExternally(url)
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
                            }

                            StyledText {
                                text: "- Support it With a Star ⭐"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            text: "System Monitoring:"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Row {
                            spacing: 4

                            StyledText {
                                text: `<a href="https://github.com/AvengeMedia/dgop" style="text-decoration:none; color:${Theme.primary};">dgop</a>`
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                linkColor: Theme.primary
                                textFormat: Text.RichText
                                onLinkActivated: url => Qt.openUrlExternally(url)
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.NoButton
                                    propagateComposedEvents: true
                                }
                            }

                            StyledText {
                                text: "- Stateless System Monitoring"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // Community tooltip - positioned absolutely above everything
    Rectangle {
        id: communityTooltip
        parent: aboutTab
        z: 1000

        property var hoveredButton: githubButton.hovered ? githubButton : null
        property string tooltipText: hoveredButton ? hoveredButton.tooltipText : ""

        visible: hoveredButton !== null && tooltipText !== ""
        width: tooltipLabel.implicitWidth + 24
        height: tooltipLabel.implicitHeight + 12

        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.width: 1
        border.color: Theme.outlineMedium

        x: hoveredButton ? hoveredButton.mapToItem(aboutTab, hoveredButton.width / 2, 0).x - width / 2 : 0
        y: hoveredButton ? hoveredButton.mapToItem(aboutTab, 0, -height - 4).y : 0

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowOpacity: 0.15
            shadowVerticalOffset: 2
            shadowBlur: 0.5
        }

        StyledText {
            id: tooltipLabel
            anchors.centerIn: parent
            text: communityTooltip.tooltipText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }
}
