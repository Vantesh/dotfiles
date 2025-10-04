pragma Singleton

pragma ComponentBehavior: Bound

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

    function init() {}

    function getSystemProfileImage() {
        systemProfileCheckProcess.running = true
    }

    function getUserProfileImage(username) {
        if (!username) {
            profileImage = ""
            return
        }
        if (Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true") {
            profileImage = ""
            return
        }
        userProfileCheckProcess.command = [
            "bash", "-c",
            `uid=$(id -u ${username} 2>/dev/null) && [ -n "$uid" ] && dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$uid org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile 2>/dev/null | grep -oP 'string "\\K[^"]+' || echo ""`
        ]
        userProfileCheckProcess.running = true
    }

    function getGreeterUserProfileImage(username) {
        if (!username) {
            profileImage = ""
            return
        }
        userProfileCheckProcess.command = [
            "bash", "-c",
            `uid=$(id -u ${username} 2>/dev/null) && [ -n "$uid" ] && dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$uid org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile 2>/dev/null | grep -oP 'string "\\K[^"]+' || echo ""`
        ]
        userProfileCheckProcess.running = true
    }

    function setProfileImage(imagePath) {
        profileImage = imagePath
        if (accountsServiceAvailable) {
            if (imagePath) {
                setSystemProfileImage(imagePath)
            } else {
                setSystemProfileImage("")
            }
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
        if (!settingsPortalAvailable) {
            return
        }

        const colorScheme = isLightMode ? "default" : "prefer-dark"
        const script = `gsettings set org.gnome.desktop.interface color-scheme '${colorScheme}'`

        systemColorSchemeSetProcess.command = ["bash", "-c", script]
        systemColorSchemeSetProcess.running = true
    }

    function setSystemProfileImage(imagePath) {
        if (!accountsServiceAvailable) {
            return
        }

        const path = imagePath || ""
        const script = `dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:'${path}'`

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
                const match = text.match(/string\s+"([^"]+)"/)
                if (match && match[1] && match[1] !== "" && match[1] !== "/var/lib/AccountsService/icons/") {
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
        id: userProfileCheckProcess
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim()
                if (trimmed && trimmed !== "" && !trimmed.includes("Error") && trimmed !== "/var/lib/AccountsService/icons/") {
                    root.profileImage = trimmed
                } else {
                    root.profileImage = ""
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.profileImage = ""
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
                const match = text.match(/uint32 (\d+)/)
                if (match && match[1]) {
                    root.systemColorScheme = parseInt(match[1])

                    if (typeof Theme !== "undefined") {
                        const shouldBeLightMode = (root.systemColorScheme === 2)
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

    IpcHandler {
        target: "profile"

        function getImage(): string {
            return root.profileImage
        }

        function setImage(path: string): string {
            if (!path) {
                return "ERROR: No path provided"
            }

            const absolutePath = path.startsWith("/") ? path : `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/${path}`

            try {
                root.setProfileImage(absolutePath)
                return "SUCCESS: Profile image set to " + absolutePath
            } catch (e) {
                return "ERROR: Failed to set profile image: " + e.toString()
            }
        }

        function clearImage(): string {
            root.setProfileImage("")
            return "SUCCESS: Profile image cleared"
        }
    }
}
