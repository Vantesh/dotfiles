import QtQuick
import Quickshell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property var controlCenterPopout: null
    property var notificationCenterPopout: null
    property var appDrawerPopout: null
    property var processListPopout: null
    property var dankDashPopout: null
    property var batteryPopout: null
    property var vpnPopout: null
    property var systemUpdatePopout: null

    property var settingsModal: null
    property var clipboardHistoryModal: null
    property var spotlightModal: null
    property var powerMenuModal: null
    property var processListModal: null
    property var colorPickerModal: null
    property var notificationModal: null
    property var wifiPasswordModal: null
    property var networkInfoModal: null

    property var notepadSlideouts: []

    function setPosition(popout, x, y, width, section, screen) {
        if (popout && popout.setTriggerPosition && arguments.length >= 6) {
            popout.setTriggerPosition(x, y, width, section, screen)
        }
    }

    function openControlCenter(x, y, width, section, screen) {
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen)
            controlCenterPopout.open()
        }
    }

    function closeControlCenter() {
        controlCenterPopout?.close()
    }

    function toggleControlCenter(x, y, width, section, screen) {
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen)
            controlCenterPopout.toggle()
        }
    }

    function openNotificationCenter(x, y, width, section, screen) {
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen)
            notificationCenterPopout.open()
        }
    }

    function closeNotificationCenter() {
        notificationCenterPopout?.close()
    }

    function toggleNotificationCenter(x, y, width, section, screen) {
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen)
            notificationCenterPopout.toggle()
        }
    }

    function openAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen)
            appDrawerPopout.open()
        }
    }

    function closeAppDrawer() {
        appDrawerPopout?.close()
    }

    function toggleAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen)
            appDrawerPopout.toggle()
        }
    }

    function openProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen)
            processListPopout.open()
        }
    }

    function closeProcessList() {
        processListPopout?.close()
    }

    function toggleProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen)
            processListPopout.toggle()
        }
    }

    function openDankDash(tabIndex, x, y, width, section, screen) {
        if (dankDashPopout) {
            if (arguments.length >= 6) {
                setPosition(dankDashPopout, x, y, width, section, screen)
            }
            dankDashPopout.currentTabIndex = tabIndex || 0
            dankDashPopout.dashVisible = true
        }
    }

    function closeDankDash() {
        if (dankDashPopout) {
            dankDashPopout.dashVisible = false
        }
    }

    function toggleDankDash(tabIndex, x, y, width, section, screen) {
        if (dankDashPopout) {
            if (arguments.length >= 6) {
                setPosition(dankDashPopout, x, y, width, section, screen)
            }
            if (dankDashPopout.dashVisible) {
                dankDashPopout.dashVisible = false
            } else {
                dankDashPopout.currentTabIndex = tabIndex || 0
                dankDashPopout.dashVisible = true
            }
        }
    }

    function openBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen)
            batteryPopout.open()
        }
    }

    function closeBattery() {
        batteryPopout?.close()
    }

    function toggleBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen)
            batteryPopout.toggle()
        }
    }

    function openVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen)
            vpnPopout.open()
        }
    }

    function closeVpn() {
        vpnPopout?.close()
    }

    function toggleVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen)
            vpnPopout.toggle()
        }
    }

    function openSystemUpdate(x, y, width, section, screen) {
        if (systemUpdatePopout) {
            setPosition(systemUpdatePopout, x, y, width, section, screen)
            systemUpdatePopout.open()
        }
    }

    function closeSystemUpdate() {
        systemUpdatePopout?.close()
    }

    function toggleSystemUpdate(x, y, width, section, screen) {
        if (systemUpdatePopout) {
            setPosition(systemUpdatePopout, x, y, width, section, screen)
            systemUpdatePopout.toggle()
        }
    }

    function openSettings() {
        settingsModal?.show()
    }

    function closeSettings() {
        settingsModal?.close()
    }

    function openClipboardHistory() {
        clipboardHistoryModal?.show()
    }

    function closeClipboardHistory() {
        clipboardHistoryModal?.close()
    }

    function openSpotlight() {
        spotlightModal?.show()
    }

    function closeSpotlight() {
        spotlightModal?.close()
    }

    function openPowerMenu() {
        powerMenuModal?.openCentered()
    }

    function closePowerMenu() {
        powerMenuModal?.close()
    }

    function togglePowerMenu() {
        if (powerMenuModal) {
            if (powerMenuModal.shouldBeVisible) {
                powerMenuModal.close()
            } else {
                powerMenuModal.openCentered()
            }
        }
    }

    function showProcessListModal() {
        processListModal?.show()
    }

    function hideProcessListModal() {
        processListModal?.hide()
    }

    function toggleProcessListModal() {
        processListModal?.toggle()
    }

    function showColorPicker() {
        colorPickerModal?.show()
    }

    function hideColorPicker() {
        colorPickerModal?.close()
    }

    function showNotificationModal() {
        notificationModal?.show()
    }

    function hideNotificationModal() {
        notificationModal?.close()
    }

    function showWifiPasswordModal() {
        wifiPasswordModal?.show()
    }

    function hideWifiPasswordModal() {
        wifiPasswordModal?.close()
    }

    function showNetworkInfoModal() {
        networkInfoModal?.show()
    }

    function hideNetworkInfoModal() {
        networkInfoModal?.close()
    }

    function openNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.show()
        }
    }

    function closeNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.hide()
        }
    }

    function toggleNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.toggle()
        }
    }
}
