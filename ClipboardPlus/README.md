# ClipBoard+

Advanced clipboard manager for DMS with clipboard history, pinned items, notes, and built-in ToDo pages.

Ported / inspired from [clipper in noctalia-shell](https://noctalia.dev/plugins/clipper/) by [blackbartblues](https://github.com/blackbartblues). 

## Notes

- Uses `cliphist`, `wl-copy`, and `wl-paste`.
- Default config / state data stored under `~/.config/dms-clipboardPlus`.

## IPC Usage

```bash
# Open/close/toggle panel
dms ipc call clipboardPlus openPanel
dms ipc call clipboardPlus closePanel
dms ipc call clipboardPlus togglePanel

# Note cards
dms ipc call clipboardPlus addNoteCard "Quick note"
dms ipc call clipboardPlus exportNoteCard "note_id"

# Add current clipboard data to ToDo
dms ipc call clipboardPlus addClipboardToTodo

# Add current clipboard data to note card
dms ipc call clipboardPlus addClipboardToNoteCard
```

Example in niri

```bash
    Mod+V hotkey-overlay-title="Clipboard Manager" {
        spawn-sh "dms ipc call clipboardPlus togglePanel"
    }
    Mod+Shift+V hotkey-overlay-title="Add to note card" {
        spawn-sh "dms ipc call clipboardPlus addClipboardToNoteCard"
    }
```

## Known Bugs

Sending close / toggle command from IPC wont close ClipBoard+ that is opened from widget / bar. 
