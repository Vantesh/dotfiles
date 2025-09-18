import QtQuick
import QtQuick.Shapes
import qs.Common

Item {
    id: root

    property real value: 0
    property real lineWidth: 2
    property real wavelength: 20
    property real amp: 1.6
    property real phase: 0.0
    property bool isPlaying: false
    property real currentAmp: 1.6
    property color trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
    property color fillColor: Theme.primary
    property color playheadColor: Theme.primary

    property real dpr: (root.window ? root.window.devicePixelRatio : 1)
    function snap(v) { return Math.round(v * dpr) / dpr }

    readonly property real playX: snap(root.width * root.value)
    readonly property real midY: snap(height / 2)

    Behavior on currentAmp { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    onIsPlayingChanged: currentAmp = isPlaying ? amp : 0

    Shape {
        id: flatTrack
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 0

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: snap(root.lineWidth)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathMove { id: flatStart; x: 0; y: root.midY }
            PathLine { id: flatEnd;   x: root.width; y: root.midY }
        }
    }

    Item {
        id: waveClip
        anchors.fill: parent
        clip: true

        readonly property real startX: snap(root.lineWidth/2)
        readonly property real aaBias: (0.25 / root.dpr)
        readonly property real endX: Math.max(startX, Math.min(root.playX - startX - aaBias, width))

        Rectangle {
            id: mask
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: 0
            width: waveClip.endX
            color: "transparent"
            clip: true

            Shape {
                id: waveShape
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width + 4 * root.wavelength
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                x: waveOffsetX

                ShapePath {
                    id: wavePath
                    strokeColor: root.fillColor
                    strokeWidth: snap(root.lineWidth)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    PathSvg { id: waveSvg; path: "" }
                }
            }
        }

        Rectangle {
            id: startCap
            width: snap(root.lineWidth)
            height: snap(root.lineWidth)
            radius: width / 2
            color: root.fillColor
            x: waveClip.startX - width/2
            y: root.midY - height/2 + root.currentAmp * Math.sin((waveClip.startX / root.wavelength) * 2 * Math.PI + root.phase)
            visible: waveClip.endX > waveClip.startX
            z: 2
        }

        Rectangle {
            id: endCap
            width: snap(root.lineWidth)
            height: snap(root.lineWidth)
            radius: width / 2
            color: root.fillColor
            x: waveClip.endX - width/2
            y: root.midY - height/2 + root.currentAmp * Math.sin((waveClip.endX / root.wavelength) * 2 * Math.PI + root.phase)
            visible: waveClip.endX > waveClip.startX
            z: 2
        }
    }

    Rectangle {
        id: playhead
        width: 3.5
        height: Math.max(root.lineWidth + 12, 16)
        radius: width / 2
        color: root.playheadColor
        x: root.playX - width / 2
        y: root.midY - height / 2
        z: 3
    }

    property real k: (2 * Math.PI) / Math.max(1e-6, wavelength)
    function wrapMod(a, m) { let r = a % m; return r < 0 ? r + m : r }
    readonly property real waveOffsetX: -wrapMod(phase / k, wavelength)

    FrameAnimation {
        running: root.visible && (root.isPlaying || root.currentAmp > 0)
        onTriggered: {
            if (root.isPlaying) root.phase += 0.03 * frameTime * 60
            startCap.y = root.midY - startCap.height/2 + root.currentAmp * Math.sin((waveClip.startX / root.wavelength) * 2 * Math.PI + root.phase)
            endCap.y = root.midY - endCap.height/2 + root.currentAmp * Math.sin((waveClip.endX / root.wavelength) * 2 * Math.PI + root.phase)
        }
    }

    function buildStaticWave() {
        const start = waveClip.startX - 2 * root.wavelength
        const end   = width + 2 * root.wavelength
        if (end <= start) { waveSvg.path = ""; return }

        const kLocal = k
        const halfPeriod = root.wavelength / 2
        function y0(x)  { return root.midY + root.currentAmp * Math.sin(kLocal * x) }
        function dy0(x) { return root.currentAmp * Math.cos(kLocal * x) * kLocal }

        let x0 = start
        let d  = `M ${x0} ${y0(x0)}`
        while (x0 < end) {
            const x1 = Math.min(x0 + halfPeriod, end)
            const dx = x1 - x0
            const yA = y0(x0), yB = y0(x1)
            const dyA = dy0(x0), dyB = dy0(x1)
            const c1x = x0 + dx/3
            const c1y = yA + (dyA * dx)/3
            const c2x = x1 - dx/3
            const c2y = yB - (dyB * dx)/3
            d += ` C ${c1x} ${c1y} ${c2x} ${c2y} ${x1} ${yB}`
            x0 = x1
        }
        waveSvg.path = d
    }

    Component.onCompleted: { currentAmp = isPlaying ? amp : 0; buildStaticWave() }
    onWidthChanged: { flatStart.x = 0; flatEnd.x = width; buildStaticWave() }
    onHeightChanged: buildStaticWave()
    onCurrentAmpChanged: buildStaticWave()
    onWavelengthChanged: { k = (2 * Math.PI) / Math.max(1e-6, wavelength); buildStaticWave() }
}
