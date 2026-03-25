import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Item {
  id: root
  property var pluginApi: null
  property bool panelVisible: false

  // Auto-paste support
  property bool wtypeAvailable: false

  // Watch for pluginApi changes and initialize settings
  onPluginApiChanged: {
    if (pluginApi) {
    }
  }

  // Pending selected text for ToDo selector
  property string pendingSelectedText: ""

  // Pinned items data
  property var pinnedItems: []
  property int pinnedRevision: 0

  // Note cards data
  property var noteCards: []
  property int noteCardsRevision: 0
  property bool noteCardsLoaded: false
  property int noteCardsLoadToken: 0
  property var deletedNoteIds: ({})

  // Clipboard items from cliphist
  property var items: []
  property bool loading: false
  property var firstSeenById: ({})

  // Image cache (id -> data URL) with LRU eviction
  property var imageCache: ({})
  property var imageCacheOrder: []  // Track insertion order for LRU
  property int imageCacheRevision: 0  // Incremented when cache changes (for reactive bindings)
  readonly property int maxImageCacheSize: 50  // Limit cache to 50 entries

  // Pending pageId for async operations (ToDo integration)
  property int pendingPageId: 0

  // Constants for limits
  readonly property int maxPinnedItems: 100 // Maximum number of pinned items
  readonly property int maxNoteCards: 50      // Maximum number of note cards
  readonly property int maxTodoTextLength: 500      // Maximum text length for ToDo items
  readonly property int maxPinnedTextMb: Math.max(1, Math.floor(pluginApi?.pluginSettings?.maxPinnedTextMb ?? 1)) * 1024 * 1024
  readonly property int maxPinnedImageMb: Math.max(5, Math.floor(pluginApi?.pluginSettings?.maxPinnedImageMb ?? 5)) * 1024 * 1024
  readonly property int maxPreviewImageSize: maxPinnedImageMb

  // Config root for DMS (override via settings)
  readonly property string defaultConfigRoot: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dms-clipboardPlus"
  readonly property string configRoot: {
    const custom = pluginApi?.pluginSettings?.dataBasePath;
    return (custom && String(custom).trim().length > 0) ? custom : defaultConfigRoot;
  }
  readonly property string clipboardPlusConfigDir: configRoot + "/data"
  readonly property string exportBasePath: {
    const custom = pluginApi?.pluginSettings?.exportPath;
    return (custom && String(custom).trim().length > 0)
        ? custom
        : (Quickshell.env("HOME") + "/Documents");
  }

  // FileView for pinned.json
  FileView {
    id: pinnedFile
    path: clipboardPlusConfigDir + "/pinned.json"
    watchChanges: true
    printErrors: false

    onLoaded: {
      try {
        const data = JSON.parse(text());
        root.pinnedItems = data.items || [];
        root.pinnedRevision++;
      } catch (e) {
        root.pinnedItems = [];
      }
    }

    onLoadFailed: {
      root.pinnedItems = [];
      root.pinnedRevision++;
    }
  }

  // NoteCards directory path (per-note JSON files)
  readonly property string noteCardsDir: clipboardPlusConfigDir + "/notecards"

  // Process to load all notecards from directory (jq aggregates JSON files)
  Process {
    id: loadNoteCardsProc
    property int loadToken: 0
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      if (loadToken !== root.noteCardsLoadToken) {
        return;
      }
      if (exitCode !== 0) {
        root.noteCards = [];
        root.noteCardsRevision++;
        root.noteCardsLoaded = true;
        return;
      }

      try {
        const output = String(stdout.text || "").trim();
        if (!output || output === "[]") {
          root.noteCards = [];
          root.noteCardsRevision++;
          root.noteCardsLoaded = true;
          return;
        }

        const loadedNotes = JSON.parse(output);
        const list = Array.isArray(loadedNotes) ? loadedNotes : [];
        root.noteCards = list.filter(n => !root.deletedNoteIds[String(n.id)]);
        root.noteCardsRevision++;
        root.noteCardsLoaded = true;
      } catch (e) {
        root.noteCards = [];
        root.noteCardsRevision++;
        root.noteCardsLoaded = true;
      }
    }
  }

  // ToDo storage (json file)
  property var todoPages: []
  property var todos: []
  property int todoRevision: 0

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
      } catch (e) {
        const lastBrace = raw.lastIndexOf("}");
        if (lastBrace !== -1) {
          const trimmed = raw.slice(0, lastBrace + 1);
          try {
            parsed = JSON.parse(trimmed);
            repaired = true;
          } catch (e2) {
            parsed = null;
          }
        }
      }

      const data = parsed || {};
      const pages = data.pages || [];
      const items = data.todos || [];
      root.todoPages = pages.length > 0 ? pages : [{ id: 1, name: "Inbox" }];
      root.todos = Array.isArray(items) ? items : [];
      root.todoRevision++;
      if (repaired) {
        root.saveTodoFile();
      }
    }

    onLoadFailed: error => {
      if (error === 2) {
        root.todoPages = [{ id: 1, name: "Inbox" }];
        root.todos = [];
        root.todoRevision++;
        root.saveTodoFile();
      }
    }
  }

  // Function to load all notecards
  function loadNoteCards() {
    root.noteCardsLoaded = false;
    root.noteCardsLoadToken++;
    loadNoteCardsProc.loadToken = root.noteCardsLoadToken;
    const script =
      "cd '" + root.noteCardsDir + "' || { echo '[]'; exit 0; };\n" +
      "python3 - <<'PY'\n" +
      "import json, glob\n" +
      "notes = []\n" +
      "for path in sorted(glob.glob('*.json')):\n" +
      "  try:\n" +
      "    with open(path, 'r') as f:\n" +
      "      notes.append(json.load(f))\n" +
      "  except Exception:\n" +
      "    pass\n" +
      "print(json.dumps(notes))\n" +
      "PY";
    loadNoteCardsProc.command = ["bash", "-c", script];
    loadNoteCardsProc.running = true;
  }

  // Helper function to add to image cache with LRU eviction
  function addToImageCache(cliphistId, dataUrl) {
    // Remove from order if already exists (will re-add at end)
    const existingIndex = root.imageCacheOrder.indexOf(cliphistId);
    if (existingIndex !== -1) {
      root.imageCacheOrder = root.imageCacheOrder.filter((_, i) => i !== existingIndex);
    }

    // Evict oldest entries if at capacity
    while (root.imageCacheOrder.length >= maxImageCacheSize) {
      const oldestKey = root.imageCacheOrder[0];
      root.imageCacheOrder = root.imageCacheOrder.slice(1);
      const newCache = Object.assign({}, root.imageCache);
      delete newCache[oldestKey];
      root.imageCache = newCache;
    }

    // Add new entry
    root.imageCache = Object.assign({}, root.imageCache, {
                                      [cliphistId]: dataUrl
                                    });
    root.imageCacheOrder = [...root.imageCacheOrder, cliphistId];
    root.imageCacheRevision++;
  }

  // Clear caches (called on wipe)
  function clearCaches() {
    root.imageCache = {};
    root.imageCacheOrder = [];
    root.imageCacheRevision++;
    root.firstSeenById = {};
  }

  // Shared item type detection (used by Panel and ClipboardCard)
  function getItemType(item) {
    if (!item)
      return "Text";
    if (item.isImage)
      return "Image";

    const preview = item.preview || "";
    const trimmed = preview.trim();

    // Color detection
    if (/^#[A-Fa-f0-9]{6}([A-Fa-f0-9]{2})?$/.test(trimmed))
      return "Color";
    if (/^#[A-Fa-f0-9]{3}$/.test(trimmed))
      return "Color";
    if (/^[A-Fa-f0-9]{6}$/.test(trimmed))
      return "Color";
    if (/^rgba?\s*\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*[\d.]+\s*)?\)$/i.test(trimmed))
      return "Color";

    // Link detection
    if (/^https?:\/\//.test(trimmed))
      return "Link";

    // Code detection — before file, so `// comment` and `{ }` don't get misclassified
    if (/^(\/\/|\/\*|#!|\*|<!--)/.test(trimmed))
      return "Code";
    if (/\b(function|import|export|const|let|var|class|def|return|if|else|for|while|async|await)\b/.test(preview))
      return "Code";
    if (/^[\{\[\(]/.test(trimmed))
      return "Code";

    // Emoji detection
    if (trimmed.length <= 4 && trimmed.length > 0 && trimmed.charCodeAt(0) > 255)
      return "Emoji";

    // File path detection — must look like an actual path, not a comment or sentence
    // Reject if it contains spaces before the first slash's path segment,
    // or looks like it has natural language / operators mixed in
    if (/^file:\/\//.test(trimmed))
      return "File";
    if (/^~\//.test(trimmed))
      return "File";
    if (/^\/[^\s/]/.test(trimmed) && !trimmed.includes(" ") || /^\/[^\s]+\//.test(trimmed) && (trimmed.match(/\//g) || []).length >= 2)
      return "File";

    return "Text";
  }

  // Process to list cliphist items
  Process {
    id: listProc
    stdout: StdioCollector {}

    onExited: exitCode => {
                if (exitCode !== 0) {
                  root.items = [];
                  root.loading = false;
                  return;
                }

                const out = String(stdout.text);
                const lines = out.split('\n').filter(l => l.length > 0);

                const parsed = lines.map(l => {
                                           let id = "";
                                           let preview = "";
                                           const m = l.match(/^(\d+)\s+(.+)$/);
                                           if (m) {
                                             id = m[1];
                                             preview = m[2];
                                           } else {
                                             const tab = l.indexOf('\t');
                                             id = tab > -1 ? l.slice(0, tab) : l;
                                             preview = tab > -1 ? l.slice(tab + 1) : "";
                                           }

                                           const lower = preview.toLowerCase();
                                           const isImage = lower.startsWith("[image]") || lower.includes(" binary data ");

                                           var mime = "text/plain";
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

                                           if (!root.firstSeenById[id]) {
                                             root.firstSeenById[id] = Date.now();
                                           }

                                           return {
                                             "id": id,
                                             "preview": preview,
                                             "isImage": isImage,
                                             "mime": mime
                                           };
                                         });

                root.items = parsed;
                root.loading = false;
              }
  }

  // Function to pin item - use preview from items list
  function pinItem(cliphistId) {
    // Validate cliphistId is numeric only (prevents command injection)
    if (!cliphistId || !/^\d+$/.test(String(cliphistId))) {
      ToastService.showError(pluginApi?.tr("toast.invalid-clipboard-item") || "Invalid clipboard item");
      return;
    }

    if (root.pinnedItems.length >= maxPinnedItems) {
      ToastService.showWarning((pluginApi?.tr("toast.max-pinned-items") || "Maximum {max} pinned items reached").replace("{max}", maxPinnedItems));
      return;
    }

    // Find item in current items list to get preview
    const item = root.items.find(i => i.id === cliphistId);
    if (!item) {
      ToastService.showError(pluginApi?.tr("toast.item-not-found") || "Item not found in clipboard");
      return;
    }

    const pinnedId = "pinned-" + Date.now() + "-" + cliphistId;

    const newItem = {
      id: pinnedId,
      cliphistId: cliphistId,  // Keep original ID for image decode
      content: "",  // Will be filled for text items
      preview: item.preview,  // Use preview from list
      mime: item.mime || "text/plain",
      isImage: item.isImage || false,
      pinnedAt: Date.now()
    };

    // Decode content (text or image data)
    decodeProc.cliphistId = cliphistId;
    decodeProc.pinnedItem = newItem;

    if (newItem.isImage) {
      // For images, pipe through base64 to avoid binary corruption
      decodeProc.command = ["sh", "-c", `cliphist decode ${cliphistId} | base64 -w 0`];
    } else {
      // For text, direct decode
      decodeProc.command = ["cliphist", "decode", String(cliphistId)];
    }
    decodeProc.running = true;
  }

  // Process to decode content for pinning
  Process {
    id: decodeProc
    property string cliphistId: ""
    property var pinnedItem: null
    stdout: StdioCollector {}

    onExited: exitCode => {
                if (exitCode !== 0) {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-pin") || "Failed to pin item");
                  return;
                }

                if (pinnedItem.isImage) {
                  // For images, stdout.text contains base64-encoded data
                  const base64 = String(stdout.text).trim();
                  if (!base64 || base64.length === 0) {
                    ToastService.showError(pluginApi?.tr("toast.failed-to-pin-image") || "Failed to pin image");
                    return;
                  }

                  // Validate image size (approximate: base64 is ~33% larger)
                  const estimatedSize = (base64.length * 3) / 4;
                  if (estimatedSize > root.maxPinnedImageMb) {
                    ToastService.showWarning(pluginApi?.tr("toast.image-too-large") || "Image too large to pin (max 5MB)");
                    return;
                  }

                  const dataUrl = "data:" + pinnedItem.mime + ";base64," + base64;
                  pinnedItem.content = dataUrl;
                } else {
                  // For text, validate size (max 1MB)
                  const textContent = String(stdout.text);
                  if (textContent.length > root.maxPinnedTextMb) {
                    ToastService.showWarning(pluginApi?.tr("toast.text-too-large") || "Text too large to pin (max 1MB)");
                    return;
                  }

                  pinnedItem.content = textContent;
                }

                // Add to array
                root.pinnedItems = [...root.pinnedItems, pinnedItem];

                // Save to file
                root.savePinnedFile();

                // Delete from cliphist
                Quickshell.execDetached(["cliphist", "delete", String(cliphistId)]);

                root.pinnedRevision++;
                ToastService.showInfo(pluginApi?.tr("toast.item-pinned") || "Item pinned");
              }
  }

  // Function to save pinned items to file
  function savePinnedFile() {
    const data = {
      items: root.pinnedItems
    };
    const json = JSON.stringify(data, null, 2);

    // Use base64 encoding to safely pass JSON through shell
    // Qt.btoa() produces valid base64 (A-Z, a-z, 0-9, +, /, =) - no shell metacharacters
    // File path is constant, not user-controlled
    const base64 = Qt.btoa(json);
    const filePath = clipboardPlusConfigDir + "/pinned.json";

    Quickshell.execDetached(["sh", "-c", `echo "${base64}" | base64 -d > "${filePath}"`]);
  }

  // Function to unpin item
  function unpinItem(pinnedId) {
    root.pinnedItems = root.pinnedItems.filter(item => item.id !== pinnedId);
    root.savePinnedFile();
    root.pinnedRevision++;
    ToastService.showInfo(pluginApi?.tr("toast.item-unpinned") || "Item unpinned");
  }

  // ==================== SCRATCHPAD FUNCTIONS ====================

  // Function to create a new scratchpad note
  function createNoteCard(initialText) {
    if (root.noteCards.length >= maxNoteCards) {
      ToastService.showWarning((pluginApi?.tr("toast.max-notes") || "Maximum {max} notes reached").replace("{max}", maxNoteCards));
      return null;
    }

    const timestamp = Date.now();
    const randomSuffix = Math.random().toString(36).substring(2, 8);
    const noteId = "note_" + timestamp + "_" + randomSuffix;

    // Cascade positioning: offset by 30px for each new note
    const cascadeOffset = (root.noteCards.length % 10) * 30;
    const baseX = 20 + cascadeOffset;
    const baseY = 80 + cascadeOffset;

    // Find highest z-index
    let maxZ = 0;
    for (let i = 0; i < root.noteCards.length; i++) {
      if (root.noteCards[i].zIndex > maxZ) {
        maxZ = root.noteCards[i].zIndex;
      }
    }

    const newNote = {
      id: noteId,
      title: "",
      content: initialText || "",
      x: baseX,
      y: baseY,
      width: 350,
      height: 280,
      zIndex: maxZ + 1,
      color: "yellow",
      createdAt: new Date().toISOString(),
      lastModified: new Date().toISOString()
    };

    // Immutable array update
    const newNotes = root.noteCards.slice();
    newNotes.push(newNote);
    root.noteCards = newNotes;
    root.noteCardsRevision++;
    root.noteCardsLoadToken++;

    // Save to file
    saveNoteCard(newNote);

    ToastService.showInfo(pluginApi?.tr("toast.note-created") || "Note created");
    return noteId;
  }

  // Function to update a note card
  function updateNoteCard(noteId, updates) {
    const index = root.noteCards.findIndex(n => n.id === noteId);
    if (index === -1) {
      return;
    }

    const note = root.noteCards[index];
    Object.assign(note, updates, {
      lastModified: new Date().toISOString()
    });
    root.noteCardsRevision++;
    root.noteCardsLoadToken++;

    // Save to file
    saveNoteCard(note);
  }

  // Update note data in memory only (no disk write)
  function updateNoteCardInMemory(noteId, updates) {
    const index = root.noteCards.findIndex(n => n.id === noteId);
    if (index === -1) {
      return;
    }

    const note = root.noteCards[index];
    Object.assign(note, updates, {
      lastModified: new Date().toISOString()
    });
    root.noteCardsRevision++;
    root.noteCardsLoadToken++;
  }

  function saveNoteCardById(noteId) {
    const note = root.noteCards.find(n => n.id === noteId);
    if (!note)
      return;
    saveNoteCard(note);
  }

  // Function to delete a note card
  function deleteNoteCard(noteId) {
    const note = root.noteCards.find(n => n.id === noteId);
    if (note) {
      root.deletedNoteIds[String(noteId)] = true;
      const filename = getNoteFilename(note);
      const filePath = root.noteCardsDir + "/" + filename;
      Quickshell.execDetached(["rm", "-f", filePath]);

      // Delete all exported .txt files - validate each filename before deletion
      const safePattern = /^notecard_\d{6}-\d{6}\.txt$/;
      const exportedFiles = note.exportedFiles || [];
      for (let i = 0; i < exportedFiles.length; i++) {
        if (safePattern.test(exportedFiles[i])) {
          const exportedPath = root.exportBasePath + "/" + exportedFiles[i];
          Quickshell.execDetached(["rm", "-f", exportedPath]);
        }
      }
    }

    root.noteCards = root.noteCards.filter(n => n.id !== noteId);
    root.noteCardsRevision++;
    root.noteCardsLoadToken++;
    ToastService.showInfo(pluginApi?.tr("toast.note-deleted") || "Note deleted");
  }

  // Function to clear all note cards and delete files from disk
  function clearAllNoteCards() {
    const safePattern = /^notecard_\d{6}-\d{6}\.txt$/;
    for (let i = 0; i < root.noteCards.length; i++) {
      const note = root.noteCards[i];

      // Delete the .json notecard file from notecards directory
      const filename = getNoteFilename(note);
      const filePath = root.noteCardsDir + "/" + filename;
      Quickshell.execDetached(["rm", "-f", filePath]);

      // Delete any exported .txt files
      const exportedFiles = note.exportedFiles || [];
      for (let j = 0; j < exportedFiles.length; j++) {
        if (safePattern.test(exportedFiles[j])) {
          const exportedPath = root.exportBasePath + "/" + exportedFiles[j];
          Quickshell.execDetached(["rm", "-f", exportedPath]);
        }
      }
    }

    root.noteCards = [];
    root.noteCardsRevision++;
    root.noteCardsLoadToken++;
    root.deletedNoteIds = ({});
    ToastService.showInfo(pluginApi?.tr("toast.notes-cleared") || "All notes cleared");
  }

  // Function to export scratchpad note to .txt file
  function exportNoteCard(noteId) {
    const note = root.noteCards.find(n => n.id === noteId);
    if (!note) {
      ToastService.showError(pluginApi?.tr("toast.note-not-found") || "Note not found");
      return;
    }

    const now = new Date();
    const timestamp = now.getFullYear().toString().slice(-2) + String(now.getMonth() + 1).padStart(2, '0') + String(now.getDate()).padStart(2, '0') + "-" + String(now.getHours()).padStart(2, '0') + String(now.getMinutes()).padStart(2, '0') + String(now.getSeconds()).padStart(2, '0');
    const fileName = "notecard_" + timestamp + ".txt";
    const filePath = root.exportBasePath + "/" + fileName;
    Quickshell.execDetached(["mkdir", "-p", root.exportBasePath]);

    // Use base64 encoding to safely pass content through shell
    const title = (note.title || "").trim();
    const body = note.content || "";
    const exportText = title.length > 0 ? (title + "\n---\n" + body) : body;
    const base64 = Qt.btoa(exportText);
    Quickshell.execDetached(["sh", "-c", `echo "${base64}" | base64 -d > "${filePath}"`]);

    // Store exported filename - append to list so all exports are tracked
    const existingExports = note.exportedFiles || [];
    root.updateNoteCard(noteId, {
                          exportedFiles: [...existingExports, fileName]
                        });

    ToastService.showInfo((pluginApi?.tr("toast.note-exported") || "Note exported to ~/Documents/{fileName}").replace("{fileName}", fileName));
  }

  // Helper function to generate safe filename from note id (stable)
  function getNoteFilename(note) {
    if (!note) {
      return "untitled.json";
    }

    let safeId = String(note.id || "untitled");
    safeId = safeId.replace(/[^a-zA-Z0-9-_]/g, '_');
    return safeId + ".json";
  }

  // Function to save individual notecard to file (per-note JSON)
  function saveNoteCard(note) {
    if (!note)
      return;
    const filename = getNoteFilename(note);
    const filePath = root.noteCardsDir + "/" + filename;
    const json = JSON.stringify(note, null, 2);
    const base64 = Qt.btoa(json);
    Quickshell.execDetached(["sh", "-c", `echo "${base64}" | base64 -d > "${filePath}"`]);
  }

  // Function to bring note to front (update z-index)
  function bringNoteToFront(noteId) {
    const index = root.noteCards.findIndex(n => n.id === noteId);
    if (index === -1)
      return;

    // Find highest z-index
    let maxZ = 0;
    for (let i = 0; i < root.noteCards.length; i++) {
      if (root.noteCards[i].zIndex > maxZ) {
        maxZ = root.noteCards[i].zIndex;
      }
    }

    // Only update if not already at front
    if (root.noteCards[index].zIndex < maxZ) {
      root.updateNoteCard(noteId, {
                            zIndex: maxZ + 1
                          });
    }
  }

  // Process for copying pinned images to clipboard
  Process {
    id: copyPinnedImageProc
    command: ["wl-copy"]
    running: false
    stdinEnabled: true

    onExited: exitCode => {
                if (exitCode === 0) {
                  ToastService.showInfo(pluginApi?.tr("toast.copied-to-clipboard") || "Copied to clipboard");
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-copy-image") || "Failed to copy image");
                }
                stdinEnabled = true;  // Re-enable for next use
              }
  }

  // Process for copying pinned text to clipboard
  Process {
    id: copyPinnedTextProc
    command: ["wl-copy", "--"]
    running: false
    stdinEnabled: true

    onExited: exitCode => {
                if (exitCode === 0) {
                  ToastService.showInfo(pluginApi?.tr("toast.copied-to-clipboard") || "Copied to clipboard");
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-copy-text") || "Failed to copy text");
                }
                stdinEnabled = true;  // Re-enable for next use
              }
  }

  // Function to copy pinned item to clipboard
  function copyPinnedToClipboard(pinnedId) {
    const item = root.pinnedItems.find(i => i.id === pinnedId);
    if (!item) {
      return;
    }

    if (item.isImage && item.content) {
      // For images, decode base64 and copy binary data
      // Extract base64 from data URL: data:image/png;base64,iVBORw0K...
      const matches = item.content.match(/^data:([^;]+);base64,(.+)$/);
      if (!matches) {
        ToastService.showError(pluginApi?.tr("toast.failed-to-copy-image") || "Failed to copy image");
        return;
      }

      const mimeType = matches[1];
      const base64Data = matches[2];

      // Decode base64 to binary in JavaScript (no shell commands)
      const binaryStr = Qt.atob(base64Data);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }

      // Copy binary data directly via Process stdin
      copyPinnedImageProc.running = true;
      copyPinnedImageProc.write(bytes);
      copyPinnedImageProc.stdinEnabled = false;  // Close stdin to signal EOF
    } else {
      // For text, copy via Process stdin (no shell interpolation)
      copyPinnedTextProc.running = true;
      copyPinnedTextProc.write(item.content || "");
      copyPinnedTextProc.stdinEnabled = false;  // Close stdin to signal EOF
    }
  }

  // Image handling functions
  function getImageData(cliphistId) {
    return root.imageCache[cliphistId] || "";
  }

  function decodeToDataUrl(cliphistId, mimeType, callback) {
    // Validate cliphistId is numeric only (prevents command injection)
    if (!cliphistId || !/^\d+$/.test(String(cliphistId))) {
      return;
    }

    // Check cache first
    if (root.imageCache[cliphistId]) {
      if (callback)
        callback(root.imageCache[cliphistId]);
      return;
    }

    // Decode and encode to base64 in one shell command (like official ClipboardService)
    imageDecodeProc.cliphistId = cliphistId;
    imageDecodeProc.mimeType = mimeType || "image/png";
    imageDecodeProc.callback = callback;
    // Use shell to pipe: cliphist decode ID | base64 -w 0
    imageDecodeProc.command = ["sh", "-c", `cliphist decode ${cliphistId} | base64 -w 0`];
    imageDecodeProc.running = true;
  }

  // Process to decode image from cliphist and encode to base64
  Process {
    id: imageDecodeProc
    property string cliphistId: ""
    property string mimeType: "image/png"
    property var callback: null
    stdout: StdioCollector {}

    onExited: exitCode => {
                if (exitCode !== 0) {
                  return;
                }

                // Read base64-encoded text output
                const base64 = String(stdout.text).trim();
                if (!base64 || base64.length === 0) {
                  return;
                }

                // Validate size (approximate: base64 is ~33% larger than binary)
                const estimatedSize = (base64.length * 3) / 4;
                if (estimatedSize > maxPreviewImageSize) {
                  return;
                }

                const dataUrl = "data:" + mimeType + ";base64," + base64;

                // Cache it with LRU eviction
                root.addToImageCache(cliphistId, dataUrl);

                if (callback)
                callback(dataUrl);
              }
  }

  // Process to get selected text (primary selection) - for ToDo integration
  Process {
    id: getSelectionProcess
    command: ["wl-paste", "-p", "-n"]
    stdout: StdioCollector {
      id: selectionStdout
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                  const selectedText = selectionStdout.text.trim();
                  if (selectedText && selectedText.length > 0) {
                    root.addTodoWithText(selectedText, root.pendingPageId);
                  } else {
                    ToastService.showError(pluginApi?.tr("toast.no-text-selected") || "No text selected");
                  }
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-get-selection") || "Failed to get selection");
                }
              }
  }

  function ensureTodoData() {
    if (!Array.isArray(root.todoPages) || root.todoPages.length === 0) {
      root.todoPages = [{ id: 1, name: "Inbox" }];
    }
    if (!Array.isArray(root.todos)) {
      root.todos = [];
    }
    return {
      pages: root.todoPages,
      todos: root.todos
    };
  }

  function saveTodoFile() {
    const data = {
      pages: root.todoPages,
      todos: root.todos
    };
    const json = JSON.stringify(data, null, 2);
    todoFile.setText(json);
  }

  // Add todo with text to specified page (stored in ClipBoard+ settings)
  function addTodoWithText(text, pageId) {
    if (!text || text.length === 0) {
      ToastService.showError(pluginApi?.tr("toast.no-text-to-add") || "No text to add");
      return;
    }

    const trimmedText = text.substring(0, maxTodoTextLength);
    const normalizedText = trimmedText.replace(/\s+/g, " ").trim();
    const store = ensureTodoData();
    const targetPageId = pageId || (store.pages[0] ? store.pages[0].id : 1);

    var newTodo = {
      id: Date.now(),
      text: normalizedText,
      completed: false,
      createdAt: new Date().toISOString(),
      pageId: targetPageId,
      priority: "medium",
      details: ""
    };

    const newTodos = store.todos.slice();
    newTodos.push(newTodo);
    root.todos = newTodos;
    root.todoRevision++;
    saveTodoFile();

    ToastService.showInfo(pluginApi?.tr("toast.added-to-todo") || "Added to ToDo");

    // Also copy to clipboard
    Quickshell.execDetached(["wl-copy", "--", text]);
  }

  function toggleTodo(todoId) {
    const idx = root.todos.findIndex(t => t.id === todoId);
    if (idx === -1)
      return;
    const updated = Object.assign({}, root.todos[idx], {
      completed: !root.todos[idx].completed
    });
    const newTodos = root.todos.slice();
    newTodos[idx] = updated;
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

  // Process for copying to clipboard (direct pipe: cliphist decode | wl-copy)
  Process {
    id: copyToClipboardProc
    property string clipboardId: ""
    stdout: StdioCollector {}

    onExited: exitCode => {
                if (exitCode !== 0) {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-copy") || "Failed to copy to clipboard");
                }
              }
  }

  // Poll clipboard text while panel is visible (widget-safe)
  property string lastClipboardText: ""

  Timer {
    id: clipboardPollTimer
    interval: 500
    repeat: true
    running: root.panelVisible && (pluginApi?.pluginSettings?.listenClipboardWhileOpen ?? false)
    onTriggered: {
      if (!clipboardPollProc.running) {
        clipboardPollProc.running = true;
      }
    }
  }

  Process {
    id: clipboardPollProc
    command: ["wl-paste", "-n", "-t", "text"]
    stdout: StdioCollector {}
    onExited: exitCode => {
      if (exitCode !== 0) return;
      const text = String(stdout.text || "");
      if (text !== root.lastClipboardText) {
        root.lastClipboardText = text;
        root.list();
      }
    }
  }

  // Clipboard management functions
  function list(maxPreviewWidth) {
    if (listProc.running)
      return;
    root.loading = true;
    const width = maxPreviewWidth || 100;
    listProc.command = ["cliphist", "list", "-preview-width", String(width)];
    listProc.running = true;
  }

  function copyToClipboard(id) {
    // Validate id is numeric only (prevents command injection)
    if (!id || !/^\d+$/.test(String(id))) {
      ToastService.showError(pluginApi?.tr("toast.invalid-clipboard-item") || "Invalid clipboard item");
      return;
    }

    // Use shell pipe: cliphist decode ID | wl-copy
    // ID is validated to be numeric only, so this is safe from command injection
    copyToClipboardProc.clipboardId = id;
    copyToClipboardProc.command = ["sh", "-c", `cliphist decode ${id} | wl-copy`];
    copyToClipboardProc.running = true;
  }

  function deleteById(id) {
    // Validate id is numeric only (prevents command injection)
    if (!id || !/^\d+$/.test(String(id))) {
      ToastService.showError(pluginApi?.tr("toast.invalid-clipboard-item") || "Invalid clipboard item");
      return;
    }

    // cliphist delete needs the full line (ID + preview) via stdin
    // ID is validated to be numeric-only, so string interpolation is safe here
    deleteItemProc.command = ["sh", "-c", `cliphist list | grep "^${id}	" | cliphist delete`];
    deleteItemProc.running = true;
  }

  // Process for deleting clipboard item
  Process {
    id: deleteItemProc
    stdout: StdioCollector {}

    onExited: exitCode => {
                // Refresh list immediately after deletion
                root.list();
              }
  }

  function wipeAll() {
    wipeProc.running = true;
  }

  // Process for wiping all clipboard history
  Process {
    id: wipeProc
    command: ["cliphist", "wipe"]

    onExited: exitCode => {
                // Clear caches and refresh list
                root.clearCaches();
                root.list();
              }
  }

  // Add selected text to specific page
  function addSelectedToPage(pageId) {
    root.pendingPageId = pageId;
    getSelectionProcess.running = true;
  }

  function ipcOpenPanel() {
    if (root.pluginApi) {
      root.pluginApi.withCurrentScreen(screen => {
                                         root.pluginApi.openPanel(screen);
                                       });
    }
  }

  function ipcClosePanel() {
    if (root.pluginApi) {
      root.pluginApi.withCurrentScreen(screen => {
                                         root.pluginApi.closePanel(screen);
                                       });
    }
  }

  function ipcTogglePanel() {
    if (root.pluginApi) {
      root.pluginApi.withCurrentScreen(screen => {
                                         root.pluginApi.togglePanel(screen);
                                       });
    }
  }

  IpcHandler {
    target: "plugin:clipboardPlus"

    function openPanel() { ipcOpenPanel() }
    function closePanel() { ipcClosePanel() }
    function togglePanel() { ipcTogglePanel() }

    // Alias for keybind compatibility
    function toggle() { ipcTogglePanel() }

    // Pinned items IPC handlers
    function pinClipboardItem(cliphistId: string) {
      root.pinItem(cliphistId);
    }

    function unpinItem(pinnedId: string) {
      root.unpinItem(pinnedId);
    }

    function copyPinned(pinnedId: string) {
      root.copyPinnedToClipboard(pinnedId);
    }

    // Add clipboard text directly to ToDo
    // Usage: dms ipc call clipboardPlus addClipboardToTodo
    function addClipboardToTodo() {
      root.getClipboardAndAddTodoImmediate();
    }

    // NoteCards IPC handlers
    // Usage: dms ipc call clipboardPlus addNoteCard "Quick note"
    function addNoteCard(text: string) {
      const initialText = text || "";
      root.createNoteCard(initialText);
    }

    // Usage: dms ipc call clipboardPlus exportNoteCard "note_123_abc"
    function exportNoteCard(noteId: string) {
      root.exportNoteCard(noteId);
    }

    // Add clipboard text to existing note or create new one
    // Usage: dms ipc call clipboardPlus addClipboardToNoteCard
    function addClipboardToNoteCard() {
      root.getClipboardAndShowNoteSelector();
    }
  }

  IpcHandler {
    target: "clipboardPlus"

    function openPanel() { ipcOpenPanel() }
    function closePanel() { ipcClosePanel() }
    function togglePanel() { ipcTogglePanel() }
    function toggle() { ipcTogglePanel() }
    function addClipboardToTodo() { root.getClipboardAndAddTodoImmediate() }
    function addSelectionToTodo() { root.getClipboardAndAddTodoImmediate() }
    function addNoteCard(text: string) { root.createNoteCard(text || "") }
    function exportNoteCard(noteId: string) { root.exportNoteCard(noteId) }
    function addClipboardToNoteCard() { root.getClipboardAndShowNoteSelector() }
    function addSelectionToNoteCard() { root.getClipboardAndShowNoteSelector() }
    function pinClipboardItem(cliphistId: string) { root.pinItem(cliphistId) }
    function unpinItem(pinnedId: string) { root.unpinItem(pinnedId) }
    function copyPinned(pinnedId: string) { root.copyPinnedToClipboard(pinnedId) }
  }

  // Process to get selected text for ToDo selector
  Process {
    id: getSelectionForSelectorProcess
    command: ["sh", "-c", "t=$(wl-paste -p -n 2>/dev/null || true); if [ -z \"$t\" ]; then t=$(wl-paste -n 2>/dev/null || true); fi; printf '%s' \"$t\""]
    stdout: StdioCollector {
      id: selectorSelectionStdout
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                  const selectedText = selectorSelectionStdout.text.trim();
                  if (selectedText && selectedText.length > 0) {
                    root.showTodoPageSelector(selectedText);
                  } else {
                    ToastService.showError(pluginApi?.tr("toast.no-text-selected") || "No text selected");
                  }
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-get-selection") || "Failed to get selection");
                }
              }
  }

  // Get selection and show page selector
  function getSelectionAndShowSelector() {
    getSelectionForSelectorProcess.running = true;
  }

  // Process to get selected text for direct ToDo add
  Process {
    id: getSelectionForTodoImmediateProcess
    command: ["sh", "-c", "t=$(wl-paste -p -n 2>/dev/null || true); if [ -z \"$t\" ]; then t=$(wl-paste -n 2>/dev/null || true); fi; printf '%s' \"$t\""]
    stdout: StdioCollector {
      id: todoImmediateSelectionStdout
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                  const selectedText = todoImmediateSelectionStdout.text.trim();
                  if (selectedText && selectedText.length > 0) {
                    Quickshell.execDetached(["wl-copy", "--", selectedText]);
                    root.addTodoWithText(selectedText, 0);
                  } else {
                    ToastService.showError(pluginApi?.tr("toast.no-text-selected") || "No text selected");
                  }
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-get-selection") || "Failed to get selection");
                }
              }
  }

  function getSelectionAndAddTodoImmediate() {
    getSelectionForTodoImmediateProcess.running = true;
  }

  // Process to get clipboard text for direct ToDo add (IPC)
  Process {
    id: getClipboardForTodoImmediateProcess
    command: ["wl-paste", "-n"]
    stdout: StdioCollector {
      id: todoClipboardStdout
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                  const clipboardText = todoClipboardStdout.text.trim();
                  if (clipboardText && clipboardText.length > 0) {
                    Quickshell.execDetached(["wl-copy", "--", clipboardText]);
                    root.addTodoWithText(clipboardText, 0);
                  } else {
                    ToastService.showError(pluginApi?.tr("toast.no-text-selected") || "No text selected");
                  }
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-get-selection") || "Failed to get selection");
                }
              }
  }

  function getClipboardAndAddTodoImmediate() {
    getClipboardForTodoImmediateProcess.running = true;
  }

  // Refresh clipboard list when panel opens
  function refreshOnPanelOpen() {
    root.list();
  }

  // Show ToDo page selector at cursor position
  function showTodoPageSelector(text) {
    root.activeSelector = "todo";
    root.activeSelector = "todo";
    root.pendingSelectedText = text;

    // Get pages from ClipBoard+ settings
    const store = ensureTodoData();
    const todoPages = store.pages || [];

    // Show selector with pages list
    if (todoPageSelector) {
      todoPageSelector.show(text, todoPages);
    } else {
      ToastService.showError(pluginApi?.tr("toast.could-not-open-todo") || "Could not open ToDo selector");
    }
  }

  // Handle page selection from selector
  function handleTodoPageSelected(pageId, pageName) {
    if (root.pendingSelectedText) {
      root.addTodoWithText(root.pendingSelectedText, pageId);
      root.pendingSelectedText = "";
    }
  }
  // Get selection and show note card selector
  function getSelectionAndShowNoteSelector() {
    getSelectionForNoteSelectorProcess.running = true;
  }
  function showNoteCardSelector(text) {
    root.activeSelector = "notecard";
    root.activeSelector = "notecard";
    root.pendingNoteCardText = text;
    // Load notecards first
    root.loadNoteCards();
    // Wait a bit for notes to load, then show selector
    Qt.callLater(() => {
                   if (noteCardSelector) {
                     noteCardSelector.show(text, root.noteCards);
                   } else {
                     ToastService.showError(pluginApi?.tr("toast.could-not-open-note-selector") || "Could not open note selector");
                   }
                 });
  }

  // Handle note selection from selector
  function handleNoteCardSelected(noteId, noteTitle) {
    if (root.pendingNoteCardText) {
      root.appendTextToNoteCard(noteId, root.pendingNoteCardText);
      root.pendingNoteCardText = "";
    }
  }

  // Handle creating new note from selection
  // Handle creating new ToDo page from selection
  function handleCreateNewTodoPage() {
    if (root.pendingSelectedText) {
      const store = ensureTodoData();
      const pageId = Date.now();
      const pageName = root.pendingSelectedText.substring(0, 24) || "New Page";
      const newPages = store.pages.slice();
      newPages.push({ id: pageId, name: pageName });
      root.todoPages = newPages;
      root.todoRevision++;
      saveTodoFile();

      root.addTodoWithText(root.pendingSelectedText, pageId);
      ToastService.showInfo(pluginApi?.tr("toast.todo-page-created") || "New ToDo page created");
      root.pendingSelectedText = "";
    }
  }

  function handleCreateNewNoteFromSelection() {
    if (root.pendingNoteCardText) {
      root.createNoteCard(root.pendingNoteCardText);
      root.pendingNoteCardText = "";
    }
  }

  // Append text to existing note
  function appendTextToNoteCard(noteId, text) {
    for (let i = 0; i < root.noteCards.length; i++) {
      if (root.noteCards[i].id === noteId) {
        const currentContent = root.noteCards[i].content || "";
        const newContent = currentContent ? currentContent + "\n" + text : text;

        root.updateNoteCard(noteId, { content: newContent });
        ToastService.showInfo(pluginApi?.tr("toast.text-added-to-note") || "Text added to note");
        return;
      }
    }
    ToastService.showError(pluginApi?.tr("toast.note-not-found") || "Note not found");
  }

  // ToDo page selector (single instance, uses first screen)
  // It's a fullscreen overlay so it works regardless of which screen cursor is on
  // Selection context menu (shared for both note and todo selection)
  property var selectionMenu: null
  property string activeSelector: ""  // "todo" or "notecard"

  Variants {
    model: Quickshell.screens

    delegate: SelectionContextMenu {
      required property var modelData

      screen: modelData
      pluginApi: root.pluginApi

      Component.onCompleted: {
        if (!root.selectionMenu) {
          root.selectionMenu = this;
        }
      }

      onItemSelected: action => {
                        // Route to appropriate handler
                        if (root.activeSelector === "notecard" && root.noteCardSelector) {
                          root.noteCardSelector.handleItemSelected(action);
                        } else if (root.activeSelector === "todo" && root.todoPageSelector) {
                          root.todoPageSelector.handleItemSelected(action);
                        }
                      }

      onCancelled: {
        root.pendingSelectedText = "";
        root.pendingNoteCardText = "";
      }
    }
  }

  // Note card selector (logic only)
  property var noteCardSelector: NoteCardSelector {
    pluginApi: root.pluginApi
    selectionMenu: root.selectionMenu

    onNoteSelected: (noteId, noteTitle) => {
                      root.handleNoteCardSelected(noteId, noteTitle);
                    }

    onCreateNewNote: () => {
                       root.handleCreateNewNoteFromSelection();
                     }
  }

  property string pendingNoteCardText: ""

  // Todo page selector (logic only)
  property var todoPageSelector: TodoPageSelector {
    pluginApi: root.pluginApi
    selectionMenu: root.selectionMenu

    onPageSelected: (pageId, pageName) => {
                      root.handleTodoPageSelected(pageId, pageName);
                    }
  }

  // Clipboard-based note selector (IPC)
  Process {
    id: getClipboardForNoteSelectorProcess
    command: ["wl-paste", "-n"]
    stdout: StdioCollector {
      id: noteClipboardStdout
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                  const clipboardText = noteClipboardStdout.text.trim();
                  if (clipboardText && clipboardText.length > 0) {
                    Quickshell.execDetached(["wl-copy", "--", clipboardText]);
                    root.showNoteCardSelector(clipboardText);
                  } else {
                    ToastService.showError(pluginApi?.tr("toast.no-text-selected") || "No text selected");
                  }
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-get-selection") || "Failed to get selection");
                }
              }
  }

  function getClipboardAndShowNoteSelector() {
    getClipboardForNoteSelectorProcess.running = true;
  }

  Process {
    id: getSelectionForNoteSelectorProcess
    command: ["wl-paste", "-p", "-n"]
    stdout: StdioCollector {
      id: noteSelectionStdout
    }
    onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                  const selectedText = noteSelectionStdout.text.trim();
                  if (selectedText && selectedText.length > 0) {
                    Quickshell.execDetached(["wl-copy", "--", selectedText]);
                    root.showNoteCardSelector(selectedText);
                  } else {
                    ToastService.showError(pluginApi?.tr("toast.no-text-selected") || "No text selected");
                  }
                } else {
                  ToastService.showError(pluginApi?.tr("toast.failed-to-get-selection") || "Failed to get selection");
                }
              }
  }
  // Check if wtype is available
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

  // Timer for auto-paste delay
  Timer {
    id: autoPasteTimer
    interval: pluginApi?.pluginSettings?.autoPasteDelay ?? 300
    repeat: false
    onTriggered: {
      if (root.wtypeAvailable) {
        autoPasteProc.running = true;
      } else {
        Logger.w("ClipBoard+", "Auto-paste failed: wtype not found. Install with: sudo pacman -S wtype");
      }
    }
  }

  // Process to trigger auto-paste via wtype Ctrl+V
  Process {
    id: autoPasteProc
    command: ["wtype", "-M", "ctrl", "-M", "shift", "v"]
    running: false
    onExited: exitCode => {
      if (exitCode !== 0) {
        Logger.w("ClipBoard+", "wtype auto-paste exited with code: " + exitCode);
      }
    }
  }

  // Public function called from Panel.qml
  function triggerAutoPaste() {
    autoPasteTimer.restart();
  }

  // Initialize pinned.json and notecards directory if they don't exist
  Component.onCompleted: {
    // console.log("ClipBoard+: Component.onCompleted - pluginApi initialized");
    if (pluginApi) {
    }

    // Ensure config directories exist
    Quickshell.execDetached(["mkdir", "-p", root.clipboardPlusConfigDir]);
    Quickshell.execDetached(["mkdir", "-p", root.noteCardsDir]);

    // Create empty pinned.json if it doesn't exist
    const pinnedPath = clipboardPlusConfigDir + "/pinned.json";
    Quickshell.execDetached(["sh", "-c", `[ -f "${pinnedPath}" ] || echo '{"items":[]}' > "${pinnedPath}"`]);

    // Migrate legacy notecards.json (if present) into per-note files
    const legacyNotesPath = clipboardPlusConfigDir + "/notecards.json";
    const migrateScript =
      "import json, os, re, sys\n" +
      "legacy = sys.argv[1]\n" +
      "outdir = sys.argv[2]\n" +
      "if not os.path.isfile(legacy):\n" +
      "  sys.exit(0)\n" +
      "try:\n" +
      "  with open(legacy, 'r') as f:\n" +
      "    data = json.load(f)\n" +
      "except Exception:\n" +
      "  sys.exit(0)\n" +
      "if not isinstance(data, list) or len(data) == 0:\n" +
      "  sys.exit(0)\n" +
      "os.makedirs(outdir, exist_ok=True)\n" +
      "for note in data:\n" +
      "  if not isinstance(note, dict):\n" +
      "    continue\n" +
      "  note_id = str(note.get('id', 'untitled'))\n" +
      "  safe = re.sub(r'[^a-zA-Z0-9-_]', '_', note_id)\n" +
      "  path = os.path.join(outdir, safe + '.json')\n" +
      "  with open(path, 'w') as f:\n" +
      "    json.dump(note, f, indent=2)\n" +
      "try:\n" +
      "  os.rename(legacy, legacy + '.bak')\n" +
      "except Exception:\n" +
      "  pass\n";
    Quickshell.execDetached(["python3", "-c", migrateScript, legacyNotesPath, root.noteCardsDir]);

    // Force reload pinned items from file
    pinnedFile.reload();

    // Load todo file after ensuring directories
    todoFile.reload();

    // Load notecards from disk on startup
    loadNoteCards();

    // Load clipboard history
    list();
  }

  // Cleanup all running processes on destruction
  Component.onDestruction: {
    if (listProc.running)
      listProc.terminate();
    if (decodeProc.running)
      decodeProc.terminate();
    if (copyPinnedImageProc.running)
      copyPinnedImageProc.terminate();
    if (copyPinnedTextProc.running)
      copyPinnedTextProc.terminate();
    if (imageDecodeProc.running)
      imageDecodeProc.terminate();
    if (getSelectionProcess.running)
      getSelectionProcess.terminate();
    if (getSelectionForSelectorProcess.running)
      getSelectionForSelectorProcess.terminate();
    if (getSelectionForNoteSelectorProcess.running)
      getSelectionForNoteSelectorProcess.terminate();
    if (copyToClipboardProc.running)
      copyToClipboardProc.terminate();
    if (deleteItemProc.running)
      deleteItemProc.terminate();
    if (wipeProc.running)
      wipeProc.terminate();
    if (loadNoteCardsProc.running)
      loadNoteCardsProc.terminate();

    autoPasteTimer.stop();
    if (autoPasteProc.running) autoPasteProc.terminate();
    if (wtypeCheckProc.running) wtypeCheckProc.terminate();

    // Clear data structures
    pinnedItems = [];
    noteCards = [];
    items = [];
    firstSeenById = {};
    imageCache = {};
    imageCacheOrder = [];
  }
}
