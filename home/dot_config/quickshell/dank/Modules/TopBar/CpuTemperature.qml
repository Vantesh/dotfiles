import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null

    width: 55
    height: 30
    radius: Theme.cornerRadius
    color: {
        const baseColor = cpuTempArea.containsMouse ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    Component.onCompleted: {
        DgopService.addRef(["cpu"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"])
    }

    MouseArea {
        id: cpuTempArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                var globalPos = mapToGlobal(0, 0)
                var currentScreen = parentScreen || Screen
                var screenX = currentScreen.x || 0
                var relativeX = globalPos.x - screenX
                popupTarget.setTriggerPosition(
                            relativeX, Theme.barHeight + Theme.spacingXS,
                            width, section, currentScreen)
            }
            DgopService.setSortBy("cpu")
            if (root.toggleProcessList)
                root.toggleProcessList()
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "memory"
            size: Theme.iconSize - 8
            color: {
                if (DgopService.cpuTemperature > 85)
                    return Theme.tempDanger

                if (DgopService.cpuTemperature > 69)
                    return Theme.tempWarning

                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (DgopService.cpuTemperature === undefined
                        || DgopService.cpuTemperature === null
                        || DgopService.cpuTemperature < 0) {
                    return "--°"
                }
                return Math.round(DgopService.cpuTemperature) + "°"
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
