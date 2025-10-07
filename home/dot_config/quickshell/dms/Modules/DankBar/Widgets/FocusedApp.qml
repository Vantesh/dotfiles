import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property var parentScreen
    property bool compactMode: SettingsData.focusedWindowCompactMode
    property int availableWidth: 400
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS
    readonly property int baseWidth: contentRow.implicitWidth + horizontalPadding * 2
    readonly property int maxNormalWidth: 456
    readonly property int maxCompactWidth: 288
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property var activeDesktopEntry: null

    Component.onCompleted: {
        updateDesktopEntry()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.updateDesktopEntry()
        }
    }

    Connections {
        target: root
        function onActiveWindowChanged() {
            root.updateDesktopEntry()
        }
    }

    function updateDesktopEntry() {
        if (activeWindow && activeWindow.appId) {
            const moddedId = Paths.moddedAppId(activeWindow.appId)
            activeDesktopEntry = DesktopEntries.heuristicLookup(moddedId)
        } else {
            activeDesktopEntry = null
        }
    }
    readonly property bool hasWindowsOnCurrentWorkspace: {
        if (CompositorService.isNiri) {
            let currentWorkspaceId = null
            for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
                const ws = NiriService.allWorkspaces[i]
                if (ws.is_focused) {
                    currentWorkspaceId = ws.id
                    break
                }
            }

            if (!currentWorkspaceId) {
                return false
            }

            const workspaceWindows = NiriService.windows.filter(w => w.workspace_id === currentWorkspaceId)
            return workspaceWindows.length > 0 && activeWindow && activeWindow.title
        }

        if (CompositorService.isHyprland) {
            if (!Hyprland.focusedWorkspace || !activeWindow || !activeWindow.title) {
                return false
            }

            const hyprlandToplevels = Array.from(Hyprland.toplevels.values)
            const activeHyprToplevel = hyprlandToplevels.find(t => t.wayland === activeWindow)

            if (!activeHyprToplevel || !activeHyprToplevel.workspace) {
                return false
            }

            return activeHyprToplevel.workspace.id === Hyprland.focusedWorkspace.id
        }

        return activeWindow && activeWindow.title
    }

    width: !hasWindowsOnCurrentWorkspace ? 0 : (isVertical ? widgetThickness : (compactMode ? Math.min(baseWidth, maxCompactWidth) : Math.min(baseWidth, maxNormalWidth)))
    height: !hasWindowsOnCurrentWorkspace ? 0 : (isVertical ? widgetThickness : widgetThickness)
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (!activeWindow || !activeWindow.title) {
            return "transparent";
        }

        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = mouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    clip: true
    visible: hasWindowsOnCurrentWorkspace

    IconImage {
        id: appIcon
        anchors.centerIn: parent
        width: 18
        height: 18
        visible: root.isVertical && activeWindow && status === Image.Ready
        source: {
            if (!activeWindow || !activeWindow.appId) return ""
            const moddedId = Paths.moddedAppId(activeWindow.appId)
            if (moddedId.toLowerCase().includes("steam_app")) return ""
            return Quickshell.iconPath(activeDesktopEntry?.icon, true)
        }
        smooth: true
        mipmap: true
        asynchronous: true
    }

    DankIcon {
        anchors.centerIn: parent
        size: 18
        name: "sports_esports"
        color: Theme.surfaceText
        visible: {
            if (!root.isVertical || !activeWindow || !activeWindow.appId) return false
            const moddedId = Paths.moddedAppId(activeWindow.appId)
            return moddedId.toLowerCase().includes("steam_app")
        }
    }

    Text {
        anchors.centerIn: parent
        visible: {
            if (!root.isVertical || !activeWindow || !activeWindow.appId) return false
            if (appIcon.status === Image.Ready) return false
            const moddedId = Paths.moddedAppId(activeWindow.appId)
            return !moddedId.toLowerCase().includes("steam_app")
        }
        text: {
            if (!activeWindow || !activeWindow.appId) return "?"
            if (activeDesktopEntry && activeDesktopEntry.name) {
                return activeDesktopEntry.name.charAt(0).toUpperCase()
            }
            return activeWindow.appId.charAt(0).toUpperCase()
        }
        font.pixelSize: 10
        color: Theme.surfaceText
        font.weight: Font.Medium
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: !root.isVertical

        StyledText {
            id: appText

            text: {
                if (!activeWindow || !activeWindow.appId) {
                    return "";
                }

                const desktopEntry = DesktopEntries.heuristicLookup(activeWindow.appId);
                return desktopEntry && desktopEntry.name ? desktopEntry.name : activeWindow.appId;
            }
            font.pixelSize: Theme.barTextSize(barThickness)
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
            font.pixelSize: Theme.barTextSize(barThickness)
            color: Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !compactMode && appText.text && titleText.text
        }

        StyledText {
            id: titleText

            text: {
                const title = activeWindow && activeWindow.title ? activeWindow.title : "";
                const appName = appText.text;
                if (!title || !appName) {
                    return title;
                }

                if (title.endsWith(" - " + appName)) {
                    return title.substring(0, title.length - (" - " + appName).length);
                }

                if (title.endsWith(appName)) {
                    return title.substring(0, title.length - appName.length).replace(/ - $/, "");
                }

                return title;
            }
            font.pixelSize: Theme.barTextSize(barThickness)
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
        hoverEnabled: root.isVertical
        onEntered: {
            if (root.isVertical && activeWindow && activeWindow.appId && root.parentScreen) {
                tooltipLoader.active = true
                if (tooltipLoader.item) {
                    const globalPos = mapToGlobal(width / 2, height / 2)
                    const currentScreen = root.parentScreen
                    const screenX = currentScreen ? currentScreen.x : 0
                    const screenY = currentScreen ? currentScreen.y : 0
                    const relativeY = globalPos.y - screenY
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)

                    const appName = activeDesktopEntry && activeDesktopEntry.name ? activeDesktopEntry.name : activeWindow.appId
                    const title = activeWindow.title || ""
                    const tooltipText = appName + (title ? " • " + title : "")

                    const isLeft = root.axis?.edge === "left"
                    tooltipLoader.item.show(tooltipText, screenX + tooltipX, relativeY, currentScreen, isLeft, !isLeft)
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide()
            }
            tooltipLoader.active = false
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

}
