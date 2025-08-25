import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.CentcomCenter
import qs.Services

PanelWindow {
    id: root

    readonly property bool hasActiveMedia: MprisController.activePlayer !== null
    property bool calendarVisible: false
    property bool shouldBeVisible: false
    property real triggerX: (Screen.width - 480) / 2
    property real triggerY: Theme.barHeight - 4 + SettingsData.topBarSpacing + 4
    property real triggerWidth: 80
    property string triggerSection: "center"
    property var triggerScreen: null

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    visible: calendarVisible || closeTimer.running
    screen: triggerScreen
    onCalendarVisibleChanged: {
        if (calendarVisible) {
            closeTimer.stop()
            shouldBeVisible = true
            visible = true
            Qt.callLater(() => {
                             calendarGrid.loadEventsForMonth()
                         })
        } else {
            shouldBeVisible = false
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.mediumDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
            }
        }
    }
    onVisibleChanged: {
        if (visible && calendarGrid)
            calendarGrid.loadEventsForMonth()
    }
    implicitWidth: 480
    implicitHeight: 600
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: shouldBeVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Rectangle {
        id: mainContainer

        readonly property real targetWidth: Math.min(
                                                (root.screen ? root.screen.width : Screen.width)
                                                * 0.9, 600)

        function calculateWidth() {
            let baseWidth = 320
            if (leftWidgets.hasAnyWidgets)
                return Math.min(parent.width * 0.9, 600)

            return Math.min(parent.width * 0.7, 400)
        }

        function calculateHeight() {
            let contentHeight = Theme.spacingM * 2
            // margins
            let widgetHeight = 160
            widgetHeight += 140 + Theme.spacingM
            let calendarHeight = 300
            let mainRowHeight = Math.max(widgetHeight, calendarHeight)
            contentHeight += mainRowHeight + Theme.spacingM
            if (CalendarService && CalendarService.khalAvailable) {
                let hasEvents = events.selectedDateEvents
                    && events.selectedDateEvents.length > 0
                let eventsHeight = hasEvents ? Math.min(
                                                   300,
                                                   80 + events.selectedDateEvents.length * 60) : 120
                contentHeight += eventsHeight
            } else {
                contentHeight -= Theme.spacingM
            }
            return Math.min(contentHeight, parent.height * 0.9)
        }

        readonly property real calculatedX: {
            var screenWidth = root.screen ? root.screen.width : Screen.width
            if (root.triggerSection === "center") {
                return (screenWidth - targetWidth) / 2
            }

            var centerX = root.triggerX + (root.triggerWidth / 2) - (targetWidth / 2)

            if (centerX >= Theme.spacingM
                    && centerX + targetWidth <= screenWidth - Theme.spacingM) {
                return centerX
            }

            if (centerX < Theme.spacingM) {
                return Theme.spacingM
            }

            if (centerX + targetWidth > screenWidth - Theme.spacingM) {
                return screenWidth - targetWidth - Theme.spacingM
            }

            return centerX
        }

        width: targetWidth
        height: calculateHeight()
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                              Theme.outline.b, 0.08)
        border.width: 1
        layer.enabled: true
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9
        x: calculatedX
        y: root.triggerY
        onOpacityChanged: {
            if (opacity === 1)
                Qt.callLater(() => {
                                 height = calculateHeight()
                             })
        }

        Connections {
            function onEventsByDateChanged() {
                if (mainContainer.opacity === 1)
                    mainContainer.height = mainContainer.calculateHeight()
            }

            function onKhalAvailableChanged() {
                if (mainContainer.opacity === 1)
                    mainContainer.height = mainContainer.calculateHeight()
            }

            target: CalendarService
            enabled: CalendarService !== null
        }

        Connections {
            function onSelectedDateEventsChanged() {
                if (mainContainer.opacity === 1)
                    mainContainer.height = mainContainer.calculateHeight()
            }

            target: events
            enabled: events !== null
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g,
                           Theme.surfaceTint.b, 0.04)
            radius: parent.radius

            SequentialAnimation on opacity {
                running: shouldBeVisible
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.08
                    duration: Theme.extraLongDuration
                    easing.type: Theme.standardEasing
                }

                NumberAnimation {
                    to: 0.02
                    duration: Theme.extraLongDuration
                    easing.type: Theme.standardEasing
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM
            focus: true
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    calendarVisible = false
                    event.accepted = true
                } else {
                    // Don't handle other keys - let them bubble up to modals
                    event.accepted = false
                }
            }

            Row {
                width: parent.width
                height: {
                    let widgetHeight = 160
                    // Media widget
                    widgetHeight += 140 + Theme.spacingM // Weather/SystemInfo widget with spacing
                    let calendarHeight = 300
                    // Calendar
                    return Math.max(widgetHeight, calendarHeight)
                }
                spacing: Theme.spacingM

                Column {
                    id: leftWidgets

                    property bool hasAnyWidgets: true

                    width: hasAnyWidgets ? parent.width
                                           * 0.42 : 0 // Slightly narrower for better proportions
                    height: childrenRect.height
                    spacing: Theme.spacingM
                    visible: hasAnyWidgets
                    anchors.top: parent.top

                    MediaPlayer {
                        width: parent.width
                        height: 160
                    }

                    Weather {
                        width: parent.width
                        height: 140
                        visible: SettingsData.weatherEnabled
                    }

                    SystemInfo {
                        width: parent.width
                        height: 140
                        visible: !SettingsData.weatherEnabled
                    }
                }

                Rectangle {
                    width: leftWidgets.hasAnyWidgets ? parent.width - leftWidgets.width
                                                       - Theme.spacingM : parent.width
                    height: parent.height
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r,
                                   Theme.surfaceVariant.g,
                                   Theme.surfaceVariant.b, 0.2)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.08)
                    border.width: 1

                    CalendarGrid {
                        id: calendarGrid

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                    }
                }
            }

            Events {
                id: events

                width: parent.width
                selectedDate: calendarGrid.selectedDate
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Anims.durMed
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anims.emphasized
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Anims.durMed
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anims.emphasized
            }
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 0.5
            shadowColor: Qt.rgba(0, 0, 0, 0.15)
            shadowOpacity: 0.15
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: shouldBeVisible
        onClicked: function (mouse) {
            var localPos = mapToItem(mainContainer, mouse.x, mouse.y)
            if (localPos.x < 0 || localPos.x > mainContainer.width
                    || localPos.y < 0 || localPos.y > mainContainer.height)
                calendarVisible = false
        }
    }
}
