import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "clipboardPlus"
    pluginId: "clipboardPlus"

    property bool pincardsEnabled: pluginData.pincardsEnabled !== undefined ? pluginData.pincardsEnabled : true
    property bool notecardsEnabled: pluginData.notecardsEnabled !== undefined ? pluginData.notecardsEnabled : true
    property bool todoEnabled: pluginData.todoEnabled !== undefined ? pluginData.todoEnabled : true
    property bool showCloseButton: pluginData.showCloseButton !== undefined ? pluginData.showCloseButton : true
    property bool fullscreenMode: pluginData.fullscreenMode !== undefined ? pluginData.fullscreenMode : true
    property bool hidePanelBackground: pluginData.hidePanelBackground !== undefined ? pluginData.hidePanelBackground : false
    property bool showBarWidget: pluginData.showBarWidget !== undefined ? pluginData.showBarWidget : true
    property string dataBasePath: pluginData.dataBasePath !== undefined ? pluginData.dataBasePath : ""
    property string exportPath: pluginData.exportPath !== undefined ? pluginData.exportPath : ""
    property bool listenClipboardWhileOpen: pluginData.listenClipboardWhileOpen !== undefined ? pluginData.listenClipboardWhileOpen : false
    property bool autoPasteOnClick: pluginData.autoPasteOnClick !== undefined ? pluginData.autoPasteOnClick : (pluginData.autoPaste !== undefined ? pluginData.autoPaste : false)
    property bool autoPasteOnRightClick: pluginData.autoPasteOnRightClick !== undefined ? pluginData.autoPasteOnRightClick : false
    property bool autoPasteOnEnterSelect: pluginData.autoPasteOnEnterSelect !== undefined ? pluginData.autoPasteOnEnterSelect : false
    property int autoPasteDelay: pluginData.autoPasteDelay !== undefined ? pluginData.autoPasteDelay : 300
    property int panelDimOpacity: pluginData.panelDimOpacity !== undefined ? pluginData.panelDimOpacity : 35
    property bool closeOnOutsideClick: pluginData.closeOnOutsideClick !== undefined ? pluginData.closeOnOutsideClick : true
    property int maxPinnedTextMb: pluginData.maxPinnedTextMb !== undefined ? pluginData.maxPinnedTextMb : 1
    property int maxPinnedImageMb: pluginData.maxPinnedImageMb !== undefined ? pluginData.maxPinnedImageMb : 5
    property int panelOpacityPinned: pluginData.panelOpacityPinned !== undefined ? pluginData.panelOpacityPinned : 100
    property int panelOpacityClipboard: pluginData.panelOpacityClipboard !== undefined ? pluginData.panelOpacityClipboard : 100
    property int backgroundOpacity: pluginData.backgroundOpacity !== undefined ? pluginData.backgroundOpacity : panelDimOpacity
    property bool showPanelSeparator: pluginData.showPanelSeparator !== undefined ? pluginData.showPanelSeparator : true
    property bool enableAnimations: pluginData.enableAnimations !== undefined ? pluginData.enableAnimations : true
    property bool enableTabNavigation: pluginData.enableTabNavigation !== undefined ? pluginData.enableTabNavigation : true
    property bool enableFullTextDecode: pluginData.enableFullTextDecode !== undefined ? pluginData.enableFullTextDecode : false
    property int maxDecodedTextLength: pluginData.maxDecodedTextLength !== undefined ? pluginData.maxDecodedTextLength : 250
    property string tabOrder: pluginData.tabOrder !== undefined ? pluginData.tabOrder : ""
    property string tabOrderEnabled: pluginData.tabOrderEnabled !== undefined ? pluginData.tabOrderEnabled : ""

    function screenKey(screen) {
        return screen?.name || "default";
    }

    function resolveScreen(screen) {
        if (screen)
            return screen;
        const screens = Quickshell.screens || [];
        const focusedName = BarWidgetService.getFocusedScreenName();
        if (focusedName) {
            const focused = screens.find(s => s && s.name === focusedName);
            if (focused)
                return focused;
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function isPanelOpen(screen) {
        const resolved = resolveScreen(screen);
        const key = screenKey(resolved);
        return panelByName[key] ? panelByName[key].visible : false;
    }

    function setPanelVisible(screen, visible) {
        const resolved = resolveScreen(screen);
        const key = screenKey(resolved);
        if (visible) {
            // Close other panels when opening on a new screen
            for (const name in panelByName) {
                if (name !== key && panelByName[name]) {
                    panelByName[name].setOpen(false);
                }
            }
        }
        const panel = panelByName[key];
        if (panel) {
            panel.setOpen(visible);
        }
    }

    function updateBarVisibility() {
        if (root.showBarWidget) {
            root.clearVisibilityOverride();
        } else {
            root.setVisibilityOverride(false);
        }
    }

    QtObject {
        id: clipboardPlusApi

        property var pluginSettings: settingsProxy
        property var mainInstance: null
        property var manifest: ({
                id: "clipboardPlus",
                name: "ClipBoard+"
            })

        function tr(key) {
            return "";
        }

        function saveSettings() {
        }

        function withCurrentScreen(callback) {
            const screens = Quickshell.screens || [];
            const focusedName = BarWidgetService.getFocusedScreenName();
            let screen = screens.length > 0 ? screens[0] : null;
            if (focusedName) {
                const focused = screens.find(s => s && s.name === focusedName);
                if (focused)
                    screen = focused;
            }
            if (callback && screen)
                callback(screen);
        }

        function openPanel(screen) {
            root.setPanelVisible(screen, true);
        }

        function closePanel(screen) {
            root.setPanelVisible(screen, false);
        }

        function togglePanel(screen) {
            root.setPanelVisible(screen, !root.isPanelOpen(screen));
        }
    }

    QtObject {
        id: settingsProxy
        property bool pincardsEnabled: root.pincardsEnabled
        property bool notecardsEnabled: root.notecardsEnabled
        property bool todoEnabled: root.todoEnabled
        property bool showCloseButton: root.showCloseButton
        property bool fullscreenMode: root.fullscreenMode
        property bool hidePanelBackground: root.hidePanelBackground
        property string dataBasePath: root.dataBasePath
        property string exportPath: root.exportPath
        property bool listenClipboardWhileOpen: root.listenClipboardWhileOpen
        property bool autoPasteOnClick: root.autoPasteOnClick
        property bool autoPasteOnRightClick: root.autoPasteOnRightClick
        property bool autoPasteOnEnterSelect: root.autoPasteOnEnterSelect
        property int autoPasteDelay: root.autoPasteDelay
        property int maxPinnedTextMb: root.maxPinnedTextMb
        property int maxPinnedImageMb: root.maxPinnedImageMb
        property int panelOpacityPinned: root.panelOpacityPinned
        property int panelOpacityClipboard: root.panelOpacityClipboard
        property int backgroundOpacity: root.backgroundOpacity
        property bool showPanelSeparator: root.showPanelSeparator
        property bool enableAnimations: root.enableAnimations
        property bool enableTabNavigation: root.enableTabNavigation
        property bool closeOnOutsideClick: root.closeOnOutsideClick
        property bool enableFullTextDecode: root.enableFullTextDecode
        property int maxDecodedTextLength: root.maxDecodedTextLength
        property string tabOrder: root.tabOrder
        property string tabOrderEnabled: root.tabOrderEnabled
    }

    property var panelByName: ({})

    Main {
        id: main
        pluginApi: clipboardPlusApi
    }

    Component.onCompleted: {
        clipboardPlusApi.mainInstance = main;
        ClipboardPlusState.mainInstance = main;
        updateBarVisibility();
    }
    onShowBarWidgetChanged: updateBarVisibility()

    pillClickAction: (x, y, width, section, screen) => {
        clipboardPlusApi.togglePanel(screen);
    }

    pillRightClickAction: () => {
        PopoutService.openSettingsWithTab("plugins");
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: icon.size
            implicitHeight: icon.size

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: "content_paste"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: icon.size
            implicitHeight: icon.size

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: "content_paste"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
            }
        }
    }

    Instantiator {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panelWindow
            required property var modelData

            screen: modelData
            visible: false
            property bool open: false
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: panelWindow.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "dms-clipboardPlus-panel-" + (screen?.name || "unknown")
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            Component.onCompleted: {
                const key = screen?.name || "default";
                panelByName[key] = panelWindow;
            }

            onVisibleChanged: {
                if (visible) {
                    panelContent.forceActiveFocus();
                }
            }

            Component.onDestruction: {
                const key = screen?.name || "default";
                if (panelByName[key] === panelWindow) {
                    const copy = Object.assign({}, panelByName);
                    delete copy[key];
                    panelByName = copy;
                }
            }

            function setOpen(state) {
                if (state) {
                    open = true;
                    visible = true;
                    if (closeTimer.running)
                        closeTimer.stop();
                } else {
                    open = false;
                    if (panelContent.animationsEnabled) {
                        closeTimer.restart();
                    } else {
                        visible = false;
                    }
                }
            }

            Timer {
                id: closeTimer
                interval: 200
                repeat: false
                onTriggered: {
                    if (!panelWindow.open) {
                        panelWindow.visible = false;
                    }
                }
            }

            Panel {
                id: panelContent
                anchors.fill: parent
                pluginApi: clipboardPlusApi
                screen: panelWindow.screen
                panelOpen: panelWindow.open
            }
        }
    }
}
