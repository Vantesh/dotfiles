import QtQuick
import qs.Common
import qs.Widgets

MouseArea {
    id: root

    property bool disabled: false
    property color stateColor: Theme.surfaceText
    property real cornerRadius: parent?.radius ?? Theme.cornerRadius

    anchors.fill: parent
    cursorShape: disabled ? undefined : Qt.PointingHandCursor
    hoverEnabled: true

    Rectangle {
        id: hoverLayer
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(
                   root.stateColor.r, root.stateColor.g, root.stateColor.b,
                   root.disabled ? 0 : root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0)
    }
}
