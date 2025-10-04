import QtQuick
import qs.Common

QtObject {
    id: keyboardController

    required property var modal

    function reset() {
        modal.selectedIndex = 0
        modal.keyboardNavigationActive = false
        modal.showKeyboardHints = false
    }

    function selectNext() {
        if (!modal.filteredClipboardModel || modal.filteredClipboardModel.count === 0) {
            return
        }
        modal.keyboardNavigationActive = true
        modal.selectedIndex = Math.min(modal.selectedIndex + 1, modal.filteredClipboardModel.count - 1)
    }

    function selectPrevious() {
        if (!modal.filteredClipboardModel || modal.filteredClipboardModel.count === 0) {
            return
        }
        modal.keyboardNavigationActive = true
        modal.selectedIndex = Math.max(modal.selectedIndex - 1, 0)
    }

    function copySelected() {
        if (!modal.filteredClipboardModel || modal.filteredClipboardModel.count === 0 || modal.selectedIndex < 0 || modal.selectedIndex >= modal.filteredClipboardModel.count) {
            return
        }
        const selectedEntry = modal.filteredClipboardModel.get(modal.selectedIndex).entry
        modal.copyEntry(selectedEntry)
    }

    function deleteSelected() {
        if (!modal.filteredClipboardModel || modal.filteredClipboardModel.count === 0 || modal.selectedIndex < 0 || modal.selectedIndex >= modal.filteredClipboardModel.count) {
            return
        }
        const selectedEntry = modal.filteredClipboardModel.get(modal.selectedIndex).entry
        modal.deleteEntry(selectedEntry)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = false
                event.accepted = true
            } else {
                modal.hide()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            if (!modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = true
                modal.selectedIndex = 0
                event.accepted = true
            } else {
                selectNext()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            if (!modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = true
                modal.selectedIndex = 0
                event.accepted = true
            } else if (modal.selectedIndex === 0) {
                modal.keyboardNavigationActive = false
                event.accepted = true
            } else {
                selectPrevious()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
            if (!modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = true
                modal.selectedIndex = 0
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
            if (!modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = true
                modal.selectedIndex = 0
            } else if (modal.selectedIndex === 0) {
                modal.keyboardNavigationActive = false
            } else {
                selectPrevious()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
            if (!modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = true
                modal.selectedIndex = 0
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
            if (!modal.keyboardNavigationActive) {
                modal.keyboardNavigationActive = true
                modal.selectedIndex = 0
            } else if (modal.selectedIndex === 0) {
                modal.keyboardNavigationActive = false
            } else {
                selectPrevious()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
            modal.clearAll()
            modal.hide()
            event.accepted = true
        } else if (modal.keyboardNavigationActive) {
            if ((event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                copySelected()
                event.accepted = true
            } else if (event.key === Qt.Key_Delete) {
                deleteSelected()
                event.accepted = true
            }
        }
        if (event.key === Qt.Key_F10) {
            modal.showKeyboardHints = !modal.showKeyboardHints
            event.accepted = true
        }
    }
}
