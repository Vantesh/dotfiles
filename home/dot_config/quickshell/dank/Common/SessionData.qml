pragma Singleton
pragma ComponentBehavior

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    property bool isLightMode: false
    property string wallpaperPath: ""
    property string wallpaperLastPath: ""
    property string profileLastPath: ""
    property bool doNotDisturb: false
    property bool nightModeEnabled: false
    property int nightModeTemperature: 4500
    property bool nightModeAutomatic: false
    property string nightModeFromTime: "19:00"
    property string nightModeToTime: "06:30"
    property var pinnedApps: []
    property int selectedGpuIndex: 0
    property bool nvidiaGpuTempEnabled: false
    property bool nonNvidiaGpuTempEnabled: false
    property var enabledGpuPciIds: []
    property bool wallpaperCyclingEnabled: false
    property string wallpaperCyclingMode: "interval" // "interval" or "time"
    property int wallpaperCyclingInterval: 300 // seconds (5 minutes)
    property string wallpaperCyclingTime: "06:00" // HH:mm format
    property string lastBrightnessDevice: ""

    Component.onCompleted: {
        loadSettings();
    }

    function loadSettings() {
        parseSettings(settingsFile.text());
    }

    function parseSettings(content) {
        try {
            if (content && content.trim()) {
                var settings = JSON.parse(content);
                isLightMode = settings.isLightMode !== undefined ? settings.isLightMode : false;
                wallpaperPath = settings.wallpaperPath !== undefined ? settings.wallpaperPath : "";
                wallpaperLastPath = settings.wallpaperLastPath !== undefined ? settings.wallpaperLastPath : "";
                profileLastPath = settings.profileLastPath !== undefined ? settings.profileLastPath : "";
                doNotDisturb = settings.doNotDisturb !== undefined ? settings.doNotDisturb : false;
                nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false;
                nightModeTemperature = settings.nightModeTemperature !== undefined ? settings.nightModeTemperature : 4500;
                nightModeAutomatic = settings.nightModeAutomatic !== undefined ? settings.nightModeAutomatic : false;
                nightModeFromTime = settings.nightModeFromTime !== undefined ? settings.nightModeFromTime : "19:00";
                nightModeToTime = settings.nightModeToTime !== undefined ? settings.nightModeToTime : "06:30";
                pinnedApps = settings.pinnedApps !== undefined ? settings.pinnedApps : [];
                selectedGpuIndex = settings.selectedGpuIndex !== undefined ? settings.selectedGpuIndex : 0;
                nvidiaGpuTempEnabled = settings.nvidiaGpuTempEnabled !== undefined ? settings.nvidiaGpuTempEnabled : false;
                nonNvidiaGpuTempEnabled = settings.nonNvidiaGpuTempEnabled !== undefined ? settings.nonNvidiaGpuTempEnabled : false;
                enabledGpuPciIds = settings.enabledGpuPciIds !== undefined ? settings.enabledGpuPciIds : [];
                wallpaperCyclingEnabled = settings.wallpaperCyclingEnabled !== undefined ? settings.wallpaperCyclingEnabled : false;
                wallpaperCyclingMode = settings.wallpaperCyclingMode !== undefined ? settings.wallpaperCyclingMode : "interval";
                wallpaperCyclingInterval = settings.wallpaperCyclingInterval !== undefined ? settings.wallpaperCyclingInterval : 300;
                wallpaperCyclingTime = settings.wallpaperCyclingTime !== undefined ? settings.wallpaperCyclingTime : "06:00";
                lastBrightnessDevice = settings.lastBrightnessDevice !== undefined ? settings.lastBrightnessDevice : "";
            }
        } catch (e) {}
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
            "isLightMode": isLightMode,
            "wallpaperPath": wallpaperPath,
            "wallpaperLastPath": wallpaperLastPath,
            "profileLastPath": profileLastPath,
            "doNotDisturb": doNotDisturb,
            "nightModeEnabled": nightModeEnabled,
            "nightModeTemperature": nightModeTemperature,
            "nightModeAutomatic": nightModeAutomatic,
            "nightModeFromTime": nightModeFromTime,
            "nightModeToTime": nightModeToTime,
            "pinnedApps": pinnedApps,
            "selectedGpuIndex": selectedGpuIndex,
            "nvidiaGpuTempEnabled": nvidiaGpuTempEnabled,
            "nonNvidiaGpuTempEnabled": nonNvidiaGpuTempEnabled,
            "enabledGpuPciIds": enabledGpuPciIds,
            "wallpaperCyclingEnabled": wallpaperCyclingEnabled,
            "wallpaperCyclingMode": wallpaperCyclingMode,
            "wallpaperCyclingInterval": wallpaperCyclingInterval,
            "wallpaperCyclingTime": wallpaperCyclingTime,
            "lastBrightnessDevice": lastBrightnessDevice
        }, null, 2));
    }

    function setLightMode(lightMode) {
        isLightMode = lightMode;
        saveSettings();
    }

    function setDoNotDisturb(enabled) {
        doNotDisturb = enabled;
        saveSettings();
    }

    function setNightModeEnabled(enabled) {
        nightModeEnabled = enabled;
        saveSettings();
    }

    function setNightModeAutomatic(enabled) {
        nightModeAutomatic = enabled;
        saveSettings();
    }

    function setNightModeFromTime(time) {
        nightModeFromTime = time;
        saveSettings();
    }

    function setNightModeToTime(time) {
        nightModeToTime = time;
        saveSettings();
    }

    function setNightModeTemperature(temperature) {
        nightModeTemperature = temperature;
        saveSettings();
    }

    function setWallpaperPath(path) {
        wallpaperPath = path;
        saveSettings();
    }

    function setWallpaper(imagePath) {
        wallpaperPath = imagePath;
        saveSettings();

        if (typeof Colors !== "undefined" && typeof SettingsData !== "undefined" && SettingsData.wallpaperDynamicTheming) {
            Colors.extractColors();
        }
    }

    function setWallpaperLastPath(path) {
        wallpaperLastPath = path;
        saveSettings();
    }

    function setProfileLastPath(path) {
        profileLastPath = path;
        saveSettings();
    }

    function setPinnedApps(apps) {
        pinnedApps = apps;
        saveSettings();
    }

    function addPinnedApp(appId) {
        if (!appId)
            return;
        var currentPinned = [...pinnedApps];
        if (currentPinned.indexOf(appId) === -1) {
            currentPinned.push(appId);
            setPinnedApps(currentPinned);
        }
    }

    function removePinnedApp(appId) {
        if (!appId)
            return;
        var currentPinned = pinnedApps.filter(id => id !== appId);
        setPinnedApps(currentPinned);
    }

    function isPinnedApp(appId) {
        return appId && pinnedApps.indexOf(appId) !== -1;
    }

    function setSelectedGpuIndex(index) {
        selectedGpuIndex = index;
        saveSettings();
    }

    function setNvidiaGpuTempEnabled(enabled) {
        nvidiaGpuTempEnabled = enabled;
        saveSettings();
    }

    function setNonNvidiaGpuTempEnabled(enabled) {
        nonNvidiaGpuTempEnabled = enabled;
        saveSettings();
    }

    function setEnabledGpuPciIds(pciIds) {
        enabledGpuPciIds = pciIds;
        saveSettings();
    }

    function setWallpaperCyclingEnabled(enabled) {
        wallpaperCyclingEnabled = enabled;
        saveSettings();
    }

    function setWallpaperCyclingMode(mode) {
        wallpaperCyclingMode = mode;
        saveSettings();
    }

    function setWallpaperCyclingInterval(interval) {
        wallpaperCyclingInterval = interval;
        saveSettings();
    }

    function setWallpaperCyclingTime(time) {
        wallpaperCyclingTime = time;
        saveSettings();
    }

    function setLastBrightnessDevice(device) {
        lastBrightnessDevice = device;
        saveSettings();
    }

    FileView {
        id: settingsFile

        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/Dank/session.json"
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onLoaded: {
            parseSettings(settingsFile.text());
        }
        onLoadFailed: error => {}
    }

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            return root.wallpaperPath || "";
        }

        function set(path: string): string {
            if (!path) {
                return "ERROR: No path provided";
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path;

            try {
                root.setWallpaper(absolutePath);
                return "SUCCESS: Wallpaper set to " + absolutePath;
            } catch (e) {
                return "ERROR: Failed to set wallpaper: " + e.toString();
            }
        }

        function clear(): string {
            root.setWallpaper("");
            return "SUCCESS: Wallpaper cleared";
        }

        function next(): string {
            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set";
            }

            try {
                WallpaperCyclingService.cycleNextManually();
                return "SUCCESS: Cycling to next wallpaper";
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString();
            }
        }

        function prev(): string {
            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set";
            }

            try {
                WallpaperCyclingService.cyclePrevManually();
                return "SUCCESS: Cycling to previous wallpaper";
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString();
            }
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): string {
            root.setLightMode(!root.isLightMode);
            return root.isLightMode ? "light" : "dark";
        }

        function light(): string {
            root.setLightMode(true);
            return "light";
        }

        function dark(): string {
            root.setLightMode(false);
            return "dark";
        }

        function getMode(): string {
            return root.isLightMode ? "light" : "dark";
        }
    }
}
