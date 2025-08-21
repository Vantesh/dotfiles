import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string searchQuery: ""
    property string selectedCategory: "All"
    property string viewMode: "list" // "list" or "grid"
    property int selectedIndex: 0
    property int maxResults: 50
    property int gridColumns: 4
    property bool debounceSearch: true
    property int debounceInterval: 50
    property bool keyboardNavigationActive: false
    property var categories: {
        var allCategories = AppSearchService.getAllCategories().filter(cat => {
                                                                           return cat !== "Education"
                                                                           && cat !== "Science"
                                                                       })
        var result = ["All"]
        return result.concat(allCategories.filter(cat => {
                                                      return cat !== "All"
                                                  }))
    }
    property var categoryIcons: categories.map(category => {
                                                   return AppSearchService.getCategoryIcon(
                                                       category)
                                               })
    property var appUsageRanking: AppUsageHistoryData.appUsageRanking || {}
    property alias model: filteredModel
    property var _watchApplications: AppSearchService.applications

    signal appLaunched(var app)
    signal categorySelected(string category)
    signal viewModeSelected(string mode)

    function updateFilteredModel() {
        filteredModel.clear()
        selectedIndex = 0
        keyboardNavigationActive = false
        var apps = []
        if (searchQuery.length === 0) {
            if (selectedCategory === "All") {
                apps = AppSearchService.getAppsInCategory(
                            "All") // HACK: Use function call instead of property
            } else {
                var categoryApps = AppSearchService.getAppsInCategory(
                            selectedCategory)
                apps = categoryApps.slice(0, maxResults)
            }
        } else {
            if (selectedCategory === "All") {
                apps = AppSearchService.searchApplications(searchQuery)
            } else {
                var categoryApps = AppSearchService.getAppsInCategory(
                            selectedCategory)
                if (categoryApps.length > 0) {
                    var allSearchResults = AppSearchService.searchApplications(
                                searchQuery)
                    var categoryNames = new Set(categoryApps.map(app => {
                                                                     return app.name
                                                                 }))
                    apps = allSearchResults.filter(searchApp => {
                                                       return categoryNames.has(
                                                           searchApp.name)
                                                   }).slice(0, maxResults)
                } else {
                    apps = []
                }
            }
        }
        if (searchQuery.length === 0)
            apps = apps.sort(function (a, b) {
                var aId = a.id || (a.execString || a.exec || "")
                var bId = b.id || (b.execString || b.exec || "")
                var aUsage = appUsageRanking[aId] ? appUsageRanking[aId].usageCount : 0
                var bUsage = appUsageRanking[bId] ? appUsageRanking[bId].usageCount : 0
                if (aUsage !== bUsage)
                    return bUsage - aUsage

                return (a.name || "").localeCompare(b.name || "")
            })

        apps.forEach(app => {
                         if (app)
                         filteredModel.append({
                                                  "name": app.name || "",
                                                  "exec": app.execString || "",
                                                  "icon": app.icon
                                                          || "application-x-executable",
                                                  "comment": app.comment || "",
                                                  "categories": app.categories
                                                                || [],
                                                  "desktopEntry": app
                                              })
                     })
    }

    function selectNext() {
        if (filteredModel.count > 0) {
            keyboardNavigationActive = true
            if (viewMode === "grid") {
                var newIndex = Math.min(selectedIndex + gridColumns,
                                        filteredModel.count - 1)
                selectedIndex = newIndex
            } else {
                selectedIndex = Math.min(selectedIndex + 1,
                                         filteredModel.count - 1)
            }
        }
    }

    function selectPrevious() {
        if (filteredModel.count > 0) {
            keyboardNavigationActive = true
            if (viewMode === "grid") {
                var newIndex = Math.max(selectedIndex - gridColumns, 0)
                selectedIndex = newIndex
            } else {
                selectedIndex = Math.max(selectedIndex - 1, 0)
            }
        }
    }

    function selectNextInRow() {
        if (filteredModel.count > 0 && viewMode === "grid") {
            keyboardNavigationActive = true
            selectedIndex = Math.min(selectedIndex + 1, filteredModel.count - 1)
        }
    }

    function selectPreviousInRow() {
        if (filteredModel.count > 0 && viewMode === "grid") {
            keyboardNavigationActive = true
            selectedIndex = Math.max(selectedIndex - 1, 0)
        }
    }

    function launchSelected() {
        if (filteredModel.count > 0 && selectedIndex >= 0
                && selectedIndex < filteredModel.count) {
            var selectedApp = filteredModel.get(selectedIndex)
            launchApp(selectedApp)
        }
    }

    function launchApp(appData) {
        if (!appData)
            return

        appData.desktopEntry.execute()
        appLaunched(appData)
        AppUsageHistoryData.addAppUsage(appData.desktopEntry)
    }

    function setCategory(category) {
        selectedCategory = category
        categorySelected(category)
    }

    function setViewMode(mode) {
        viewMode = mode
        viewModeSelected(mode)
    }

    onSearchQueryChanged: {
        if (debounceSearch)
            searchDebounceTimer.restart()
        else
            updateFilteredModel()
    }
    onSelectedCategoryChanged: updateFilteredModel()
    onAppUsageRankingChanged: updateFilteredModel()
    on_WatchApplicationsChanged: updateFilteredModel()
    Component.onCompleted: {
        updateFilteredModel()
    }

    ListModel {
        id: filteredModel
    }

    Timer {
        id: searchDebounceTimer

        interval: root.debounceInterval
        repeat: false
        onTriggered: updateFilteredModel()
    }
}
