import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common

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

    Loader {
        anchors.fill: parent
        sourceComponent: LockScreenContent {
            demoMode: false
            passwordBuffer: root.sharedPasswordBuffer
            screenName: root.screen?.name ?? ""
            onUnlockRequested: root.unlock()
            onPasswordBufferChanged: {
                if (root.sharedPasswordBuffer !== passwordBuffer) {
                    root.passwordChanged(passwordBuffer)
                }
            }
        }
    }
}
