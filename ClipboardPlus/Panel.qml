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

    // Reset selection when filter changes
    onFilterTypeChanged: selectedIndex = 0
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
            opacity: 1.0  // Override global panel opacity

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

                    Item {
                        Layout.fillWidth: true
                    }

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
                                } else {
                                    root.onEscapePressed();
                                }
                            }
                            Keys.onLeftPressed: event => {
                                if (searchField.cursorPosition === 0) {
                                    root.onLeftPressed();
                                    event.accepted = true;
                                }
                            }
                            Keys.onRightPressed: event => {
                                if (searchField.cursorPosition === text.length) {
                                    root.onRightPressed();
                                    event.accepted = true;
                                }
                            }
                            Keys.onReturnPressed: root.onReturnPressed()
                            Keys.onEnterPressed: root.onReturnPressed()
                            Keys.onTabPressed: event => {
                                root.filterType = "Text";
                                event.accepted = true;
                            }
                            Keys.onUpPressed: event => {
                                event.accepted = true;
                            }
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

                    Item {
                        Layout.fillWidth: true
                    }

                    // Filter type -> accent color key mapping (mirrors ClipboardCard defaults)
                    // All/Text/Link/Emoji -> mPrimary, Image/File -> mTertiary, Color/Code -> mSecondary
                    RowLayout {
                        spacing: Theme.spacingXS
                        Layout.alignment: Qt.AlignVCenter

                        // --- ALL ---
                        Item {
                            readonly property string fType: ""
                            readonly property color accentColor: Theme.primary
                            readonly property color accentFgColor: Theme.primaryText
                            readonly property bool isActive: root.filterType === fType
                            readonly property int itemCount: (pluginApi?.mainInstance?.items || []).length
                            // Expand slightly so the burst ring has room without clipping
                            width: btnAll.width + Theme.fontSizeSmall
                            height: btnAll.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnAll
                                anchors.centerIn: parent
                                focus: true
                                iconName: "apps"
                                tooltipText: pluginApi?.tr("panel.filter-all") || "All"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = ""
                                Keys.onTabPressed: {
                                    root.filterType = "";
                                    event.accepted = true;
                                }
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

                            // Count badge - matches groupedWorkspaceNumberContainer pattern
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }

                                StyledText {
                                    id: badgeAll
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnText.width + Theme.fontSizeSmall
                            height: btnText.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnText
                                anchors.centerIn: parent
                                focus: true
                                iconName: "format_align_left"
                                tooltipText: pluginApi?.tr("panel.filter-text") || "Text"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Text"
                                Keys.onTabPressed: {
                                    root.filterType = "Image";
                                    event.accepted = true;
                                }
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnImage.width + Theme.fontSizeSmall
                            height: btnImage.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnImage
                                anchors.centerIn: parent
                                focus: true
                                iconName: "image"
                                tooltipText: pluginApi?.tr("panel.filter-images") || "Images"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Image"
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeImage
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnColorFilter.width + Theme.fontSizeSmall
                            height: btnColorFilter.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnColorFilter
                                anchors.centerIn: parent
                                focus: true
                                iconName: "palette"
                                tooltipText: pluginApi?.tr("panel.filter-colors") || "Colors"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Color"
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeColorFilter
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnLink.width + Theme.fontSizeSmall
                            height: btnLink.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnLink
                                anchors.centerIn: parent
                                focus: true
                                iconName: "link"
                                tooltipText: pluginApi?.tr("panel.filter-links") || "Links"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Link"
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeLink
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnCode.width + Theme.fontSizeSmall
                            height: btnCode.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnCode
                                anchors.centerIn: parent
                                focus: true
                                iconName: "code"
                                tooltipText: pluginApi?.tr("panel.filter-code") || "Code"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Code"
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeCode
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnEmoji.width + Theme.fontSizeSmall
                            height: btnEmoji.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnEmoji
                                anchors.centerIn: parent
                                focus: true
                                iconName: "sentiment_satisfied"
                                tooltipText: pluginApi?.tr("panel.filter-emoji") || "Emoji"
                                backgroundColor: parent.isActive ? Theme.primary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "Emoji"
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeEmoji
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
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
                            width: btnFile.width + Theme.fontSizeSmall
                            height: btnFile.height + Theme.fontSizeSmall + 8

                            DankActionButton {
                                id: btnFile
                                anchors.centerIn: parent
                                focus: true
                                iconName: "description"
                                tooltipText: pluginApi?.tr("panel.filter-files") || "Files"
                                backgroundColor: parent.isActive ? Theme.secondary : Theme.surfaceContainer
                                iconColor: parent.isActive ? Theme.primaryText : Theme.surfaceText
                                onClicked: root.filterType = "File"
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
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on color {
                                        enabled: true
                                        ColorAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }
                                StyledText {
                                    id: badgeFile
                                    anchors.centerIn: parent
                                    text: parent.parent.itemCount > 99 ? "99+" : parent.parent.itemCount
                                    font.pixelSize: (typeof Style !== "undefined") ? Theme.fontSizeSmall * 0.75 : 8
                                    font.bold: true
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

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
                }

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

                    Keys.onUpPressed: {
                        searchInput.forceActiveFocus();
                    }
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
                    Keys.onTabPressed: {
                        // Cycle through filters: All -> Text -> Image -> Color -> Link -> Code -> Emoji -> File -> All
                        const filters = ["", "Text", "Image", "Color", "Link", "Code", "Emoji", "File"];
                        const currentIdx = filters.indexOf(root.filterType);
                        const nextIdx = (currentIdx + 1) % filters.length;
                        root.filterType = filters[nextIdx];
                    }
                    Keys.onBacktabPressed: {
                        // Shift+Tab = cycle backwards
                        const filters = ["", "Text", "Image", "Color", "Link", "Code", "Emoji", "File"];
                        const currentIdx = filters.indexOf(root.filterType);
                        const prevIdx = (currentIdx - 1 + filters.length) % filters.length;
                        root.filterType = filters[prevIdx];
                    }
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
                        selected: index === root.selectedIndex
                        enableTodoIntegration: pluginApi?.pluginSettings?.todoEnabled ?? true
                        isPinned: {
                            // Force re-evaluation when pinnedRevision changes
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

                        onDeleteClicked: {
                            root.pluginApi?.mainInstance?.deleteById(clipboardId);
                        }

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
                                // Direct call to Main.qml function (no internal IPC)
                                root.pluginApi?.mainInstance?.addTodoWithText(preview.substring(0, 200), 0);
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: listView.count === 0
                        text: root.filterType || root.searchText ? (pluginApi?.tr("panel.no-matches") || "No matching items") : (pluginApi?.tr("panel.empty") || "Clipboard is empty")
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }  // End clipboardPanel

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
            opacity: 1.0  // Override global panel opacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

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

                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                ListView {
                    id: pinnedListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: pinnedPanel.showPinned
                    orientation: ListView.Vertical
                    spacing: Theme.spacingS
                    clip: true

                    model: root.pluginApi?.mainInstance?.pinnedItems || []
                    property bool hoverScroll: false

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
                                "preview": modelData.isImage ? "" : modelData.preview  // Don't show binary preview
                                ,
                                "mime": modelData.mime || "text/plain",
                                "isImage": modelData.isImage || false,
                                "content": modelData.content || ""  // For images, this is data URL
                            };
                        }
                        isPinned: true
                        pluginApi: root.pluginApi
                        screen: root.currentScreen
                        selected: false
                        pinnedImageDataUrl: modelData.isImage ? modelData.content : ""  // Pass data URL directly

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

                    StyledText {
                        anchors.centerIn: parent
                        visible: pinnedListView.count === 0
                        text: "No pinned items"
                        color: Theme.surfaceVariantText
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.4
                    visible: pinnedPanel.showPinned && pinnedPanel.showTodo
                }

                // ToDo section (stored in plugin settings)
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
                                        if (todos[i].completed)
                                            done++;
                                    }
                                    return done + " / " + todos.length;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }
                        }

                        ListView {
                            id: todoListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Theme.spacingXS
                            clip: true
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

                                implicitHeight: todoCard.height

                                Rectangle {
                                    id: todoCard
                                    width: parent.width
                                    height: Math.max(40, todoText.implicitHeight + innerPadding * 2)
                                    radius: Theme.cornerRadius / 2
                                    color: isHover ? Qt.lighter(Theme.surfaceContainer, 1.08) : Theme.surfaceContainer
                                    border.width: isHover ? 1 : 0
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

                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: todoListView.count === 0
                                text: pluginApi?.tr("panel.no-todos") || "No todos yet"
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }  // End pinnedPanel & todo

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
        }  // End noteCardsPanel
    }  // End mainContainer

    Component.onCompleted: {
        selectedIndex = 0;
        filterType = "";
        searchText = "";
        pluginApi?.mainInstance?.list(screen?.width || 100);
        listView.forceActiveFocus();
    }
}
