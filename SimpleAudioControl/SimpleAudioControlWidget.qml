import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "simple-audio-control"

    // ── Settings from pluginData ──
    property bool showSpeaker: pluginData.showSpeaker !== undefined ? pluginData.showSpeaker : true
    property bool showSpeakerValue: pluginData.showSpeakerValue !== undefined ? pluginData.showSpeakerValue : true
    property bool showMic: pluginData.showMic !== undefined ? pluginData.showMic : false
    property bool showMicValue: pluginData.showMicValue !== undefined ? pluginData.showMicValue : false
    property int volumeScrollStep: pluginData.volumeScrollStep || 2
    property int micVolumeScrollStep: pluginData.micVolumeScrollStep || 2
    property int maxVolumePercent: pluginData.maxVolumePercent || 100
    property bool useCustomTabRadius: pluginData.useCustomTabRadius !== undefined ? pluginData.useCustomTabRadius : false
    property int tabRadius: useCustomTabRadius ? (pluginData.tabRadius || Theme.cornerRadius) : Theme.cornerRadius
    property int tabInnerRadius: Math.max(0, tabRadius - 3)
    property string speakerIconColorKey: pluginData.speakerIconColorKey || "primary"
    property string speakerTextColorKey: pluginData.speakerTextColorKey || "surfaceText"
    property string micIconColorKey: pluginData.micIconColorKey || "primary"
    property string micTextColorKey: pluginData.micTextColorKey || "surfaceText"

    // ── PipeWire references ──
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // ── Computed audio values ──
    readonly property int sinkVolume: sink?.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool sinkMuted: sink?.audio ? sink.audio.muted : false
    readonly property int sourceVolume: source?.audio ? Math.round(source.audio.volume * 100) : 0
    readonly property bool sourceMuted: source?.audio ? source.audio.muted : false

    // ── PipeWire node tracker ──
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio)
    }

    // ── Helper functions ──
    function speakerIconName() {
        if (sinkMuted || sinkVolume === 0)
            return "volume_off";
        if (sinkVolume < 33)
            return "volume_mute";
        if (sinkVolume < 66)
            return "volume_down";
        return "volume_up";
    }

    function speakerIconNameOffOrNo() {
        if (sinkMuted || sinkVolume === 0)
            return "volume_off";
        return "volume_up";
    }

    function micIconName() {
        if (sourceMuted)
            return "mic_off";
        return "mic";
    }

    function adjustSinkVolume(delta) {
        if (!sink?.audio)
            return;
        if (sink.audio.muted)
            sink.audio.muted = false;
        const maxSetting = root.maxVolumePercent || 100;
        const maxFromService = (typeof AudioService !== "undefined" && AudioService.getMaxVolumePercent) ? AudioService.getMaxVolumePercent(sink) : maxSetting;
        const maxVol = Math.min(maxSetting, maxFromService);
        const newVol = Math.max(0, Math.min(maxVol, sinkVolume + delta));
        sink.audio.volume = newVol / 100;
    }

    function adjustSourceVolume(delta) {
        if (!source?.audio)
            return;
        if (source.audio.muted)
            source.audio.muted = false;
        const newVol = Math.max(0, Math.min(100, sourceVolume + delta));
        source.audio.volume = newVol / 100;
    }

    function displayName(node) {
        if (!node)
            return "";
        if (typeof AudioService !== "undefined" && AudioService.displayName) {
            return AudioService.displayName(node);
        }
        if (node.description && node.description !== node.name)
            return node.description;
        if (node.properties && node.properties["node.description"])
            return node.properties["node.description"];
        if (node.nickname && node.nickname !== node.name)
            return node.nickname;
        return node.name || "";
    }

    function getAvailableSinks() {
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream);
    }

    function getAvailableSources() {
        return Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream);
    }

    function getStreamNodes() {
        return Pipewire.nodes.values.filter(node => node.audio && node.isStream && node.isSink);
    }

    function getStreamAppIconName(node) {
        if (!node)
            return "";
        const props = node.properties || {};
        // PipeWire exposes the application's icon name
        return props["application.icon-name"] || props["application.icon_name"] || "";
    }

    function getStreamFallbackIcon(node) {
        if (!node)
            return "graphic_eq";
        const props = node.properties || {};
        const appName = (props["application.name"] || node.name || "").toLowerCase();
        if (appName.includes("firefox"))
            return "public";
        if (appName.includes("chrome"))
            return "public";
        if (appName.includes("vivaldi"))
            return "public";
        if (appName.includes("spotify"))
            return "music_note";
        if (appName.includes("mpv"))
            return "movie";
        if (appName.includes("vlc"))
            return "movie";
        if (appName.includes("discord"))
            return "chat";
        if (appName.includes("steam"))
            return "sports_esports";
        if (appName.includes("obs"))
            return "videocam";
        if (appName.includes("telegram"))
            return "chat";
        return "graphic_eq";
    }

    function getStreamDisplayName(node) {
        if (!node)
            return "";
        const props = node.properties || {};
        return props["application.name"] || root.displayName(node);
    }

    function themeColorFromKey(key, fallback) {
        switch (key) {
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

    function adjustStreamVolume(node, delta) {
        if (!node?.audio)
            return;
        if (node.audio.muted)
            node.audio.muted = false;
        const maxVol = root.maxVolumePercent || 100;
        const currentVol = Math.round(node.audio.volume * 100);
        const newVol = Math.max(0, Math.min(maxVol, currentVol + delta));
        node.audio.volume = newVol / 100;
    }

    function resetAppStreamVolumeToBase(node) {
        // for resetting per app volume, we want it to reset to default (100%)
        if (!node?.audio)
            return;
        if (node.audio.muted)
            node.audio.muted = false;
        const maxVol = 100;
        node.audio.volume = maxVol / 100;
    }

    // ── Mic Volume Popup State ──
    property bool micPopupMode: false
    property bool isPopoutActuallyOpen: false

    Timer {
        id: micPopoutTimer
        interval: 1500
        onTriggered: {
            if (typeof root.closePopout === "function")
                root.closePopout();
        }
    }

    function triggerMicPopout() {
        // If the main menu is already open and we are not in mic popup mode, do nothing
        if (root.isPopoutActuallyOpen && !root.micPopupMode)
            return;

        root.micPopupMode = true;
        micPopoutTimer.restart();

        if (!root.isPopoutActuallyOpen) {
            if (typeof root.triggerPopout === "function")
                root.triggerPopout();
        }
    }

    // ── Horizontal bar pill ──
    horizontalBarPill: Component {
        Item {
            implicitWidth: hBarRow.implicitWidth
            implicitHeight: hBarRow.implicitHeight

            Row {
                id: hBarRow
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.speakerIconName()
                    size: root.iconSize
                    color: root.sinkMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.speakerIconColorKey, Theme.primary)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showSpeaker
                }

                StyledText {
                    text: root.sinkVolume
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.sinkMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.speakerTextColorKey, Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showSpeaker && root.showSpeakerValue
                }

                DankIcon {
                    name: root.micIconName()
                    size: root.iconSize
                    color: root.sourceMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.micIconColorKey, Theme.primary)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showMic
                }

                StyledText {
                    text: root.sourceVolume
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.sourceMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.micTextColorKey, Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showMic && root.showMicValue
                }

                // Add a little spacing on this horizontal bar layout
                Item {
                    width: 0.09
                    height: 1
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                onWheel: function (wheel) {
                    const midX = parent.width / 2;
                    const onMicSide = root.showMic && (!root.showSpeaker || wheel.x > midX);

                    if (onMicSide) {
                        root.adjustSourceVolume(wheel.angleDelta.y > 0 ? root.micVolumeScrollStep : -root.micVolumeScrollStep);
                        root.triggerMicPopout();
                    } else if (root.showSpeaker) {
                        root.adjustSinkVolume(wheel.angleDelta.y > 0 ? root.volumeScrollStep : -root.volumeScrollStep);
                    }
                }
            }
        }
    }

    // ── Vertical bar pill ──
    verticalBarPill: Component {
        Item {
            implicitWidth: vBarCol.implicitWidth
            implicitHeight: vBarCol.implicitHeight

            Column {
                id: vBarCol
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.speakerIconName()
                    size: root.iconSize
                    color: root.sinkMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.speakerIconColorKey, Theme.primary)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showSpeaker
                }

                StyledText {
                    text: root.sinkVolume
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.sinkMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.speakerTextColorKey, Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showSpeaker && root.showSpeakerValue
                }

                DankIcon {
                    name: root.micIconName()
                    size: root.iconSize
                    color: root.sourceMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.micIconColorKey, Theme.primary)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showMic
                }

                StyledText {
                    text: root.sourceVolume
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.sourceMuted ? Theme.surfaceVariantText : root.themeColorFromKey(root.micTextColorKey, Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showMic && root.showMicValue
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                onWheel: function (wheel) {
                    const midY = parent.height / 2;
                    const onMicSide = root.showMic && (!root.showSpeaker || wheel.y > midY);

                    if (onMicSide) {
                        root.adjustSourceVolume(wheel.angleDelta.y > 0 ? root.micVolumeScrollStep : -root.micVolumeScrollStep);
                        root.triggerMicPopout();
                    } else if (root.showSpeaker) {
                        root.adjustSinkVolume(wheel.angleDelta.y > 0 ? root.volumeScrollStep : -root.volumeScrollStep);
                    }
                }
            }
        }
    }

    // ── Popout content ──
    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: root.micPopupMode ? "" : "Audio"
            showCloseButton: !root.micPopupMode

            Component.onCompleted: root.isPopoutActuallyOpen = true
            Component.onDestruction: {
                root.isPopoutActuallyOpen = false;
                root.micPopupMode = false;
            }

            property int activeTab: 0

            // ── Mic popup UI (only visible when scrolled) ──
            Item {
                width: parent.width
                height: micCol.implicitHeight + Theme.spacingL * 2
                visible: root.micPopupMode

                StyledRect {
                    width: Math.max(140, micCol.implicitWidth + Theme.spacingL * 2)
                    height: parent.height
                    radius: 12
                    color: Theme.surfaceContainerHigh
                    anchors.centerIn: parent

                    Column {
                        id: micCol
                        spacing: Theme.spacingS
                        anchors.centerIn: parent

                        StyledText {
                            text: "Microphone"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: root.sourceVolume + "%"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: Theme.primary
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            // ── Main audio UI (hidden when mic popup is active) ──
            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: !root.micPopupMode

                // ── Tab bar ──
                StyledRect {
                    width: parent.width
                    height: 40
                    radius: root.tabRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            radius: root.tabInnerRadius
                            color: popout.activeTab === 0 ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: "Volumes"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: popout.activeTab === 0 ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popout.activeTab = 0
                            }
                        }

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            radius: root.tabInnerRadius
                            color: popout.activeTab === 1 ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: "Devices"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: popout.activeTab === 1 ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popout.activeTab = 1
                            }
                        }
                    }
                }

                // ══════════════════════════════════════
                // ── Volumes tab content ──
                // ══════════════════════════════════════
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: popout.activeTab === 0

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // ── Output section ──
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            height: 20

                            DankIcon {
                                name: root.speakerIconNameOffOrNo()
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Output" + (root.sink ? " – " + root.displayName(root.sink) : "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                                width: parent.width - 18 - Theme.spacingS
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Slider {
                                id: outputSlider
                                width: parent.width - outputVolLabel.width - outputMuteBtn.width - Theme.spacingS * 2
                                from: 0
                                to: (typeof AudioService !== "undefined" && AudioService.getMaxVolumePercent) ? Math.min(root.maxVolumePercent, AudioService.getMaxVolumePercent(root.sink)) : root.maxVolumePercent
                                value: root.sinkVolume
                                anchors.verticalCenter: parent.verticalCenter

                                onMoved: {
                                    if (root.sink?.audio) {
                                        root.sink.audio.volume = value / 100;
                                    }
                                }

                                background: Rectangle {
                                    x: outputSlider.leftPadding
                                    y: outputSlider.topPadding + outputSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 4
                                    width: outputSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: Theme.surfaceContainerHighest

                                    Rectangle {
                                        width: outputSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: root.sinkMuted ? Theme.surfaceVariantText : Theme.primary
                                    }
                                }

                                handle: Rectangle {
                                    x: outputSlider.leftPadding + outputSlider.visualPosition * (outputSlider.availableWidth - width)
                                    y: outputSlider.topPadding + outputSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 8
                                    color: root.sinkMuted ? Theme.surfaceVariantText : Theme.primary
                                    border.color: Theme.surface
                                    border.width: 2
                                }
                            }

                            StyledText {
                                id: outputVolLabel
                                text: root.sinkVolume + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                id: outputMuteBtn
                                width: 28
                                height: 28
                                radius: 14
                                color: outputMuteArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: root.speakerIconName()
                                    size: 18
                                    color: root.sinkMuted ? Theme.surfaceVariantText : Theme.primary
                                }

                                MouseArea {
                                    id: outputMuteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.sink?.audio)
                                            root.sink.audio.muted = !root.sink.audio.muted;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // ── Input section ──
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            height: 20

                            DankIcon {
                                name: root.micIconName()
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Input" + (root.source ? " – " + root.displayName(root.source) : "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                                width: parent.width - 18 - Theme.spacingS
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Slider {
                                id: inputSlider
                                width: parent.width - inputVolLabel.width - inputMuteBtn.width - Theme.spacingS * 2
                                from: 0
                                to: 100
                                value: root.sourceVolume
                                anchors.verticalCenter: parent.verticalCenter

                                onMoved: {
                                    if (root.source?.audio) {
                                        root.source.audio.volume = value / 100;
                                    }
                                }

                                background: Rectangle {
                                    x: inputSlider.leftPadding
                                    y: inputSlider.topPadding + inputSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 4
                                    width: inputSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: Theme.surfaceContainerHighest

                                    Rectangle {
                                        width: inputSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: root.sourceMuted ? Theme.surfaceVariantText : Theme.primary
                                    }
                                }

                                handle: Rectangle {
                                    x: inputSlider.leftPadding + inputSlider.visualPosition * (inputSlider.availableWidth - width)
                                    y: inputSlider.topPadding + inputSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 8
                                    color: root.sourceMuted ? Theme.surfaceVariantText : Theme.primary
                                    border.color: Theme.surface
                                    border.width: 2
                                }
                            }

                            StyledText {
                                id: inputVolLabel
                                text: root.sourceVolume + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                id: inputMuteBtn
                                width: 28
                                height: 28
                                radius: 14
                                color: inputMuteArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: root.micIconName()
                                    size: 18
                                    color: root.sourceMuted ? Theme.surfaceVariantText : Theme.primary
                                }

                                MouseArea {
                                    id: inputMuteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.source?.audio)
                                            root.source.audio.muted = !root.source.audio.muted;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // ── Application streams (scrollable, max 200px) ──
                    Item {
                        width: parent.width
                        height: Math.min(streamsContentCol.implicitHeight, 200)
                        visible: streamRepeater.count > 0
                        clip: true

                        Flickable {
                            id: streamsFlickable
                            anchors.fill: parent
                            contentHeight: streamsContentCol.implicitHeight
                            contentWidth: width
                            flickableDirection: Flickable.VerticalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            property int scrollGutter: Theme.spacingS
                            ScrollBar.vertical: ScrollBar {
                                id: streamsScrollBar
                                policy: ScrollBar.AsNeeded
                                visible: streamsFlickable.contentHeight > streamsFlickable.height
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
                                id: streamsContentCol
                                width: parent.width - (streamsScrollBar.visible ? (streamsScrollBar.width + streamsFlickable.scrollGutter) : 0)
                                spacing: Theme.spacingM

                                Repeater {
                                    id: streamRepeater
                                    model: root.getStreamNodes()

                                    Column {
                                        id: streamItem
                                        width: streamsContentCol.width
                                        spacing: Theme.spacingXS
                                        property bool expanded: false
                                        property real controlsProgress: expanded ? 1 : 0

                                        Behavior on controlsProgress {
                                            NumberAnimation {
                                                duration: 180
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        // App name row with icon
                                        Row {
                                            spacing: Theme.spacingS
                                            height: 24
                                            width: parent.width

                                            // Try real app icon first, fall back to DankIcon
                                            Item {
                                                width: 20
                                                height: 20
                                                anchors.verticalCenter: parent.verticalCenter

                                                Image {
                                                    id: appIconImage
                                                    anchors.fill: parent
                                                    source: {
                                                        const iconName = root.getStreamAppIconName(modelData);
                                                        if (!iconName)
                                                            return "";
                                                        // Try freedesktop icon theme paths
                                                        return "image://icon/" + iconName;
                                                    }
                                                    sourceSize.width: 20
                                                    sourceSize.height: 20
                                                    visible: status === Image.Ready
                                                    smooth: true
                                                }

                                                DankIcon {
                                                    anchors.fill: parent
                                                    name: root.getStreamFallbackIcon(modelData)
                                                    size: 20
                                                    color: Theme.surfaceText
                                                    visible: appIconImage.status !== Image.Ready
                                                }
                                            }

                                            StyledText {
                                                text: root.getStreamDisplayName(modelData)
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 20 - Theme.spacingS
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Volume slider row
                                        Item {
                                            width: parent.width
                                            height: Math.max(streamSlider.implicitHeight, 28)

                                            Row {
                                                id: streamRightControls
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter

                                                DankActionButton {
                                                    id: streamScrollBtn
                                                    width: 28 * streamItem.controlsProgress
                                                    height: 28
                                                    buttonSize: 28
                                                    radius: width / 2
                                                    iconName: ""
                                                    iconSize: 0
                                                    iconColor: "transparent"
                                                    backgroundColor: streamScrollBtn.knobHovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                    opacity: streamItem.controlsProgress
                                                    enabled: streamItem.controlsProgress > 0.1
                                                    visible: streamItem.controlsProgress > 0
                                                    tooltipText: "Drag or scroll to adjust"
                                                    tooltipSide: "top"
                                                    onEntered: streamScrollBtn.knobHovered = true
                                                    onExited: streamScrollBtn.knobHovered = false

                                                    property real dragAccum: 0
                                                    property real dragSensitivity: 4
                                                    property real lastDragTranslationX: 0
                                                    property real lastDragTranslationY: 0
                                                    property bool knobHovered: false
                                                    property real knobAngle: {
                                                        const vol = modelData.audio ? Math.round(modelData.audio.volume * 100) : 0;
                                                        const clamped = Math.max(0, Math.min(root.maxVolumePercent || 100, vol));
                                                        const range = 270;
                                                        const start = -135;
                                                        return start + (clamped / (root.maxVolumePercent || 100)) * range;
                                                    }

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: parent.width - 8
                                                        height: parent.height - 8
                                                        radius: width / 2
                                                        color: "transparent"
                                                        border.width: 1
                                                        border.color: streamScrollBtn.knobHovered ? Theme.surfaceVariantText : Theme.outlineVariant
                                                    }

                                                    Item {
                                                        width: parent.width
                                                        height: parent.height
                                                        anchors.centerIn: parent
                                                        clip: true

                                                        Rectangle {
                                                            id: knobIndicator
                                                            width: 3
                                                            height: parent.height * 0.25
                                                            radius: 2
                                                            color: streamScrollBtn.knobHovered ? Theme.primary : Theme.surfaceVariantText
                                                            x: parent.width / 2 - width / 2
                                                            y: parent.height / 2 - height - 2

                                                            transform: Rotation {
                                                                origin.x: knobIndicator.width / 2        // horizontal center of the indicator
                                                                origin.y: knobIndicator.height + 2       // bottom of indicator + gap = knob center
                                                                angle: streamScrollBtn.knobAngle
                                                            }
                                                        }
                                                    }

                                                    WheelHandler {
                                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                        onWheel: event => {
                                                            root.adjustStreamVolume(modelData, event.angleDelta.y > 0 ? root.volumeScrollStep : -root.volumeScrollStep);
                                                            event.accepted = true;
                                                        }
                                                    }

                                                    DragHandler {
                                                        target: null
                                                        yAxis.enabled: true
                                                        xAxis.enabled: true
                                                        onActiveChanged: {
                                                            if (active) {
                                                                streamScrollBtn.dragAccum = 0;
                                                                streamScrollBtn.lastDragTranslationX = translation.x;
                                                                streamScrollBtn.lastDragTranslationY = translation.y;
                                                            }
                                                        }
                                                        onTranslationChanged: {
                                                            var deltaX = translation.x - streamScrollBtn.lastDragTranslationX;
                                                            var deltaY = streamScrollBtn.lastDragTranslationY - translation.y;
                                                            streamScrollBtn.lastDragTranslationX = translation.x;
                                                            streamScrollBtn.lastDragTranslationY = translation.y;
                                                            var delta = deltaX + deltaY;
                                                            streamScrollBtn.dragAccum += delta;
                                                            var steps = Math.trunc(streamScrollBtn.dragAccum / streamScrollBtn.dragSensitivity);
                                                            if (steps !== 0) {
                                                                root.adjustStreamVolume(modelData, steps * root.volumeScrollStep);
                                                                streamScrollBtn.dragAccum -= steps * streamScrollBtn.dragSensitivity;
                                                            }
                                                        }
                                                    }
                                                }

                                                DankActionButton {
                                                    id: streamResetBtn
                                                    width: 28 * streamItem.controlsProgress
                                                    height: 28
                                                    buttonSize: 28
                                                    radius: 14
                                                    iconName: "restart_alt"
                                                    iconSize: 16
                                                    iconColor: Theme.surfaceVariantText
                                                    backgroundColor: "transparent"
                                                    opacity: streamItem.controlsProgress
                                                    enabled: streamItem.controlsProgress > 0.1
                                                    visible: streamItem.controlsProgress > 0
                                                    tooltipText: "Reset volume"
                                                    tooltipSide: "top"
                                                    onClicked: root.resetAppStreamVolumeToBase(modelData)
                                                }

                                                Rectangle {
                                                    id: streamExpandBtn
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: streamExpandArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: streamItem.expanded ? "chevron_left" : "chevron_right"
                                                        size: 18
                                                        color: Theme.surfaceVariantText
                                                    }

                                                    MouseArea {
                                                        id: streamExpandArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: streamItem.expanded = !streamItem.expanded
                                                    }
                                                }

                                                // tighten gap to left (chevron) side
                                                Item {
                                                    width: -4
                                                    height: 1
                                                }

                                                StyledText {
                                                    id: streamVolLabel
                                                    text: (modelData.audio ? Math.round(modelData.audio.volume * 100) : 0) + "%"
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 40
                                                    horizontalAlignment: Text.AlignRight
                                                }

                                                // widen gap to mute icon
                                                Item {
                                                    width: 6
                                                    height: 1
                                                }

                                                Rectangle {
                                                    id: streamMuteBtn
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: streamMuteArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: modelData.audio?.muted ? "volume_off" : "volume_up"
                                                        size: 18
                                                        color: modelData.audio?.muted ? Theme.surfaceVariantText : Theme.primary
                                                    }

                                                    MouseArea {
                                                        id: streamMuteArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData.audio)
                                                                modelData.audio.muted = !modelData.audio.muted;
                                                        }
                                                    }
                                                }
                                            }

                                            Slider {
                                                id: streamSlider
                                                anchors.left: parent.left
                                                anchors.right: streamRightControls.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                from: 0
                                                to: root.maxVolumePercent
                                                value: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0

                                                onMoved: {
                                                    if (modelData.audio) {
                                                        modelData.audio.volume = value / 100;
                                                    }
                                                }

                                                background: Rectangle {
                                                    x: streamSlider.leftPadding
                                                    y: streamSlider.topPadding + streamSlider.availableHeight / 2 - height / 2
                                                    implicitWidth: 200
                                                    implicitHeight: 4
                                                    width: streamSlider.availableWidth
                                                    height: implicitHeight
                                                    radius: 2
                                                    color: Theme.surfaceContainerHighest

                                                    Rectangle {
                                                        width: streamSlider.visualPosition * parent.width
                                                        height: parent.height
                                                        radius: 2
                                                        color: modelData.audio?.muted ? Theme.surfaceVariantText : Theme.primary
                                                    }
                                                }

                                                handle: Rectangle {
                                                    x: streamSlider.leftPadding + streamSlider.visualPosition * (streamSlider.availableWidth - width)
                                                    y: streamSlider.topPadding + streamSlider.availableHeight / 2 - height / 2
                                                    implicitWidth: 16
                                                    implicitHeight: 16
                                                    radius: 8
                                                    color: modelData.audio?.muted ? Theme.surfaceVariantText : Theme.primary
                                                    border.color: Theme.surface
                                                    border.width: 2
                                                }

                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: 180
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── "No applications" message ──
                    StyledText {
                        width: parent.width
                        text: "No applications are currently playing audio"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: streamRepeater.count === 0
                        topPadding: Theme.spacingS
                    }
                }

                // ══════════════════════════════════════
                // ── Devices tab content ──
                // ══════════════════════════════════════
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: popout.activeTab === 1

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // ── Output devices ──
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Row {
                            spacing: Theme.spacingS
                            height: 20

                            DankIcon {
                                name: "volume_up"
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Output device"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Repeater {
                            model: root.getAvailableSinks()

                            Item {
                                width: parent.width
                                height: 36

                                Row {
                                    anchors.fill: parent
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        border.width: 2
                                        border.color: modelData.name === root.sink?.name ? Theme.primary : Theme.outlineStrong
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 10
                                            height: 10
                                            radius: 5
                                            anchors.centerIn: parent
                                            color: Theme.primary
                                            visible: modelData.name === root.sink?.name
                                        }
                                    }

                                    StyledText {
                                        text: root.displayName(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 28
                                        elide: Text.ElideMiddle
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Pipewire.preferredDefaultAudioSink = modelData;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // ── Input devices ──
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Row {
                            spacing: Theme.spacingS
                            height: 20

                            DankIcon {
                                name: "mic"
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Input device"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Repeater {
                            model: root.getAvailableSources()

                            Item {
                                width: parent.width
                                height: 36

                                Row {
                                    anchors.fill: parent
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        border.width: 2
                                        border.color: modelData.name === root.source?.name ? Theme.primary : Theme.outlineStrong
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 10
                                            height: 10
                                            radius: 5
                                            anchors.centerIn: parent
                                            color: Theme.primary
                                            visible: modelData.name === root.source?.name
                                        }
                                    }

                                    StyledText {
                                        text: root.displayName(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 28
                                        elide: Text.ElideMiddle
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Pipewire.preferredDefaultAudioSource = modelData;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: root.micPopupMode ? 160 : 420
    popoutHeight: root.micPopupMode ? 100 : 500
}
