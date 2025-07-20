import "Components"
import QtQuick 6.8
import QtQuick.Effects 6.8
import QtMultimedia 6.8

Item {
    id: root
    height: Screen.height
    width: Screen.width

    property bool isPrimary: primaryScreen

    FontLoader {
        id: primaryFont

        source: Qt.resolvedUrl("fonts/Oxanium-SemiBold.ttf")
    }

    Item { //Primary monitor view
        id: primaryView

        visible: isPrimary
        anchors.fill: parent

        Background {
            id: background
            anchors.fill: parent
        }

        LoginScreen {
            id: loginScreen
            timePosition: background.position
        }
        
        layer.enabled: JSON.parse(config.HueShift)
        layer.effect: ShaderEffect {
            property date dateTime: new Date()
            Timer {
                interval: 60000
                running: true
                repeat: true
                onTriggered: dateTime = new Date()
            }

            //Adjust Hue to current time of the day
            property real hue: (dateTime.getHours() * 60 + dateTime.getMinutes()) / 1440 + JSON.parse(config.HueShiftAmount)
            fragmentShader: Qt.resolvedUrl("shader/hue.frag.qsb")
        }
    }

    Item { //View on other monitors
        id: secondaryView

        visible: !isPrimary
        anchors.fill: parent
    }
}
