pragma Singleton
pragma ComponentBehavior

import Qt.labs.platform
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    readonly property string _homeUrl: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string homeDir: _homeUrl.startsWith("file://") ? _homeUrl.substring(7) : _homeUrl
    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string configDir: _configUrl.startsWith("file://") ? _configUrl.substring(7) : _configUrl
    readonly property string shellDir: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Common/", "")
    readonly property string wallpaperPath: SessionData.wallpaperPath
    property bool matugenAvailable: false
    property bool systemThemeGenerationInProgress: false
    property var matugenColors: ({})
    property bool extractionRequested: false
    property int colorUpdateTrigger: 0
    property string lastWallpaperTimestamp: ""
    property color primary: getMatugenColor("primary", "#42a5f5")
    property color secondary: getMatugenColor("secondary", "#8ab4f8")
    property color tertiary: getMatugenColor("tertiary", "#bb86fc")
    property color tertiaryContainer: getMatugenColor("tertiary_container", "#3700b3")
    property color error: getMatugenColor("error", "#cf6679")
    property color inversePrimary: getMatugenColor("inverse_primary", "#6200ea")
    property color bg: getMatugenColor("background", "#1a1c1e")
    property color surface: getMatugenColor("surface", "#1a1c1e")
    property color surfaceContainer: getMatugenColor("surface_container", "#1e2023")
    property color surfaceContainerHigh: getMatugenColor("surface_container_high", "#292b2f")
    property color surfaceVariant: getMatugenColor("surface_variant", "#44464f")
    property color surfaceText: getMatugenColor("on_background", "#e3e8ef")
    property color primaryText: getMatugenColor("on_primary", "#ffffff")
    property color surfaceVariantText: getMatugenColor("on_surface_variant", "#c4c7c5")
    property color primaryContainer: getMatugenColor("primary_container", "#1976d2")
    property color surfaceTint: getMatugenColor("surface_tint", "#8ab4f8")
    property color outline: getMatugenColor("outline", "#8e918f")
    property color accentHi: primary
    property color accentLo: secondary

    signal colorsUpdated

    function onLightModeChanged() {
        if (matugenColors && Object.keys(matugenColors).length > 0) {
            colorUpdateTrigger++;
            colorsUpdated();
        }
        // Always rerun walset with the correct mode when light mode changes
        let mode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark";
        Quickshell.execDetached(["walset", root.wallpaperPath, "--mode", mode]);
    }

    function extractColors() {
        extractionRequested = true;
        if (matugenAvailable)
            fileChecker.running = true;
        else
            matugenCheck.running = true;
    }

    function getMatugenColor(path, fallback) {
        colorUpdateTrigger;
        const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark";
        let cur = matugenColors && matugenColors.colors && matugenColors.colors[colorMode];
        for (const part of path.split(".")) {
            if (!cur || typeof cur !== "object" || !(part in cur))
                return fallback;

            cur = cur[part];
        }
        return cur || fallback;
    }

    function isColorDark(c) {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5;
    }

    Component.onCompleted: {
        matugenCheck.running = true;

        if (typeof SessionData !== "undefined")
            SessionData.isLightModeChanged.connect(root.onLightModeChanged);
    }

    Process {
        id: matugenCheck

        command: ["which", "matugen"]
        onExited: code => {
            matugenAvailable = (code === 0);
            if (!matugenAvailable) {
                ToastService.wallpaperErrorStatus = "matugen_missing";
                ToastService.showWarning("matugen not found - dynamic theming disabled");
                return;
            }
            if (extractionRequested) {
                fileChecker.running = true;
            }
        }
    }

    Process {
        id: fileChecker

        command: ["test", "-r", wallpaperPath]
        onExited: code => {
            if (code === 0) {
                matugenProcess.running = true;
            } else {
                ToastService.wallpaperErrorStatus = "error";
                ToastService.showError("Wallpaper processing failed");
            }
        }
    }

    Process {
        id: matugenProcess

        command: ["matugen", "image", wallpaperPath, "--json", "hex"]

        stdout: StdioCollector {
            id: matugenCollector

            onStreamFinished: {
                if (!matugenCollector.text) {
                    ToastService.wallpaperErrorStatus = "error";
                    ToastService.showError("Wallpaper Processing Failed: Empty JSON extracted from matugen output.");
                    return;
                }
                const extractedJson = extractJsonFromText(matugenCollector.text);
                if (!extractedJson) {
                    ToastService.wallpaperErrorStatus = "error";
                    ToastService.showError("Wallpaper Processing Failed: Invalid JSON extracted from matugen output.");
                    console.log("Raw matugen output:", matugenCollector.text);
                    return;
                }
                try {
                    root.matugenColors = JSON.parse(extractedJson);
                    root.colorsUpdated();
                    generateAppConfigs();
                    // --- WALSET SUPPORT ---
                    // Determine mode: dark or light
                    let mode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark";
                    Quickshell.execDetached(["walset", root.wallpaperPath, "--mode", mode]);
                    ToastService.clearWallpaperError();
                } catch (e) {
                    ToastService.wallpaperErrorStatus = "error";
                    ToastService.showError("Wallpaper processing failed (JSON parse error after extraction)");
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                ToastService.wallpaperErrorStatus = "error";
                ToastService.showError("Matugen command failed with exit code " + code);
            }
        }
    }

    function generateAppConfigs() {
        if (!matugenColors || !matugenColors.colors) {
            return;
        }
    }

    // Returns the first complete JSON substring (object or array) or null.
    function extractJsonFromText(text) {
        if (!text)
            return null;

        const start = text.search(/[{\[]/);
        if (start === -1)
            return null;

        const open = text[start];
        const pairs = {
            "{": '}',
            "[": ']'
        };
        const close = pairs[open];
        if (!close)
            return null;

        let inString = false;
        let escape = false;
        const stack = [open];

        for (var i = start + 1; i < text.length; i++) {
            const ch = text[i];

            if (inString) {
                if (escape) {
                    escape = false;
                } else if (ch === '\\') {
                    escape = true;
                } else if (ch === '"') {
                    inString = false;
                }
                continue;
            }

            if (ch === '"') {
                inString = true;
                continue;
            }
            if (ch === '{' || ch === '[') {
                stack.push(ch);
                continue;
            }
            if (ch === '}' || ch === ']') {
                const last = stack.pop();
                if (!last || pairs[last] !== ch) {
                    return null;
                }
                if (stack.length === 0) {
                    return text.slice(start, i + 1);
                }
            }
        }

        return null;
    }
}
