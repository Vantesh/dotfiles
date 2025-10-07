//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Modals.Settings
import qs.Modals.Spotlight
import qs.Modules
import qs.Modules.AppDrawer
import qs.Modules.DankDash
import qs.Modules.ControlCenter
import qs.Modules.Dock
import qs.Modules.Lock
import qs.Modules.Notepad
import qs.Modules.Notifications.Center
import qs.Widgets
import qs.Modules.Notifications.Popup
import qs.Modules.OSD
import qs.Modules.ProcessList
import qs.Modules.Settings
import qs.Modules.DankBar
import qs.Modules.DankBar.Popouts
import qs.Modules.Plugins
import qs.Services


ShellRoot {
  id: root

  property bool servicesReady: false

  Component.onCompleted: {
    PortalService.init()
    DisplayService.nightModeEnabled
    WallpaperCyclingService.cyclingActive
    PluginService.pluginDirectory
    Qt.callLater(() => {
      servicesReady = true
    })
  }

  Instantiator {
      id: daemonPluginInstantiator
      model: servicesReady ? Object.keys(PluginService.pluginDaemonComponents) : []

      delegate: Loader {
          id: daemonLoader
          property string pluginId: modelData
          sourceComponent: PluginService.pluginDaemonComponents[pluginId]

          onLoaded: {
              if (item) {
                  item.pluginService = PluginService
                  if (item.popoutService !== undefined) {
                      item.popoutService = PopoutService
                  }
                  item.pluginId = pluginId
                  console.log("Daemon plugin loaded:", pluginId)
              }
          }
      }
  }

  WallpaperBackground {}

  Lock {
      id: lock

      anchors.fill: parent
  }

  Loader {
      id: dankBarLoader
      asynchronous: false

      property var currentPosition: SettingsData.dankBarPosition
      property bool initialized: false

      sourceComponent: DankBar {
          onColorPickerRequested: colorPickerModal.show()
      }

      Component.onCompleted: {
          initialized = true
      }

      onCurrentPositionChanged: {
          if (!initialized) return

          const component = sourceComponent
          sourceComponent = null
          sourceComponent = component
      }
  }

  Loader {
      id: dockLoader
      active: true
      asynchronous: false

      property var currentPosition: SettingsData.dockPosition
      property bool initialized: false

      sourceComponent: Dock {
          contextMenu: dockContextMenuLoader.item ? dockContextMenuLoader.item : null
      }

      onLoaded: {
          if (item) {
              dockContextMenuLoader.active = true
          }
      }

      Component.onCompleted: {
          initialized = true
      }

      onCurrentPositionChanged: {
          if (!initialized) return

          console.log("DEBUG: Dock position changed to:", currentPosition, "- recreating dock")
          const comp = sourceComponent
          sourceComponent = null
          sourceComponent = comp
      }
  }

  Loader {
      id: dankDashPopoutLoader

      active: false
      asynchronous: true

      sourceComponent: Component {
          DankDashPopout {
              id: dankDashPopout

              Component.onCompleted: {
                  PopoutService.dankDashPopout = dankDashPopout
              }
          }
      }
  }

  LazyLoader {
      id: dockContextMenuLoader

      active: false

      DockContextMenu {
          id: dockContextMenu
      }
  }

  LazyLoader {
      id: notificationCenterLoader

      active: false

      NotificationCenterPopout {
          id: notificationCenter

          Component.onCompleted: {
              PopoutService.notificationCenterPopout = notificationCenter
          }
      }
  }

  Variants {
      model: SettingsData.getFilteredScreens("notifications")

      delegate: NotificationPopupManager {
          modelData: item
      }
  }

  LazyLoader {
      id: controlCenterLoader

      active: false

      property var modalRef: colorPickerModal
      property LazyLoader powerModalLoaderRef: powerMenuModalLoader

      ControlCenterPopout {
          id: controlCenterPopout
          colorPickerModal: controlCenterLoader.modalRef
          powerMenuModalLoader: controlCenterLoader.powerModalLoaderRef

          onLockRequested: {
              lock.activate()
          }

          Component.onCompleted: {
              PopoutService.controlCenterPopout = controlCenterPopout
          }
      }
  }

  LazyLoader {
      id: wifiPasswordModalLoader

      active: false

      WifiPasswordModal {
          id: wifiPasswordModal

          Component.onCompleted: {
              PopoutService.wifiPasswordModal = wifiPasswordModal
          }
      }
  }

  LazyLoader {
      id: networkInfoModalLoader

      active: false

      NetworkInfoModal {
          id: networkInfoModal

          Component.onCompleted: {
              PopoutService.networkInfoModal = networkInfoModal
          }
      }
  }

  LazyLoader {
      id: batteryPopoutLoader

      active: false

      BatteryPopout {
          id: batteryPopout

          Component.onCompleted: {
              PopoutService.batteryPopout = batteryPopout
          }
      }
  }

  LazyLoader {
      id: vpnPopoutLoader

      active: false

      VpnPopout {
          id: vpnPopout

          Component.onCompleted: {
              PopoutService.vpnPopout = vpnPopout
          }
      }
  }

  LazyLoader {
      id: powerMenuLoader

      active: false

      PowerMenu {
          id: powerMenu

          onPowerActionRequested: (action, title, message) => {
                                      powerConfirmModalLoader.active = true
                                      if (powerConfirmModalLoader.item) {
                                          powerConfirmModalLoader.item.confirmButtonColor = action === "poweroff" ? Theme.error : action === "reboot" ? Theme.warning : Theme.primary
                                          powerConfirmModalLoader.item.show(title, message, function () {
                                              switch (action) {
                                              case "logout":
                                                  SessionService.logout()
                                                  break
                                              case "suspend":
                                                  SessionService.suspend()
                                                  break
                                              case "hibernate":
                                                  SessionService.hibernate()
                                                  break
                                              case "reboot":
                                                  SessionService.reboot()
                                                  break
                                              case "poweroff":
                                                  SessionService.poweroff()
                                                  break
                                              }
                                          }, function () {})
                                      }
                                  }
      }
  }

  LazyLoader {
      id: powerConfirmModalLoader

      active: false

      ConfirmModal {
          id: powerConfirmModal
      }
  }

  LazyLoader {
      id: processListPopoutLoader

      active: false

      ProcessListPopout {
          id: processListPopout

          Component.onCompleted: {
              PopoutService.processListPopout = processListPopout
          }
      }
  }

  SettingsModal {
      id: settingsModal

      Component.onCompleted: {
          PopoutService.settingsModal = settingsModal
      }
  }

  LazyLoader {
      id: appDrawerLoader

      active: false

      AppDrawerPopout {
          id: appDrawerPopout

          Component.onCompleted: {
              PopoutService.appDrawerPopout = appDrawerPopout
          }
      }
  }

  SpotlightModal {
      id: spotlightModal

      Component.onCompleted: {
          PopoutService.spotlightModal = spotlightModal
      }
  }

  ClipboardHistoryModal {
      id: clipboardHistoryModalPopup

      Component.onCompleted: {
          PopoutService.clipboardHistoryModal = clipboardHistoryModalPopup
      }
  }

  NotificationModal {
      id: notificationModal

      Component.onCompleted: {
          PopoutService.notificationModal = notificationModal
      }
  }

  DankColorPickerModal {
      id: colorPickerModal

      Component.onCompleted: {
          PopoutService.colorPickerModal = colorPickerModal
      }
  }

  LazyLoader {
      id: processListModalLoader

      active: false

      ProcessListModal {
          id: processListModal

          Component.onCompleted: {
              PopoutService.processListModal = processListModal
          }
      }
  }

  LazyLoader {
      id: systemUpdateLoader

      active: false

      SystemUpdatePopout {
          id: systemUpdatePopout

          Component.onCompleted: {
              PopoutService.systemUpdatePopout = systemUpdatePopout
          }
      }
  }

  Variants {
      id: notepadSlideoutVariants
      model: SettingsData.getFilteredScreens("notepad")

      delegate: DankSlideout {
          id: notepadSlideout
          modelData: item
          title: qsTr("Notepad")
          slideoutWidth: 480
          expandable: true
          expandedWidthValue: 960
          customTransparency: SettingsData.notepadTransparencyOverride

          content: Component {
              Notepad {
                  onHideRequested: {
                      notepadSlideout.hide()
                  }
              }
          }

          function toggle() {
              if (isVisible) {
                  hide()
              } else {
                  show()
              }
          }
      }
  }

  LazyLoader {
      id: powerMenuModalLoader

      active: false

      PowerMenuModal {
          id: powerMenuModal

          onPowerActionRequested: (action, title, message) => {
                                      powerConfirmModalLoader.active = true
                                      if (powerConfirmModalLoader.item) {
                                          powerConfirmModalLoader.item.confirmButtonColor = action === "poweroff" ? Theme.error : action === "reboot" ? Theme.warning : Theme.primary
                                          powerConfirmModalLoader.item.show(title, message, function () {
                                              switch (action) {
                                              case "logout":
                                                  SessionService.logout()
                                                  break
                                              case "suspend":
                                                  SessionService.suspend()
                                                  break
                                              case "hibernate":
                                                  SessionService.hibernate()
                                                  break
                                              case "reboot":
                                                  SessionService.reboot()
                                                  break
                                              case "poweroff":
                                                  SessionService.poweroff()
                                                  break
                                              }
                                          }, function () {})
                                      }
                                  }

          Component.onCompleted: {
              PopoutService.powerMenuModal = powerMenuModal
          }
      }
  }

  IpcHandler {
      function open() {
          powerMenuModalLoader.active = true
          if (powerMenuModalLoader.item)
              powerMenuModalLoader.item.openCentered()

          return "POWERMENU_OPEN_SUCCESS"
      }

      function close() {
          if (powerMenuModalLoader.item)
              powerMenuModalLoader.item.close()

          return "POWERMENU_CLOSE_SUCCESS"
      }

      function toggle() {
          powerMenuModalLoader.active = true
          if (powerMenuModalLoader.item) {
              if (powerMenuModalLoader.item.shouldBeVisible) {
                  powerMenuModalLoader.item.close()
              } else {
                  powerMenuModalLoader.item.openCentered()
              }
          }

          return "POWERMENU_TOGGLE_SUCCESS"
      }

      target: "powermenu"
  }

  IpcHandler {
      function open(): string {
          processListModalLoader.active = true
          if (processListModalLoader.item)
              processListModalLoader.item.show()

          return "PROCESSLIST_OPEN_SUCCESS"
      }

      function close(): string {
          if (processListModalLoader.item)
              processListModalLoader.item.hide()

          return "PROCESSLIST_CLOSE_SUCCESS"
      }

      function toggle(): string {
          processListModalLoader.active = true
          if (processListModalLoader.item)
              processListModalLoader.item.toggle()

          return "PROCESSLIST_TOGGLE_SUCCESS"
      }

      target: "processlist"
  }

  IpcHandler {
      function open(): string {
          controlCenterLoader.active = true
          if (controlCenterLoader.item) {
              controlCenterLoader.item.open()
              return "CONTROL_CENTER_OPEN_SUCCESS"
          }
          return "CONTROL_CENTER_OPEN_FAILED"
      }

      function close(): string {
          if (controlCenterLoader.item) {
              controlCenterLoader.item.close()
              return "CONTROL_CENTER_CLOSE_SUCCESS"
          }
          return "CONTROL_CENTER_CLOSE_FAILED"
      }

      function toggle(): string {
          controlCenterLoader.active = true
          if (controlCenterLoader.item) {
              controlCenterLoader.item.toggle()
              return "CONTROL_CENTER_TOGGLE_SUCCESS"
          }
          return "CONTROL_CENTER_TOGGLE_FAILED"
      }

      target: "control-center"
  }

  IpcHandler {
      function open(tab: string): string {
          dankDashPopoutLoader.active = true
          if (dankDashPopoutLoader.item) {
              switch (tab.toLowerCase()) {
              case "media":
                  dankDashPopoutLoader.item.currentTabIndex = 1
                  break
              case "weather":
                  dankDashPopoutLoader.item.currentTabIndex = SettingsData.weatherEnabled ? 2 : 0
                  break
              default:
                  dankDashPopoutLoader.item.currentTabIndex = 0
                  break
              }
              dankDashPopoutLoader.item.setTriggerPosition(Screen.width / 2, Theme.barHeight + Theme.spacingS, 100, "center", Screen)
              dankDashPopoutLoader.item.dashVisible = true
              return "DASH_OPEN_SUCCESS"
          }
          return "DASH_OPEN_FAILED"
      }

      function close(): string {
          if (dankDashPopoutLoader.item) {
              dankDashPopoutLoader.item.dashVisible = false
              return "DASH_CLOSE_SUCCESS"
          }
          return "DASH_CLOSE_FAILED"
      }

      function toggle(tab: string): string {
          dankDashPopoutLoader.active = true
          if (dankDashPopoutLoader.item) {
              if (dankDashPopoutLoader.item.dashVisible) {
                  dankDashPopoutLoader.item.dashVisible = false
              } else {
                  switch (tab.toLowerCase()) {
                  case "media":
                      dankDashPopoutLoader.item.currentTabIndex = 1
                      break
                  case "weather":
                      dankDashPopoutLoader.item.currentTabIndex = SettingsData.weatherEnabled ? 2 : 0
                      break
                  default:
                      dankDashPopoutLoader.item.currentTabIndex = 0
                      break
                  }
                  dankDashPopoutLoader.item.setTriggerPosition(Screen.width / 2, Theme.barHeight + Theme.spacingS, 100, "center", Screen)
                  dankDashPopoutLoader.item.dashVisible = true
              }
              return "DASH_TOGGLE_SUCCESS"
          }
          return "DASH_TOGGLE_FAILED"
      }

      target: "dash"
  }

  IpcHandler {
      function getFocusedScreenName() {
          if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
              return Hyprland.focusedWorkspace.monitor.name
          }
          if (CompositorService.isNiri && NiriService.currentOutput) {
              return NiriService.currentOutput
          }
          return ""
      }

      function getActiveNotepadInstance() {
          if (notepadSlideoutVariants.instances.length === 0) {
              return null
          }

          if (notepadSlideoutVariants.instances.length === 1) {
              return notepadSlideoutVariants.instances[0]
          }

          var focusedScreen = getFocusedScreenName()
          if (focusedScreen && notepadSlideoutVariants.instances.length > 0) {
              for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
                  var slideout = notepadSlideoutVariants.instances[i]
                  if (slideout.modelData && slideout.modelData.name === focusedScreen) {
                      return slideout
                  }
              }
          }

          for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
              var slideout = notepadSlideoutVariants.instances[i]
              if (slideout.isVisible) {
                  return slideout
              }
          }

          return notepadSlideoutVariants.instances[0]
      }

      function open(): string {
          var instance = getActiveNotepadInstance()
          if (instance) {
              instance.show()
              return "NOTEPAD_OPEN_SUCCESS"
          }
          return "NOTEPAD_OPEN_FAILED"
      }

      function close(): string {
          var instance = getActiveNotepadInstance()
          if (instance) {
              instance.hide()
              return "NOTEPAD_CLOSE_SUCCESS"
          }
          return "NOTEPAD_CLOSE_FAILED"
      }

      function toggle(): string {
          var instance = getActiveNotepadInstance()
          if (instance) {
              instance.toggle()
              return "NOTEPAD_TOGGLE_SUCCESS"
          }
          return "NOTEPAD_TOGGLE_FAILED"
      }

      target: "notepad"
  }

  IpcHandler {
      function toggle(): string {
          SessionService.toggleIdleInhibit()
          return SessionService.idleInhibited ? "Idle inhibit enabled" : "Idle inhibit disabled"
      }

      function enable(): string {
          SessionService.enableIdleInhibit()
          return "Idle inhibit enabled"
      }

      function disable(): string {
          SessionService.disableIdleInhibit()
          return "Idle inhibit disabled"
      }

      function status(): string {
          return SessionService.idleInhibited ? "Idle inhibit is enabled" : "Idle inhibit is disabled"
      }

      function reason(newReason: string): string {
          if (!newReason) {
              return `Current reason: ${SessionService.inhibitReason}`
          }

          SessionService.setInhibitReason(newReason)
          return `Inhibit reason set to: ${newReason}`
      }

      target: "inhibit"
  }

  Variants {
      model: SettingsData.getFilteredScreens("toast")

      delegate: Toast {
          modelData: item
          visible: ToastService.toastVisible
      }
  }

  Variants {
      model: SettingsData.getFilteredScreens("osd")

      delegate: VolumeOSD {
          modelData: item
      }
  }

  Variants {
      model: SettingsData.getFilteredScreens("osd")

      delegate: MicMuteOSD {
          modelData: item
      }
  }

  Variants {
      model: SettingsData.getFilteredScreens("osd")

      delegate: BrightnessOSD {
          modelData: item
      }
  }

  Variants {
      model: SettingsData.getFilteredScreens("osd")

      delegate: IdleInhibitorOSD {
          modelData: item
      }
  }
}
