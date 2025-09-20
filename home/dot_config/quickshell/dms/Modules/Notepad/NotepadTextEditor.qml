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

    spacing: Theme.spacingM

    StyledRect {
        width: parent.width
        height: parent.height - bottomControls.height - Theme.spacingM
        color: Theme.surface
        border.color: Theme.outlineMedium
        border.width: 1
        radius: Theme.cornerRadius

        ScrollView {
            anchors.fill: parent
            anchors.margins: 1
            clip: true

            TextArea {
                id: textArea
                placeholderText: qsTr("Start typing your notes here...")
                font.family: SettingsData.notepadUseMonospace ? SettingsData.monoFontFamily : (SettingsData.notepadFontFamily || SettingsData.fontFamily)
                font.pixelSize: SettingsData.notepadFontSize * SettingsData.fontScale
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
                leftPadding: Theme.spacingM
                topPadding: Theme.spacingM
                rightPadding: Theme.spacingM
                bottomPadding: Theme.spacingM

                Component.onCompleted: {
                    loadCurrentTabContent()
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

                onTextChanged: {
                    if (contentLoaded && text !== lastSavedContent) {
                        autoSaveTimer.restart()
                    }
                    root.contentChanged()
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
                opacity: textArea.text.length > 0 ? 1 : 0
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