import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Services
import qs.Widgets

Item {
    id: themeColorsTab

    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property bool fontsEnumerated: false

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

            var rootName = fontName.replace(
                        / (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i,
                        "").replace(
                        / (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i,
                        "").replace(/ (UI|Display|Text|Mono|Sans|Serif)$/i,
                                    function (match, suffix) {
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
            if (lowerName.includes("mono") || lowerName.includes(
                        "code") || lowerName.includes(
                        "console") || lowerName.includes(
                        "terminal") || lowerName.includes(
                        "courier") || lowerName.includes(
                        "dejavu sans mono") || lowerName.includes(
                        "jetbrains") || lowerName.includes(
                        "fira") || lowerName.includes(
                        "hack") || lowerName.includes(
                        "source code") || lowerName.includes(
                        "ubuntu mono") || lowerName.includes("cascadia")) {
                var rootName2 = fontName2.replace(
                            / (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i,
                            "").replace(
                            / (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i,
                            "").trim()
                if (!seenMonoFamilies.has(rootName2) && rootName2 !== "") {
                    seenMonoFamilies.add(rootName2)
                    monoFamilies.push(rootName2)
                }
            }
        }
        cachedMonoFamilies = monoFonts.concat(monoFamilies.sort())
    }

    Component.onCompleted: {
        if (!fontsEnumerated) {
            enumerateFonts()
            fontsEnumerated = true
        }
    }

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            // Theme Color
            StyledRect {
                width: parent.width
                height: themeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: themeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "palette"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Theme Color"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Current Theme: " + (Theme.currentTheme === Theme.dynamic ? "Dynamic" : Theme.getThemeColors(Theme.currentThemeName).name)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: {
                                if (Theme.currentTheme === Theme.dynamic)
                                    return "Wallpaper-based dynamic colors"

                                var descriptions = {
                                    "blue": "Material blue inspired by modern interfaces",
                                    "deepBlue": "Deep blue inspired by material 3",
                                    "purple": "Rich purple tones for elegance",
                                    "green": "Natural green for productivity",
                                    "orange": "Energetic orange for creativity",
                                    "red": "Bold red for impact",
                                    "cyan": "Cool cyan for tranquility",
                                    "pink": "Vibrant pink for expression",
                                    "amber": "Warm amber for comfort",
                                    "coral": "Soft coral for gentle warmth"
                                }
                                return descriptions[Theme.currentThemeName] || "Select a theme"
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                            wrapMode: Text.WordWrap
                            width: Math.min(parent.width, 400)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Column {
                        spacing: Theme.spacingS
                        anchors.horizontalCenter: parent.horizontalCenter

                        Row {
                            spacing: Theme.spacingM

                            Repeater {
                                model: Theme.availableThemeNames.slice(0, 5)

                                Rectangle {
                                    property string themeName: modelData
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.getThemeColors(themeName).primary
                                    border.color: Theme.outline
                                    border.width: (Theme.currentThemeName === themeName
                                                   && Theme.currentTheme !== Theme.dynamic) ? 2 : 1
                                    scale: (Theme.currentThemeName === themeName
                                            && Theme.currentTheme !== Theme.dynamic) ? 1.1 : 1

                                    Rectangle {
                                        width: nameText.contentWidth + Theme.spacingS * 2
                                        height: nameText.contentHeight + Theme.spacingXS * 2
                                        color: Theme.surfaceContainer
                                        border.color: Theme.outline
                                        border.width: 1
                                        radius: Theme.cornerRadius
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mouseArea.containsMouse

                                        StyledText {
                                            id: nameText

                                            text: Theme.getThemeColors(themeName).name
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: mouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Theme.switchTheme(themeName)
                                        }
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }

                                    Behavior on border.width {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: Theme.spacingM

                            Repeater {
                                model: Theme.availableThemeNames.slice(5, 10)

                                Rectangle {
                                    property string themeName: modelData

                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.getThemeColors(themeName).primary
                                    border.color: Theme.outline
                                    border.width: Theme.currentThemeName === themeName ? 2 : 1
                                    visible: true
                                    scale: Theme.currentThemeName === themeName ? 1.1 : 1

                                    Rectangle {
                                        width: nameText2.contentWidth + Theme.spacingS * 2
                                        height: nameText2.contentHeight + Theme.spacingXS * 2
                                        color: Theme.surfaceContainer
                                        border.color: Theme.outline
                                        border.width: 1
                                        radius: Theme.cornerRadius
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mouseArea2.containsMouse

                                        StyledText {
                                            id: nameText2

                                            text: Theme.getThemeColors(themeName).name
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: mouseArea2

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Theme.switchTheme(themeName)
                                        }
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }

                                    Behavior on border.width {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: 1
                            height: Theme.spacingM
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.spacingL

                            Rectangle {
                                width: 120
                                height: 40
                                radius: 20
                                color: {
                                    if (ToastService.wallpaperErrorStatus === "error"
                                            || ToastService.wallpaperErrorStatus === "matugen_missing")
                                        return Qt.rgba(Theme.error.r,
                                                       Theme.error.g,
                                                       Theme.error.b, 0.12)
                                    else
                                        return Qt.rgba(Theme.surfaceVariant.r,
                                                       Theme.surfaceVariant.g,
                                                       Theme.surfaceVariant.b, 0.3)
                                }
                                border.color: {
                                    if (ToastService.wallpaperErrorStatus === "error"
                                            || ToastService.wallpaperErrorStatus === "matugen_missing")
                                        return Qt.rgba(Theme.error.r,
                                                       Theme.error.g,
                                                       Theme.error.b, 0.5)
                                    else if (Theme.currentThemeName === "dynamic")
                                        return Theme.primary
                                    else
                                        return Theme.outline
                                }
                                border.width: (Theme.currentThemeName === "dynamic") ? 2 : 1
                                scale: (Theme.currentThemeName === "dynamic") ? 1.1 : (autoMouseArea.containsMouse ? 1.02 : 1)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    DankIcon {
                                    name: {
                                        if (ToastService.wallpaperErrorStatus === "error"
                                                || ToastService.wallpaperErrorStatus
                                                === "matugen_missing")
                                            return "error"
                                        else
                                            return "palette"
                                    }
                                    size: 16
                                    color: {
                                        if (ToastService.wallpaperErrorStatus === "error"
                                                || ToastService.wallpaperErrorStatus
                                                === "matugen_missing")
                                            return Theme.error
                                        else
                                            return Theme.surfaceText
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: {
                                        if (ToastService.wallpaperErrorStatus === "error")
                                            return "Error"
                                        else if (ToastService.wallpaperErrorStatus
                                                 === "matugen_missing")
                                            return "No matugen"
                                        else
                                            return "Auto"
                                    }
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: {
                                        if (ToastService.wallpaperErrorStatus === "error"
                                                || ToastService.wallpaperErrorStatus
                                                === "matugen_missing")
                                            return Theme.error
                                        else
                                            return Theme.surfaceText
                                    }
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: autoMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                        ToastService.showError(
                                                    "matugen not found - install matugen package for dynamic theming")
                                    else if (ToastService.wallpaperErrorStatus === "error")
                                        ToastService.showError(
                                                    "Wallpaper processing failed - check wallpaper path")
                                    else
                                        Theme.switchTheme(Theme.dynamic)
                                }
                            }

                            Rectangle {
                                width: autoTooltipText.contentWidth + Theme.spacingM * 2
                                height: autoTooltipText.contentHeight + Theme.spacingS * 2
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 1
                                radius: Theme.cornerRadius
                                anchors.bottom: parent.top
                                anchors.bottomMargin: Theme.spacingS
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: autoMouseArea.containsMouse
                                         && (Theme.currentTheme !== Theme.dynamic
                                             || ToastService.wallpaperErrorStatus === "error"
                                             || ToastService.wallpaperErrorStatus
                                             === "matugen_missing")

                                StyledText {
                                    id: autoTooltipText

                                    text: {
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            return "Install matugen package for dynamic themes"
                                        else
                                            return "Dynamic wallpaper-based colors"
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: (ToastService.wallpaperErrorStatus === "error"
                                            || ToastService.wallpaperErrorStatus
                                            === "matugen_missing") ? Theme.error : Theme.surfaceText
                                    anchors.centerIn: parent
                                    wrapMode: Text.WordWrap
                                    width: Math.min(implicitWidth, 250)
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Rectangle {
                            width: 120
                            height: 40
                            radius: 20
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                            border.color: (Theme.currentThemeName === "custom") ? Theme.primary : Theme.outline
                            border.width: (Theme.currentThemeName === "custom") ? 2 : 1
                            scale: (Theme.currentThemeName === "custom") ? 1.1 : (customMouseArea.containsMouse ? 1.02 : 1)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "folder_open"
                                    size: 16
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Custom"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: customMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    fileBrowserModal.open()
                                }
                            }

                            Rectangle {
                                width: customTooltipText.contentWidth + Theme.spacingM * 2
                                height: customTooltipText.contentHeight + Theme.spacingS * 2
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 1
                                radius: Theme.cornerRadius
                                anchors.bottom: parent.top
                                anchors.bottomMargin: Theme.spacingS
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: customMouseArea.containsMouse

                                StyledText {
                                    id: customTooltipText
                                    text: {
                                        if (Theme.currentThemeName === "custom")
                                            return SettingsData.customThemeFile || "Custom theme loaded"
                                        else
                                            return "Load custom theme from JSON file"
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.centerIn: parent
                                    wrapMode: Text.WordWrap
                                    width: Math.min(implicitWidth, 250)
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }

                            Behavior on border.width {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }
                        }
                        } // Close Row
                    }
                }
            }

            // Transparency Settings
            StyledRect {
                width: parent.width
                height: transparencySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: transparencySection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "opacity"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Transparency Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Top Bar Transparency"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(
                                       SettingsData.topBarTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setTopBarTransparency(
                                                          newValue / 100)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Top Bar Widget Transparency"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(
                                       SettingsData.topBarWidgetTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setTopBarWidgetTransparency(
                                                          newValue / 100)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Popup Transparency"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(
                                       SettingsData.popupTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setPopupTransparency(
                                                          newValue / 100)
                                                  }
                        }
                    }
                }
            }

            // System Configuration Warning
            Rectangle {
                width: parent.width
                height: warningText.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g,
                               Theme.warning.b, 0.12)
                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g,
                                      Theme.warning.b, 0.3)
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: warningText
                        font.pixelSize: Theme.fontSizeSmall
                        text: "The below settings will modify your GTK and Qt settings. If you wish to preserve your current configurations, please back them up (qt5ct.conf|qt6ct.conf and ~/.config/gtk-3.0|gtk-4.0)."
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Icon Theme
            StyledRect {
                width: parent.width
                height: iconThemeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: iconThemeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "image"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankDropdown {
                            width: parent.width - Theme.iconSize - Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Icon Theme"
                            description: "DankShell & System Icons\n(requires restart)"
                            currentValue: SettingsData.iconTheme
                            enableFuzzySearch: true
                            popupWidthOffset: 100
                            maxPopupHeight: 236
                            options: {
                                SettingsData.detectAvailableIconThemes()
                                return SettingsData.availableIconThemes
                            }
                            onValueChanged: value => {
                                                SettingsData.setIconTheme(value)
                                                if (Quickshell.env("QT_QPA_PLATFORMTHEME") != "gtk3" &&
                                                    Quickshell.env("QT_QPA_PLATFORMTHEME") != "qt6ct" &&
                                                    Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") != "qt6ct") {
                                                    ToastService.showError("Missing Environment Variables", "You need to set either:\nQT_QPA_PLATFORMTHEME=gtk3 OR\nQT_QPA_PLATFORMTHEME=qt6ct\nas environment variables, and then restart the shell.\n\nqt6ct requires qt6ct-kde to be installed.")
                                                }
                                            }
                        }
                    }
                }
            }

        }
    }

    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: "Select Custom Theme"
        filterExtensions: ["*.json"]
        showHiddenFiles: true

        function selectCustomTheme() {
            shouldBeVisible = true
        }

        onFileSelected: function(filePath) {
            // Save the custom theme file path and switch to custom theme
            if (filePath.endsWith(".json")) {
                SettingsData.setCustomThemeFile(filePath)
                Theme.switchTheme("custom")
                close()
            }
        }
    }
}
