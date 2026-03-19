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
    property bool compactMode: pluginData.compactMode !== undefined ? pluginData.compactMode : false
    property bool showIpAddress: pluginData.showIpAddress !== undefined ? pluginData.showIpAddress : true
    property bool hideDisconnected: pluginData.hideDisconnected !== undefined ? pluginData.hideDisconnected : false
    property bool showPing: pluginData.showPing !== undefined ? pluginData.showPing : false
    property int pingCount: pluginData.pingCount !== undefined ? pluginData.pingCount : 5
    property string customTerminal: pluginData.terminalCommand || ""
    function normalizePeerAction(value) {
        if (value === "Copy IP") return "copy-ip"
        if (value === "SSH to host") return "ssh"
        if (value === "Ping host") return "ping"
        return value || "copy-ip"
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
        if (!ip) return "";
        var idx = ip.indexOf("/");
        if (idx > 0) return ip.substring(0, idx);
        return ip;
    }

    function getHostname(peer) {
        if (!peer) return "Unknown";
        if (peer.fqdn) {
            var parts = peer.fqdn.split(".");
            if (parts.length > 0) return parts[0];
        }
        return peer.netbirdIp || "Unknown";
    }

    function getConnectionIcon(connType) {
        if (!connType) return "signal_disconnected";
        switch (connType.toLowerCase()) {
        case "p2p": return "compare_arrows";
        case "relayed": return "cloud";
        default: return "signal_disconnected";
        }
    }

    function requireTerminal() {
        if (!terminalDetected) {
            ToastService.showError("NetBird Terminal Not Configured", "Please install a supported terminal emulator to use SSH and Ping features")
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
                ToastService.showInfo("IP Copied", "IP of " + getHostname(peer) + " copied to clipboard")
            }
        } else if (action === "ssh") {
            if (!requireTerminal()) return;
            if (peer && peer.netbirdIp) {
                Quickshell.execDetached([root.activeTerminal, "-e", "ssh", peer.netbirdIp]);
            }
        } else if (action === "ping") {
            if (!requireTerminal()) return;
            if (peer && peer.netbirdIp) {
                Quickshell.execDetached([root.activeTerminal, "-e", "ping", "-c", root.pingCount.toString(), peer.netbirdIp]);
            }
        }
    }

    function getPeerKey(peer) {
        if (!peer) return "";
        return peer.netbirdIp || peer.fqdn || "";
    }

    function isPeerOpen(peer) {
        const key = getPeerKey(peer);
        if (!key) return false;
        return peerActionOpenMap[key] === true;
    }

    function setPeerOpen(peer, open) {
        const key = getPeerKey(peer);
        if (!key) return;
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
        }
    }

    Process {
        id: toggleProcess
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                var message = root.lastToggleAction === "connect" ? "NetBird Connected" : "NetBird Disconnected";
                ToastService.showInfo("NetBird", message)
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
            return;
        }

        root.isRefreshing = true;
        statusProcess.command = ["netbird", "status", "--json"];
        statusProcess.running = true;
    }

    function toggleNetbird() {
        if (!root.netbirdInstalled) return;
        root.isRefreshing = true;
        if (root.netbirdRunning) {
            root.lastToggleAction = "disconnect";
            toggleProcess.command = ["netbird", "down"];
        } else {
            root.lastToggleAction = "connect";
            toggleProcess.command = ["netbird", "up"];
        }
        toggleProcess.running = true;
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
        if (!root.peerList) return [];
        var peers = root.peerList.slice();

        if (root.hideDisconnected) {
            peers = peers.filter(function (peer) {
                return peer.status === "Connected";
            });
        }

        peers.sort(function (a, b) {
            var aConnected = a.status === "Connected";
            var bConnected = b.status === "Connected";
            if (aConnected && !bConnected) return -1;
            if (!aConnected && bConnected) return 1;

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
                }

                StyledText {
                    text: root.netbirdIp
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.compactMode && root.netbirdRunning && root.showIpAddress && root.netbirdIp !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof root.triggerPopout === "function") root.triggerPopout()
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
                }

                StyledText {
                    text: root.netbirdIp
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.compactMode && root.netbirdRunning && root.showIpAddress && root.netbirdIp !== ""
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof root.triggerPopout === "function") root.triggerPopout()
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

            Column {
                width: parent.width
                spacing: Theme.spacingM

                // Header / Status Card
                StyledRect {
                    width: parent.width
                    height: statusCol.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            NetBirdIcon {
                                size: 32
                                color: root.netbirdRunning ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                                crossed: !root.netbirdRunning
                            }

                            Column {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: "NetBird Network"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: root.netbirdRunning ? (root.peerConnected + "/" + root.peerCount + " peers") : root.netbirdStatus
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }

                        Item { width: 1; height: Theme.spacingS }

                        StyledText {
                            text: root.netbirdIp
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            visible: root.netbirdRunning && root.netbirdIp !== ""
                            width: parent.width

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyToClipboard(root.netbirdIp)
                            }
                        }

                        StyledText {
                            text: root.netbirdFqdn
                            font.pixelSize: 12
                            color: Theme.surfaceVariantText
                            visible: root.netbirdRunning && root.netbirdFqdn !== ""
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        Item { width: 1; height: Theme.spacingS; visible: root.netbirdRunning }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: root.netbirdRunning

                            Row {
                                spacing: 4
                                DankIcon {
                                    name: "dns"
                                    size: 16
                                    color: root.managementConnected ? Theme.primary : Theme.error
                                }
                                StyledText {
                                    text: "Management"
                                    font.pixelSize: 12
                                    color: Theme.surfaceVariantText
                                }
                            }

                            Row {
                                spacing: 4
                                DankIcon {
                                    name: "wifi"
                                    size: 16
                                    color: root.signalConnected ? Theme.primary : Theme.error
                                }
                                StyledText {
                                    text: "Signal"
                                    font.pixelSize: 12
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outlineVariant
                    visible: root.netbirdRunning && root.sortedPeerList.length > 0
                }

                // Peers List
                Item {
                    width: parent.width
                    height: Math.min(peersCol.implicitHeight, 250)
                    clip: true
                    visible: root.netbirdRunning && root.sortedPeerList.length > 0

                    Flickable {
                        anchors.fill: parent
                        contentHeight: peersCol.implicitHeight
                        contentWidth: width
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            minimumSize: 0.1
                            contentItem: Rectangle {
                                radius: width / 2
                                color: Theme.primary
                                opacity: parent.pressed ? 0.9 : (parent.hovered ? 0.75 : 0.5)
                            }
                            background: Rectangle {
                                radius: width / 2
                                color: Theme.surfaceContainerHighest
                                opacity: 0.4
                            }
                        }

                        Column {
                            id: peersCol
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.sortedPeerList
                                delegate: Item {
                                    width: peersCol.width
                                    height: peerRow.height + (actionsCol.visible ? actionsCol.implicitHeight + Theme.spacingXS : 0)

                                    readonly property var peerData: modelData
                                    readonly property bool peerConnected: peerData.status === "Connected"
                                    property bool actionsOpen: root.isPeerOpen(peerData)

                                    onPeerConnectedChanged: {
                                        if (!peerConnected) {
                                            root.setPeerOpen(peerData, false)
                                        }
                                    }

                                    Column {
                                        anchors.fill: parent
                                        spacing: Theme.spacingXS

                                        Rectangle {
                                            id: peerRow
                                            width: parent.width
                                            height: 56
                                            color: peerMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                            radius: Theme.cornerRadius

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingM

                                                DankIcon {
                                                    name: root.getConnectionIcon(peerData.connectionType)
                                                    size: 20
                                                    color: peerConnected ? Theme.primary : Theme.surfaceVariantText
                                                }

                                                Column {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    StyledText {
                                                        text: root.getHostname(peerData)
                                                        color: Theme.surfaceText
                                                        font.weight: Font.Medium
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                    StyledText {
                                                        visible: peerData.connectionType !== ""
                                                        text: peerData.connectionType
                                                        font.pixelSize: 12
                                                        color: Theme.surfaceVariantText
                                                    }
                                                }

                                                Column {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 2
                                                    StyledText {
                                                        text: peerData.netbirdIp
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Theme.surfaceVariantText
                                                        anchors.right: parent.right
                                                    }
                                                    StyledText {
                                                        visible: root.showPing && peerConnected
                                                        text: {
                                                            var pingVal = root.peerPings[peerData.netbirdIp] ?? "";
                                                            if (pingVal === "") return "...";
                                                            if (pingVal === "timeout") return "timeout";
                                                            return pingVal + " ms";
                                                        }
                                                        font.pixelSize: 12
                                                        anchors.right: parent.right
                                                        color: {
                                                            var pingVal = root.peerPings[peerData.netbirdIp] ?? "";
                                                            if (pingVal === "" || pingVal === "timeout") return Theme.error;
                                                            var ms = parseFloat(pingVal);
                                                            if (ms < 50) return Theme.primary;
                                                            if (ms < 150) return "#FF9800";
                                                            return Theme.error;
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: peerMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        root.setPeerOpen(peerData, false)
                                                        if (!peerConnected && root.defaultPeerAction !== "copy-ip") {
                                                            return
                                                        }
                                                        root.executePeerAction(root.defaultPeerAction, peerData)
                                                    } else if (mouse.button === Qt.RightButton) {
                                                        if (peerConnected) {
                                                            root.setPeerOpen(peerData, !root.isPeerOpen(peerData))
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Column {
                                            id: actionsCol
                                            width: parent.width
                                            spacing: 2
                                            visible: peerConnected && actionsOpen

                                            Repeater {
                                                model: [
                                                    { action: "copy-ip", label: "Copy IP", icon: "content_copy" },
                                                    { action: "ssh", label: "SSH to host", icon: "terminal" },
                                                    { action: "ping", label: "Ping host", icon: "network_ping" }
                                                ]

                                                delegate: Rectangle {
                                                    width: parent.width
                                                    height: 32
                                                    radius: Theme.cornerRadius - 2
                                                    color: actionArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                                    Row {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: Theme.spacingM
                                                        anchors.rightMargin: Theme.spacingM
                                                        spacing: Theme.spacingM

                                                        DankIcon {
                                                            name: modelData.icon
                                                            size: 16
                                                            color: Theme.surfaceText
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        StyledText {
                                                            text: modelData.label
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceText
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: actionArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.executePeerAction(modelData.action, peerData)
                                                            root.setPeerOpen(peerData, false)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: "No connected peers"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.netbirdRunning && root.sortedPeerList.length === 0
                }

                // Controls
                Button {
                    width: parent.width
                    height: 40
                    text: root.netbirdRunning ? "Disconnect" : "Connect"
                    visible: root.netbirdInstalled

                    contentItem: StyledText {
                        text: parent.text
                        color: parent.hovered ? Theme.surface : Theme.onPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.weight: Font.Bold
                    }

                    background: Rectangle {
                        color: root.netbirdRunning ? Theme.error : Theme.primary
                        radius: 20
                        opacity: parent.hovered ? 0.8 : 1.0
                    }

                    onClicked: root.toggleNetbird()
                }

                // Admin Console button
                Button {
                    width: parent.width
                    height: 40
                    text: "Admin Console"
                    visible: root.netbirdRunning

                    contentItem: StyledText {
                        text: parent.text
                        color: Theme.primary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.weight: Font.Medium
                    }

                    background: Rectangle {
                        color: Theme.surfaceContainerHighest
                        radius: 20
                        opacity: parent.hovered ? 0.8 : 1.0
                    }

                    onClicked: Qt.openUrlExternally("https://app.netbird.io/")
                }
            }
        }
    }
}
