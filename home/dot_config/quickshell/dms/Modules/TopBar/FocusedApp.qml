import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool compactMode: SettingsData.focusedWindowCompactMode
    property int availableWidth: 400
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS
    readonly property int baseWidth: contentRow.implicitWidth + horizontalPadding * 2
    readonly property int maxNormalWidth: 456
    readonly property int maxCompactWidth: 288
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    width: compactMode ? Math.min(baseWidth,
                                  maxCompactWidth) : Math.min(baseWidth,
                                                              maxNormalWidth)
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (!activeWindow || !activeWindow.title)
            return "transparent"
        
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = mouseArea.containsMouse ? Theme.primaryHover : Theme.surfaceTextHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    clip: true
    visible: activeWindow && activeWindow.title

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        StyledText {
            id: appText

            text: {
                if (!activeWindow || !activeWindow.appId)
                    return ""

                var desktopEntry = DesktopEntries.byId(activeWindow.appId)
                return desktopEntry
                        && desktopEntry.name ? desktopEntry.name : activeWindow.appId
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, compactMode ? 80 : 180)
            visible: !compactMode && text.length > 0
        }

        StyledText {
            text: "•"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !compactMode && appText.text && titleText.text
        }

        StyledText {
            id: titleText

            text: {
                var title = activeWindow && activeWindow.title ? activeWindow.title : ""
                var appName = appText.text

                if (!title || !appName)
                    return title

                // Remove app name from end of title if it exists there
                if (title.endsWith(" - " + appName)) {
                    return title.substring(
                                0, title.length - (" - " + appName).length)
                }
                if (title.endsWith(appName)) {
                    return title.substring(
                                0, title.length - appName.length).replace(
                                / - $/, "")
                }

                return title
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, compactMode ? 280 : 250)
            visible: text.length > 0
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
