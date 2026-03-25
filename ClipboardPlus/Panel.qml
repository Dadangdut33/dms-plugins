import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: root

    // Plugin API (injected by PluginPanelSlot)
    property var pluginApi: null
    property var screen: null
    property bool panelOpen: true
    property bool animationsEnabled: pluginApi?.pluginSettings?.enableAnimations ?? true
    property real openProgress: panelOpen ? 1 : 0

    Behavior on openProgress {
        enabled: animationsEnabled
        NumberAnimation {
            duration: 200
            easing.type: Theme.emphasizedEasing
        }
    }

    function focusClipboardList() {
        if (!listView) return;
        listView.forceActiveFocus();
        if (listView.count > 0) {
            selectedIndex = Math.min(selectedIndex, listView.count - 1);
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            Qt.callLater(() => focusClipboardList());
        }
    }

    opacity: animationsEnabled ? openProgress : 1
    scale: animationsEnabled ? (0.98 + 0.02 * openProgress) : 1

    // Screen context - store reference for child components
    property var currentScreen: screen

    // Track currently open ToDo context menu
    property var activeContextMenu: null

    // Refresh clipboard list and load notecards when panel becomes visible
    // Save notecards when panel is closed
    onVisibleChanged: {
        if (visible) {
            pluginApi?.mainInstance?.refreshOnPanelOpen();
            if (pluginApi?.mainInstance && !pluginApi.mainInstance.noteCardsLoaded) {
                pluginApi.mainInstance.loadNoteCards();
            }
            if (pluginApi?.mainInstance) {
                pluginApi.mainInstance.panelVisible = true;
            }
        } else {
            // Sync all local changes from notecards before saving
            if (noteCardsPanel && noteCardsPanel.children[0] && noteCardsPanel.children[0].syncAllChanges) {
                noteCardsPanel.children[0].syncAllChanges();
            }
            if (pluginApi?.mainInstance) {
                pluginApi.mainInstance.panelVisible = false;
            }
        }
    }

    // SmartPanel properties (required for panel behavior)
    readonly property var geometryPlaceholder: mainContainer
    readonly property bool allowAttach: true

    property bool isFullscreen: pluginApi?.pluginSettings?.fullscreenMode ?? false
    property real contentPreferredWidth: isFullscreen
        ? (screen?.width ?? 1920)
        : Math.min(1450, screen?.width ?? 1450)
    property real contentPreferredHeight: isFullscreen
        ? (screen?.height ?? 900)
        : Math.min((screen?.height ?? 900) * 0.85, 760)
    property real dimOpacity: {
        const raw = pluginApi?.pluginSettings?.backgroundOpacity;
        const percent = (raw !== undefined && raw !== null) ? raw : 35;
        return Math.max(0, Math.min(1, percent / 100));
    }

    // Keyboard navigation
    property int selectedIndex: 0

    // Filtering
    property string filterType: ""
    property string searchText: ""
    property bool enableTabNavigation: pluginApi?.pluginSettings?.enableTabNavigation ?? true
    property var categoryTabTarget: null
    property int categoryIndex: 0

    function categoryButtons() {
        const buttons = [btnAll, btnText, btnImage, btnColorFilter, btnLink, btnCode, btnEmoji, btnFile];
        return buttons.filter(b => b && (b.visible === undefined || b.visible));
    }

    function filterTypeToCategoryIndex() {
        switch (filterType) {
        case "Text": return 1;
        case "Image": return 2;
        case "Color": return 3;
        case "Link": return 4;
        case "Code": return 5;
        case "Emoji": return 6;
        case "File": return 7;
        default: return 0;
        }
    }

    function categoryIndexToFilterType(idx) {
        switch (idx) {
        case 1: return "Text";
        case 2: return "Image";
        case 3: return "Color";
        case 4: return "Link";
        case 5: return "Code";
        case 6: return "Emoji";
        case 7: return "File";
        default: return "";
        }
    }

    function focusCategoryIndex(idx) {
        const buttons = categoryButtons();
        if (buttons.length === 0) return;
        let next = idx;
        if (next < 0) next = buttons.length - 1;
        if (next >= buttons.length) next = 0;
        categoryIndex = next;
        const target = buttons[next];
        if (target && typeof target.forceActiveFocus === "function") {
            target.forceActiveFocus();
        }
    }

    function handleListLeft() {
        if (listView && listView.count > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1);
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    function handleListRight() {
        if (listView && listView.count > 0) {
            selectedIndex = Math.min(listView.count - 1, selectedIndex + 1);
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    // Tab navigation 
    function normalizeTabKey(key) {
        if (!key) return "";
        const k = key.toLowerCase().trim();
        if (k === "clipboard" || k.startsWith("clip") || k === "history") return "clipboard";
        if (k === "search")                                                 return "search";
        if (k === "category" || k === "categories" || k === "filters")     return "category";
        if (k === "pinned"   || k === "pin")                               return "pinned";
        if (k === "todo"     || k === "todos")                             return "todo";
        return "";
    }

    function resolveTabOrder() {
        const fallback = ["clipboard", "search", "category", "pinned", "todo"];
        const raw = pluginApi?.pluginSettings?.tabOrder;
        if (!raw || !raw.trim()) return fallback;
        const parts = raw.split(",").map(s => s.trim()).filter(Boolean);
        const seen  = {};
        const order = [];
        for (let i = 0; i < parts.length; i++) {
            const key = normalizeTabKey(parts[i]);
            if (!key || seen[key]) continue;
            seen[key] = true;
            order.push(key);
        }
        for (let i = 0; i < fallback.length; i++) {
            if (!seen[fallback[i]]) order.push(fallback[i]);
        }
        return order;
    }

    function resolveEnabledSet() {
        const raw = pluginApi?.pluginSettings?.tabOrderEnabled;
        if (raw === undefined || raw === null) return null; // null = all enabled
        if (!raw.trim()) return {};                         // empty = all disabled
        const set   = {};
        const parts = raw.split(",").map(s => s.trim()).filter(Boolean);
        for (let i = 0; i < parts.length; i++) {
            const key = normalizeTabKey(parts[i]);
            if (key) set[key] = true;
        }
        return set;
    }

    function tabTargets() {
        const order      = resolveTabOrder();
        const enabledSet = resolveEnabledSet();

        const targets = [];
        for (let i = 0; i < order.length; i++) {
            const key = order[i];
            if (enabledSet !== null && !enabledSet[key]) continue;

            let target = null;
            switch (key) {
                case "clipboard": target = listView;      break;
                case "search":    target = searchField;   break;
                case "category":  target = categoryFocus; break;
                case "pinned":    target = pinnedFocus;   break;
                case "todo":      target = todoFocus;     break;
            }

            if (target && (target.visible === undefined || target.visible)) {
                targets.push(target);
            }
        }
        return targets;
    }

    // Returns true if `target` has activeFocus OR any of its descendants do.
    // Needed because ListView delegates steal focus from the ListView itself,
    // and FocusScopes forward focus inward — so target.activeFocus is often
    // false even when that section is "active" from the user's perspective.
    function targetHasFocus(target) {
        if (!target) return false;
        if (target.activeFocus) return true;
        // Walk up from the window's currently focused item to see if target
        // is an ancestor — i.e. focus is somewhere inside target's subtree.
        const focused = Window.activeFocusItem;
        if (!focused) return false;
        let item = focused;
        while (item) {
            if (item === target) return true;
            item = item.parent;
        }
        return false;
    }

    function currentTabIndex(targets) {
        for (let i = 0; i < targets.length; i++) {
            if (targetHasFocus(targets[i])) return i;
        }
        return -1;
    }

    function focusTarget(target) {
        if (!target) return;
        if (typeof target.forceActiveFocus === "function") {
            target.forceActiveFocus();
        } else if (target.contentItem && typeof target.contentItem.forceActiveFocus === "function") {
            target.contentItem.forceActiveFocus();
        }
    }

    function advanceTab() {
        if (!enableTabNavigation) return;
        const targets = tabTargets();
        if (targets.length === 0) return;
        const idx  = currentTabIndex(targets);
        const next = targets[(idx + 1) % targets.length];
        focusTarget(next);
    }

    function reverseTab() {
        if (!enableTabNavigation) return;
        const targets = tabTargets();
        if (targets.length === 0) return;
        const idx  = currentTabIndex(targets);
        const next = targets[(idx - 1 + targets.length) % targets.length];
        focusTarget(next);
    }

    // Reset selection when filter changes
    onFilterTypeChanged: {
        selectedIndex = 0;
        categoryIndex = filterTypeToCategoryIndex();
    }
    onSearchTextChanged: selectedIndex = 0

    // Filtered items (uses shared getItemType from Main.qml)
    readonly property var filteredItems: {
        let items = pluginApi?.mainInstance?.items || [];
        if (!filterType && !searchText)
            return items;

        return items.filter(item => {
            if (filterType) {
                const itemType = pluginApi?.mainInstance?.getItemType(item) || "Text";
                if (itemType !== filterType)
                    return false;
            }
            if (searchText) {
                const preview = item.preview || "";
                if (!preview.toLowerCase().includes(searchText.toLowerCase()))
                    return false;
            }
            return true;
        });
    }

    Keys.onLeftPressed: {
        if (listView.count > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1);
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    Keys.onRightPressed: {
        if (listView.count > 0) {
            selectedIndex = Math.min(listView.count - 1, selectedIndex + 1);
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    Keys.onReturnPressed: {
        if (!listView || !listView.activeFocus) return;
        if (listView.count > 0 && selectedIndex >= 0 && selectedIndex < listView.count) {
            const item = root.filteredItems[selectedIndex];
            if (item) {
                pluginApi?.mainInstance?.copyToClipboard(item.id);
                if (pluginApi) {
                    pluginApi.closePanel(screen);
                    const enterPaste = pluginApi?.pluginSettings?.autoPasteOnEnterSelect ?? false;
                    if (enterPaste) {
                        pluginApi.mainInstance?.triggerAutoPaste();
                    }
                }
            }
        }
    }

    Keys.onTabPressed: event => {
        advanceTab();
        event.accepted = true;
    }

    Keys.onEscapePressed: {
        if (pluginApi) {
            pluginApi.closePanel(screen);
        }
    }

    Keys.onDeletePressed: {
        if (listView.count > 0 && selectedIndex >= 0 && selectedIndex < listView.count) {
            const item = root.filteredItems[selectedIndex];
            if (item) {
                pluginApi?.mainInstance?.deleteById(item.id);
                if (selectedIndex >= listView.count - 1) {
                    selectedIndex = Math.max(0, listView.count - 2);
                }
            }
        }
    }

    Keys.onDigit1Pressed: filterType = ""
    Keys.onDigit2Pressed: filterType = "Text"
    Keys.onDigit3Pressed: filterType = "Image"
    Keys.onDigit4Pressed: filterType = "Color"
    Keys.onDigit5Pressed: filterType = "Link"
    Keys.onDigit6Pressed: filterType = "Code"
    Keys.onDigit7Pressed: filterType = "Emoji"
    Keys.onDigit8Pressed: filterType = "File"

    // Fullscreen backdrop + click-to-close
    Rectangle {
        id: backdrop
        anchors.fill: parent
        z: -2
        color: (pluginApi?.pluginSettings?.hidePanelBackground ?? false)
               ? "transparent"
               : Qt.rgba(0, 0, 0, root.dimOpacity)
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: function(mouse) {
            if (!(root.pluginApi?.pluginSettings?.closeOnOutsideClick ?? true)) {
                return;
            }
            const p = mapToItem(mainContainer, mouse.x, mouse.y);
            const outside = (p.x < 0 || p.y < 0 || p.x > mainContainer.width || p.y > mainContainer.height);
            if (outside && root.pluginApi) {
                root.pluginApi.closePanel(screen);
            }
        }
    }

    // Main container - centered when not fullscreen
    Item {
        id: mainContainer
        width: Math.min(root.contentPreferredWidth || parent.width, parent.width)
        height: Math.min(root.contentPreferredHeight || parent.height, parent.height)
        anchors.centerIn: parent

        DankActionButton {
            visible: pluginApi?.pluginSettings?.showCloseButton ?? false
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingM
            z: 10
            iconName: "close"
            tooltipText: pluginApi?.tr("panel.close") || "Close"
            backgroundColor: Theme.surfaceContainer
            iconColor: Theme.surfaceText
            onClicked: {
                if (root.pluginApi) {
                    root.pluginApi.closePanel(screen);
                }
            }

            // Subtle outline for contrast
            StyledRect {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Theme.outline
                border.width: 1
                z: 1
            }
        }

        // CLIPBOARD PANEL - Bottom, full width (horizontal)
        Rectangle {
            id: clipboardPanel
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(300, screen?.height * 0.3 || 300)
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Math.max(0.2, Math.min(1.0, (pluginApi?.pluginSettings?.panelOpacityClipboard ?? 100) / 100)))
            radius: Theme.cornerRadius
            opacity: 1.0

            Rectangle {
                topLeftRadius: Theme.cornerRadius
                topRightRadius: Theme.cornerRadius
                bottomLeftRadius: 0
                bottomRightRadius: 0
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Math.max(0.2, Math.min(1.0, (pluginApi?.pluginSettings?.panelOpacityClipboard ?? 100) / 100)))
                opacity: 1.0
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StyledText {
                        text: pluginApi?.tr("panel.title") || "Clipboard History"
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: -2 * 1
                    }

                    Item { Layout.fillWidth: true }

                    DankActionButton {
                        iconName: "settings"
                        tooltipText: pluginApi?.tr("panel.settings") || "Settings"
                        Layout.alignment: Qt.AlignVCenter
                        backgroundColor: Theme.surfaceContainer
                        iconColor: Theme.surfaceText
                        onClicked: {
                            PopoutService.openSettingsWithTab("plugins");
                        }
                    }

                    StyledRect {
                        id: searchInput
                        Layout.preferredWidth: 250
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.color: Theme.outline
                        border.width: 1
                        height: Math.round(Theme.fontSizeMedium * 2.2)

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            text: root.searchText
                            onTextChanged: root.searchText = text

                            Keys.onEscapePressed: {
                                if (text !== "") {
                                    text = "";
                                } else if (root.pluginApi) {
                                    root.pluginApi.closePanel(screen);
                                }
                            }
                            Keys.onLeftPressed: event => {
                                if (searchField.cursorPosition === 0) {
                                    root.handleListLeft();
                                    event.accepted = true;
                                }
                            }
                            Keys.onRightPressed: event => {
                                if (searchField.cursorPosition === text.length) {
                                    root.handleListRight();
                                    event.accepted = true;
                                }
                            }
                            Keys.onReturnPressed: root.onReturnPressed()
                            Keys.onEnterPressed: root.onReturnPressed()
                            Keys.onTabPressed: event => {
                                root.advanceTab();
                                event.accepted = true;
                            }
                            Keys.onUpPressed: event => { event.accepted = true; }
                            Keys.onDownPressed: event => {
                                listView.forceActiveFocus();
                                event.accepted = true;
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) {
                                    root.onHomePressed();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_End && event.modifiers & Qt.ControlModifier) {
                                    root.onEndPressed();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Delete) {
                                    if (listView.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < listView.count) {
                                        const item = root.filteredItems[root.selectedIndex];
                                        if (item) {
                                            pluginApi?.mainInstance?.deleteById(item.id);
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingS
                            text: pluginApi?.tr("panel.search-placeholder") || "Search..."
                            color: Theme.surfaceVariantText
                            visible: searchField.text.length === 0
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Filter buttons row
                    FocusScope {
                        id: categoryFocus
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: filterRow.implicitWidth
                        implicitHeight: filterRow.implicitHeight
                        Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                        Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                        Keys.onLeftPressed: event => { root.focusCategoryIndex(root.categoryIndex - 1); event.accepted = true; }
                        Keys.onRightPressed: event => { root.focusCategoryIndex(root.categoryIndex + 1); event.accepted = true; }
                        Keys.onReturnPressed: event => {
                            root.filterType = root.categoryIndexToFilterType(root.categoryIndex);
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: event => {
                            root.filterType = root.categoryIndexToFilterType(root.categoryIndex);
                            event.accepted = true;
                        }
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.focusCategoryIndex(root.filterTypeToCategoryIndex());
                            }
                        }
                        Component.onCompleted: root.categoryTabTarget = categoryFocus

                        RowLayout {
                            id: filterRow
                            spacing: Theme.spacingXS
                            Layout.alignment: Qt.AlignVCenter

                        // --- ALL ---
                        Item {
                            readonly property string fType: ""
                            readonly property color accentColor: Theme.primary
                            readonly property color accentFgColor: Theme.primaryText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: (pluginApi?.mainInstance?.items || []).length
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 0
                            width: btnAll.width + Theme.fontSizeSmall
                            height: btnAll.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnAll
                                width: btnAll.width + 8
                                height: btnAll.height + 8
                                radius: (btnAll.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnAll
                                anchors.centerIn: parent
                                focus: true
                                iconName: "apps"
                                tooltipText: pluginApi?.tr("panel.filter-all") || "All"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = ""
                                Keys.onTabPressed: event => {
                                    root.advanceTab();
                                    event.accepted = true;
                                }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnAll.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnAll.horizontalCenter
                                width: btnAll.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnAll.left
                                    top: btnAll.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeAll.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeAll.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }

                                StyledText {
                                    id: badgeAll
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- TEXT ---
                        Item {
                            readonly property string fType: "Text"
                            readonly property color accentColor: Theme.primary
                            readonly property color accentFgColor: Theme.primaryText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "Text").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 1
                            width: btnText.width + Theme.fontSizeSmall
                            height: btnText.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnText
                                width: btnText.width + 8
                                height: btnText.height + 8
                                radius: (btnText.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnText
                                anchors.centerIn: parent
                                iconName: "format_align_left"
                                tooltipText: pluginApi?.tr("panel.filter-text") || "Text"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Text"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnText.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnText.horizontalCenter
                                width: btnText.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnText.left
                                    top: btnText.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeText.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeText.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- IMAGE ---
                        Item {
                            readonly property string fType: "Image"
                            readonly property color accentColor: Theme.secondary
                            readonly property color accentFgColor: Theme.surfaceText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "Image").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 2
                            width: btnImage.width + Theme.fontSizeSmall
                            height: btnImage.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnImage
                                width: btnImage.width + 8
                                height: btnImage.height + 8
                                radius: (btnImage.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnImage
                                anchors.centerIn: parent
                                iconName: "image"
                                tooltipText: pluginApi?.tr("panel.filter-images") || "Images"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Image"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnImage.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnImage.horizontalCenter
                                width: btnImage.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnImage.left
                                    top: btnImage.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeImage.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeImage.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeImage
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- COLOR ---
                        Item {
                            readonly property string fType: "Color"
                            readonly property color accentColor: Theme.secondary
                            readonly property color accentFgColor: Theme.surfaceText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "Color").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 3
                            width: btnColorFilter.width + Theme.fontSizeSmall
                            height: btnColorFilter.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnColorFilter
                                width: btnColorFilter.width + 8
                                height: btnColorFilter.height + 8
                                radius: (btnColorFilter.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnColorFilter
                                anchors.centerIn: parent
                                iconName: "palette"
                                tooltipText: pluginApi?.tr("panel.filter-colors") || "Colors"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Color"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnColorFilter.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnColorFilter.horizontalCenter
                                width: btnColorFilter.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnColorFilter.left
                                    top: btnColorFilter.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeColorFilter.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeColorFilter.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeColorFilter
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- LINK ---
                        Item {
                            readonly property string fType: "Link"
                            readonly property color accentColor: Theme.primary
                            readonly property color accentFgColor: Theme.primaryText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "Link").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 4
                            width: btnLink.width + Theme.fontSizeSmall
                            height: btnLink.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnLink
                                width: btnLink.width + 8
                                height: btnLink.height + 8
                                radius: (btnLink.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnLink
                                anchors.centerIn: parent
                                iconName: "link"
                                tooltipText: pluginApi?.tr("panel.filter-links") || "Links"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Link"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnLink.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnLink.horizontalCenter
                                width: btnLink.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnLink.left
                                    top: btnLink.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeLink.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeLink.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeLink
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- CODE ---
                        Item {
                            readonly property string fType: "Code"
                            readonly property color accentColor: Theme.secondary
                            readonly property color accentFgColor: Theme.surfaceText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "Code").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 5
                            width: btnCode.width + Theme.fontSizeSmall
                            height: btnCode.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnCode
                                width: btnCode.width + 8
                                height: btnCode.height + 8
                                radius: (btnCode.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnCode
                                anchors.centerIn: parent
                                iconName: "code"
                                tooltipText: pluginApi?.tr("panel.filter-code") || "Code"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Code"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnCode.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnCode.horizontalCenter
                                width: btnCode.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnCode.left
                                    top: btnCode.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeCode.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeCode.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeCode
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- EMOJI ---
                        Item {
                            readonly property string fType: "Emoji"
                            readonly property color accentColor: Theme.primary
                            readonly property color accentFgColor: Theme.primaryText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "Emoji").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 6
                            width: btnEmoji.width + Theme.fontSizeSmall
                            height: btnEmoji.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnEmoji
                                width: btnEmoji.width + 8
                                height: btnEmoji.height + 8
                                radius: (btnEmoji.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnEmoji
                                anchors.centerIn: parent
                                iconName: "sentiment_satisfied"
                                tooltipText: pluginApi?.tr("panel.filter-emoji") || "Emoji"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Emoji"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnEmoji.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnEmoji.horizontalCenter
                                width: btnEmoji.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnEmoji.left
                                    top: btnEmoji.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeEmoji.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeEmoji.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeEmoji
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        // --- FILE ---
                        Item {
                            readonly property string fType: "File"
                            readonly property color accentColor: Theme.secondary
                            readonly property color accentFgColor: Theme.surfaceText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: {
                                const all = pluginApi?.mainInstance?.items || [];
                                return all.filter(i => (pluginApi?.mainInstance?.getItemType(i) || "Text") === "File").length;
                            }
                            readonly property bool keyboardFocus: categoryFocus.activeFocus && root.categoryIndex === 7
                            width: btnFile.width + Theme.fontSizeSmall
                            height: btnFile.height + Theme.fontSizeSmall + 8

                            Rectangle {
                                anchors.centerIn: btnFile
                                width: btnFile.width + 8
                                height: btnFile.height + 8
                                radius: (btnFile.height + 8) / 2
                                color: "transparent"
                                border.width: parent.keyboardFocus ? 2 : 0
                                border.color: Theme.primary
                                z: -1
                                opacity: parent.keyboardFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            DankActionButton {
                                id: btnFile
                                anchors.centerIn: parent
                                iconName: "description"
                                tooltipText: pluginApi?.tr("panel.filter-files") || "Files"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "File"
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            }

                            Rectangle {
                                anchors.top: btnFile.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: btnFile.horizontalCenter
                                width: btnFile.width * 0.6
                                height: 3
                                radius: 2
                                color: parent.isActive ? parent.accentColor : "transparent"
                                opacity: parent.isActive ? 1.0 : 0
                            }

                            Item {
                                visible: parent.itemCount > 0
                                anchors {
                                    left: btnFile.left
                                    top: btnFile.top
                                    leftMargin: -Theme.fontSizeSmall * 0.55
                                    topMargin: -Theme.fontSizeSmall * 0.25
                                }
                                width: Math.max(badgeFile.implicitWidth + 2, Theme.fontSizeTiny * 2)
                                height: Math.max(badgeFile.implicitHeight + Theme.spacingXS, Theme.fontSizeTiny * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(Theme.cornerRadius, width / 2)
                                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceContainerHighest
                                    scale: parent.parent.parent.isActive ? 1.0 : 0.85
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutBack }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutCubic }
                                    }
                                }
                                StyledText {
                                    id: badgeFile
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: Theme.fontSizeSmall * 0.75
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }
                        } // End filter RowLayout
                    } // End categoryFocus

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.outline
                        opacity: 0.5
                    }

                    DankButton {
                        focus: true
                        text: pluginApi?.tr("panel.clear-all") || "Clear All"
                        iconName: "delete"
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: -2 * 1
                        onClicked: pluginApi?.mainInstance?.wipeAll()
                    }
                } // End header RowLayout

                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: Theme.spacingM
                    clip: true
                    header: Item { width: Theme.spacingS }
                    footer: Item { width: Theme.spacingS }
                    currentIndex: root.selectedIndex
                    focus: false

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            listView.flick(wheel.angleDelta.y * 12, 0);
                            wheel.accepted = true;
                        }
                    }

                    model: root.filteredItems

                    Keys.onUpPressed: { searchInput.forceActiveFocus(); }
                    Keys.onLeftPressed: {
                        if (count > 0) {
                            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                            positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                    }
                    Keys.onRightPressed: {
                        if (count > 0) {
                            root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1);
                            positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                    }
                    Keys.onReturnPressed: {
                        if (count > 0 && root.selectedIndex >= 0 && root.selectedIndex < count) {
                            const item = root.filteredItems[root.selectedIndex];
                            if (item) {
                                root.pluginApi?.mainInstance?.copyToClipboard(item.id);
                                if (root.pluginApi) {
                                    root.pluginApi.closePanel(screen);
                                    const enterPaste = root.pluginApi?.pluginSettings?.autoPasteOnEnterSelect ?? false;
                                    if (enterPaste) {
                                        root.pluginApi.mainInstance?.triggerAutoPaste();
                                    }
                                }
                            }
                        }
                    }
                    Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                    Keys.onDeletePressed: {
                        if (count > 0 && root.selectedIndex >= 0 && root.selectedIndex < count) {
                            const item = root.filteredItems[root.selectedIndex];
                            if (item) {
                                root.pluginApi?.mainInstance?.deleteById(item.id);
                                if (root.selectedIndex >= count - 1) {
                                    root.selectedIndex = Math.max(0, count - 2);
                                }
                            }
                        }
                    }
                    Keys.onEscapePressed: {
                        if (root.pluginApi) {
                            root.pluginApi.closePanel(screen);
                        }
                    }
                    Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                    Keys.onPressed: event => {
                        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            const filterMap = {
                                [Qt.Key_1]: "",
                                [Qt.Key_2]: "Text",
                                [Qt.Key_3]: "Image",
                                [Qt.Key_4]: "Color",
                                [Qt.Key_5]: "Link",
                                [Qt.Key_6]: "Code",
                                [Qt.Key_7]: "Emoji",
                                [Qt.Key_8]: "File"
                            };
                            if (filterMap.hasOwnProperty(event.key)) {
                                root.filterType = filterMap[event.key];
                                event.accepted = true;
                            }
                        }
                    }

                    delegate: ClipboardCard {
                        clipboardItem: modelData
                        pluginApi: root.pluginApi
                        screen: root.currentScreen
                        panelRoot: root
                        fixedHeight: listView.height
                        selected: listView.activeFocus && index === root.selectedIndex
                        enableTodoIntegration: pluginApi?.pluginSettings?.todoEnabled ?? true
                        isPinned: {
                            const rev = root.pluginApi?.mainInstance?.pinnedRevision || 0;
                            const pinnedItems = root.pluginApi?.mainInstance?.pinnedItems || [];
                            return pinnedItems.some(p => p.id === clipboardId);
                        }
                        onClicked: {
                            root.selectedIndex = index;
                            root.pluginApi?.mainInstance?.copyToClipboard(clipboardId);
                            if (root.pluginApi) {
                                root.pluginApi.closePanel(screen);
                                const autoPaste = root.pluginApi.pluginSettings?.autoPasteOnClick ?? false;
                                const rmbOnly = root.pluginApi.pluginSettings?.autoPasteOnRightClick ?? false;
                                if (autoPaste && !rmbOnly) {
                                    root.pluginApi.mainInstance?.triggerAutoPaste();
                                }
                            }
                        }

                        onRightClicked: {
                            root.selectedIndex = index;
                            const autoPaste = root.pluginApi?.pluginSettings?.autoPasteOnClick ?? false;
                            const rmbOnly = root.pluginApi?.pluginSettings?.autoPasteOnRightClick ?? false;
                            if (autoPaste && rmbOnly) {
                                root.pluginApi?.mainInstance?.copyToClipboard(clipboardId);
                                if (root.pluginApi) {
                                    root.pluginApi.closePanel(screen);
                                    root.pluginApi.mainInstance?.triggerAutoPaste();
                                }
                            }
                        }

                        onDeleteClicked: { root.pluginApi?.mainInstance?.deleteById(clipboardId); }

                        onPinClicked: {
                            if (isPinned) {
                                root.pluginApi?.mainInstance?.unpinItem(clipboardId);
                                ToastService.showInfo(pluginApi?.tr("toast.item-unpinned") || "Item unpinned");
                            } else {
                                const pinnedItems = root.pluginApi?.mainInstance?.pinnedItems || [];
                                if (pinnedItems.length >= 100) {
                                    ToastService.showWarning((pluginApi?.tr("toast.max-pinned-items") || "Maximum {max} pinned items reached").replace("{max}", "100"));
                                } else {
                                    root.pluginApi?.mainInstance?.pinItem(clipboardId);
                                    ToastService.showInfo(pluginApi?.tr("toast.item-pinned") || "Item pinned");
                                }
                            }
                        }

                        onAddToTodoClicked: {
                            if (preview) {
                                root.pluginApi?.mainInstance?.addTodoWithText(preview.substring(0, 200), 0);
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: listView.count === 0
                        text: root.filterType || root.searchText
                            ? (pluginApi?.tr("panel.no-matches") || "No matching items")
                            : (pluginApi?.tr("panel.empty") || "Clipboard is empty")
                        color: Theme.surfaceVariantText
                    }
                } // End ListView
            } // End ColumnLayout
        } // End clipboardPanel

        // PINNED PANEL - Left side, vertical
        Rectangle {
            id: pinnedPanel
            property bool showPinned: pluginApi?.pluginSettings?.pincardsEnabled ?? true
            property bool showTodo: pluginApi?.pluginSettings?.todoEnabled ?? true
            visible: showPinned || showTodo
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: clipboardPanel.top
            anchors.bottomMargin: Theme.spacingM
            width: Math.min(300, screen?.width * 0.2 || 300)
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Math.max(0.2, Math.min(1.0, (pluginApi?.pluginSettings?.panelOpacityPinned ?? 100) / 100)))
            radius: Theme.cornerRadius
            opacity: 1.0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // Pinned header
                Item {
                    implicitHeight: pinnedHeaderColumn.implicitHeight
                    Layout.fillWidth: true
                    visible: pinnedPanel.showPinned

                    ColumnLayout {
                        id: pinnedHeaderColumn
                        anchors.fill: parent
                        spacing: Theme.spacingM

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            StyledText {
                                text: pluginApi?.tr("panel.pinned-title") || "Pinned Items"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeLarge
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text: {
                                    const items = root.pluginApi?.mainInstance?.pinnedItems || [];
                                    return items.length + " / 100";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                // Pinned list + empty label wrapped together
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: pinnedPanel.showPinned

                    FocusScope {
                        id: pinnedFocus
                        anchors.fill: parent
                        Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                        Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                if (pinnedListView.currentIndex < 0 && pinnedListView.count > 0) {
                                    pinnedListView.currentIndex = 0;
                                }
                                pinnedListView.forceActiveFocus();
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Theme.cornerRadius
                            color: "transparent"
                            border.width: pinnedFocus.activeFocus ? 1 : 0
                            border.color: Theme.outlineVariant
                            opacity: pinnedFocus.activeFocus ? 0.5 : 0
                            z: 2
                            Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                        }

                        ListView {
                            id: pinnedListView
                            anchors.fill: parent
                            orientation: ListView.Vertical
                            spacing: Theme.spacingS
                            clip: true
                            focus: true
                            keyNavigationWraps: true
                            Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                            Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            Keys.onReturnPressed: {
                                if (currentIndex < 0 || currentIndex >= count) return;
                                const item = model[currentIndex];
                                if (!item) return;
                                root.pluginApi?.mainInstance?.copyPinnedToClipboard(item.id);
                                if (root.pluginApi) {
                                    root.pluginApi.closePanel(screen);
                                    const enterPaste = root.pluginApi?.pluginSettings?.autoPasteOnEnterSelect ?? false;
                                    if (enterPaste) {
                                        root.pluginApi.mainInstance?.triggerAutoPaste();
                                    }
                                }
                            }
                            model: root.pluginApi?.mainInstance?.pinnedItems || []

                            ScrollBar.vertical: ScrollBar {
                                id: pinnedScrollBar
                                policy: ScrollBar.AsNeeded
                                visible: pinnedListView.contentHeight > pinnedListView.height
                                width: 6
                                minimumSize: 0.1
                                opacity: (hovered || pressed) ? 1.0 : 0.0
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.shortDuration }
                                }
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

                            delegate: ClipboardCard {
                                width: pinnedListView.width
                                panelRoot: root
                                clipboardItem: {
                                    return {
                                        "id": modelData.id,
                                        "preview": modelData.isImage ? "" : modelData.preview,
                                        "mime": modelData.mime || "text/plain",
                                        "isImage": modelData.isImage || false,
                                        "content": modelData.content || ""
                                    };
                                }
                                isPinned: true
                                pluginApi: root.pluginApi
                                screen: root.currentScreen
                                selected: pinnedFocus.activeFocus && pinnedListView.currentIndex === index
                                pinnedImageDataUrl: modelData.isImage ? modelData.content : ""

                                onClicked: {
                                    root.pluginApi?.mainInstance?.copyPinnedToClipboard(modelData.id);
                                    if (root.pluginApi) {
                                        root.pluginApi.closePanel(screen);
                                        const autoPaste = root.pluginApi.pluginSettings?.autoPasteOnClick ?? false;
                                        const rmbOnly = root.pluginApi.pluginSettings?.autoPasteOnRightClick ?? false;
                                        if (autoPaste && !rmbOnly) {
                                            root.pluginApi.mainInstance?.triggerAutoPaste();
                                        }
                                    }
                                }

                                onRightClicked: {
                                    const autoPaste = root.pluginApi?.pluginSettings?.autoPasteOnClick ?? false;
                                    const rmbOnly = root.pluginApi?.pluginSettings?.autoPasteOnRightClick ?? false;
                                    if (autoPaste && rmbOnly) {
                                        root.pluginApi?.mainInstance?.copyPinnedToClipboard(modelData.id);
                                        if (root.pluginApi) {
                                            root.pluginApi.closePanel(screen);
                                            root.pluginApi.mainInstance?.triggerAutoPaste();
                                        }
                                    }
                                }

                                onPinClicked: {
                                    root.pluginApi?.mainInstance?.unpinItem(modelData.id);
                                    ToastService.showInfo("Item unpinned");
                                }

                                onDeleteClicked: {
                                    root.pluginApi?.mainInstance?.unpinItem(modelData.id);
                                }
                            }

                            // Empty state label - correctly placed inside ListView
                            StyledText {
                                anchors.centerIn: parent
                                visible: pinnedListView.count === 0
                                text: pluginApi?.tr("panel.no-pinned") || "No pinned items"
                                color: Theme.surfaceVariantText
                            }
                        } // End pinnedListView
                    } // End pinnedFocus
                } // End pinned Item wrapper

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.4
                    visible: pinnedPanel.showPinned && pinnedPanel.showTodo
                }

                // ToDo section
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: pinnedPanel.showTodo

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: pluginApi?.tr("panel.todo-title") || "ToDo"
                                font.bold: true
                                font.pixelSize: Theme.fontSizeMedium
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text: {
                                    const todos = root.pluginApi?.mainInstance?.todos || [];
                                    let done = 0;
                                    for (let i = 0; i < todos.length; i++) {
                                        if (todos[i].completed) done++;
                                    }
                                    return done + " / " + todos.length;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }
                        }

                        FocusScope {
                            id: todoFocus
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                            Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    if (todoListView.currentIndex < 0 && todoListView.count > 0) {
                                        todoListView.currentIndex = 0;
                                    }
                                    todoListView.forceActiveFocus();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Theme.cornerRadius
                                color: "transparent"
                                border.width: todoFocus.activeFocus ? 1 : 0
                                border.color: Theme.outlineVariant
                                opacity: todoFocus.activeFocus ? 0.5 : 0
                                z: 2
                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            }

                            ListView {
                                id: todoListView
                                anchors.fill: parent
                                spacing: Theme.spacingXS
                                clip: true
                                focus: true
                                keyNavigationWraps: true
                                Keys.onTabPressed: event => { root.advanceTab(); event.accepted = true; }
                                Keys.onBacktabPressed: event => { root.reverseTab(); event.accepted = true; }
                                Keys.onReturnPressed: {
                                    if (currentIndex < 0 || currentIndex >= count) return;
                                    const item = model[currentIndex];
                                    if (item) root.pluginApi?.mainInstance?.toggleTodo(item.id);
                                }
                                model: root.pluginApi?.mainInstance?.todos || []
                                property int scrollGutter: Theme.spacingS

                                ScrollBar.vertical: ScrollBar {
                                    id: todoScrollBar
                                    policy: ScrollBar.AsNeeded
                                    visible: todoListView.contentHeight > todoListView.height
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

                                delegate: Item {
                                    width: todoListView.width - (todoScrollBar.visible ? (todoScrollBar.width + todoListView.scrollGutter) : 0)
                                    property int iconSize: 16
                                    property int buttonSize: 22
                                    property int innerPadding: Theme.spacingXS
                                    property int rowSpacing: Theme.spacingS
                                    property int rightGutter: Theme.spacingM
                                    property bool isHover: todoHoverArea.containsMouse
                                    property bool isCurrent: ListView.isCurrentItem

                                    implicitHeight: todoCard.height

                                    Rectangle {
                                        id: todoCard
                                        width: parent.width
                                        height: Math.max(40, todoText.implicitHeight + innerPadding * 2)
                                        radius: Theme.cornerRadius / 2
                                        color: isHover
                                            ? Qt.lighter(Theme.surfaceContainer, 1.08)
                                            : (isCurrent && todoFocus.activeFocus ? Qt.lighter(Theme.surfaceContainer, 1.12) : Theme.surfaceContainer)
                                        border.width: (isHover || (isCurrent && todoFocus.activeFocus)) ? 1 : 0
                                        border.color: Theme.outline

                                        Row {
                                            id: contentRow
                                            anchors.fill: parent
                                            anchors.margins: innerPadding
                                            spacing: rowSpacing

                                            DankIcon {
                                                id: todoCheck
                                                width: iconSize
                                                height: iconSize
                                                name: modelData.completed ? "check_circle" : "radio_button_unchecked"
                                                size: iconSize
                                                color: modelData.completed ? Theme.primary : Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                id: todoText
                                                width: Math.max(0, parent.width - todoCheck.width - (modelData.completed ? buttonSize : 0) - rowSpacing * 2 - rightGutter)
                                                text: modelData.text || ""
                                                color: Theme.surfaceText
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideNone
                                            }

                                            DankActionButton {
                                                id: todoDeleteButton
                                                visible: modelData.completed
                                                width: buttonSize
                                                height: buttonSize
                                                iconName: "delete"
                                                iconColor: Theme.surfaceVariantText
                                                backgroundColor: "transparent"
                                                tooltipText: "Delete"
                                                onClicked: root.pluginApi?.mainInstance?.deleteTodo(modelData.id)
                                            }

                                            Item {
                                                width: rightGutter
                                                height: 1
                                            }
                                        }

                                        MouseArea {
                                            id: todoHoverArea
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: todoDeleteButton.visible ? (todoCard.width - buttonSize - rowSpacing) : todoCard.width
                                            hoverEnabled: true
                                            onClicked: root.pluginApi?.mainInstance?.toggleTodo(modelData.id)
                                        }
                                    }
                                } // End todo delegate

                                StyledText {
                                    anchors.centerIn: parent
                                    visible: todoListView.count === 0
                                    text: pluginApi?.tr("panel.no-todos") || "No todos yet"
                                    color: Theme.surfaceVariantText
                                }
                            } // End todoListView
                        } // End todoFocus
                    } // End todo ColumnLayout
                } // End todo Item
            } // End pinnedPanel ColumnLayout
        } // End pinnedPanel

        // Vertical separator between pinned and notecards
        Rectangle {
            visible: (pluginApi?.pluginSettings?.showPanelSeparator ?? true) && pinnedPanel.visible && noteCardsPanel.visible
            anchors.left: pinnedPanel.right
            anchors.top: parent.top
            anchors.bottom: clipboardPanel.top
            anchors.bottomMargin: Theme.spacingM
            width: 1
            color: "transparent"

            Column {
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: 27
                    Rectangle {
                        width: 2
                        height: 8
                        color: Theme.outline
                        opacity: 0.7
                    }
                }
            }
        }

        // NOTECARDS PANEL - Middle space (between pinned and clipboard)
        Item {
            id: noteCardsPanel
            visible: pluginApi?.pluginSettings?.notecardsEnabled ?? true
            anchors.left: pinnedPanel.visible ? pinnedPanel.right : parent.left
            anchors.leftMargin: pinnedPanel.visible ? Theme.spacingM : 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: clipboardPanel.top
            anchors.bottomMargin: Theme.spacingM

            NoteCardsPanel {
                id: notecardsPanelInstance
                anchors.fill: parent
                pluginApi: root.pluginApi
                screen: root.currentScreen
            }
        } // End noteCardsPanel
    } // End mainContainer

    Component.onCompleted: {
        selectedIndex = 0;
        filterType = "";
        searchText = "";
        pluginApi?.mainInstance?.list(screen?.width || 100);
        listView.forceActiveFocus();
    }
}
