import QtQuick
import qs.Common
import qs.Widgets

DankPopout {
    id: root

    property var triggerScreen: null
    property Component pluginContent: null
    property real contentWidth: 400
    property real contentHeight: 400

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    popupWidth: contentWidth
    popupHeight: contentHeight
    screen: triggerScreen
    shouldBeVisible: false
    visible: shouldBeVisible

    content: Component {
        Rectangle {
            id: popoutContainer

            implicitHeight: popoutColumn.implicitHeight + Theme.spacingL * 2
            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            border.width: 0
            antialiasing: true
            smooth: true
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus()
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(() => {
                            popoutContainer.forceActiveFocus()
                        })
                    }
                }
            }

            Column {
                id: popoutColumn
                width: parent.width - Theme.spacingS * 2
                height: parent.height - Theme.spacingS * 2
                x: Theme.spacingS
                y: Theme.spacingS
                spacing: Theme.spacingS

                Loader {
                    id: popoutContent
                    width: parent.width
                    sourceComponent: root.pluginContent

                    onLoaded: {
                        if (item && "closePopout" in item) {
                            item.closePopout = function() {
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
