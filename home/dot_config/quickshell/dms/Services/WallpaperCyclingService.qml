pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool cyclingActive: false
    property string cachedCyclingTime: SessionData.wallpaperCyclingTime
    property int cachedCyclingInterval: SessionData.wallpaperCyclingInterval
    property string lastTimeCheck: ""

    Component.onCompleted: {
        updateCyclingState()
    }

    Connections {
        target: SessionData

        function onWallpaperCyclingEnabledChanged() {
            updateCyclingState()
        }

        function onWallpaperCyclingModeChanged() {
            updateCyclingState()
        }

        function onWallpaperCyclingIntervalChanged() {
            cachedCyclingInterval = SessionData.wallpaperCyclingInterval
            if (SessionData.wallpaperCyclingMode === "interval") {
                updateCyclingState()
            }
        }

        function onWallpaperCyclingTimeChanged() {
            cachedCyclingTime = SessionData.wallpaperCyclingTime
            if (SessionData.wallpaperCyclingMode === "time") {
                updateCyclingState()
            }
        }

        function onPerMonitorWallpaperChanged() {
            updateCyclingState()
        }
    }

    function updateCyclingState() {
        if (SessionData.wallpaperCyclingEnabled && SessionData.wallpaperPath && !SessionData.perMonitorWallpaper) {
            startCycling()
        } else {
            stopCycling()
        }
    }

    function startCycling() {
        if (SessionData.wallpaperCyclingMode === "interval") {
            intervalTimer.interval = cachedCyclingInterval * 1000
            intervalTimer.start()
            cyclingActive = true
        } else if (SessionData.wallpaperCyclingMode === "time") {
            cyclingActive = true
            checkTimeBasedCycling()
        }
    }

    function stopCycling() {
        intervalTimer.stop()
        cyclingActive = false
    }

    function cycleToNextWallpaper(screenName, wallpaperPath) {
        const currentWallpaper = wallpaperPath || SessionData.wallpaperPath
        if (!currentWallpaper) return

        const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
        cyclingProcess.command = ["sh", "-c", `ls -1 "${wallpaperDir}"/*.jpg "${wallpaperDir}"/*.jpeg "${wallpaperDir}"/*.png "${wallpaperDir}"/*.bmp "${wallpaperDir}"/*.gif "${wallpaperDir}"/*.webp 2>/dev/null | sort`]
        cyclingProcess.targetScreenName = screenName || ""
        cyclingProcess.currentWallpaper = currentWallpaper
        cyclingProcess.running = true
    }

    function cycleToPrevWallpaper(screenName, wallpaperPath) {
        const currentWallpaper = wallpaperPath || SessionData.wallpaperPath
        if (!currentWallpaper) return

        const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
        prevCyclingProcess.command = ["sh", "-c", `ls -1 "${wallpaperDir}"/*.jpg "${wallpaperDir}"/*.jpeg "${wallpaperDir}"/*.png "${wallpaperDir}"/*.bmp "${wallpaperDir}"/*.gif "${wallpaperDir}"/*.webp 2>/dev/null | sort`]
        prevCyclingProcess.targetScreenName = screenName || ""
        prevCyclingProcess.currentWallpaper = currentWallpaper
        prevCyclingProcess.running = true
    }

    function cycleNextManually() {
        if (SessionData.wallpaperPath) {
            cycleToNextWallpaper()
            // Restart timers if cycling is active
            if (cyclingActive && SessionData.wallpaperCyclingEnabled) {
                if (SessionData.wallpaperCyclingMode === "interval") {
                    intervalTimer.interval = cachedCyclingInterval * 1000
                    intervalTimer.restart()
                }
            }
        }
    }

    function cyclePrevManually() {
        if (SessionData.wallpaperPath) {
            cycleToPrevWallpaper()
            // Restart timers if cycling is active
            if (cyclingActive && SessionData.wallpaperCyclingEnabled) {
                if (SessionData.wallpaperCyclingMode === "interval") {
                    intervalTimer.interval = cachedCyclingInterval * 1000
                    intervalTimer.restart()
                }
            }
        }
    }

    function cycleNextForMonitor(screenName) {
        if (!screenName) return
        
        var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
        if (currentWallpaper) {
            cycleToNextWallpaper(screenName, currentWallpaper)
        }
    }

    function cyclePrevForMonitor(screenName) {
        if (!screenName) return
        
        var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
        if (currentWallpaper) {
            cycleToPrevWallpaper(screenName, currentWallpaper)
        }
    }

    function checkTimeBasedCycling() {
        const currentTime = Qt.formatTime(systemClock.date, "hh:mm")

        if (currentTime === cachedCyclingTime
                && currentTime !== lastTimeCheck) {
            lastTimeCheck = currentTime
            cycleToNextWallpaper()
        } else if (currentTime !== cachedCyclingTime) {
            lastTimeCheck = ""
        }
    }

    Timer {
        id: intervalTimer
        interval: cachedCyclingInterval * 1000
        running: false
        repeat: true
        onTriggered: cycleToNextWallpaper()
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
        onDateChanged: {
            if (SessionData.wallpaperCyclingMode === "time" && cyclingActive) {
                checkTimeBasedCycling()
            }
        }
    }

    Process {
        id: cyclingProcess
        
        property string targetScreenName: ""
        property string currentWallpaper: ""
        
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    const files = text.trim().split('\n').filter(file => file.length > 0)
                    if (files.length <= 1) return

                    const wallpaperList = files.sort()
                    const currentPath = cyclingProcess.currentWallpaper
                    let currentIndex = wallpaperList.findIndex(path => path === currentPath)
                    if (currentIndex === -1) currentIndex = 0

                    const nextIndex = (currentIndex + 1) % wallpaperList.length
                    const nextWallpaper = wallpaperList[nextIndex]

                    if (nextWallpaper && nextWallpaper !== currentPath) {
                        if (cyclingProcess.targetScreenName) {
                            SessionData.setMonitorWallpaper(cyclingProcess.targetScreenName, nextWallpaper)
                        } else {
                            SessionData.setWallpaper(nextWallpaper)
                        }
                    }
                }
            }
        }
    }

    Process {
        id: prevCyclingProcess
        
        property string targetScreenName: ""
        property string currentWallpaper: ""
        
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    const files = text.trim().split('\n').filter(file => file.length > 0)
                    if (files.length <= 1) return

                    const wallpaperList = files.sort()
                    const currentPath = prevCyclingProcess.currentWallpaper
                    let currentIndex = wallpaperList.findIndex(path => path === currentPath)
                    if (currentIndex === -1) currentIndex = 0

                    const prevIndex = currentIndex === 0 ? wallpaperList.length - 1 : currentIndex - 1
                    const prevWallpaper = wallpaperList[prevIndex]

                    if (prevWallpaper && prevWallpaper !== currentPath) {
                        if (prevCyclingProcess.targetScreenName) {
                            SessionData.setMonitorWallpaper(prevCyclingProcess.targetScreenName, prevWallpaper)
                        } else {
                            SessionData.setWallpaper(prevWallpaper)
                        }
                    }
                }
            }
        }
    }

}
