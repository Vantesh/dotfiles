import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property var widgetData: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property string mountPath: (widgetData && widgetData.mountPath !== undefined) ? widgetData.mountPath : "/"
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null
        }

        // Force re-evaluation when mountPath changes
        const currentMountPath = root.mountPath || "/"

        // First try to find exact match
        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === currentMountPath) {
                return DgopService.diskMounts[i]
            }
        }

        // Fallback to root
        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === "/") {
                return DgopService.diskMounts[i]
            }
        }

        // Last resort - first mount
        return DgopService.diskMounts[0] || null
    }

    property real diskUsagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0
        }
        const percentStr = selectedMount.percent.replace("%", "")
        return parseFloat(percentStr) || 0
    }

    width: isVertical ? widgetThickness : (diskContent.implicitWidth + horizontalPadding * 2)
    height: isVertical ? (diskColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent"
        }

        const baseColor = Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    Component.onCompleted: {
        DgopService.addRef(["diskmounts"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"])
    }

    Connections {
        function onWidgetDataChanged() {
            // Force property re-evaluation by triggering change detection
            root.mountPath = Qt.binding(() => {
                return (root.widgetData && root.widgetData.mountPath !== undefined) ? root.widgetData.mountPath : "/"
            })

            root.selectedMount = Qt.binding(() => {
                if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                    return null
                }

                const currentMountPath = root.mountPath || "/"

                // First try to find exact match
                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === currentMountPath) {
                        return DgopService.diskMounts[i]
                    }
                }

                // Fallback to root
                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === "/") {
                        return DgopService.diskMounts[i]
                    }
                }

                // Last resort - first mount
                return DgopService.diskMounts[0] || null
            })
        }

        target: SettingsData
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    MouseArea {
        id: diskArea
        anchors.fill: parent
        hoverEnabled: root.isVertical
        onEntered: {
            if (root.isVertical && root.selectedMount) {
                tooltipLoader.active = true
                if (tooltipLoader.item) {
                    const globalPos = mapToGlobal(width / 2, height / 2)
                    const currentScreen = root.parentScreen || Screen
                    const screenX = currentScreen ? currentScreen.x : 0
                    const screenY = currentScreen ? currentScreen.y : 0
                    const relativeY = globalPos.y - screenY
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                    const isLeft = root.axis?.edge === "left"
                    tooltipLoader.item.show(root.selectedMount.mount, screenX + tooltipX, relativeY, currentScreen, isLeft, !isLeft)
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide()
            }
            tooltipLoader.active = false
        }
    }

    Column {
        id: diskColumn
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 1

        DankIcon {
            name: "storage"
            size: Theme.barIconSize(barThickness)
            color: {
                if (root.diskUsagePercent > 90) {
                    return Theme.tempDanger
                }
                if (root.diskUsagePercent > 75) {
                    return Theme.tempWarning
                }
                return Theme.surfaceText
            }
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: {
                if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                    return "--"
                }
                return root.diskUsagePercent.toFixed(0)
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Row {
        id: diskContent
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "storage"
            size: Theme.barIconSize(barThickness)
            color: {
                if (root.diskUsagePercent > 90) {
                    return Theme.tempDanger
                }
                if (root.diskUsagePercent > 75) {
                    return Theme.tempWarning
                }
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (!root.selectedMount) {
                    return "--"
                }
                return root.selectedMount.mount
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone
        }

        StyledText {
            text: {
                if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                    return "--%"
                }
                return root.diskUsagePercent.toFixed(0) + "%"
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone

            StyledTextMetrics {
                id: diskBaseline
                font.pixelSize: Theme.barTextSize(barThickness)
                font.weight: Font.Medium
                text: "100%"
            }

            width: Math.max(diskBaseline.width, paintedWidth)

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}