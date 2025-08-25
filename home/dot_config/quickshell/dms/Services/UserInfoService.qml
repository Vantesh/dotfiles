pragma Singleton

pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string username: ""
    property string fullName: ""
    property string profilePicture: ""
    property string uptime: ""
    property string hostname: ""
    property bool profileAvailable: false

    function getUserInfo() {
        userInfoProcess.running = true
    }

    function getUptime() {
        uptimeProcess.running = true
    }

    function refreshUserInfo() {
        getUserInfo()
        getUptime()
    }

    Component.onCompleted: {
        getUserInfo()
        getUptime()
    }

    // Get username and full name
    Process {
        id: userInfoProcess

        command: ["bash", "-c", "echo \"$USER|$(getent passwd $USER | cut -d: -f5 | cut -d, -f1)|$(hostname)\""]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {

                root.username = "User"
                root.fullName = "User"
                root.hostname = "System"
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                if (parts.length >= 3) {
                    root.username = parts[0] || ""
                    root.fullName = parts[1] || parts[0] || ""
                    root.hostname = parts[2] || ""
                }
            }
        }
    }

    // Get system uptime
    Process {
        id: uptimeProcess

        command: ["cat", "/proc/uptime"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.uptime = "Unknown"
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = parseInt(text.split(" ")[0])
                const days = Math.floor(seconds / 86400)
                const hours = Math.floor((seconds % 86400) / 3600)
                const minutes = Math.floor((seconds % 3600) / 60)

                const parts = []
                if (days > 0)
                parts.push(`${days} day${days === 1 ? "" : "s"}`)
                if (hours > 0)
                parts.push(`${hours} hour${hours === 1 ? "" : "s"}`)
                if (minutes > 0)
                parts.push(`${minutes} minute${minutes === 1 ? "" : "s"}`)

                if (parts.length > 0)
                root.uptime = "up " + parts.join(", ")
                else
                root.uptime = `up ${seconds} seconds`
            }
        }
    }
}
