import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

DankModal {
    id: clipboardHistoryModal

    property int totalCount: 0
    property var activeTheme: Theme
    property bool showClearConfirmation: false
    property var clipboardEntries: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool keyboardNavigationActive: false
    property bool showKeyboardHints: false
    property Component clipboardContent

    function updateFilteredModel() {
        filteredClipboardModel.clear()
        for (var i = 0; i < clipboardModel.count; i++) {
            const entry = clipboardModel.get(i).entry
            if (searchText.trim().length === 0) {
                filteredClipboardModel.append({
                                                  "entry": entry
                                              })
            } else {
                const content = getEntryPreview(entry).toLowerCase()
                if (content.includes(searchText.toLowerCase()))
                    filteredClipboardModel.append({
                                                      "entry": entry
                                                  })
            }
        }
        clipboardHistoryModal.totalCount = filteredClipboardModel.count
        // Clamp selectedIndex to valid range
        if (filteredClipboardModel.count === 0) {
            keyboardNavigationActive = false
            selectedIndex = 0
        } else if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = filteredClipboardModel.count - 1
        }
    }

    function toggle() {
        if (shouldBeVisible)
            hide()
        else
            show()
    }

    function show() {
        open()
        clipboardHistoryModal.searchText = ""

        initializeThumbnailSystem()
        refreshClipboard()
        keyboardController.reset()

        Qt.callLater(function () {
            if (contentLoader.item && contentLoader.item.searchField) {
                contentLoader.item.searchField.text = ""
                contentLoader.item.searchField.forceActiveFocus()
            }
        })
    }

    function hide() {
        close()
        clipboardHistoryModal.searchText = ""

        updateFilteredModel()
        keyboardController.reset()
        cleanupTempFiles()
    }

    function initializeThumbnailSystem() {}

    function cleanupTempFiles() {
        Quickshell.execDetached(["sh", "-c", "rm -f /tmp/clipboard_*.png"])
    }

    function generateThumbnails() {}

    function refreshClipboard() {
        clipboardProcess.running = true
    }

    function copyEntry(entry) {
        const entryId = entry.split('\t')[0]
        Quickshell.execDetached(
                    ["sh", "-c", `cliphist decode ${entryId} | wl-copy`])
        ToastService.showInfo("Copied to clipboard")
        hide()
    }

    function deleteEntry(entry) {
        deleteProcess.deletedEntry = entry
        deleteProcess.command = ["sh", "-c", `echo '${entry.replace(
                                     /'/g, "'\\''")}' | cliphist delete`]
        deleteProcess.running = true
    }

    function clearAll() {
        clearProcess.running = true
    }

    function getEntryPreview(entry) {
        let content = entry.replace(/^\s*\d+\s+/, "")
        if (content.includes("image/") || content.includes("binary data")
                || /\.(png|jpg|jpeg|gif|bmp|webp)/i.test(content)) {
            const dimensionMatch = content.match(/(\d+)x(\d+)/)
            if (dimensionMatch)
                return `Image ${dimensionMatch[1]}×${dimensionMatch[2]}`

            const typeMatch = content.match(/\b(png|jpg|jpeg|gif|bmp|webp)\b/i)
            if (typeMatch)
                return `Image (${typeMatch[1].toUpperCase()})`

            return "Image"
        }
        if (content.length > 100)
            return content.substring(0, 100) + "..."

        return content
    }

    function getEntryType(entry) {
        if (entry.includes("image/") || entry.includes("binary data")
                || /\.(png|jpg|jpeg|gif|bmp|webp)/i.test(entry)
                || /\b(png|jpg|jpeg|gif|bmp|webp)\b/i.test(entry))
            return "image"

        if (entry.length > 200)
            return "long_text"

        return "text"
    }

    visible: false
    width: 650
    height: 550
    backgroundColor: Theme.popupBackground()
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    onBackgroundClicked: {
        hide()
    }
    modalFocusScope.Keys.onPressed: function (event) {
        keyboardController.handleKey(event)
    }
    content: clipboardContent

    QtObject {
        id: keyboardController

        function reset() {
            selectedIndex = 0
            keyboardNavigationActive = false
            showKeyboardHints = false
            if (typeof clipboardListView !== 'undefined' && clipboardListView)
                clipboardListView.keyboardActive = false
        }

        function selectNext() {
            if (filteredClipboardModel.count === 0)
                return

            keyboardNavigationActive = true
            selectedIndex = Math.min(selectedIndex + 1,
                                     filteredClipboardModel.count - 1)
        }

        function selectPrevious() {
            if (filteredClipboardModel.count === 0)
                return

            keyboardNavigationActive = true
            selectedIndex = Math.max(selectedIndex - 1, 0)
        }

        function copySelected() {
            if (filteredClipboardModel.count === 0 || selectedIndex < 0
                    || selectedIndex >= filteredClipboardModel.count)
                return

            var selectedEntry = filteredClipboardModel.get(selectedIndex).entry
            copyEntry(selectedEntry)
        }

        function deleteSelected() {
            if (filteredClipboardModel.count === 0 || selectedIndex < 0
                    || selectedIndex >= filteredClipboardModel.count)
                return

            var selectedEntry = filteredClipboardModel.get(selectedIndex).entry
            deleteEntry(selectedEntry)
        }

        function handleKey(event) {
            if (event.key === Qt.Key_Escape) {
                if (keyboardNavigationActive) {
                    keyboardNavigationActive = false
                    if (typeof clipboardListView !== 'undefined'
                            && clipboardListView)
                        clipboardListView.keyboardActive = false

                    event.accepted = true
                } else {
                    hide()
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Down) {
                if (!keyboardNavigationActive) {
                    keyboardNavigationActive = true
                    selectedIndex = 0
                    if (typeof clipboardListView !== 'undefined'
                            && clipboardListView)
                        clipboardListView.keyboardActive = true

                    event.accepted = true
                } else {
                    selectNext()
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Up) {
                if (!keyboardNavigationActive) {
                    keyboardNavigationActive = true
                    selectedIndex = 0
                    if (typeof clipboardListView !== 'undefined'
                            && clipboardListView)
                        clipboardListView.keyboardActive = true

                    event.accepted = true
                } else if (selectedIndex === 0) {
                    keyboardNavigationActive = false
                    if (typeof clipboardListView !== 'undefined'
                            && clipboardListView)
                        clipboardListView.keyboardActive = false

                    event.accepted = true
                } else {
                    selectPrevious()
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Delete
                       && (event.modifiers & Qt.ShiftModifier)) {
                clearAll()
                hide()
                event.accepted = true
            } else if (keyboardNavigationActive) {
                if ((event.key === Qt.Key_C
                     && (event.modifiers & Qt.ControlModifier))
                        || event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter) {
                    copySelected()
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete) {
                    deleteSelected()
                    event.accepted = true
                }
            }
            if (event.key === Qt.Key_F10) {
                showKeyboardHints = !showKeyboardHints
                event.accepted = true
            }
        }
    }

    DankModal {
        id: clearConfirmDialog

        visible: showClearConfirmation
        width: 350
        height: 150
        onBackgroundClicked: {
            showClearConfirmation = false
        }

        content: Component {
            Item {
                anchors.fill: parent

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Clear All History?"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "This will permanently delete all clipboard history."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.WordWrap
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 100
                            height: 40
                            radius: Theme.cornerRadius
                            color: cancelClearButton.containsMouse ? Theme.surfaceTextPressed : Theme.surfaceVariantAlpha

                            StyledText {
                                text: "Cancel"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: cancelClearButton

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showClearConfirmation = false
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 40
                            radius: Theme.cornerRadius
                            color: confirmClearButton.containsMouse ? Theme.errorPressed : Theme.error

                            StyledText {
                                text: "Clear All"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primaryText
                                font.weight: Font.Medium
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: confirmClearButton

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    clearAll()
                                    showClearConfirmation = false
                                    hide()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: clipboardModel
    }

    ListModel {
        id: filteredClipboardModel
    }

    Process {
        id: clipboardProcess

        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                clipboardModel.clear()
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.trim().length > 0)
                        clipboardModel.append({
                                                  "entry": line
                                              })
                }
                updateFilteredModel()
            }
        }
    }

    Process {
        id: deleteProcess

        property string deletedEntry: ""

        running: false
        onExited: exitCode => {
                      if (exitCode === 0) {
                          // Just remove the item from models instead of re-fetching everything
                          for (var i = 0; i < clipboardModel.count; i++) {
                              if (clipboardModel.get(
                                      i).entry === deleteProcess.deletedEntry) {
                                  clipboardModel.remove(i)
                                  break
                              }
                          }
                          for (var j = 0; j < filteredClipboardModel.count; j++) {
                              if (filteredClipboardModel.get(
                                      j).entry === deleteProcess.deletedEntry) {
                                  filteredClipboardModel.remove(j)
                                  break
                              }
                          }
                          clipboardHistoryModal.totalCount = filteredClipboardModel.count
                          // Clamp selectedIndex to valid range
                          if (filteredClipboardModel.count === 0) {
                              keyboardNavigationActive = false
                              selectedIndex = 0
                          } else if (selectedIndex >= filteredClipboardModel.count) {
                              selectedIndex = filteredClipboardModel.count - 1
                          }
                      } else {
                          console.warn("Failed to delete clipboard entry")
                      }
                  }
    }

    Process {
        id: clearProcess

        command: ["cliphist", "wipe"]
        running: false
        onExited: exitCode => {
                      if (exitCode === 0) {
                          clipboardModel.clear()
                          filteredClipboardModel.clear()
                          totalCount = 0
                      } else {

                      }
                  }
    }

    IpcHandler {
        function open() {
            clipboardHistoryModal.show()
            return "CLIPBOARD_OPEN_SUCCESS"
        }

        function close() {
            hide()
            return "CLIPBOARD_CLOSE_SUCCESS"
        }

        function toggle() {
            clipboardHistoryModal.toggle()
            return "CLIPBOARD_TOGGLE_SUCCESS"
        }

        target: "clipboard"
    }

    clipboardContent: Component {
        Item {
            id: clipboardContent
            property alias searchField: searchField

            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL
                focus: false

                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "content_paste"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `Clipboard History (${totalCount})`
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankActionButton {
                            iconName: "info"
                            iconSize: Theme.iconSize - 4
                            iconColor: showKeyboardHints ? Theme.primary : Theme.surfaceText
                            hoverColor: Theme.primaryHover
                            onClicked: {
                                showKeyboardHints = !showKeyboardHints
                            }
                        }

                        DankActionButton {
                            iconName: "delete_sweep"
                            iconSize: Theme.iconSize
                            iconColor: Theme.error
                            hoverColor: Theme.errorHover
                            onClicked: {
                                showClearConfirmation = true
                            }
                        }

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            hoverColor: Theme.errorHover
                            onClicked: hide()
                        }
                    }
                }

                DankTextField {
                    id: searchField

                    width: parent.width
                    placeholderText: ""
                    leftIconName: "search"
                    showClearButton: true
                    focus: true
                    ignoreLeftRightKeys: true
                    keyForwardTargets: [modalFocusScope]
                    onTextChanged: {
                        clipboardHistoryModal.searchText = text
                        updateFilteredModel()
                    }
                    Keys.onEscapePressed: function (event) {
                        hide()
                        event.accepted = true
                    }
                    Component.onCompleted: {
                        Qt.callLater(function () {
                            forceActiveFocus()
                        })
                    }

                    Connections {
                        target: clipboardHistoryModal
                        function onOpened() {
                            Qt.callLater(function () {
                                searchField.forceActiveFocus()
                            })
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - 110
                    radius: Theme.cornerRadius
                    color: Theme.surfaceLight
                    border.color: Theme.outlineLight
                    border.width: 1
                    clip: true

                    DankListView {
                        id: clipboardListView

                        function ensureVisible(index) {
                            if (index < 0 || index >= count)
                                return

                            var itemHeight = 72 + spacing
                            var itemY = index * itemHeight
                            var itemBottom = itemY + itemHeight
                            if (itemY < contentY)
                                contentY = itemY
                            else if (itemBottom > contentY + height)
                                contentY = itemBottom - height
                        }

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        clip: true
                        model: filteredClipboardModel
                        currentIndex: selectedIndex
                        spacing: Theme.spacingXS
                        interactive: true
                        flickDeceleration: 1500
                        maximumFlickVelocity: 2000
                        boundsBehavior: Flickable.DragAndOvershootBounds
                        boundsMovement: Flickable.FollowBoundsBehavior
                        pressDelay: 0
                        flickableDirection: Flickable.VerticalFlick
                        onCurrentIndexChanged: {
                            if (keyboardNavigationActive && currentIndex >= 0)
                                ensureVisible(currentIndex)
                        }

                        StyledText {
                            text: "No clipboard entries found"
                            anchors.centerIn: parent
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            visible: filteredClipboardModel.count === 0
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }

                        delegate: Rectangle {
                            property string entryType: getEntryType(model.entry)
                            property string entryPreview: getEntryPreview(
                                                              model.entry)
                            property int entryIndex: index + 1
                            property string entryData: model.entry
                            property alias thumbnailImageSource: thumbnailImageSource

                            width: clipboardListView.width
                            height: 72
                            radius: Theme.cornerRadius
                            color: {
                                if (keyboardNavigationActive
                                        && index === selectedIndex)
                                    return Qt.rgba(Theme.surfaceVariant.r,
                                                   Theme.surfaceVariant.g,
                                                   Theme.surfaceVariant.b, 0.2)

                                return mouseArea.containsMouse ? Theme.primaryHover : Theme.primaryBackground
                            }
                            border.color: {
                                if (keyboardNavigationActive
                                        && index === selectedIndex)
                                    return Qt.rgba(Theme.primary.r,
                                                   Theme.primary.g,
                                                   Theme.primary.b, 0.5)

                                return Theme.outlineStrong
                            }
                            border.width: keyboardNavigationActive
                                          && index === selectedIndex ? 1.5 : 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingL

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: Theme.primarySelected
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: entryIndex.toString()
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 68
                                    spacing: Theme.spacingM

                                    Item {
                                        width: entryType === "image" ? 48 : Theme.iconSize
                                        height: entryType === "image" ? 48 : Theme.iconSize
                                        anchors.verticalCenter: parent.verticalCenter

                                        CachingImage {
                                            id: thumbnailImageSource

                                            property string entryId: model.entry.split(
                                                                         '\t')[0]

                                            anchors.fill: parent
                                            source: entryType === "image"
                                                    && imageLoader.imageData ? `data:image/png;base64,${imageLoader.imageData}` : ""
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            cache: true
                                            visible: false
                                            asynchronous: true

                                            Process {
                                                id: imageLoader

                                                property string imageData: ""

                                                command: ["sh", "-c", `cliphist decode ${thumbnailImageSource.entryId} | base64 -w 0`]
                                                running: entryType === "image"

                                                stdout: StdioCollector {
                                                    onStreamFinished: {
                                                        imageLoader.imageData = text.trim()
                                                    }
                                                }
                                            }
                                        }

                                        MultiEffect {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: thumbnailImageSource
                                            maskEnabled: true
                                            maskSource: clipboardCircularMask
                                            visible: entryType === "image"
                                                     && thumbnailImageSource.status === Image.Ready
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1
                                        }

                                        Item {
                                            id: clipboardCircularMask

                                            width: 48 - 4
                                            height: 48 - 4
                                            layer.enabled: true
                                            layer.smooth: true
                                            visible: false

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: width / 2
                                                color: "black"
                                                antialiasing: true
                                            }
                                        }

                                        DankIcon {
                                            visible: !(entryType === "image"
                                                       && thumbnailImageSource.status
                                                       === Image.Ready)
                                            name: {
                                                if (entryType === "image")
                                                    return "image"

                                                if (entryType === "long_text")
                                                    return "subject"

                                                return "content_copy"
                                            }
                                            size: Theme.iconSize
                                            color: Theme.primary
                                            anchors.centerIn: parent
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - (entryType === "image" ? 48 : Theme.iconSize) - Theme.spacingM
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: {
                                                switch (entryType) {
                                                case "image":
                                                    return "Image • " + entryPreview
                                                case "long_text":
                                                    return "Long Text"
                                                default:
                                                    return "Text"
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.primary
                                            font.weight: Font.Medium
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            id: contentText

                                            text: entryPreview
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: entryType === "long_text" ? 3 : 1
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            DankActionButton {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "close"
                                iconSize: Theme.iconSize - 6
                                iconColor: Theme.error
                                hoverColor: Theme.errorHover
                                onClicked: {
                                    deleteEntry(model.entry)
                                }
                            }

                            MouseArea {
                                id: mouseArea

                                anchors.fill: parent
                                anchors.rightMargin: 40
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: copyEntry(model.entry)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: showKeyboardHints ? 80 + Theme.spacingL : 0

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                height: 80
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r,
                               Theme.surfaceContainer.g,
                               Theme.surfaceContainer.b, 0.95)
                border.color: Theme.primary
                border.width: 2
                opacity: showKeyboardHints ? 1 : 0
                z: 100

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    StyledText {
                        text: "↑/↓: Navigate • Enter/Ctrl+C: Copy • Del: Delete • F10: Help"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "Shift+Del: Clear All • Esc: Close"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }
    }
}
