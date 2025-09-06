import QtQuick
import Quickshell.Io

QtObject {
    id: clipboardProcesses

    required property var modal
    required property var clipboardModel
    required property var filteredClipboardModel

    // Load clipboard entries
    property var loadProcess: Process {
        id: loadProcess
        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                clipboardModel.clear()
                const lines = text.trim().split('\n')
                for (const line of lines) {
                    if (line.trim().length > 0) {
                        clipboardModel.append({
                                                  "entry": line
                                              })
                    }
                }
                modal.updateFilteredModel()
            }
        }
    }

    // Delete single entry
    property var deleteProcess: Process {
        id: deleteProcess
        property string deletedEntry: ""
        running: false

        onExited: exitCode => {
                      if (exitCode === 0) {
                          for (var i = 0; i < clipboardModel.count; i++) {
                              if (clipboardModel.get(i).entry === deleteProcess.deletedEntry) {
                                  clipboardModel.remove(i)
                                  break
                              }
                          }
                          for (var j = 0; j < filteredClipboardModel.count; j++) {
                              if (filteredClipboardModel.get(j).entry === deleteProcess.deletedEntry) {
                                  filteredClipboardModel.remove(j)
                                  break
                              }
                          }
                          modal.totalCount = filteredClipboardModel.count
                          if (filteredClipboardModel.count === 0) {
                              modal.keyboardNavigationActive = false
                              modal.selectedIndex = 0
                          } else if (modal.selectedIndex >= filteredClipboardModel.count) {
                              modal.selectedIndex = filteredClipboardModel.count - 1
                          }
                      } else {
                          console.warn("Failed to delete clipboard entry")
                      }
                  }
    }

    // Clear all entries
    property var clearProcess: Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
        running: false

        onExited: exitCode => {
                      if (exitCode === 0) {
                          clipboardModel.clear()
                          filteredClipboardModel.clear()
                          modal.totalCount = 0
                      }
                  }
    }

    function refresh() {
        loadProcess.running = true
    }

    function deleteEntry(entry) {
        deleteProcess.deletedEntry = entry
        deleteProcess.command = ["sh", "-c", `echo '${entry.replace(/'/g, "'\\''")}' | cliphist delete`]
        deleteProcess.running = true
    }

    function clearAll() {
        clearProcess.running = true
    }
}
