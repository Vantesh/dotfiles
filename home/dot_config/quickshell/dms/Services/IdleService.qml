pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property bool idleMonitorAvailable: {
        try {
            return typeof IdleMonitor !== "undefined"
        } catch (e) {
            return false
        }
    }

    property bool enabled: true
    property bool respectInhibitors: true
    property bool _enableGate: true

    readonly property bool isOnBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property int monitorTimeout: isOnBattery ? SessionData.batteryMonitorTimeout : SessionData.acMonitorTimeout
    readonly property int lockTimeout: isOnBattery ? SessionData.batteryLockTimeout : SessionData.acLockTimeout
    readonly property int suspendTimeout: isOnBattery ? SessionData.batterySuspendTimeout : SessionData.acSuspendTimeout
    readonly property int hibernateTimeout: isOnBattery ? SessionData.batteryHibernateTimeout : SessionData.acHibernateTimeout

    readonly property int firstTimeout: {
        const timeouts = []
        if (monitorTimeout > 0) timeouts.push(monitorTimeout)
        if (lockTimeout > 0) timeouts.push(lockTimeout)
        if (suspendTimeout > 0) timeouts.push(suspendTimeout)
        if (hibernateTimeout > 0) timeouts.push(hibernateTimeout)
        return timeouts.length > 0 ? Math.min(...timeouts) : 0
    }

    property int currentStepIndex: -1
    property var steps: []

    signal lockRequested()
    signal requestMonitorOff()
    signal requestMonitorOn()
    signal requestSuspend()
    signal requestHibernate()
    signal stageFired(string name)

    onFirstTimeoutChanged: {
        if (idleMonitor) _rearmIdleMonitor()
    }

    function _rearmIdleMonitor() {
        cancel()

        _enableGate = false
        Qt.callLater(() => { _enableGate = true })
    }

    function makeSteps() {
        const steps = []
        if (lockTimeout > 0) {
            steps.push({name: "lock", delaySec: lockTimeout})
        }
        if (monitorTimeout > 0) {
            steps.push({name: "monitor-off", delaySec: monitorTimeout})
        }
        if (suspendTimeout > 0) {
            steps.push({name: "suspend", delaySec: suspendTimeout})
        }
        if (hibernateTimeout > 0) {
            steps.push({name: "hibernate", delaySec: hibernateTimeout})
        }
        return steps.sort((a, b) => a.delaySec - b.delaySec)
    }

    function start() {
        if (!enabled || !idleMonitorAvailable) return
        if (currentStepIndex !== -1) return

        steps = makeSteps()
        currentStepIndex = -1
        next()
    }

    function next() {
        if (++currentStepIndex >= steps.length) return

        const currentStep = steps[currentStepIndex]

        const firstStepDelay = steps[0].delaySec
        const relativeDelay = currentStep.delaySec - firstStepDelay
        const ms = (relativeDelay * 1000) | 0

        if (ms > 0) {
            stepTimer.interval = ms
            stepTimer.restart()
        } else {
            Qt.callLater(run)
        }
    }

    function run() {
        const currentStep = steps[currentStepIndex]
        if (!currentStep) return

        console.log("IdleService: Executing step:", currentStep.name)

        if (currentStep.name === "lock") {
            lockRequested()
        } else if (currentStep.name === "monitor-off") {
            requestMonitorOff()
        } else if (currentStep.name === "suspend") {
            requestSuspend()
        } else if (currentStep.name === "hibernate") {
            requestHibernate()
        }

        stageFired(currentStep.name)
        next()
    }

    function cancel() {
        stepTimer.stop()
        currentStepIndex = -1
    }

    function wake() {
        cancel()
        requestMonitorOn()
    }

    Timer {
        id: stepTimer
        repeat: false
        onTriggered: root.run()
    }

    property var idleMonitor: null

    function createIdleMonitor() {
        if (!idleMonitorAvailable) {
            console.log("IdleService: IdleMonitor not available, skipping creation")
            return
        }

        try {
            const qmlString = `
                import QtQuick
                import Quickshell.Wayland

                IdleMonitor {
                    enabled: false
                    respectInhibitors: true
                    timeout: 0
                }
            `

            idleMonitor = Qt.createQmlObject(qmlString, root, "IdleService.IdleMonitor")

            if (idleMonitor) {
                idleMonitor.enabled = Qt.binding(
                    () => root._enableGate && root.enabled && root.idleMonitorAvailable && root.firstTimeout > 0
                )
                idleMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
                idleMonitor.timeout = Qt.binding(() => root.firstTimeout)

                idleMonitor.isIdleChanged.connect(function() {
                    if (idleMonitor.isIdle) {
                        console.log("IdleService: User is idle, starting power management")
                        Qt.callLater(root.start)
                    } else {
                        console.log("IdleService: User is active, canceling power management")
                        Qt.callLater(root.cancel)
                    }
                })
            }
        } catch (e) {
            console.warn("IdleService: Error creating IdleMonitor:", e)
        }
    }

    Connections {
        target: root
        function onRequestMonitorOff() {
            CompositorService.powerOffMonitors()
        }

        function onRequestMonitorOn() {
            CompositorService.powerOnMonitors()
        }

        function onRequestSuspend() {
            SessionService.suspend()
        }

        function onRequestHibernate() {
            SessionService.hibernate()
        }
    }

    Component.onCompleted: {
        if (!idleMonitorAvailable) {
            console.warn("IdleService: IdleMonitor not available - power management disabled. This requires a newer version of Quickshell.")
        } else {
            console.log("IdleService: Initialized with idle monitoring support")
            createIdleMonitor()
        }
    }
}