import QtQuick
import QtQuick.Controls
import qs.Widgets

ListView {
    id: listView

    property real mouseWheelSpeed: 60
    property real savedY: 0
    property bool justChanged: false
    property bool isUserScrolling: false
    property real momentumVelocity: 0
    property bool isMomentumActive: false
    property real friction: 0.95
    property real minMomentumVelocity: 50
    property real maxMomentumVelocity: 2500

    flickDeceleration: 1500
    maximumFlickVelocity: 2000
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    pressDelay: 0
    flickableDirection: Flickable.VerticalFlick

    onMovementStarted: {
        isUserScrolling = true
        vbar._scrollBarActive = true
        vbar.hideTimer.stop()
    }
    onMovementEnded: {
        isUserScrolling = false
        vbar.hideTimer.restart()
    }

    onContentYChanged: {
        if (!justChanged && isUserScrolling) {
            savedY = contentY
        }
        justChanged = false
    }

    onModelChanged: {
        justChanged = true
        contentY = savedY
    }

    WheelHandler {
        id: wheelHandler
        property real touchpadSpeed: 1.8
        property real lastWheelTime: 0
        property real momentum: 0
        property var velocitySamples: []

        function startMomentum() {
            isMomentumActive = true
            momentumTimer.start()
        }

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
                     isUserScrolling = true
                     vbar._scrollBarActive = true
                     vbar.hideTimer.restart()

                     const currentTime = Date.now()
                     const timeDelta = currentTime - lastWheelTime
                     lastWheelTime = currentTime

                     const deltaY = event.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0

                     if (isMouseWheel) {
                         momentumTimer.stop()
                         isMomentumActive = false
                         velocitySamples = []
                         momentum = 0

                         const lines = Math.floor(Math.abs(deltaY) / 120)
                         const scrollAmount = (deltaY > 0 ? -lines : lines) * mouseWheelSpeed
                         let newY = listView.contentY + scrollAmount
                         newY = Math.max(0, Math.min(listView.contentHeight - listView.height, newY))

                         if (listView.flicking) {
                             listView.cancelFlick()
                         }

                         listView.contentY = newY
                         savedY = newY
                     } else {
                         momentumTimer.stop()
                         isMomentumActive = false

                         let delta = 0
                         if (event.pixelDelta.y !== 0) {
                             delta = event.pixelDelta.y * touchpadSpeed
                         } else {
                             delta = event.angleDelta.y / 8 * touchpadSpeed
                         }

                         velocitySamples.push({
                                                  "delta": delta,
                                                  "time": currentTime
                                              })
                         velocitySamples = velocitySamples.filter(s => currentTime - s.time < 100)

                         if (velocitySamples.length > 1) {
                             const totalDelta = velocitySamples.reduce((sum, s) => sum + s.delta, 0)
                             const timeSpan = currentTime - velocitySamples[0].time
                             if (timeSpan > 0) {
                                 momentumVelocity = Math.max(-maxMomentumVelocity, Math.min(maxMomentumVelocity, totalDelta / timeSpan * 1000))
                             }
                         }

                         if (event.pixelDelta.y !== 0 && timeDelta < 50) {
                             momentum = momentum * 0.92 + delta * 0.15
                             delta += momentum
                         } else {
                             momentum = 0
                         }

                         let newY = listView.contentY - delta
                         newY = Math.max(0, Math.min(listView.contentHeight - listView.height, newY))

                         if (listView.flicking) {
                             listView.cancelFlick()
                         }

                         listView.contentY = newY
                         savedY = newY
                     }

                     event.accepted = true
                 }

        onActiveChanged: {
            if (!active) {
                isUserScrolling = false
                if (Math.abs(momentumVelocity) >= minMomentumVelocity) {
                    startMomentum()
                } else {
                    velocitySamples = []
                    momentumVelocity = 0
                }
            }
        }
    }

    Timer {
        id: momentumTimer
        interval: 16
        repeat: true

        onTriggered: {
            const newY = contentY - momentumVelocity * 0.016
            const maxY = Math.max(0, contentHeight - height)

            if (newY < 0 || newY > maxY) {
                contentY = newY < 0 ? 0 : maxY
                savedY = contentY
                stop()
                isMomentumActive = false
                momentumVelocity = 0
                return
            }

            contentY = newY
            savedY = newY
            momentumVelocity *= friction

            if (Math.abs(momentumVelocity) < 5) {
                stop()
                isMomentumActive = false
                momentumVelocity = 0
            }
        }
    }

    ScrollBar.vertical: DankScrollbar {
        id: vbar
    }
}
