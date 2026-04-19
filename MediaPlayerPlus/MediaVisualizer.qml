import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    property bool verticalMode: false
    property real barSpan: 20
    property int barCount: 6
    property bool stretchToWidth: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasActiveMedia: activePlayer !== null
    readonly property bool isPlaying: hasActiveMedia && activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property int effectiveBarCount: Math.max(1, barCount)
    readonly property real baseBarWidth: 2
    readonly property real baseSpacing: 1.5
    readonly property real computedSpacing: stretchToWidth ? (effectiveBarCount > 1 ? 1 : 0) : baseSpacing
    readonly property real computedBarWidth: {
        if (!stretchToWidth)
            return baseBarWidth;
        const totalSpacing = computedSpacing * Math.max(0, effectiveBarCount - 1);
        return Math.max(1, (barSpan - totalSpacing) / effectiveBarCount);
    }
    readonly property real contentSpan: stretchToWidth ? barSpan : (effectiveBarCount * computedBarWidth + Math.max(0, effectiveBarCount - 1) * computedSpacing)

    width: verticalMode ? 20 : barSpan
    height: verticalMode ? barSpan : 20

    Loader {
        active: isPlaying

        sourceComponent: Component {
            Ref {
                service: CavaService
            }
        }
    }

    readonly property real maxBarHeight: 18
    readonly property real minBarHeight: 3
    readonly property real heightRange: maxBarHeight - minBarHeight
    property var barHeights: []

    function resetBarHeights() {
        const values = [];
        for (let i = 0; i < effectiveBarCount; i++)
            values.push(minBarHeight);
        barHeights = values;
    }

    function sampledLevel(index) {
        const values = CavaService.values || [];
        if (values.length === 0)
            return 0;
        if (values.length === 1)
            return values[0];
        if (effectiveBarCount <= 1)
            return values[0];

        const position = (index / Math.max(1, effectiveBarCount - 1)) * (values.length - 1);
        const lowerIndex = Math.floor(position);
        const upperIndex = Math.min(values.length - 1, Math.ceil(position));
        const mix = position - lowerIndex;
        const lowerValue = values[lowerIndex] ?? 0;
        const upperValue = values[upperIndex] ?? lowerValue;
        return lowerValue + (upperValue - lowerValue) * mix;
    }

    Component.onCompleted: resetBarHeights()
    onEffectiveBarCountChanged: resetBarHeights()

    Timer {
        id: fallbackTimer

        running: !CavaService.cavaAvailable && isPlaying
        interval: 500
        repeat: true
        onTriggered: {
            const values = [];
            for (let i = 0; i < root.effectiveBarCount; i++)
                values.push(Math.random() * 25 + 5);
            CavaService.values = values;
        }
    }

    Connections {
        target: CavaService
        function onValuesChanged() {
            if (!root.isPlaying) {
                root.resetBarHeights();
                return;
            }

            const newHeights = [];
            for (let i = 0; i < root.effectiveBarCount; i++) {
                const rawLevel = root.sampledLevel(i);
                if (rawLevel <= 0) {
                    newHeights.push(root.minBarHeight);
                } else if (rawLevel >= 100) {
                    newHeights.push(root.maxBarHeight);
                } else {
                    newHeights.push(root.minBarHeight + Math.sqrt(rawLevel * 0.01) * root.heightRange);
                }
            }
            root.barHeights = newHeights;
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.contentSpan
        height: 20
        rotation: root.verticalMode ? 90 : 0

        Row {
            anchors.centerIn: parent
            spacing: root.computedSpacing

            Repeater {
                model: root.effectiveBarCount

                Rectangle {
                    width: root.computedBarWidth
                    height: root.barHeights[index]
                    radius: 1.5
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on height {
                        enabled: root.isPlaying && !CavaService.cavaAvailable
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.Linear
                        }
                    }
                }
            }
        }
    }
}
