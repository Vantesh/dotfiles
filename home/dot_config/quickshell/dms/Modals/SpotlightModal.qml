import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modules.AppDrawer
import qs.Services
import qs.Widgets

DankModal {
    id: spotlightModal

    property bool spotlightOpen: false
    property Component spotlightContent

    function show() {
        spotlightOpen = true
        open()
        if (contentLoader.item && contentLoader.item.appLauncher)
            contentLoader.item.appLauncher.searchQuery = ""

        Qt.callLater(function () {
            if (contentLoader.item && contentLoader.item.searchField)
                contentLoader.item.searchField.forceActiveFocus()
        })
    }

    function hide() {
        spotlightOpen = false
        close()
        if (contentLoader.item && contentLoader.item.appLauncher) {
            contentLoader.item.appLauncher.searchQuery = ""
            contentLoader.item.appLauncher.selectedIndex = 0
            contentLoader.item.appLauncher.setCategory("All")
        }
    }

    function toggle() {
        if (spotlightOpen)
            hide()
        else
            show()
    }

    shouldBeVisible: spotlightOpen

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== spotlightModal && !allowStacking
                    && spotlightOpen) {
                spotlightOpen = false
            }
        }
    }
    width: 550
    height: 600
    backgroundColor: Theme.popupBackground()
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    onVisibleChanged: {
        if (visible && !spotlightOpen)
            show()

        if (visible && contentLoader.item)
            Qt.callLater(function () {
                if (contentLoader.item.searchField)
                    contentLoader.item.searchField.forceActiveFocus()
            })
    }
    onBackgroundClicked: {
        hide()
    }
    Component.onCompleted: {

    }
    content: spotlightContent

    IpcHandler {
        function open() {
            spotlightModal.show()
            return "SPOTLIGHT_OPEN_SUCCESS"
        }

        function close() {
            spotlightModal.hide()
            return "SPOTLIGHT_CLOSE_SUCCESS"
        }

        function toggle() {
            spotlightModal.toggle()
            return "SPOTLIGHT_TOGGLE_SUCCESS"
        }

        target: "spotlight"
    }

    spotlightContent: Component {
        Item {
            id: spotlightKeyHandler

            property alias appLauncher: appLauncher
            property alias searchField: searchField

            anchors.fill: parent
            focus: true
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    hide()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    appLauncher.selectNext()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    appLauncher.selectPrevious()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right
                           && appLauncher.viewMode === "grid") {
                    appLauncher.selectNextInRow()
                    event.accepted = true
                } else if (event.key === Qt.Key_Left
                           && appLauncher.viewMode === "grid") {
                    appLauncher.selectPreviousInRow()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return
                           || event.key === Qt.Key_Enter) {
                    appLauncher.launchSelected()
                    event.accepted = true
                } else if (!searchField.activeFocus && event.text
                           && event.text.length > 0 && event.text.match(
                               /[a-zA-Z0-9\\s]/)) {
                    searchField.forceActiveFocus()
                    searchField.insertText(event.text)
                    event.accepted = true
                }
            }

            AppLauncher {
                id: appLauncher

                viewMode: SettingsData.spotlightModalViewMode
                gridColumns: 4
                onAppLaunched: hide()
                onViewModeSelected: function (mode) {
                    SettingsData.setSpotlightModalViewMode(mode)
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                Rectangle {
                    width: parent.width
                    height: categorySelector.height + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceVariantAlpha
                    border.color: Theme.outlineMedium
                    border.width: 1
                    visible: appLauncher.categories.length > 1
                             || appLauncher.model.count > 0

                    CategorySelector {
                        id: categorySelector

                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        categories: appLauncher.categories
                        selectedCategory: appLauncher.selectedCategory
                        compact: false
                        onCategorySelected: category => {
                                                return appLauncher.setCategory(
                                                    category)
                                            }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankTextField {
                        id: searchField

                        width: parent.width - 80
                               - Theme.spacingM // Leave space for view toggle buttons
                        height: 56
                        cornerRadius: Theme.cornerRadius
                        backgroundColor: Qt.rgba(
                                             Theme.surfaceVariant.r,
                                             Theme.surfaceVariant.g,
                                             Theme.surfaceVariant.b,
                                             Theme.getContentBackgroundAlpha(
                                                 ) * 0.7)
                        normalBorderColor: Theme.outlineMedium
                        focusedBorderColor: Theme.primary
                        leftIconName: "search"
                        leftIconSize: Theme.iconSize
                        leftIconColor: Theme.surfaceVariantText
                        leftIconFocusedColor: Theme.primary
                        showClearButton: true
                        textColor: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeLarge
                        enabled: spotlightOpen
                        placeholderText: ""
                        ignoreLeftRightKeys: true
                        keyForwardTargets: [spotlightKeyHandler]
                        text: appLauncher.searchQuery
                        onTextEdited: {
                            appLauncher.searchQuery = text
                        }
                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Escape) {
                                                hide()
                                                event.accepted = true
                                            } else if ((event.key === Qt.Key_Return
                                                        || event.key === Qt.Key_Enter)
                                                       && text.length > 0) {
                                                if (appLauncher.keyboardNavigationActive
                                                    && appLauncher.model.count > 0)
                                                appLauncher.launchSelected()
                                                else if (appLauncher.model.count > 0)
                                                appLauncher.launchApp(
                                                    appLauncher.model.get(0))
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Right || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length === 0)) {
                                                event.accepted = false
                                            }
                                        }
                    }

                    Row {
                        spacing: Theme.spacingXS
                        visible: appLauncher.model.count > 0
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 36
                            height: 36
                            radius: Theme.cornerRadius
                            color: appLauncher.viewMode === "list" ? Theme.primaryHover : listViewArea.containsMouse ? Theme.surfaceHover : "transparent"
                            border.color: appLauncher.viewMode
                                          === "list" ? Theme.primarySelected : "transparent"
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: "view_list"
                                size: 18
                                color: appLauncher.viewMode
                                       === "list" ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: listViewArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    appLauncher.setViewMode("list")
                                }
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 36
                            radius: Theme.cornerRadius
                            color: appLauncher.viewMode === "grid" ? Theme.primaryHover : gridViewArea.containsMouse ? Theme.surfaceHover : "transparent"
                            border.color: appLauncher.viewMode
                                          === "grid" ? Theme.primarySelected : "transparent"
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: "grid_view"
                                size: 18
                                color: appLauncher.viewMode
                                       === "grid" ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: gridViewArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    appLauncher.setViewMode("grid")
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: resultsContainer

                    width: parent.width
                    height: parent.height - y
                    radius: Theme.cornerRadius
                    color: Theme.surfaceLight
                    border.color: Theme.outlineLight
                    border.width: 1

                    DankListView {
                        id: resultsList

                        property int itemHeight: 60
                        property int iconSize: 40
                        property bool showDescription: true
                        property int itemSpacing: Theme.spacingS
                        property bool hoverUpdatesSelection: false
                        property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive

                        signal keyboardNavigationReset
                        signal itemClicked(int index, var modelData)
                        signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                        function ensureVisible(index) {
                            if (index < 0 || index >= count)
                                return

                            var itemY = index * (itemHeight + itemSpacing)
                            var itemBottom = itemY + itemHeight
                            if (itemY < contentY)
                                contentY = itemY
                            else if (itemBottom > contentY + height)
                                contentY = itemBottom - height
                        }

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        visible: appLauncher.viewMode === "list"
                        model: appLauncher.model
                        currentIndex: appLauncher.selectedIndex
                        clip: true
                        spacing: itemSpacing
                        focus: true
                        interactive: true
                        cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
                        reuseItems: true
                        onCurrentIndexChanged: {
                            if (keyboardNavigationActive)
                                ensureVisible(currentIndex)
                        }
                        onItemClicked: function (index, modelData) {
                            appLauncher.launchApp(modelData)
                        }
                        onItemRightClicked: function (index, modelData, mouseX, mouseY) {
                            contextMenu.show(mouseX, mouseY, modelData)
                        }
                        onKeyboardNavigationReset: {
                            appLauncher.keyboardNavigationActive = false
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOn
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: resultsList.itemHeight
                            radius: Theme.cornerRadius
                            color: ListView.isCurrentItem ? Theme.primaryPressed : listMouseArea.containsMouse ? Theme.primaryHoverLight : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.03)
                            border.color: ListView.isCurrentItem ? Theme.primarySelected : Theme.outlineMedium
                            border.width: ListView.isCurrentItem ? 2 : 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingL

                                Item {
                                    width: resultsList.iconSize
                                    height: resultsList.iconSize
                                    anchors.verticalCenter: parent.verticalCenter

                                    IconImage {
                                        id: listIconImg

                                        anchors.fill: parent
                                        source: (model.icon) ? Quickshell.iconPath(
                                                                   model.icon,
                                                                   SettingsData.iconTheme === "System Default" ? "" : SettingsData.iconTheme) : ""
                                        smooth: true
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: !listIconImg.visible
                                        color: Theme.surfaceLight
                                        radius: Theme.cornerRadius
                                        border.width: 1
                                        border.color: Theme.primarySelected

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: (model.name
                                                   && model.name.length
                                                   > 0) ? model.name.charAt(
                                                              0).toUpperCase(
                                                              ) : "A"
                                            font.pixelSize: resultsList.iconSize * 0.4
                                            color: Theme.primary
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - resultsList.iconSize - Theme.spacingL
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        width: parent.width
                                        text: model.name || ""
                                        font.pixelSize: Theme.fontSizeLarge
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: model.comment || "Application"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        visible: resultsList.showDescription
                                                 && model.comment
                                                 && model.comment.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                id: listMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                z: 10
                                onEntered: {
                                    if (resultsList.hoverUpdatesSelection
                                            && !resultsList.keyboardNavigationActive)
                                        resultsList.currentIndex = index
                                }
                                onPositionChanged: {
                                    resultsList.keyboardNavigationReset()
                                }
                                onClicked: mouse => {
                                               if (mouse.button === Qt.LeftButton) {
                                                   resultsList.itemClicked(
                                                       index, model)
                                               } else if (mouse.button === Qt.RightButton) {
                                                   var modalPos = mapToItem(
                                                       spotlightKeyHandler,
                                                       mouse.x, mouse.y)
                                                   resultsList.itemRightClicked(
                                                       index, model,
                                                       modalPos.x, modalPos.y)
                                               }
                                           }
                            }
                        }
                    }

                    DankGridView {
                        id: resultsGrid

                        property int currentIndex: appLauncher.selectedIndex
                        property int columns: 4
                        property bool adaptiveColumns: false
                        property int minCellWidth: 120
                        property int maxCellWidth: 160
                        property int cellPadding: 8
                        property real iconSizeRatio: 0.55
                        property int maxIconSize: 48
                        property int minIconSize: 32
                        property bool hoverUpdatesSelection: false
                        property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive
                        property int baseCellWidth: adaptiveColumns ? Math.max(
                                                                          minCellWidth,
                                                                          Math.min(maxCellWidth, width / columns)) : (width - Theme.spacingS * 2) / columns
                        property int baseCellHeight: baseCellWidth + 20
                        property int actualColumns: adaptiveColumns ? Math.floor(
                                                                          width
                                                                          / cellWidth) : columns
                        property int remainingSpace: width - (actualColumns * cellWidth)

                        signal keyboardNavigationReset
                        signal itemClicked(int index, var modelData)
                        signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                        function ensureVisible(index) {
                            if (index < 0 || index >= count)
                                return

                            var itemY = Math.floor(
                                        index / actualColumns) * cellHeight
                            var itemBottom = itemY + cellHeight
                            if (itemY < contentY)
                                contentY = itemY
                            else if (itemBottom > contentY + height)
                                contentY = itemBottom - height
                        }

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        visible: appLauncher.viewMode === "grid"
                        model: appLauncher.model
                        clip: true
                        cellWidth: baseCellWidth
                        cellHeight: baseCellHeight
                        leftMargin: Math.max(Theme.spacingS, remainingSpace / 2)
                        rightMargin: leftMargin
                        focus: true
                        interactive: true
                        cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
                        reuseItems: true
                        onCurrentIndexChanged: {
                            if (keyboardNavigationActive)
                                ensureVisible(currentIndex)
                        }
                        onItemClicked: function (index, modelData) {
                            appLauncher.launchApp(modelData)
                        }
                        onItemRightClicked: function (index, modelData, mouseX, mouseY) {
                            contextMenu.show(mouseX, mouseY, modelData)
                        }
                        onKeyboardNavigationReset: {
                            appLauncher.keyboardNavigationActive = false
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }

                        delegate: Rectangle {
                            width: resultsGrid.cellWidth - resultsGrid.cellPadding
                            height: resultsGrid.cellHeight - resultsGrid.cellPadding
                            radius: Theme.cornerRadius
                            color: resultsGrid.currentIndex === index ? Theme.primaryPressed : gridMouseArea.containsMouse ? Theme.primaryHoverLight : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.03)
                            border.color: resultsGrid.currentIndex
                                          === index ? Theme.primarySelected : Theme.outlineMedium
                            border.width: resultsGrid.currentIndex === index ? 2 : 1

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                Item {
                                    property int iconSize: Math.min(
                                                               resultsGrid.maxIconSize,
                                                               Math.max(
                                                                   resultsGrid.minIconSize,
                                                                   resultsGrid.cellWidth
                                                                   * resultsGrid.iconSizeRatio))

                                    width: iconSize
                                    height: iconSize
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    IconImage {
                                        id: gridIconImg

                                        anchors.fill: parent
                                        source: (model.icon) ? Quickshell.iconPath(
                                                                   model.icon,
                                                                   SettingsData.iconTheme === "System Default" ? "" : SettingsData.iconTheme) : ""
                                        smooth: true
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: !gridIconImg.visible
                                        color: Theme.surfaceLight
                                        radius: Theme.cornerRadius
                                        border.width: 1
                                        border.color: Theme.primarySelected

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: (model.name
                                                   && model.name.length
                                                   > 0) ? model.name.charAt(
                                                              0).toUpperCase(
                                                              ) : "A"
                                            font.pixelSize: Math.min(
                                                                28,
                                                                parent.width * 0.5)
                                            color: Theme.primary
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: resultsGrid.cellWidth - 12
                                    text: model.name || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                id: gridMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                z: 10
                                onEntered: {
                                    if (resultsGrid.hoverUpdatesSelection
                                            && !resultsGrid.keyboardNavigationActive)
                                        resultsGrid.currentIndex = index
                                }
                                onPositionChanged: {
                                    resultsGrid.keyboardNavigationReset()
                                }
                                onClicked: mouse => {
                                               if (mouse.button === Qt.LeftButton) {
                                                   resultsGrid.itemClicked(
                                                       index, model)
                                               } else if (mouse.button === Qt.RightButton) {
                                                   var modalPos = mapToItem(
                                                       spotlightKeyHandler,
                                                       mouse.x, mouse.y)
                                                   resultsGrid.itemRightClicked(
                                                       index, model,
                                                       modalPos.x, modalPos.y)
                                               }
                                           }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: contextMenu

                property var currentApp: null
                property bool menuVisible: false

                function show(x, y, app) {
                    currentApp = app

                    const menuWidth = 180
                    const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2
                    let finalX = x + 8
                    let finalY = y + 8

                    if (finalX + menuWidth > spotlightKeyHandler.width) {
                        finalX = x - menuWidth - 8
                    }

                    if (finalY + menuHeight > spotlightKeyHandler.height) {
                        finalY = y - menuHeight - 8
                    }

                    finalX = Math.max(
                                8, Math.min(
                                    finalX,
                                    spotlightKeyHandler.width - menuWidth - 8))
                    finalY = Math.max(
                                8, Math.min(
                                    finalY,
                                    spotlightKeyHandler.height - menuHeight - 8))

                    contextMenu.x = finalX
                    contextMenu.y = finalY
                    contextMenu.visible = true
                    contextMenu.menuVisible = true
                }

                function close() {
                    contextMenu.menuVisible = false
                    Qt.callLater(() => {
                                     contextMenu.visible = false
                                 })
                }

                visible: false
                width: 180
                height: menuColumn.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Theme.popupBackground()
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.08)
                border.width: 1
                z: 1000
                opacity: menuVisible ? 1 : 0
                scale: menuVisible ? 1 : 0.85

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.leftMargin: 2
                    anchors.rightMargin: -2
                    anchors.bottomMargin: -4
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, 0.15)
                    z: parent.z - 1
                }

                Column {
                    id: menuColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: 1

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: pinMouseArea.containsMouse ? Qt.rgba(
                                                                Theme.primary.r,
                                                                Theme.primary.g,
                                                                Theme.primary.b,
                                                                0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: {
                                    if (!contextMenu.currentApp
                                            || !contextMenu.currentApp.desktopEntry)
                                        return "push_pin"

                                    var appId = contextMenu.currentApp.desktopEntry.id
                                            || contextMenu.currentApp.desktopEntry.execString
                                            || ""
                                    return SessionData.isPinnedApp(
                                                appId) ? "keep_off" : "push_pin"
                                }
                                size: Theme.iconSize - 2
                                color: Theme.surfaceText
                                opacity: 0.7
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: {
                                    if (!contextMenu.currentApp
                                            || !contextMenu.currentApp.desktopEntry)
                                        return "Pin to Dock"

                                    var appId = contextMenu.currentApp.desktopEntry.id
                                            || contextMenu.currentApp.desktopEntry.execString
                                            || ""
                                    return SessionData.isPinnedApp(
                                                appId) ? "Unpin from Dock" : "Pin to Dock"
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: pinMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!contextMenu.currentApp
                                        || !contextMenu.currentApp.desktopEntry)
                                    return

                                var appId = contextMenu.currentApp.desktopEntry.id
                                        || contextMenu.currentApp.desktopEntry.execString
                                        || ""
                                if (SessionData.isPinnedApp(appId))
                                    SessionData.removePinnedApp(appId)
                                else
                                    SessionData.addPinnedApp(appId)
                                contextMenu.close()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - Theme.spacingS * 2
                        height: 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                           Theme.outline.b, 0.2)
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: launchMouseArea.containsMouse ? Qt.rgba(
                                                                   Theme.primary.r,
                                                                   Theme.primary.g,
                                                                   Theme.primary.b,
                                                                   0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "launch"
                                size: Theme.iconSize - 2
                                color: Theme.surfaceText
                                opacity: 0.7
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Launch"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: launchMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (contextMenu.currentApp)
                                    appLauncher.launchApp(
                                                contextMenu.currentApp)

                                contextMenu.close()
                            }
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: contextMenu.visible
                z: 999
                onClicked: {
                    contextMenu.close()
                }

                MouseArea {
                    x: contextMenu.x
                    y: contextMenu.y
                    width: contextMenu.width
                    height: contextMenu.height
                    onClicked: {

                        // Prevent closing when clicking on the menu itself
                    }
                }
            }
        }
    }
}
