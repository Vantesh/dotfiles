import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: weather

    width: parent.width
    height: parent.height
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    layer.enabled: true

    Ref {
        service: WeatherService
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: !WeatherService.weather.available || WeatherService.weather.temp === 0

        DankIcon {
            name: "cloud_off"
            size: Theme.iconSize + 8
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: "No Weather Data"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingS
        visible: WeatherService.weather.available && WeatherService.weather.temp !== 0

        Item {
            width: parent.width
            height: 60

            DankIcon {
                id: refreshButton
                name: "refresh"
                size: Theme.iconSize - 6
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -Theme.spacingS
                anchors.topMargin: -Theme.spacingS

                property bool isRefreshing: false
                enabled: !isRefreshing

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        refreshButton.isRefreshing = true
                        WeatherService.forceRefresh()
                        refreshTimer.restart()
                    }
                    enabled: parent.enabled
                }

                Timer {
                    id: refreshTimer
                    interval: 2000
                    onTriggered: refreshButton.isRefreshing = false
                }

                NumberAnimation on rotation {
                    running: refreshButton.isRefreshing
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingL

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.iconSize + 8
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°" + (SettingsData.useFahrenheit ? "F" : "C")
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                        font.weight: Font.Light

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (WeatherService.weather.available) {
                                    SettingsData.setTemperatureUnit(!SettingsData.useFahrenheit)
                                }
                            }
                            enabled: WeatherService.weather.available
                        }
                    }

                    StyledText {
                        text: WeatherService.weather.city || ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        visible: text.length > 0
                    }
                }
            }
        }

        Grid {
            columns: 2
            spacing: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                spacing: Theme.spacingXS

                DankIcon {
                    name: "humidity_low"
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: WeatherService.weather.humidity ? WeatherService.weather.humidity + "%" : "--"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: Theme.spacingXS

                DankIcon {
                    name: "air"
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: WeatherService.weather.wind || "--"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: Theme.spacingXS

                DankIcon {
                    name: "wb_twilight"
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: WeatherService.weather.sunrise || "--"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: Theme.spacingXS

                DankIcon {
                    name: "bedtime"
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: WeatherService.weather.sunset || "--"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 2
        shadowBlur: 0.5
        shadowColor: Qt.rgba(0, 0, 0, 0.1)
        shadowOpacity: 0.1
    }
}
