import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: weatherTab

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            // Enable Weather
            StyledRect {
                width: parent.width
                height: enableWeatherSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: enableWeatherSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "cloud"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - enableToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Enable Weather"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Show weather information in top bar and control center"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: enableToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.weatherEnabled
                            onToggled: checked => {
                                           return SettingsData.setWeatherEnabled(
                                               checked)
                                       }
                        }
                    }
                }
            }

            // Temperature Unit
            StyledRect {
                width: parent.width
                height: temperatureSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: temperatureSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "thermostat"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - temperatureToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Use Fahrenheit"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Use Fahrenheit instead of Celsius for temperature"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: temperatureToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.useFahrenheit
                            onToggled: checked => {
                                           return SettingsData.setTemperatureUnit(
                                               checked)
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
            }

            // Location Settings
            StyledRect {
                width: parent.width
                height: locationSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: locationSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "location_on"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - autoLocationToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Auto Location"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Automatically determine your location using your IP address"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: autoLocationToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.useAutoLocation
                            onToggled: checked => {
                                           return SettingsData.setAutoLocation(
                                               checked)
                                       }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: !SettingsData.useAutoLocation

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        StyledText {
                            text: "Custom Location"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankTextField {
                                id: latitudeInput
                                width: (parent.width - Theme.spacingM) / 2
                                height: 48
                                placeholderText: "Latitude"
                                text: SettingsData.weatherCoordinates ? SettingsData.weatherCoordinates.split(',')[0] : ""
                                backgroundColor: Theme.surfaceVariant
                                normalBorderColor: Theme.primarySelected
                                focusedBorderColor: Theme.primary
                                onTextEdited: {
                                    if (text && longitudeInput.text) {
                                        const coords = text + "," + longitudeInput.text
                                        const displayName = `${text}, ${longitudeInput.text}`
                                        SettingsData.setWeatherLocation(displayName, coords)
                                    }
                                }
                            }

                            DankTextField {
                                id: longitudeInput
                                width: (parent.width - Theme.spacingM) / 2
                                height: 48
                                placeholderText: "Longitude"
                                text: SettingsData.weatherCoordinates ? SettingsData.weatherCoordinates.split(',')[1] : ""
                                backgroundColor: Theme.surfaceVariant
                                normalBorderColor: Theme.primarySelected
                                focusedBorderColor: Theme.primary
                                onTextEdited: {
                                    if (text && latitudeInput.text) {
                                        const coords = latitudeInput.text + "," + text
                                        const displayName = `${latitudeInput.text}, ${text}`
                                        SettingsData.setWeatherLocation(displayName, coords)
                                    }
                                }
                            }
                        }

                        DankLocationSearch {
                            width: parent.width
                            currentLocation: SettingsData.weatherLocation
                            placeholderText: "New York, NY"
                            onLocationSelected: (displayName, coordinates) => {
                                                    SettingsData.setWeatherLocation(
                                                        displayName,
                                                        coordinates)
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
            }
        }
    }
}
