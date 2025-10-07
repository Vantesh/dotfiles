pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Common/fzf.js" as Fzf
import qs.Common

Singleton {
    id: root

    property var applications: DesktopEntries.applications.values.filter(app => !app.noDisplay && !app.runInTerminal)

    function searchApplications(query) {
        if (!query || query.length === 0)
            return applications
        if (applications.length === 0)
            return []

        const queryLower = query.toLowerCase().trim()
        const scoredApps = []
        const usageRanking = AppUsageHistoryData.getAppUsageRanking()

        for (const app of applications) {
            const name = (app.name || "").toLowerCase()
            const genericName = (app.genericName || "").toLowerCase()
            const comment = (app.comment || "").toLowerCase()
            const keywords = app.keywords ? app.keywords.map(k => k.toLowerCase()) : []

            let score = 0
            let matched = false

            const nameWords = name.trim().split(/\s+/).filter(w => w.length > 0)
            const containsAsWord = nameWords.includes(queryLower)
            const startsWithAsWord = nameWords.some(word => word.startsWith(queryLower))

            if (name === queryLower) {
                score = 10000
                matched = true
            } else if (containsAsWord) {
                score = 9500 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (name.startsWith(queryLower)) {
                score = 9000 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (startsWithAsWord) {
                score = 8500 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (name.includes(queryLower)) {
                score = 8000 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (keywords.length > 0) {
                for (const keyword of keywords) {
                    if (keyword === queryLower) {
                        score = 6000
                        matched = true
                        break
                    } else if (keyword.startsWith(queryLower)) {
                        score = 5500
                        matched = true
                        break
                    } else if (keyword.includes(queryLower)) {
                        score = 5000
                        matched = true
                        break
                    }
                }
            }
            if (!matched && genericName.includes(queryLower)) {
                if (genericName === queryLower) {
                    score = 9000
                } else if (genericName.startsWith(queryLower)) {
                    score = 8500
                } else {
                    const genericWords = genericName.trim().split(/\s+/).filter(w => w.length > 0)
                    if (genericWords.includes(queryLower)) {
                        score = 8000
                    } else if (genericWords.some(word => word.startsWith(queryLower))) {
                        score = 7500
                    } else {
                        score = 7000
                    }
                }
                matched = true
            } else if (!matched && comment.includes(queryLower)) {
                score = 3000
                matched = true
            } else if (!matched) {
                const nameFinder = new Fzf.Finder([app], {
                                                      "selector": a => a.name || "",
                                                      "casing": "case-insensitive",
                                                      "fuzzy": "v2"
                                                  })
                const fuzzyResults = nameFinder.find(query)
                if (fuzzyResults.length > 0 && fuzzyResults[0].score > 0) {
                    score = Math.min(fuzzyResults[0].score, 2000)
                    matched = true
                }
            }

            if (matched) {
                const appId = app.id || (app.execString || app.exec || "")
                const idVariants = [
                    appId,
                    appId.replace(".desktop", ""),
                    app.id,
                    app.id ? app.id.replace(".desktop", "") : null
                ].filter(id => id)

                let usageData = null
                for (const variant of idVariants) {
                    if (usageRanking[variant]) {
                        usageData = usageRanking[variant]
                        break
                    }
                }

                if (usageData) {
                    const usageCount = usageData.usageCount || 0
                    const lastUsed = usageData.lastUsed || 0
                    const now = Date.now()
                    const daysSinceUsed = (now - lastUsed) / (1000 * 60 * 60 * 24)

                    let usageBonus = 0
                    usageBonus += Math.min(usageCount * 100, 2000)

                    if (daysSinceUsed < 1) {
                        usageBonus += 1500
                    } else if (daysSinceUsed < 7) {
                        usageBonus += 1000
                    } else if (daysSinceUsed < 30) {
                        usageBonus += 500
                    }

                    score += usageBonus
                }

                scoredApps.push({
                                    "app": app,
                                    "score": score
                                })
            }
        }

        scoredApps.sort((a, b) => b.score - a.score)
        return scoredApps.slice(0, 50).map(item => item.app)
    }

    function getCategoriesForApp(app) {
        if (!app?.categories)
            return []

        const categoryMap = {
            "AudioVideo": qsTr("Media"),
            "Audio": qsTr("Media"),
            "Video": qsTr("Media"),
            "Development": qsTr("Development"),
            "TextEditor": qsTr("Development"),
            "IDE": qsTr("Development"),
            "Education": qsTr("Education"),
            "Game": qsTr("Games"),
            "Graphics": qsTr("Graphics"),
            "Photography": qsTr("Graphics"),
            "Network": qsTr("Internet"),
            "WebBrowser": qsTr("Internet"),
            "Email": qsTr("Internet"),
            "Office": qsTr("Office"),
            "WordProcessor": qsTr("Office"),
            "Spreadsheet": qsTr("Office"),
            "Presentation": qsTr("Office"),
            "Science": qsTr("Science"),
            "Settings": qsTr("Settings"),
            "System": qsTr("System"),
            "Utility": qsTr("Utilities"),
            "Accessories": qsTr("Utilities"),
            "FileManager": qsTr("Utilities"),
            "TerminalEmulator": qsTr("Utilities")
        }

        const mappedCategories = new Set()

        for (const cat of app.categories) {
            if (categoryMap[cat])
                mappedCategories.add(categoryMap[cat])
        }

        return Array.from(mappedCategories)
    }

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
        const categories = new Set([qsTr("All")])

        for (const app of applications) {
            const appCategories = getCategoriesForApp(app)
            appCategories.forEach(cat => categories.add(cat))
        }

        return Array.from(categories).sort()
    }

    function getAppsInCategory(category) {
        if (category === qsTr("All")) {
            return applications
        }

        return applications.filter(app => {
                                       const appCategories = getCategoriesForApp(app)
                                       return appCategories.includes(category)
                                   })
    }
}
