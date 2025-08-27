import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property var modelData
    property bool shouldBeVisible: false
    property int autoHideInterval: 2000
    property bool enableMouseInteraction: false
    property real osdWidth: Theme.iconSize + Theme.spacingS * 2
    property real osdHeight: Theme.iconSize + Theme.spacingS * 2
    property int animationDuration: Theme.mediumDuration
    property var animationEasing: Theme.emphasizedEasing

    signal osdShown
    signal osdHidden

    function show() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        hideTimer.restart()
        osdShown()
    }

    function hide() {
        shouldBeVisible = false
        closeTimer.restart()
    }

    function resetHideTimer() {
        if (shouldBeVisible && enableMouseInteraction) {
            // Only restart timer if we're not currently hovering
            let isHovered = (enableMouseInteraction && mouseArea.containsMouse) || osdContainer.childHovered
            if (!isHovered) {
                hideTimer.restart()
            }
        }
    }

    function stopHideTimer() {
        if (enableMouseInteraction)
            hideTimer.stop()
    }

    function updateHoverState() {
        let isHovered = (enableMouseInteraction && mouseArea.containsMouse) || osdContainer.childHovered
        if (enableMouseInteraction) {
            if (isHovered) {
                stopHideTimer()
            } else if (shouldBeVisible) {
                resetHideTimer()
            }
        }
    }

    function setChildHovered(hovered) {
        osdContainer.childHovered = hovered
        updateHoverState()
    }

    screen: modelData
    visible: shouldBeVisible
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

    Timer {
        id: hideTimer

        interval: autoHideInterval
        repeat: false
        onTriggered: {
            if (!enableMouseInteraction || !osdContainer.containsMouse) {
                hide()
            } else {
                hideTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
                osdHidden()
            }
        }
    }

    Rectangle {
        id: osdContainer

        property bool containsMouse: enableMouseInteraction && mouseArea.containsMouse
        property bool childHovered: false

        width: osdWidth
        height: osdHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingM
        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9
        layer.enabled: true

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: enableMouseInteraction
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            z: -1

            onContainsMouseChanged: {
                updateHoverState()
            }
        }

        onChildHoveredChanged: {
            root.updateHoverState()
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 0.8
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowOpacity: 0.3
        }

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }
    }

    mask: Region {
        item: osdContainer
    }
}