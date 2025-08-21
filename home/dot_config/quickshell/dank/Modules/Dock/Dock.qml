import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: dock

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var modelData
    property var contextMenu
    property var windowsMenu
    property bool autoHide: SettingsData.dockAutoHide
    property real backgroundTransparency: SettingsData.dockTransparency

    property bool contextMenuOpen: (contextMenu && contextMenu.visible && contextMenu.screen === modelData) || (windowsMenu && windowsMenu.visible && windowsMenu.screen === modelData)
    property bool windowIsFullscreen: {
        if (!HyprlandService.focusedWindowId || !HyprlandService.hyprAvailable)
            return "";
        var focusedWindow = HyprlandService.windows.find(w => w.id === HyprlandService.focusedWindowId);
        if (!focusedWindow)
            return false;
        var fullscreenApps = ["vlc", "mpv", "kodi", "steam", "lutris", "wine", "dosbox"];
        return fullscreenApps.some(app => focusedWindow.app_id && focusedWindow.app_id.toLowerCase().includes(app));
    }
    property bool reveal: (!autoHide || dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen) && !windowIsFullscreen

    Connections {
        target: SettingsData
        function onDockTransparencyChanged() {
            dock.backgroundTransparency = SettingsData.dockTransparency;
        }
    }

    screen: modelData
    visible: SettingsData.showDock
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        left: 0
        right: 0
    }

    implicitHeight: 100
    exclusiveZone: autoHide ? -1 : 65 - 16

    mask: Region {
        item: dockMouseArea
    }

    MouseArea {
        id: dockMouseArea
        height: dock.reveal ? 65 : 12
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        implicitWidth: dock.reveal ? dockBackground.width + 32 : (dockBackground.width + 32)
        hoverEnabled: true

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: dockContainer
            anchors.fill: parent

            transform: Translate {
                id: dockSlide
                y: dock.reveal ? 0 : 60

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: dockBackground
                objectName: "dockBackground"
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }

                width: dockApps.implicitWidth + 12
                height: parent.height - 8

                anchors.topMargin: 4
                anchors.bottomMargin: 1

                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, backgroundTransparency)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Theme.outlineMedium
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                    radius: parent.radius
                }

                DockApps {
                    id: dockApps

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4

                    contextMenu: dock.contextMenu
                    windowsMenu: dock.windowsMenu
                }
            }

            Rectangle {
                id: appTooltip

                property var hoveredButton: {
                    if (!dockApps.children[0])
                        return null;
                    var row = dockApps.children[0];
                    var repeater = null;
                    for (var i = 0; i < row.children.length; i++) {
                        var child = row.children[i];
                        if (child && typeof child.count !== "undefined" && typeof child.itemAt === "function") {
                            repeater = child;
                            break;
                        }
                    }
                    if (!repeater || !repeater.itemAt)
                        return null;
                    for (var i = 0; i < repeater.count; i++) {
                        var item = repeater.itemAt(i);
                        if (item && item.dockButton && item.dockButton.showTooltip) {
                            return item.dockButton;
                        }
                    }
                    return null;
                }

                property string tooltipText: hoveredButton ? hoveredButton.tooltipText : ""

                visible: hoveredButton !== null && tooltipText !== ""
                width: tooltipLabel.implicitWidth + 24
                height: tooltipLabel.implicitHeight + 12

                color: Theme.surfaceContainer
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Theme.outlineMedium

                y: -height - 8
                x: hoveredButton ? hoveredButton.mapToItem(dockContainer, hoveredButton.width / 2, 0).x - width / 2 : 0

                StyledText {
                    id: tooltipLabel
                    anchors.centerIn: parent
                    text: appTooltip.tooltipText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
        }
    }
}
