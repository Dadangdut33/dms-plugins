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
    property string channelMode: "mono"
    property real responseCurve: 0.5
    property real attackSmoothing: 0.75
    property real releaseSmoothing: 0.35
    property bool peakHoldEnabled: false
    property int peakHoldMs: 450
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
    property var peakHeights: []
    property var peakTimes: []

    function resetBarHeights() {
        const values = [];
        const peaks = [];
        const times = [];
        for (let i = 0; i < effectiveBarCount; i++) {
            values.push(minBarHeight);
            peaks.push(minBarHeight);
            times.push(0);
        }
        barHeights = values;
        peakHeights = peaks;
        peakTimes = times;
    }

    function sampledLevel(index) {
        const values = CavaService.values || [];
        if (values.length === 0)
            return 0;
        if (values.length === 1)
            return values[0];
        if (effectiveBarCount <= 1)
            return values[0];

        if (channelMode === "split" || channelMode === "splitReverse") {
            const halfCount = Math.max(1, Math.ceil(effectiveBarCount / 2));
            let halfIndex = index < halfCount ? index : (index - halfCount);
            if (channelMode === "splitReverse" && index >= halfCount)
                halfIndex = Math.max(0, halfCount - 1 - halfIndex);
            const splitPosition = (halfIndex / Math.max(1, halfCount - 1)) * (values.length - 1);
            const splitLowerIndex = Math.floor(splitPosition);
            const splitUpperIndex = Math.min(values.length - 1, Math.ceil(splitPosition));
            const splitMix = splitPosition - splitLowerIndex;
            const splitLowerValue = values[splitLowerIndex] ?? 0;
            const splitUpperValue = values[splitUpperIndex] ?? splitLowerValue;
            return splitLowerValue + (splitUpperValue - splitLowerValue) * splitMix;
        }

        if (channelMode === "centerOut" || channelMode === "outsideIn") {
            const center = (effectiveBarCount - 1) / 2;
            const maxDistance = Math.max(0.5, center);
            const distanceNormalized = Math.abs(index - center) / maxDistance;
            const positionFactor = channelMode === "centerOut" ? distanceNormalized : (1 - distanceNormalized);
            const mirroredPosition = Math.max(0, Math.min(1, positionFactor)) * (values.length - 1);
            const mirroredLowerIndex = Math.floor(mirroredPosition);
            const mirroredUpperIndex = Math.min(values.length - 1, Math.ceil(mirroredPosition));
            const mirroredMix = mirroredPosition - mirroredLowerIndex;
            const mirroredLowerValue = values[mirroredLowerIndex] ?? 0;
            const mirroredUpperValue = values[mirroredUpperIndex] ?? mirroredLowerValue;
            return mirroredLowerValue + (mirroredUpperValue - mirroredLowerValue) * mirroredMix;
        }

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
            const newPeaks = [];
            const newPeakTimes = [];
            const now = Date.now();
            for (let i = 0; i < root.effectiveBarCount; i++) {
                const rawLevel = root.sampledLevel(i);
                const previousHeight = root.barHeights[i] ?? root.minBarHeight;
                const previousPeak = root.peakHeights[i] ?? root.minBarHeight;
                const previousPeakTime = root.peakTimes[i] ?? 0;
                const clampedLevel = Math.max(0, Math.min(100, rawLevel));
                const normalizedLevel = clampedLevel / 100.0;
                const curvedLevel = normalizedLevel <= 0 ? 0 : Math.pow(normalizedLevel, Math.max(0.05, root.responseCurve));
                const targetHeight = root.minBarHeight + curvedLevel * root.heightRange;
                const smoothing = targetHeight >= previousHeight ? root.attackSmoothing : root.releaseSmoothing;
                const smoothedHeight = previousHeight + (targetHeight - previousHeight) * Math.max(0, Math.min(1, smoothing));

                if (rawLevel <= 0) {
                    newHeights.push(root.minBarHeight);
                } else if (rawLevel >= 100) {
                    newHeights.push(root.maxBarHeight);
                } else {
                    newHeights.push(Math.max(root.minBarHeight, Math.min(root.maxBarHeight, smoothedHeight)));
                }

                if (!root.peakHoldEnabled) {
                    newPeaks.push(newHeights[i]);
                    newPeakTimes.push(now);
                    continue;
                }

                if (newHeights[i] >= previousPeak) {
                    newPeaks.push(newHeights[i]);
                    newPeakTimes.push(now);
                } else if (now - previousPeakTime < root.peakHoldMs) {
                    newPeaks.push(previousPeak);
                    newPeakTimes.push(previousPeakTime);
                } else {
                    const droppedPeak = Math.max(newHeights[i], previousPeak - 1.5);
                    newPeaks.push(droppedPeak);
                    newPeakTimes.push(previousPeakTime);
                }
            }
            root.barHeights = newHeights;
            root.peakHeights = newPeaks;
            root.peakTimes = newPeakTimes;
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

                Item {
                    width: root.computedBarWidth
                    height: 20

                    Rectangle {
                        width: parent.width
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

                    Rectangle {
                        visible: root.peakHoldEnabled
                        width: parent.width
                        height: 2
                        radius: 1
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.95)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.max(0, (parent.height - (root.peakHeights[index] ?? root.minBarHeight)) / 2)
                    }
                }
            }
        }
    }
}
