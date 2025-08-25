import QtQuick
import qs.Common

StyledText {
    id: icon

    property alias name: icon.text
    property alias size: icon.font.pixelSize
    property alias color: icon.color
    property bool filled: false
    property real fill: filled ? 1 : 0
    property int grade: Theme.isLightMode ? 0 : -25
    property int weight: filled ? 500 : 400

    font.family: "Material Symbols Rounded"
    font.pixelSize: Appearance.fontSize.normal
    font.weight: weight
    color: Theme.surfaceText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    font.variableAxes: ({
                            "FILL": fill.toFixed(1),
                            "GRAD": grade,
                            "opsz": 24,
                            "wght": weight
                        })

    Behavior on fill {
        NumberAnimation {
            duration: Appearance.anim.durations.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    Behavior on weight {
        NumberAnimation {
            duration: Appearance.anim.durations.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }
}
