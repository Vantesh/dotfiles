import QtQuick
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

pragma ComponentBehavior: Bound

PanelWindow {
    id: root

    property bool isVisible: false
    property bool fileDialogOpen: false
    property string currentFileName: ""
    property url currentFileUrl
    property var targetScreen: null
    property var modelData: null
    property bool confirmationDialogOpen: false
    property string pendingAction: ""
    property url pendingFileUrl
    property string lastSavedFileContent: ""
    property bool expandedWidth: false
    property var currentTab: NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null
    property string currentContent: ""
    property string lastSavedContent: ""
    property bool contentLoaded: false
    property bool showSettingsMenu: false
    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property bool fontsEnumerated: false
    
    function hasUnsavedChanges() {
        if (!currentTab || !contentLoaded) {
            return false
        }
        
        // For temporary files, show unsaved if there's any content that hasn't been hard-saved
        if (currentTab.isTemporary) {
            return textArea.text.length > 0
        }
        return textArea.text !== lastSavedContent
    }
    
    function hasUnsavedTemporaryContent() {
        return hasUnsavedChanges()
    }
    
    function hasUnsavedChangesForTab(tab) {
        if (!tab) return false
        
        // Only the currently active tab can show real unsaved status
        if (tab.id === currentTab?.id) {
            return hasUnsavedChanges()
        }
        return false
    }
    
    function enumerateFonts() {
        var fonts = ["Default"]
        var availableFonts = Qt.fontFamilies()
        var rootFamilies = []
        var seenFamilies = new Set()
        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i]
            if (fontName.startsWith("."))
                continue

            if (fontName === SettingsData.defaultFontFamily)
                continue

            var rootName = fontName.replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "").replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i,
                                                                                                                                                      "").replace(/ (UI|Display|Text|Mono|Sans|Serif)$/i, function (match, suffix) {
                                                                                                                                                          return match
                                                                                                                                                      }).trim()
            if (!seenFamilies.has(rootName) && rootName !== "") {
                seenFamilies.add(rootName)
                rootFamilies.push(rootName)
            }
        }
        cachedFontFamilies = fonts.concat(rootFamilies.sort())
        var monoFonts = ["Default"]
        var monoFamilies = []
        var seenMonoFamilies = new Set()
        for (var j = 0; j < availableFonts.length; j++) {
            var fontName2 = availableFonts[j]
            if (fontName2.startsWith("."))
                continue

            if (fontName2 === SettingsData.defaultMonoFontFamily)
                continue

            var lowerName = fontName2.toLowerCase()
            if (lowerName.includes("mono") || lowerName.includes("code") || lowerName.includes("console") || lowerName.includes("terminal") || lowerName.includes("courier") || lowerName.includes("dejavu sans mono") || lowerName.includes(
                        "jetbrains") || lowerName.includes("fira") || lowerName.includes("hack") || lowerName.includes("source code") || lowerName.includes("ubuntu mono") || lowerName.includes("cascadia")) {
                var rootName2 = fontName2.replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "").replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i, "").trim()
                if (!seenMonoFamilies.has(rootName2) && rootName2 !== "") {
                    seenMonoFamilies.add(rootName2)
                    monoFamilies.push(rootName2)
                }
            }
        }
        cachedMonoFamilies = monoFonts.concat(monoFamilies.sort())
        fontsEnumerated = true
    }
    
    function loadCurrentTabContent() {
        if (!currentTab) return

        contentLoaded = false
        NotepadStorageService.loadTabContent(
            NotepadStorageService.currentTabIndex,
            (content) => {
                currentContent = content
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
        currentContent = textArea.text
        lastSavedContent = textArea.text
    }

    function autoSaveToSession() {
        if (!currentTab || !contentLoaded) return

        currentContent = textArea.text
        saveCurrentTabContent()
    }
    
    function createNewTab() {
        performCreateNewTab()
    }
    
    function performCreateNewTab() {
        NotepadStorageService.createNewTab()
        textArea.text = ""
        currentContent = ""
        lastSavedContent = ""
        contentLoaded = true
        textArea.forceActiveFocus()
    }
    
    function closeTab(tabIndex) {
        if (tabIndex === NotepadStorageService.currentTabIndex && hasUnsavedChanges()) {
            root.pendingAction = "close_tab_" + tabIndex
            root.confirmationDialogOpen = true
            confirmationDialog.open()
        } else {
            performCloseTab(tabIndex)
        }
    }
    
    function performCloseTab(tabIndex) {
        NotepadStorageService.closeTab(tabIndex)
        Qt.callLater(() => {
            loadCurrentTabContent()
        })
    }
    
    function switchToTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= NotepadStorageService.tabs.length) return

        if (contentLoaded) {
            autoSaveToSession()
        }

        NotepadStorageService.switchToTab(tabIndex)
        Qt.callLater(() => {
            loadCurrentTabContent()
            if (currentTab) {
                root.currentFileName = currentTab.fileName || ""
                root.currentFileUrl = currentTab.fileUrl || ""
            }
        })
    }

    function show() {
        visible = true
        isVisible = true
        textArea.forceActiveFocus()
    }

    function hide() {
        isVisible = false
    }

    function toggle() {
        if (isVisible) {
            hide()
        } else {
            show()
        }
    }

    visible: isVisible
    screen: modelData
    
    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    
    implicitWidth: 960
    implicitHeight: modelData ? modelData.height : 800
    
    color: "transparent"
    
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Component.onCompleted: {
        if (!fontsEnumerated) {
            enumerateFonts()
        }
    }

    StyledRect {
        id: contentRect
        
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: expandedWidth ? 960 : 480
        color: Theme.surfaceContainer
        border.color: Theme.outlineMedium
        border.width: 1
        opacity: isVisible ? SettingsData.popupTransparency : 0
        
        Behavior on opacity {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }
        
        transform: Translate {
            id: slideTransform
            x: isVisible ? 0 : contentRect.width
            
            Behavior on x {
                NumberAnimation {
                    id: slideAnimation
                    duration: 450
                    easing.type: Easing.OutCubic
                    
                    onRunningChanged: {
                        if (!running && !isVisible) {
                            root.visible = false
                        }
                    }
                }
            }
        }
        
        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            // Header
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                
                // Title row
                Row {
                    width: parent.width
                    height: 32

                    Column {
                        width: parent.width - buttonRow.width
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        
                        StyledText {
                            text: qsTr("Notepad")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        id: buttonRow
                        spacing: Theme.spacingXS
                        
                        DankActionButton {
                            id: expandButton
                            iconName: root.expandedWidth ? "unfold_less" : "unfold_more"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.expandedWidth = !root.expandedWidth
                            
                            transform: Rotation {
                                angle: 90
                                origin.x: expandButton.width / 2
                                origin.y: expandButton.height / 2
                            }
                        }
                        
                        DankActionButton {
                            id: closeButton
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.hide()
                        }
                    }
                }
                
                // Tab bar
                Row {
                    width: parent.width
                    height: 36
                    spacing: Theme.spacingXS
                    
                    ScrollView {
                        width: parent.width - newTabButton.width - Theme.spacingXS
                        height: parent.height
                        clip: true
                        
                        ScrollBar.horizontal.visible: false
                        ScrollBar.vertical.visible: false
                        
                        Row {
                            spacing: Theme.spacingXS
                            
                            Repeater {
                                model: NotepadStorageService.tabs
                                
                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    
                                    readonly property bool isActive: NotepadStorageService.currentTabIndex === index
                                    readonly property bool isHovered: tabMouseArea.containsMouse && !closeMouseArea.containsMouse
                                    readonly property real calculatedWidth: {
                                        const textWidth = tabText.paintedWidth || 100
                                        const closeButtonWidth = NotepadStorageService.tabs.length > 1 ? 20 : 0
                                        const spacing = Theme.spacingXS
                                        const padding = Theme.spacingM * 2
                                        return Math.max(120, Math.min(200, textWidth + closeButtonWidth + spacing + padding))
                                    }
                                    
                                    width: calculatedWidth
                                    height: 32
                                    radius: Theme.cornerRadius
                                    color: isActive ? Theme.primaryPressed : isHovered ? Theme.primaryHoverLight : "transparent"
                                    border.width: isActive ? 0 : 1
                                    border.color: Theme.outlineMedium
                                    
                                    MouseArea {
                                        id: tabMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton
                                        
                                        onClicked: switchToTab(index)
                                    }
                                    
                                    Row {
                                        id: tabContent
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        
                                        StyledText {
                                            id: tabText
                                            text: {
                                                var prefix = ""
                                                if (hasUnsavedChangesForTab(modelData)) {
                                                    prefix = "● "  
                                                }
                                                return prefix + (modelData.title || "Untitled")
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: isActive ? Theme.primary : Theme.surfaceText
                                            font.weight: isActive ? Font.Medium : Font.Normal
                                            elide: Text.ElideMiddle
                                            maximumLineCount: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Rectangle {
                                            id: tabCloseButton
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: closeMouseArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                                            visible: NotepadStorageService.tabs.length > 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            
                                            DankIcon {
                                                name: "close"
                                                size: 14
                                                color: Theme.surfaceTextMedium
                                                anchors.centerIn: parent
                                            }
                                            
                                            MouseArea {
                                                id: closeMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                z: 100
                                                
                                                onClicked: {
                                                    closeTab(index)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.standardEasing
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    DankActionButton {
                        id: newTabButton
                        width: 32
                        height: 32
                        iconName: "add"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: createNewTab()
                    }
                }
            }

            // Text area
            StyledRect {
                width: parent.width
                height: parent.height - 180
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
                        focus: root.isVisible
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
                            if (currentTab) {
                                root.currentFileName = currentTab.fileName || ""
                                root.currentFileUrl = currentTab.fileUrl || ""
                            }
                        }
                        
                        Connections {
                            target: NotepadStorageService
                            function onCurrentTabIndexChanged() {
                                loadCurrentTabContent()
                                if (currentTab) {
                                    root.currentFileName = currentTab.fileName || ""
                                    root.currentFileUrl = currentTab.fileUrl || ""
                                }
                            }
                            function onTabsChanged() {
                                if (NotepadStorageService.tabs.length > 0 && !contentLoaded) {
                                    loadCurrentTabContent()
                                    if (currentTab) {
                                        root.currentFileName = currentTab.fileName || ""
                                        root.currentFileUrl = currentTab.fileUrl || ""
                                    }
                                }
                            }
                        }
                        
                        onTextChanged: {
                            if (contentLoaded && text !== lastSavedContent) {
                                autoSaveTimer.restart()
                            }
                        }
                        
                        Keys.onEscapePressed: (event) => {
                            root.hide()
                            event.accepted = true
                        }
                        
                        Keys.onPressed: (event) => {
                            if (event.modifiers & Qt.ControlModifier) {
                                switch (event.key) {
                                case Qt.Key_S:
                                    event.accepted = true
                                    if (currentTab && !currentTab.isTemporary && currentTab.filePath) {
                                        // For non-temporary tabs, save directly to the original file
                                        var fileUrl = "file://" + currentTab.filePath
                                        saveToFile(fileUrl)
                                    } else {
                                        // For temporary tabs or new files, open save dialog
                                        root.fileDialogOpen = true
                                        saveBrowser.open()
                                    }
                                    break
                                case Qt.Key_O:
                                    event.accepted = true
                                    if (hasUnsavedChanges()) {
                                        root.pendingAction = "open"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        root.fileDialogOpen = true
                                        loadBrowser.open()
                                    }
                                    break
                                case Qt.Key_N:
                                    event.accepted = true
                                    if (hasUnsavedChanges()) {
                                        root.pendingAction = "new"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        createNewTab()
                                    }
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

            // Bottom controls
            Column {
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
                                onClicked: {
                                    root.fileDialogOpen = true
                                    saveBrowser.open()
                                }
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
                                onClicked: {
                                    if (hasUnsavedChanges()) {
                                        root.pendingAction = "open"
                                        root.confirmationDialogOpen = true
                                        confirmationDialog.open()
                                    } else {
                                        root.fileDialogOpen = true
                                        loadBrowser.open()
                                    }
                                }
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
                                onClicked: createNewTab()
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
                        id: settingsButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "more_horiz"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.surfaceText
                        onClicked: showSettingsMenu = !showSettingsMenu
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
        }
        
        MouseArea {
            anchors.fill: parent
            visible: showSettingsMenu
            onClicked: showSettingsMenu = false
            z: 50
        }
        
        // Settings Menu Popup
        Rectangle {
            id: settingsMenu
            visible: showSettingsMenu
            anchors.horizontalCenter: parent.horizontalCenter
            y: 423
            width: 360 
            height: settingsColumn.implicitHeight + Theme.spacingXL * 2 
            radius: Theme.cornerRadius
            color: Theme.popupBackground()
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1
            z: 100

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
                id: settingsColumn
                width: parent.width - Theme.spacingXL * 2 
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingXL 
                spacing: Theme.spacingS  
                
                Rectangle {
                    width: parent.width
                    height: 36
                    color: "transparent"
                    
                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: -Theme.spacingXS 
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notepad Font Settings"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }
                
                DankToggle {
                    anchors.left: parent.left
                    anchors.leftMargin: -Theme.spacingM 
                    width: parent.width + Theme.spacingM 
                    text: "Use Monospace Font"
                    description: "Toggle fonts"
                    checked: SettingsData.notepadUseMonospace
                    onToggled: checked => {
                        SettingsData.notepadUseMonospace = checked
                    }
                }

                Rectangle {
                    width: parent.width
                    height: visible ? (fontDropdown.height + Theme.spacingS) : 0
                    color: "transparent"
                    visible: !SettingsData.notepadUseMonospace
                    
                    DankDropdown {
                        id: fontDropdown
                        anchors.left: parent.left
                        anchors.leftMargin: -Theme.spacingM 
                        width: parent.width + Theme.spacingM 
                        text: "Font Family"
                        options: cachedFontFamilies
                        currentValue: {
                            if (!SettingsData.notepadFontFamily || SettingsData.notepadFontFamily === "")
                                return "Default (Global)"
                            else
                                return SettingsData.notepadFontFamily
                        }
                        enableFuzzySearch: true
                        onValueChanged: value => {
                            if (value && (value.startsWith("Default") || value === "Default (Global)")) {
                                SettingsData.notepadFontFamily = ""
                            } else {
                                SettingsData.notepadFontFamily = value
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: fontSizeRow.height + Theme.spacingS
                    color: "transparent"
                    
                    Row {
                        id: fontSizeRow
                        width: parent.width
                        spacing: Theme.spacingS
                        
                        Column {
                            width: parent.width - fontSizeControls.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            
                            StyledText {
                                text: "Font Size"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            
                            StyledText {
                                text: SettingsData.notepadFontSize + "px"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }
                        
                        Row {
                            id: fontSizeControls
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            
                            DankActionButton {
                                buttonSize: 32
                                iconName: "remove"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.notepadFontSize > 8
                                backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newSize = Math.max(8, SettingsData.notepadFontSize - 1)
                                    SettingsData.notepadFontSize = newSize
                                }
                            }
                            
                            Rectangle {
                                width: 60
                                height: 32
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 1
                                
                                StyledText {
                                    anchors.centerIn: parent
                                    text: SettingsData.notepadFontSize + "px"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                            
                            DankActionButton {
                                buttonSize: 32
                                iconName: "add"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.notepadFontSize < 48
                                backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newSize = Math.min(48, SettingsData.notepadFontSize + 1)
                                    SettingsData.notepadFontSize = newSize
                                }
                            }
                        }
                    }
                }
                
                StyledText {
                    width: parent.width
                    text: SettingsData.notepadUseMonospace ? 
                        "Using global monospace font from Settings → Personalization" :
                        "Global fonts can be configured in Settings → Personalization"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    wrapMode: Text.WordWrap
                    opacity: 0.8
                }
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
    

    property string pendingSaveContent: ""
    
    function saveToFile(fileUrl) {
        if (!currentTab) return

        var content = textArea.text
        var filePath = fileUrl.toString().replace(/^file:\/\//, '')

        saveFileView.path = ""
        pendingSaveContent = content
        saveFileView.path = filePath

        Qt.callLater(() => {
            saveFileView.setText(pendingSaveContent)
        })
    }
    
    function loadFromFile(fileUrl) {
        if (hasUnsavedTemporaryContent()) {
            root.pendingFileUrl = fileUrl
            root.pendingAction = "load_file"
            root.confirmationDialogOpen = true
            confirmationDialog.open()
        } else {
            performLoadFromFile(fileUrl)
        }
    }
    
    function performLoadFromFile(fileUrl) {
        const filePath = fileUrl.toString().replace(/^file:\/\//, '')
        const fileName = filePath.split('/').pop()

        loadFileView.path = ""
        loadFileView.path = filePath

        // Wait for the file to be loaded before reading
        if (loadFileView.waitForJob()) {
            Qt.callLater(() => {
                var content = loadFileView.text()
                if (currentTab && content !== undefined && content !== null) {
                    textArea.text = content
                    currentContent = content
                    lastSavedContent = content
                    contentLoaded = true
                    root.lastSavedFileContent = content
                    
                    NotepadStorageService.updateTabMetadata(NotepadStorageService.currentTabIndex, {
                        title: fileName,
                        filePath: filePath,
                        isTemporary: false
                    })
                    
                    root.currentFileName = fileName
                    root.currentFileUrl = fileUrl
                    saveCurrentTabContent()
                }
            })
        }
    }

    FileView {
        id: saveFileView
        blockWrites: true      
        preload: false         
        atomicWrites: true     
        printErrors: true      

        onSaved: {
            if (currentTab && saveFileView.path && pendingSaveContent) {
                NotepadStorageService.updateTabMetadata(NotepadStorageService.currentTabIndex, {
                    hasUnsavedChanges: false,
                    lastSavedContent: pendingSaveContent
                })
                root.lastSavedFileContent = pendingSaveContent
                pendingSaveContent = ""
            }
        }

        onSaveFailed: (error) => {
            pendingSaveContent = ""
        }
    }

    FileView {
        id: loadFileView
        blockLoading: true     
        preload: true          
        atomicWrites: true     
        printErrors: true      

        onLoadFailed: (error) => {
        }
    }

    FileBrowserModal {
        id: saveBrowser

        browserTitle: qsTr("Save Notepad File")
        browserIcon: "save"
        browserType: "notepad_save"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true
        saveMode: true
        defaultFileName: {
            if (currentTab && currentTab.title && currentTab.title !== "Untitled") {
                return currentTab.title
            } else if (currentTab && !currentTab.isTemporary && currentTab.filePath) {
                return currentTab.filePath.split('/').pop()
            } else {
                return "note.txt"
            }
        }
        
        WlrLayershell.layer: WlrLayershell.Overlay
        
        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath
            
            root.currentFileName = fileName
            root.currentFileUrl = fileUrl

            if (currentTab) {
                NotepadStorageService.saveTabAs(
                    NotepadStorageService.currentTabIndex,
                    cleanPath
                )
            }

            saveToFile(fileUrl)
            
            if (root.pendingAction === "new") {
                Qt.callLater(() => {
                    createNewTab()
                })
            } else if (root.pendingAction === "open") {
                Qt.callLater(() => {
                    root.fileDialogOpen = true
                    loadBrowser.open()
                })
            } else if (root.pendingAction.startsWith("close_tab_")) {
                Qt.callLater(() => {
                    var tabIndex = parseInt(root.pendingAction.split("_")[2])
                    performCloseTab(tabIndex)
                })
            }
            root.pendingAction = ""
            
            close()
        }
        
        onDialogClosed: {
            root.fileDialogOpen = false
        }
    }

    FileBrowserModal {
        id: loadBrowser

        browserTitle: qsTr("Open Notepad File")
        browserIcon: "folder_open"
        browserType: "notepad_load"
        fileExtensions: ["*.txt", "*.md", "*.*"]
        allowStacking: true
        
        WlrLayershell.layer: WlrLayershell.Overlay
        
        onFileSelected: (path) => {
            root.fileDialogOpen = false
            const cleanPath = path.toString().replace(/^file:\/\//, '')
            const fileName = cleanPath.split('/').pop()
            const fileUrl = "file://" + cleanPath
            
            root.currentFileName = fileName
            root.currentFileUrl = fileUrl
            
            loadFromFile(fileUrl)
            close()
        }
        
        onDialogClosed: {
            root.fileDialogOpen = false
        }
    }

    DankModal {
        id: confirmationDialog

        width: 400
        height: 180
        shouldBeVisible: false
        allowStacking: true

        onBackgroundClicked: {
            close()
            root.confirmationDialogOpen = false
        }

        content: Component {
            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    confirmationDialog.close()
                    root.confirmationDialogOpen = false
                    event.accepted = true
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width

                        Column {
                            width: parent.width - 40
                            spacing: Theme.spacingXS

                            StyledText {
                                text: qsTr("Unsaved Changes")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: root.pendingAction === "new" ? 
                                      qsTr("You have unsaved changes. Save before creating a new file?") :
                                      root.pendingAction.startsWith("close_tab_") ?
                                      qsTr("You have unsaved changes. Save before closing this tab?") :
                                      root.pendingAction === "load_file" || root.pendingAction === "open" ?
                                      qsTr("You have unsaved changes. Save before opening a file?") :
                                      qsTr("You have unsaved changes. Save before continuing?")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceTextMedium
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                        }

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: {
                                confirmationDialog.close()
                                root.confirmationDialogOpen = false
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            Rectangle {
                                width: Math.max(80, discardText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: Theme.cornerRadius
                                color: discardArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                                border.color: Theme.surfaceVariantAlpha
                                border.width: 1

                                StyledText {
                                    id: discardText
                                    anchors.centerIn: parent
                                    text: qsTr("Don't Save")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: discardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmationDialog.close()
                                        root.confirmationDialogOpen = false
                                        if (root.pendingAction === "new") {
                                            createNewTab()
                                        } else if (root.pendingAction === "open") {
                                            root.fileDialogOpen = true
                                            loadBrowser.open()
                                        } else if (root.pendingAction === "load_file") {
                                            performLoadFromFile(root.pendingFileUrl)
                                        } else if (root.pendingAction.startsWith("close_tab_")) {
                                            var tabIndex = parseInt(root.pendingAction.split("_")[2])
                                            performCloseTab(tabIndex)
                                        }
                                        root.pendingAction = ""
                                        root.pendingFileUrl = ""
                                    }
                                }
                            }

                            Rectangle {
                                width: Math.max(70, saveAsText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: Theme.cornerRadius
                                color: saveAsArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                                StyledText {
                                    id: saveAsText
                                    anchors.centerIn: parent
                                    text: qsTr("Save")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.background
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: saveAsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        confirmationDialog.close()
                                        root.confirmationDialogOpen = false
                                        root.fileDialogOpen = true
                                        saveBrowser.open()
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
    }
}