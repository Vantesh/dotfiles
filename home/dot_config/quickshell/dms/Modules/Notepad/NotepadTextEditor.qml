import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

pragma ComponentBehavior: Bound

Column {
    id: root

    property alias text: textArea.text
    property alias textArea: textArea
    property bool contentLoaded: false
    property string lastSavedContent: ""
    property var currentTab: NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null

    signal saveRequested()
    signal openRequested()
    signal newRequested()
    signal escapePressed()
    signal contentChanged()
    signal settingsRequested()

    function hasUnsavedChanges() {
        if (!currentTab || !contentLoaded) {
            return false
        }

        if (currentTab.isTemporary) {
            return textArea.text.length > 0
        }
        return textArea.text !== lastSavedContent
    }

    function loadCurrentTabContent() {
        if (!currentTab) return

        contentLoaded = false
        NotepadStorageService.loadTabContent(
            NotepadStorageService.currentTabIndex,
            (content) => {
                lastSavedContent = content
                textArea.text = content
                contentLoaded = true
            }
        )
    }

    function saveCurrentTabContent() {
        if (!currentTab || !contentLoaded) return

        NotepadStorageService.saveTabContent(
            NotepadStorageService.currentTabIndex,
            textArea.text
        )
        lastSavedContent = textArea.text
    }

    function autoSaveToSession() {
        if (!currentTab || !contentLoaded) return
        saveCurrentTabContent()
    }

    function setTextDocumentLineHeight() {
        return
    }

    property string lastTextForLineModel: ""
    property var lineModel: []
    
    function updateLineModel() {
        if (!SettingsData.notepadShowLineNumbers) {
            lineModel = []
            lastTextForLineModel = ""
            return
        }
        
        if (textArea.text !== lastTextForLineModel || lineModel.length === 0) {
            lastTextForLineModel = textArea.text
            lineModel = textArea.text.split('\n')
        }
    }

    spacing: Theme.spacingM

    StyledRect {
        width: parent.width
        height: parent.height - bottomControls.height - Theme.spacingM
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.notepadTransparency)
        border.color: Theme.outlineMedium
        border.width: 1
        radius: Theme.cornerRadius

        DankFlickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            contentWidth: width - 11

            Rectangle {
                id: lineNumberArea
                anchors.left: parent.left
                anchors.top: parent.top
                width: SettingsData.notepadShowLineNumbers ? Math.max(30, 32 + Theme.spacingXS) : 0
                height: textArea.contentHeight + textArea.topPadding + textArea.bottomPadding
                color: "transparent"
                visible: SettingsData.notepadShowLineNumbers

                ListView {
                    id: lineNumberList
                    anchors.top: parent.top
                    anchors.topMargin: textArea.topPadding
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: 32
                    height: textArea.contentHeight
                    model: SettingsData.notepadShowLineNumbers ? root.lineModel : []
                    interactive: false
                    spacing: 0

                    delegate: Item {
                        id: lineDelegate
                        required property int index
                        required property string modelData
                        width: 32
                        height: measuringText.contentHeight

                        Text {
                            id: measuringText
                            width: textArea.width - textArea.leftPadding - textArea.rightPadding
                            text: modelData || " "
                            font: textArea.font
                            wrapMode: Text.Wrap
                            visible: false
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.top: parent.top
                            text: index + 1
                            font.family: textArea.font.family
                            font.pixelSize: textArea.font.pixelSize
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            TextArea.flickable: TextArea {
                id: textArea
                placeholderText: qsTr("Start typing your notes here...")
                font.family: SettingsData.notepadUseMonospace ? SettingsData.monoFontFamily : (SettingsData.notepadFontFamily || SettingsData.fontFamily)
                font.pixelSize: SettingsData.notepadFontSize * SettingsData.fontScale
                font.letterSpacing: 0
                color: Theme.surfaceText
                selectByMouse: true
                selectByKeyboard: true
                wrapMode: TextArea.Wrap
                focus: true
                activeFocusOnTab: true
                textFormat: TextEdit.PlainText
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                persistentSelection: true
                tabStopDistance: 40
                leftPadding: (SettingsData.notepadShowLineNumbers ? lineNumberArea.width + Theme.spacingXS : Theme.spacingM)
                topPadding: Theme.spacingM
                rightPadding: Theme.spacingM
                bottomPadding: Theme.spacingM

                Component.onCompleted: {
                    loadCurrentTabContent()
                    setTextDocumentLineHeight()
                    root.updateLineModel()
                }

                Connections {
                    target: NotepadStorageService
                    function onCurrentTabIndexChanged() {
                        loadCurrentTabContent()
                    }
                    function onTabsChanged() {
                        if (NotepadStorageService.tabs.length > 0 && !contentLoaded) {
                            loadCurrentTabContent()
                        }
                    }
                }

                Connections {
                    target: SettingsData
                    function onNotepadShowLineNumbersChanged() {
                        root.updateLineModel()
                    }
                }

                onTextChanged: {
                    if (contentLoaded && text !== lastSavedContent) {
                        autoSaveTimer.restart()
                    }
                    root.contentChanged()
                    root.updateLineModel()
                }

                Keys.onEscapePressed: (event) => {
                    root.escapePressed()
                    event.accepted = true
                }

                Keys.onPressed: (event) => {
                    if (event.modifiers & Qt.ControlModifier) {
                        switch (event.key) {
                        case Qt.Key_S:
                            event.accepted = true
                            root.saveRequested()
                            break
                        case Qt.Key_O:
                            event.accepted = true
                            root.openRequested()
                            break
                        case Qt.Key_N:
                            event.accepted = true
                            root.newRequested()
                            break
                        case Qt.Key_A:
                            event.accepted = true
                            selectAll()
                            break
                        }
                    }
                }

                background: Rectangle {
                    color: "transparent"
                }
            }
        }
    }

    Column {
        id: bottomControls
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingL

                Row {
                    spacing: Theme.spacingS
                    DankActionButton {
                        iconName: "save"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.primary
                        enabled: currentTab && (hasUnsavedChanges() || textArea.text.length > 0)
                        onClicked: root.saveRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Save")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    DankActionButton {
                        iconName: "folder_open"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.secondary
                        onClicked: root.openRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Open")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    DankActionButton {
                        iconName: "note_add"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.surfaceText
                        onClicked: root.newRequested()
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("New")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "more_horiz"
                iconSize: Theme.iconSize - 2
                iconColor: Theme.surfaceText
                onClicked: root.settingsRequested()
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingL

            StyledText {
                text: textArea.text.length > 0 ? qsTr("%1 characters").arg(textArea.text.length) : qsTr("Empty")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            StyledText {
                text: qsTr("Lines: %1").arg(textArea.lineCount)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                visible: textArea.text.length > 0
                opacity: 1.0
            }

            StyledText {
                text: {
                    if (autoSaveTimer.running) {
                        return qsTr("Auto-saving...")
                    }

                    if (hasUnsavedChanges()) {
                        if (currentTab && currentTab.isTemporary) {
                            return qsTr("Unsaved note...")
                        } else {
                            return qsTr("Unsaved changes")
                        }
                    } else {
                        return qsTr("Saved")
                    }
                }
                font.pixelSize: Theme.fontSizeSmall
                color: {
                    if (autoSaveTimer.running) {
                        return Theme.primary
                    }

                    if (hasUnsavedChanges()) {
                        return Theme.warning
                    } else {
                        return Theme.success
                    }
                }
                opacity: textArea.text.length > 0 ? 1.0 : 0.0
            }
        }
    }

    Timer {
        id: autoSaveTimer
        interval: 2000
        repeat: false
        onTriggered: {
            autoSaveToSession()
        }
    }
}