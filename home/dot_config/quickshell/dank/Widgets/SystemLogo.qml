import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common

IconImage {
    id: root

    property string colorOverride: ""
    property real brightnessOverride: 0.5
    property real contrastOverride: 1

    smooth: true
    asynchronous: true
    layer.enabled: colorOverride !== ""

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release && echo $LOGO"]

        stdout: StdioCollector {
            onStreamFinished: () => {
                                  root.source = Quickshell.iconPath(
                                      this.text.trim())
                              }
        }
    }

    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: colorOverride
        brightness: brightnessOverride
        contrast: contrastOverride
    }
}
