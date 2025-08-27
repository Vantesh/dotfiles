pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int levelInfo: 0
    readonly property int levelWarn: 1
    readonly property int levelError: 2
    property string currentMessage: ""
    property int currentLevel: levelInfo
    property bool toastVisible: false
    property var toastQueue: []
    property string currentDetails: ""
    property bool hasDetails: false
    property string wallpaperErrorStatus: ""

    function showToast(message, level = levelInfo, details = "") {
        toastQueue.push({
                            "message": message,
                            "level": level,
                            "details": details
                        })
        if (!toastVisible)
            processQueue()
    }

    function showInfo(message, details = "") {
        showToast(message, levelInfo, details)
    }

    function showWarning(message, details = "") {
        showToast(message, levelWarn, details)
    }

    function showError(message, details = "") {
        showToast(message, levelError, details)
    }

    function hideToast() {
        toastVisible = false
        currentMessage = ""
        currentDetails = ""
        hasDetails = false
        currentLevel = levelInfo
        toastTimer.stop()
        resetToastState()
        if (toastQueue.length > 0)
            processQueue()
    }

    function processQueue() {
        if (toastQueue.length === 0)
            return

        const toast = toastQueue.shift()
        currentMessage = toast.message
        currentLevel = toast.level
        currentDetails = toast.details || ""
        hasDetails = currentDetails.length > 0
        toastVisible = true
        resetToastState()

        if (toast.level === levelError && hasDetails) {
            toastTimer.interval = 8000
            toastTimer.start()
        } else {
            toastTimer.interval = toast.level
                    === levelError ? 5000 : toast.level === levelWarn ? 4000 : 3000
            toastTimer.start()
        }
    }

    signal resetToastState

    function stopTimer() {
        toastTimer.stop()
    }

    function restartTimer() {
        if (hasDetails && currentLevel === levelError) {
            toastTimer.interval = 8000
            toastTimer.restart()
        }
    }

    function clearWallpaperError() {
        wallpaperErrorStatus = ""
    }

    Timer {
        id: toastTimer

        interval: 5000
        running: false
        repeat: false
        onTriggered: hideToast()
    }
}
