pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Minimal VPN controller backed by NetworkManager (nmcli + D-Bus monitor)
Singleton {
    id: root

    // State
    property bool available: true
    property bool isBusy: false
    property string errorMessage: ""

    // Profiles discovered on the system
    // [{ name, uuid, type }]
    property var profiles: []

    // Allow multiple active VPNs (set true to allow concurrent connections)
    // Default: allow multiple, to align with NetworkManager capability
    property bool singleActive: false

    // Active VPN connections (may be multiple)
    // Full list and convenience projections
    property var activeConnections: [] // [{ name, uuid, device, state }]
    property var activeUuids: []
    property var activeNames: []
    // Back-compat single values (first active if present)
    property string activeUuid: activeUuids.length > 0 ? activeUuids[0] : ""
    property string activeName: activeNames.length > 0 ? activeNames[0] : ""
    property string activeDevice: activeConnections.length > 0 ? (activeConnections[0].device || "") : ""
    property string activeState: activeConnections.length > 0 ? (activeConnections[0].state || "") : ""
    property bool connected: activeUuids.length > 0

    // Use implicit property notify signals (profilesChanged, activeUuidChanged, etc.)

    Component.onCompleted: initialize()

    Component.onDestruction: {
        nmMonitor.running = false
    }

    function initialize() {
        // Start monitoring NetworkManager for changes
        nmMonitor.running = true
        refreshAll()
    }

    function refreshAll() {
        listProfiles()
        refreshActive()
    }

    // Monitor NetworkManager changes and refresh on activity
    Process {
        id: nmMonitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.NetworkManager"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.includes("ActiveConnection") || line.includes("PropertiesChanged") || line.includes("StateChanged")) {
                    refreshAll()
                }
            }
        }
    }

    // Query all VPN profiles
    function listProfiles() {
        getProfiles.running = true
    }

    Process {
        id: getProfiles
        command: ["bash", "-lc", "nmcli -t -f NAME,UUID,TYPE connection show | while IFS=: read -r name uuid type; do case \"$type\" in vpn) svc=$(nmcli -g vpn.service-type connection show uuid \"$uuid\" 2>/dev/null); echo \"$name:$uuid:$type:$svc\" ;; wireguard) echo \"$name:$uuid:$type:\" ;; *) : ;; esac; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length ? text.trim().split('\n') : []
                const out = []
                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 3 && (parts[2] === "vpn" || parts[2] === "wireguard")) {
                        const svc = parts.length >= 4 ? parts[3] : ""
                        out.push({ name: parts[0], uuid: parts[1], type: parts[2], serviceType: svc })
                    }
                }
                root.profiles = out
            }
        }
    }

    // Query active VPN connection
    function refreshActive() {
        getActive.running = true
    }

    Process {
        id: getActive
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show", "--active"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length ? text.trim().split('\n') : []
                let act = []
                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 5 && (parts[2] === "vpn" || parts[2] === "wireguard")) {
                        act.push({ name: parts[0], uuid: parts[1], device: parts[3], state: parts[4] })
                    }
                }
                root.activeConnections = act
                root.activeUuids = act.map(a => a.uuid).filter(u => !!u)
                root.activeNames = act.map(a => a.name).filter(n => !!n)
            }
        }
    }

    function isActiveUuid(uuid) {
        return root.activeUuids && root.activeUuids.indexOf(uuid) !== -1
    }

    function _looksLikeUuid(s) {
        // Very loose check for UUID pattern
        return s && s.indexOf('-') !== -1 && s.length >= 8
    }

    function connect(uuidOrName) {
        if (root.isBusy) return
        root.isBusy = true
        root.errorMessage = ""
        if (root.singleActive) {
            // Bring down all active VPNs, then bring up the requested one
            const isUuid = _looksLikeUuid(uuidOrName)
            const escaped = ('' + uuidOrName).replace(/'/g, "'\\''")
            const upCmd = isUuid ? `nmcli connection up uuid '${escaped}'` : `nmcli connection up id '${escaped}'`
            const script = `set -e\n` +
                           `nmcli -t -f UUID,TYPE connection show --active | awk -F: '$2 ~ /^(vpn|wireguard)$/ {print $1}' | while read u; do [ -n \"$u\" ] && nmcli connection down uuid \"$u\" || true; done\n` +
                           upCmd + `\n`
            vpnSwitch.command = ["bash", "-lc", script]
            vpnSwitch.running = true
        } else {
            if (_looksLikeUuid(uuidOrName)) {
                vpnUp.command = ["nmcli", "connection", "up", "uuid", uuidOrName]
            } else {
                vpnUp.command = ["nmcli", "connection", "up", "id", uuidOrName]
            }
            vpnUp.running = true
        }
    }

    function disconnect(uuidOrName) {
        if (root.isBusy) return
        root.isBusy = true
        root.errorMessage = ""
        if (_looksLikeUuid(uuidOrName)) {
            vpnDown.command = ["nmcli", "connection", "down", "uuid", uuidOrName]
        } else {
            vpnDown.command = ["nmcli", "connection", "down", "id", uuidOrName]
        }
        vpnDown.running = true
    }

    function toggle(uuid) {
        if (uuid) {
            if (isActiveUuid(uuid)) disconnect(uuid)
            else connect(uuid)
            return
        }
        if (root.profiles.length > 0) {
            connect(root.profiles[0].uuid)
        }
    }

    Process {
        id: vpnUp
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isBusy = false
                if (!text.toLowerCase().includes("successfully")) {
                    root.errorMessage = text.trim()
                }
                refreshAll()
            }
        }
        onExited: exitCode => {
            root.isBusy = false
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = "Failed to connect VPN"
            }
        }
    }

    Process {
        id: vpnDown
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isBusy = false
                if (!text.toLowerCase().includes("deactivated") && !text.toLowerCase().includes("successfully")) {
                    root.errorMessage = text.trim()
                }
                refreshAll()
            }
        }
        onExited: exitCode => {
            root.isBusy = false
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = "Failed to disconnect VPN"
            }
        }
    }

    function disconnectAllActive() {
        if (root.isBusy) return
        root.isBusy = true
        const script = `nmcli -t -f UUID,TYPE connection show --active | awk -F: '$2 ~ /^(vpn|wireguard)$/ {print $1}' | while read u; do [ -n \"$u\" ] && nmcli connection down uuid \"$u\" || true; done`
        vpnSwitch.command = ["bash", "-lc", script]
        vpnSwitch.running = true
    }

    // Sequenced down/up using a single shell for exclusive switch
    Process {
        id: vpnSwitch
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isBusy = false
                refreshAll()
            }
        }
        onExited: exitCode => {
            root.isBusy = false
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = "Failed to switch VPN"
            }
        }
    }
}
