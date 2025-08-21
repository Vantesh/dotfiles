pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modals

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property string sharedPasswordBuffer

    signal passwordChanged(string newPassword)

    property bool thisLocked: false
    readonly property bool locked: thisLocked && lock && !lock.unlocked

    function unlock(): void {
        console.log("LockSurface.unlock() called")
        if (lock) {
            lock.unlocked = true
            animDelay.start()
        }
    }

    Component.onCompleted: {
        thisLocked = true
    }

    Component.onDestruction: {
        animDelay.stop()
    }

    color: "transparent"

    Timer {
        id: animDelay
        interval: 1500 // Longer delay for success feedback
        onTriggered: {
            if (root.lock) {
                root.lock.locked = false
            }
        }
    }

    PowerConfirmModal {
        id: powerConfirmModal
    }

    Loader {
        anchors.fill: parent
        sourceComponent: LockScreenContent {
            demoMode: false
            powerModal: powerConfirmModal
            passwordBuffer: root.sharedPasswordBuffer
            onUnlockRequested: root.unlock()
            onPasswordBufferChanged: {
                if (root.sharedPasswordBuffer !== passwordBuffer) {
                    root.passwordChanged(passwordBuffer)
                }
            }
        }
    }
}
