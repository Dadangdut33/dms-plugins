import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: root
    property var pluginApi: null
    property bool panelVisible: false

    // ── Clipboard items ────────────────────────────────────────────────────────
    property var items: []
    property bool loading: false
    property var firstSeenById: ({})
    property int previewWidth: 100

    // ── Full-text decode queue ─────────────────────────────────────────────────
    property var decodedTextCache: ({})
    property var decodeQueue: []
    property var decodeQueued: ({})
    property bool decodeRunning: false
    property int decodedRevision: 0

    // ── Image cache (LRU, max 50 entries) ─────────────────────────────────────
    property var imageCache: ({})
    property var imageCacheOrder: []
    property int imageCacheRevision: 0
    readonly property int maxImageCacheSize: 50

    // ── Pinned items ───────────────────────────────────────────────────────────
    property var pinnedItems: []
    property int pinnedRevision: 0

    // ── Note cards ────────────────────────────────────────────────────────────
    property var noteCards: []
    property int noteCardsRevision: 0
    property bool noteCardsLoaded: false
    property int noteCardsLoadToken: 0
    property var deletedNoteIds: ({})

    // ── ToDo ───────────────────────────────────────────────────────────────────
    property var todoPages: []
    property var todos: []
    property int todoRevision: 0

    // ── Pending / selector state ───────────────────────────────────────────────
    property string pendingSelectedText: ""
    property string pendingNoteCardText: ""
    property int pendingPageId: 0
    property string activeSelector: ""  // "todo" | "notecard"

    // ── Auto-paste ─────────────────────────────────────────────────────────────
    property bool wtypeAvailable: false
    property bool autoPasteAfterNextCopy: false

    // ── Limits ────────────────────────────────────────────────────────────────
    readonly property int maxPinnedItems: 100
    readonly property int maxNoteCards: 50
    readonly property int maxTodoTextLength: 500
    readonly property int maxPinnedTextMb: Math.max(1, Math.floor(pluginApi?.pluginSettings?.maxPinnedTextMb ?? 1)) * 1024 * 1024
    readonly property int maxPinnedImageMb: Math.max(5, Math.floor(pluginApi?.pluginSettings?.maxPinnedImageMb ?? 5)) * 1024 * 1024
    readonly property int maxPreviewImageSize: maxPinnedImageMb
    readonly property bool useBuiltInDmsClipboard: pluginApi?.pluginSettings?.useDmsClipboard ?? (pluginApi?.pluginSettings?.useBuiltInDmsClipboard ?? false)

    // ── Paths ──────────────────────────────────────────────────────────────────
    readonly property string defaultConfigRoot: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dms-clipboardPlus"
    readonly property string configRoot: {
        const custom = pluginApi?.pluginSettings?.dataBasePath;
        return (custom && String(custom).trim().length > 0) ? custom : defaultConfigRoot;
    }
    readonly property string clipboardPlusConfigDir: configRoot + "/data"
    readonly property string noteCardsDir: clipboardPlusConfigDir + "/notecards"
    readonly property string exportBasePath: {
        const custom = pluginApi?.pluginSettings?.exportPath;
        return (custom && String(custom).trim().length > 0) ? custom : (Quickshell.env("HOME") + "/Documents");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FILE VIEWS
    // ══════════════════════════════════════════════════════════════════════════

    FileView {
        id: pinnedFile
        path: clipboardPlusConfigDir + "/pinned.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (root.useBuiltInDmsClipboard)
                return;
            try {
                const data = JSON.parse(text());
                root.pinnedItems = data.items || [];
            } catch (_) {
                root.pinnedItems = [];
            }
            root.pinnedRevision++;
        }
        onLoadFailed: {
            if (root.useBuiltInDmsClipboard)
                return;
            root.pinnedItems = [];
            root.pinnedRevision++;
        }
    }

    FileView {
        id: todoFile
        path: clipboardPlusConfigDir + "/todo.json"
        watchChanges: false
        blockWrites: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const raw = text();
            let parsed = null;
            let repaired = false;
            try {
                parsed = JSON.parse(raw);
            } catch (_) {
                const lastBrace = raw.lastIndexOf("}");
                if (lastBrace !== -1) {
                    try {
                        parsed = JSON.parse(raw.slice(0, lastBrace + 1));
                        repaired = true;
                    } catch (_2) {}
                }
            }
            const data = parsed || {};
            const pages = data.pages || [];
            root.todoPages = pages.length > 0 ? pages : [
                {
                    id: 1,
                    name: "Inbox"
                }
            ];
            root.todos = Array.isArray(data.todos) ? data.todos : [];
            root.todoRevision++;
            if (repaired)
                root.saveTodoFile();
        }
        onLoadFailed: error => {
            if (error === 2) {
                root.todoPages = [
                    {
                        id: 1,
                        name: "Inbox"
                    }
                ];
                root.todos = [];
                root.todoRevision++;
                root.saveTodoFile();
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // IPC HANDLER  (single handler, target: "clipboardPlus")
    // ══════════════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "clipboardPlus"

        function openPanel() {
            root.ipcOpenPanel();
        }
        function closePanel() {
            root.ipcClosePanel();
        }
        function togglePanel() {
            root.ipcTogglePanel();
        }
        function toggle() {
            root.ipcTogglePanel();
        }

        function pinClipboardItem(cliphistId: string) {
            root.pinItem(cliphistId);
        }
        function unpinItem(pinnedId: string) {
            root.unpinItem(pinnedId);
        }
        function copyPinned(pinnedId: string) {
            root.copyPinnedToClipboard(pinnedId);
        }

        function addClipboardToTodo() {
            root.fetchTextThen("clipboard", t => root.addTodoWithText(t, 0));
        }

        function addNoteCard(text: string) {
            root.createNoteCard(text || "");
        }
        function exportNoteCard(noteId: string) {
            root.exportNoteCard(noteId);
        }
        function listNoteCards(): string {
            return root.listNoteCardsIpc();
        }

        function addClipboardToNoteCard() {
            root.fetchTextThen("clipboard", t => root.showSelector("notecard", t));
        }
    }

    function ipcOpenPanel() {
        pluginApi?.withCurrentScreen(screen => pluginApi.openPanel(screen));
    }
    function ipcClosePanel() {
        pluginApi?.withCurrentScreen(screen => pluginApi.closePanel(screen));
    }
    function ipcTogglePanel() {
        pluginApi?.withCurrentScreen(screen => pluginApi.togglePanel(screen));
    }

    function clipboardHistoryCommand(width) {
        if (root.useBuiltInDmsClipboard)
            return ["dms", "cl", "history", "--json"];
        return ["cliphist", "list", "-preview-width", String(width)];
    }

    function clipboardHeadCommand() {
        if (root.useBuiltInDmsClipboard)
            return ["dms", "cl", "history", "--json"];
        return ["cliphist", "list", "-preview-width", "1"];
    }

    function clipboardGetTextCommand(id) {
        if (root.useBuiltInDmsClipboard)
            return ["sh", "-c", `dms cl get ${id} | base64 -d`];
        return ["cliphist", "decode", String(id)];
    }

    function clipboardGetJsonCommand(id) {
        return ["dms", "cl", "get", String(id), "--json"];
    }

    function requestBuiltInClipboardEntry(id, onSuccess, onFailure) {
        const numericId = Number(id);
        if (!Number.isFinite(numericId) || numericId <= 0) {
            onFailure?.();
            return;
        }
        DMSService.sendRequest("clipboard.getEntry", {
            id: numericId
        }, function (response) {
            if (response?.error || !response?.result) {
                onFailure?.(response?.error || "Failed to get clipboard entry");
                return;
            }
            onSuccess?.(response.result);
        });
    }

    function requestBuiltInClipboardHistory(onSuccess, onFailure) {
        DMSService.sendRequest("clipboard.getHistory", null, function (response) {
            if (response?.error || !Array.isArray(response?.result)) {
                onFailure?.(response?.error || "Failed to get clipboard history");
                return;
            }
            onSuccess?.(response.result);
        });
    }

    function parseHistoryItems(output) {
        if (!root.useBuiltInDmsClipboard) {
            const lines = String(output || "").split("\n").filter(l => l.length > 0);
            return lines.map(l => {
                let id = "", preview = "";
                const m = l.match(/^(\d+)\s+(.+)$/);
                if (m) {
                    id = m[1];
                    preview = m[2];
                } else {
                    const tab = l.indexOf("\t");
                    id = tab > -1 ? l.slice(0, tab) : l;
                    preview = tab > -1 ? l.slice(tab + 1) : "";
                }
                const lower = preview.toLowerCase();
                const isImage = lower.startsWith("[image]") || lower.includes(" binary data ");
                let mime = "text/plain";
                if (isImage) {
                    if (lower.includes(" png"))
                        mime = "image/png";
                    else if (lower.includes(" jpg") || lower.includes(" jpeg"))
                        mime = "image/jpeg";
                    else if (lower.includes(" webp"))
                        mime = "image/webp";
                    else if (lower.includes(" gif"))
                        mime = "image/gif";
                    else
                        mime = "image/*";
                }
                if (!root.firstSeenById[id])
                    root.firstSeenById[id] = Date.now();
                return {
                    id,
                    preview,
                    isImage,
                    mime,
                    pinned: false
                };
            });
        }

        let parsed = [];
        try {
            parsed = JSON.parse(String(output || "[]"));
        } catch (_) {
            return [];
        }

        return (Array.isArray(parsed) ? parsed : []).map(entry => {
            const id = String(entry.id ?? "");
            const preview = String(entry.preview ?? "");
            const mime = String(entry.mimeType || "text/plain");
            const isImage = Boolean(entry.isImage) || mime.startsWith("image/");
            if (id && !root.firstSeenById[id])
                root.firstSeenById[id] = Date.now();
            return {
                id,
                preview,
                isImage,
                mime,
                pinned: Boolean(entry.pinned)
            };
        }).filter(entry => entry.id.length > 0);
    }

    function parseBuiltInHistoryEntries(entries) {
        return (Array.isArray(entries) ? entries : []).map(entry => {
            const id = String(entry.id ?? "");
            const preview = String(entry.preview ?? "");
            const mime = String(entry.mimeType || "text/plain");
            const isImage = Boolean(entry.isImage) || mime.startsWith("image/");
            if (id && !root.firstSeenById[id])
                root.firstSeenById[id] = Date.now();
            return {
                id,
                preview,
                isImage,
                mime,
                pinned: Boolean(entry.pinned)
            };
        }).filter(entry => entry.id.length > 0);
    }

    function syncBuiltInPinnedItems() {
        if (!root.useBuiltInDmsClipboard)
            return;
        root.pinnedItems = root.items.filter(item => item.pinned).map(item => {
            return {
                id: item.id,
                cliphistId: item.id,
                content: "",
                preview: item.preview,
                mime: item.mime || "text/plain",
                isImage: item.isImage || false,
                pinnedAt: Date.now()
            };
        });
        root.pinnedRevision++;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CLIPBOARD LIST
    // ══════════════════════════════════════════════════════════════════════════

    function list(maxPreviewWidth) {
        root.loading = true;
        const width = (maxPreviewWidth !== undefined && maxPreviewWidth !== null) ? maxPreviewWidth : root.previewWidth;
        root.previewWidth = width;
        if (root.useBuiltInDmsClipboard) {
            root.requestBuiltInClipboardHistory(function (entries) {
                root.items = root.parseBuiltInHistoryEntries(entries);
                root.syncBuiltInPinnedItems();
                root.loading = false;
                if (root.items.length > 0)
                    root.lastClipboardId = root.items[0].id;
            }, function () {
                root.items = [];
                root.syncBuiltInPinnedItems();
                root.loading = false;
            });
            return;
        }
        if (listProc.running)
            return;
        listProc.command = root.clipboardHistoryCommand(width);
        listProc.running = true;
    }

    Process {
        id: listProc
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.items = [];
                root.loading = false;
                return;
            }
            root.items = root.parseHistoryItems(stdout.text);
            root.syncBuiltInPinnedItems();
            root.loading = false;
            if (root.items.length > 0) {
                root.lastClipboardId = root.items[0].id;
            }
        }
    }

    // ── Poll while panel is open (optional setting) ───────────────────────────
    property string lastClipboardId: ""

    Timer {
        id: clipboardPollTimer
        interval: 500
        repeat: true
        running: root.panelVisible && (pluginApi?.pluginSettings?.listenClipboardWhileOpen ?? false)
        onTriggered: {
            if (root.useBuiltInDmsClipboard) {
                root.requestBuiltInClipboardHistory(function (entries) {
                    const builtInItems = root.parseBuiltInHistoryEntries(entries);
                    const id = builtInItems.length > 0 ? builtInItems[0].id : "";
                    if (id && id !== root.lastClipboardId) {
                        root.items = builtInItems;
                        root.syncBuiltInPinnedItems();
                        root.lastClipboardId = id;
                    }
                });
                return;
            }
            if (!clipboardPollProc.running) {
                clipboardPollProc.command = root.clipboardHeadCommand();
                clipboardPollProc.running = true;
            }
        }
    }

    Process {
        id: clipboardPollProc
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            const polledItems = root.parseHistoryItems(stdout.text);
            const id = polledItems.length > 0 ? polledItems[0].id : "";
            if (id && id !== root.lastClipboardId) {
                root.lastClipboardId = id;
                root.list();
            }
        }
    }

    Connections {
        target: DMSService
        enabled: root.useBuiltInDmsClipboard

        function onClipboardStateUpdate(data) {
            const builtInItems = root.parseBuiltInHistoryEntries(data?.history || []);
            root.items = builtInItems;
            root.syncBuiltInPinnedItems();
            root.loading = false;
            if (builtInItems.length > 0)
                root.lastClipboardId = builtInItems[0].id;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COPY TO CLIPBOARD
    // ══════════════════════════════════════════════════════════════════════════

    // Copy a cliphist entry by id (decode → wl-copy pipe)
    function copyToClipboard(id) {
        if (!id || !/^\d+$/.test(String(id))) {
            ToastService.showError("Invalid clipboard item");
            return;
        }
        if (root.useBuiltInDmsClipboard) {
            root.requestBuiltInClipboardEntry(id, function (_) {
                DMSService.sendRequest("clipboard.copyEntry", {
                    id: Number(id)
                }, function (response) {
                    if (response?.error) {
                        ToastService.showError("Failed to copy");
                        root.autoPasteAfterNextCopy = false;
                        return;
                    }
                    if (root.autoPasteAfterNextCopy) {
                        root.autoPasteAfterNextCopy = false;
                        root.triggerAutoPaste();
                    }
                    ToastService.showInfo("Copied to clipboard");
                });
            }, function () {
                ToastService.showError("Failed to copy");
                root.autoPasteAfterNextCopy = false;
            });
            return;
        } else {
            copyDecodeProc.command = ["sh", "-c", `cliphist decode ${id} | wl-copy`];
        }
        copyDecodeProc.running = true;
    }

    Process {
        id: copyDecodeProc
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError("Failed to copy");
                root.autoPasteAfterNextCopy = false;
                return;
            }
            if (root.autoPasteAfterNextCopy) {
                root.autoPasteAfterNextCopy = false;
                root.triggerAutoPaste();
            }
            ToastService.showInfo("Copied to clipboard");
        }
    }

    // Copy raw text or binary (used by pinned items)
    function copyRawText(text, silent) {
        if (text == null)
            return;
        copyRawTextProc.notify = !silent;
        copyRawTextProc.command = root.useBuiltInDmsClipboard ? ["dms", "cl", "copy"] : ["wl-copy", "--"];
        copyRawTextProc.running = true;
        copyRawTextProc.write(String(text));
        copyRawTextProc.stdinEnabled = false;
    }

    function copyRawImage(mimeType, base64Data, silent) {
        const binaryStr = Qt.atob(base64Data);
        const bytes = new Uint8Array(binaryStr.length);
        for (let i = 0; i < binaryStr.length; i++)
            bytes[i] = binaryStr.charCodeAt(i);
        copyRawImageProc.notify = !silent;
        copyRawImageProc.command = root.useBuiltInDmsClipboard ? ["dms", "cl", "copy", "-t", mimeType] : ["wl-copy"];
        copyRawImageProc.running = true;
        copyRawImageProc.write(bytes);
        copyRawImageProc.stdinEnabled = false;
    }

    Process {
        id: copyRawTextProc
        property bool notify: true
        stdinEnabled: true
        onExited: exitCode => {
            stdinEnabled = true;
            if (exitCode === 0 && root.autoPasteAfterNextCopy) {
                root.autoPasteAfterNextCopy = false;
                root.triggerAutoPaste();
            } else if (exitCode !== 0) {
                root.autoPasteAfterNextCopy = false;
            }
            if (!notify)
                return;
            exitCode === 0 ? ToastService.showInfo("Copied to clipboard") : ToastService.showError("Failed to copy text");
        }
    }

    Process {
        id: copyRawImageProc
        property bool notify: true
        stdinEnabled: true
        onExited: exitCode => {
            stdinEnabled = true;
            if (exitCode === 0 && root.autoPasteAfterNextCopy) {
                root.autoPasteAfterNextCopy = false;
                root.triggerAutoPaste();
            } else if (exitCode !== 0) {
                root.autoPasteAfterNextCopy = false;
            }
            if (!notify)
                return;
            exitCode === 0 ? ToastService.showInfo("Copied to clipboard") : ToastService.showError("Failed to copy image");
        }
    }

    function copyTextToClipboard(text) {
        copyRawText(text, false);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DELETE / WIPE
    // ══════════════════════════════════════════════════════════════════════════

    function deleteById(id) {
        if (!id || !/^\d+$/.test(String(id))) {
            ToastService.showError("Invalid clipboard item");
            return;
        }
        if (root.useBuiltInDmsClipboard) {
            DMSService.sendRequest("clipboard.deleteEntry", {
                id: Number(id)
            }, function (response) {
                if (response?.error) {
                    ToastService.showError("Failed to delete item");
                    return;
                }
                root.list();
            });
            return;
        }
        deleteItemProc.command = ["sh", "-c", `cliphist list | grep "^${id}	" | cliphist delete`];
        deleteItemProc.running = true;
    }

    Process {
        id: deleteItemProc
        stdout: StdioCollector {}
        onExited: _ => root.list()
    }

    function wipeAll() {
        if (root.useBuiltInDmsClipboard) {
            DMSService.sendRequest("clipboard.clearHistory", null, function (response) {
                if (response?.error) {
                    ToastService.showError("Failed to clear history");
                    return;
                }
                root.clearCaches();
                root.list();
            });
            return;
        }
        wipeProc.command = root.wipeCommand();
        wipeProc.running = true;
    }

    Process {
        id: wipeProc
        onExited: _ => {
            root.clearCaches();
            root.list();
        }
    }

    function wipeCommand() {
        return root.useBuiltInDmsClipboard ? ["dms", "cl", "clear"] : ["cliphist", "wipe"];
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FULL-TEXT DECODE QUEUE
    // ══════════════════════════════════════════════════════════════════════════

    function getDecodedText(id) {
        return decodedTextCache[id] || "";
    }

    function queueTextDecode(id) {
        if (!(pluginApi?.pluginSettings?.enableFullTextDecode ?? false))
            return;
        if (!id || decodedTextCache[id] || decodeQueued[id])
            return;
        decodeQueued[id] = true;
        decodeQueue.push(id);
        startTextDecode();
    }

    function queueTextDecodes(itemsList) {
        if (!(pluginApi?.pluginSettings?.enableFullTextDecode ?? false))
            return;
        for (let i = 0; i < itemsList.length; i++) {
            const it = itemsList[i];
            if (!it || it.isImage)
                continue;
            queueTextDecode(it.id);
        }
    }

    function queueTextDecodesRange(itemsList, startIndex, endIndex) {
        if (!(pluginApi?.pluginSettings?.enableFullTextDecode ?? false))
            return;
        if (!itemsList?.length)
            return;
        const start = Math.max(0, startIndex);
        const end = Math.min(itemsList.length - 1, endIndex);
        for (let i = start; i <= end; i++) {
            const it = itemsList[i];
            if (!it || it.isImage)
                continue;
            queueTextDecode(it.id);
        }
    }

    function startTextDecode() {
        if (decodeRunning || decodeQueue.length === 0)
            return;
        const id = decodeQueue.shift();
        decodeRunning = true;
        textDecodeProc.clipId = id;
        textDecodeProc.command = root.clipboardGetTextCommand(id);
        textDecodeProc.running = true;
    }

    Process {
        id: textDecodeProc
        property string clipId: ""
        stdout: StdioCollector {}
        onExited: exitCode => {
            const id = clipId;
            decodeRunning = false;
            decodeQueued[id] = false;
            if (exitCode === 0) {
                decodedTextCache[id] = String(stdout.text || "");
                decodedRevision++;
            }
            startTextDecode();
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // IMAGE CACHE
    // ══════════════════════════════════════════════════════════════════════════

    function getImageData(cliphistId) {
        return root.imageCache[cliphistId] || "";
    }

    function decodeToDataUrl(cliphistId, mimeType, callback) {
        if (!cliphistId || !/^\d+$/.test(String(cliphistId)))
            return;
        if (root.imageCache[cliphistId]) {
            callback?.(root.imageCache[cliphistId]);
            return;
        }
        if (root.useBuiltInDmsClipboard) {
            root.requestBuiltInClipboardEntry(cliphistId, function (entry) {
                const base64 = String(entry.data || "").trim();
                const resolvedMimeType = String(entry.mimeType || mimeType || "image/png");
                if (!base64)
                    return;
                if ((base64.length * 3) / 4 > maxPreviewImageSize)
                    return;
                const dataUrl = "data:" + resolvedMimeType + ";base64," + base64;
                root.addToImageCache(cliphistId, dataUrl);
                callback?.(dataUrl);
            });
            return;
        }
        imageDecodeProc.cliphistId = cliphistId;
        imageDecodeProc.mimeType = mimeType || "image/png";
        imageDecodeProc.callback = callback;
        imageDecodeProc.command = ["sh", "-c", `cliphist decode ${cliphistId} | base64 -w 0`];
        imageDecodeProc.running = true;
    }

    Process {
        id: imageDecodeProc
        property string cliphistId: ""
        property string mimeType: "image/png"
        property var callback: null
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            let base64 = "";
            let mimeType = imageDecodeProc.mimeType;
            if (root.useBuiltInDmsClipboard) {
                try {
                    const entry = JSON.parse(String(stdout.text || "{}"));
                    base64 = String(entry.data || "").trim();
                    mimeType = String(entry.mimeType || mimeType);
                } catch (_) {
                    return;
                }
            } else {
                base64 = String(stdout.text).trim();
            }
            if (!base64)
                return;
            if ((base64.length * 3) / 4 > maxPreviewImageSize)
                return;
            const dataUrl = "data:" + mimeType + ";base64," + base64;
            root.addToImageCache(cliphistId, dataUrl);
            callback?.(dataUrl);
        }
    }

    function addToImageCache(cliphistId, dataUrl) {
        const existingIndex = root.imageCacheOrder.indexOf(cliphistId);
        if (existingIndex !== -1)
            root.imageCacheOrder = root.imageCacheOrder.filter((_, i) => i !== existingIndex);
        while (root.imageCacheOrder.length >= maxImageCacheSize) {
            const oldest = root.imageCacheOrder[0];
            root.imageCacheOrder = root.imageCacheOrder.slice(1);
            const c = Object.assign({}, root.imageCache);
            delete c[oldest];
            root.imageCache = c;
        }
        root.imageCache = Object.assign({}, root.imageCache, {
            [cliphistId]: dataUrl
        });
        root.imageCacheOrder = [...root.imageCacheOrder, cliphistId];
        root.imageCacheRevision++;
    }

    function clearCaches() {
        root.imageCache = {};
        root.imageCacheOrder = [];
        root.imageCacheRevision++;
        root.firstSeenById = {};
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PINNED ITEMS
    // ══════════════════════════════════════════════════════════════════════════

    function pinItem(cliphistId) {
        if (!cliphistId || !/^\d+$/.test(String(cliphistId))) {
            ToastService.showError("Invalid clipboard item");
            return;
        }
        if (root.useBuiltInDmsClipboard) {
            DMSService.sendRequest("clipboard.getPinnedCount", null, function (countResponse) {
                if (countResponse?.error) {
                    ToastService.showError("Failed to check pin limit");
                    return;
                }
                const count = Number(countResponse?.result?.count ?? 0);
                if (count >= maxPinnedItems) {
                    ToastService.showWarning(("Maximum {max} pinned items reached").replace("{max}", maxPinnedItems));
                    return;
                }
                DMSService.sendRequest("clipboard.pinEntry", {
                    id: Number(cliphistId)
                }, function (response) {
                    if (response?.error) {
                        ToastService.showError("Failed to pin item");
                        return;
                    }
                    root.list();
                    ToastService.showInfo("Item pinned");
                });
            });
            return;
        }
        if (root.pinnedItems.length >= maxPinnedItems) {
            ToastService.showWarning(("Maximum {max} pinned items reached").replace("{max}", maxPinnedItems));
            return;
        }
        const item = root.items.find(i => i.id === cliphistId);
        if (!item) {
            ToastService.showError("Item not found in clipboard");
            return;
        }

        const newItem = {
            id: "pinned-" + Date.now() + "-" + cliphistId,
            cliphistId,
            content: "",
            preview: item.preview,
            mime: item.mime || "text/plain",
            isImage: item.isImage || false,
            pinnedAt: Date.now()
        };
        if (item.isImage && root.useBuiltInDmsClipboard) {
            root.requestBuiltInClipboardEntry(cliphistId, function (entry) {
                const base64 = String(entry.data || "").trim();
                const mimeType = String(entry.mimeType || newItem.mime || "image/png");
                if (!base64) {
                    ToastService.showError("Failed to pin image");
                    return;
                }
                if ((base64.length * 3) / 4 > root.maxPinnedImageMb) {
                    ToastService.showWarning("Image too large to pin (max 5MB)");
                    return;
                }
                newItem.mime = mimeType;
                newItem.content = "data:" + mimeType + ";base64," + base64;
                root.pinnedItems = [...root.pinnedItems, newItem];
                root.savePinnedFile();
                Quickshell.execDetached(["dms", "cl", "delete", String(newItem.cliphistId)]);
                root.pinnedRevision++;
                ToastService.showInfo("Item pinned");
            }, function () {
                ToastService.showError("Failed to pin image");
            });
            return;
        }
        decodeProc.pinnedItem = newItem;
        decodeProc.command = item.isImage ? ["sh", "-c", `cliphist decode ${cliphistId} | base64 -w 0`] : root.clipboardGetTextCommand(cliphistId);
        decodeProc.running = true;
    }

    Process {
        id: decodeProc
        property var pinnedItem: null
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError("Failed to pin item");
                return;
            }
            const item = pinnedItem;
            if (item.isImage) {
                let base64 = "";
                let mimeType = item.mime;
                base64 = String(stdout.text).trim();
                if (!base64) {
                    ToastService.showError("Failed to pin image");
                    return;
                }
                if ((base64.length * 3) / 4 > root.maxPinnedImageMb) {
                    ToastService.showWarning("Image too large to pin (max 5MB)");
                    return;
                }
                item.mime = mimeType;
                item.content = "data:" + mimeType + ";base64," + base64;
            } else {
                const text = String(stdout.text);
                if (text.length > root.maxPinnedTextMb) {
                    ToastService.showWarning("Text too large to pin (max 1MB)");
                    return;
                }
                item.content = text;
            }
            root.pinnedItems = [...root.pinnedItems, item];
            root.savePinnedFile();
            Quickshell.execDetached(root.useBuiltInDmsClipboard ? ["dms", "cl", "delete", String(item.cliphistId)] : ["cliphist", "delete", String(item.cliphistId)]);
            root.pinnedRevision++;
            ToastService.showInfo("Item pinned");
        }
    }

    function unpinItem(pinnedId) {
        if (root.useBuiltInDmsClipboard) {
            if (!pinnedId || !/^\d+$/.test(String(pinnedId))) {
                ToastService.showError("Invalid pinned item");
                return;
            }
            DMSService.sendRequest("clipboard.unpinEntry", {
                id: Number(pinnedId)
            }, function (response) {
                if (response?.error) {
                    ToastService.showError("Failed to unpin item");
                    return;
                }
                root.list();
                ToastService.showInfo("Item unpinned");
            });
            return;
        }
        root.pinnedItems = root.pinnedItems.filter(i => i.id !== pinnedId);
        root.savePinnedFile();
        root.pinnedRevision++;
        ToastService.showInfo("Item unpinned");
    }

    function deletePinnedItem(pinnedId) {
        if (root.useBuiltInDmsClipboard) {
            if (!pinnedId || !/^\d+$/.test(String(pinnedId))) {
                ToastService.showError("Invalid pinned item");
                return;
            }
            DMSService.sendRequest("clipboard.deleteEntry", {
                id: Number(pinnedId)
            }, function (response) {
                if (response?.error) {
                    ToastService.showError("Failed to delete pinned item");
                    return;
                }
                root.list();
                ToastService.showInfo("Pinned item deleted");
            });
            return;
        }
        root.pinnedItems = root.pinnedItems.filter(i => i.id !== pinnedId);
        root.savePinnedFile();
        root.pinnedRevision++;
        ToastService.showInfo("Item unpinned");
    }

    function copyPinnedToClipboard(pinnedId) {
        const item = root.pinnedItems.find(i => i.id === pinnedId);
        if (!item)
            return;
        if (item.isImage && item.content) {
            const matches = item.content.match(/^data:([^;]+);base64,(.+)$/);
            if (!matches) {
                ToastService.showError("Failed to copy image");
                return;
            }
            copyRawImage(matches[1], matches[2], false);
        } else {
            copyRawText(item.content || "", false);
        }
    }

    function savePinnedFile() {
        const base64 = Qt.btoa(JSON.stringify({
            items: root.pinnedItems
        }, null, 2));
        const filePath = clipboardPlusConfigDir + "/pinned.json";
        Quickshell.execDetached(["sh", "-c", `echo "${base64}" | base64 -d > "${filePath}"`]);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NOTE CARDS
    // ══════════════════════════════════════════════════════════════════════════

    function listNoteCardsIpc() {
        const list = Array.isArray(root.noteCards) ? root.noteCards : [];
        try {
            return JSON.stringify(list.map(n => ({
                        id: n.id,
                        title: n.title || "",
                        createdAt: n.createdAt || "",
                        lastModified: n.lastModified || ""
                    })));
        } catch (_) {
            return "[]";
        }
    }

    function loadNoteCards() {
        root.noteCardsLoaded = false;
        root.noteCardsLoadToken++;
        loadNoteCardsProc.loadToken = root.noteCardsLoadToken;
        const script = "cd '" + root.noteCardsDir + "' || { echo '[]'; exit 0; };\n" + "python3 - <<'PY'\n" + "import json, glob\n" + "notes = []\n" + "for path in sorted(glob.glob('*.json')):\n" + "  try:\n" + "    with open(path, 'r') as f:\n" + "      notes.append(json.load(f))\n" + "  except Exception:\n" + "    pass\n" + "print(json.dumps(notes))\n" + "PY";
        loadNoteCardsProc.command = ["bash", "-c", script];
        loadNoteCardsProc.running = true;
    }

    Process {
        id: loadNoteCardsProc
        property int loadToken: 0
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (loadToken !== root.noteCardsLoadToken)
                return;
            try {
                const output = String(stdout.text || "").trim();
                const loaded = (!output || output === "[]") ? [] : JSON.parse(output);
                root.noteCards = (Array.isArray(loaded) ? loaded : []).filter(n => !root.deletedNoteIds[String(n.id)]);
            } catch (_) {
                root.noteCards = [];
            }
            root.noteCardsRevision++;
            root.noteCardsLoaded = true;
        }
    }

    function createNoteCard(initialText) {
        if (root.noteCards.length >= maxNoteCards) {
            ToastService.showWarning(("Maximum {max} notes reached").replace("{max}", maxNoteCards));
            return null;
        }
        const timestamp = Date.now();
        const noteId = "note_" + timestamp + "_" + Math.random().toString(36).substring(2, 8);
        const offset = (root.noteCards.length % 10) * 30;
        const maxZ = root.noteCards.reduce((z, n) => Math.max(z, n.zIndex || 0), 0);
        const newNote = {
            id: noteId,
            title: "",
            content: initialText || "",
            isPrivate: false,
            x: 20 + offset,
            y: 80 + offset,
            width: 350,
            height: 280,
            zIndex: maxZ + 1,
            color: "yellow",
            createdAt: new Date().toISOString(),
            lastModified: new Date().toISOString()
        };
        root.noteCards = [...root.noteCards, newNote];
        root.noteCardsRevision++;
        root.noteCardsLoadToken++;
        saveNoteCard(newNote);
        ToastService.showInfo("Note created");
        return noteId;
    }

    function updateNoteCard(noteId, updates) {
        const index = root.noteCards.findIndex(n => n.id === noteId);
        if (index === -1)
            return;
        Object.assign(root.noteCards[index], updates, {
            lastModified: new Date().toISOString()
        });
        root.noteCardsRevision++;
        root.noteCardsLoadToken++;
        saveNoteCard(root.noteCards[index]);
    }

    function updateNoteCardInMemory(noteId, updates) {
        const index = root.noteCards.findIndex(n => n.id === noteId);
        if (index === -1)
            return;
        Object.assign(root.noteCards[index], updates, {
            lastModified: new Date().toISOString()
        });
        root.noteCardsRevision++;
        root.noteCardsLoadToken++;
    }

    function saveNoteCardById(noteId) {
        const note = root.noteCards.find(n => n.id === noteId);
        if (note)
            saveNoteCard(note);
    }

    function deleteNoteCard(noteId) {
        const note = root.noteCards.find(n => n.id === noteId);
        if (note) {
            root.deletedNoteIds[String(noteId)] = true;
            Quickshell.execDetached(["rm", "-f", root.noteCardsDir + "/" + getNoteFilename(note)]);
            const safePattern = /^notecard_\d{6}-\d{6}\.txt$/;
            (note.exportedFiles || []).forEach(f => {
                if (safePattern.test(f))
                    Quickshell.execDetached(["rm", "-f", root.exportBasePath + "/" + f]);
            });
        }
        root.noteCards = root.noteCards.filter(n => n.id !== noteId);
        root.noteCardsRevision++;
        root.noteCardsLoadToken++;
        ToastService.showInfo("Note deleted");
    }

    function clearAllNoteCards() {
        const safePattern = /^notecard_\d{6}-\d{6}\.txt$/;
        root.noteCards.forEach(note => {
            Quickshell.execDetached(["rm", "-f", root.noteCardsDir + "/" + getNoteFilename(note)]);
            (note.exportedFiles || []).forEach(f => {
                if (safePattern.test(f))
                    Quickshell.execDetached(["rm", "-f", root.exportBasePath + "/" + f]);
            });
        });
        root.noteCards = [];
        root.noteCardsRevision++;
        root.noteCardsLoadToken++;
        root.deletedNoteIds = ({});
        ToastService.showInfo("All notes cleared");
    }

    function exportNoteCard(noteId) {
        const note = root.noteCards.find(n => n.id === noteId);
        if (!note) {
            ToastService.showError("Note not found");
            return;
        }
        const now = new Date();
        const ts = now.getFullYear().toString().slice(-2) + String(now.getMonth() + 1).padStart(2, '0') + String(now.getDate()).padStart(2, '0') + "-" + String(now.getHours()).padStart(2, '0') + String(now.getMinutes()).padStart(2, '0') + String(now.getSeconds()).padStart(2, '0');
        const fileName = "notecard_" + ts + ".txt";
        const filePath = root.exportBasePath + "/" + fileName;
        Quickshell.execDetached(["mkdir", "-p", root.exportBasePath]);
        const title = (note.title || "").trim();
        const exportText = title.length > 0 ? (title + "\n---\n" + (note.content || "")) : (note.content || "");
        Quickshell.execDetached(["sh", "-c", `echo "${Qt.btoa(exportText)}" | base64 -d > "${filePath}"`]);
        root.updateNoteCard(noteId, {
            exportedFiles: [...(note.exportedFiles || []), fileName]
        });
        ToastService.showInfo(("Note exported to ~/Documents/{f}").replace("{f}", fileName));
    }

    function bringNoteToFront(noteId) {
        const index = root.noteCards.findIndex(n => n.id === noteId);
        if (index === -1)
            return;
        const maxZ = root.noteCards.reduce((z, n) => Math.max(z, n.zIndex || 0), 0);
        if (root.noteCards[index].zIndex < maxZ)
            root.updateNoteCard(noteId, {
                zIndex: maxZ + 1
            });
    }

    function appendTextToNoteCard(noteId, text) {
        const note = root.noteCards.find(n => n.id === noteId);
        if (!note) {
            ToastService.showError("Note not found");
            return;
        }
        const newContent = note.content ? note.content + "\n" + text : text;
        root.updateNoteCard(noteId, {
            content: newContent
        });
        ToastService.showInfo("Text added to note");
    }

    function getNoteFilename(note) {
        if (!note)
            return "untitled.json";
        return String(note.id || "untitled").replace(/[^a-zA-Z0-9-_]/g, '_') + ".json";
    }

    function saveNoteCard(note) {
        if (!note)
            return;
        const filePath = root.noteCardsDir + "/" + getNoteFilename(note);
        Quickshell.execDetached(["sh", "-c", `echo "${Qt.btoa(JSON.stringify(note, null, 2))}" | base64 -d > "${filePath}"`]);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // TODO
    // ══════════════════════════════════════════════════════════════════════════

    function ensureTodoData() {
        if (!Array.isArray(root.todoPages) || root.todoPages.length === 0)
            root.todoPages = [
                {
                    id: 1,
                    name: "Inbox"
                }
            ];
        if (!Array.isArray(root.todos))
            root.todos = [];
        return {
            pages: root.todoPages,
            todos: root.todos
        };
    }

    function saveTodoFile() {
        todoFile.setText(JSON.stringify({
            pages: root.todoPages,
            todos: root.todos
        }, null, 2));
    }

    function addTodoWithText(text, pageId) {
        if (!text?.length) {
            ToastService.showError("No text to add");
            return;
        }
        const normalizedText = text.substring(0, maxTodoTextLength).replace(/\s+/g, " ").trim();
        const store = ensureTodoData();
        const targetPageId = pageId || store.pages[0]?.id || 1;
        root.todos = [...store.todos,
            {
                id: Date.now(),
                text: normalizedText,
                completed: false,
                createdAt: new Date().toISOString(),
                pageId: targetPageId,
                priority: "medium",
                details: ""
            }
        ];
        root.todoRevision++;
        saveTodoFile();
        ToastService.showInfo("Added to ToDo");
        copyRawText(text, true);
    }

    function toggleTodo(todoId) {
        const idx = root.todos.findIndex(t => t.id === todoId);
        if (idx === -1)
            return;
        const newTodos = root.todos.slice();
        newTodos[idx] = Object.assign({}, root.todos[idx], {
            completed: !root.todos[idx].completed
        });
        root.todos = newTodos;
        root.todoRevision++;
        saveTodoFile();
    }

    function deleteTodo(todoId) {
        const idx = root.todos.findIndex(t => t.id === todoId);
        if (idx === -1)
            return;
        const newTodos = root.todos.slice();
        newTodos.splice(idx, 1);
        root.todos = newTodos;
        root.todoRevision++;
        saveTodoFile();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // TEXT FETCH HELPER
    // ══════════════════════════════════════════════════════════════════════════
    // source: "clipboard"
    // callback: function(text) — called only on non-empty success

    property var _fetchCallbacks: []

    function fetchTextThen(source, callback) {
        _fetchCallbacks.push(callback);
        fetchTextProc.command = root.useBuiltInDmsClipboard ? ["dms", "cl", "paste"] : ["wl-paste", "-n"];
        fetchTextProc.running = true;
    }

    Process {
        id: fetchTextProc
        stdout: StdioCollector {}
        onExited: exitCode => {
            const cb = root._fetchCallbacks.shift();
            if (exitCode !== 0 || !cb) {
                ToastService.showError("Failed to get text");
                return;
            }
            const text = String(stdout.text || "").trim();
            if (!text.length) {
                ToastService.showError("No text found");
                return;
            }
            cb(text);
        }
    }

    // ── Convenience wrappers kept for Panel.qml call-sites ────────────────────
    function getClipboardAndAddTodoImmediate() {
        fetchTextThen("clipboard", t => addTodoWithText(t, 0));
    }
    function getClipboardAndShowNoteSelector() {
        fetchTextThen("clipboard", t => {
            copyRawText(t, true);
            showSelector("notecard", t);
        });
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SELECTORS  (todo page / note card)
    // ══════════════════════════════════════════════════════════════════════════

    // Unified entry point
    function showSelector(type, text) {
        root.activeSelector = type;
        if (type === "todo") {
            root.pendingSelectedText = text;
            todoPageSelector?.show(text, ensureTodoData().pages);
        } else {
            root.pendingNoteCardText = text;
            root.loadNoteCards();
            Qt.callLater(() => noteCardSelector?.show(text, root.noteCards));
        }
    }

    // Keep legacy name working
    function showTodoPageSelector(text) {
        showSelector("todo", text);
    }
    function showNoteCardSelector(text) {
        showSelector("notecard", text);
    }

    function handleTodoPageSelected(pageId, pageName) {
        if (root.pendingSelectedText) {
            root.addTodoWithText(root.pendingSelectedText, pageId);
            root.pendingSelectedText = "";
        }
    }

    function handleNoteCardSelected(noteId, noteTitle) {
        if (root.pendingNoteCardText) {
            root.appendTextToNoteCard(noteId, root.pendingNoteCardText);
            root.pendingNoteCardText = "";
        }
    }

    function handleCreateNewTodoPage() {
        if (!root.pendingSelectedText)
            return;
        const store = ensureTodoData();
        const pageId = Date.now();
        const pageName = root.pendingSelectedText.substring(0, 24) || "New Page";
        root.todoPages = [...store.pages,
            {
                id: pageId,
                name: pageName
            }
        ];
        root.todoRevision++;
        saveTodoFile();
        root.addTodoWithText(root.pendingSelectedText, pageId);
        ToastService.showInfo("New ToDo page created");
        root.pendingSelectedText = "";
    }

    function handleCreateNewNoteFromSelection() {
        if (root.pendingNoteCardText) {
            root.createNoteCard(root.pendingNoteCardText);
            root.pendingNoteCardText = "";
        }
    }

    // ── Selector UI instances ─────────────────────────────────────────────────
    property var selectionMenu: null

    Variants {
        model: Quickshell.screens
        delegate: SelectionContextMenu {
            required property var modelData
            screen: modelData
            pluginApi: root.pluginApi
            Component.onCompleted: {
                if (!root.selectionMenu)
                    root.selectionMenu = this;
            }
            onItemSelected: action => {
                if (root.activeSelector === "notecard")
                    root.noteCardSelector?.handleItemSelected(action);
                else if (root.activeSelector === "todo")
                    root.todoPageSelector?.handleItemSelected(action);
            }
            onCancelled: {
                root.pendingSelectedText = "";
                root.pendingNoteCardText = "";
            }
        }
    }

    property var noteCardSelector: NoteCardSelector {
        pluginApi: root.pluginApi
        selectionMenu: root.selectionMenu
        onNoteSelected: (id, title) => root.handleNoteCardSelected(id, title)
        onCreateNewNote: () => root.handleCreateNewNoteFromSelection()
    }

    property var todoPageSelector: TodoPageSelector {
        pluginApi: root.pluginApi
        selectionMenu: root.selectionMenu
        onPageSelected: (pageId, pageName) => root.handleTodoPageSelected(pageId, pageName)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // AUTO-PASTE
    // ══════════════════════════════════════════════════════════════════════════

    Process {
        id: wtypeCheckProc
        command: ["which", "wtype"]
        running: true
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            root.wtypeAvailable = (exitCode === 0);
        }
    }

    Timer {
        id: autoPasteTimer
        interval: pluginApi?.pluginSettings?.autoPasteDelay ?? 300
        repeat: false
        onTriggered: {
            if (root.wtypeAvailable)
                autoPasteProc.running = true;
            else
                Logger.w("ClipBoard+", "Auto-paste failed: wtype not found. Install with: sudo pacman -S wtype");
        }
    }

    Process {
        id: autoPasteProc
        command: ["wtype", "-M", "ctrl", "-M", "shift", "v"]
        onExited: exitCode => {
            if (exitCode !== 0)
                Logger.w("ClipBoard+", "wtype auto-paste exited with code: " + exitCode);
        }
    }

    function triggerAutoPaste() {
        autoPasteTimer.restart();
    }

    function queueAutoPasteAfterCopy() {
        root.autoPasteAfterNextCopy = true;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // TYPE DETECTION
    // ══════════════════════════════════════════════════════════════════════════

    function getItemType(item) {
        if (!item)
            return "Text";
        if (item.isImage)
            return "Image";

        const preview = item.preview || "";
        const trimmed = preview.trim();

        // Color
        if (/^#[A-Fa-f0-9]{6}([A-Fa-f0-9]{2})?$/.test(trimmed))
            return "Color";
        if (/^#[A-Fa-f0-9]{3}$/.test(trimmed))
            return "Color";
        if (/^[A-Fa-f0-9]{6}$/.test(trimmed))
            return "Color";
        if (/^rgba?\s*\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*[\d.]+\s*)?\)$/i.test(trimmed))
            return "Color";

        // Link
        if (/^https?:\/\//.test(trimmed))
            return "Link";

        // Code — must come before File so `// comment` doesn't match `^/`
        if (/^(\/\/|\/\*|#!|\*|<!--)/.test(trimmed))
            return "Code";
        if (/\b(function|import|export|const|let|var|class|def|return|if|else|for|while|async|await)\b/.test(preview))
            return "Code";
        if (/^[\{\[\(]/.test(trimmed))
            return "Code";

        // Emoji
        if (trimmed.length <= 4 && trimmed.length > 0 && trimmed.charCodeAt(0) > 255)
            return "Emoji";

        // File path
        if (/^file:\/\//.test(trimmed))
            return "File";
        if (/^~\//.test(trimmed))
            return "File";
        if ((/^\/[^\s/]/.test(trimmed) && !trimmed.includes(" ")) || (/^\/[^\s]+\//.test(trimmed) && (trimmed.match(/\//g) || []).length >= 2))
            return "File";

        return "Text";
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    function refreshOnPanelOpen() {
        root.list();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.clipboardPlusConfigDir]);
        Quickshell.execDetached(["mkdir", "-p", root.noteCardsDir]);

        // Create empty pinned.json if missing
        Quickshell.execDetached(["sh", "-c", `[ -f "${clipboardPlusConfigDir}/pinned.json" ] || echo '{"items":[]}' > "${clipboardPlusConfigDir}/pinned.json"`]);

        pinnedFile.reload();
        todoFile.reload();
        loadNoteCards();
        list();
    }

    Component.onDestruction: {
        const procs = [listProc, decodeProc, copyRawTextProc, copyRawImageProc, imageDecodeProc, fetchTextProc, copyDecodeProc, deleteItemProc, wipeProc, loadNoteCardsProc, wtypeCheckProc, autoPasteProc, textDecodeProc];
        procs.forEach(p => {
            if (p.running)
                p.terminate();
        });
        autoPasteTimer.stop();
        pinnedItems = [];
        noteCards = [];
        items = [];
        firstSeenById = {};
        imageCache = {};
        imageCacheOrder = [];
    }
}
