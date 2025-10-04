import QtQuick
import qs.Common

Item {
    id: root

    property var widgetsModel: null
    property var components: null
    property bool noBackground: false
    required property var axis
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48

    readonly property bool isVertical: axis?.isVertical ?? false

    implicitHeight: layoutLoader.item ? layoutLoader.item.implicitHeight : 0
    implicitWidth: layoutLoader.item ? layoutLoader.item.implicitWidth : 0

    Loader {
        id: layoutLoader
        width: parent.width
        height: parent.height
        sourceComponent: root.isVertical ? columnComp : rowComp
    }

    Component {
        id: rowComp
        Row {
            spacing: noBackground ? 2 : Theme.spacingXS
            anchors.right: parent ? parent.right : undefined
            Repeater {
                model: root.widgetsModel
                Item {
                    width: widgetLoader.item ? widgetLoader.item.width : 0
                    height: widgetLoader.item ? widgetLoader.item.height : 0
                    WidgetHost {
                        id: widgetLoader
                        anchors.verticalCenter: parent.verticalCenter
                        widgetId: model.widgetId
                        widgetData: model
                        spacerSize: model.size || 20
                        components: root.components
                        isInColumn: false
                        axis: root.axis
                        section: "right"
                        parentScreen: root.parentScreen
                        widgetThickness: root.widgetThickness
                        barThickness: root.barThickness
                    }
                }
            }
        }
    }

    Component {
        id: columnComp
        Column {
            width: parent ? parent.width : 0
            spacing: noBackground ? 2 : Theme.spacingXS
            Repeater {
                model: root.widgetsModel
                Item {
                    width: parent.width
                    height: widgetLoader.item ? widgetLoader.item.height : 0
                    WidgetHost {
                        id: widgetLoader
                        anchors.horizontalCenter: parent.horizontalCenter
                        widgetId: model.widgetId
                        widgetData: model
                        spacerSize: model.size || 20
                        components: root.components
                        isInColumn: true
                        axis: root.axis
                        section: "right"
                        parentScreen: root.parentScreen
                        widgetThickness: root.widgetThickness
                        barThickness: root.barThickness
                    }
                }
            }
        }
    }
}