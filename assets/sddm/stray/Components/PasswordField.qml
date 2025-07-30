import QtQuick 6.8
import QtQuick.Controls 6.8

TextInput {
    id: textField

    function runAnimation() {
        removeTextAnimation.start();
    }

    signal animationDone;

    
    focus: true
    selectByMouse: false
    clip: true
    autoScroll: true
    echoMode: TextInput.Password
    passwordCharacter: config.PasswordCharacter
    passwordMaskDelay: config.PasswordShowLastCharDelay

    font {
        family: primaryFont.name
    }
    color: "white"
    selectionColor: "white"
    padding: 0

    horizontalAlignment: TextInput.AlignHCenter
    verticalAlignment: TextInput.AlignVCenter

    property int index: 0

    SequentialAnimation {
        id: removeTextAnimation

        ScriptAction {
            script: {
                index = textField.text.length
                removeTextTimer.start()
            }
        }
    }

    Timer {
        id: removeTextTimer
        interval: 25
        repeat: true
        onTriggered: {
            if (index <= 0)
            {
                stop();
                animationDone();
                return;
            }
            textField.text = textField.text.substring(0, index - 1);
            index--;
        }
    }
}
