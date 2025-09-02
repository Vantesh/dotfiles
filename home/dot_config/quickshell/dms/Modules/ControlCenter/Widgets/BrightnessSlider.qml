import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

SimpleSlider {
    id: root

    iconName: {
        if (!DisplayService.brightnessAvailable) return "brightness_low"
        
        let brightness = DisplayService.brightnessLevel
        if (brightness <= 33) return "brightness_low"
        if (brightness <= 66) return "brightness_medium"
        return "brightness_high"
    }

    iconColor: DisplayService.brightnessAvailable && DisplayService.brightnessLevel > 0 ? Theme.primary : Theme.surfaceText

    enabled: DisplayService.brightnessAvailable

    value: DisplayService.brightnessLevel
    maximumValue: 100.0
    minimumValue: 0.0

    onSliderValueChanged: function(newValue) {
        if (DisplayService.brightnessAvailable) {
            DisplayService.brightnessLevel = newValue
        }
    }
}