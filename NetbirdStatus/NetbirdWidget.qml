import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "netbird-control"

    // ── Settings from pluginData ──
    property int refreshInterval: pluginData.refreshInterval !== undefined ? pluginData.refreshInterval : 30000
    property bool showIpAddress: pluginData.showIpAddress !== undefined ? pluginData.showIpAddress : true
    property bool hideDisconnected: pluginData.hideDisconnected !== undefined ? pluginData.hideDisconnected : false
    property bool showPing: pluginData.showPing !== undefined ? pluginData.showPing : false
    property int pingCount: pluginData.pingCount !== undefined ? pluginData.pingCount : 5
    property string customTerminal: pluginData.terminalCommand || ""
    property bool colorizeIcon: pluginData.colorizeIcon !== undefined ? pluginData.colorizeIcon : true
    property string adminConsoleUrl: pluginData.adminConsoleUrl || "https://app.netbird.io/"
    function normalizePeerAction(value) {
        if (value === "Copy IP")
            return "copy-ip";
        if (value === "SSH to host")
            return "ssh";
        if (value === "Ping host")
            return "ping";
        return value || "copy-ip";
    }

    property string defaultPeerAction: normalizePeerAction(pluginData.defaultPeerAction)

    // ── State variables ──
    property bool netbirdInstalled: false
    property bool netbirdRunning: false
    property string netbirdIp: ""
    property string netbirdFqdn: ""
    property string netbirdStatus: "Checking..."
    property int peerCount: 0
    property int peerConnected: 0
    property bool isRefreshing: false
    property string lastToggleAction: ""
    property var peerList: []
    property bool managementConnected: false
    property bool signalConnected: false
    property bool _stateRestored: false

    onPluginDataChanged: {
        if (_stateRestored)
            return;
        if (pluginData && pluginData.lastInstalled !== undefined) {
            root.netbirdInstalled = pluginData.lastInstalled === true;
            root.netbirdRunning = pluginData.lastRunning === true;
            root.netbirdIp = pluginData.lastIp || "";
            root.netbirdFqdn = pluginData.lastFqdn || "";
            root.peerCount = pluginData.lastPeerCount || 0;
            root.peerConnected = pluginData.lastPeerConnected || 0;
            if (!root.netbirdInstalled) {
                root.netbirdStatus = "Not installed";
            } else {
                root.netbirdStatus = root.netbirdRunning ? "Connected" : "Disconnected";
            }
            root._stateRestored = true;
        }
    }

    function _saveStateCache() {
        if (!pluginService)
            return;
        pluginService.savePluginData("netbirdStatus", "lastInstalled", root.netbirdInstalled);
        pluginService.savePluginData("netbirdStatus", "lastRunning", root.netbirdRunning);
        pluginService.savePluginData("netbirdStatus", "lastIp", root.netbirdIp);
        pluginService.savePluginData("netbirdStatus", "lastFqdn", root.netbirdFqdn);
        pluginService.savePluginData("netbirdStatus", "lastPeerCount", root.peerCount);
        pluginService.savePluginData("netbirdStatus", "lastPeerConnected", root.peerConnected);
    }

    property var peerPings: ({})
    property var pingQueue: []
    property string currentPingIp: ""
    property var peerActionOpenMap: ({})

    property string detectedTerminal: ""
    property string activeTerminal: customTerminal !== "" ? customTerminal : detectedTerminal
    property bool terminalDetected: activeTerminal !== ""
    property var terminalCandidates: ["ghostty", "alacritty", "kitty", "foot", "wezterm", "konsole", "gnome-terminal", "xfce4-terminal", "xterm"]
    property int terminalCheckIndex: 0

    // ── Helper functions ──
    function parseIp(ip) {
        if (!ip)
            return "";
        var idx = ip.indexOf("/");
        if (idx > 0)
            return ip.substring(0, idx);
        return ip;
    }

    function getHostname(peer) {
        if (!peer)
            return "Unknown";
        if (peer.fqdn) {
            var parts = peer.fqdn.split(".");
            if (parts.length > 0)
                return parts[0];
        }
        return peer.netbirdIp || "Unknown";
    }

    function getConnectionIcon(connType) {
        if (!connType)
            return "signal_disconnected";
        switch (connType.toLowerCase()) {
        case "p2p":
            return "compare_arrows";
        case "relayed":
            return "cloud";
        default:
            return "signal_disconnected";
        }
    }

    function requireTerminal() {
        if (!terminalDetected) {
            ToastService.showError("NetBird Terminal Not Configured", "Please install a supported terminal emulator to use SSH and Ping features");
            return false;
        }
        return true;
    }

    function copyToClipboard(text) {
        var escaped = text.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
    }

    function executePeerAction(action, peer) {
        if (action === "copy-ip") {
            if (peer && peer.netbirdIp) {
                copyToClipboard(peer.netbirdIp);
                ToastService.showInfo("IP Copied", "IP of " + getHostname(peer) + " copied to clipboard");
            }
        } else if (action === "ssh") {
            if (!requireTerminal())
                return;
            if (peer && peer.netbirdIp) {
                Quickshell.execDetached([root.activeTerminal, "-e", "ssh", peer.netbirdIp]);
            }
        } else if (action === "ping") {
            if (!requireTerminal())
                return;
            if (peer && peer.netbirdIp) {
                Quickshell.execDetached([root.activeTerminal, "-e", "ping", "-c", root.pingCount.toString(), peer.netbirdIp]);
            }
        }
    }

    function getPeerKey(peer) {
        if (!peer)
            return "";
        return peer.netbirdIp || peer.fqdn || "";
    }

    function isPeerOpen(peer) {
        const key = getPeerKey(peer);
        if (!key)
            return false;
        return peerActionOpenMap[key] === true;
    }

    function setPeerOpen(peer, open) {
        const key = getPeerKey(peer);
        if (!key)
            return;
        const updated = Object.assign({}, peerActionOpenMap);
        if (open) {
            updated[key] = true;
        } else {
            delete updated[key];
        }
        peerActionOpenMap = updated;
    }

    function prunePeerOpenMap() {
        const updated = {};
        for (let i = 0; i < sortedPeerList.length; i++) {
            const key = getPeerKey(sortedPeerList[i]);
            if (key && peerActionOpenMap[key]) {
                updated[key] = true;
            }
        }
        peerActionOpenMap = updated;
    }

    // ── Processes ──
    Process {
        id: whichProcess
        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            root.netbirdInstalled = (exitCode === 0);
            root.isRefreshing = false;
            updateNetbirdStatus();
        }
    }

    Process {
        id: terminalDetectProcess
        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                root.detectedTerminal = root.terminalCandidates[root.terminalCheckIndex];
            } else {
                root.terminalCheckIndex++;
                if (root.terminalCheckIndex < root.terminalCandidates.length) {
                    terminalDetectProcess.command = ["which", root.terminalCandidates[root.terminalCheckIndex]];
                    terminalDetectProcess.running = true;
                }
            }
        }
    }

    function detectTerminal() {
        root.terminalCheckIndex = 0;
        root.detectedTerminal = "";
        if (root.terminalCandidates.length > 0) {
            terminalDetectProcess.command = ["which", root.terminalCandidates[0]];
            terminalDetectProcess.running = true;
        }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            root.isRefreshing = false;
            var stdout = String(statusProcess.stdout.text || "").trim();

            if (exitCode === 0 && stdout && stdout.length > 0) {
                try {
                    var data = JSON.parse(stdout);

                    root.managementConnected = data.management?.connected ?? false;
                    root.signalConnected = data.signal?.connected ?? false;

                    root.netbirdRunning = root.managementConnected;

                    if (root.netbirdRunning) {
                        root.netbirdIp = parseIp(data.netbirdIp || "");
                        root.netbirdFqdn = data.fqdn || "";
                        root.netbirdStatus = "Connected";

                        var peers = [];
                        if (data.peers && data.peers.details) {
                            for (var i = 0; i < data.peers.details.length; i++) {
                                var peer = data.peers.details[i];
                                peers.push({
                                    "fqdn": peer.fqdn || "",
                                    "netbirdIp": parseIp(peer.netbirdIp || ""),
                                    "status": peer.status || "Disconnected",
                                    "connectionType": peer.connectionType || "",
                                    "lastStatusUpdate": peer.lastStatusUpdate || "",
                                    "latency": peer.latency || 0,
                                    "transferReceived": peer.transferReceived || 0,
                                    "transferSent": peer.transferSent || 0,
                                    "networks": peer.networks || [],
                                    "quantumResistance": peer.quantumResistance || false
                                });
                            }
                        }
                        root.peerList = peers;
                        root.peerCount = data.peers?.total ?? peers.length;
                        root.peerConnected = data.peers?.connected ?? 0;

                        if (root.showPing) {
                            root.startPingQueue();
                        }
                    } else {
                        root.netbirdIp = "";
                        root.netbirdFqdn = "";
                        root.netbirdStatus = "Disconnected";
                        root.peerCount = 0;
                        root.peerConnected = 0;
                        root.peerList = [];
                    }
                } catch (e) {
                    root.netbirdRunning = false;
                    root.netbirdStatus = "Error";
                    root.peerList = [];
                }
            } else {
                root.netbirdRunning = false;
                root.netbirdStatus = "Disconnected";
                root.netbirdIp = "";
                root.netbirdFqdn = "";
                root.peerCount = 0;
                root.peerConnected = 0;
                root.peerList = [];
            }
            root._stateRestored = true;
            root._saveStateCache();
        }
    }

    Process {
        id: toggleProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                var message = root.lastToggleAction === "connect" ? "NetBird Connected" : "NetBird Disconnected";
                ToastService.showInfo("NetBird", message);
            }
            statusDelayTimer.start();
        }
    }

    Process {
        id: pingProcess
        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            var stdout = String(pingProcess.stdout.text || "").trim();
            var ip = root.currentPingIp;

            if (exitCode === 0 && stdout.length > 0) {
                var match = stdout.match(/time=([\d.]+)/); // basic parsed fallback for latency
                if (match) {
                    var latency = parseFloat(match[1]);
                    var newPings = Object.assign({}, root.peerPings);
                    newPings[ip] = latency.toFixed(1);
                    root.peerPings = newPings;
                }
            } else {
                var newPings2 = Object.assign({}, root.peerPings);
                newPings2[ip] = "timeout";
                root.peerPings = newPings2;
            }

            root.processNextPing();
        }
    }

    function startPingQueue() {
        var queue = [];
        for (var i = 0; i < root.peerList.length; i++) {
            if (root.peerList[i].status === "Connected" && root.peerList[i].netbirdIp) {
                queue.push(root.peerList[i].netbirdIp);
            }
        }
        root.pingQueue = queue;
        root.processNextPing();
    }

    function processNextPing() {
        if (root.pingQueue.length === 0) {
            root.currentPingIp = "";
            return;
        }
        var ip = root.pingQueue[0];
        root.pingQueue = root.pingQueue.slice(1);
        root.currentPingIp = ip;
        pingProcess.command = ["ping", "-c", "1", "-W", "2", ip];
        pingProcess.running = true;
    }

    Timer {
        id: statusDelayTimer
        interval: 500
        repeat: false
        onTriggered: {
            root.isRefreshing = false;
            updateNetbirdStatus();
        }
    }

    function checkNetbirdInstalled() {
        root.isRefreshing = true;
        whichProcess.command = ["which", "netbird"];
        whichProcess.running = true;
    }

    function updateNetbirdStatus() {
        if (!root.netbirdInstalled) {
            root.netbirdRunning = false;
            root.netbirdIp = "";
            root.netbirdStatus = "Not installed";
            root.peerCount = 0;
            root._stateRestored = true;
            root._saveStateCache();
            return;
        }

        root.isRefreshing = true;
        statusProcess.command = ["netbird", "status", "--json"];
        statusProcess.running = true;
    }

    function toggleNetbird() {
        if (!root.netbirdInstalled)
            return;
        root.isRefreshing = true;
        if (root.netbirdRunning) {
            root.lastToggleAction = "disconnect";
            toggleProcess.command = ["netbird", "down"];
            toggleProcess.running = true;
        } else {
            // `netbird up` may run an SSO login that waits on localhost:53000 for the
            // browser redirect. A child Process dies with this widget (e.g. when the
            // control center closes), killing that listener mid-login. Run it detached,
            // report through notify-send, and poll status until it connects.
            root.lastToggleAction = "connect";
            Quickshell.execDetached(["sh", "-c", root.connectScript]);
            connectPollTimer.ticks = 0;
            connectPollTimer.start();
        }
    }

    readonly property string connectScript: [
        'dir="${XDG_RUNTIME_DIR:-/tmp}"',
        'log="$dir/netbird-up.log"',
        'exec 9>"$dir/netbird-up.lock"',
        'if command -v flock >/dev/null && ! flock -n 9; then',
        '  notify-send -a NetBird "NetBird" "Login already in progress. Finish it in the browser."',
        '  exit 0',
        'fi',
        'if netbird up >"$log" 2>&1; then',
        '  notify-send -a NetBird "NetBird" "Connected"',
        'else',
        '  notify-send -u critical -a NetBird "NetBird connect failed" "$(tail -n 3 "$log")"',
        'fi'
    ].join("\n")

    Timer {
        id: connectPollTimer
        property int ticks: 0
        interval: 3000
        repeat: true
        onTriggered: {
            ticks++;
            if (root.netbirdRunning || ticks > 100) {
                stop();
                root.isRefreshing = false;
                return;
            }
            updateNetbirdStatus();
        }
    }

    Timer {
        id: updateTimer
        interval: refreshInterval
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (root.netbirdInstalled === false) {
                checkNetbirdInstalled();
            } else {
                updateNetbirdStatus();
            }
        }
    }

    Component.onCompleted: {
        checkNetbirdInstalled();
        detectTerminal();
    }

    // ── Pre-Sorted Peer List ──
    property var sortedPeerList: {
        if (!root.peerList)
            return [];
        var peers = root.peerList.slice();

        if (root.hideDisconnected) {
            peers = peers.filter(function (peer) {
                return peer.status === "Connected";
            });
        }

        peers.sort(function (a, b) {
            var aConnected = a.status === "Connected";
            var bConnected = b.status === "Connected";
            if (aConnected && !bConnected)
                return -1;
            if (!aConnected && bConnected)
                return 1;

            var nameA = getHostname(a).toLowerCase();
            var nameB = getHostname(b).toLowerCase();
            return nameA.localeCompare(nameB);
        });
        return peers;
    }

    onPeerListChanged: prunePeerOpenMap()
    onHideDisconnectedChanged: prunePeerOpenMap()

    // ── Bar Widget (Pill) ──
    horizontalBarPill: Component {
        Item {
            implicitWidth: hBarRow.implicitWidth
            implicitHeight: hBarRow.implicitHeight

            Row {
                id: hBarRow
                spacing: Theme.spacingXS

                NetBirdIcon {
                    size: root.iconSize
                    color: root.netbirdRunning ? Theme.primary : Theme.surfaceVariantText
                    opacity: root.isRefreshing ? 0.5 : 1.0
                    anchors.verticalCenter: parent.verticalCenter
                    crossed: !root.netbirdRunning
                    colorize: root.colorizeIcon
                }

                StyledText {
                    text: root.netbirdIp
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.netbirdRunning && root.showIpAddress && root.netbirdIp !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof root.triggerPopout === "function")
                        root.triggerPopout();
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: vBarCol.implicitWidth
            implicitHeight: vBarCol.implicitHeight

            Column {
                id: vBarCol
                spacing: Theme.spacingXS

                NetBirdIcon {
                    size: root.iconSize
                    color: root.netbirdRunning ? Theme.primary : Theme.surfaceVariantText
                    opacity: root.isRefreshing ? 0.5 : 1.0
                    anchors.horizontalCenter: parent.horizontalCenter
                    crossed: !root.netbirdRunning
                    colorize: root.colorizeIcon
                }

                StyledText {
                    text: root.netbirdIp
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.netbirdRunning && root.showIpAddress && root.netbirdIp !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof root.triggerPopout === "function")
                        root.triggerPopout();
                }
            }
        }
    }

    // ── Control Center Tile ──
    readonly property bool _ccInitialCheck: root.netbirdStatus === "Checking..."

    ccWidgetIcon: _ccInitialCheck ? "sync" : (root.netbirdRunning ? "vpn_lock" : "vpn_key_off")
    ccWidgetPrimaryText: "NetBird"
    ccWidgetSecondaryText: {
        if (_ccInitialCheck)
            return "Checking...";
        if (!root.netbirdInstalled)
            return "Not installed";
        if (root.netbirdRunning) {
            if (root.netbirdIp !== "")
                return root.netbirdIp;
            return root.peerConnected + "/" + root.peerCount + " peers";
        }
        return root.netbirdStatus;
    }
    ccWidgetIsActive: !_ccInitialCheck && root.netbirdRunning
    ccWidgetIsToggle: true

    property real _ccContentHeight: 250
    ccDetailHeight: _ccContentHeight

    onCcWidgetToggled: root.toggleNetbird()

    ccDetailContent: Component {
        Rectangle {
            id: ccDetailRoot
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            NetbirdContent {
                id: ccDetailCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                widget: root
                compactHeader: true
                peersListMaxHeight: 130
            }

            Component.onCompleted: {
                root._ccContentHeight = Qt.binding(() => ccDetailCol.implicitHeight + Theme.spacingM * 2);
                if (!root.pluginService) {
                    root.pluginService = PluginService;
                }
                if (!root.pluginId) {
                    root.pluginId = "netbirdStatus";
                }
            }
        }
    }

    // ── Popout Content ──
    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "NetBird"
            showCloseButton: true

            NetbirdContent {
                width: parent.width
                widget: root
            }
        }
    }
}
