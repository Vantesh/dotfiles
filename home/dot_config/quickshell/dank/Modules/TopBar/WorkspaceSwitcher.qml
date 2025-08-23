import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import Quickshell.Hyprland
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string screenName: ""
    property int currentWorkspace: getDisplayActiveWorkspace()
    property var workspaceList: {
        var baseList = getDisplayWorkspaces();
        return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList;
    }

    function padWorkspaces(list) {
        var padded = list.slice();
        while (padded.length < 3)
            padded.push(-1); // Use -1 as a placeholder
        return padded;
    }

    function getWorkspaceNumbers() {
        if (!HyprlandService.hyprAvailable || HyprlandService.allWorkspaces.length === 0)
            return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

        if (displayMode === "monitors")
            return HyprlandService.getCurrentOutputWorkspaceNumbers();

        var numbers = [];
        for (var i = 0; i < HyprlandService.allWorkspaces.length; i++) {
            var ws = HyprlandService.allWorkspaces[i];
            numbers.push(ws.idx + 1);
        }
        return numbers;
    }

    function getCurrentWorkspaceNumber() {
        if (!HyprlandService.hyprAvailable || HyprlandService.allWorkspaces.length === 0)
            return 1;

        if (displayMode === "monitors")
            return HyprlandService.getCurrentWorkspaceNumber();

        for (var i = 0; i < HyprlandService.allWorkspaces.length; i++) {
            var ws = HyprlandService.allWorkspaces[i];
            if (ws.is_focused)
                return ws.idx + 1;
        }
        return 1;
    }

    function getDisplayWorkspaces() {
        if (!HyprlandService.hyprAvailable || HyprlandService.allWorkspaces.length === 0)
            return [1, 2];

        if (!root.screenName)
            return HyprlandService.getCurrentOutputWorkspaceNumbers();

        var displayWorkspaces = [];
        for (var i = 0; i < HyprlandService.allWorkspaces.length; i++) {
            var ws = HyprlandService.allWorkspaces[i];
            if (ws.output === root.screenName)
                displayWorkspaces.push(ws.idx + 1);
        }
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2];
    }

    function getDisplayActiveWorkspace() {
        if (!HyprlandService.hyprAvailable || HyprlandService.allWorkspaces.length === 0)
            return 1;

        if (!root.screenName)
            return HyprlandService.getCurrentWorkspaceNumber();

        for (var i = 0; i < HyprlandService.allWorkspaces.length; i++) {
            var ws = HyprlandService.allWorkspaces[i];
            if (ws.output === root.screenName && ws.is_active)
                return ws.idx + 1;
        }
        return 1;
    }

    width: SettingsData.showWorkspacePadding ? Math.max(120, workspaceRow.implicitWidth + Theme.spacingL * 2) : workspaceRow.implicitWidth + Theme.spacingL * 2
    height: 30
    radius: Theme.cornerRadius
    color: {
        const baseColor = Theme.surfaceTextHover;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: HyprlandService.hyprAvailable

    Connections {
        target: HyprlandService
        function onAllWorkspacesChanged() {
            root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(root.getDisplayWorkspaces()) : root.getDisplayWorkspaces();
            root.currentWorkspace = root.getDisplayActiveWorkspace();
        }

        function onFocusedWorkspaceIdChanged() {
            root.currentWorkspace = root.getDisplayActiveWorkspace();
        }

        function onHyprAvailableChanged() {
            if (HyprlandService.hyprAvailable) {
                root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(root.getDisplayWorkspaces()) : root.getDisplayWorkspaces();
                root.currentWorkspace = root.getDisplayActiveWorkspace();
            }
        }
    }

    Connections {
        function onShowWorkspacePaddingChanged() {
            var baseList = root.getDisplayWorkspaces();
            root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(baseList) : baseList;
        }

        target: SettingsData
    }

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        Repeater {
            model: root.workspaceList

            Rectangle {
                property bool isActive: modelData === root.currentWorkspace
                property bool isPlaceholder: modelData === -1
                property bool isHovered: mouseArea.containsMouse
                property int sequentialNumber: index + 1
                property var workspaceData: {
                    if (isPlaceholder || !HyprlandService.hyprAvailable)
                        return null;
                    for (var i = 0; i < HyprlandService.allWorkspaces.length; i++) {
                        var ws = HyprlandService.allWorkspaces[i];
                        if (ws.idx + 1 === modelData)
                            return ws;
                    }
                    return null;
                }
                property var iconData: workspaceData && workspaceData.name ? SettingsData.getWorkspaceNameIcon(workspaceData.name) : null
                property bool hasIcon: iconData !== null

                width: isActive ? Theme.spacingXL + Theme.spacingM : Theme.spacingL + Theme.spacingXS
                height: Theme.spacingL
                radius: height / 2
                color: isActive ? Theme.primary : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (!isPlaceholder)
                            HyprlandService.switchToWorkspace(modelData - 1);
                    }
                }

                // Icon display (priority over numbers)
                DankIcon {
                    visible: hasIcon && iconData.type === "icon"
                    anchors.centerIn: parent
                    name: hasIcon && iconData.type === "icon" ? iconData.value : ""
                    size: Theme.fontSizeSmall
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    weight: isActive && !isPlaceholder ? 500 : 400
                }

                // Custom text display (priority over numbers)
                StyledText {
                    visible: hasIcon && iconData.type === "text"
                    anchors.centerIn: parent
                    text: hasIcon && iconData.type === "text" ? iconData.value : ""
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: isActive && !isPlaceholder ? Font.DemiBold : Font.Normal
                }

                // Number display (secondary priority, only when no icon)
                StyledText {
                    visible: SettingsData.showWorkspaceIndex && !hasIcon
                    anchors.centerIn: parent
                    text: isPlaceholder ? sequentialNumber : modelData
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: isActive && !isPlaceholder ? Font.DemiBold : Font.Normal
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }
}
