import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property date currentDate: new Date()
    property bool compactMode: false
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null

    signal clockClicked

    width: clockRow.implicitWidth + Theme.spacingS * 2
    height: 30
    radius: Theme.cornerRadius
    color: {
        const baseColor = clockMouseArea.containsMouse ? Theme.primaryHover : Theme.surfaceTextHover;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        root.currentDate = systemClock.date;
    }

    Row {
        id: clockRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        StyledText {
            text: SettingsData.use24HourClock ? Qt.formatTime(root.currentDate, "HH:mm") : Qt.formatTime(root.currentDate, "hh:mm AP")
            font.pixelSize: Theme.fontSizeMedium - 1
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: "•"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
        }

        StyledText {
            text: Qt.formatDate(root.currentDate, SettingsData.clockDateFormat)
            font.pixelSize: Theme.fontSizeMedium - 1
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
        }
    }

    SystemClock {
        id: systemClock

        precision: SystemClock.Seconds
        onDateChanged: root.currentDate = systemClock.date
    }

    MouseArea {
        id: clockMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                var globalPos = mapToGlobal(0, 0);
                var currentScreen = parentScreen || Screen;
                var screenX = currentScreen.x || 0;
                var relativeX = globalPos.x - screenX;
                popupTarget.setTriggerPosition(relativeX, Theme.barHeight + Theme.spacingXS, width, section, currentScreen);
            }
            root.clockClicked();
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
