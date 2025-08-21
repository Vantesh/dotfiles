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

    width: (text && !hideText) ? parent.width : 48
    height: (text && !hideText) ? 60 : 24

    StyledRect {
        id: background

        anchors.fill: parent
        radius: (toggle.text && !toggle.hideText) ? Theme.cornerRadius : 0
        color: (toggle.text
                && !toggle.hideText) ? Theme.surfaceHover : "transparent"
        visible: (toggle.text && !toggle.hideText)

        StateLayer {
            visible: (toggle.text && !toggle.hideText)
            disabled: !toggle.enabled
            stateColor: Theme.primary
            cornerRadius: parent.radius
            onClicked: {
                if (toggle.enabled) {
                    toggle.checked = !toggle.checked
                    toggle.clicked()
                    toggle.toggled(toggle.checked)
                }
            }
        }
    }

    Row {
        id: textRow

        anchors.left: parent.left
        anchors.right: toggleTrack.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingXS
        visible: (toggle.text && !toggle.hideText)

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

        width: toggle.text ? 48 : parent.width
        height: toggle.text ? 24 : parent.height
        anchors.right: parent.right
        anchors.rightMargin: toggle.text ? Theme.spacingM : 0
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: (toggle.checked
                && toggle.enabled) ? Theme.primary : Theme.surfaceVariantAlpha
        opacity: toggle.toggling ? 0.6 : (toggle.enabled ? 1 : 0.4)

        StyledRect {
            id: toggleHandle

            width: 20
            height: 20
            radius: 10
            color: Theme.surface
            anchors.verticalCenter: parent.verticalCenter
            x: (toggle.checked && toggle.enabled) ? parent.width - width - 2 : 2

            StyledRect {
                anchors.centerIn: parent
                width: parent.width + 2
                height: parent.height + 2
                radius: (parent.width + 2) / 2
                color: "transparent"
                border.color: Qt.rgba(0, 0, 0, 0.1)
                border.width: 1
                z: -1
            }

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
            onClicked: {
                if (toggle.enabled) {
                    toggle.checked = !toggle.checked
                    toggle.clicked()
                    toggle.toggled(toggle.checked)
                }
            }
        }
    }
}
