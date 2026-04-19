import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "media-player-plus"
    property bool popoutVisibleState: false

    pillRightClickAction: () => {
        if (root.rightClickOpensSettings)
            PopoutService.openSettingsWithTab("plugins");
    }
    popoutWidth: root.isVertical ? root.popoutPanelWidthVertical : root.popoutPanelWidthHorizontal
    popoutHeight: root.isVertical ? root.popoutPanelHeightVertical : root.popoutPanelHeightHorizontal

    property bool showHorizontalTitle: pluginData.showHorizontalTitle !== undefined ? pluginData.showHorizontalTitle : true
    property bool showHorizontalSkipControls: pluginData.showHorizontalSkipControls !== undefined ? pluginData.showHorizontalSkipControls : true
    property bool showHorizontalPlayPause: pluginData.showHorizontalPlayPause !== undefined ? pluginData.showHorizontalPlayPause : true
    property bool showVerticalTitle: pluginData.showVerticalTitle !== undefined ? pluginData.showVerticalTitle : true
    property bool showVerticalSkipControls: pluginData.showVerticalSkipControls !== undefined ? pluginData.showVerticalSkipControls : true
    property bool showVerticalPlayPause: pluginData.showVerticalPlayPause !== undefined ? pluginData.showVerticalPlayPause : true
    property bool rightClickOpensSettings: pluginData.rightClickOpensSettings !== undefined ? pluginData.rightClickOpensSettings : true
    property bool showHorizontalVisualizer: pluginData.showHorizontalVisualizer !== undefined ? pluginData.showHorizontalVisualizer : (pluginData.showVisualizer !== undefined ? pluginData.showVisualizer : true)
    property bool showVerticalVisualizer: pluginData.showVerticalVisualizer !== undefined ? pluginData.showVerticalVisualizer : (pluginData.showVisualizer !== undefined ? pluginData.showVisualizer : true)
    property bool showWhenNoPlayer: pluginData.showWhenNoPlayer !== undefined ? pluginData.showWhenNoPlayer : false
    property int horizontalTitleExtent: pluginData.horizontalTitleExtent !== undefined ? pluginData.horizontalTitleExtent : 160
    property int verticalTitleExtent: pluginData.verticalTitleExtent !== undefined ? pluginData.verticalTitleExtent : 88
    property int popoutPanelWidthHorizontal: pluginData.popoutPanelWidthHorizontal !== undefined ? pluginData.popoutPanelWidthHorizontal : (pluginData.popoutPanelWidth !== undefined ? pluginData.popoutPanelWidth : 560)
    property int popoutPanelWidthVertical: pluginData.popoutPanelWidthVertical !== undefined ? pluginData.popoutPanelWidthVertical : (pluginData.popoutPanelWidth !== undefined ? pluginData.popoutPanelWidth : 560)
    property int popoutPanelHeightHorizontal: pluginData.popoutPanelHeightHorizontal !== undefined ? pluginData.popoutPanelHeightHorizontal : (pluginData.popoutPanelHeight !== undefined ? pluginData.popoutPanelHeight : 420)
    property int popoutPanelHeightVertical: pluginData.popoutPanelHeightVertical !== undefined ? pluginData.popoutPanelHeightVertical : (pluginData.popoutPanelHeight !== undefined ? pluginData.popoutPanelHeight : 420)
    property int horizontalVisualizerWidth: pluginData.horizontalVisualizerWidth !== undefined ? pluginData.horizontalVisualizerWidth : (pluginData.visualizerWidth !== undefined ? pluginData.visualizerWidth : 20)
    property int horizontalVisualizerBars: pluginData.horizontalVisualizerBars !== undefined ? pluginData.horizontalVisualizerBars : (pluginData.visualizerBars !== undefined ? pluginData.visualizerBars : 6)
    property bool horizontalVisualizerStretchToWidth: pluginData.horizontalVisualizerStretchToWidth !== undefined ? pluginData.horizontalVisualizerStretchToWidth : (pluginData.visualizerStretchToWidth !== undefined ? pluginData.visualizerStretchToWidth : false)
    property int verticalVisualizerWidth: pluginData.verticalVisualizerWidth !== undefined ? pluginData.verticalVisualizerWidth : (pluginData.visualizerWidth !== undefined ? pluginData.visualizerWidth : 20)
    property int verticalVisualizerBars: pluginData.verticalVisualizerBars !== undefined ? pluginData.verticalVisualizerBars : (pluginData.visualizerBars !== undefined ? pluginData.visualizerBars : 6)
    property bool verticalVisualizerStretchToWidth: pluginData.verticalVisualizerStretchToWidth !== undefined ? pluginData.verticalVisualizerStretchToWidth : (pluginData.visualizerStretchToWidth !== undefined ? pluginData.visualizerStretchToWidth : false)
    property string horizontalTitleScrollBehavior: pluginData.horizontalTitleScrollBehavior !== undefined ? pluginData.horizontalTitleScrollBehavior : "never"
    property int horizontalTitleScrollSpeed: pluginData.horizontalTitleScrollSpeed !== undefined ? pluginData.horizontalTitleScrollSpeed : 28
    property string verticalTitleScrollBehavior: pluginData.verticalTitleScrollBehavior !== undefined ? pluginData.verticalTitleScrollBehavior : ((pluginData.scrollVerticalTitle !== undefined && pluginData.scrollVerticalTitle) ? "always" : "never")
    property int verticalTitleScrollSpeed: pluginData.verticalTitleScrollSpeed !== undefined ? pluginData.verticalTitleScrollSpeed : 28
    property bool showHorizontalTitleBackground: pluginData.showHorizontalTitleBackground !== undefined ? pluginData.showHorizontalTitleBackground : false
    property bool showVerticalTitleBackground: pluginData.showVerticalTitleBackground !== undefined ? pluginData.showVerticalTitleBackground : false
    property string horizontalTitleBackgroundColorKey: pluginData.horizontalTitleBackgroundColorKey || (pluginData.titleBackgroundColorKey || "surfaceContainer")
    property string horizontalTitleTextColorKey: pluginData.horizontalTitleTextColorKey || (pluginData.titleTextColorKey || "widgetText")
    property string verticalTitleBackgroundColorKey: pluginData.verticalTitleBackgroundColorKey || horizontalTitleBackgroundColorKey
    property string verticalTitleTextColorKey: pluginData.verticalTitleTextColorKey || horizontalTitleTextColorKey
    property int horizontalTitlePadding: pluginData.horizontalTitlePadding !== undefined ? pluginData.horizontalTitlePadding : 4
    property int horizontalTitleRadius: pluginData.horizontalTitleRadius !== undefined ? pluginData.horizontalTitleRadius : 12
    property int verticalTitlePadding: pluginData.verticalTitlePadding !== undefined ? pluginData.verticalTitlePadding : 4
    property int verticalTitleRadius: pluginData.verticalTitleRadius !== undefined ? pluginData.verticalTitleRadius : 12
    property int popoutTitleMaxLines: pluginData.popoutTitleMaxLines !== undefined ? parseInt(pluginData.popoutTitleMaxLines) : 1
    property bool showPopoutInnerBackground: pluginData.showPopoutInnerBackground !== undefined ? pluginData.showPopoutInnerBackground : false

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: !!(activePlayer && (((activePlayer.trackTitle || "").length > 0) || ((activePlayer.trackArtist || "").length > 0) || activePlayer.playbackState === MprisPlaybackState.Playing))
    readonly property bool showWidget: playerAvailable || showWhenNoPlayer
    readonly property int iconUnit: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
    readonly property int textPixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)

    function displayText() {
        if (!activePlayer) {
            return showWhenNoPlayer ? "No media" : "";
        }
        if (!root.playerAvailable)
            return showWhenNoPlayer ? "No media" : "";
        const title = activePlayer.trackTitle || "";
        const artist = activePlayer.trackArtist || "";
        if (title.length === 0 && artist.length === 0) {
            return activePlayer.identity || "Media";
        }
        return artist.length > 0 ? title + " • " + artist : title;
    }

    function verticalDisplayText() {
        const source = root.displayText().trim().replace(/\s*•\s*/g, "\n\n").replace(/ /g, "\n");
        if (source.length === 0)
            return "";
        const lines = [];
        for (let i = 0; i < source.length; i++) {
            const ch = source[i];
            if (ch === "\n") {
                lines.push("");
            } else {
                lines.push(ch);
            }
        }
        return lines.join("\n");
    }

    function togglePlayback() {
        if (activePlayer)
            activePlayer.togglePlaying();
    }

    function previousTrack() {
        if (activePlayer)
            MprisController.previousOrRewind();
    }

    function nextTrack() {
        if (activePlayer)
            activePlayer.next();
    }

    function buttonBg(hovered, emphasized) {
        if (!playerAvailable)
            return "transparent";
        if (emphasized)
            return activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? Theme.primary : Theme.primaryHover;
        return hovered ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent";
    }

    function themeColorFromKey(key, fallback) {
        switch (key) {
        case "widgetText":
            return Theme.widgetTextColor;
        case "primary":
            return Theme.primary;
        case "primaryText":
            return Theme.primaryText;
        case "primaryContainer":
            return Theme.primaryContainer;
        case "secondary":
            return Theme.secondary;
        case "surface":
            return Theme.surface;
        case "surfaceText":
            return Theme.surfaceText;
        case "surfaceVariant":
            return Theme.surfaceVariant;
        case "surfaceVariantText":
            return Theme.surfaceVariantText;
        case "surfaceTint":
            return Theme.surfaceTint;
        case "background":
            return Theme.background;
        case "backgroundText":
            return Theme.backgroundText;
        case "outline":
            return Theme.outline;
        case "surfaceContainer":
            return Theme.surfaceContainer;
        case "surfaceContainerHigh":
            return Theme.surfaceContainerHigh;
        case "surfaceContainerHighest":
            return Theme.surfaceContainerHighest;
        case "error":
            return Theme.error;
        case "warning":
            return Theme.warning;
        case "info":
            return Theme.info;
        default:
            return fallback;
        }
    }

    readonly property color resolvedHorizontalTitleBackgroundColor: themeColorFromKey(horizontalTitleBackgroundColorKey, Theme.surfaceContainer)
    readonly property color resolvedHorizontalTitleTextColor: themeColorFromKey(horizontalTitleTextColorKey, Theme.widgetTextColor)
    readonly property color resolvedVerticalTitleBackgroundColor: themeColorFromKey(verticalTitleBackgroundColorKey, resolvedHorizontalTitleBackgroundColor)
    readonly property color resolvedVerticalTitleTextColor: themeColorFromKey(verticalTitleTextColorKey, resolvedHorizontalTitleTextColor)
    readonly property int activePopoutHeight: root.isVertical ? root.popoutPanelHeightVertical : root.popoutPanelHeightHorizontal
    property bool showPopoutArtworkBackdrop: pluginData.showPopoutArtworkBackdrop !== undefined ? pluginData.showPopoutArtworkBackdrop : true

    IpcHandler {
        target: "mediaPlayerPlus"

        function openPopout() {
            root.ipcOpenPopout();
        }
        function closePopout() {
            root.ipcClosePopout();
        }
        function togglePopout() {
            root.ipcTogglePopout();
        }
    }

    function ipcOpenPopout() {
        if (!root.popoutVisibleState && typeof root.triggerPopout === "function")
            root.triggerPopout();
    }

    function ipcClosePopout() {
        if (typeof root.closePopout === "function")
            root.closePopout();
    }

    function ipcTogglePopout() {
        if (root.popoutVisibleState) {
            root.ipcClosePopout();
        } else {
            root.ipcOpenPopout();
        }
    }

    popoutContent: Component {
        MediaPlayerPlusPopout {
            activePlayer: root.activePlayer
            preferredHeight: Math.max(0, root.activePopoutHeight - Theme.spacingS * 2)
            titleMaxLines: root.popoutTitleMaxLines
            showInnerBackground: root.showPopoutInnerBackground
            showArtworkBackdrop: root.showPopoutArtworkBackdrop
            onPopoutOpened: root.popoutVisibleState = true
            onPopoutClosed: root.popoutVisibleState = false
        }
    }

    component ControlButton: Rectangle {
        id: buttonRoot
        property string iconName: ""
        property bool emphasized: false
        property bool enabledState: root.playerAvailable
        signal clicked

        width: emphasized ? root.iconUnit + 4 : root.iconUnit
        height: width
        radius: width / 2
        color: root.buttonBg(buttonArea.containsMouse, emphasized)
        opacity: enabledState ? 1 : 0.35

        DankIcon {
            anchors.centerIn: parent
            name: buttonRoot.iconName
            size: emphasized ? Math.max(12, root.iconUnit - 8) : Math.max(11, root.iconUnit - 8)
            color: buttonRoot.emphasized && root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? Theme.background : Theme.widgetTextColor
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: buttonRoot.enabledState
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: buttonRoot.clicked()
        }
    }

    component HorizontalMediaButton: Rectangle {
        id: buttonRoot
        property string iconName: ""
        property bool emphasized: false
        property bool enabledState: root.playerAvailable
        signal clicked

        width: emphasized ? 24 : 20
        height: width
        radius: width / 2
        color: {
            if (!root.playerAvailable)
                return "transparent";
            if (emphasized)
                return root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? Theme.primary : Theme.primaryHover;
            return buttonArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent";
        }
        opacity: enabledState ? 1 : 0.3

        DankIcon {
            anchors.centerIn: parent
            name: buttonRoot.iconName
            size: buttonRoot.emphasized ? 14 : 12
            color: buttonRoot.emphasized && root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? Theme.background : (buttonRoot.emphasized ? Theme.primary : Theme.widgetTextColor)
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: buttonRoot.enabledState
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: buttonRoot.clicked()
        }
    }

    horizontalBarPill: root.showWidget ? horizontalBarPillComponent : null

    Component {
        id: horizontalBarPillComponent

        Item {
            implicitWidth: root.showWidget ? mediaRow.implicitWidth : 0
            implicitHeight: root.showWidget ? mediaRow.implicitHeight : 0
            visible: root.showWidget

            Row {
                id: mediaRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Row {
                    id: mediaInfoRow
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: Math.max(20, root.horizontalVisualizerWidth)
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showHorizontalVisualizer

                        MediaVisualizer {
                            anchors.centerIn: parent
                            width: root.horizontalVisualizerWidth
                            height: 20
                            barSpan: root.horizontalVisualizerWidth
                            barCount: root.horizontalVisualizerBars
                            stretchToWidth: root.horizontalVisualizerStretchToWidth
                            visible: root.playerAvailable
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "music_note"
                            size: 20
                            color: Theme.primary
                            visible: !root.playerAvailable || !root.showHorizontalVisualizer
                        }
                    }

                    Item {
                        id: horizontalTitleClip
                        readonly property real titleHorizontalPadding: root.showHorizontalTitleBackground ? root.horizontalTitlePadding * 2 : 0
                        width: Math.min(root.horizontalTitleExtent, Math.max(horizontalTitleText.implicitWidth + titleHorizontalPadding, root.textPixelSize + titleHorizontalPadding))
                        visible: root.showHorizontalTitle
                        height: Math.max(20, root.textPixelSize + root.horizontalTitlePadding * 2)
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            visible: root.showHorizontalTitleBackground
                            radius: root.horizontalTitleRadius
                            color: root.resolvedHorizontalTitleBackgroundColor
                            opacity: 0.82
                            border.width: 1
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22)
                        }

                        Item {
                            id: horizontalTitleViewport
                            anchors.fill: parent
                            anchors.margins: root.showHorizontalTitleBackground ? root.horizontalTitlePadding : 0
                            clip: true

                            StyledText {
                                id: horizontalTitleText
                                property bool needsScrolling: implicitWidth > horizontalTitleViewport.width && root.horizontalTitleScrollBehavior !== "never"
                                property bool scrollActive: {
                                    if (!needsScrolling)
                                        return false;
                                    switch (root.horizontalTitleScrollBehavior) {
                                    case "always":
                                        return true;
                                    case "hover":
                                        return horizontalTitleHover.containsMouse;
                                    case "pauseOnHover":
                                        return !horizontalTitleHover.containsMouse;
                                    default:
                                        return false;
                                    }
                                }
                                property real scrollOffset: 0

                                anchors.verticalCenter: parent.verticalCenter
                                text: root.displayText()
                                font.pixelSize: root.textPixelSize
                                color: root.resolvedHorizontalTitleTextColor
                                wrapMode: Text.NoWrap
                                elide: needsScrolling ? Text.ElideNone : Text.ElideRight
                                x: needsScrolling ? -scrollOffset : 0

                                onTextChanged: {
                                    scrollOffset = 0;
                                    horizontalTitleScroll.restart();
                                }

                                onScrollActiveChanged: {
                                    if (!scrollActive && root.horizontalTitleScrollBehavior === "hover")
                                        scrollOffset = 0;
                                    horizontalTitleScroll.restart();
                                }

                                SequentialAnimation {
                                    id: horizontalTitleScroll
                                    running: horizontalTitleText.scrollActive && horizontalTitleClip.visible
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: root.horizontalTitleScrollBehavior === "hover" ? 150 : 900 }

                                    NumberAnimation {
                                        target: horizontalTitleText
                                        property: "scrollOffset"
                                        from: 0
                                        to: Math.max(0, horizontalTitleText.implicitWidth - horizontalTitleViewport.width + 5)
                                        duration: Math.max(800, Math.round((Math.max(0, horizontalTitleText.implicitWidth - horizontalTitleViewport.width + 5) / Math.max(1, root.horizontalTitleScrollSpeed)) * 1000))
                                        easing.type: Easing.Linear
                                    }

                                    PauseAnimation { duration: root.horizontalTitleScrollBehavior === "hover" ? 150 : 900 }

                                    NumberAnimation {
                                        target: horizontalTitleText
                                        property: "scrollOffset"
                                        to: 0
                                        duration: Math.max(800, Math.round((Math.max(0, horizontalTitleText.implicitWidth - horizontalTitleViewport.width + 5) / Math.max(1, root.horizontalTitleScrollSpeed)) * 1000))
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: horizontalTitleHover
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                        }
                    }
                }

                Row {
                    id: horizontalControlsRow
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    HorizontalMediaButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showHorizontalSkipControls
                        iconName: "skip_previous"
                        onClicked: root.previousTrack()
                    }

                    HorizontalMediaButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showHorizontalPlayPause
                        iconName: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                        emphasized: true
                        onClicked: root.togglePlayback()
                    }

                    HorizontalMediaButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showHorizontalSkipControls
                        iconName: "skip_next"
                        onClicked: root.nextTrack()
                    }
                }
            }
        }
    }

    verticalBarPill: root.showWidget ? verticalBarPillComponent : null

    Component {
        id: verticalBarPillComponent

        Item {
            implicitWidth: root.showWidget ? verticalColumn.implicitWidth : 0
            implicitHeight: root.showWidget ? verticalColumn.implicitHeight : 0
            visible: root.showWidget

            Column {
                id: verticalColumn
                spacing: Theme.spacingXS

                Item {
                    width: 20
                    height: Math.max(20, root.verticalVisualizerWidth)
                    anchors.horizontalCenter: parent.horizontalCenter

                    MediaVisualizer {
                        anchors.centerIn: parent
                        width: 20
                        height: root.verticalVisualizerWidth
                        barSpan: root.verticalVisualizerWidth
                        barCount: root.verticalVisualizerBars
                        stretchToWidth: root.verticalVisualizerStretchToWidth
                        verticalMode: true
                        visible: root.playerAvailable && root.showVerticalVisualizer
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "music_note"
                        size: 20
                        color: Theme.primary
                        visible: !root.playerAvailable || !root.showVerticalVisualizer
                    }
                }

                Item {
                    id: titleClip
                    width: root.iconUnit + 8
                    readonly property real titleVerticalPadding: root.showVerticalTitleBackground ? root.verticalTitlePadding * 2 : 0
                    height: Math.min(root.verticalTitleExtent, Math.max(verticalTitleText.contentHeight + titleVerticalPadding, root.textPixelSize + titleVerticalPadding))
                    visible: root.showVerticalTitle
                    anchors.horizontalCenter: parent.horizontalCenter
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        visible: root.showVerticalTitleBackground
                        radius: root.verticalTitleRadius
                        color: root.resolvedVerticalTitleBackgroundColor
                        opacity: 0.82
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.24)
                    }

                    Item {
                        id: titleViewport
                        anchors.fill: parent
                        anchors.margins: root.showVerticalTitleBackground ? root.verticalTitlePadding : 0
                        clip: true

                        MouseArea {
                            id: titleHoverArea
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                        }

                        StyledText {
                            id: verticalTitleText
                            property bool needsScrolling: contentHeight > titleViewport.height && root.verticalTitleScrollBehavior !== "never"
                            property bool scrollActive: {
                                if (!needsScrolling)
                                    return false;
                                switch (root.verticalTitleScrollBehavior) {
                                case "always":
                                    return true;
                                case "hover":
                                    return titleHoverArea.containsMouse;
                                case "pauseOnHover":
                                    return !titleHoverArea.containsMouse;
                                default:
                                    return false;
                                }
                            }
                            property real scrollOffset: 0

                            width: parent.width
                            text: root.verticalDisplayText()
                            font.pixelSize: root.textPixelSize
                            color: root.resolvedVerticalTitleTextColor
                            elide: needsScrolling ? Text.ElideNone : Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignTop
                            wrapMode: Text.NoWrap
                            lineHeight: 0.92
                            y: needsScrolling ? -scrollOffset : 0

                            onTextChanged: {
                                scrollOffset = 0;
                                verticalTitleScroll.restart();
                            }

                            onScrollActiveChanged: {
                                if (!scrollActive && root.verticalTitleScrollBehavior === "hover")
                                    scrollOffset = 0;
                                verticalTitleScroll.restart();
                            }

                            SequentialAnimation {
                                id: verticalTitleScroll
                                running: verticalTitleText.scrollActive && titleClip.visible
                                loops: Animation.Infinite

                                PauseAnimation {
                                    duration: root.verticalTitleScrollBehavior === "hover" ? 150 : 900
                                }

                                NumberAnimation {
                                    target: verticalTitleText
                                    property: "scrollOffset"
                                    from: 0
                                    to: Math.max(0, verticalTitleText.contentHeight - titleViewport.height + Theme.spacingXS)
                                    duration: Math.max(800, Math.round((Math.max(0, verticalTitleText.contentHeight - titleViewport.height + Theme.spacingXS) / Math.max(1, root.verticalTitleScrollSpeed)) * 1000))
                                    easing.type: Easing.Linear
                                }

                                PauseAnimation {
                                    duration: root.verticalTitleScrollBehavior === "hover" ? 150 : 900
                                }

                                NumberAnimation {
                                    target: verticalTitleText
                                    property: "scrollOffset"
                                    to: 0
                                    duration: Math.max(800, Math.round((Math.max(0, verticalTitleText.contentHeight - titleViewport.height + Theme.spacingXS) / Math.max(1, root.verticalTitleScrollSpeed)) * 1000))
                                    easing.type: Easing.Linear
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 20
                    radius: 10
                    visible: root.showVerticalSkipControls
                    color: prevArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"
                    opacity: root.playerAvailable ? 1 : 0.35

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_previous"
                        size: 14
                        color: Theme.widgetTextColor
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.playerAvailable
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.previousTrack()
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 24
                    height: 24
                    radius: 12
                    visible: root.showVerticalPlayPause
                    color: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? Theme.primary : Theme.primaryHover
                    opacity: root.playerAvailable ? 1 : 0.3

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                        size: 14
                        color: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.playerAvailable
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.togglePlayback()
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 20
                    radius: 10
                    visible: root.showVerticalSkipControls
                    color: nextArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"
                    opacity: root.playerAvailable ? 1 : 0.35

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_next"
                        size: 14
                        color: Theme.widgetTextColor
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.playerAvailable
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.nextTrack()
                    }
                }
            }
        }
    }
}
