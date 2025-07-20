import QtQuick 6.8
import QtQuick.Controls 6.8
import QtQuick.Effects 6.8
import "timestamps.js" as Timestamps

Item {
    property int timePosition: 0

    function tryLogin() {
        sddm.login(userPanel.user, userPanel.password, sessionPanel.currentSessionID);
    }

    Keys.forwardTo: [sessionPanel]
    //Poweroff and Reboot
    Keys.onReleased: (event) => {
        switch (event.key) {
        case Qt.Key_P:
            if (event.modifiers & Qt.MetaModifier)
                sddm.powerOff();

            break;
        case Qt.Key_R:
            if (event.modifiers & Qt.MetaModifier)
                sddm.reboot();

            break;
        }
    }

    UserPanel {
        id: userPanel

        anchors {
            centerIn: parent
        }
    }

    SessionPanel {
        id: sessionPanel

        anchors {
            bottom: parent.bottom
            bottomMargin: 35
            left: parent.left
            leftMargin: 60
        }

    }

    // Caps Lock indicator
    Rectangle {
        id: capsLockIndicator

        width: capsLockText.width + 20
        height: capsLockText.height + 10
        color: "#ff4444"
        radius: 5
        opacity: keyboard.capsLock ? 1.0 : 0.0
        visible: opacity > 0

        anchors {
            top: parent.top
            topMargin: 15
            left: parent.left
            leftMargin: 60
        }

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Text {
            id: capsLockText
            text: "CAPS LOCK"
            color: "white"
            font {
                family: primaryFont.name
                pointSize: config.fontSize * 0.8
                bold: true
            }
            anchors.centerIn: parent
        }
    }

    // Failed login indicator
    Rectangle {
        id: failedLoginIndicator

        width: failedLoginText.width + 20
        height: failedLoginText.height + 10
        color: "#cc0000"
        radius: 5
        opacity: 0.0
        visible: opacity > 0

        anchors {
            top: parent.top
            topMargin: 70
            left: parent.left
            leftMargin: 60
        }

        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }

        Text {
            id: failedLoginText
            text: "LOGIN FAILED"
            color: "white"
            font {
                family: primaryFont.name
                pointSize: config.fontSize * 0.8
                bold: true
            }
            anchors.centerIn: parent
        }

        Timer {
            id: hideFailedTimer
            interval: 3000
            repeat: false
            onTriggered: failedLoginIndicator.opacity = 0.0
        }
    }

    // Monitor login attempts
    Connections {
        target: sddm
        function onLoginFailed() {
            failedLoginIndicator.opacity = 1.0
            hideFailedTimer.restart()
        }
        function onLoginSucceeded() {
            failedLoginIndicator.opacity = 0.0
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {

        colorization: 1.0
        colorizationColor: primaryColor

        readonly property var a: Timestamps.blurInterval[0]
        readonly property var b: Timestamps.blurInterval[1]
        blurEnabled: true
        blurMax: 48
        blur: ((a > b && (timePosition >= a || timePosition <= b))
                || (a <= b && timePosition >= a && timePosition <= b))
                ? 1.0 : 0
        shadowEnabled: true
        shadowBlur : 1.0
        shadowColor : primaryColor
    }
}
