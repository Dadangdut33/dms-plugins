import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    pluginId: "systemMonitorPlus"
    layerNamespacePlugin: "system-monitor-plus"

    readonly property var allResourceKeys: ["cpuUsage", "cpuTemp", "ramUsage", "gpuTemp", "diskPartitionUsage", "networkSpeed"]
    readonly property var enabledResources: visibleResources()
    readonly property string primaryResource: enabledResources.length > 0 ? enabledResources[0] : "cpuUsage"
    readonly property string resourceSignature: JSON.stringify(enabledResources) + "|" + gpuSubscriptionSignature()

    property var _trackedModules: []
    property var _trackedGpuPciIds: []
    property var _parsedDiskMounts: []
    property real _parsedDiskMountsPercent: -1
    readonly property real _downloadSpeedValue: DgopService.networkRxRate ?? 0
    readonly property real _uploadSpeedValue: DgopService.networkTxRate ?? 0
    readonly property string _downloadSpeedFormatted: formatSpeed(DgopService.networkRxRate)
    readonly property string _uploadSpeedFormatted: formatSpeed(DgopService.networkTxRate)

    pillRightClickAction: rightClickSettingsEnabled() ? (() => {
            PopoutService.openSettingsWithTab("plugins");
        }) : null

    pillClickAction: () => {
        openProcessList();
    }

    function pluginValue(key, fallback) {
        const value = pluginData[key];
        if (value === undefined)
            return fallback;
        if (typeof fallback === "boolean") {
            if (typeof value === "string") {
                const lower = value.trim().toLowerCase();
                if (lower === "true")
                    return true;
                if (lower === "false")
                    return false;
            }
            return Boolean(value);
        }
        return value;
    }

    function rightClickSettingsEnabled() {
        return pluginValue("EnableRightClickSettings", true);
    }

    function parseColorString(value, fallback) {
        if (value && value.r !== undefined && value.g !== undefined && value.b !== undefined)
            return value;
        if (typeof value !== "string" || value.trim().length === 0)
            return fallback;
        try {
            return Qt.color(value.trim());
        } catch (error) {
            return fallback;
        }
    }

    function resourceInfo(kind) {
        switch (kind) {
        case "cpuTemp":
            return {
                "label": "CPU Temperature",
                "icon": "device_thermostat",
                "module": "cpu",
                "sortKey": "cpu",
                "placeholder": "--°",
                "unit": "°",
                "maxValue": 100,
                "warning": 70,
                "danger": 85,
                "precision": 0
            };
        case "ramUsage":
            return {
                "label": "RAM Usage",
                "icon": "developer_board",
                "module": "memory",
                "sortKey": "memory",
                "placeholder": "--%",
                "unit": "%",
                "maxValue": 100,
                "warning": 75,
                "danger": 90,
                "precision": 0
            };
        case "gpuTemp":
            return {
                "label": "GPU Temperature",
                "icon": "auto_awesome_mosaic",
                "module": "gpu",
                "sortKey": "cpu",
                "placeholder": "--°",
                "unit": "°",
                "maxValue": 100,
                "warning": 65,
                "danger": 80,
                "precision": 0
            };
        case "diskPartitionUsage":
            return {
                "label": "Disk Usage",
                "icon": "storage",
                "module": "diskmounts",
                "sortKey": "diskmounts",
                "placeholder": "--%",
                "unit": "%",
                "maxValue": 100,
                "warning": 80,
                "danger": 90,
                "precision": 0
            };
        case "networkSpeed":
            return {
                "label": "Network Speed",
                "icon": "network_cell",
                "module": "network",
                "sortKey": "network",
                "placeholder": "--",
                "unit": "",
                "maxValue": 100,
                "warning": 70,
                "danger": 90,
                "precision": 0
            };
        case "cpuUsage":
        default:
            return {
                "label": "CPU Usage",
                "icon": "memory",
                "module": "cpu",
                "sortKey": "cpu",
                "placeholder": "--%",
                "unit": "%",
                "maxValue": 100,
                "warning": 60,
                "danger": 80,
                "precision": 0
            };
        }
    }

    function resourceOrder() {
        const defaultOrder = allResourceKeys.slice();
        const rawOrder = String(pluginValue("resourceOrder", defaultOrder.join(",")));
        const parsed = rawOrder.split(/[,\s]+/).filter(Boolean);
        const seen = {};
        const finalOrder = [];
        for (const key of parsed) {
            if (allResourceKeys.indexOf(key) === -1 || seen[key])
                continue;
            seen[key] = true;
            finalOrder.push(key);
        }
        for (const key of defaultOrder) {
            if (!seen[key])
                finalOrder.push(key);
        }
        return finalOrder;
    }

    function visibleResources() {
        const ordered = resourceOrder();
        const visible = [];
        for (const key of ordered) {
            if (pluginValue(key + "Enabled", key === "cpuUsage"))
                visible.push(key);
        }
        return visible.length > 0 ? visible : ["cpuUsage"];
    }

    function resolveSelectedGpu(resourceKey) {
        const gpus = DgopService.availableGpus || [];
        if (gpus.length === 0)
            return null;

        const selectedPciId = String(pluginValue(resourceKey + "SelectedGpuPciId", ""));
        if (selectedPciId.length > 0) {
            for (const gpu of gpus) {
                if (gpu.pciId === selectedPciId)
                    return gpu;
            }
        }
        return gpus[0];
    }

    function currentValue(resourceKey) {
        const gpu = resolveSelectedGpu(resourceKey);
        switch (resourceKey) {
        case "cpuTemp":
            return DgopService.cpuTemperature;
        case "ramUsage":
            return DgopService.memoryUsage;
        case "gpuTemp":
            return gpu ? (gpu.temperature || 0) : 0;
        case "diskPartitionUsage":
            return _parsedDiskMountsPercent >= 0 ? _parsedDiskMountsPercent : 0;
        case "networkSpeed":
            return Math.max(_downloadSpeedValue, _uploadSpeedValue);
        case "cpuUsage":
        default:
            return DgopService.cpuUsage;
        }
    }

    function hasValue(resourceKey) {
        if (resourceKey === "gpuTemp")
            return resolveSelectedGpu(resourceKey) !== null;
        if (resourceKey === "diskPartitionUsage")
            return _parsedDiskMountsPercent >= 0;
        if (resourceKey === "networkSpeed")
            return Math.max(_downloadSpeedValue, _uploadSpeedValue) > 0;
        const value = currentValue(resourceKey);
        return value !== undefined && value !== null;
    }

    function ramTextMode() {
        return String(pluginValue("ramUsageTextMode", "percentage"));
    }

    function formatDiskUsage() {
        const mounts = DgopService.diskMounts;
        if (Array.isArray(mounts) && mounts.length > 0) {
            const mountPoint = String(root.pluginValue("diskPartitionUsageMount", "/"));
            for (let i = 0; i < mounts.length; i++) {
                if (mounts[i].mount === mountPoint) {
                    root._parsedDiskMountsPercent = mounts[i].percent.replace("%", "");
                    return mounts[i].percent;
                }
            }
            root._parsedDiskMountsPercent = -2;
            return "-2%";
        } else {
            root._parsedDiskMountsPercent = -3;
            return "-3%";
        }
    }

    function formatNetworkSpeed(verticalCompact = false) {
        const downloadText = formatSpeed(DgopService.networkRxRate);
        const uploadText = formatSpeed(DgopService.networkTxRate);
        if (verticalCompact)
            return "↓ " + downloadText + "\n↑ " + uploadText;
        const separator = pluginValue("networkSpeedShowSeparator", true) ? " / " : " ";
        return "↓ " + downloadText + separator + "↑ " + uploadText;
    }

    function formatSpeed(bytesPerSecond) {
        if (bytesPerSecond === undefined || bytesPerSecond === null || bytesPerSecond < 0)
            return "--";
        const bytes = Number(bytesPerSecond);
        const shortUnits = pluginValue("networkSpeedShortUnits", false);
        if (bytes >= 1e9)
            return shortUnits ? (bytes / 1e9).toFixed(1) + "G" : (bytes / 1e9).toFixed(1) + " GB/s";
        if (bytes >= 1e6)
            return shortUnits ? (bytes / 1e6).toFixed(1) + "M" : (bytes / 1e6).toFixed(1) + " MB/s";
        if (bytes >= 1e3)
            return shortUnits ? Math.round(bytes / 1e3).toString() + "K" : Math.round(bytes / 1e3).toString() + " KB/s";
        return shortUnits ? Math.round(bytes).toString() + "B" : Math.round(bytes).toString() + " B/s";
    }

    function formatMemoryGb(valueMb) {
        if (valueMb === undefined || valueMb === null || valueMb <= 0)
            return "-- GB";
        return (Number(valueMb) / 1024).toFixed(1) + " GB";
    }

    function formatRamValue(verticalCompact = false) {
        const percentAvailable = DgopService.memoryUsage !== undefined && DgopService.memoryUsage !== null;
        const percentText = percentAvailable ? Number(DgopService.memoryUsage).toFixed(0) + "%" : "--%";
        const valueText = formatMemoryGb(DgopService.usedMemoryMB);

        switch (ramTextMode()) {
        case "value":
            return valueText;
        case "custom":
            return applyRamTemplate(ramTemplate(), verticalCompact);
        case "percentageAndValue":
            return verticalCompact ? (percentText + "\n" + valueText) : (percentText + " · " + valueText);
        case "percentage":
        default:
            return percentText;
        }
    }

    function ramTemplate() {
        return String(pluginValue("ramUsageCustomTemplate", "{percent}"));
    }

    function applyRamTemplate(templateValue, verticalCompact) {
        const replacements = {
            "{percent}": DgopService.memoryUsage !== undefined && DgopService.memoryUsage !== null ? Number(DgopService.memoryUsage).toFixed(0) + "%" : "--%",
            "{usedGB}": formatMemoryGb(DgopService.usedMemoryMB),
            "{usedMB}": DgopService.usedMemoryMB !== undefined && DgopService.usedMemoryMB !== null ? Math.round(Number(DgopService.usedMemoryMB)).toString() + " MB" : "-- MB",
            "{totalGB}": formatMemoryGb(DgopService.totalMemoryMB),
            "{totalMB}": DgopService.totalMemoryMB !== undefined && DgopService.totalMemoryMB !== null ? Math.round(Number(DgopService.totalMemoryMB)).toString() + " MB" : "-- MB",
            "{freeGB}": formatMemoryGb(DgopService.freeMemoryMB),
            "{availableGB}": formatMemoryGb(DgopService.availableMemoryMB)
        };

        let output = templateValue;
        for (const key in replacements)
            output = output.split(key).join(replacements[key]);
        if (verticalCompact)
            output = output.split(" · ").join("\n");
        return output;
    }

    function formatValue(resourceKey, verticalCompact = false) {
        const meta = resourceInfo(resourceKey);
        if (resourceKey === "ramUsage")
            return formatRamValue(verticalCompact);
        if (resourceKey === "networkSpeed")
            return formatNetworkSpeed(verticalCompact);
        if (resourceKey === "diskPartitionUsage")
            return formatDiskUsage();
        if (!hasValue(resourceKey))
            return meta.placeholder;
        const value = currentValue(resourceKey);
        if (resourceKey === "cpuTemp" || resourceKey === "gpuTemp")
            return Math.round(value).toString() + meta.unit;
        return Number(value).toFixed(meta.precision) + meta.unit;
    }

    function progressFor(resourceKey) {
        if (resourceKey === "networkSpeed") {
            const speedKb = Math.max(_downloadSpeedValue, _uploadSpeedValue) / 1024;
            const maxValue = Math.max(1, Number(pluginValue(resourceKey + "ProgressMaxValue", resourceInfo(resourceKey).maxValue)));
            return Math.max(0, Math.min(1, speedKb / maxValue));
        }
        const maxValue = Math.max(1, Number(pluginValue(resourceKey + "ProgressMaxValue", resourceInfo(resourceKey).maxValue)));
        return Math.max(0, Math.min(1, Number(currentValue(resourceKey) || 0) / maxValue));
    }

    function styleFor(resourceKey) {
        return String(pluginValue(resourceKey + "VisualStyle", "default"));
    }

    function showIconFor(resourceKey, isVertical = false) {
        return pluginValue(resourceKey + "ShowIcon", true);
    }

    function hideNetworkDirectionArrows(resourceKey) {
        return resourceKey === "networkSpeed" && pluginValue("networkSpeedHideVerticalIcon", false);
    }

    function showFixedTextWidthFor(resourceKey) {
        return pluginValue(resourceKey + "FixedTextWidth", false);
    }

    function horizontalFixedTextWidth(resourceKey) {
        const defaultWidth = resourceKey === "networkSpeed" ? 76 : 0;
        const widthValue = Number(pluginValue(resourceKey + "FixedTextWidthH", defaultWidth));
        return widthValue > 0 ? widthValue : defaultWidth;
    }

    function showTextFor(resourceKey) {
        return pluginValue(resourceKey + "ShowText", true);
    }

    function useValueColorsFor(resourceKey) {
        return pluginValue(resourceKey + "UseValueColors", true);
    }

    function colorizeTextFor(resourceKey) {
        return pluginValue(resourceKey + "ColorizeText", false);
    }

    function warningThresholdFor(resourceKey) {
        return Number(pluginValue(resourceKey + "WarningThreshold", resourceInfo(resourceKey).warning));
    }

    function dangerThresholdFor(resourceKey) {
        return Number(pluginValue(resourceKey + "DangerThreshold", resourceInfo(resourceKey).danger));
    }

    function themeColorFromKey(key, customColor, fallback) {
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
        case "custom":
            return customColor;
        case "widgetText":
            return Theme.widgetTextColor;
        default:
            return fallback;
        }
    }

    function colorForValue(resourceKey) {
        const value = resourceKey === "networkSpeed" ? Math.max(_downloadSpeedValue, _uploadSpeedValue) / 1024 : currentValue(resourceKey);
        if (!useValueColorsFor(resourceKey)) {
            return themeColorFromKey(String(pluginValue(resourceKey + "FixedColorKey", "primary")), parseColorString(pluginValue(resourceKey + "FixedCustomColor", Theme.primary.toString()), Theme.primary), Theme.primary);
        }

        if (value >= dangerThresholdFor(resourceKey)) {
            return themeColorFromKey(String(pluginValue(resourceKey + "DangerColorKey", "error")), parseColorString(pluginValue(resourceKey + "DangerCustomColor", Theme.error.toString()), Theme.error), Theme.error);
        }
        if (value >= warningThresholdFor(resourceKey)) {
            return themeColorFromKey(String(pluginValue(resourceKey + "WarningColorKey", "warning")), parseColorString(pluginValue(resourceKey + "WarningCustomColor", Theme.warning.toString()), Theme.warning), Theme.warning);
        }
        return themeColorFromKey(String(pluginValue(resourceKey + "NormalColorKey", "primary")), parseColorString(pluginValue(resourceKey + "NormalCustomColor", Theme.primary.toString()), Theme.primary), Theme.primary);
    }

    function textColorFor(resourceKey) {
        return colorizeTextFor(resourceKey) ? colorForValue(resourceKey) : Theme.widgetTextColor;
    }

    function networkSpeedDownloadColor() {
        return parseColorString(pluginValue("networkSpeedDownloadColor", Theme.primary), Theme.primary);
    }

    function networkSpeedUploadColor() {
        return parseColorString(pluginValue("networkSpeedUploadColor", Theme.secondary), Theme.secondary);
    }

    function iconNameFor(resourceKey) {
        const customIcon = String(pluginValue(resourceKey + "IconName", ""));
        return customIcon.length > 0 ? customIcon : resourceInfo(resourceKey).icon;
    }

    function gpuSubscriptionSignature() {
        const ids = [];
        for (const key of enabledResources) {
            if (resourceInfo(key).module !== "gpu")
                continue;
            const gpu = resolveSelectedGpu(key);
            if (gpu?.pciId && ids.indexOf(gpu.pciId) === -1)
                ids.push(gpu.pciId);
        }
        return ids.join(",");
    }

    function syncDgopSubscriptions() {
        if (_trackedModules.length > 0) {
            DgopService.removeRef(_trackedModules);
            _trackedModules = [];
        }
        for (const pciId of _trackedGpuPciIds) {
            DgopService.removeGpuPciId(pciId);
        }
        _trackedGpuPciIds = [];

        const modules = [];
        for (const key of enabledResources) {
            const moduleKey = resourceInfo(key).module;
            if (modules.indexOf(moduleKey) === -1)
                modules.push(moduleKey);
        }
        if (modules.length === 0)
            modules.push("cpu");

        DgopService.addRef(modules);
        _trackedModules = modules;

        const gpuIds = gpuSubscriptionSignature().split(",").filter(Boolean);
        for (const pciId of gpuIds) {
            DgopService.addGpuPciId(pciId);
        }
        _trackedGpuPciIds = gpuIds;
    }

    function cleanupDgopSubscriptions() {
        if (_trackedModules.length > 0) {
            DgopService.removeRef(_trackedModules);
            _trackedModules = [];
        }
        for (const pciId of _trackedGpuPciIds) {
            DgopService.removeGpuPciId(pciId);
        }
        _trackedGpuPciIds = [];
    }

    function openProcessList() {
        DgopService.setSortBy(resourceInfo(primaryResource).sortKey);

        if (!PopoutService.processListPopoutLoader) {
            PopoutService.toggleProcessListModal();
            return;
        }

        PopoutService.processListPopoutLoader.active = true;
        Qt.callLater(() => {
            const popout = PopoutService.processListPopout || PopoutService.processListPopoutLoader.item;
            if (!popout)
                return;

            const currentScreen = root.parentScreen || Screen;
            const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
            const globalPos = root.mapToItem(null, 0, 0);
            const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, root.width, root.barSpacing, barPosition, root.barConfig);
            if (popout.setBarContext) {
                popout.setBarContext(barPosition, root.barConfig?.bottomGap ?? 0);
            }
            if (popout.setTriggerPosition) {
                popout.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
            }

            PopoutManager.requestPopout(popout, undefined, "system-monitor-plus-" + primaryResource);
        });
    }

    onResourceSignatureChanged: Qt.callLater(syncDgopSubscriptions)

    Component.onCompleted: {
        syncDgopSubscriptions();
    }

    Component.onDestruction: {
        cleanupDgopSubscriptions();
    }

    popoutContent: Component {
        Column {
            width: root.popoutWidth
            spacing: Theme.spacingS

            Repeater {
                model: _parsedDiskMounts
                delegate: Row {
                    width: parent.width
                    height: 32
                    spacing: Theme.spacingM

                    StyledText {
                        text: modelData.mount
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        width: 100
                    }

                    StyledText {
                        text: modelData.size
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        width: 90
                    }

                    StyledText {
                        text: (modelData.used || "") + " / " + (modelData.avail || "")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: modelData.percent
                        font.pixelSize: Theme.fontSizeMedium
                        horizontalAlignment: Text.AlignRight
                        width: 50
                        color: modelData.mount === String(pluginValue("diskPartitionUsageMount", "/")) ? Theme.primary : Theme.surfaceVariantText
                        font.weight: modelData.mount === String(pluginValue("diskPartitionUsageMount", "/")) ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        SystemMonitorPlusPill {
            pluginRoot: root
            isVerticalOrientation: false
        }
    }

    verticalBarPill: Component {
        SystemMonitorPlusPill {
            pluginRoot: root
            isVerticalOrientation: true
        }
    }
}
