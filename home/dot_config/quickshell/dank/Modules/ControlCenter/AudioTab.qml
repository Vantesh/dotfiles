import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.Common
import qs.Modules.ControlCenter.Audio
import qs.Services
import qs.Widgets

Item {
    id: audioTab

    property int audioSubTab: 0

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        DankTabBar {
            width: parent.width
            tabHeight: 40
            currentIndex: audioTab.audioSubTab
            showIcons: false
            model: [{
                    "text": "Output"
                }, {
                    "text": "Input"
                }]
            onTabClicked: function (index) {
                audioTab.audioSubTab = index
            }
        }

        // Single Loader that switches between Output and Input
        Loader {
            width: parent.width
            height: parent.height - 48
            asynchronous: true
            sourceComponent: audioTab.audioSubTab === 0 ? outputTabComponent : inputTabComponent
        }
    }

    // Output Tab Component
    Component {
        id: outputTabComponent
        DankFlickable {
            clip: true
            contentHeight: outputColumn.height
            contentWidth: width

            Column {
                id: outputColumn
                width: parent.width
                spacing: Theme.spacingL

                Loader {
                    width: parent.width
                    sourceComponent: volumeComponent
                }

                Loader {
                    width: parent.width
                    sourceComponent: outputDevicesComponent
                }
            }
        }
    }

    // Input Tab Component
    Component {
        id: inputTabComponent
        DankFlickable {
            clip: true
            contentHeight: inputColumn.height
            contentWidth: width

            Column {
                id: inputColumn
                width: parent.width
                spacing: Theme.spacingL

                Loader {
                    width: parent.width
                    sourceComponent: microphoneComponent
                }

                Loader {
                    width: parent.width
                    sourceComponent: inputDevicesComponent
                }
            }
        }
    }

    // Volume Control Component
    Component {
        id: volumeComponent
        VolumeControl {
            width: parent.width
        }
    }

    // Microphone Control Component
    Component {
        id: microphoneComponent
        MicrophoneControl {
            width: parent.width
        }
    }

    // Output Devices Component
    Component {
        id: outputDevicesComponent
        AudioDevicesList {
            width: parent.width
        }
    }

    // Input Devices Component
    Component {
        id: inputDevicesComponent
        AudioInputDevicesList {
            width: parent.width
        }
    }
}
