import QtQuick
import QtQuick.Controls
import qs.Widgets

GridView {
    id: gridView

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
        vbar._scrollBarActive = true
        vbar.hideTimer.stop()
    }
    onMovementEnded: vbar.hideTimer.restart()

    WheelHandler {
        id: wheelHandler

        property real mouseWheelSpeed: 60
        property real touchpadSpeed: 1.8
        property real momentumRetention: 0.92
        property real lastWheelTime: 0
        property real momentum: 0
        property var velocitySamples: []

        function startMomentum() {
            isMomentumActive = true
            momentumTimer.start()
        }

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
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
                         const scrollAmount = (deltaY > 0 ? -lines : lines) * cellHeight * 0.35
                         let newY = contentY + scrollAmount
                         newY = Math.max(0, Math.min(contentHeight - height, newY))

                         if (flicking) {
                             cancelFlick()
                         }

                         contentY = newY
                     } else {
                         momentumTimer.stop()
                         isMomentumActive = false

                         let delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * touchpadSpeed : event.angleDelta.y / 120 * cellHeight * 1.2

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
                             momentum = momentum * momentumRetention + delta * 0.15
                             delta += momentum
                         } else {
                             momentum = 0
                         }

                         let newY = contentY - delta
                         newY = Math.max(0, Math.min(contentHeight - height, newY))

                         if (flicking) {
                             cancelFlick()
                         }

                         contentY = newY
                     }

                     event.accepted = true
                 }
        onActiveChanged: {
            if (!active) {
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
                stop()
                isMomentumActive = false
                momentumVelocity = 0
                return
            }

            contentY = newY
            momentumVelocity *= friction

            if (Math.abs(momentumVelocity) < 5) {
                stop()
                isMomentumActive = false
                momentumVelocity = 0
            }
        }
    }

    NumberAnimation {
        id: returnToBoundsAnimation
        target: gridView
        property: "contentY"
        duration: 300
        easing.type: Easing.OutQuad
    }

    ScrollBar.vertical: DankScrollbar {
        id: vbar
    }
}
