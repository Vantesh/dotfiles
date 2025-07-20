import QtQuick 6.8
import QtQuick.Controls 6.8

Item {
    property var inputHeight: 50
    property var inputWidth: loginScreen.width * 0.9
    property alias user: userField.user
    property alias password: passwordField.text

    //Pass to child since it isn't focused
    Keys.forwardTo: [userField]

    width: column.implicitWidth
    height: column.implicitHeight
    Column {
        id: column
        spacing: 30
        width: inputWidth

        UsernameField {
            id: userField
            height: inputHeight
            width: inputWidth
            anchors {
                horizontalCenter: parent.horizontalCenter
            }
            font.pointSize: config.fontSize
        }

        PasswordField {
            id: passwordField
            width: inputWidth
            anchors {
                horizontalCenter: parent.horizontalCenter
            }
            font.pointSize: config.fontSize
            onAccepted: {
                passwordField.focus = false;
                tryLogin();
            }
            onAnimationDone: {
                passwordField.focus = true;
            }
        }

    }

    Connections {
        function onLoginFailed() {
            passwordField.runAnimation();
        }

        target: sddm
    }

}
