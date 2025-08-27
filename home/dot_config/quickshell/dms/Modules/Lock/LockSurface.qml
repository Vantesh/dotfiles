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

    readonly property bool locked: lock && !lock.locked

    function unlock(): void {
        lock.locked = false
    }

    color: "transparent"

    ConfirmModal {
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
