pragma Singleton

pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property int refCount: 0

    property var weather: ({
                               "available": false,
                               "loading": true,
                               "temp": 0,
                               "tempF": 0,
                               "city": "",
                               "wCode": "113",
                               "humidity": 0,
                               "wind": "",
                               "sunrise": "06:00",
                               "sunset": "18:00",
                               "uv": 0,
                               "pressure": 0
                           })

    property int updateInterval: 600000 // 10 minutes
    property int retryAttempts: 0
    property int maxRetryAttempts: 3
    property int retryDelay: 30000 // 30 seconds
    property int lastFetchTime: 0
    property int minFetchInterval: 30000 // 30 seconds minimum between fetches
    property int persistentRetryCount: 0 // Track persistent retry attempts for backoff

    // Weather icon mapping (based on wttr.in weather codes)
    property var weatherIcons: ({
                                    "113": "clear_day",
                                    "116": "partly_cloudy_day",
                                    "119": "cloud",
                                    "122": "cloud",
                                    "143": "foggy",
                                    "176": "rainy",
                                    "179": "rainy",
                                    "182": "rainy",
                                    "185": "rainy",
                                    "200": "thunderstorm",
                                    "227": "cloudy_snowing",
                                    "230": "snowing_heavy",
                                    "248": "foggy",
                                    "260": "foggy",
                                    "263": "rainy",
                                    "266": "rainy",
                                    "281": "rainy",
                                    "284": "rainy",
                                    "293": "rainy",
                                    "296": "rainy",
                                    "299": "rainy",
                                    "302": "weather_hail",
                                    "305": "rainy",
                                    "308": "weather_hail",
                                    "311": "rainy",
                                    "314": "rainy",
                                    "317": "rainy",
                                    "320": "cloudy_snowing",
                                    "323": "cloudy_snowing",
                                    "326": "cloudy_snowing",
                                    "329": "snowing_heavy",
                                    "332": "snowing_heavy",
                                    "335": "snowing_heavy",
                                    "338": "snowing_heavy",
                                    "350": "rainy",
                                    "353": "rainy",
                                    "356": "weather_hail",
                                    "359": "weather_hail",
                                    "362": "rainy",
                                    "365": "weather_hail",
                                    "368": "cloudy_snowing",
                                    "371": "snowing_heavy",
                                    "374": "weather_hail",
                                    "377": "weather_hail",
                                    "386": "thunderstorm",
                                    "389": "thunderstorm",
                                    "392": "snowing_heavy",
                                    "395": "snowing_heavy"
                                })

    function getWeatherIcon(code) {
        return weatherIcons[code] || "cloud"
    }

    function getWeatherUrl() {
        if (SettingsData.useAutoLocation) {
            const url = "wttr.in/?format=j1"
            console.log("Using auto location, URL:", url)
            return url
        }

        const location = SettingsData.weatherCoordinates || "40.7128,-74.0060"
        const url = `wttr.in/${encodeURIComponent(location)}?format=j1`
        return url
    }

    function addRef() {
        refCount++

        if (refCount === 1 && !weather.available
                && SettingsData.weatherEnabled) {
            // Start fetching when first consumer appears and weather is enabled
            fetchWeather()
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1)
    }

    function fetchWeather() {
        // Only fetch if someone is consuming the data and weather is enabled
        if (root.refCount === 0 || !SettingsData.weatherEnabled) {
            return
        }

        if (weatherFetcher.running) {
            console.log("Weather fetch already in progress, skipping")
            return
        }

        // Check if we've fetched recently to prevent spam
        const now = Date.now()
        if (now - root.lastFetchTime < root.minFetchInterval) {
            console.log("Weather fetch throttled, too soon since last fetch")
            return
        }

        console.log("Fetching weather from:", getWeatherUrl())
        root.lastFetchTime = now
        root.weather.loading = true
        weatherFetcher.command
                = ["bash", "-c", `curl -s --connect-timeout 10 --max-time 30 '${getWeatherUrl(
                       )}'`]
        weatherFetcher.running = true
    }

    function forceRefresh() {
        console.log("Force refreshing weather")
        root.lastFetchTime = 0 // Reset throttle
        fetchWeather()
    }

    function handleWeatherSuccess() {
        root.retryAttempts = 0
        root.persistentRetryCount = 0 // Reset persistent retry count on success
        // Stop any persistent retry timer if running
        if (persistentRetryTimer.running) {
            persistentRetryTimer.stop()
        }
        // Don't restart the timer - let it continue its normal interval
        if (updateTimer.interval !== root.updateInterval) {
            updateTimer.interval = root.updateInterval
        }
    }

    function handleWeatherFailure() {
        root.retryAttempts++
        if (root.retryAttempts < root.maxRetryAttempts) {
            console.log(`Weather fetch failed, retrying in ${root.retryDelay
                        / 1000}s (attempt ${root.retryAttempts}/${root.maxRetryAttempts})`)
            retryTimer.start()
        } else {
            console.warn("Weather fetch failed after maximum retry attempts, will keep trying...")
            root.weather.available = false
            root.weather.loading = false
            // Reset retry count but keep trying with exponential backoff
            root.retryAttempts = 0
            // Use exponential backoff: 1min, 2min, 4min, then cap at 5min
            const backoffDelay = Math.min(60000 * Math.pow(
                                              2, persistentRetryCount), 300000)
            persistentRetryCount++
            console.log(`Scheduling persistent retry in ${backoffDelay / 1000}s`)
            persistentRetryTimer.interval = backoffDelay
            persistentRetryTimer.start()
        }
    }

    Process {
        id: weatherFetcher
        command: ["bash", "-c", `curl -s --connect-timeout 10 --max-time 30 '${root.getWeatherUrl(
                )}'`]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                if (!raw || raw[0] !== "{") {
                    console.warn("No valid weather data received")
                    root.handleWeatherFailure()
                    return
                }

                try {
                    const data = JSON.parse(raw)

                    const current = data.current_condition[0] || {}
                    const location = data.nearest_area[0] || {}
                    const astronomy = data.weather[0]?.astronomy[0] || {}

                    if (!Object.keys(current).length || !Object.keys(
                            location).length) {
                        throw new Error("Required fields missing")
                    }

                    root.weather = {
                        "available": true,
                        "loading": false,
                        "temp": Number(current.temp_C) || 0,
                        "tempF": Number(current.temp_F) || 0,
                        "city": location.areaName[0]?.value || "Unknown",
                        "wCode": current.weatherCode || "113",
                        "humidity": Number(current.humidity) || 0,
                        "wind": `${current.windspeedKmph || 0} km/h`,
                        "sunrise": astronomy.sunrise || "06:00",
                        "sunset": astronomy.sunset || "18:00",
                        "uv": Number(current.uvIndex) || 0,
                        "pressure": Number(current.pressure) || 0
                    }

                    console.log("Weather updated:", root.weather.city,
                                `${root.weather.temp}°C`)

                    root.handleWeatherSuccess()
                } catch (e) {
                    console.warn("Failed to parse weather data:", e.message)
                    root.handleWeatherFailure()
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("Weather fetch failed with exit code:", exitCode)
                root.handleWeatherFailure()
            }
        }
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.refCount > 0 && SettingsData.weatherEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.fetchWeather()
        }
    }

    Timer {
        id: retryTimer
        interval: root.retryDelay
        running: false
        repeat: false
        onTriggered: {
            root.fetchWeather()
        }
    }

    Timer {
        id: persistentRetryTimer
        interval: 60000 // Will be dynamically set
        running: false
        repeat: false
        onTriggered: {
            console.log("Persistent retry attempt...")
            root.fetchWeather()
        }
    }

    Component.onCompleted: {
        SettingsData.weatherCoordinatesChanged.connect(() => {
                                                           console.log(
                                                               "Weather location changed, force refreshing weather")
                                                           root.weather = {
                                                               "available": false,
                                                               "loading": true,
                                                               "temp": 0,
                                                               "tempF": 0,
                                                               "city": "",
                                                               "wCode": "113",
                                                               "humidity": 0,
                                                               "wind": "",
                                                               "sunrise": "06:00",
                                                               "sunset": "18:00",
                                                               "uv": 0,
                                                               "pressure": 0
                                                           }
                                                           root.lastFetchTime = 0
                                                           root.forceRefresh()
                                                       })

        SettingsData.weatherLocationChanged.connect(() => {
                                                        console.log(
                                                            "Weather location display name changed")
                                                        const currentWeather = Object.assign(
                                                            {}, root.weather)
                                                        root.weather = currentWeather
                                                    })

        SettingsData.useAutoLocationChanged.connect(() => {
                                                        console.log(
                                                            "Auto location setting changed, force refreshing weather")
                                                        root.weather = {
                                                            "available": false,
                                                            "loading": true,
                                                            "temp": 0,
                                                            "tempF": 0,
                                                            "city": "",
                                                            "wCode": "113",
                                                            "humidity": 0,
                                                            "wind": "",
                                                            "sunrise": "06:00",
                                                            "sunset": "18:00",
                                                            "uv": 0,
                                                            "pressure": 0
                                                        }
                                                        root.lastFetchTime = 0
                                                        root.forceRefresh()
                                                    })

        SettingsData.weatherEnabledChanged.connect(() => {
                                                       console.log(
                                                           "Weather enabled setting changed:",
                                                           SettingsData.weatherEnabled)
                                                       if (SettingsData.weatherEnabled
                                                           && root.refCount > 0
                                                           && !root.weather.available) {
                                                           // Start fetching when weather is re-enabled
                                                           root.forceRefresh()
                                                       } else if (!SettingsData.weatherEnabled) {
                                                           // Stop all timers when weather is disabled
                                                           updateTimer.stop()
                                                           retryTimer.stop()
                                                           persistentRetryTimer.stop()
                                                           if (weatherFetcher.running) {
                                                               weatherFetcher.running = false
                                                           }
                                                       }
                                                   })
    }
}
