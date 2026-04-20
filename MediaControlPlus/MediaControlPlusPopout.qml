import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PopoutComponent {
    id: root

    signal popoutOpened
    signal popoutClosed

    property MprisPlayer activePlayer: null
    property int preferredHeight: 0
    property int titleMaxLines: 1
    property bool showInnerBackground: false
    property bool showArtworkBackdrop: true
    property bool isSeeking: false
    property bool volumePanelDragging: false
    property int dropdownType: 0
    property real previousVolume: 0.5
    readonly property real sideRailWidth: 56
    readonly property real sideRailGap: Theme.spacingM
    readonly property real contentSideInset: sideRailWidth + sideRailGap
    readonly property bool isRightEdge: {
        if (!parentPopout)
            return false;
        if (parentPopout.effectiveBarPosition === SettingsData.Position.Right)
            return true;
        if (parentPopout.effectiveBarPosition === SettingsData.Position.Left)
            return false;
        return parentPopout.triggerSection === "right";
    }
    readonly property bool controlsOnLeft: isRightEdge
    readonly property string buttonTooltipSide: controlsOnLeft ? "right" : "left"

    readonly property var allPlayers: MprisController.availablePlayers
    readonly property var availableDevices: AudioService.getAvailableSinks()
    readonly property int playerCount: allPlayers ? allPlayers.length : 0
    readonly property bool noneAvailable: playerCount === 0
    readonly property bool trulyIdle: activePlayer && activePlayer.playbackState === MprisPlaybackState.Stopped && !activePlayer.trackTitle && !activePlayer.trackArtist
    readonly property bool showNoPlayerNow: noneAvailable || trulyIdle || !activePlayer
    readonly property bool hasArtwork: !showNoPlayerNow && !!(activePlayer && activePlayer.trackArtUrl && String(activePlayer.trackArtUrl).trim().length > 0)
    readonly property bool isChromePlayer: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !isChromePlayer
    readonly property bool volumeAvailable: !!((activePlayer && activePlayer.volumeSupported && !isChromePlayer) || (AudioService.sink && AudioService.sink.audio))
    readonly property real currentVolume: usePlayerVolume ? activePlayer.volume : (AudioService.sink?.audio?.volume ?? 0)

    headerText: "Media"
    showCloseButton: true

    Component.onCompleted: root.popoutOpened()
    Component.onDestruction: root.popoutClosed()

    DankTooltipV2 {
        id: sharedTooltip
    }

    Timer {
        id: volumeCloseTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (root.dropdownType === 1)
                root.dropdownType = 0;
        }
    }

    function formatTime(value) {
        const total = Math.max(0, Math.floor(value || 0));
        const minutes = Math.floor(total / 60);
        const seconds = total % 60;
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    function getAudioDeviceIcon(device) {
        if (!device?.name)
            return "speaker";
        const name = device.name.toLowerCase();
        if (name.includes("bluez") || name.includes("bluetooth"))
            return "headset";
        if (name.includes("hdmi"))
            return "tv";
        if (name.includes("usb"))
            return "headset";
        if (name.includes("analog") || name.includes("built-in"))
            return "speaker";
        return "speaker";
    }

    function getVolumeIcon() {
        if (!volumeAvailable)
            return "volume_off";
        const volume = currentVolume;
        if (usePlayerVolume) {
            if (volume === 0.0)
                return "music_off";
            return "music_note";
        }
        if (volume === 0.0)
            return "volume_off";
        if (volume <= 0.33)
            return "volume_down";
        return "volume_up";
    }

    function hideDropdowns() {
        volumeCloseTimer.stop();
        dropdownType = 0;
    }

    onDropdownTypeChanged: sharedTooltip.hide()

    function openVolumeDropdown() {
        if (!root.volumeAvailable)
            return;
        volumeCloseTimer.stop();
        root.dropdownType = 1;
    }

    function startVolumeCloseTimer() {
        if (root.dropdownType === 1 && !root.volumePanelDragging)
            volumeCloseTimer.restart();
    }

    function stopVolumeCloseTimer() {
        volumeCloseTimer.stop();
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

    function setVolume(volume) {
        const clamped = Math.max(0, Math.min(1, volume));
        SessionData.suppressOSDTemporarily();
        if (usePlayerVolume) {
            activePlayer.volume = clamped;
        } else if (AudioService.sink?.audio) {
            AudioService.sink.audio.volume = clamped;
        }
    }

    function toggleMuteOrRestore() {
        SessionData.suppressOSDTemporarily();
        if (currentVolume > 0) {
            previousVolume = currentVolume;
            setVolume(0);
        } else {
            setVolume(previousVolume > 0 ? previousVolume : 0.5);
        }
    }

    component MiniButton: Rectangle {
        id: buttonRoot
        property string iconName: ""
        property color iconColor: Theme.surfaceText
        property bool active: false
        property bool enabledState: true
        property string tooltipText: ""
        property string tooltipSide: root.buttonTooltipSide
        signal entered
        signal exited
        signal wheeled(var wheelEvent)
        signal clicked

        width: 40
        height: 40
        radius: 20
        color: buttonArea.containsMouse || active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : "transparent"
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, enabledState ? 0.3 : 0.15)
        border.width: 1
        opacity: enabledState ? 1 : 0.4

        DankIcon {
            anchors.centerIn: parent
            name: buttonRoot.iconName
            size: 18
            color: buttonRoot.iconColor
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: buttonRoot.enabledState
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: {
                buttonRoot.entered();
                if (buttonRoot.tooltipText.length > 0 && !buttonRoot.active)
                    sharedTooltip.show(buttonRoot.tooltipText, buttonRoot, 0, 0, buttonRoot.tooltipSide);
            }
            onExited: {
                buttonRoot.exited();
                sharedTooltip.hide();
            }
            onClicked: {
                sharedTooltip.hide();
                buttonRoot.clicked();
            }
            onWheel: wheel => {
                buttonRoot.wheeled(wheel);
            }
        }
    }

    Item {
        id: shell
        width: parent.width
        implicitHeight: Math.max(contentCard.implicitHeight, Math.max(0, root.preferredHeight - root.headerHeight))
        height: implicitHeight

        Rectangle {
            id: contentCard
            z: 200
            width: parent.width
            implicitHeight: Math.max(cardColumn.implicitHeight, noPlayerState.implicitHeight) + Theme.spacingL * 2
            height: shell.height
            radius: Theme.cornerRadius * 1.5
            color: root.showInnerBackground ? Theme.surfaceContainer : "transparent"
            border.width: root.showInnerBackground ? 1 : 0
            border.color: root.showInnerBackground ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35) : "transparent"

            Item {
                anchors.fill: parent
                visible: root.showArtworkBackdrop && root.hasArtwork

                Image {
                    id: artworkImage
                    anchors.fill: parent
                    source: root.activePlayer ? root.activePlayer.trackArtUrl || "" : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                    cache: true
                }

                Item {
                    id: blurredBg
                    anchors.fill: parent
                    visible: false

                    MultiEffect {
                        anchors.fill: parent
                        source: artworkImage
                        blurEnabled: true
                        blurMax: 64
                        blur: 0.8
                        saturation: -0.2
                        brightness: -0.25
                    }
                }

                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: contentCard.radius
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: blurredBg
                    maskEnabled: true
                    maskSource: maskRect
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    opacity: 0.75
                }

                Rectangle {
                    anchors.fill: parent
                    radius: contentCard.radius
                    color: Theme.surface
                    opacity: 0.30
                }
            }

            Column {
                id: cardColumn
                width: parent.width - Theme.spacingL * 2 - root.contentSideInset
                x: root.controlsOnLeft ? (Theme.spacingL + root.contentSideInset) : Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingM
                visible: !root.showNoPlayerNow

                Item {
                    width: parent.width
                    height: 128

                    Item {
                        id: artFrame
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 128
                        height: 128

                        DankAlbumArt {
                            anchors.fill: parent
                            activePlayer: root.activePlayer
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Rectangle {
                        visible: root.hasArtwork
                        width: parent.width
                        height: titleColumn.implicitHeight + Theme.spacingS * 2
                        clip: true
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.26)
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                        Column {
                            id: titleColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: 4

                            StyledText {
                                text: root.activePlayer?.trackTitle || "Unknown Track"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: root.titleMaxLines === 1 ? Text.ElideRight : (root.titleMaxLines <= 0 ? Text.ElideNone : Text.ElideRight)
                                wrapMode: root.titleMaxLines === 1 ? Text.NoWrap : Text.WrapAnywhere
                                maximumLineCount: root.titleMaxLines <= 0 ? 999 : root.titleMaxLines
                            }

                            StyledText {
                                text: root.activePlayer?.trackArtist || (root.activePlayer?.identity || "Unknown Artist")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.86)
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            StyledText {
                                text: root.activePlayer?.trackAlbum || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.68)
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                visible: text.length > 0
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: !root.hasArtwork

                        StyledText {
                            text: root.activePlayer?.trackTitle || "Unknown Track"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: root.titleMaxLines === 1 ? Text.ElideRight : (root.titleMaxLines <= 0 ? Text.ElideNone : Text.ElideRight)
                            wrapMode: root.titleMaxLines === 1 ? Text.NoWrap : Text.WrapAnywhere
                            maximumLineCount: root.titleMaxLines <= 0 ? 999 : root.titleMaxLines
                        }

                        StyledText {
                            text: root.activePlayer?.trackArtist || (root.activePlayer?.identity || "Unknown Artist")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.86)
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        StyledText {
                            text: root.activePlayer?.trackAlbum || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.68)
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            visible: text.length > 0
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    DankSeekbar {
                        width: parent.width
                        height: 20
                        activePlayer: root.activePlayer
                        isSeeking: root.isSeeking
                        onIsSeekingChanged: root.isSeeking = isSeeking
                    }

                    Item {
                        width: parent.width
                        height: 16

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.activePlayer ? root.formatTime(root.activePlayer.position || 0) : "0:00"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.activePlayer ? root.formatTime(root.activePlayer.length || 0) : "0:00"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    Item {
                        width: 50
                        height: 50
                        visible: root.activePlayer && root.activePlayer.shuffleSupported

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            anchors.centerIn: parent
                            color: shuffleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "shuffle"
                                size: 20
                                color: root.activePlayer && root.activePlayer.shuffle ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: shuffleArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer && root.activePlayer.canControl && root.activePlayer.shuffleSupported) {
                                        root.activePlayer.shuffle = !root.activePlayer.shuffle;
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: 50
                        height: 50

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            anchors.centerIn: parent
                            color: prevBtnArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "skip_previous"
                                size: 24
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: prevBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previousTrack()
                            }
                        }
                    }

                    Item {
                        width: 50
                        height: 50

                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            anchors.centerIn: parent
                            color: Theme.primary

                            DankIcon {
                                anchors.centerIn: parent
                                name: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                size: 28
                                color: Theme.background
                                weight: 500
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePlayback()
                            }

                            ElevationShadow {
                                anchors.fill: parent
                                z: -1
                                level: Theme.elevationLevel1
                                fallbackOffset: 1
                                targetRadius: parent.radius
                                targetColor: parent.color
                                shadowOpacity: Theme.elevationLevel1 && Theme.elevationLevel1.alpha !== undefined ? Theme.elevationLevel1.alpha : 0.2
                                shadowEnabled: Theme.elevationEnabled
                            }
                        }
                    }

                    Item {
                        width: 50
                        height: 50

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            anchors.centerIn: parent
                            color: nextBtnArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "skip_next"
                                size: 24
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: nextBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextTrack()
                            }
                        }
                    }

                    Item {
                        width: 50
                        height: 50
                        visible: root.activePlayer && root.activePlayer.loopSupported

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            anchors.centerIn: parent
                            color: repeatArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: {
                                    if (!root.activePlayer)
                                        return "repeat";
                                    switch (root.activePlayer.loopState) {
                                    case MprisLoopState.Track:
                                        return "repeat_one";
                                    case MprisLoopState.Playlist:
                                        return "repeat";
                                    default:
                                        return "repeat";
                                    }
                                }
                                size: 20
                                color: root.activePlayer && root.activePlayer.loopState !== MprisLoopState.None ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: repeatArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer && root.activePlayer.canControl && root.activePlayer.loopSupported) {
                                        switch (root.activePlayer.loopState) {
                                        case MprisLoopState.None:
                                            root.activePlayer.loopState = MprisLoopState.Playlist;
                                            break;
                                        case MprisLoopState.Playlist:
                                            root.activePlayer.loopState = MprisLoopState.Track;
                                            break;
                                        case MprisLoopState.Track:
                                            root.activePlayer.loopState = MprisLoopState.None;
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: noPlayerState
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: root.showNoPlayerNow

                DankIcon {
                    name: "music_note"
                    size: Theme.iconSize * 3
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "No Active Players"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Rectangle {
                id: volumePanel
                visible: root.dropdownType === 1 && root.volumeAvailable
                width: 60
                height: 180
                x: root.controlsOnLeft ? (volumeButton.x + volumeButton.width + Theme.spacingS) : (volumeButton.x - width - Theme.spacingS)
                y: volumeButton.y - (height - volumeButton.height) / 2
                radius: Theme.cornerRadius * 2
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                border.width: 1
                z: 200

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    hoverEnabled: true
                    onEntered: root.stopVolumeCloseTimer()
                    onExited: root.startVolumeCloseTimer()
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS

                    Item {
                        width: parent.width * 0.5
                        height: parent.height - Theme.spacingXL * 2
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingS
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: parent.width
                            height: parent.height
                            anchors.centerIn: parent
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            radius: Theme.cornerRadius
                        }

                        Rectangle {
                            width: parent.width
                            height: root.volumeAvailable ? (Math.min(1.0, root.currentVolume) * parent.height) : 0
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.primary
                            bottomLeftRadius: Theme.cornerRadius
                            bottomRightRadius: Theme.cornerRadius
                        }

                        Rectangle {
                            width: parent.width + 8
                            height: 8
                            radius: Theme.cornerRadius
                            y: {
                                const ratio = root.volumeAvailable ? Math.min(1.0, root.currentVolume) : 0;
                                const travel = parent.height - height;
                                return Math.max(0, Math.min(travel, travel * (1 - ratio)));
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.primary
                            border.width: 3
                            border.color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 1.0)
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -12
                            enabled: root.volumeAvailable
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            onPressed: mouse => {
                                root.volumePanelDragging = true;
                                root.stopVolumeCloseTimer();
                                updateVolume(mouse);
                            }
                            onPositionChanged: mouse => {
                                if (pressed)
                                    updateVolume(mouse);
                            }
                            onReleased: {
                                root.volumePanelDragging = false;
                            }
                            onCanceled: {
                                root.volumePanelDragging = false;
                                root.startVolumeCloseTimer();
                            }
                            onClicked: mouse => updateVolume(mouse)

                            function updateVolume(mouse) {
                                if (!root.volumeAvailable)
                                    return;
                                const ratio = 1.0 - (mouse.y / height);
                                root.setVolume(ratio);
                            }
                        }
                    }

                    StyledText {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: Theme.spacingM
                        text: root.volumeAvailable ? Math.round(root.currentVolume * 100) + "%" : "0%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                }
            }

            Rectangle {
                id: devicesPanel
                visible: root.dropdownType === 2
                width: 340
                height: Math.max(200, Math.min(280, root.availableDevices.length * 50 + 100))
                x: root.controlsOnLeft ? (audioDevicesButton.x + audioDevicesButton.width + Theme.spacingS) : (audioDevicesButton.x - width - Theme.spacingS)
                y: audioDevicesButton.y - (height - audioDevicesButton.height) / 2
                radius: Theme.cornerRadius * 2
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
                border.width: 2
                z: 200

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    StyledText {
                        text: "Audio Output Devices (" + root.availableDevices.length + ")"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        bottomPadding: Theme.spacingM
                    }

                    ScrollView {
                        width: parent.width
                        height: parent.height - 40
                        clip: true

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            Repeater {
                                model: root.availableDevices

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 48
                                    radius: Theme.cornerRadius
                                    color: deviceMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: modelData === AudioService.sink ? 2 : 1

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingM
                                        width: parent.width - Theme.spacingM * 2

                                        DankIcon {
                                            name: root.getAudioDeviceIcon(modelData)
                                            size: 20
                                            color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(0, parent.width - 20 - Theme.spacingM)
                                            clip: true

                                            StyledText {
                                                text: AudioService.displayName(modelData)
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                                font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            StyledText {
                                                text: modelData === AudioService.sink ? "Active" : "Available"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: deviceMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData?.name) {
                                                AudioService.setDefaultSinkByName(modelData.name);
                                                root.hideDropdowns();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: playersPanel
                visible: root.dropdownType === 3
                width: 340
                height: Math.max(180, Math.min(240, (root.allPlayers?.length || 0) * 50 + 80))
                x: root.controlsOnLeft ? (playerSelectorButton.x + playerSelectorButton.width + Theme.spacingS) : (playerSelectorButton.x - width - Theme.spacingS)
                y: playerSelectorButton.y - (height - playerSelectorButton.height) / 2
                radius: Theme.cornerRadius * 2
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
                border.width: 2
                z: 200

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    StyledText {
                        text: "Media Players (" + (root.allPlayers?.length || 0) + ")"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        bottomPadding: Theme.spacingM
                    }

                    ScrollView {
                        width: parent.width
                        height: parent.height - 40
                        clip: true

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            Repeater {
                                model: root.allPlayers || []

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 48
                                    radius: Theme.cornerRadius
                                    color: playerMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    border.color: modelData === root.activePlayer ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: modelData === root.activePlayer ? 2 : 1

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingM
                                        width: parent.width - Theme.spacingM * 2

                                        DankIcon {
                                            name: "music_note"
                                            size: 20
                                            color: modelData === root.activePlayer ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(0, parent.width - 20 - Theme.spacingM)
                                            clip: true

                                            StyledText {
                                                text: {
                                                    const identity = modelData?.identity || "Unknown Player";
                                                    const trackTitle = modelData?.trackTitle || "";
                                                    return trackTitle.length > 0 ? identity + " - " + trackTitle : identity;
                                                }
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                                font.weight: modelData === root.activePlayer ? Font.Medium : Font.Normal
                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            StyledText {
                                                text: {
                                                    const artist = modelData?.trackArtist || "";
                                                    const isActive = modelData === root.activePlayer;
                                                    if (artist.length > 0)
                                                        return artist + (isActive ? " (Active)" : "");
                                                    return isActive ? "Active" : "Available";
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                wrapMode: Text.NoWrap
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: playerMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const currentPlayer = MprisController.activePlayer;
                                            if (currentPlayer && currentPlayer !== modelData && currentPlayer.canPause) {
                                                currentPlayer.pause();
                                            }
                                            MprisController.setActivePlayer(modelData);
                                            root.hideDropdowns();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MiniButton {
                id: playerSelectorButton
                x: root.controlsOnLeft ? Theme.spacingM : parent.width - width - Theme.spacingM
                y: 160
                z: 250
                active: root.dropdownType === 3
                enabledState: (root.allPlayers?.length || 0) >= 1
                iconName: "assistant_device"
                tooltipText: "Media Players"
                onClicked: root.dropdownType = root.dropdownType === 3 ? 0 : 3
            }

            MiniButton {
                id: volumeButton
                x: root.controlsOnLeft ? Theme.spacingM : parent.width - width - Theme.spacingM
                y: 105
                z: 250
                active: root.dropdownType === 1
                enabledState: root.volumeAvailable
                iconName: root.getVolumeIcon()
                iconColor: root.volumeAvailable && root.currentVolume > 0 ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, root.volumeAvailable ? 1.0 : 0.5)
                tooltipText: ""
                onEntered: root.openVolumeDropdown()
                onExited: root.startVolumeCloseTimer()
                onClicked: root.toggleMuteOrRestore()
                onWheeled: wheelEvent => {
                    SessionData.suppressOSDTemporarily();
                    const delta = wheelEvent.angleDelta.y;
                    const current = (root.currentVolume * 100) || 0;
                    const maxVol = root.usePlayerVolume ? 100 : AudioService.sinkMaxVolume;
                    const newVolume = delta > 0 ? Math.min(maxVol, current + 5) : Math.max(0, current - 5);
                    root.setVolume(newVolume / 100);
                    wheelEvent.accepted = true;
                }
            }

            MiniButton {
                id: audioDevicesButton
                x: root.controlsOnLeft ? Theme.spacingM : parent.width - width - Theme.spacingM
                y: 215
                z: 250
                active: root.dropdownType === 2
                enabledState: true
                iconName: root.dropdownType === 2 ? "expand_less" : "speaker"
                tooltipText: "Output Device"
                onClicked: root.dropdownType = root.dropdownType === 2 ? 0 : 2
            }

        }

        MouseArea {
            anchors.fill: parent
            z: 150
            enabled: root.dropdownType !== 0
            propagateComposedEvents: false
            onClicked: root.hideDropdowns()
        }
    }
}
