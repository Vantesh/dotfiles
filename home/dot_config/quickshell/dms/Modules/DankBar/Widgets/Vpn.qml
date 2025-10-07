import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property int widgetThickness: 28
    property int barThickness: 32
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal toggleVpnPopup()

    width: isVertical ? widgetThickness : (Theme.iconSize + horizontalPadding * 2)
    height: isVertical ? (Theme.iconSize + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = clickArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    DankIcon {
        id: icon

        name: VpnService.isBusy ? "sync" : (VpnService.connected ? "vpn_lock" : "vpn_key_off")
        size: Theme.barIconSize(barThickness, -4)
        color: VpnService.connected ? Theme.primary : Theme.surfaceText
        anchors.centerIn: parent
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    MouseArea {
        id: clickArea

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
            root.toggleVpnPopup();
        }
        onEntered: {
            if (root.parentScreen && !(popupTarget && popupTarget.shouldBeVisible)) {
                tooltipLoader.active = true
                if (tooltipLoader.item) {
                    let tooltipText = ""
                    if (!VpnService.connected) {
                        tooltipText = "VPN Disconnected"
                    } else {
                        const names = VpnService.activeNames || []
                        if (names.length <= 1) {
                            tooltipText = "VPN Connected • " + (names[0] || "")
                        } else {
                            tooltipText = "VPN Connected • " + names[0] + " +" + (names.length - 1)
                        }
                    }

                    if (root.isVertical) {
                        const globalPos = mapToGlobal(width / 2, height / 2)
                        const screenX = root.parentScreen ? root.parentScreen.x : 0
                        const screenY = root.parentScreen ? root.parentScreen.y : 0
                        const relativeY = globalPos.y - screenY
                        const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (root.parentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                        const isLeft = root.axis?.edge === "left"
                        tooltipLoader.item.show(tooltipText, screenX + tooltipX, relativeY, root.parentScreen, isLeft, !isLeft)
                    } else {
                        const globalPos = mapToGlobal(width / 2, height)
                        const tooltipY = Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS
                        tooltipLoader.item.show(tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false)
                    }
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

}
