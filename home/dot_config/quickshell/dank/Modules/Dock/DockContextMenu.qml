import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property bool showContextMenu: false
    property var appData: null
    property var anchorItem: null
    property real dockVisibleHeight: 40
    property int margin: 10

    function showForButton(button, data, dockHeight) {
        anchorItem = button;
        appData = data;
        dockVisibleHeight = dockHeight || 40;

        var dockWindow = button.Window.window;
        if (dockWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var s = Quickshell.screens[i];
                if (dockWindow.x >= s.x && dockWindow.x < s.x + s.width) {
                    root.screen = s;
                    break;
                }
            }
        }

        showContextMenu = true;
    }
    function close() {
        showContextMenu = false;
    }

    screen: Quickshell.screens[0]

    visible: showContextMenu
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: if (visible)
        updatePosition()

    function updatePosition() {
        if (!anchorItem) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100);
            return;
        }

        var dockWindow = anchorItem.Window.window;
        if (!dockWindow) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100);
            return;
        }

        var buttonPosInDock = anchorItem.mapToItem(dockWindow.contentItem, 0, 0);

        var actualDockHeight = root.dockVisibleHeight; // fallback

        function findDockBackground(item) {
            if (item.objectName === "dockBackground") {
                return item;
            }
            for (var i = 0; i < item.children.length; i++) {
                var found = findDockBackground(item.children[i]);
                if (found)
                    return found;
            }
            return null;
        }

        var dockBackground = findDockBackground(dockWindow.contentItem);
        if (dockBackground) {
            actualDockHeight = dockBackground.height;
        }

        var dockBottomMargin = 16; // The dock has bottom margin
        var buttonScreenY = root.screen.height - actualDockHeight - dockBottomMargin - 20;

        var dockContentWidth = dockWindow.width;
        var screenWidth = root.screen.width;
        var dockLeftMargin = Math.round((screenWidth - dockContentWidth) / 2);
        var buttonScreenX = dockLeftMargin + buttonPosInDock.x + anchorItem.width / 2;

        anchorPos = Qt.point(buttonScreenX, buttonScreenY);
    }

    Rectangle {
        id: menuContainer

        width: Math.min(400, Math.max(200, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(60, menuColumn.implicitHeight + Theme.spacingS * 2)

        x: {
            var left = 10;
            var right = root.width - width - 10;
            var want = root.anchorPos.x - width / 2;
            return Math.max(left, Math.min(right, want));
        }
        y: Math.max(10, root.anchorPos.y - height + 30)
        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        opacity: showContextMenu ? 1 : 0
        scale: showContextMenu ? 1 : 0.85

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            spacing: 1

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: pinArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appData && root.appData.isPinned ? "Unpin from Dock" : "Pin to Dock"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: pinArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.appData)
                            return;
                        if (root.appData.isPinned) {
                            SessionData.removePinnedApp(root.appData.appId);
                        } else {
                            SessionData.addPinnedApp(root.appData.appId);
                        }
                        root.close();
                    }
                }
            }

            Rectangle {
                visible: !!(root.appData && root.appData.windows && root.appData.windows.count > 0)
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Repeater {
                model: root.appData && root.appData.windows ? root.appData.windows : null

                Rectangle {
                    required property var model
                    width: menuColumn.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: windowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.title || "Untitled Window"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    MouseArea {
                        id: windowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            HyprlandService.focusWindow(model.id);
                            root.close();
                        }
                    }
                }
            }

            Rectangle {
                visible: !!(root.appData && root.appData.windows && root.appData.windows.count > 1)
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: !!(root.appData && root.appData.windows && root.appData.windows.count > 1)
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: closeAllArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Close All Windows"
                    font.pixelSize: Theme.fontSizeSmall
                    color: closeAllArea.containsMouse ? Theme.error : Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: closeAllArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.appData || !root.appData.windows)
                            return;
                        for (var i = 0; i < root.appData.windows.count; i++) {
                            var window = root.appData.windows.get(i);
                            HyprlandService.closeWindow(window.id);
                        }
                        root.close();
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.close();
        }
    }
}
