import QtQuick
import qs.Common

Item {
    id: root

    required property var barWindow
    required property var axis

    anchors.fill: parent

    anchors.left: parent.left
    anchors.top: parent.top
    anchors.leftMargin: -(SettingsData.dankBarGothCornersEnabled && axis.isVertical && axis.edge === "right" ? barWindow._wingR : 0)
    anchors.rightMargin: -(SettingsData.dankBarGothCornersEnabled && axis.isVertical && axis.edge === "left" ? barWindow._wingR : 0)
    anchors.topMargin: -(SettingsData.dankBarGothCornersEnabled && !axis.isVertical && axis.edge === "bottom" ? barWindow._wingR : 0)
    anchors.bottomMargin: -(SettingsData.dankBarGothCornersEnabled && !axis.isVertical && axis.edge === "top" ? barWindow._wingR : 0)

    Canvas {
        id: barShape
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        readonly property real correctWidth: root.width
        readonly property real correctHeight: root.height
        canvasSize: Qt.size(barWindow.px(correctWidth), barWindow.px(correctHeight))

        property real wing: SettingsData.dankBarGothCornersEnabled ? barWindow._wingR : 0
        property real rt: SettingsData.dankBarSquareCorners ? 0 : Theme.cornerRadius

        onWingChanged: requestPaint()
        onRtChanged: requestPaint()
        onCorrectWidthChanged: requestPaint()
        onCorrectHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: barWindow
            function on_BgColorChanged() { barShape.requestPaint() }
            function on_DprChanged() { barShape.requestPaint() }
        }

        Connections {
            target: Theme
            function onIsLightModeChanged() { barShape.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            const scale = barWindow._dpr
            const W = barWindow.px(barWindow.isVertical ? correctHeight : correctWidth)
            const H_raw = barWindow.px(barWindow.isVertical ? correctWidth : correctHeight)
            const R = barWindow.px(wing)
            const RT = barWindow.px(rt)
            const H = H_raw - (R > 0 ? R : 0)
            const isTop = SettingsData.dankBarPosition === SettingsData.Position.Top
            const isBottom = SettingsData.dankBarPosition === SettingsData.Position.Bottom
            const isLeft = SettingsData.dankBarPosition === SettingsData.Position.Left
            const isRight = SettingsData.dankBarPosition === SettingsData.Position.Right

            ctx.scale(scale, scale)

            function drawTopPath() {
                ctx.beginPath()
                ctx.moveTo(RT, 0)
                ctx.lineTo(W - RT, 0)
                ctx.arcTo(W, 0, W, RT, RT)
                ctx.lineTo(W, H)

                if (R > 0) {
                    ctx.lineTo(W, H + R)
                    ctx.arc(W - R, H + R, R, 0, -Math.PI / 2, true)
                    ctx.lineTo(R, H)
                    ctx.arc(R, H + R, R, -Math.PI / 2, -Math.PI, true)
                    ctx.lineTo(0, H + R)
                } else {
                    ctx.lineTo(W, H - RT)
                    ctx.arcTo(W, H, W - RT, H, RT)
                    ctx.lineTo(RT, H)
                    ctx.arcTo(0, H, 0, H - RT, RT)
                }

                ctx.lineTo(0, RT)
                ctx.arcTo(0, 0, RT, 0, RT)
                ctx.closePath()
            }

            ctx.reset()
            ctx.clearRect(0, 0, W, H_raw)

            ctx.save()
            if (isBottom) {
                ctx.translate(W, H_raw)
                ctx.rotate(Math.PI)
            } else if (isLeft) {
                ctx.translate(0, W)
                ctx.rotate(-Math.PI / 2)
            } else if (isRight) {
                ctx.translate(H_raw, 0)
                ctx.rotate(Math.PI / 2)
            }

            drawTopPath()
            ctx.restore()

            ctx.fillStyle = barWindow._bgColor
            ctx.fill()
        }
    }

    Canvas {
        id: barTint
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        readonly property real correctWidth: root.width
        readonly property real correctHeight: root.height
        canvasSize: Qt.size(barWindow.px(correctWidth), barWindow.px(correctHeight))

        property real wing: SettingsData.dankBarGothCornersEnabled ? barWindow._wingR : 0
        property real rt: SettingsData.dankBarSquareCorners ? 0 : Theme.cornerRadius
        property real alphaTint: (barWindow._bgColor?.a ?? 1) < 0.99 ? (Theme.stateLayerOpacity ?? 0) : 0

        onWingChanged: requestPaint()
        onRtChanged: requestPaint()
        onAlphaTintChanged: requestPaint()
        onCorrectWidthChanged: requestPaint()
        onCorrectHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: barWindow
            function on_BgColorChanged() { barTint.requestPaint() }
            function on_DprChanged() { barTint.requestPaint() }
        }

        Connections {
            target: Theme
            function onIsLightModeChanged() { barTint.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            const scale = barWindow._dpr
            const W = barWindow.px(barWindow.isVertical ? correctHeight : correctWidth)
            const H_raw = barWindow.px(barWindow.isVertical ? correctWidth : correctHeight)
            const R = barWindow.px(wing)
            const RT = barWindow.px(rt)
            const H = H_raw - (R > 0 ? R : 0)
            const isTop = SettingsData.dankBarPosition === SettingsData.Position.Top
            const isBottom = SettingsData.dankBarPosition === SettingsData.Position.Bottom
            const isLeft = SettingsData.dankBarPosition === SettingsData.Position.Left
            const isRight = SettingsData.dankBarPosition === SettingsData.Position.Right

            ctx.scale(scale, scale)

            function drawTopPath() {
                ctx.beginPath()
                ctx.moveTo(RT, 0)
                ctx.lineTo(W - RT, 0)
                ctx.arcTo(W, 0, W, RT, RT)
                ctx.lineTo(W, H)

                if (R > 0) {
                    ctx.lineTo(W, H + R)
                    ctx.arc(W - R, H + R, R, 0, -Math.PI / 2, true)
                    ctx.lineTo(R, H)
                    ctx.arc(R, H + R, R, -Math.PI / 2, -Math.PI, true)
                    ctx.lineTo(0, H + R)
                } else {
                    ctx.lineTo(W, H - RT)
                    ctx.arcTo(W, H, W - RT, H, RT)
                    ctx.lineTo(RT, H)
                    ctx.arcTo(0, H, 0, H - RT, RT)
                }

                ctx.lineTo(0, RT)
                ctx.arcTo(0, 0, RT, 0, RT)
                ctx.closePath()
            }

            ctx.reset()
            ctx.clearRect(0, 0, W, H_raw)

            ctx.save()
            if (isBottom) {
                ctx.translate(W, H_raw)
                ctx.rotate(Math.PI)
            } else if (isLeft) {
                ctx.translate(0, W)
                ctx.rotate(-Math.PI / 2)
            } else if (isRight) {
                ctx.translate(H_raw, 0)
                ctx.rotate(Math.PI / 2)
            }

            drawTopPath()
            ctx.restore()

            ctx.fillStyle = Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, alphaTint)
            ctx.fill()
        }
    }
}