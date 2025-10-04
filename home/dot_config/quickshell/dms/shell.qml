import QtQuick
import Quickshell

ShellRoot {
    id: entrypoint

    readonly property bool runGreeter: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    Loader {
        id: dmsShellLoader
        asynchronous: false
        sourceComponent: DMSShell{}
        active: !entrypoint.runGreeter
    }

    Loader {
        id: dmsGreeterLoader
        asynchronous: false
        sourceComponent: DMSGreeter{}
        active: entrypoint.runGreeter
    }
}
