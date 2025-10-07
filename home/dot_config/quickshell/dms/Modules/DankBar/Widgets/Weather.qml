import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barThickness: 48
    property real widgetThickness: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS

    signal clicked()

    visible: SettingsData.weatherEnabled
    width: isVertical ? widgetThickness : (visible ? Math.min(100, weatherRow.implicitWidth + horizontalPadding * 2) : 0)
    height: isVertical ? (weatherColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = weatherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Ref {
        service: WeatherService
    }

    Column {
        id: weatherColumn
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 1

        DankIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: Theme.barIconSize(barThickness, -6)
            color: Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: {
                const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                if (temp === undefined || temp === null || temp === 0) {
                    return "--";
                }
                return temp;
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Row {
        id: weatherRow

        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: Theme.barIconSize(barThickness, -6)
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                if (temp === undefined || temp === null || temp === 0) {
                    return "--°" + (SettingsData.useFahrenheit ? "F" : "C");
                }

                return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C");
            }
            font.pixelSize: Theme.barTextSize(barThickness)
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
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            root.clicked();
        }
    }


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

}
