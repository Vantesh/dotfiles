import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: toggle

    property bool checked: false
    property bool enabled: true
    property bool toggling: false
    property string text: ""
    property string description: ""
    property bool hideText: false

    signal clicked
    signal toggled(bool checked)

    readonly property bool showText: text && !hideText

    width: showText ? parent.width : 48
    height: showText ? 60 : 24

    function handleClick() {
        if (!enabled) {
            return
        }
        checked = !checked
        clicked()
        toggled(checked)
    }

    StyledRect {
        id: background

        anchors.fill: parent
        radius: showText ? Theme.cornerRadius : 0
        color: showText ? Theme.surfaceHover : "transparent"
        visible: showText

        StateLayer {
            visible: showText
            disabled: !toggle.enabled
            stateColor: Theme.primary
            cornerRadius: parent.radius
            onClicked: toggle.handleClick()
        }
    }

    Row {
        anchors.left: parent.left
        anchors.right: toggleTrack.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingXS
        visible: showText

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: toggle.text
                font.pixelSize: Appearance.fontSize.normal
                font.weight: Font.Medium
                opacity: toggle.enabled ? 1 : 0.4
            }

            StyledText {
                text: toggle.description
                font.pixelSize: Appearance.fontSize.small
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, toggle.width - 120)
                visible: toggle.description.length > 0
            }
        }
    }

    StyledRect {
        id: toggleTrack

        width: text ? 48 : parent.width
        height: text ? 24 : parent.height
        anchors.right: parent.right
        anchors.rightMargin: text ? Theme.spacingM : 0
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: (checked && enabled) ? Theme.primary : Theme.surfaceVariantAlpha
        opacity: toggling ? 0.6 : (enabled ? 1 : 0.4)

        StyledRect {
            id: toggleHandle

            width: 20
            height: 20
            radius: 10
            color: Theme.surface
            anchors.verticalCenter: parent.verticalCenter
            x: (checked && enabled) ? parent.width - width - 2 : 2
            border.color: Qt.rgba(0, 0, 0, 0.1)
            border.width: 1

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
                }
            }
        }

        StateLayer {
            disabled: !toggle.enabled
            stateColor: Theme.primary
            cornerRadius: parent.radius
            onClicked: toggle.handleClick()
        }
    }
}
