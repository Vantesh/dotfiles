import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string passwordBuffer: ""
    property bool demoMode: false
    property string screenName: ""
    property bool unlocking: false
    property string pamState: ""
    property string randomFact: ""

    signal unlockRequested

    // Internal power dialog state
    property bool powerDialogVisible: false
    property string powerDialogTitle: ""
    property string powerDialogMessage: ""
    property string powerDialogConfirmText: ""
    property color powerDialogConfirmColor: Theme.primary
    property var powerDialogOnConfirm: function () {}

    function showPowerDialog(title, message, confirmText, confirmColor, onConfirm) {
        powerDialogTitle = title
        powerDialogMessage = message
        powerDialogConfirmText = confirmText
        powerDialogConfirmColor = confirmColor
        powerDialogOnConfirm = onConfirm
        powerDialogVisible = true
    }

    function hidePowerDialog() {
        powerDialogVisible = false
    }

    property var facts: ["A photon takes 100,000 to 200,000 years bouncing through the Sun's dense core, then races to Earth in just 8 minutes 20 seconds.", "A teaspoon of neutron star matter would weigh a billion metric tons here on Earth.", "Right now, 100 trillion solar neutrinos are passing through your body every second.", "The Sun converts 4 million metric tons of matter into pure energy every second—enough to power Earth for 500,000 years.", "The universe still glows with leftover heat from the Big Bang—just 2.7 degrees above absolute zero.", "There's a nebula out there that's actually colder than empty space itself.", "We've detected black holes crashing together by measuring spacetime stretch by less than 1/10,000th the width of a proton.", "Fast radio bursts can release more energy in 5 milliseconds than our Sun produces in 3 days.", "Our galaxy might be crawling with billions of rogue planets drifting alone in the dark.", "Distant galaxies can move away from us faster than light because space itself is stretching.", "The edge of what we can see is 46.5 billion light-years away, even though the universe is only 13.8 billion years old.", "The universe is mostly invisible: 5% regular matter, 27% dark matter, 68% dark energy.", "A day on Venus lasts longer than its entire year around the Sun.", "On Mercury, the time between sunrises is 176 Earth days long.", "In about 4.5 billion years, our galaxy will smash into Andromeda.", "Most of the gold in your jewelry was forged when neutron stars collided somewhere in space.", "PSR J1748-2446ad, the fastest spinning star, rotates 716 times per second—its equator moves at 24% the speed of light.", "Cosmic rays create particles that shouldn't make it to Earth's surface, but time dilation lets them sneak through.", "Jupiter's magnetic field is so huge that if we could see it, it would look bigger than the Moon in our sky.", "Interstellar space is so empty it's like a cube 32 kilometers wide containing just a single grain of sand.", "Voyager 1 is 24 billion kilometers away but won't leave the Sun's gravitational influence for another 30,000 years.", "Counting to a billion at one number per second would take over 31 years.", "Space is so vast, even speeding at light-speed, you'd never return past the cosmic horizon.", "Astronauts on the ISS age about 0.01 seconds less each year than people on Earth.", "Sagittarius B2, a dust cloud near our galaxy's center, contains ethyl formate—the compound that gives raspberries their flavor and rum its smell.", "Beyond 16 billion light-years, the cosmic event horizon marks where space expands too fast for light to ever reach us again.", "Even at light-speed, you'd never catch up to most galaxies—space expands faster.", "Only around 5% of galaxies are ever reachable—even at light-speed.", "If the Sun vanished, we'd still orbit it for 8 minutes before drifting away.", "If a planet 65 million light-years away looked at Earth now, it'd see dinosaurs.", "Our oldest radio signals will reach the Milky Way's center in 26,000 years.", "Every atom in your body heavier than hydrogen was forged in the nuclear furnace of a dying star.", "The Moon moves 3.8 centimeters farther from Earth every year.", "The universe creates 275 million new stars every single day.", "Jupiter's Great Red Spot is a storm twice the size of Earth that has been raging for at least 350 years.", "If you watched someone fall into a black hole, they'd appear frozen at the event horizon forever—time effectively stops from your perspective.", "The Boötes Supervoid is a cosmic desert 1.8 billion light-years across with 60% fewer galaxies than it should have."]

    function pickRandomFact() {
        randomFact = facts[Math.floor(Math.random() * facts.length)]
    }

    Component.onCompleted: {
        if (demoMode) {
            pickRandomFact()
        }

        WeatherService.addRef()
        UserInfoService.refreshUserInfo()
    }
    onDemoModeChanged: {
        if (demoMode) {
            pickRandomFact()
        }
    }
    Component.onDestruction: {
        WeatherService.removeRef()
    }

    Loader {
        anchors.fill: parent
        active: {
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
            return !currentWallpaper || (currentWallpaper && currentWallpaper.startsWith("#"))
        }
        asynchronous: true

        sourceComponent: DankBackdrop {
            screenName: root.screenName
        }
    }

    Image {
        id: wallpaperBackground

        anchors.fill: parent
        source: {
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName)
            if (screenName && currentWallpaper && currentWallpaper.startsWith("we:")) {
                const cacheHome = StandardPaths.writableLocation(StandardPaths.CacheLocation).toString()
                const baseDir = Paths.strip(cacheHome)
                const screenshotPath = baseDir + "/dankshell/we_screenshots" + "/" + currentWallpaper.substring(3) + ".jpg"
                return screenshotPath
            }
            return (currentWallpaper && !currentWallpaper.startsWith("#")) ? currentWallpaper : ""
        }
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        cache: true
        visible: source !== ""
        layer.enabled: true

        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.8
            blurMax: 32
            blurMultiplier: 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
    }

    SystemClock {
        id: systemClock

        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -100
            width: 400
            height: 140

            StyledText {
                id: clockText

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                text: {
                    const format = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP"
                    return systemClock.date.toLocaleTimeString(Qt.locale(), format)
                }
                font.pixelSize: 120
                font.weight: Font.Light
                color: "white"
                lineHeight: 0.8
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clockText.bottom
                anchors.topMargin: -20
                text: {
                    if (SettingsData.lockDateFormat && SettingsData.lockDateFormat.length > 0) {
                        return systemClock.date.toLocaleDateString(Qt.locale(), SettingsData.lockDateFormat)
                    }
                    return systemClock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                }
                font.pixelSize: Theme.fontSizeXLarge
                color: "white"
                opacity: 0.9
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 50
            spacing: Theme.spacingM
            width: 380

            RowLayout {
                spacing: Theme.spacingL
                Layout.fillWidth: true

                Item {
                    id: avatarContainer

                    property bool hasImage: profileImageLoader.status === Image.Ready

                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 1
                        visible: parent.hasImage
                    }

                    Image {
                        id: profileImageLoader

                        source: {
                            if (PortalService.profileImage === "") {
                                return ""
                            }

                            if (PortalService.profileImage.startsWith("/")) {
                                return "file://" + PortalService.profileImage
                            }

                            return PortalService.profileImage
                        }
                        smooth: true
                        asynchronous: true
                        mipmap: true
                        cache: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: profileImageLoader
                        maskEnabled: true
                        maskSource: circularMask
                        visible: avatarContainer.hasImage
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Item {
                        id: circularMask

                        width: 60 - 10
                        height: 60 - 10
                        layer.enabled: true
                        layer.smooth: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "black"
                            antialiasing: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.primary
                        visible: !parent.hasImage

                        DankIcon {
                            anchors.centerIn: parent
                            name: "person"
                            size: Theme.iconSize + 4
                            color: Theme.primaryText
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "warning"
                        size: Theme.iconSize + 4
                        color: Theme.primaryText
                        visible: PortalService.profileImage !== "" && profileImageLoader.status === Image.Error
                    }
                }

                Rectangle {
                    property bool showPassword: false

                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                    border.color: passwordField.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.3)
                    border.width: passwordField.activeFocus ? 2 : 1

                    DankIcon {
                        id: lockIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock"
                        size: 20
                        color: passwordField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                    }

                    TextInput {
                        id: passwordField

                        anchors.fill: parent
                        anchors.leftMargin: lockIcon.width + Theme.spacingM * 2
                        anchors.rightMargin: {
                            let margin = Theme.spacingM
                            if (loadingSpinner.visible) {
                                margin += loadingSpinner.width
                            }
                            if (enterButton.visible) {
                                margin += enterButton.width + 2
                            }
                            if (virtualKeyboardButton.visible) {
                                margin += virtualKeyboardButton.width
                            }
                            if (revealButton.visible) {
                                margin += revealButton.width
                            }
                            return margin
                        }
                        opacity: 0
                        focus: true
                        enabled: !demoMode
                        activeFocusOnTab: !demoMode
                        echoMode: parent.showPassword ? TextInput.Normal : TextInput.Password
                        onTextChanged: {
                            if (!demoMode) {
                                root.passwordBuffer = text
                            }
                        }
                        onAccepted: {
                            if (!demoMode && root.passwordBuffer.length > 0 && !pam.active) {
                                console.log("Enter pressed, starting PAM authentication")
                                pam.start()
                            }
                        }
                        Keys.onPressed: event => {
                                            if (demoMode) {
                                                return
                                            }

                                            if (pam.active) {
                                                console.log("PAM is active, ignoring input")
                                                event.accepted = true
                                                return
                                            }
                                        }

                        Component.onCompleted: {
                            if (!demoMode) {
                                forceActiveFocus()
                            }
                        }

                        onVisibleChanged: {
                            if (visible && !demoMode) {
                                forceActiveFocus()
                            }
                        }
                    }

                    KeyboardController {
                        id: keyboardController
                        target: passwordField
                        rootObject: root
                    }

                    StyledText {
                        id: placeholder

                        anchors.left: lockIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: (revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))))
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (demoMode) {
                                return ""
                            }
                            if (root.unlocking) {
                                return "Unlocking..."
                            }
                            if (pam.active) {
                                return "Authenticating..."
                            }
                            return "Password..."
                        }
                        color: root.unlocking ? Theme.primary : (pam.active ? Theme.primary : Theme.outline)
                        font.pixelSize: Theme.fontSizeMedium
                        opacity: (demoMode || root.passwordBuffer.length === 0) ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    StyledText {
                        anchors.left: lockIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: (revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))))
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (demoMode) {
                                return "••••••••"
                            }
                            if (parent.showPassword) {
                                return root.passwordBuffer
                            }
                            return "•".repeat(Math.min(root.passwordBuffer.length, 25))
                        }
                        color: Theme.surfaceText
                        font.pixelSize: parent.showPassword ? Theme.fontSizeMedium : Theme.fontSizeLarge
                        opacity: (demoMode || root.passwordBuffer.length > 0) ? 1 : 0
                        elide: Text.ElideRight

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankActionButton {
                        id: revealButton

                        anchors.right: virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right))
                        anchors.rightMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: parent.showPassword ? "visibility_off" : "visibility"
                        buttonSize: 32
                        visible: !demoMode && root.passwordBuffer.length > 0 && !pam.active && !root.unlocking
                        enabled: visible
                        onClicked: parent.showPassword = !parent.showPassword
                    }
                    DankActionButton {
                        id: virtualKeyboardButton

                        anchors.right: enterButton.visible ? enterButton.left : (loadingSpinner.visible ? loadingSpinner.left : parent.right)
                        anchors.rightMargin: enterButton.visible ? 0 : Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "keyboard"
                        buttonSize: 32
                        visible: !demoMode && !pam.active && !root.unlocking
                        enabled: visible
                        onClicked: {
                            if (keyboardController.isKeyboardActive) {
                                keyboardController.hide()
                            } else {
                                keyboardController.show()
                            }
                        }
                    }

                    Rectangle {
                        id: loadingSpinner

                        anchors.right: enterButton.visible ? enterButton.left : parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: 12
                        color: "transparent"
                        visible: !demoMode && (pam.active || root.unlocking)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check_circle"
                            size: 20
                            color: Theme.primary
                            visible: root.unlocking

                            SequentialAnimation on scale {
                                running: root.unlocking

                                NumberAnimation {
                                    from: 0
                                    to: 1.2
                                    duration: Anims.durShort
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Anims.emphasizedDecel
                                }

                                NumberAnimation {
                                    from: 1.2
                                    to: 1
                                    duration: Anims.durShort
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Anims.emphasizedAccel
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: pam.active && !root.unlocking

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.centerIn: parent
                                color: "transparent"
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                border.width: 2
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.centerIn: parent
                                color: "transparent"
                                border.color: Theme.primary
                                border.width: 2

                                Rectangle {
                                    width: parent.width
                                    height: parent.height / 2
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                                }

                                RotationAnimation on rotation {
                                    running: pam.active && !root.unlocking
                                    loops: Animation.Infinite
                                    duration: Anims.durLong
                                    from: 0
                                    to: 360
                                }
                            }
                        }
                    }

                    DankActionButton {
                        id: enterButton

                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "keyboard_return"
                        buttonSize: 36
                        visible: (demoMode || (root.passwordBuffer.length > 0 && !pam.active && !root.unlocking))
                        enabled: !demoMode
                        onClicked: {
                            if (!demoMode) {
                                console.log("Enter button clicked, starting PAM authentication")
                                pam.start()
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: root.pamState ? 20 : 0
                text: {
                    if (root.pamState === "error") {
                        return "Authentication error - try again"
                    }
                    if (root.pamState === "max") {
                        return "Too many attempts - locked out"
                    }
                    if (root.pamState === "fail") {
                        return "Incorrect password - try again"
                    }
                    return ""
                }
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                visible: root.pamState !== ""
                opacity: root.pamState !== "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }

        StyledText {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            text: "DEMO MODE - Click anywhere to exit"
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
            opacity: 0.7
            visible: demoMode
        }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Row {
                spacing: 6
                visible: WeatherService.weather.available
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.iconSize
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: WeatherService.weather.available && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio) || BatteryService.batteryAvailable)
            }

            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: NetworkService.networkStatus !== "disconnected" || (BluetoothService.available && BluetoothService.enabled) || (AudioService.sink && AudioService.sink.audio)

                DankIcon {
                    name: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                    size: Theme.iconSize - 2
                    color: NetworkService.networkStatus !== "disconnected" ? "white" : Qt.rgba(255, 255, 255, 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NetworkService.networkStatus !== "disconnected"
                }

                DankIcon {
                    name: "bluetooth"
                    size: Theme.iconSize - 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BluetoothService.available && BluetoothService.enabled
                }

                DankIcon {
                    name: {
                        if (!AudioService.sink?.audio) {
                            return "volume_up"
                        }
                        if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0) {
                            return "volume_off"
                        }
                        if (AudioService.sink.audio.volume * 100 < 33) {
                            return "volume_down"
                        }
                        return "volume_up"
                    }
                    size: Theme.iconSize - 2
                    color: (AudioService.sink && AudioService.sink.audio && (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0)) ? Qt.rgba(255, 255, 255, 0.5) : "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioService.sink && AudioService.sink.audio
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: BatteryService.batteryAvailable && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio))
            }

            Row {
                spacing: 4
                visible: BatteryService.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: {
                        if (BatteryService.isCharging) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full"
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90"
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80"
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60"
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50"
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30"
                            }

                            return "battery_charging_20"
                        }
                        if (BatteryService.isPluggedIn) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full"
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90"
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80"
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60"
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50"
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30"
                            }

                            return "battery_charging_20"
                        }
                        if (BatteryService.batteryLevel >= 95) {
                            return "battery_full"
                        }

                        if (BatteryService.batteryLevel >= 85) {
                            return "battery_6_bar"
                        }

                        if (BatteryService.batteryLevel >= 70) {
                            return "battery_5_bar"
                        }

                        if (BatteryService.batteryLevel >= 55) {
                            return "battery_4_bar"
                        }

                        if (BatteryService.batteryLevel >= 40) {
                            return "battery_3_bar"
                        }

                        if (BatteryService.batteryLevel >= 25) {
                            return "battery_2_bar"
                        }

                        return "battery_1_bar"
                    }
                    size: Theme.iconSize
                    color: {
                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary
                        }

                        return "white"
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: BatteryService.batteryLevel + "%"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL
            visible: SettingsData.lockScreenShowPowerActions

            DankActionButton {
                iconName: "power_settings_new"
                iconColor: Theme.error
                buttonSize: 40
                onClicked: {
                    if (demoMode) {
                        console.log("Demo: Power")
                    } else {
                        showPowerDialog("Power Off", "Power off this computer?", "Power Off", Theme.error, function () {
                            SessionService.poweroff()
                        })
                    }
                }
            }

            DankActionButton {
                iconName: "refresh"
                buttonSize: 40
                onClicked: {
                    if (demoMode) {
                        console.log("Demo: Reboot")
                    } else {
                        showPowerDialog("Restart", "Restart this computer?", "Restart", Theme.primary, function () {
                            SessionService.reboot()
                        })
                    }
                }
            }

            DankActionButton {
                iconName: "logout"
                buttonSize: 40
                onClicked: {
                    if (demoMode) {
                        console.log("Demo: Logout")
                    } else {
                        showPowerDialog("Log Out", "End this session?", "Log Out", Theme.primary, function () {
                            SessionService.logout()
                        })
                    }
                }
            }
        }

        StyledText {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.spacingL
            width: Math.min(parent.width - Theme.spacingXL * 2, implicitWidth)
            text: root.randomFact
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
            opacity: 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            visible: root.randomFact !== ""
        }
    }

    FileView {
        id: pamConfigWatcher

        path: "/etc/pam.d/dankshell"
        printErrors: false
    }

    PamContext {
        id: pam

        config: pamConfigWatcher.loaded ? "dankshell" : "login"
        onResponseRequiredChanged: {
            if (demoMode)
                return

            console.log("PAM response required:", responseRequired)
            if (!responseRequired)
                return

            console.log("Responding to PAM with password buffer length:", root.passwordBuffer.length)
            respond(root.passwordBuffer)
        }
        onCompleted: res => {
                         if (demoMode)
                         return

                         console.log("PAM authentication completed with result:", res)
                         if (res === PamResult.Success) {
                             console.log("Authentication successful, unlocking")
                             root.unlocking = true
                             passwordField.text = ""
                             root.passwordBuffer = ""
                             root.unlockRequested()
                             return
                         }
                         console.log("Authentication failed:", res)
                         if (res === PamResult.Error)
                         root.pamState = "error"
                         else if (res === PamResult.MaxTries)
                         root.pamState = "max"
                         else if (res === PamResult.Failed)
                         root.pamState = "fail"
                         placeholderDelay.restart()
                     }
    }

    Timer {
        id: placeholderDelay

        interval: 4000
        onTriggered: root.pamState = ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: demoMode
        onClicked: root.unlockRequested()
    }

    // Internal power dialog
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.8)
        visible: powerDialogVisible
        z: 1000

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 180
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXL

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "power_settings_new"
                    size: 32
                    color: powerDialogConfirmColor
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: powerDialogMessage
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 100
                        height: 40
                        radius: Theme.cornerRadius
                        color: Theme.surfaceVariant

                        StyledText {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hidePowerDialog()
                        }
                    }

                    Rectangle {
                        width: 100
                        height: 40
                        radius: Theme.cornerRadius
                        color: powerDialogConfirmColor

                        StyledText {
                            anchors.centerIn: parent
                            text: powerDialogConfirmText
                            color: Theme.primaryText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hidePowerDialog()
                                powerDialogOnConfirm()
                            }
                        }
                    }
                }
            }
        }
    }
}
