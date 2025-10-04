import QtQuick
import qs.Common

StyledText {
    id: icon

    property alias name: icon.text
    property alias size: icon.font.pixelSize
    property alias color: icon.color
    property bool filled: false
    property real fill: filled ? 1.0 : 0.0
    property int grade: Theme.isLightMode ? 0 : -25
    property int weight: filled ? 500 : 400

    signal rotationCompleted()

    font.family: "Material Symbols Rounded"
    font.pixelSize: Theme.fontSizeMedium
    font.weight: weight
    color: Theme.surfaceText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
    antialiasing: true
    font.variableAxes: {
        "FILL": fill.toFixed(1),
        "GRAD": grade,
        "opsz": 24,
        "wght": weight
    }

    Behavior on fill {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on weight {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Timer {
        id: rotationTimer
        interval: 16
        repeat: false
        onTriggered: icon.rotationCompleted()
    }

    onRotationChanged: {
        rotationTimer.restart()
    }
}
