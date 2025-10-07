pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    property bool hasUwsm: false
    property bool isElogind: false
    property bool hibernateSupported: false
    property bool inhibitorAvailable: true
    property bool idleInhibited: false
    property string inhibitReason: "Keep system awake"
    property bool hasPrimeRun: false

    readonly property bool nativeInhibitorAvailable: {
        try {
            return typeof IdleInhibitor !== "undefined"
        } catch (e) {
            return false
        }
    }

    Component.onCompleted: {
        detectElogindProcess.running = true
        detectHibernateProcess.running = true
        detectPrimeRunProcess.running = true
        console.log("SessionService: Native inhibitor available:", nativeInhibitorAvailable)
    }


    Process {
        id: detectUwsmProcess
        running: false
        command: ["which", "uwsm"]

        onExited: function (exitCode) {
            hasUwsm = (exitCode === 0)
        }
    }

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -E '^(elogind|elogind-daemon)$'"]

        onExited: function (exitCode) {
            console.log("SessionService: Elogind detection exited with code", exitCode)
            isElogind = (exitCode === 0)
        }
    }

    Process {
        id: detectHibernateProcess
        running: false
        command: ["grep", "-q", "disk", "/sys/power/state"]

        onExited: function (exitCode) {
            hibernateSupported = (exitCode === 0)
        }
    }

    Process {
        id: detectPrimeRunProcess
        running: false
        command: ["which", "prime-run"]

        onExited: function (exitCode) {
            hasPrimeRun = (exitCode === 0)
        }
    }

    Process {
        id: uwsmLogout
        command: ["uwsm", "stop"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().toLowerCase().includes("not running")) {
                    _logout()
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                return
            }
            _logout()
        }
    }

    // * Apps
    function launchDesktopEntry(desktopEntry, usePrimeRun) {
        let cmd = desktopEntry.command
        if (usePrimeRun && hasPrimeRun) {
            cmd = ["prime-run"].concat(cmd)
        }
        if (SessionData.launchPrefix && SessionData.launchPrefix.length > 0) {
            const launchPrefix = SessionData.launchPrefix.trim().split(" ")
            cmd = launchPrefix.concat(cmd)
        }

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: desktopEntry.workingDirectory || Quickshell.env("HOME"),
        });
    }

    function launchDesktopAction(desktopEntry, action, usePrimeRun) {
        let cmd = action.command
        if (usePrimeRun && hasPrimeRun) {
            cmd = ["prime-run"].concat(cmd)
        }
        if (SessionData.launchPrefix && SessionData.launchPrefix.length > 0) {
            const launchPrefix = SessionData.launchPrefix.trim().split(" ")
            cmd = launchPrefix.concat(cmd)
        }

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: desktopEntry.workingDirectory || Quickshell.env("HOME"),
        });
    }

    // * Session management
    function logout() {
        if (hasUwsm) {
            uwsmLogout.running = true
        }
        _logout()
    }

    function _logout() {
        if (CompositorService.isNiri) {
            NiriService.quit()
            return
        }

        // Hyprland fallback
        Hyprland.dispatch("exit")
    }

    function suspend() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"])
    }

    function hibernate() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "hibernate"])
    }

    function reboot() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"])
    }

    function poweroff() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"])
    }

    // * Idle Inhibitor
    signal inhibitorChanged

    function enableIdleInhibit() {
        if (idleInhibited) {
            return
        }
        console.log("SessionService: Enabling idle inhibit (native:", nativeInhibitorAvailable, ")")
        idleInhibited = true
        inhibitorChanged()
    }

    function disableIdleInhibit() {
        if (!idleInhibited) {
            return
        }
        console.log("SessionService: Disabling idle inhibit (native:", nativeInhibitorAvailable, ")")
        idleInhibited = false
        inhibitorChanged()
    }

    function toggleIdleInhibit() {
        if (idleInhibited) {
            disableIdleInhibit()
        } else {
            enableIdleInhibit()
        }
    }

    function setInhibitReason(reason) {
        inhibitReason = reason

        if (idleInhibited && !nativeInhibitorAvailable) {
            const wasActive = idleInhibited
            idleInhibited = false

            Qt.callLater(() => {
                             if (wasActive) {
                                 idleInhibited = true
                             }
                         })
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited || nativeInhibitorAvailable) {
                return ["true"]
            }

            console.log("SessionService: Starting systemd/elogind inhibit process")
            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", `--why=${inhibitReason}`, "--mode=block", "sleep", "infinity"]
        }

        running: idleInhibited && !nativeInhibitorAvailable

        onRunningChanged: {
            console.log("SessionService: Inhibit process running:", running, "(native:", nativeInhibitorAvailable, ")")
        }

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0 && !nativeInhibitorAvailable) {
                console.warn("SessionService: Inhibitor process crashed with exit code:", exitCode)
                idleInhibited = false
                ToastService.showWarning("Idle inhibitor failed")
            }
        }
    }

}
