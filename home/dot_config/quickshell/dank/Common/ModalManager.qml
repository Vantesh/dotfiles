import QtQuick
pragma Singleton

QtObject {
    id: modalManager

    signal closeAllModalsExcept(var excludedModal)

    function openModal(modal) {
        if (!modal.allowStacking) {
            closeAllModalsExcept(modal)
        }
    }
}
