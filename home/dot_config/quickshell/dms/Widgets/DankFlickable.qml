import QtQuick
import QtQuick.Controls
import qs.Common

Flickable {
    id: flickable

    property real mouseWheelSpeed: 60
    property real momentumVelocity: 0
    property bool isMomentumActive: false
    property real friction: 0.95
    property real minMomentumVelocity: 50
    property real maxMomentumVelocity: 2500
    // Internal: controls transient scrollbar visibility
    property bool _scrollBarActive: false

    flickDeceleration: 1500
    maximumFlickVelocity: 2000
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    pressDelay: 0
    flickableDirection: Flickable.VerticalFlick

    WheelHandler {
        id: wheelHandler

        property real touchpadSpeed: 1.8
        property real momentumRetention: 0.92
        property real lastWheelTime: 0
        property real momentum: 0
        property var velocitySamples: []

        function startMomentum() {
            flickable.isMomentumActive = true
            momentumTimer.start()
        }

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
                     // Activate scrollbar on any wheel interaction
                     flickable._scrollBarActive = true
                     hideScrollBarTimer.restart()
                     let currentTime = Date.now()
                     let timeDelta = currentTime - lastWheelTime
                     lastWheelTime = currentTime

                     const deltaY = event.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120
                     && (Math.abs(deltaY) % 120) === 0

                     if (isMouseWheel) {
                         momentumTimer.stop()
                         flickable.isMomentumActive = false
                         velocitySamples = []
                         momentum = 0

                         const lines = Math.floor(Math.abs(deltaY) / 120)
                         const scrollAmount = (deltaY > 0 ? -lines : lines)
                         * flickable.mouseWheelSpeed
                         let newY = flickable.contentY + scrollAmount
                         newY = Math.max(
                             0, Math.min(
                                 flickable.contentHeight - flickable.height,
                                 newY))

                         if (flickable.flicking)
                         flickable.cancelFlick()

                         flickable.contentY = newY
                     } else {
                         momentumTimer.stop()
                         flickable.isMomentumActive = false

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
                         velocitySamples = velocitySamples.filter(s => {
                                                                      return currentTime
                                                                      - s.time < 100
                                                                  })

                         if (velocitySamples.length > 1) {
                             let totalDelta = velocitySamples.reduce(
                                 (sum, s) => {
                                     return sum + s.delta
                                 }, 0)
                             let timeSpan = currentTime - velocitySamples[0].time
                             if (timeSpan > 0)
                             flickable.momentumVelocity = Math.max(
                                 -flickable.maxMomentumVelocity,
                                 Math.min(flickable.maxMomentumVelocity,
                                          totalDelta / timeSpan * 1000))
                         }

                         if (event.pixelDelta.y !== 0 && timeDelta < 50) {
                             momentum = momentum * momentumRetention + delta * 0.15
                             delta += momentum
                         } else {
                             momentum = 0
                         }

                         let newY = flickable.contentY - delta
                         newY = Math.max(
                             0, Math.min(
                                 flickable.contentHeight - flickable.height,
                                 newY))

                         if (flickable.flicking)
                         flickable.cancelFlick()

                         flickable.contentY = newY
                     }

                     event.accepted = true
                 }

        onActiveChanged: {
            if (!active) {
                if (Math.abs(flickable.momentumVelocity) >= flickable.minMomentumVelocity) {
                    startMomentum()
                } else {
                    velocitySamples = []
                    flickable.momentumVelocity = 0
                }
            }
        }
    }

    // Show scrollbar while flicking / momentum
    onMovementStarted: {
        _scrollBarActive = true
        hideScrollBarTimer.stop()
    }
    onMovementEnded: hideScrollBarTimer.restart()

    Timer {
        id: momentumTimer
        interval: 16
        repeat: true

        onTriggered: {
            let newY = flickable.contentY - flickable.momentumVelocity * 0.016
            let maxY = Math.max(0, flickable.contentHeight - flickable.height)

            if (newY < 0) {
                flickable.contentY = 0
                stop()
                flickable.isMomentumActive = false
                flickable.momentumVelocity = 0
                return
            } else if (newY > maxY) {
                flickable.contentY = maxY
                stop()
                flickable.isMomentumActive = false
                flickable.momentumVelocity = 0
                return
            }

            flickable.contentY = newY

            flickable.momentumVelocity *= flickable.friction

            if (Math.abs(flickable.momentumVelocity) < 5) {
                stop()
                flickable.isMomentumActive = false
                flickable.momentumVelocity = 0
            }
        }
    }

    NumberAnimation {
        id: returnToBoundsAnimation
        target: flickable
        property: "contentY"
        duration: 300
        easing.type: Easing.OutQuad
    }

    // Styled vertical scrollbar (auto-hide, no track)
    ScrollBar.vertical: ScrollBar {
        id: vbar
        policy: flickable.contentHeight
                > flickable.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        minimumSize: 0.08
        implicitWidth: 10
        interactive: true
        hoverEnabled: true
        z: 1000
        opacity: (policy !== ScrollBar.AlwaysOff)
                 && (vbar.pressed || vbar.hovered || vbar.active
                     || flickable.moving || flickable.flicking
                     || flickable.isMomentumActive
                     || flickable._scrollBarActive) ? 1 : 0
        visible: policy !== ScrollBar.AlwaysOff
        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        contentItem: Rectangle {
            implicitWidth: 6
            radius: width / 2
            color: vbar.pressed ? Theme.primary : (vbar.hovered || vbar.active
                                                   || flickable.moving
                                                   || flickable.flicking
                                                   || flickable.isMomentumActive
                                                   || flickable._scrollBarActive ? Theme.outline : Theme.outlineMedium)
            opacity: vbar.pressed ? 1 : (vbar.hovered || vbar.active
                                         || flickable.moving
                                         || flickable.flicking
                                         || flickable.isMomentumActive
                                         || flickable._scrollBarActive ? 1 : 0.6)
        }

        background: Item {}
    }

    Timer {
        id: hideScrollBarTimer
        interval: 1200
        onTriggered: flickable._scrollBarActive = false
    }
}
