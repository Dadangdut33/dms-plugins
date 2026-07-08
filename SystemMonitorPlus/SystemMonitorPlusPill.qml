import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var pluginRoot
    property bool isVerticalOrientation: false

    readonly property int iconSize: Theme.barIconSize(pluginRoot.barThickness, undefined, pluginRoot.barConfig?.maximizeWidgetIcons, pluginRoot.barConfig?.iconScale)
    readonly property int textSize: Theme.barTextSize(pluginRoot.barThickness, pluginRoot.barConfig?.fontScale, pluginRoot.barConfig?.maximizeWidgetText)
    readonly property real compactGaugeSize: Math.max(iconSize + 8, Math.round(textSize * 1.75))
    readonly property real verticalGaugeSize: Math.max(iconSize + 8, Math.round(textSize * 1.75))
    readonly property real progressLineWidth: Math.max(2, Math.round(textSize * 0.12))
    readonly property real barHeight: Math.max(6, Math.round(root.textSize * 0.42))
    readonly property real verticalBarWidth: Math.max(18, pluginRoot.widgetThickness - 10)
    readonly property real compactBarWidth: Math.max(root.iconSize + 2, Math.round(root.textSize * 1.8))
    readonly property bool hasTextOnlyMetric: root.anyActiveResourceWithoutIcon()
    readonly property real normalizedSlotWidth: Math.max(root.iconSize, Math.round(root.textSize * 1.9))
    readonly property real sharedVerticalMetricWidth: root.computeSharedVerticalMetricWidth()
    readonly property real fixedTextWidthV: Math.max(root.textSize * 5.5, 64)
    readonly property real fixedTextWidthH: Math.max(root.textSize * 7, 76)

    function anyActiveResourceWithoutIcon() {
        const resources = pluginRoot.enabledResources || [];
        for (let i = 0; i < resources.length; ++i) {
            if (!pluginRoot.showIconFor(resources[i]))
                return true;
        }
        return false;
    }

    function visualIconSize(resourceKey, style) {
        if (style === "gauge")
            return gaugeIconSize(resourceKey);
        if (!root.hasTextOnlyMetric)
            return root.iconSize;
        return Math.max(root.iconSize, Math.round(root.normalizedSlotWidth * 0.82));
    }

    function computeSharedVerticalMetricWidth() {
        let width = Math.max(root.verticalGaugeSize, root.verticalBarWidth, root.normalizedSlotWidth);
        const resources = pluginRoot.enabledResources || [];
        for (let i = 0; i < resources.length; ++i) {
            const resourceKey = resources[i];
            if (pluginRoot.showTextFor(resourceKey)) {
                const baseWidth = Math.round(root.textSize * 3.9);
                width = Math.max(width, baseWidth);
                if (resourceKey === "networkSpeed") {
                    width = Math.max(width, Math.round(root.textSize * 7.5));
                }
            }
        }
        return width;
    }

    function gaugeIconSize(resourceKey) {
        switch (resourceKey) {
        case "ramUsage":
        case "gpuTemp":
            return Math.max(10, root.iconSize - 3);
        default:
            return root.iconSize;
        }
    }

    implicitWidth: isVerticalOrientation ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
    implicitHeight: isVerticalOrientation ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

    component GaugeBadge: Item {
        required property string resourceKey
        required property real badgeSize
        property bool verticalOrientation: false

        readonly property real progressValue: pluginRoot.progressFor(resourceKey)
        readonly property color accentColor: pluginRoot.colorForValue(resourceKey)
        readonly property color trackColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
        readonly property bool iconVisible: pluginRoot.showIconFor(resourceKey, verticalOrientation)
        readonly property real expandedBadgeSize: Math.max(badgeSize, Math.round(root.textSize * 2.3))
        readonly property real effectiveBadgeSize: root.hasTextOnlyMetric ? expandedBadgeSize : (iconVisible ? badgeSize : expandedBadgeSize)

        implicitWidth: effectiveBadgeSize
        implicitHeight: implicitWidth

        Canvas {
            id: gaugeCanvas
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d");
                const radius = Math.max(1, Math.min(width, height) / 2 - root.progressLineWidth);
                const start = Math.PI * 0.75;
                const end = Math.PI * 2.25;

                ctx.reset();
                ctx.lineCap = "round";
                ctx.lineWidth = root.progressLineWidth;

                ctx.beginPath();
                ctx.strokeStyle = parent.trackColor;
                ctx.arc(width / 2, height / 2, radius, start, end, false);
                ctx.stroke();

                ctx.beginPath();
                ctx.strokeStyle = parent.accentColor;
                ctx.arc(width / 2, height / 2, radius, start, start + ((end - start) * parent.progressValue), false);
                ctx.stroke();
            }
        }

        onProgressValueChanged: gaugeCanvas.requestPaint()
        onAccentColorChanged: gaugeCanvas.requestPaint()
        onTrackColorChanged: gaugeCanvas.requestPaint()

        DankIcon {
            visible: parent.iconVisible
            anchors.centerIn: parent
            name: pluginRoot.iconNameFor(parent.resourceKey)
            size: Math.max(root.gaugeIconSize(parent.resourceKey), Math.round(parent.effectiveBadgeSize * 0.48))
            color: parent.accentColor
        }

        StyledText {
            visible: !parent.iconVisible
            anchors.centerIn: parent
            text: pluginRoot.formatValue(parent.resourceKey)
            width: Math.max(14, parent.width - root.progressLineWidth * 5)
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Math.max(9, Math.min(root.textSize, parent.width * 0.36))
            color: pluginRoot.textColorFor(parent.resourceKey)
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
        }
    }

    component HorizontalMetric: Item {
        id: horizontalMetric
        required property string resourceKey

        readonly property string currentStyle: pluginRoot.styleFor(resourceKey)
        readonly property real visualSlotWidth: {
            if (root.hasTextOnlyMetric)
                return Math.max(root.normalizedSlotWidth, currentStyle === "gauge" ? root.compactGaugeSize : 0);
            switch (currentStyle) {
            case "gauge":
                return root.compactGaugeSize;
            case "bar":
                return Math.max(root.iconSize, root.compactBarWidth);
            default:
                return root.iconSize;
            }
        }

        implicitWidth: metricRow.implicitWidth
        implicitHeight: metricRow.implicitHeight

        Row {
            id: metricRow
            spacing: Theme.spacingXS

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: horizontalMetric.visualSlotWidth
                height: Math.max(root.iconSize, visualColumn.implicitHeight, gaugeBadge.implicitHeight)

                GaugeBadge {
                    id: gaugeBadge
                    visible: horizontalMetric.currentStyle === "gauge"
                    anchors.centerIn: parent
                    resourceKey: horizontalMetric.resourceKey
                    badgeSize: root.compactGaugeSize
                }

                Column {
                    id: visualColumn
                    visible: horizontalMetric.currentStyle !== "gauge" && (pluginRoot.showIconFor(horizontalMetric.resourceKey) || horizontalMetric.currentStyle === "bar")
                    spacing: Theme.spacingXS / 2
                    anchors.centerIn: parent

                    DankIcon {
                        visible: pluginRoot.showIconFor(horizontalMetric.resourceKey)
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: pluginRoot.iconNameFor(horizontalMetric.resourceKey)
                        size: root.visualIconSize(horizontalMetric.resourceKey, horizontalMetric.currentStyle)
                        color: pluginRoot.colorForValue(horizontalMetric.resourceKey)
                    }

                    Rectangle {
                        visible: horizontalMetric.currentStyle === "bar"
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: root.compactBarWidth
                        implicitHeight: root.barHeight
                        radius: height / 2
                        color: Qt.rgba(pluginRoot.colorForValue(horizontalMetric.resourceKey).r, pluginRoot.colorForValue(horizontalMetric.resourceKey).g, pluginRoot.colorForValue(horizontalMetric.resourceKey).b, 0.18)
                        clip: true

                        Rectangle {
                            width: parent.width * pluginRoot.progressFor(horizontalMetric.resourceKey)
                            height: parent.height
                            radius: parent.radius
                            color: pluginRoot.colorForValue(horizontalMetric.resourceKey)
                        }
                    }
                }
            }

            StyledText {
                visible: pluginRoot.showTextFor(horizontalMetric.resourceKey)
                anchors.verticalCenter: parent.verticalCenter
                text: pluginRoot.formatValue(horizontalMetric.resourceKey, false)
                width: pluginRoot.showFixedTextWidthFor(horizontalMetric.resourceKey) ? pluginRoot.horizontalFixedTextWidth(horizontalMetric.resourceKey) : undefined
                font.pixelSize: root.textSize
                color: pluginRoot.textColorFor(horizontalMetric.resourceKey)
                wrapMode: Text.NoWrap
                elide: pluginRoot.showFixedTextWidthFor(horizontalMetric.resourceKey) ? Text.ElideRight : Text.ElideNone
            }
        }
    }

    component VerticalMetric: Item {
        id: verticalMetric
        required property string resourceKey

        readonly property string currentStyle: pluginRoot.styleFor(resourceKey)
        readonly property real visualSlotWidth: {
            if (root.hasTextOnlyMetric)
                return Math.max(root.normalizedSlotWidth, currentStyle === "gauge" ? root.verticalGaugeSize : root.verticalBarWidth);
            if (currentStyle === "gauge")
                return root.verticalGaugeSize;
            if (currentStyle === "bar")
                return Math.max(root.iconSize, root.verticalBarWidth);
            return root.iconSize;
        }
        readonly property real effectiveMetricWidth: root.sharedVerticalMetricWidth

        width: effectiveMetricWidth
        implicitWidth: width
        implicitHeight: metricColumn.implicitHeight

        Column {
            id: metricColumn
            spacing: Theme.spacingXS / 1.5
            anchors.centerIn: parent
            width: parent.width

            GaugeBadge {
                visible: verticalMetric.currentStyle === "gauge"
                anchors.horizontalCenter: parent.horizontalCenter
                resourceKey: verticalMetric.resourceKey
                badgeSize: root.verticalGaugeSize
                verticalOrientation: true
            }

            Column {
                visible: verticalMetric.currentStyle !== "gauge"
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingXS / 2

                DankIcon {
                    visible: pluginRoot.showIconFor(verticalMetric.resourceKey, true)
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: pluginRoot.iconNameFor(verticalMetric.resourceKey)
                    size: root.visualIconSize(verticalMetric.resourceKey, verticalMetric.currentStyle)
                    color: pluginRoot.colorForValue(verticalMetric.resourceKey)
                }

                Rectangle {
                    visible: verticalMetric.currentStyle === "bar"
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: root.verticalBarWidth
                    implicitHeight: root.barHeight
                    radius: height / 2
                    color: Qt.rgba(pluginRoot.colorForValue(verticalMetric.resourceKey).r, pluginRoot.colorForValue(verticalMetric.resourceKey).g, pluginRoot.colorForValue(verticalMetric.resourceKey).b, 0.18)
                    clip: true

                    Rectangle {
                        width: parent.width * pluginRoot.progressFor(verticalMetric.resourceKey)
                        height: parent.height
                        radius: parent.radius
                        color: pluginRoot.colorForValue(verticalMetric.resourceKey)
                    }
                }
            }

            Column {
                visible: pluginRoot.showTextFor(verticalMetric.resourceKey)
                anchors.horizontalCenter: parent.horizontalCenter
                width: pluginRoot.showFixedTextWidthFor(verticalMetric.resourceKey) ? root.fixedTextWidthV : parent.width
                spacing: Theme.spacingXS / 2

                Repeater {
                    model: verticalMetric.resourceKey === "networkSpeed" && pluginRoot.hideNetworkDirectionArrows(verticalMetric.resourceKey) ? [
                        {
                            text: pluginRoot._downloadSpeedFormatted,
                            color: pluginRoot.networkSpeedDownloadColor()
                        },
                        {
                            text: pluginRoot._uploadSpeedFormatted,
                            color: pluginRoot.networkSpeedUploadColor()
                        }
                    ] : [
                        {
                            text: pluginRoot.formatValue(verticalMetric.resourceKey, true),
                            color: pluginRoot.textColorFor(verticalMetric.resourceKey)
                        }
                    ]

                    delegate: StyledText {
                        text: modelData.text
                        width: parent.width
                        font.pixelSize: verticalMetric.resourceKey === "networkSpeed" ? Math.max(root.textSize * 0.58, 9) : root.textSize
                        color: modelData.color
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        elide: pluginRoot.showFixedTextWidthFor(verticalMetric.resourceKey) ? Text.ElideRight : Text.ElideNone
                    }
                }
            }
        }
    }

    Item {
        id: horizontalLayout
        visible: !root.isVerticalOrientation
        implicitWidth: horizontalResources.implicitWidth
        implicitHeight: horizontalResources.implicitHeight

        Row {
            id: horizontalResources
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Repeater {
                model: pluginRoot.enabledResources

                delegate: HorizontalMetric {
                    required property var modelData
                    resourceKey: modelData
                }
            }
        }
    }

    Item {
        id: verticalLayout
        visible: root.isVerticalOrientation
        implicitWidth: verticalResources.implicitWidth
        implicitHeight: verticalResources.implicitHeight

        Column {
            id: verticalResources
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Repeater {
                model: pluginRoot.enabledResources

                delegate: VerticalMetric {
                    required property var modelData
                    resourceKey: modelData
                }
            }
        }
    }
}
