import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property string placeholder: ""
    property string defaultValue: ""
    property string value: defaultValue

    width: parent.width
    spacing: Theme.spacingS

    property bool isInitialized: false

    function loadValue() {
        const settings = findSettings()
        if (settings && settings.pluginService) {
            const loadedValue = settings.loadValue(settingKey, defaultValue)
            value = loadedValue
            textField.text = loadedValue
            isInitialized = true
        }
    }

    onValueChanged: {
        if (!isInitialized) return
        const settings = findSettings()
        if (settings) {
            settings.saveValue(settingKey, value)
        }
    }

    function findSettings() {
        let item = parent
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) {
                return item
            }
            item = item.parent
        }
        return null
    }

    StyledText {
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
        visible: root.description !== ""
    }

    DankTextField {
        id: textField
        width: parent.width
        placeholderText: root.placeholder
        onTextEdited: {
            root.value = text
        }
        onEditingFinished: {
            root.value = text
        }
        onActiveFocusChanged: {
            if (!activeFocus) {
                root.value = text
            }
        }
    }
}
