import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock

    color: "transparent"

    GreeterContent {
        anchors.fill: parent
        screenName: root.screen?.name ?? ""
        sessionLock: root.lock
    }
}
