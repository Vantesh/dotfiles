import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Common
import qs.Widgets

Item {
    id: root

    property string currentLocation: ""
    property string placeholderText: "Search for a location..."
    property bool _internalChange: false
    property bool isLoading: false
    property string helperTextState: "default" // "default", "prompt", "searching", "found", "not_found"
    property string currentSearchText: ""

    signal locationSelected(string displayName, string coordinates)

    function resetSearchState() {
        locationSearchTimer.stop()
        dropdownHideTimer.stop()
        if (locationSearcher.running)
            locationSearcher.running = false

        isLoading = false
        searchResultsModel.clear()
        helperTextState = "default"
    }

    width: parent.width
    height: searchInputField.height + (searchDropdown.visible ? searchDropdown.height : 0)

    ListModel {
        id: searchResultsModel
    }

    Timer {
        id: locationSearchTimer

        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (locationInput.text.length > 2) {
                if (locationSearcher.running)
                    locationSearcher.running = false

                searchResultsModel.clear()
                root.isLoading = true
                root.helperTextState = "searching"
                const searchLocation = locationInput.text
                root.currentSearchText = searchLocation
                const encodedLocation = encodeURIComponent(searchLocation)
                const curlCommand = `curl -4 -s --connect-timeout 5 --max-time 10 'https://nominatim.openstreetmap.org/search?q=${encodedLocation}&format=json&limit=5&addressdetails=1'`
                locationSearcher.command = ["bash", "-c", curlCommand]
                locationSearcher.running = true
            }
        }
    }

    Timer {
        id: dropdownHideTimer

        interval: 200
        running: false
        repeat: false
        onTriggered: {
            if (!locationInput.getActiveFocus() && !searchDropdown.hovered)
                root.resetSearchState()
        }
    }

    Process {
        id: locationSearcher

        command: ["bash", "-c", "echo"]
        running: false
        onExited: exitCode => {
                      root.isLoading = false
                      if (exitCode !== 0) {
                          searchResultsModel.clear()
                          root.helperTextState = "not_found"
                      }
                  }

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.currentSearchText !== locationInput.text)
                    return

                const raw = text.trim()
                root.isLoading = false
                searchResultsModel.clear()
                if (!raw || raw[0] !== "[") {
                    root.helperTextState = "not_found"
                    return
                }
                try {
                    const data = JSON.parse(raw)
                    if (data.length === 0) {
                        root.helperTextState = "not_found"
                        return
                    }
                    for (var i = 0; i < Math.min(data.length, 5); i++) {
                        const location = data[i]
                        if (location.display_name && location.lat
                                && location.lon) {
                            const parts = location.display_name.split(', ')
                            let cleanName = parts[0]
                            if (parts.length > 1) {
                                const state = parts[parts.length - 2]
                                if (state && state !== cleanName)
                                    cleanName += `, ${state}`
                            }
                            const query = `${location.lat},${location.lon}`
                            searchResultsModel.append({
                                                          "name": cleanName,
                                                          "query": query
                                                      })
                        }
                    }
                    root.helperTextState = "found"
                } catch (e) {
                    root.helperTextState = "not_found"
                }
            }
        }
    }

    Item {
        id: searchInputField

        width: parent.width
        height: 48

        DankTextField {
            id: locationInput

            width: parent.width
            height: parent.height
            leftIconName: "search"
            placeholderText: root.placeholderText
            text: root.currentLocation
            backgroundColor: Theme.surfaceVariant
            normalBorderColor: Theme.primarySelected
            focusedBorderColor: Theme.primary
            onTextEdited: {
                if (root._internalChange)
                    return

                if (getActiveFocus()) {
                    if (text.length > 2) {
                        root.isLoading = true
                        root.helperTextState = "searching"
                        locationSearchTimer.restart()
                    } else {
                        root.resetSearchState()
                        root.helperTextState = "prompt"
                    }
                }
            }
            onFocusStateChanged: hasFocus => {
                                     if (hasFocus) {
                                         dropdownHideTimer.stop()
                                         if (text.length <= 2)
                                         root.helperTextState = "prompt"
                                     } else {
                                         dropdownHideTimer.start()
                                     }
                                 }
        }

        DankIcon {
            name: {
                if (root.isLoading)
                    return "hourglass_empty"

                if (searchResultsModel.count > 0)
                    return "check_circle"

                if (locationInput.getActiveFocus()
                        && locationInput.text.length > 2 && !root.isLoading)
                    return "error"

                return ""
            }
            size: Theme.iconSize - 4
            color: {
                if (root.isLoading)
                    return Theme.surfaceVariantText

                if (searchResultsModel.count > 0)
                    return Theme.success || Theme.primary

                if (locationInput.getActiveFocus()
                        && locationInput.text.length > 2)
                    return Theme.error

                return "transparent"
            }
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            opacity: (locationInput.getActiveFocus()
                      && locationInput.text.length > 2) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }

    StyledRect {
        id: searchDropdown

        property bool hovered: false

        width: parent.width
        height: Math.min(
                    Math.max(
                        searchResultsModel.count * 38 + Theme.spacingS * 2,
                        50), 200)
        y: searchInputField.height
        radius: Theme.cornerRadius
        color: Theme.popupBackground()
        border.color: Theme.primarySelected
        border.width: 1
        visible: locationInput.getActiveFocus() && locationInput.text.length > 2
                 && (searchResultsModel.count > 0 || root.isLoading)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                parent.hovered = true
                dropdownHideTimer.stop()
            }
            onExited: {
                parent.hovered = false
                if (!locationInput.getActiveFocus())
                    dropdownHideTimer.start()
            }
            acceptedButtons: Qt.NoButton
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            DankListView {
                id: searchResultsList

                anchors.fill: parent
                clip: true
                model: searchResultsModel
                spacing: 2

                // Qt 6.9+ scrolling: flickDeceleration/maximumFlickVelocity only affect touch now
                interactive: true
                flickDeceleration: 1500
                maximumFlickVelocity: 2000
                boundsBehavior: Flickable.DragAndOvershootBounds
                boundsMovement: Flickable.FollowBoundsBehavior
                pressDelay: 0
                flickableDirection: Flickable.VerticalFlick

                // Custom wheel handler for Qt 6.9+ responsive mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property real momentum: 0
                    onWheel: event => {
                                 if (event.pixelDelta.y !== 0) {
                                     // Touchpad with pixel delta
                                     momentum = event.pixelDelta.y * 1.8
                                 } else {
                                     // Mouse wheel with angle delta
                                     momentum = (event.angleDelta.y / 120)
                                     * ((36 + parent.spacing) * 2.5) // ~2.5 items per wheel step
                                 }

                                 let newY = parent.contentY - momentum
                                 newY = Math.max(
                                     0, Math.min(
                                         parent.contentHeight - parent.height,
                                         newY))
                                 parent.contentY = newY
                                 momentum *= 0.92 // Decay for smooth momentum
                                 event.accepted = true
                             }
                }

                delegate: StyledRect {
                    width: searchResultsList.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: resultMouseArea.containsMouse ? Theme.surfaceLight : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "place"
                            size: Theme.iconSize - 6
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: model.name || "Unknown"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - 30
                        }
                    }

                    MouseArea {
                        id: resultMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._internalChange = true
                            const selectedName = model.name
                            const selectedQuery = model.query
                            locationInput.text = selectedName
                            root.locationSelected(selectedName, selectedQuery)
                            root.resetSearchState()
                            locationInput.setFocus(false)
                            root._internalChange = false
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: root.isLoading ? "Searching..." : "No locations found"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: searchResultsList.count === 0
                         && locationInput.text.length > 2
            }
        }
    }
}
