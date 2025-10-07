import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool isActive: false
    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string section: "right"
    property var clipboardHistoryModal: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    width: widgetThickness
    height: widgetThickness

    MouseArea {
        id: clipboardArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            root.clicked()
        }
    }

    Rectangle {
        id: clipboardContent

        anchors.fill: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (SettingsData.dankBarNoBackground) {
                return "transparent"
            }

            const baseColor = clipboardArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
        }

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            name: "content_paste"
            size: Theme.barIconSize(barThickness)
            color: Theme.surfaceText
        }
    }
}