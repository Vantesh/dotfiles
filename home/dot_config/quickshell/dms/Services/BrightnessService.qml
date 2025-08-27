pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool brightnessAvailable: devices.length > 0
    property var devices: []
    property var ddcDevices: []
    property var deviceBrightness: ({})
    property var ddcPendingInit: ({})
    property string currentDevice: ""
    property string lastIpcDevice: ""
    property bool ddcAvailable: false
    property var ddcInitQueue: []
    property bool skipDdcRead: false
    property int brightnessLevel: {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) return 50

        // Always use cached values for consistency
        return getDeviceBrightness(deviceToUse)
    }
    property int maxBrightness: 100
    property bool brightnessInitialized: false

    signal brightnessChanged
    signal deviceSwitched

    property bool nightModeActive: false

    function setBrightnessInternal(percentage, device) {
        const clampedValue = Math.max(1, Math.min(100, percentage))
        const actualDevice = device === "" ? getDefaultDevice(
                                                 ) : (device || currentDevice
                                                      || getDefaultDevice())

        // Update the device brightness cache immediately for all devices
        if (actualDevice) {
            var newBrightness = Object.assign({}, deviceBrightness)
            newBrightness[actualDevice] = clampedValue
            deviceBrightness = newBrightness
        }
        
        const deviceInfo = getCurrentDeviceInfoByName(actualDevice)

        if (deviceInfo && deviceInfo.class === "ddc") {
            // Use ddcutil for DDC devices
            ddcBrightnessSetProcess.command = ["ddcutil", "setvcp", "-d", String(
                                                   deviceInfo.ddcDisplay), "10", String(
                                                   clampedValue)]
            ddcBrightnessSetProcess.running = true
        } else {
            // Use brightnessctl for regular devices
            if (device)
                brightnessSetProcess.command
                        = ["brightnessctl", "-d", device, "set", clampedValue + "%"]
            else
                brightnessSetProcess.command = ["brightnessctl", "set", clampedValue + "%"]
            brightnessSetProcess.running = true
        }
    }

    function setBrightness(percentage, device) {
        setBrightnessInternal(percentage, device)
        brightnessChanged()
    }

    function setCurrentDevice(deviceName, saveToSession = false) {
        if (currentDevice === deviceName)
            return

        currentDevice = deviceName
        lastIpcDevice = deviceName

        // Only save to session if explicitly requested (user choice)
        if (saveToSession) {
            SessionData.setLastBrightnessDevice(deviceName)
        }

        deviceSwitched()

        // Check if this is a DDC device
        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (deviceInfo && deviceInfo.class === "ddc") {
            // For DDC devices, never read after initial - just use cached values
            return
        } else {
            // For regular devices, use brightnessctl
            brightnessGetProcess.command = ["brightnessctl", "-m", "-d", deviceName, "get"]
            brightnessGetProcess.running = true
        }
    }

    function refreshDevices() {
        deviceListProcess.running = true
    }

    function refreshDevicesInternal() {
        const allDevices = [...devices, ...ddcDevices]

        allDevices.sort((a, b) => {
                            if (a.class === "backlight"
                                && b.class !== "backlight")
                            return -1
                            if (a.class !== "backlight"
                                && b.class === "backlight")
                            return 1

                            if (a.class === "ddc" && b.class !== "ddc"
                                && b.class !== "backlight")
                            return -1
                            if (a.class !== "ddc" && b.class === "ddc"
                                && a.class !== "backlight")
                            return 1

                            return a.name.localeCompare(b.name)
                        })

        devices = allDevices

        if (devices.length > 0 && !currentDevice) {
            const lastDevice = SessionData.lastBrightnessDevice || ""
            const deviceExists = devices.some(d => d.name === lastDevice)
            if (deviceExists) {
                setCurrentDevice(lastDevice, false)
            } else {
                const nonKbdDevice = devices.find(d => !d.name.includes("kbd"))
                                   || devices[0]
                setCurrentDevice(nonKbdDevice.name, false)
            }
        }
    }

    function getDeviceBrightness(deviceName) {
        if (!deviceName) return 50
        
        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (!deviceInfo) return 50
        
        // For DDC devices, always use cached values
        if (deviceInfo.class === "ddc") {
            return deviceBrightness[deviceName] || 50
        }
        
        // For regular devices, try cache first, then device info
        return deviceBrightness[deviceName] || deviceInfo.percentage || 50
    }

    function getDefaultDevice() {
        for (const device of devices) {
            if (device.class === "backlight") {
                return device.name
            }
        }
        return devices.length > 0 ? devices[0].name : ""
    }

    function getCurrentDeviceInfo() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice(
                                                       ) : (lastIpcDevice
                                                            || currentDevice)
        if (!deviceToUse)
            return null

        for (const device of devices) {
            if (device.name === deviceToUse) {
                return device
            }
        }
        return null
    }

    function isCurrentDeviceReady() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice(
                                                       ) : (lastIpcDevice
                                                            || currentDevice)
        if (!deviceToUse)
            return false

        if (ddcPendingInit[deviceToUse]) {
            return false
        }

        return true
    }

    function getCurrentDeviceInfoByName(deviceName) {
        if (!deviceName)
            return null

        for (const device of devices) {
            if (device.name === deviceName) {
                return device
            }
        }
        return null
    }

    function processNextDdcInit() {
        if (ddcInitQueue.length === 0 || ddcInitialBrightnessProcess.running) {
            return
        }

        const displayId = ddcInitQueue.shift()
        ddcInitialBrightnessProcess.command = ["ddcutil", "getvcp", "-d", String(
                                                   displayId), "10", "--brief"]
        ddcInitialBrightnessProcess.running = true
    }

    function enableNightMode() {
        if (nightModeActive)
            return

        // Test if gammastep exists before enabling
        gammaStepTestProcess.running = true
    }

    function updateNightModeTemperature(temperature) {
        SessionData.setNightModeTemperature(temperature)

        // If night mode is active, restart it with new temperature
        if (nightModeActive) {
            // Temporarily disable and re-enable to restart with new temp
            nightModeActive = false
            Qt.callLater(() => {
                             if (SessionData.nightModeEnabled) {
                                 nightModeActive = true
                             }
                         })
        }
    }

    function disableNightMode() {
        nightModeActive = false
        SessionData.setNightModeEnabled(false)

        // Also kill any stray gammastep processes
        Quickshell.execDetached(["pkill", "gammastep"])
    }

    function toggleNightMode() {
        if (nightModeActive) {
            disableNightMode()
        } else {
            enableNightMode()
        }
    }

    Component.onCompleted: {
        ddcDetectionProcess.running = true
        refreshDevices()

        // Check if night mode was enabled on startup
        if (SessionData.nightModeEnabled) {
            enableNightMode()
        }
    }

    Process {
        id: ddcDetectionProcess

        command: ["which", "ddcutil"]
        running: false

        onExited: function (exitCode) {
            ddcAvailable = (exitCode === 0)
            if (ddcAvailable) {
                console.log("BrightnessService: ddcutil detected")
                ddcDisplayDetectionProcess.running = true
            } else {
                console.log("BrightnessService: ddcutil not available")
            }
        }
    }

    Process {
        id: ddcDisplayDetectionProcess

        command: ["bash", "-c", "ddcutil detect --brief 2>/dev/null | grep '^Display [0-9]' | awk '{print \"{\\\"display\\\":\" $2 \",\\\"name\\\":\\\"ddc-\" $2 \"\\\",\\\"class\\\":\\\"ddc\\\"}\"}' | tr '\\n' ',' | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/' || echo '[]'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    console.log("BrightnessService: No DDC displays found")
                    ddcDevices = []
                    return
                }

                try {
                    const parsedDevices = JSON.parse(text.trim())
                    const newDdcDevices = []

                    for (const device of parsedDevices) {
                        if (device.display && device.class === "ddc") {
                            newDdcDevices.push({
                                                   "name": device.name,
                                                   "class": "ddc",
                                                   "current": 50,
                                                   "percentage": 50,
                                                   "max": 100,
                                                   "ddcDisplay": device.display
                                               })
                        }
                    }

                    ddcDevices = newDdcDevices
                    console.log("BrightnessService: Found", ddcDevices.length,
                                "DDC displays")

                    // Queue initial brightness readings for DDC devices
                    ddcInitQueue = []
                    for (const device of ddcDevices) {
                        ddcInitQueue.push(device.ddcDisplay)
                        // Mark DDC device as pending initialization
                        ddcPendingInit[device.name] = true
                    }

                    // Start processing the queue
                    processNextDdcInit()

                    // Refresh device list to include DDC devices
                    refreshDevicesInternal()

                    // Retry setting last device now that DDC devices are available
                    const lastDevice = SessionData.lastBrightnessDevice || ""
                    if (lastDevice) {
                        const deviceExists = devices.some(
                                               d => d.name === lastDevice)
                        if (deviceExists && (!currentDevice
                                             || currentDevice !== lastDevice)) {
                            setCurrentDevice(lastDevice, false)
                        }
                    }
                } catch (error) {
                    console.warn("BrightnessService: Failed to parse DDC devices:",
                                 error)
                    ddcDevices = []
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("BrightnessService: Failed to detect DDC displays:",
                             exitCode)
                ddcDevices = []
            }
        }
    }

    Process {
        id: deviceListProcess

        command: ["brightnessctl", "-m", "-l"]
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("BrightnessService: Failed to list devices:",
                             exitCode)
                brightnessAvailable = false
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    console.warn("BrightnessService: No devices found")
                    return
                }
                const lines = text.trim().split("\n")
                const newDevices = []
                for (const line of lines) {
                    const parts = line.split(",")
                    if (parts.length >= 5)
                        newDevices.push({
                                            "name": parts[0],
                                            "class": parts[1],
                                            "current": parseInt(parts[2]),
                                            "percentage": parseInt(parts[3]),
                                            "max": parseInt(parts[4])
                                        })
                }
                // Store brightnessctl devices separately, will be combined with DDC
                const brightnessCtlDevices = newDevices
                devices = brightnessCtlDevices

                // If we have DDC devices, combine them
                if (ddcDevices.length > 0) {
                    refreshDevicesInternal()
                } else if (devices.length > 0 && !currentDevice) {
                    // Try to restore last selected device, fallback to first device
                    const lastDevice = SessionData.lastBrightnessDevice || ""
                    const deviceExists = devices.some(
                                           d => d.name === lastDevice)
                    if (deviceExists) {
                        setCurrentDevice(lastDevice, false)
                    } else {
                        const nonKbdDevice = devices.find(
                                               d => !d.name.includes("kbd"))
                                           || devices[0]
                        setCurrentDevice(nonKbdDevice.name, false)
                    }
                }
            }
        }
    }

    Process {
        id: brightnessSetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.warn("BrightnessService: Failed to set brightness:",
                             exitCode)
        }
    }

    Process {
        id: ddcBrightnessSetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.warn(
                            "BrightnessService: Failed to set DDC brightness:",
                            exitCode)
        }
    }

    Process {
        id: ddcInitialBrightnessProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.warn("BrightnessService: Failed to get initial DDC brightness:",
                             exitCode)

            processNextDdcInit()
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return

                const parts = text.trim().split(" ")
                if (parts.length >= 5) {
                    const current = parseInt(parts[3]) || 50
                    const max = parseInt(parts[4]) || 100
                    const brightness = Math.round((current / max) * 100)

                    const commandParts = ddcInitialBrightnessProcess.command
                    if (commandParts && commandParts.length >= 4) {
                        const displayId = commandParts[3]
                        const deviceName = "ddc-" + displayId

                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[deviceName] = brightness
                        deviceBrightness = newBrightness

                        var newPending = Object.assign({}, ddcPendingInit)
                        delete newPending[deviceName]
                        ddcPendingInit = newPending

                        console.log("BrightnessService: Initial DDC Device",
                                    deviceName, "brightness:", brightness + "%")
                    }
                }
            }
        }
    }

    Process {
        id: brightnessGetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.warn("BrightnessService: Failed to get brightness:",
                             exitCode)
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return

                const parts = text.trim().split(",")
                if (parts.length >= 5) {
                    const current = parseInt(parts[2])
                    const max = parseInt(parts[4])
                    maxBrightness = max
                    const brightness = Math.round((current / max) * 100)

                    // Update the device brightness cache
                    if (currentDevice) {
                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[currentDevice] = brightness
                        deviceBrightness = newBrightness
                    }

                    brightnessInitialized = true
                    console.log("BrightnessService: Device", currentDevice,
                                "brightness:", brightness + "%")
                    brightnessChanged()
                }
            }
        }
    }

    Process {
        id: ddcBrightnessGetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.warn(
                            "BrightnessService: Failed to get DDC brightness:",
                            exitCode)
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return

                // Parse ddcutil getvcp output format: "VCP 10 C 50 100"
                const parts = text.trim().split(" ")
                if (parts.length >= 5) {
                    const current = parseInt(parts[3]) || 50
                    const max = parseInt(parts[4]) || 100
                    maxBrightness = max
                    const brightness = Math.round((current / max) * 100)

                    // Update the device brightness cache
                    if (currentDevice) {
                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[currentDevice] = brightness
                        deviceBrightness = newBrightness
                    }

                    brightnessInitialized = true
                    console.log("BrightnessService: DDC Device", currentDevice,
                                "brightness:", brightness + "%")
                    brightnessChanged()
                }
            }
        }
    }

    Process {
        id: gammaStepTestProcess

        command: ["which", "gammastep"]
        running: false

        onExited: function (exitCode) {
            if (exitCode === 0) {
                // gammastep exists, enable night mode
                nightModeActive = true
                SessionData.setNightModeEnabled(true)
            } else {
                // gammastep not found
                console.warn("BrightnessService: gammastep not found")
                ToastService.showWarning(
                            "Night mode failed: gammastep not found")
            }
        }
    }

    Process {
        id: gammaStepProcess

        command: {
            const temperature = SessionData.nightModeTemperature || 4500
            return ["gammastep", "-m", "wayland", "-O", String(temperature)]
        }
        running: nightModeActive

        onExited: function (exitCode) {
            // If process exits with non-zero code while we think it should be running
            if (nightModeActive && exitCode !== 0) {
                console.warn("BrightnessService: Night mode process crashed with exit code:",
                             exitCode)
                nightModeActive = false
                SessionData.setNightModeEnabled(false)
                ToastService.showWarning("Night mode failed: process crashed")
            }
        }
    }

    // IPC Handler for external control
    IpcHandler {
        function set(percentage: string, device: string): string {
            if (!root.brightnessAvailable)
                return "Brightness control not available"

            const value = parseInt(percentage)
            if (isNaN(value)) {
                return "Invalid brightness value: " + percentage
            }
            
            const clampedValue = Math.max(1, Math.min(100, value))
            const targetDevice = device || ""
            
            // Ensure device exists if specified
            if (targetDevice && !root.devices.some(d => d.name === targetDevice)) {
                return "Device not found: " + targetDevice
            }
            
            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(clampedValue, targetDevice)
            
            if (targetDevice)
                return "Brightness set to " + clampedValue + "% on " + targetDevice
            else
                return "Brightness set to " + clampedValue + "%"
        }

        function increment(step: string, device: string): string {
            if (!root.brightnessAvailable)
                return "Brightness control not available"

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice
            
            // Ensure device exists
            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }
            
            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel + stepValue))
            
            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)
            
            if (targetDevice)
                return "Brightness increased to " + newLevel + "% on " + targetDevice
            else
                return "Brightness increased to " + newLevel + "%"
        }

        function decrement(step: string, device: string): string {
            if (!root.brightnessAvailable)
                return "Brightness control not available"

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice
            
            // Ensure device exists
            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }
            
            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel - stepValue))
            
            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)
            
            if (targetDevice)
                return "Brightness decreased to " + newLevel + "% on " + targetDevice
            else
                return "Brightness decreased to " + newLevel + "%"
        }

        function status(): string {
            if (!root.brightnessAvailable)
                return "Brightness control not available"

            return "Device: " + root.currentDevice + " - Brightness: " + root.brightnessLevel + "%"
        }

        function list(): string {
            if (!root.brightnessAvailable)
                return "No brightness devices available"

            let result = "Available devices:\n"
            for (const device of root.devices) {
                result += device.name + " (" + device.class + ")\n"
            }
            return result
        }

        target: "brightness"
    }

    // IPC Handler for night mode control
    IpcHandler {
        function toggle(): string {
            root.toggleNightMode()
            return root.nightModeActive ? "Night mode enabled" : "Night mode disabled"
        }

        function enable(): string {
            root.enableNightMode()
            return "Night mode enabled"
        }

        function disable(): string {
            root.disableNightMode()
            return "Night mode disabled"
        }

        function status(): string {
            return root.nightModeActive ? "Night mode is enabled" : "Night mode is disabled"
        }

        function temperature(value: string): string {
            if (!value) {
                return "Current temperature: " + SessionData.nightModeTemperature + "K"
            }

            const temp = parseInt(value)
            if (isNaN(temp)) {
                return "Invalid temperature. Use a value between 2500 and 6000 (in steps of 500)"
            }

            // Validate temperature is in valid range and steps
            if (temp < 2500 || temp > 6000) {
                return "Temperature must be between 2500K and 6000K"
            }

            // Round to nearest 500
            const rounded = Math.round(temp / 500) * 500

            SessionData.setNightModeTemperature(rounded)

            // If night mode is active, restart it with new temperature
            if (root.nightModeActive) {
                root.nightModeActive = false
                Qt.callLater(() => {
                                 root.nightModeActive = true
                             })
            }

            if (rounded !== temp) {
                return "Night mode temperature set to " + rounded + "K (rounded from " + temp + "K)"
            } else {
                return "Night mode temperature set to " + rounded + "K"
            }
        }

        target: "night"
    }
}
