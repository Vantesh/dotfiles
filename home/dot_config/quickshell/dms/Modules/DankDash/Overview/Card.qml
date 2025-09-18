import QtQuick
import QtQuick.Controls
import qs.Common

Rectangle {
    id: card
    
    property int pad: Theme.spacingM
    
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    default property alias content: contentItem.data

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: card.pad
    }
}