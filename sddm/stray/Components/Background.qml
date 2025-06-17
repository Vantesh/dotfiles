import QtMultimedia 6.8
import QtQuick 6.8
import "timestamps.js" as Timestamps

Rectangle {
    id: background

    property string mediaPath: "../background/stray.mp4"
    property var timestamps: Timestamps.timestamps
    property alias position: mediaplayer.position

    color: "black"

    MediaPlayer {
        id: mediaplayer

        source: Qt.resolvedUrl(mediaPath)
        videoOutput: videoOutput
        autoPlay: true
        loops: MediaPlayer.Infinite
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia)
                position = timestamps[Math.floor(Math.random() * timestamps.length)];

        }

        audioOutput: AudioOutput {
            volume: config.Volume
            muted: !JSON.parse(config.Audio)
        }

    }

    VideoOutput {
        id: videoOutput

        fillMode: VideoOutput.PreserveAspectCrop
        anchors.fill: parent
    }

}
