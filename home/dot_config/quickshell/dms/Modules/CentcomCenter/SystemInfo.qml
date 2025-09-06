import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    Component.onCompleted: {
        DgopService.addRef(["system", "hardware"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["system", "hardware"])
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
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
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
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                width: parent.width
                elide: Text.ElideRight
            }
        }
    }

    function formatUptime(uptime) {
        if (!uptime) {
            return "0m"
        }

        const uptimeStr = uptime.toString().trim()
        const weekMatch = uptimeStr.match(/(\d+)\s+weeks?/)
        const dayMatch = uptimeStr.match(/(\d+)\s+days?/)

        if (weekMatch) {
            const weeks = parseInt(weekMatch[1])
            let totalDays = weeks * 7
            if (dayMatch) {
                const days = parseInt(dayMatch[1])
                totalDays += days
            }
            return totalDays + "d"
        }

        if (dayMatch) {
            const days = parseInt(dayMatch[1])
            return days + "d"
        }

        const timeMatch = uptimeStr.match(/(\d+):(\d+)/)
        if (timeMatch) {
            const hours = parseInt(timeMatch[1])
            const minutes = parseInt(timeMatch[2])
            return hours > 0 ? hours + "h" : minutes + "m"
        }

        return uptimeStr.length > 8 ? uptimeStr.substring(0, 8) + "…" : uptimeStr
    }
}
