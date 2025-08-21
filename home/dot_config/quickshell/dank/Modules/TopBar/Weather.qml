import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null

    signal clicked

    visible: SettingsData.weatherEnabled
    width: visible ? Math.min(100,
                              weatherRow.implicitWidth + Theme.spacingS * 2) : 0
    height: 30
    radius: Theme.cornerRadius
    color: {
        const baseColor = weatherArea.containsMouse ? Theme.primaryHover : Theme.surfaceTextHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }

    Ref {
        service: WeatherService
    }

    Row {
        id: weatherRow

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: Theme.iconSize - 4
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                var temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp
                if (temp === undefined || temp === null || temp === 0) {
                    return "--°" + (SettingsData.useFahrenheit ? "F" : "C")
                }
                return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C")
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: weatherArea

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
            root.clicked()
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
