pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property int previewLength: 100
    readonly property int longTextThreshold: 200
    readonly property int modalWidth: 650
    readonly property int modalHeight: 550
    readonly property int itemHeight: 72
    readonly property int thumbnailSize: 48
    readonly property int retryInterval: 50
    readonly property int viewportBuffer: 100
    readonly property int extendedBuffer: 200
    readonly property int keyboardHintsHeight: 80
    readonly property int headerHeight: 40
}
