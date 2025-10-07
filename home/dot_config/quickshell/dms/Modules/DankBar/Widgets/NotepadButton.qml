import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "right"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    readonly property string focusedScreenName: (
        CompositorService.isHyprland && typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor ? (Hyprland.focusedWorkspace.monitor.name || "") :
        CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.currentOutput ? NiriService.currentOutput : ""
    )

    function resolveNotepadInstance() {
        if (typeof notepadSlideoutVariants === "undefined" || !notepadSlideoutVariants || !notepadSlideoutVariants.instances) {
            return null
        }

        const targetScreen = focusedScreenName
        if (targetScreen) {
            for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
                var slideout = notepadSlideoutVariants.instances[i]
                if (slideout.modelData && slideout.modelData.name === targetScreen) {
                    return slideout
                }
            }
        }

        return notepadSlideoutVariants.instances.length > 0 ? notepadSlideoutVariants.instances[0] : null
    }

    readonly property var notepadInstance: resolveNotepadInstance()
    readonly property bool isActive: notepadInstance?.isVisible ?? false

    width: isVertical ? widgetThickness : (notepadIcon.width + horizontalPadding * 2)
    height: isVertical ? (notepadIcon.height + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = notepadArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    DankIcon {
        id: notepadIcon

        anchors.centerIn: parent
        name: "assignment"
        size: Theme.barIconSize(barThickness, -4)
        color: notepadArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
    }

    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: Theme.primary
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: SettingsData.dankBarNoBackground ? 0 : 4
        anchors.topMargin: SettingsData.dankBarNoBackground ? 0 : 4
        visible: NotepadStorageService.tabs && NotepadStorageService.tabs.length > 0
        opacity: 0.8
    }

    MouseArea {
        id: notepadArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            const inst = root.notepadInstance
            if (inst) {
                inst.toggle()
            }
            root.clicked()
        }
    }


}