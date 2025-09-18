import QtQuick
import Qt.labs.platform
import Quickshell
import qs.Common
import qs.Services

Item {
    id: colorPickerModal

    signal colorSelected(color selectedColor)

    function show() {
        colorDialog.open()
    }

    function hide() {
        colorDialog.close()
    }

    function copyColorToClipboard(colorValue) {
        Quickshell.execDetached(["sh", "-c", `echo "${colorValue}" | wl-copy`])
        ToastService.showInfo(`Color ${colorValue} copied to clipboard`)
        console.log("Copied color to clipboard:", colorValue)
    }

    ColorDialog {
        id: colorDialog
        title: "Color Picker - Select and copy color"
        color: Theme.primary

        onAccepted: {
            const colorString = color.toString()
            copyColorToClipboard(colorString)
            colorSelected(color)
        }
    }
}