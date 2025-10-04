pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var availablePlugins: ({})
    property var loadedPlugins: ({})
    property var pluginWidgetComponents: ({})
    property var pluginDaemonComponents: ({})
    property string pluginDirectory: {
        var configDir = StandardPaths.writableLocation(StandardPaths.ConfigLocation)
        var configDirStr = configDir.toString()
        if (configDirStr.startsWith("file://")) {
            configDirStr = configDirStr.substring(7)
        }
        return configDirStr + "/DankMaterialShell/plugins"
    }
    property string systemPluginDirectory: "/etc/xdg/quickshell/dms-plugins"
    property var pluginDirectories: [pluginDirectory, systemPluginDirectory]

    signal pluginLoaded(string pluginId)
    signal pluginUnloaded(string pluginId)
    signal pluginLoadFailed(string pluginId, string error)
    signal pluginDataChanged(string pluginId)

    Component.onCompleted: {
        Qt.callLater(initializePlugins)
    }

    function initializePlugins() {
        scanPlugins()
    }

    property int currentScanIndex: 0
    property var scanResults: []

    property var lsProcess: Process {
        id: dirScanner

        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim()
                var currentDir = pluginDirectories[currentScanIndex]
                if (output) {
                    var directories = output.split('\n')
                    for (var i = 0; i < directories.length; i++) {
                        var dir = directories[i].trim()
                        if (dir) {
                            var manifestPath = currentDir + "/" + dir + "/plugin.json"
                            loadPluginManifest(manifestPath)
                        }
                    }
                }
            }
        }

        onExited: function(exitCode) {
            currentScanIndex++
            if (currentScanIndex < pluginDirectories.length) {
                scanNextDirectory()
            } else {
                currentScanIndex = 0
            }
        }
    }

    function scanPlugins() {
        currentScanIndex = 0
        scanNextDirectory()
    }

    function scanNextDirectory() {
        var dir = pluginDirectories[currentScanIndex]
        lsProcess.command = ["find", "-L", dir, "-maxdepth", "1", "-type", "d", "-not", "-path", dir, "-exec", "basename", "{}", ";"]
        lsProcess.running = true
    }

    property var manifestReaders: ({})

    function loadPluginManifest(manifestPath) {
        var readerId = "reader_" + Date.now() + "_" + Math.random()

        var catProcess = Qt.createComponent("data:text/plain,import Quickshell.Io; Process { stdout: StdioCollector { } }")
        if (catProcess.status === Component.Ready) {
            var process = catProcess.createObject(root)
            process.command = ["cat", manifestPath]
            process.stdout.streamFinished.connect(function() {
                try {
                    var manifest = JSON.parse(process.stdout.text.trim())
                    processManifest(manifest, manifestPath)
                } catch (e) {
                    console.error("PluginService: Failed to parse manifest", manifestPath, ":", e.message)
                }
                process.destroy()
                delete manifestReaders[readerId]
            })
            process.exited.connect(function(exitCode) {
                if (exitCode !== 0) {
                    console.error("PluginService: Failed to read manifest file:", manifestPath, "exit code:", exitCode)
                    process.destroy()
                    delete manifestReaders[readerId]
                }
            })
            manifestReaders[readerId] = process
            process.running = true
        } else {
            console.error("PluginService: Failed to create manifest reader process")
        }
    }

    function processManifest(manifest, manifestPath) {
        registerPlugin(manifest, manifestPath)

        // Auto-load plugin if it's enabled in settings (default to enabled)
        var enabled = SettingsData.getPluginSetting(manifest.id, "enabled", true)
        if (enabled) {
            loadPlugin(manifest.id)
        }
    }

    function registerPlugin(manifest, manifestPath) {
        if (!manifest.id || !manifest.name || !manifest.component) {
            console.error("PluginService: Invalid manifest, missing required fields:", manifestPath)
            return
        }

        var pluginDir = manifestPath.substring(0, manifestPath.lastIndexOf('/'))

        // Clean up relative paths by removing './' prefix
        var componentFile = manifest.component
        if (componentFile.startsWith('./')) {
            componentFile = componentFile.substring(2)
        }

        var settingsFile = manifest.settings
        if (settingsFile && settingsFile.startsWith('./')) {
            settingsFile = settingsFile.substring(2)
        }

        var pluginInfo = {}
        for (var key in manifest) {
            pluginInfo[key] = manifest[key]
        }
        pluginInfo.manifestPath = manifestPath
        pluginInfo.pluginDirectory = pluginDir
        pluginInfo.componentPath = pluginDir + '/' + componentFile
        pluginInfo.settingsPath = settingsFile ? pluginDir + '/' + settingsFile : null
        pluginInfo.loaded = false
        pluginInfo.type = manifest.type || "widget"

        availablePlugins[manifest.id] = pluginInfo
    }

    function hasPermission(pluginId, permission) {
        var plugin = availablePlugins[pluginId]
        if (!plugin) {
            return false
        }
        var permissions = plugin.permissions || []
        return permissions.indexOf(permission) !== -1
    }

    function loadPlugin(pluginId) {
        var plugin = availablePlugins[pluginId]
        if (!plugin) {
            console.error("PluginService: Plugin not found:", pluginId)
            pluginLoadFailed(pluginId, "Plugin not found")
            return false
        }

        if (plugin.loaded) {
            return true
        }

        var isDaemon = plugin.type === "daemon"
        var componentMap = isDaemon ? pluginDaemonComponents : pluginWidgetComponents

        if (componentMap[pluginId]) {
            var oldComponent = componentMap[pluginId]
            if (oldComponent) {
                oldComponent.destroy()
            }
            if (isDaemon) {
                delete pluginDaemonComponents[pluginId]
            } else {
                delete pluginWidgetComponents[pluginId]
            }
        }

        try {
            var componentUrl = "file://" + plugin.componentPath
            var component = Qt.createComponent(componentUrl, Component.PreferSynchronous)

            if (component.status === Component.Loading) {
                component.statusChanged.connect(function() {
                    if (component.status === Component.Error) {
                        console.error("PluginService: Failed to create component for plugin:", pluginId, "Error:", component.errorString())
                        pluginLoadFailed(pluginId, component.errorString())
                        component.destroy()
                    }
                })
            }

            if (component.status === Component.Error) {
                console.error("PluginService: Failed to create component for plugin:", pluginId, "Error:", component.errorString())
                pluginLoadFailed(pluginId, component.errorString())
                component.destroy()
                return false
            }

            if (isDaemon) {
                var newDaemons = Object.assign({}, pluginDaemonComponents)
                newDaemons[pluginId] = component
                pluginDaemonComponents = newDaemons
            } else {
                var newComponents = Object.assign({}, pluginWidgetComponents)
                newComponents[pluginId] = component
                pluginWidgetComponents = newComponents
            }

            plugin.loaded = true
            loadedPlugins[pluginId] = plugin

            pluginLoaded(pluginId)
            return true

        } catch (error) {
            console.error("PluginService: Error loading plugin:", pluginId, "Error:", error.message)
            pluginLoadFailed(pluginId, error.message)
            return false
        }
    }

    function unloadPlugin(pluginId) {
        var plugin = loadedPlugins[pluginId]
        if (!plugin) {
            console.warn("PluginService: Plugin not loaded:", pluginId)
            return false
        }

        try {
            var isDaemon = plugin.type === "daemon"

            if (isDaemon && pluginDaemonComponents[pluginId]) {
                var daemonComponent = pluginDaemonComponents[pluginId]
                if (daemonComponent) {
                    daemonComponent.destroy()
                }
                var newDaemons = Object.assign({}, pluginDaemonComponents)
                delete newDaemons[pluginId]
                pluginDaemonComponents = newDaemons
            } else if (pluginWidgetComponents[pluginId]) {
                var component = pluginWidgetComponents[pluginId]
                if (component) {
                    component.destroy()
                }
                var newComponents = Object.assign({}, pluginWidgetComponents)
                delete newComponents[pluginId]
                pluginWidgetComponents = newComponents
            }

            plugin.loaded = false
            delete loadedPlugins[pluginId]

            pluginUnloaded(pluginId)
            return true

        } catch (error) {
            console.error("PluginService: Error unloading plugin:", pluginId, "Error:", error.message)
            return false
        }
    }

    function getWidgetComponents() {
        return pluginWidgetComponents
    }

    function getDaemonComponents() {
        return pluginDaemonComponents
    }

    function getAvailablePlugins() {
        var result = []
        for (var key in availablePlugins) {
            result.push(availablePlugins[key])
        }
        return result
    }

    function getLoadedPlugins() {
        var result = []
        for (var key in loadedPlugins) {
            result.push(loadedPlugins[key])
        }
        return result
    }

    function isPluginLoaded(pluginId) {
        return loadedPlugins[pluginId] !== undefined
    }

    function enablePlugin(pluginId) {
        SettingsData.setPluginSetting(pluginId, "enabled", true)
        return loadPlugin(pluginId)
    }

    function disablePlugin(pluginId) {
        SettingsData.setPluginSetting(pluginId, "enabled", false)
        return unloadPlugin(pluginId)
    }

    function reloadPlugin(pluginId) {
        if (isPluginLoaded(pluginId)) {
            unloadPlugin(pluginId)
        }
        return loadPlugin(pluginId)
    }

    function savePluginData(pluginId, key, value) {
        SettingsData.setPluginSetting(pluginId, key, value)
        pluginDataChanged(pluginId)
        return true
    }

    function loadPluginData(pluginId, key, defaultValue) {
        return SettingsData.getPluginSetting(pluginId, key, defaultValue)
    }

    function createPluginDirectory() {
        var mkdirProcess = Qt.createComponent("data:text/plain,import Quickshell.Io; Process { }")
        if (mkdirProcess.status === Component.Ready) {
            var process = mkdirProcess.createObject(root)
            process.command = ["mkdir", "-p", pluginDirectory]
            process.exited.connect(function(exitCode) {
                if (exitCode !== 0) {
                    console.error("PluginService: Failed to create plugin directory, exit code:", exitCode)
                }
                process.destroy()
            })
            process.running = true
            return true
        } else {
            console.error("PluginService: Failed to create mkdir process")
            return false
        }
    }
}
