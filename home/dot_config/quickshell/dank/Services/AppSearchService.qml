pragma Singleton

pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Common/fuzzysort.js" as Fuzzy

Singleton {
    id: root

    property var applications: DesktopEntries.applications.values

    property var preppedApps: applications.map(app => ({
                                                           "name": Fuzzy.prepare(
                                                                       app.name
                                                                       || ""),
                                                           "comment": Fuzzy.prepare(
                                                                          app.comment
                                                                          || ""),
                                                           "entry": app
                                                       }))

    function searchApplications(query) {
        if (!query || query.length === 0) {
            return applications
        }

        if (preppedApps.length === 0) {
            return []
        }

        var results = Fuzzy.go(query, preppedApps, {
                                   "all": false,
                                   "keys": ["name", "comment"],
                                   "scoreFn": r => {
                                       var nameScore = r[0] ? r[0].score : 0
                                       var commentScore = r[1] ? r[1].score : 0
                                       var appName = r.obj.entry.name || ""
                                       var finalScore = 0

                                       if (nameScore > 0) {
                                           var queryLower = query.toLowerCase()
                                           var nameLower = appName.toLowerCase()

                                           if (nameLower === queryLower) {
                                               finalScore = nameScore * 100
                                           } else if (nameLower.startsWith(
                                                          queryLower)) {
                                               finalScore = nameScore * 50
                                           } else if (nameLower.includes(
                                                          " " + queryLower)
                                                      || nameLower.includes(
                                                          queryLower + " ")
                                                      || nameLower.endsWith(
                                                          " " + queryLower)) {
                                               finalScore = nameScore * 25
                                           } else if (nameLower.includes(
                                                          queryLower)) {
                                               finalScore = nameScore * 10
                                           } else {
                                               finalScore = nameScore * 2 + commentScore * 0.1
                                           }
                                       } else {
                                           finalScore = commentScore * 0.1
                                       }

                                       return finalScore
                                   },
                                   "limit": 50
                               })

        return results.map(r => r.obj.entry)
    }

    function getCategoriesForApp(app) {
        if (!app || !app.categories)
            return []

        var categoryMap = {
            "AudioVideo": "Media",
            "Audio": "Media",
            "Video": "Media",
            "Development": "Development",
            "TextEditor": "Development",
            "IDE": "Development",
            "Education": "Education",
            "Game": "Games",
            "Graphics": "Graphics",
            "Photography": "Graphics",
            "Network": "Internet",
            "WebBrowser": "Internet",
            "Email": "Internet",
            "Office": "Office",
            "WordProcessor": "Office",
            "Spreadsheet": "Office",
            "Presentation": "Office",
            "Science": "Science",
            "Settings": "Settings",
            "System": "System",
            "Utility": "Utilities",
            "Accessories": "Utilities",
            "FileManager": "Utilities",
            "TerminalEmulator": "Utilities"
        }

        var mappedCategories = new Set()

        for (var i = 0; i < app.categories.length; i++) {
            var cat = app.categories[i]
            if (categoryMap[cat]) {
                mappedCategories.add(categoryMap[cat])
            }
        }

        return Array.from(mappedCategories)
    }

    // Category icon mappings
    property var categoryIcons: ({
                                     "All": "apps",
                                     "Media": "music_video",
                                     "Development": "code",
                                     "Games": "sports_esports",
                                     "Graphics": "photo_library",
                                     "Internet": "web",
                                     "Office": "content_paste",
                                     "Settings": "settings",
                                     "System": "host",
                                     "Utilities": "build"
                                 })

    function getCategoryIcon(category) {
        return categoryIcons[category] || "folder"
    }

    function getAllCategories() {
        var categories = new Set(["All"])

        for (var i = 0; i < applications.length; i++) {
            var appCategories = getCategoriesForApp(applications[i])
            appCategories.forEach(cat => categories.add(cat))
        }

        return Array.from(categories).sort()
    }

    function getAppsInCategory(category) {
        if (category === "All") {
            return applications
        }

        return applications.filter(app => {
                                       var appCategories = getCategoriesForApp(
                                           app)
                                       return appCategories.includes(category)
                                   })
    }
}
