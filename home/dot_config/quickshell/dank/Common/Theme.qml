pragma Singleton
pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property var themes: [
        {
            "name": "Blue",
            "primary": "#42a5f5",
            "primaryText": "#ffffff",
            "primaryContainer": "#1976d2",
            "secondary": "#8ab4f8",
            "surface": "#1a1c1e",
            "surfaceText": "#e3e8ef",
            "surfaceVariant": "#44464f",
            "surfaceVariantText": "#c4c7c5",
            "surfaceTint": "#8ab4f8",
            "background": "#1a1c1e",
            "backgroundText": "#e3e8ef",
            "outline": "#8e918f",
            "surfaceContainer": "#1e2023",
            "surfaceContainerHigh": "#292b2f"
        },
        {
            "name": "Deep Blue",
            "primary": "#0061a4",
            "primaryText": "#ffffff",
            "primaryContainer": "#004881",
            "secondary": "#42a5f5",
            "surface": "#1a1c1e",
            "surfaceText": "#e3e8ef",
            "surfaceVariant": "#44464f",
            "surfaceVariantText": "#c4c7c5",
            "surfaceTint": "#8ab4f8",
            "background": "#1a1c1e",
            "backgroundText": "#e3e8ef",
            "outline": "#8e918f",
            "surfaceContainer": "#1e2023",
            "surfaceContainerHigh": "#292b2f"
        },
        {
            "name": "Purple",
            "primary": "#D0BCFF",
            "primaryText": "#381E72",
            "primaryContainer": "#4F378B",
            "secondary": "#CCC2DC",
            "surface": "#10121E",
            "surfaceText": "#E6E0E9",
            "surfaceVariant": "#49454F",
            "surfaceVariantText": "#CAC4D0",
            "surfaceTint": "#D0BCFF",
            "background": "#10121E",
            "backgroundText": "#E6E0E9",
            "outline": "#938F99",
            "surfaceContainer": "#1D1B20",
            "surfaceContainerHigh": "#2B2930"
        },
        {
            "name": "Green",
            "primary": "#4caf50",
            "primaryText": "#ffffff",
            "primaryContainer": "#388e3c",
            "secondary": "#81c995",
            "surface": "#0f1411",
            "surfaceText": "#e1f5e3",
            "surfaceVariant": "#404943",
            "surfaceVariantText": "#c1cbc4",
            "surfaceTint": "#81c995",
            "background": "#0f1411",
            "backgroundText": "#e1f5e3",
            "outline": "#8b938c",
            "surfaceContainer": "#1a1f1b",
            "surfaceContainerHigh": "#252a26"
        },
        {
            "name": "Orange",
            "primary": "#ff6d00",
            "primaryText": "#ffffff",
            "primaryContainer": "#e65100",
            "secondary": "#ffb74d",
            "surface": "#1c1410",
            "surfaceText": "#f5f1ea",
            "surfaceVariant": "#4a453a",
            "surfaceVariantText": "#cbc5b8",
            "surfaceTint": "#ffb74d",
            "background": "#1c1410",
            "backgroundText": "#f5f1ea",
            "outline": "#958f84",
            "surfaceContainer": "#211e17",
            "surfaceContainerHigh": "#2c291f"
        },
        {
            "name": "Red",
            "primary": "#f44336",
            "primaryText": "#ffffff",
            "primaryContainer": "#d32f2f",
            "secondary": "#f28b82",
            "surface": "#1c1011",
            "surfaceText": "#f5e8ea",
            "surfaceVariant": "#4a3f41",
            "surfaceVariantText": "#cbc2c4",
            "surfaceTint": "#f28b82",
            "background": "#1c1011",
            "backgroundText": "#f5e8ea",
            "outline": "#958b8d",
            "surfaceContainer": "#211b1c",
            "surfaceContainerHigh": "#2c2426"
        },
        {
            "name": "Cyan",
            "primary": "#00bcd4",
            "primaryText": "#ffffff",
            "primaryContainer": "#0097a7",
            "secondary": "#4dd0e1",
            "surface": "#0f1617",
            "surfaceText": "#e8f4f5",
            "surfaceVariant": "#3f474a",
            "surfaceVariantText": "#c2c9cb",
            "surfaceTint": "#4dd0e1",
            "background": "#0f1617",
            "backgroundText": "#e8f4f5",
            "outline": "#8c9194",
            "surfaceContainer": "#1a1f20",
            "surfaceContainerHigh": "#252b2c"
        },
        {
            "name": "Pink",
            "primary": "#e91e63",
            "primaryText": "#ffffff",
            "primaryContainer": "#c2185b",
            "secondary": "#f8bbd9",
            "surface": "#1a1014",
            "surfaceText": "#f3e8ee",
            "surfaceVariant": "#483f45",
            "surfaceVariantText": "#c9c2c7",
            "surfaceTint": "#f8bbd9",
            "background": "#1a1014",
            "backgroundText": "#f3e8ee",
            "outline": "#938a90",
            "surfaceContainer": "#1f1b1e",
            "surfaceContainerHigh": "#2a2428"
        },
        {
            "name": "Amber",
            "primary": "#ffc107",
            "primaryText": "#000000",
            "primaryContainer": "#ff8f00",
            "secondary": "#ffd54f",
            "surface": "#1a1710",
            "surfaceText": "#f3f0e8",
            "surfaceVariant": "#49453a",
            "surfaceVariantText": "#cac5b8",
            "surfaceTint": "#ffd54f",
            "background": "#1a1710",
            "backgroundText": "#f3f0e8",
            "outline": "#949084",
            "surfaceContainer": "#1f1e17",
            "surfaceContainerHigh": "#2a281f"
        },
        {
            "name": "Coral",
            "primary": "#ffb4ab",
            "primaryText": "#5f1412",
            "primaryContainer": "#8c1d18",
            "secondary": "#f9dedc",
            "surface": "#1a1110",
            "surfaceText": "#f1e8e7",
            "surfaceVariant": "#4a4142",
            "surfaceVariantText": "#cdc2c1",
            "surfaceTint": "#ffb4ab",
            "background": "#1a1110",
            "backgroundText": "#f1e8e7",
            "outline": "#968b8a",
            "surfaceContainer": "#201a19",
            "surfaceContainerHigh": "#2b2221"
        }
    ]
    property var lightThemes: [
        {
            "name": "Blue Light",
            "primary": "#1976d2",
            "primaryText": "#ffffff",
            "primaryContainer": "#e3f2fd",
            "secondary": "#42a5f5",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#1976d2",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Deep Blue Light",
            "primary": "#0061a4",
            "primaryText": "#ffffff",
            "primaryContainer": "#cfe5ff",
            "secondary": "#1976d2",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#0061a4",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Purple Light",
            "primary": "#6750A4",
            "primaryText": "#ffffff",
            "primaryContainer": "#EADDFF",
            "secondary": "#625B71",
            "surface": "#FFFBFE",
            "surfaceText": "#1C1B1F",
            "surfaceVariant": "#E7E0EC",
            "surfaceVariantText": "#49454F",
            "surfaceTint": "#6750A4",
            "background": "#FFFBFE",
            "backgroundText": "#1C1B1F",
            "outline": "#79747E",
            "surfaceContainer": "#F3EDF7",
            "surfaceContainerHigh": "#ECE6F0"
        },
        {
            "name": "Green Light",
            "primary": "#2e7d32",
            "primaryText": "#ffffff",
            "primaryContainer": "#e8f5e8",
            "secondary": "#4caf50",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#2e7d32",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Orange Light",
            "primary": "#e65100",
            "primaryText": "#ffffff",
            "primaryContainer": "#ffecb3",
            "secondary": "#ff9800",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#e65100",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Red Light",
            "primary": "#d32f2f",
            "primaryText": "#ffffff",
            "primaryContainer": "#ffebee",
            "secondary": "#f44336",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#d32f2f",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Cyan Light",
            "primary": "#0097a7",
            "primaryText": "#ffffff",
            "primaryContainer": "#e0f2f1",
            "secondary": "#00bcd4",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#0097a7",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Pink Light",
            "primary": "#c2185b",
            "primaryText": "#ffffff",
            "primaryContainer": "#fce4ec",
            "secondary": "#e91e63",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#c2185b",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Amber Light",
            "primary": "#ff8f00",
            "primaryText": "#000000",
            "primaryContainer": "#fff8e1",
            "secondary": "#ffc107",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#ff8f00",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        },
        {
            "name": "Coral Light",
            "primary": "#8c1d18",
            "primaryText": "#ffffff",
            "primaryContainer": "#ffdad6",
            "secondary": "#ff5449",
            "surface": "#fefefe",
            "surfaceText": "#1a1c1e",
            "surfaceVariant": "#e7e0ec",
            "surfaceVariantText": "#49454f",
            "surfaceTint": "#8c1d18",
            "background": "#fefefe",
            "backgroundText": "#1a1c1e",
            "outline": "#79747e",
            "surfaceContainer": "#f3f3f3",
            "surfaceContainerHigh": "#ececec"
        }
    ]
    property int currentThemeIndex: 0
    property bool isDynamicTheme: false
    property bool isLightMode: false
    property color primary: isDynamicTheme ? Colors.accentHi : getCurrentTheme().primary
    property color primaryText: isDynamicTheme ? Colors.primaryText : getCurrentTheme().primaryText
    property color primaryContainer: isDynamicTheme ? Colors.primaryContainer : getCurrentTheme().primaryContainer
    property color secondary: isDynamicTheme ? Colors.accentLo : getCurrentTheme().secondary
    property color surface: isDynamicTheme ? Colors.surface : getCurrentTheme().surface
    property color surfaceText: isDynamicTheme ? Colors.surfaceText : getCurrentTheme().surfaceText
    property color surfaceVariant: isDynamicTheme ? Colors.surfaceVariant : getCurrentTheme().surfaceVariant
    property color surfaceVariantText: isDynamicTheme ? Colors.surfaceVariantText : getCurrentTheme().surfaceVariantText
    property color surfaceTint: isDynamicTheme ? Colors.surfaceTint : getCurrentTheme().surfaceTint
    property color background: isDynamicTheme ? Colors.bg : getCurrentTheme().background
    property color backgroundText: isDynamicTheme ? Colors.surfaceText : getCurrentTheme().backgroundText
    property color outline: isDynamicTheme ? Colors.outline : getCurrentTheme().outline
    property color surfaceContainer: isDynamicTheme ? Colors.surfaceContainer : getCurrentTheme().surfaceContainer
    property color surfaceContainerHigh: isDynamicTheme ? Colors.surfaceContainerHigh : getCurrentTheme().surfaceContainerHigh
    property color archBlue: "#1793D1"
    property color success: "#4CAF50"
    property color warning: "#FF9800"
    property color info: "#2196F3"
    property color error: "#F2B8B5"

    // Temperature-specific colors
    property color tempWarning: "#ff9933" // Balanced orange for warm temperatures
    property color tempDanger: "#ff5555" // Balanced red for dangerous temperatures

    property color primaryHover: Qt.rgba(primary.r, primary.g, primary.b, 0.12)
    property color primaryHoverLight: Qt.rgba(primary.r, primary.g, primary.b, 0.08)
    property color primaryPressed: Qt.rgba(primary.r, primary.g, primary.b, 0.16)
    property color primarySelected: Qt.rgba(primary.r, primary.g, primary.b, 0.3)
    property color primaryBackground: Qt.rgba(primary.r, primary.g, primary.b, 0.04)

    property color secondaryHover: Qt.rgba(secondary.r, secondary.g, secondary.b, 0.08)

    property color surfaceHover: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.08)
    property color surfacePressed: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.12)
    property color surfaceSelected: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.15)
    property color surfaceLight: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.1)
    property color surfaceVariantAlpha: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.2)
    property color surfaceTextHover: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.08)
    property color surfaceTextPressed: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.12)
    property color surfaceTextAlpha: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.3)
    property color surfaceTextLight: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.06)
    property color surfaceTextMedium: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.7)

    property color outlineLight: Qt.rgba(outline.r, outline.g, outline.b, 0.05)
    property color outlineMedium: Qt.rgba(outline.r, outline.g, outline.b, 0.08)
    property color outlineStrong: Qt.rgba(outline.r, outline.g, outline.b, 0.12)
    property color outlineSelected: Qt.rgba(outline.r, outline.g, outline.b, 0.2)
    property color outlineHeavy: Qt.rgba(outline.r, outline.g, outline.b, 0.3)
    property color outlineButton: Qt.rgba(outline.r, outline.g, outline.b, 0.5)

    property color errorHover: Qt.rgba(error.r, error.g, error.b, 0.12)
    property color errorPressed: Qt.rgba(error.r, error.g, error.b, 0.9)

    property color warningHover: Qt.rgba(warning.r, warning.g, warning.b, 0.12)

    property color shadowLight: Qt.rgba(0, 0, 0, 0.05)
    property color shadowMedium: Qt.rgba(0, 0, 0, 0.08)
    property color shadowDark: Qt.rgba(0, 0, 0, 0.1)
    property color shadowStrong: Qt.rgba(0, 0, 0, 0.3)
    property int shortDuration: 150
    property int mediumDuration: 300
    property int longDuration: 500
    property int extraLongDuration: 1000
    property int standardEasing: Easing.OutCubic
    property int emphasizedEasing: Easing.OutQuart
    property real cornerRadius: typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12
    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12
    property real spacingL: 16
    property real spacingXL: 24
    property real fontSizeSmall: 12
    property real fontSizeMedium: 14
    property real fontSizeLarge: 16
    property real fontSizeXLarge: 20
    property real barHeight: 48
    property real iconSize: 24
    property real iconSizeSmall: 16
    property real iconSizeLarge: 32
    property real opacityDisabled: 0.38
    property real opacityMedium: 0.6
    property real opacityHigh: 0.87
    property real opacityFull: 1
    property real panelTransparency: 0.85
    property real widgetTransparency: 0.85
    property real popupTransparency: 0.92

    function onColorsUpdated() {
        if (isDynamicTheme) {
            currentThemeIndex = 10;
            isDynamicTheme = true;
            if (typeof SettingsData !== "undefined")
                SettingsData.setTheme(currentThemeIndex, isDynamicTheme);
        }
    }

    function switchTheme(themeIndex, isDynamic = false, savePrefs = true) {
        if (isDynamic && themeIndex === 10) {
            isDynamicTheme = true;
            if (typeof Colors !== "undefined") {
                Colors.extractColors();
            }
        } else if (themeIndex >= 0 && themeIndex < themes.length) {
            currentThemeIndex = themeIndex;
            isDynamicTheme = false;
        }
        if (savePrefs && typeof SettingsData !== "undefined")
            SettingsData.setTheme(currentThemeIndex, isDynamicTheme);
    }

    function toggleLightMode(savePrefs = true) {
        isLightMode = !isLightMode;
        if (savePrefs && typeof SessionData !== "undefined")
            SessionData.setLightMode(isLightMode);
    }

    function getCurrentThemeArray() {
        return isLightMode ? lightThemes : themes;
    }

    function getCurrentTheme() {
        var themeArray = getCurrentThemeArray();
        return currentThemeIndex < themeArray.length ? themeArray[currentThemeIndex] : themeArray[0];
    }

    function getPopupBackgroundAlpha() {
        return popupTransparency;
    }

    function getContentBackgroundAlpha() {
        return popupTransparency;
    }

    function popupBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, popupTransparency);
    }

    function contentBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, popupTransparency);
    }

    function panelBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, panelTransparency);
    }

    function widgetBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, widgetTransparency);
    }

    function getBatteryIcon(level, isCharging, batteryAvailable) {
        if (!batteryAvailable)
            return _getBatteryPowerProfileIcon();

        if (isCharging) {
            if (level >= 90)
                return "battery_charging_full";

            if (level >= 80)
                return "battery_charging_90";

            if (level >= 60)
                return "battery_charging_80";

            if (level >= 50)
                return "battery_charging_60";

            if (level >= 30)
                return "battery_charging_50";

            if (level >= 20)
                return "battery_charging_30";

            return "battery_charging_20";
        } else {
            if (level >= 95)
                return "battery_full";

            if (level >= 85)
                return "battery_6_bar";

            if (level >= 70)
                return "battery_5_bar";

            if (level >= 55)
                return "battery_4_bar";

            if (level >= 40)
                return "battery_3_bar";

            if (level >= 25)
                return "battery_2_bar";

            if (level >= 10)
                return "battery_1_bar";

            return "battery_alert";
        }
    }

    function _getBatteryPowerProfileIcon() {
        if (typeof PowerProfiles === "undefined")
            return "balance";

        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "energy_savings_leaf";
        case PowerProfile.Performance:
            return "rocket_launch";
        default:
            return "balance";
        }
    }

    function getPowerProfileIcon(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "battery_saver";
        case PowerProfile.Balanced:
            return "battery_std";
        case PowerProfile.Performance:
            return "flash_on";
        default:
            return "settings";
        }
    }

    function getPowerProfileLabel(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "Power Saver";
        case PowerProfile.Balanced:
            return "Balanced";
        case PowerProfile.Performance:
            return "Performance";
        default:
            return profile.charAt(0).toUpperCase() + profile.slice(1);
        }
    }

    function getPowerProfileDescription(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "Extend battery life";
        case PowerProfile.Balanced:
            return "Balance power and performance";
        case PowerProfile.Performance:
            return "Prioritize performance";
        default:
            return "Custom power profile";
        }
    }

    Component.onCompleted: {
        if (typeof Colors !== "undefined")
            Colors.colorsUpdated.connect(root.onColorsUpdated);

        if (typeof SettingsData !== "undefined") {
            if (SettingsData.popupTransparency !== undefined)
                root.popupTransparency = SettingsData.popupTransparency;

            if (SettingsData.topBarWidgetTransparency !== undefined)
                root.widgetTransparency = SettingsData.topBarWidgetTransparency;

            if (SettingsData.popupTransparencyChanged)
                SettingsData.popupTransparencyChanged.connect(function () {
                    if (typeof SettingsData !== "undefined" && SettingsData.popupTransparency !== undefined)
                        root.popupTransparency = SettingsData.popupTransparency;
                });

            if (SettingsData.topBarWidgetTransparencyChanged)
                SettingsData.topBarWidgetTransparencyChanged.connect(function () {
                    if (typeof SettingsData !== "undefined" && SettingsData.topBarWidgetTransparency !== undefined)
                        root.widgetTransparency = SettingsData.topBarWidgetTransparency;
                });
        }
    }
}
