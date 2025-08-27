pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values

    property MprisPlayer activePlayer: availablePlayers.find(p => p.isPlaying)
                                       ?? availablePlayers.find(
                                           p => p.canControl
                                           && p.canPlay) ?? null

    IpcHandler {
        target: "mpris"

        function list(): string {
            return root.availablePlayers.map(p => p.identity).join("")
        }

        function play(): void {
            if (root.activePlayer?.canPlay)
                root.activePlayer.play()
        }

        function pause(): void {
            if (root.activePlayer?.canPause)
                root.activePlayer.pause()
        }

        function playPause(): void {
            if (root.activePlayer?.canTogglePlaying)
                root.activePlayer.togglePlaying()
        }

        function previous(): void {
            if (root.activePlayer?.canGoPrevious)
                root.activePlayer.previous()
        }

        function next(): void {
            if (root.activePlayer?.canGoNext)
                root.activePlayer.next()
        }

        function stop(): void {
            root.activePlayer?.stop()
        }
    }
}
