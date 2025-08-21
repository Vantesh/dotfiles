import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: root

    property var categories: []
    property string selectedCategory: "All"
    property bool compact: false // For different layout styles

    signal categorySelected(string category)

    height: compact ? 36 : (72 + Theme.spacingS) // Single row vs two rows

    Row {
        visible: compact
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: categories.slice(0, Math.min(categories.length,
                                                8)) // Limit for space

            Rectangle {
                height: 36
                width: (parent.width - (Math.min(
                                            categories.length,
                                            8) - 1) * Theme.spacingS) / Math.min(
                           categories.length, 8)
                radius: Theme.cornerRadius
                color: selectedCategory === modelData ? Theme.primary : "transparent"
                border.color: selectedCategory === modelData ? "transparent" : Qt.rgba(
                                                                   Theme.outline.r,
                                                                   Theme.outline.g,
                                                                   Theme.outline.b,
                                                                   0.3)

                StyledText {
                    anchors.centerIn: parent
                    text: modelData
                    color: selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        selectedCategory = modelData
                        categorySelected(modelData)
                    }
                }
            }
        }
    }

    Column {
        visible: !compact
        width: parent.width
        spacing: Theme.spacingS

        Row {
            property var firstRowCategories: categories.slice(
                                                 0, Math.min(4,
                                                             categories.length))

            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: parent.firstRowCategories

                Rectangle {
                    height: 36
                    width: (parent.width - (parent.firstRowCategories.length - 1)
                            * Theme.spacingS) / parent.firstRowCategories.length
                    radius: Theme.cornerRadius
                    color: selectedCategory === modelData ? Theme.primary : "transparent"
                    border.color: selectedCategory
                                  === modelData ? "transparent" : Qt.rgba(
                                                      Theme.outline.r,
                                                      Theme.outline.g,
                                                      Theme.outline.b, 0.3)

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        color: selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedCategory = modelData
                            categorySelected(modelData)
                        }
                    }
                }
            }
        }

        Row {
            property var secondRowCategories: categories.slice(
                                                  4, categories.length)

            width: parent.width
            spacing: Theme.spacingS
            visible: secondRowCategories.length > 0

            Repeater {
                model: parent.secondRowCategories

                Rectangle {
                    height: 36
                    width: (parent.width - (parent.secondRowCategories.length - 1)
                            * Theme.spacingS) / parent.secondRowCategories.length
                    radius: Theme.cornerRadius
                    color: selectedCategory === modelData ? Theme.primary : "transparent"
                    border.color: selectedCategory
                                  === modelData ? "transparent" : Qt.rgba(
                                                      Theme.outline.r,
                                                      Theme.outline.g,
                                                      Theme.outline.b, 0.3)

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        color: selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedCategory = modelData
                            categorySelected(modelData)
                        }
                    }
                }
            }
        }
    }
}
