pragma Singleton

pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool accountsServiceAvailable: false
    property string systemProfileImage: ""
    property string profileImage: ""
    property bool settingsPortalAvailable: false
    property int systemColorScheme: 0 // 0=default, 1=prefer-dark, 2=prefer-light

    function getSystemProfileImage() {
        systemProfileCheckProcess.running = true
    }

    function setProfileImage(imagePath) {
        profileImage = imagePath
        if (accountsServiceAvailable && imagePath) {
            setSystemProfileImage(imagePath)
        }
    }

    function getSystemColorScheme() {
        systemColorSchemeCheckProcess.running = true
    }

    function setLightMode(isLightMode) {
        if (settingsPortalAvailable) {
            setSystemColorScheme(isLightMode)
        }
    }

    function setSystemColorScheme(isLightMode) {
        if (!settingsPortalAvailable)
            return

        var colorScheme = isLightMode ? "prefer-light" : "prefer-dark"
        var script = "gsettings set org.gnome.desktop.interface color-scheme '" + colorScheme + "'"

        systemColorSchemeSetProcess.command = ["bash", "-c", script]
        systemColorSchemeSetProcess.running = true
    }

    function setSystemProfileImage(imagePath) {
        if (!accountsServiceAvailable || !imagePath)
            return

        var script = ["dbus-send --system --print-reply --dest=org.freedesktop.Accounts", "/org/freedesktop/Accounts/User$(id -u)", "org.freedesktop.Accounts.User.SetIconFile", "string:'" + imagePath + "'"].join(
                    " ")

        systemProfileSetProcess.command = ["bash", "-c", script]
        systemProfileSetProcess.running = true
    }

    Component.onCompleted: {
        checkAccountsService()
        checkSettingsPortal()
    }

    function checkAccountsService() {
        accountsServiceCheckProcess.running = true
    }

    function checkSettingsPortal() {
        settingsPortalCheckProcess.running = true
    }

    Process {
        id: accountsServiceCheckProcess
        command: ["bash", "-c", "dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName string:\"$USER\""]
        running: false

        onExited: exitCode => {
            root.accountsServiceAvailable = (exitCode === 0)
            if (root.accountsServiceAvailable) {
                root.getSystemProfileImage()
            }
        }
    }

    Process {
        id: systemProfileCheckProcess
        command: ["bash", "-c", "dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var match = text.match(/string\s+"([^"]+)"/)
                if (match && match[1] && match[1] !== ""
                    && match[1] !== "/var/lib/AccountsService/icons/") {
                    root.systemProfileImage = match[1]

                    if (!root.profileImage || root.profileImage === "") {
                        root.profileImage = root.systemProfileImage
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.systemProfileImage = ""
            }
        }
    }

    Process {
        id: systemProfileSetProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                root.getSystemProfileImage()
            }
        }
    }

    Process {
        id: settingsPortalCheckProcess
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop", "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        running: false

        onExited: exitCode => {
            root.settingsPortalAvailable = (exitCode === 0)
            if (root.settingsPortalAvailable) {
                root.getSystemColorScheme()
            }
        }
    }

    Process {
        id: systemColorSchemeCheckProcess
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop", "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var match = text.match(/uint32 (\d+)/)
                if (match && match[1]) {
                    root.systemColorScheme = parseInt(match[1])

                    if (typeof Theme !== "undefined") {
                        var shouldBeLightMode = (root.systemColorScheme === 2)
                        if (Theme.isLightMode !== shouldBeLightMode) {
                            Theme.isLightMode = shouldBeLightMode
                            if (typeof SessionData !== "undefined") {
                                SessionData.setLightMode(shouldBeLightMode)
                            }
                        }
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.systemColorScheme = 0
            }
        }
    }

    Process {
        id: systemColorSchemeSetProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                                 root.getSystemColorScheme()
                             })
            }
        }
    }
}
