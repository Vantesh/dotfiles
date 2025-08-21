import QtQuick
import Quickshell
import qs.Common
import qs.Services

QtObject {
    id: manager

    property var modelData
    property int topMargin: 0
    property int baseNotificationHeight: 120
    property int maxTargetNotifications: 3
    property var popupWindows: [] // strong refs to windows (live until exitFinished)
    property var destroyingWindows: new Set()
    property Component popupComponent

    popupComponent: Component {
        NotificationPopup {
            onEntered: manager._onPopupEntered(this)
            onExitFinished: manager._onPopupExitFinished(this)
        }
    }

    property Connections notificationConnections

    notificationConnections: Connections {
        function onVisibleNotificationsChanged() {
            manager._sync(NotificationService.visibleNotifications)
        }

        target: NotificationService
    }

    property Timer sweeper

    sweeper: Timer {
        interval: 2000
        running: false // Not running by default
        repeat: true
        onTriggered: {
            let toRemove = []
            for (let p of popupWindows) {
                if (!p) {
                    toRemove.push(p)
                    continue
                }
                const isZombie = p.status === Component.Null || (!p.visible
                                                                 && !p.exiting)
                               || (!p.notificationData && !p._isDestroying)
                               || (!p.hasValidData && !p._isDestroying)
                if (isZombie) {

                    toRemove.push(p)
                    if (p.forceExit) {
                        p.forceExit()
                    } else if (p.destroy) {
                        try {
                            p.destroy()
                        } catch (e) {

                        }
                    }
                }
            }
            if (toRemove.length > 0) {
                for (let zombie of toRemove) {
                    const i = popupWindows.indexOf(zombie)
                    if (i !== -1)
                        popupWindows.splice(i, 1)
                }
                popupWindows = popupWindows.slice()
                const survivors = _active().sort((a, b) => {
                                                     return a.screenY - b.screenY
                                                 })
                for (var k = 0; k < survivors.length; ++k) {
                    survivors[k].screenY = topMargin + k * baseNotificationHeight
                }
            }
            if (popupWindows.length === 0)
                sweeper.stop()
        }
    }

    function _hasWindowFor(w) {
        return popupWindows.some(p => {
                                     return p && p.notificationData === w
                                     && !p._isDestroying
                                     && p.status !== Component.Null
                                 })
    }

    function _isValidWindow(p) {
        return p && p.status !== Component.Null && !p._isDestroying
                && p.hasValidData
    }

    function _sync(newWrappers) {
        for (let w of newWrappers) {
            if (w && !_hasWindowFor(w))
                insertNewestAtTop(w)
        }
        for (let p of popupWindows.slice()) {
            if (!_isValidWindow(p))
                continue

            if (p.notificationData && newWrappers.indexOf(
                        p.notificationData) === -1 && !p.exiting) {
                p.notificationData.removedByLimit = true
                p.notificationData.popup = false
            }
        }
    }

    function insertNewestAtTop(wrapper) {
        if (!wrapper) {

            return
        }
        for (let p of popupWindows) {
            if (!_isValidWindow(p))
                continue

            if (p.exiting)
                continue

            p.screenY = p.screenY + baseNotificationHeight
        }
        const notificationId = wrapper
                             && wrapper.notification ? wrapper.notification.id : ""
        const win = popupComponent.createObject(null, {
                                                    "notificationData": wrapper,
                                                    "notificationId": notificationId,
                                                    "screenY": topMargin,
                                                    "screen": manager.modelData
                                                })
        if (!win) {

            return
        }
        if (!win.hasValidData) {

            win.destroy()
            return
        }
        popupWindows.push(win)
        if (!sweeper.running)
            sweeper.start()

        _maybeStartOverflow()
    }

    function _active() {
        return popupWindows.filter(p => {
                                       return _isValidWindow(p)
                                       && p.notificationData
                                       && p.notificationData.popup && !p.exiting
                                   })
    }

    function _bottom() {
        let b = null, maxY = -1
        for (let p of _active()) {
            if (p.screenY > maxY) {
                maxY = p.screenY
                b = p
            }
        }
        return b
    }

    function _maybeStartOverflow() {
        const activeWindows = _active()
        if (activeWindows.length <= maxTargetNotifications + 1)
            return

        const expiredCandidates = activeWindows.filter(p => {
                                                           if (!p.notificationData
                                                               || !p.notificationData.notification)
                                                           return false
                                                           if (p.notificationData.notification.urgency === 2)
                                                           return false

                                                           const timeoutMs = p.notificationData.timer ? p.notificationData.timer.interval : 5000
                                                           if (timeoutMs === 0)
                                                           return false

                                                           return !p.notificationData.timer.running
                                                       }).sort(
                                    (a, b) => b.screenY - a.screenY)

        if (expiredCandidates.length > 0) {
            const toRemove = expiredCandidates[0]
            if (toRemove && !toRemove.exiting) {
                toRemove.notificationData.removedByLimit = true
                toRemove.notificationData.popup = false
            }
            return
        }

        const timeoutCandidates = activeWindows.filter(p => {
                                                           if (!p.notificationData
                                                               || !p.notificationData.notification)
                                                           return false
                                                           if (p.notificationData.notification.urgency === 2)
                                                           return false

                                                           const timeoutMs = p.notificationData.timer ? p.notificationData.timer.interval : 5000
                                                           return timeoutMs > 0
                                                       }).sort((a, b) => {
                                                                   const aTimeout = a.notificationData.timer ? a.notificationData.timer.interval : 5000
                                                                   const bTimeout = b.notificationData.timer ? b.notificationData.timer.interval : 5000
                                                                   if (aTimeout !== bTimeout)
                                                                   return aTimeout - bTimeout
                                                                   return b.screenY - a.screenY
                                                               })

        if (timeoutCandidates.length > 0) {
            const toRemove = timeoutCandidates[0]
            if (toRemove && !toRemove.exiting) {
                toRemove.notificationData.removedByLimit = true
                toRemove.notificationData.popup = false
            }
        }
    }

    function _onPopupEntered(p) {
        if (_isValidWindow(p))
            _maybeStartOverflow()
    }

    function _onPopupExitFinished(p) {
        if (!p)
            return

        const windowId = p.toString()
        if (destroyingWindows.has(windowId))
            return

        destroyingWindows.add(windowId)
        const i = popupWindows.indexOf(p)
        if (i !== -1) {
            popupWindows.splice(i, 1)
            popupWindows = popupWindows.slice()
        }
        if (NotificationService.releaseWrapper && p.notificationData)
            NotificationService.releaseWrapper(p.notificationData)

        Qt.callLater(() => {
                         if (p && p.destroy) {
                             try {
                                 p.destroy()
                             } catch (e) {

                             }
                         }
                         Qt.callLater(() => {
                                          destroyingWindows.delete(windowId)
                                      })
                     })
        const survivors = _active().sort((a, b) => {
                                             return a.screenY - b.screenY
                                         })
        for (var k = 0; k < survivors.length; ++k) {
            survivors[k].screenY = topMargin + k * baseNotificationHeight
        }
        _maybeStartOverflow()
    }

    function cleanupAllWindows() {
        sweeper.stop()
        for (let p of popupWindows.slice()) {
            if (p) {
                try {
                    if (p.forceExit)
                        p.forceExit()
                    else if (p.destroy)
                        p.destroy()
                } catch (e) {

                }
            }
        }
        popupWindows = []
        destroyingWindows.clear()
    }

    onPopupWindowsChanged: {
        if (popupWindows.length > 0 && !sweeper.running)
            sweeper.start()
        else if (popupWindows.length === 0 && sweeper.running)
            sweeper.stop()
    }
}
