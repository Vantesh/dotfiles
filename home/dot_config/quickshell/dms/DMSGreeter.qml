import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs.Common
import qs.Modules.Greetd

ShellRoot {
    id: root

    WlSessionLock {
        id: sessionLock
        locked: false

        Component.onCompleted: {
            Qt.callLater(() => { locked = true })
        }

        onLockedChanged: {
            if (!locked) {
                console.log("Greetd session unlocked, exiting")
            }
        }

        GreeterSurface {
            lock: sessionLock
        }
    }
}
