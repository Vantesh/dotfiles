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
        const baseColor = ramArea.containsMouse ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    Component.onCompleted: {
        DgopService.addRef(["memory"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["memory"])
    }

    MouseArea {
        id: ramArea

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
            DgopService.setSortBy("memory")
            if (root.toggleProcessList)
                root.toggleProcessList()
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "developer_board"
            size: Theme.iconSize - 8
            color: {
                if (DgopService.memoryUsage > 90)
                    return Theme.tempDanger

                if (DgopService.memoryUsage > 75)
                    return Theme.tempWarning

                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (DgopService.memoryUsage === undefined
                        || DgopService.memoryUsage === null
                        || DgopService.memoryUsage === 0) {
                    return "--%"
                }
                return DgopService.memoryUsage.toFixed(0) + "%"
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
