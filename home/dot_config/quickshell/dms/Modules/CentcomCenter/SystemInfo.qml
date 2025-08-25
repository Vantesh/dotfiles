import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                   Theme.surfaceContainer.b, 0.4)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                          Theme.outline.b, 0.08)
    border.width: 1

    Ref {
        service: DgopService
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingM

            SystemLogo {
                width: 48
                height: 48
            }

            Column {
                width: parent.width - 48 - Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                StyledText {
                    text: DgopService.hostname
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                }

                StyledText {
                    text: DgopService.distribution + " • " + DgopService.architecture
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                                   Theme.surfaceText.b, 0.7)
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                           Theme.outline.b, 0.1)
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: "Uptime " + formatUptime(UserInfoService.uptime)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                width: parent.width
                elide: Text.ElideRight
            }

            StyledText {
                text: "Load: " + DgopService.loadAverage
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                width: parent.width
                elide: Text.ElideRight
            }

            StyledText {
                text: DgopService.processCount + " proc, " + DgopService.threadCount + " threads"
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                               Theme.surfaceText.b, 0.8)
                width: parent.width
                elide: Text.ElideRight
            }
        }
    }

    function formatUptime(uptime) {
        if (!uptime)
            return "0m"

        // Parse the uptime string - handle formats like "1 week, 4 days, 3:45" or "4 days, 3:45" or "3:45"
        var uptimeStr = uptime.toString().trim()

        // Check for weeks and days - need to add them together
        var weekMatch = uptimeStr.match(/(\d+)\s+weeks?/)
        var dayMatch = uptimeStr.match(/(\d+)\s+days?/)

        if (weekMatch) {
            var weeks = parseInt(weekMatch[1])
            var totalDays = weeks * 7
            if (dayMatch) {
                var days = parseInt(dayMatch[1])
                totalDays += days
            }
            return totalDays + "d"
        } else if (dayMatch) {
            var days = parseInt(dayMatch[1])
            return days + "d"
        }

        // If it's just hours:minutes, show the largest unit
        var timeMatch = uptimeStr.match(/(\d+):(\d+)/)
        if (timeMatch) {
            var hours = parseInt(timeMatch[1])
            var minutes = parseInt(timeMatch[2])
            if (hours > 0) {
                return hours + "h"
            } else {
                return minutes + "m"
            }
        }

        // Fallback - return as is but truncated
        return uptimeStr.length > 8 ? uptimeStr.substring(0,
                                                          8) + "…" : uptimeStr
    }
}
