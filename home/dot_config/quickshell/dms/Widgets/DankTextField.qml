import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property alias text: textInput.text
    property string placeholderText: ""
    property alias font: textInput.font
    property alias textColor: textInput.color
    property alias selectByMouse: textInput.selectByMouse
    property alias enabled: textInput.enabled
    property alias echoMode: textInput.echoMode
    property alias verticalAlignment: textInput.verticalAlignment
    property alias cursorVisible: textInput.cursorVisible
    property alias readOnly: textInput.readOnly
    property alias validator: textInput.validator
    property alias inputMethodHints: textInput.inputMethodHints
    property alias maximumLength: textInput.maximumLength
    property string leftIconName: ""
    property int leftIconSize: Theme.iconSize
    property color leftIconColor: Theme.surfaceVariantText
    property color leftIconFocusedColor: Theme.primary
    property bool showClearButton: false
    property color backgroundColor: Qt.rgba(Theme.surfaceContainer.r,
                                            Theme.surfaceContainer.g,
                                            Theme.surfaceContainer.b, 0.9)
    property color focusedBorderColor: Theme.primary
    property color normalBorderColor: Theme.outlineStrong
    property color placeholderColor: Theme.outlineButton
    property int borderWidth: 1
    property int focusedBorderWidth: 2
    property real cornerRadius: Theme.cornerRadius
    readonly property real leftPadding: Theme.spacingM
                                        + (leftIconName ? leftIconSize + Theme.spacingM : 0)
    readonly property real rightPadding: Theme.spacingM + (showClearButton
                                                           && text.length
                                                           > 0 ? 24 + Theme.spacingM : 0)
    property real topPadding: Theme.spacingM
    property real bottomPadding: Theme.spacingM
    property bool ignoreLeftRightKeys: false
    property var keyForwardTargets: []

    signal textEdited
    signal editingFinished
    signal accepted
    signal focusStateChanged(bool hasFocus)

    function getActiveFocus() {
        return textInput.activeFocus
    }

    function getFocus() {
        return textInput.focus
    }

    function setFocus(value) {
        textInput.focus = value
    }

    function forceActiveFocus() {
        textInput.forceActiveFocus()
    }

    function selectAll() {
        textInput.selectAll()
    }

    function clear() {
        textInput.clear()
    }

    function paste() {
        textInput.paste()
    }

    function copy() {
        textInput.copy()
    }

    function cut() {
        textInput.cut()
    }

    function insertText(str) {
        textInput.insert(textInput.cursorPosition, str)
    }

    function clearFocus() {
        textInput.focus = false
    }

    width: 200
    height: 48
    radius: cornerRadius
    color: backgroundColor
    border.color: textInput.activeFocus ? focusedBorderColor : normalBorderColor
    border.width: textInput.activeFocus ? focusedBorderWidth : borderWidth

    DankIcon {
        id: leftIcon

        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        name: leftIconName
        size: leftIconSize
        color: textInput.activeFocus ? leftIconFocusedColor : leftIconColor
        visible: leftIconName !== ""
    }

    TextInput {
        id: textInput

        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: !root.ignoreLeftRightKeys
        clip: true
        onTextChanged: root.textEdited()
        onEditingFinished: root.editingFinished()
        onAccepted: root.accepted()
        onActiveFocusChanged: root.focusStateChanged(activeFocus)
        Keys.forwardTo: root.ignoreLeftRightKeys ? root.keyForwardTargets : []
        Keys.onLeftPressed: function (event) {
            if (root.ignoreLeftRightKeys)
                event.accepted = true
        }
        Keys.onRightPressed: function (event) {
            if (root.ignoreLeftRightKeys)
                event.accepted = true
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
        }
    }

    StyledRect {
        id: clearButton

        width: 24
        height: 24
        radius: 12
        color: clearArea.containsMouse ? Theme.outlineStrong : "transparent"
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        visible: showClearButton && text.length > 0

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 16
            color: clearArea.containsMouse ? Theme.outline : Theme.surfaceVariantText
        }

        MouseArea {
            id: clearArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                textInput.text = ""
            }
        }
    }

    StyledText {
        id: placeholderLabel

        anchors.fill: textInput
        text: root.placeholderText
        font: textInput.font
        color: placeholderColor
        verticalAlignment: textInput.verticalAlignment
        visible: textInput.text.length === 0 && !textInput.activeFocus
        elide: Text.ElideRight
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on border.width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
