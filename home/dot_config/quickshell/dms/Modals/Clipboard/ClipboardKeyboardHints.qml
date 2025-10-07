import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.Clipboard

Rectangle {
    id: keyboardHints

    height: ClipboardConstants.keyboardHintsHeight
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
    border.color: Theme.primary
    border.width: 2
    opacity: visible ? 1 : 0
    z: 100

    Column {
        anchors.centerIn: parent
        spacing: 2

        StyledText {
            text: "↑/↓: Navigate • Enter/Ctrl+C: Copy • Del: Delete • F10: Help"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: qsTr("Shift+Del: Clear All • Esc: Close")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
