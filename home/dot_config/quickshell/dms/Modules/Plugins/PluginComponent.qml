import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var axis: null
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property string pluginId: ""
    property var pluginService: null

    property Component horizontalBarPill: null
    property Component verticalBarPill: null
    property Component popoutContent: null
    property real popoutWidth: 400
    property real popoutHeight: 400
    property var pillClickAction: null

    property var pluginData: ({})

    readonly property bool isVertical: axis?.isVertical ?? false
    readonly property bool hasHorizontalPill: horizontalBarPill !== null
    readonly property bool hasVerticalPill: verticalBarPill !== null
    readonly property bool hasPopout: popoutContent !== null

    Component.onCompleted: {
        loadPluginData()
    }

    onPluginServiceChanged: {
        loadPluginData()
    }

    onPluginIdChanged: {
        loadPluginData()
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === pluginId) {
                loadPluginData()
            }
        }
    }

    function loadPluginData() {
        if (!pluginService || !pluginId) {
            pluginData = {}
            return
        }
        pluginData = SettingsData.getPluginSettingsForPlugin(pluginId)
    }

    width: isVertical ? (hasVerticalPill ? verticalPill.width : 0) : (hasHorizontalPill ? horizontalPill.width : 0)
    height: isVertical ? (hasVerticalPill ? verticalPill.height : 0) : (hasHorizontalPill ? horizontalPill.height : 0)

    BasePill {
        id: horizontalPill
        visible: !isVertical && hasHorizontalPill
        axis: root.axis
        section: root.section
        popoutTarget: hasPopout ? pluginPopout : null
        parentScreen: root.parentScreen
        widgetThickness: root.widgetThickness
        barThickness: root.barThickness
        content: root.horizontalBarPill
        onClicked: {
            if (pillClickAction) {
                if (pillClickAction.length === 0) {
                    pillClickAction()
                } else {
                    const globalPos = mapToGlobal(0, 0)
                    const currentScreen = parentScreen || Screen
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                    pillClickAction(pos.x, pos.y, pos.width, section, currentScreen)
                }
            } else if (hasPopout) {
                pluginPopout.toggle()
            }
        }
    }

    BasePill {
        id: verticalPill
        visible: isVertical && hasVerticalPill
        axis: root.axis
        section: root.section
        popoutTarget: hasPopout ? pluginPopout : null
        parentScreen: root.parentScreen
        widgetThickness: root.widgetThickness
        barThickness: root.barThickness
        content: root.verticalBarPill
        isVerticalOrientation: true
        onClicked: {
            if (pillClickAction) {
                if (pillClickAction.length === 0) {
                    pillClickAction()
                } else {
                    const globalPos = mapToGlobal(0, 0)
                    const currentScreen = parentScreen || Screen
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                    pillClickAction(pos.x, pos.y, pos.width, section, currentScreen)
                }
            } else if (hasPopout) {
                pluginPopout.toggle()
            }
        }
    }

    function closePopout() {
        if (pluginPopout) {
            pluginPopout.close()
        }
    }

    PluginPopout {
        id: pluginPopout
        contentWidth: root.popoutWidth
        contentHeight: root.popoutHeight
        pluginContent: root.popoutContent
    }
}
