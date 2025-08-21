import QtQuick
import Quickshell

QtObject {
    required property Singleton service

    Component.onCompleted: service.refCount++
    Component.onDestruction: service.refCount--
}
