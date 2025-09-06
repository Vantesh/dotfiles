pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<int> values: Array(6)
    property int refCount: 0
    property bool cavaAvailable: false

    Process {
        id: cavaCheck

        command: ["which", "cava"]
        running: false
        onExited: exitCode => {
            root.cavaAvailable = exitCode === 0
        }
    }

    Component.onCompleted: {
        cavaCheck.running = true
    }

    Process {
        id: cavaProcess

        running: root.cavaAvailable && root.refCount > 0
        command: ["sh", "-c", `printf '[general]\\nmode=normal\\nframerate=25\\nautosens=0\\nsensitivity=30\\nbars=6\\nlower_cutoff_freq=50\\nhigher_cutoff_freq=12000\\n[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nchannels=mono\\nmono_option=average\\n[smoothing]\\nnoise_reduction=35\\nintegral=90\\ngravity=95\\nignore=2\\nmonstercat=1.5' | cava -p /dev/stdin`]

        onRunningChanged: {
            if (!running) {
                root.values = Array(6).fill(0)
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root.refCount > 0 && data.trim()) {
                    let points = data.split(";").map(p => {
                                                         return parseInt(p.trim(), 10)
                                                     }).filter(p => {
                                                                   return !isNaN(p)
                                                               })
                    if (points.length >= 6) {
                        root.values = points.slice(0, 6)
                    }
                }
            }
        }
    }
}
