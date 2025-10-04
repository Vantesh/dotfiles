import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    property string value: defaultValue

    width: parent.width
    spacing: Theme.spacingS

    function loadValue() {
        const settings = findSettings()
        if (settings && settings.pluginService) {
            value = settings.loadValue(settingKey, defaultValue)
        }
    }

    Component.onCompleted: {
        loadValue()
    }

    readonly property var optionLabels: {
        const labels = []
        for (let i = 0; i < options.length; i++) {
            labels.push(options[i].label || options[i])
        }
        return labels
    }

    readonly property var valueToLabel: {
        const map = {}
        for (let i = 0; i < options.length; i++) {
            const opt = options[i]
            if (typeof opt === 'object') {
                map[opt.value] = opt.label
            } else {
                map[opt] = opt
            }
        }
        return map
    }

    readonly property var labelToValue: {
        const map = {}
        for (let i = 0; i < options.length; i++) {
            const opt = options[i]
            if (typeof opt === 'object') {
                map[opt.label] = opt.value
            } else {
                map[opt] = opt
            }
        }
        return map
    }

    onValueChanged: {
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

    DankDropdown {
        width: parent.width
        text: root.label
        description: root.description
        currentValue: root.valueToLabel[root.value] || root.value
        options: root.optionLabels
        onValueChanged: newValue => {
            root.value = root.labelToValue[newValue] || newValue
        }
    }
}
