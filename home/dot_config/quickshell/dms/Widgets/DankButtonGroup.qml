import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root

    property var model: []
    property int currentIndex: -1
    property string selectionMode: "single"
    property bool multiSelect: selectionMode === "multi"
    property bool checkEnabled: true

    signal selectionChanged(int index, bool selected)

    spacing: Theme.spacingXS

    function isSelected(index) {
        if (multiSelect) {
            return repeater.itemAt(index)?.selected || false
        }
        return index === currentIndex
    }

    function selectItem(index) {
        if (multiSelect) {
            const item = repeater.itemAt(index)
            if (item) {
                item.selected = !item.selected
                selectionChanged(index, item.selected)
            }
        } else {
            const oldIndex = currentIndex
            currentIndex = index
            selectionChanged(index, true)
            if (oldIndex !== index && oldIndex >= 0) {
                selectionChanged(oldIndex, false)
            }
        }
    }

    Repeater {
        id: repeater
        model: root.model

        delegate: Rectangle {
            id: segment

            property bool selected: multiSelect ? false : (index === root.currentIndex)
            property bool hovered: mouseArea.containsMouse
            property bool pressed: mouseArea.pressed
            property bool isFirst: index === 0
            property bool isLast: index === repeater.count - 1
            property bool prevSelected: index > 0 ? root.isSelected(index - 1) : false
            property bool nextSelected: index < repeater.count - 1 ? root.isSelected(index + 1) : false

            width: Math.max(contentItem.implicitWidth + Theme.spacingL * 2, 64) + (selected ? 4 : 0)
            height: 40

            color: selected ? Theme.primaryContainer : Theme.primary
            border.color: "transparent"
            border.width: 0

            topLeftRadius: (isFirst || selected) ? Theme.cornerRadius : 4
            bottomLeftRadius: (isFirst || selected) ? Theme.cornerRadius : 4
            topRightRadius: (isLast || selected) ? Theme.cornerRadius : 4
            bottomRightRadius: (isLast || selected) ? Theme.cornerRadius : 4

            Behavior on width {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on topLeftRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on topRightRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on bottomLeftRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on bottomRightRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                id: stateLayer
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                bottomLeftRadius: parent.bottomLeftRadius
                topRightRadius: parent.topRightRadius
                bottomRightRadius: parent.bottomRightRadius
                color: {
                    if (pressed) return selected ? Theme.primaryPressed : Theme.surfacePressed
                    if (hovered) return selected ? Theme.primaryHover : Theme.surfaceHover
                    return "transparent"
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shorterDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Item {
                id: contentItem
                anchors.centerIn: parent
                implicitWidth: contentRow.implicitWidth
                implicitHeight: contentRow.implicitHeight

                Row {
                    id: contentRow
                    spacing: Theme.spacingS

                    DankIcon {
                        id: checkIcon
                        name: "check"
                        size: Theme.iconSizeSmall
                        color: segment.selected ? Theme.surfaceText : Theme.primaryText
                        visible: root.checkEnabled && segment.selected
                        opacity: segment.selected ? 1 : 0
                        scale: segment.selected ? 1 : 0.6

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }

                    StyledText {
                        id: buttonText
                        text: typeof modelData === "string" ? modelData : modelData.text || ""
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: segment.selected ? Font.Medium : Font.Normal
                        color: segment.selected ? Theme.surfaceText : Theme.primaryText
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectItem(index)
            }
        }
    }
}