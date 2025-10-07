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
    property var foundPlugins: ({})

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
                cleanupRemovedPlugins()
            }
        }
    }

    function scanPlugins() {
        currentScanIndex = 0
        foundPlugins = {}
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

        var checkProcess = Qt.createComponent("data:text/plain,import Quickshell.Io; Process { stdout: StdioCollector { } }")
        if (checkProcess.status === Component.Ready) {
            var checker = checkProcess.createObject(root)
            checker.command = ["test", "-f", manifestPath]
            checker.exited.connect(function(exitCode) {
                if (exitCode !== 0) {
                    checker.destroy()
                    delete manifestReaders[readerId]
                    return
                }

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

                checker.destroy()
            })
            manifestReaders[readerId] = checker
            checker.running = true
        } else {
            console.error("PluginService: Failed to create file check process")
        }
    }

    function processManifest(manifest, manifestPath) {
        registerPlugin(manifest, manifestPath)

        var enabled = SettingsData.getPluginSetting(manifest.id, "enabled", false)
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

        var newPlugins = Object.assign({}, availablePlugins)
        newPlugins[manifest.id] = pluginInfo
        availablePlugins = newPlugins
        foundPlugins[manifest.id] = true
    }

    function hasPermission(pluginId, permission) {
        var plugin = availablePlugins[pluginId]
        if (!plugin) {
            return false
        }
        var permissions = plugin.permissions || []
        return permissions.indexOf(permission) !== -1
    }

    function cleanupRemovedPlugins() {
        var pluginsToRemove = []
        for (var pluginId in availablePlugins) {
            if (!foundPlugins[pluginId]) {
                pluginsToRemove.push(pluginId)
            }
        }

        if (pluginsToRemove.length > 0) {
            var newPlugins = Object.assign({}, availablePlugins)
            for (var i = 0; i < pluginsToRemove.length; i++) {
                var pluginId = pluginsToRemove[i]
                if (isPluginLoaded(pluginId)) {
                    unloadPlugin(pluginId)
                }
                delete newPlugins[pluginId]
            }
            availablePlugins = newPlugins
        }
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
            componentMap[pluginId]?.destroy()
            if (isDaemon) {
                var newDaemons = Object.assign({}, pluginDaemonComponents)
                delete newDaemons[pluginId]
                pluginDaemonComponents = newDaemons
            } else {
                var newComponents = Object.assign({}, pluginWidgetComponents)
                delete newComponents[pluginId]
                pluginWidgetComponents = newComponents
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
                    }
                })
            }

            if (component.status === Component.Error) {
                console.error("PluginService: Failed to create component for plugin:", pluginId, "Error:", component.errorString())
                pluginLoadFailed(pluginId, component.errorString())
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
                pluginDaemonComponents[pluginId]?.destroy()
                var newDaemons = Object.assign({}, pluginDaemonComponents)
                delete newDaemons[pluginId]
                pluginDaemonComponents = newDaemons
            } else if (pluginWidgetComponents[pluginId]) {
                pluginWidgetComponents[pluginId]?.destroy()
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

    function getPluginVariants(pluginId) {
        var plugin = availablePlugins[pluginId]
        if (!plugin) {
            return []
        }
        var variants = SettingsData.getPluginSetting(pluginId, "variants", [])
        return variants
    }

    function getAllPluginVariants() {
        var result = []
        for (var pluginId in availablePlugins) {
            var plugin = availablePlugins[pluginId]
            if (plugin.type !== "widget") {
                continue
            }
            var variants = getPluginVariants(pluginId)
            if (variants.length === 0) {
                result.push({
                    pluginId: pluginId,
                    variantId: null,
                    fullId: pluginId,
                    name: plugin.name,
                    icon: plugin.icon || "extension",
                    description: plugin.description || "Plugin widget",
                    loaded: plugin.loaded
                })
            } else {
                for (var i = 0; i < variants.length; i++) {
                    var variant = variants[i]
                    result.push({
                        pluginId: pluginId,
                        variantId: variant.id,
                        fullId: pluginId + ":" + variant.id,
                        name: plugin.name + " - " + variant.name,
                        icon: variant.icon || plugin.icon || "extension",
                        description: variant.description || plugin.description || "Plugin widget variant",
                        loaded: plugin.loaded
                    })
                }
            }
        }
        return result
    }

    function createPluginVariant(pluginId, variantName, variantConfig) {
        var variants = getPluginVariants(pluginId)
        var variantId = "variant_" + Date.now()
        var newVariant = Object.assign({}, variantConfig, {
            id: variantId,
            name: variantName
        })
        variants.push(newVariant)
        SettingsData.setPluginSetting(pluginId, "variants", variants)
        pluginDataChanged(pluginId)
        return variantId
    }

    function removePluginVariant(pluginId, variantId) {
        var variants = getPluginVariants(pluginId)
        var newVariants = variants.filter(function(v) { return v.id !== variantId })
        SettingsData.setPluginSetting(pluginId, "variants", newVariants)
        pluginDataChanged(pluginId)
    }

    function updatePluginVariant(pluginId, variantId, variantConfig) {
        var variants = getPluginVariants(pluginId)
        for (var i = 0; i < variants.length; i++) {
            if (variants[i].id === variantId) {
                variants[i] = Object.assign({}, variants[i], variantConfig)
                break
            }
        }
        SettingsData.setPluginSetting(pluginId, "variants", variants)
        pluginDataChanged(pluginId)
    }

    function getPluginVariantData(pluginId, variantId) {
        var variants = getPluginVariants(pluginId)
        for (var i = 0; i < variants.length; i++) {
            if (variants[i].id === variantId) {
                return variants[i]
            }
        }
        return null
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

    function saveAllPluginSettings() {
        SettingsData.savePluginSettings()
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
