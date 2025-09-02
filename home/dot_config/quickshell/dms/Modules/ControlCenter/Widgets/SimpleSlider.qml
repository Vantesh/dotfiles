import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Row {
    id: root

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property real value: 0.0
    property real maximumValue: 1.0
    property real minimumValue: 0.0
    property bool enabled: true
    property bool allowIconClick: false
    
    signal sliderValueChanged(real value)
    signal iconClicked()

    height: 60
    spacing: Theme.spacingM

    DankIcon {
        name: root.iconName
        size: Theme.iconSize
        color: root.iconColor
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            visible: root.allowIconClick
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    DankSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: {
            if (parent.width <= 0) return 80
            return Math.max(80, Math.min(400, parent.width - Theme.iconSize - Theme.spacingM))
        }
        enabled: root.enabled
        minimum: Math.round(root.minimumValue * 100)
        maximum: Math.round(root.maximumValue * 100)
        value: Math.round(root.value * 100)
        onSliderValueChanged: function(newValue) { root.sliderValueChanged(newValue / 100.0) }
    }
}