import QtQuick
import Quickshell

ShellRoot {
    id: entrypoint

    readonly property bool runGreeter: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    Component {
        id: shellComponent
        DMSShell {}
    }

    Component {
        id: greeterComponent
        DMSGreeter {}
    }

    Loader {
        id: dmsShellLoader
        asynchronous: false
        sourceComponent: shellComponent
        active: !entrypoint.runGreeter
    }

    Loader {
        id: dmsGreeterLoader
        asynchronous: false
        sourceComponent: greeterComponent
        active: entrypoint.runGreeter
    }
}
