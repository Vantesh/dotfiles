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

    onMonitorTimeoutChanged: _rearmIdleMonitors()
    onLockTimeoutChanged: _rearmIdleMonitors()
    onSuspendTimeoutChanged: _rearmIdleMonitors()
    onHibernateTimeoutChanged: _rearmIdleMonitors()

    function _rearmIdleMonitors() {
        _enableGate = false
        Qt.callLater(() => { _enableGate = true })
    }

    signal lockRequested()
    signal requestMonitorOff()
    signal requestMonitorOn()
    signal requestSuspend()
    signal requestHibernate()

    property var monitorOffMonitor: null
    property var lockMonitor: null
    property var suspendMonitor: null
    property var hibernateMonitor: null

    function wake() {
        requestMonitorOn()
    }

    function createIdleMonitors() {
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

            if (monitorTimeout > 0) {
                monitorOffMonitor = Qt.createQmlObject(qmlString, root, "IdleService.MonitorOffMonitor")
                monitorOffMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.monitorTimeout > 0)
                monitorOffMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
                monitorOffMonitor.timeout = Qt.binding(() => root.monitorTimeout)
                monitorOffMonitor.isIdleChanged.connect(function() {
                    if (monitorOffMonitor.isIdle) {
                        root.requestMonitorOff()
                    } else {
                        root.requestMonitorOn()
                    }
                })
            }

            if (lockTimeout > 0) {
                lockMonitor = Qt.createQmlObject(qmlString, root, "IdleService.LockMonitor")
                lockMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.lockTimeout > 0)
                lockMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
                lockMonitor.timeout = Qt.binding(() => root.lockTimeout)
                lockMonitor.isIdleChanged.connect(function() {
                    if (lockMonitor.isIdle) {
                        root.lockRequested()
                    }
                })
            }

            if (suspendTimeout > 0) {
                suspendMonitor = Qt.createQmlObject(qmlString, root, "IdleService.SuspendMonitor")
                suspendMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.suspendTimeout > 0)
                suspendMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
                suspendMonitor.timeout = Qt.binding(() => root.suspendTimeout)
                suspendMonitor.isIdleChanged.connect(function() {
                    if (suspendMonitor.isIdle) {
                        root.requestSuspend()
                    }
                })
            }

            if (hibernateTimeout > 0 && SessionService.hibernateSupported) {
                hibernateMonitor = Qt.createQmlObject(qmlString, root, "IdleService.HibernateMonitor")
                hibernateMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.idleMonitorAvailable && root.hibernateTimeout > 0)
                hibernateMonitor.respectInhibitors = Qt.binding(() => root.respectInhibitors)
                hibernateMonitor.timeout = Qt.binding(() => root.hibernateTimeout)
                hibernateMonitor.isIdleChanged.connect(function() {
                    if (hibernateMonitor.isIdle) {
                        root.requestHibernate()
                    }
                })
            }
        } catch (e) {
            console.warn("IdleService: Error creating IdleMonitors:", e)
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
            createIdleMonitors()
        }
    }
}