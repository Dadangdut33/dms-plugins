import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "systemMonitorPlus"
    property int currentTab: 0
    property bool resourceCardActive: true

    readonly property var allResourceKeys: ["cpuUsage", "cpuTemp", "ramUsage", "gpuTemp", "diskPartitionUsage"]
    readonly property var colorOptions: [
        {
            "label": "Widget Text",
            "value": "widgetText"
        },
        {
            "label": "Primary",
            "value": "primary"
        },
        {
            "label": "Primary Text",
            "value": "primaryText"
        },
        {
            "label": "Primary Container",
            "value": "primaryContainer"
        },
        {
            "label": "Secondary",
            "value": "secondary"
        },
        {
            "label": "Surface",
            "value": "surface"
        },
        {
            "label": "Surface Text",
            "value": "surfaceText"
        },
        {
            "label": "Surface Variant",
            "value": "surfaceVariant"
        },
        {
            "label": "Surface Variant Text",
            "value": "surfaceVariantText"
        },
        {
            "label": "Surface Tint",
            "value": "surfaceTint"
        },
        {
            "label": "Background",
            "value": "background"
        },
        {
            "label": "Background Text",
            "value": "backgroundText"
        },
        {
            "label": "Outline",
            "value": "outline"
        },
        {
            "label": "Surface Container",
            "value": "surfaceContainer"
        },
        {
            "label": "Surface Container High",
            "value": "surfaceContainerHigh"
        },
        {
            "label": "Surface Container Highest",
            "value": "surfaceContainerHighest"
        },
        {
            "label": "Error",
            "value": "error"
        },
        {
            "label": "Warning",
            "value": "warning"
        },
        {
            "label": "Info",
            "value": "info"
        },
        {
            "label": "Custom",
            "value": "custom"
        }
    ]
    readonly property var styleOptions: [
        {
            "label": "Default",
            "value": "default"
        },
        {
            "label": "Gauge",
            "value": "gauge"
        },
        {
            "label": "Bar",
            "value": "bar"
        }
    ]
    readonly property var ramTextModeOptions: [
        {
            "label": "Percentage",
            "value": "percentage"
        },
        {
            "label": "Value",
            "value": "value"
        },
        {
            "label": "Percentage + Value",
            "value": "percentageAndValue"
        },
        {
            "label": "Custom",
            "value": "custom"
        }
    ]

    function labelForResource(key) {
        switch (key) {
        case "cpuTemp":
            return "CPU Temperature";
        case "ramUsage":
            return "RAM Usage";
        case "gpuTemp":
            return "GPU Temperature";
        case "diskPartitionUsage":
            return "Disk Usage";
        case "cpuUsage":
        default:
            return "CPU Usage";
        }
    }

    function descriptionForResource(key) {
        switch (key) {
        case "cpuTemp":
            return "Monitor CPU thermals from DgopService.";
        case "ramUsage":
            return "Monitor memory usage from DgopService.";
        case "gpuTemp":
            return "Monitor GPU temperature from DgopService for a selected GPU.";
        case "diskPartitionUsage":
            return "Monitor disk partition usage from dgop.";
        case "cpuUsage":
        default:
            return "Monitor CPU load from DgopService.";
        }
    }

    function defaultIconForResource(key) {
        switch (key) {
        case "cpuTemp":
            return "device_thermostat";
        case "ramUsage":
            return "developer_board";
        case "gpuTemp":
            return "auto_awesome_mosaic";
        case "diskPartitionUsage":
            return "sd_storage";
        case "cpuUsage":
        default:
            return "memory";
        }
    }

    function defaultWarningThreshold(key) {
        switch (key) {
        case "cpuTemp":
            return 70;
        case "ramUsage":
            return 75;
        case "gpuTemp":
            return 65;
        case "diskPartitionUsage":
            return 80;
        case "cpuUsage":
        default:
            return 60;
        }
    }

    function defaultDangerThreshold(key) {
        switch (key) {
        case "cpuTemp":
            return 85;
        case "ramUsage":
            return 90;
        case "gpuTemp":
            return 80;
        case "diskPartitionUsage":
            return 90;
        case "cpuUsage":
        default:
            return 80;
        }
    }

    function gpuOptions() {
        const items = [];
        const gpus = DgopService.availableGpus || [];
        for (let i = 0; i < gpus.length; i++) {
            const gpu = gpus[i];
            items.push({
                "label": gpu.displayName || gpu.fullName || ("GPU " + (i + 1)),
                "value": gpu.pciId
            });
        }
        return items;
    }

    Process {
        id: diskMountsProcess
        command: ["dgop", "disk", "--json"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError("Disk init process failed with exit code:", exitCode);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        const data = JSON.parse(text.trim());
                        _diskMounts = data.mounts || [];
                    } catch (e) {
                        ToastService.showError("Failed to parse disk init JSON:", e);
                    }
                }
            }
        }
    }

    function refreshDiskMounts() {
        _diskMounts = [];
        diskMountsProcess.running = true;
    }

    property var _diskMounts: []
    function diskMountOptions(resourceKey) {
        if (_diskMounts.length === 0)
            return [];
        return _diskMounts.map(m => ({
            label: m.mount + " (" + m.size + ")",
            value: m.mount
        }));

        // return [{label: "/", value: "/"},{label: "/home", value: "/home"}];
    }

    function resourceIsGpu(key) {
        return key === "gpuTemp";
    }

    function resourceUsesProgressScale(key) {
        return key === "cpuTemp" || key === "gpuTemp";
    }

    function progressScaleUnit(key) {
        switch (key) {
        case "cpuTemp":
        case "gpuTemp":
            return "°";
        default:
            return "";
        }
    }

    function loadedValue(key, fallback) {
        const value = loadValue(key, fallback);
        return (value === undefined || value === null) ? fallback : value;
    }

    function defaultResourceOrder() {
        return allResourceKeys.slice();
    }

    function initResourceOrderModel() {
        const parsed = String(loadValue("resourceOrder", defaultResourceOrder().join(","))).split(/[,\s]+/).filter(Boolean);
        const seen = {};
        const finalOrder = [];
        for (const key of parsed) {
            if (allResourceKeys.indexOf(key) === -1 || seen[key])
                continue;
            seen[key] = true;
            finalOrder.push(key);
        }
        for (const key of defaultResourceOrder()) {
            if (!seen[key])
                finalOrder.push(key);
        }

        resourceOrderModel.clear();
        for (const key of finalOrder) {
            resourceOrderModel.append({
                "key": key,
                "label": labelForResource(key)
            });
        }
    }

    function saveResourceOrderModel() {
        const order = [];
        for (let i = 0; i < resourceOrderModel.count; i++)
            order.push(resourceOrderModel.get(i).key);
        saveValue("resourceOrder", order.join(","));
    }

    function moveResourceOrderItem(fromIndex, toIndex) {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= resourceOrderModel.count || toIndex >= resourceOrderModel.count)
            return;
        const items = [];
        for (let i = 0; i < resourceOrderModel.count; i++) {
            const item = resourceOrderModel.get(i);
            items.push({
                "key": item.key,
                "label": item.label
            });
        }
        const moved = items.splice(fromIndex, 1)[0];
        items.splice(toIndex, 0, moved);
        resourceOrderModel.clear();
        for (const item of items)
            resourceOrderModel.append(item);
        saveResourceOrderModel();
    }

    function refreshSettingsUi() {
        initResourceOrderModel();
    }

    function rebuildResourceCard() {
        resourceCardActive = false;
        Qt.callLater(() => {
            resourceCardActive = true;
        });
    }

    function resourceKeyForTab(index) {
        switch (index) {
        case 1:
            return "cpuUsage";
        case 2:
            return "cpuTemp";
        case 3:
            return "ramUsage";
        case 4:
            return "gpuTemp";
        case 5:
            return "diskPartitionUsage";
        default:
            return "";
        }
    }

    Component.onCompleted: Qt.callLater(() => refreshSettingsUi())
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => refreshSettingsUi());
            if (currentTab > 0)
                rebuildResourceCard();
            if (currentTab === 5)
                refreshDiskMounts();
        }
    }
    onCurrentTabChanged: {
        if (currentTab > 0)
            rebuildResourceCard();
        if (currentTab === 5)
            ToastService.showInfo(388);
            diskMountsProcess.running = true;
            refreshDiskMounts();
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                Qt.callLater(root.initResourceOrderModel);
        }
    }

    ListModel {
        id: resourceOrderModel
    }

    component SectionCard: StyledRect {
        id: card
        required property string title
        required property string description
        default property alias sectionContent: contentColumn.data

        width: parent.width
        height: contentColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: card.title
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    text: card.description
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component InlineColorSetting: Column {
        id: inlineColorSetting
        required property string settingKey
        required property string label
        property string description: ""
        property color defaultValue: Theme.primary
        property color value: root.loadedValue(settingKey, defaultValue)

        function reloadValue() {
            value = root.loadedValue(settingKey, defaultValue);
        }

        Component.onCompleted: reloadValue()
        onSettingKeyChanged: reloadValue()
        onDefaultValueChanged: reloadValue()

        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: inlineColorSetting.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            visible: inlineColorSetting.description !== ""
            text: inlineColorSetting.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: inlineColorSetting.width
            wrapMode: Text.WordWrap
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                width: 100
                height: 36
                radius: Theme.cornerRadius
                color: inlineColorSetting.value
                border.color: Theme.outlineStrong
                border.width: 2

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (PopoutService && PopoutService.colorPickerModal) {
                            PopoutService.colorPickerModal.selectedColor = inlineColorSetting.value;
                            PopoutService.colorPickerModal.pickerTitle = inlineColorSetting.label;
                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                inlineColorSetting.value = selectedColor;
                                root.saveValue(inlineColorSetting.settingKey, selectedColor);
                            };
                            PopoutService.colorPickerModal.show();
                        }
                    }
                }
            }

            StyledText {
                text: inlineColorSetting.value.toString()
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component InlineToggleSetting: Row {
        id: inlineToggleSetting
        required property string settingKey
        required property string label
        property string description: ""
        property bool defaultValue: false
        property bool value: !!root.loadedValue(settingKey, defaultValue)

        function reloadValue() {
            value = !!root.loadedValue(settingKey, defaultValue);
        }

        Component.onCompleted: reloadValue()
        onSettingKeyChanged: reloadValue()
        onDefaultValueChanged: reloadValue()

        width: parent.width
        spacing: Theme.spacingM

        Column {
            width: inlineToggleSetting.width - toggle.width - Theme.spacingM
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: inlineToggleSetting.label
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                visible: inlineToggleSetting.description !== ""
                text: inlineToggleSetting.description
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }
        }

        DankToggle {
            id: toggle
            anchors.verticalCenter: parent.verticalCenter
            checked: inlineToggleSetting.value
            onToggled: isChecked => {
                inlineToggleSetting.value = isChecked;
                root.saveValue(inlineToggleSetting.settingKey, isChecked);
            }
        }
    }

    component InlineSelectionSetting: Column {
        id: inlineSelectionSetting
        required property string settingKey
        required property string label
        property string description: ""
        required property var options
        property string defaultValue: ""
        property string value: String(root.loadedValue(settingKey, defaultValue))

        function reloadValue() {
            value = String(root.loadedValue(settingKey, defaultValue));
        }

        Component.onCompleted: reloadValue()
        onSettingKeyChanged: reloadValue()
        onDefaultValueChanged: reloadValue()

        width: parent.width
        spacing: Theme.spacingS

        function optionLabels() {
            const labels = [];
            for (let i = 0; i < options.length; i++)
                labels.push(options[i].label || options[i]);
            return labels;
        }

        function valueToLabelMap() {
            const map = {};
            for (let i = 0; i < options.length; i++) {
                const opt = options[i];
                if (typeof opt === "object")
                    map[opt.value] = opt.label;
                else
                    map[opt] = opt;
            }
            return map;
        }

        function labelToValueMap() {
            const map = {};
            for (let i = 0; i < options.length; i++) {
                const opt = options[i];
                if (typeof opt === "object")
                    map[opt.label] = opt.value;
                else
                    map[opt] = opt;
            }
            return map;
        }

        DankDropdown {
            width: inlineSelectionSetting.width
            text: inlineSelectionSetting.label
            description: inlineSelectionSetting.description
            currentValue: inlineSelectionSetting.valueToLabelMap()[inlineSelectionSetting.value] || inlineSelectionSetting.value
            options: inlineSelectionSetting.optionLabels()
            onValueChanged: newValue => {
                const mappedValue = inlineSelectionSetting.labelToValueMap()[newValue] || newValue;
                inlineSelectionSetting.value = mappedValue;
                root.saveValue(inlineSelectionSetting.settingKey, mappedValue);
            }
        }
    }

    component InlineSliderSetting: Column {
        id: inlineSliderSetting
        required property string settingKey
        required property string label
        property string description: ""
        property int defaultValue: 0
        property int value: Number(root.loadedValue(settingKey, defaultValue))
        property int minimum: 0
        property int maximum: 100
        property string leftIcon: ""
        property string rightIcon: ""
        property string unit: ""

        function reloadValue() {
            value = Number(root.loadedValue(settingKey, defaultValue));
        }

        Component.onCompleted: reloadValue()
        onSettingKeyChanged: reloadValue()
        onDefaultValueChanged: reloadValue()

        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: inlineSliderSetting.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            visible: inlineSliderSetting.description !== ""
            text: inlineSliderSetting.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: inlineSliderSetting.width
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: inlineSliderSetting.width
            value: inlineSliderSetting.value
            minimum: inlineSliderSetting.minimum
            maximum: inlineSliderSetting.maximum
            leftIcon: inlineSliderSetting.leftIcon
            rightIcon: inlineSliderSetting.rightIcon
            unit: inlineSliderSetting.unit
            wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainerHighest
            onSliderValueChanged: newValue => {
                inlineSliderSetting.value = newValue;
                root.saveValue(inlineSliderSetting.settingKey, newValue);
            }
        }
    }

    component InlineStringSetting: Column {
        id: inlineStringSetting
        required property string settingKey
        required property string label
        property string description: ""
        property string placeholder: ""
        property string defaultValue: ""
        property string value: String(root.loadedValue(settingKey, defaultValue))

        function reloadValue() {
            value = String(root.loadedValue(settingKey, defaultValue));
            if (!textField.activeFocus)
                textField.text = value;
        }

        function commitValue() {
            value = textField.text;
            root.saveValue(settingKey, value);
        }

        Component.onCompleted: reloadValue()
        onSettingKeyChanged: reloadValue()
        onDefaultValueChanged: reloadValue()

        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: inlineStringSetting.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            visible: inlineStringSetting.description !== ""
            text: inlineStringSetting.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: inlineStringSetting.width
            wrapMode: Text.WordWrap
        }

        DankTextField {
            id: textField
            width: inlineStringSetting.width
            text: inlineStringSetting.value
            placeholderText: inlineStringSetting.placeholder
            onEditingFinished: inlineStringSetting.commitValue()
            onFocusStateChanged: hasFocus => {
                if (!hasFocus)
                    inlineStringSetting.commitValue();
            }
        }
    }

    component InlineIconSetting: Column {
        id: inlineIconSetting
        required property string settingKey
        required property string label
        property string description: ""
        required property string defaultIcon
        property string value: String(root.loadedValue(settingKey, ""))

        function reloadValue() {
            value = String(root.loadedValue(settingKey, ""));
            iconPicker.setIcon(value, "icon");
            if (!manualField.activeFocus)
                manualField.text = value;
        }

        function saveSelectedIcon(iconName) {
            value = iconName;
            root.saveValue(settingKey, iconName);
            iconPicker.setIcon(iconName, "icon");
            manualField.text = iconName;
        }

        function resetToDefault() {
            value = "";
            root.saveValue(settingKey, "");
            iconPicker.setIcon("", "icon");
            manualField.text = "";
        }

        function saveManualIconName() {
            value = manualField.text.trim();
            root.saveValue(settingKey, value);
            iconPicker.setIcon(value, "icon");
        }

        Component.onCompleted: reloadValue()
        onSettingKeyChanged: reloadValue()

        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: inlineIconSetting.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            visible: inlineIconSetting.description !== ""
            text: inlineIconSetting.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: inlineIconSetting.width
            wrapMode: Text.WordWrap
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankIconPicker {
                id: iconPicker
                width: Math.max(220, parent.width - 36 - Theme.spacingS)

                Component.onCompleted: setIcon(inlineIconSetting.value, "icon")

                onIconSelected: (iconName, iconType) => {
                    inlineIconSetting.saveSelectedIcon(iconName);
                }
            }

            DankActionButton {
                width: 32
                height: 32
                iconName: "restart_alt"
                backgroundColor: Theme.surfaceContainer
                iconColor: Theme.surfaceText
                onClicked: inlineIconSetting.resetToDefault()
            }
        }

        DankTextField {
            id: manualField
            width: parent.width
            text: inlineIconSetting.value
            placeholderText: "Type any icon name, for example thermostat"
            onEditingFinished: inlineIconSetting.saveManualIconName()
            onFocusStateChanged: hasFocus => {
                if (!hasFocus)
                    inlineIconSetting.saveManualIconName();
            }
        }

        StyledText {
            width: parent.width
            text: "Default icon: " + inlineIconSetting.defaultIcon
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.NoWrap
        }

        StyledText {
            width: parent.width
            text: "If the picker does not show the icon you want, type the icon name manually. The icons should be from material icons so you can try looking at https://fonts.google.com/icons"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }
    }

    component ResourceCard: SectionCard {
        required property string resourceKey
        title: root.labelForResource(resourceKey)
        description: root.descriptionForResource(resourceKey)

        InlineToggleSetting {
            settingKey: resourceKey + "Enabled"
            label: "Show " + root.labelForResource(resourceKey)
            description: "Enable this metric in the unified monitor"
            defaultValue: resourceKey === "cpuUsage"
        }

        InlineSelectionSetting {
            id: styleSetting
            settingKey: resourceKey + "VisualStyle"
            label: "Style"
            description: "Choose text, gauge, or bar for this metric"
            options: root.styleOptions
            defaultValue: "default"
        }

        InlineToggleSetting {
            settingKey: resourceKey + "ShowIcon"
            label: "Show Icon"
            description: "Display the resource icon"
            defaultValue: true
        }

        InlineIconSetting {
            settingKey: resourceKey + "IconName"
            label: "Icon"
            description: "Choose a custom icon for this resource, or reset to use the default."
            defaultIcon: root.defaultIconForResource(resourceKey)
        }

        InlineToggleSetting {
            settingKey: resourceKey + "ShowText"
            label: "Show Text"
            description: "Display the numeric value"
            defaultValue: true
        }

        InlineSelectionSetting {
            id: ramTextModeSetting
            visible: resourceKey === "ramUsage"
            settingKey: "ramUsageTextMode"
            label: "RAM Text"
            description: "Choose whether RAM shows usage percentage, used memory value, both, or a custom template."
            options: root.ramTextModeOptions
            defaultValue: "percentage"
        }

        InlineStringSetting {
            visible: resourceKey === "ramUsage" && ramTextModeSetting.value === "custom"
            settingKey: "ramUsageCustomTemplate"
            label: "RAM Custom Template"
            description: "Build your own RAM text using the placeholders below."
            placeholder: "{percent}"
            defaultValue: "{percent}"
        }

        StyledText {
            visible: resourceKey === "ramUsage" && ramTextModeSetting.value === "custom"
            width: parent.width
            text: "Available placeholders: {percent}, {usedGB}, {usedMB}, {totalGB}, {totalMB}, {freeGB}, {availableGB}"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        InlineToggleSetting {
            settingKey: resourceKey + "ColorizeText"
            label: "Colorize Text"
            description: "Use the active status color for the value text"
            defaultValue: false
        }

        InlineSliderSetting {
            visible: root.resourceUsesProgressScale(resourceKey) && styleSetting.value !== "default"
            settingKey: resourceKey + "ProgressMaxValue"
            label: "Gauge/Bar Max Value"
            description: "The value treated as 100% fill for gauge and bar styles."
            defaultValue: 100
            minimum: 40
            maximum: 150
            unit: root.progressScaleUnit(resourceKey)
            leftIcon: "tune"
        }

        InlineSelectionSetting {
            id: gpuSetting
            visible: root.resourceIsGpu(resourceKey) && root.gpuOptions().length > 0
            settingKey: resourceKey + "SelectedGpuPciId"
            label: "GPU"
            description: "Choose which GPU this metric should monitor"
            options: root.gpuOptions()
            defaultValue: root.gpuOptions().length > 0 ? root.gpuOptions()[0].value : ""
        }

        InlineSelectionSetting {
            visible: resourceKey === "diskPartitionUsage"
            settingKey: resourceKey + "Mount"
            label: "Partition"
            description: "Choose which partition to monitor"
            options: root.diskMountOptions(resourceKey)
            defaultValue: "/"
        }

        StyledText {
            visible: root.resourceIsGpu(resourceKey) && root.gpuOptions().length === 0
            width: parent.width
            text: "No GPU metadata is available yet. This metric will use the first GPU once DgopService reports one."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        InlineToggleSetting {
            id: valueColorToggle
            settingKey: resourceKey + "UseValueColors"
            label: "Value-Based Colors"
            description: "Switch colors automatically based on warning and danger thresholds"
            defaultValue: true
        }

        InlineSelectionSetting {
            id: fixedColorSetting
            visible: !valueColorToggle.value
            settingKey: resourceKey + "FixedColorKey"
            label: "Fixed Color"
            description: "Single color used for this metric"
            options: root.colorOptions
            defaultValue: "primary"
        }

        InlineColorSetting {
            visible: !valueColorToggle.value && fixedColorSetting.value === "custom"
            settingKey: resourceKey + "FixedCustomColor"
            label: "Custom Fixed Color"
            description: "Pick a custom solid color for this metric"
            defaultValue: Theme.primary
        }

        InlineSelectionSetting {
            id: normalColorSetting
            visible: valueColorToggle.value
            settingKey: resourceKey + "NormalColorKey"
            label: "Normal Color"
            description: "Used below the warning threshold"
            options: root.colorOptions
            defaultValue: "primary"
        }

        InlineColorSetting {
            visible: valueColorToggle.value && normalColorSetting.value === "custom"
            settingKey: resourceKey + "NormalCustomColor"
            label: "Custom Normal Color"
            description: "Pick a custom color for safe values"
            defaultValue: Theme.primary
        }

        InlineSelectionSetting {
            id: warningColorSetting
            visible: valueColorToggle.value
            settingKey: resourceKey + "WarningColorKey"
            label: "Warning Color"
            description: "Used at or above the warning threshold"
            options: root.colorOptions
            defaultValue: "warning"
        }

        InlineColorSetting {
            visible: valueColorToggle.value && warningColorSetting.value === "custom"
            settingKey: resourceKey + "WarningCustomColor"
            label: "Custom Warning Color"
            description: "Pick a custom warning color"
            defaultValue: Theme.warning
        }

        InlineSelectionSetting {
            id: dangerColorSetting
            visible: valueColorToggle.value
            settingKey: resourceKey + "DangerColorKey"
            label: "Danger Color"
            description: "Used at or above the danger threshold"
            options: root.colorOptions
            defaultValue: "error"
        }

        InlineColorSetting {
            visible: valueColorToggle.value && dangerColorSetting.value === "custom"
            settingKey: resourceKey + "DangerCustomColor"
            label: "Custom Danger Color"
            description: "Pick a custom danger color"
            defaultValue: Theme.error
        }

        InlineSliderSetting {
            visible: valueColorToggle.value
            settingKey: resourceKey + "WarningThreshold"
            label: "Warning Threshold"
            description: "Values at or above this point switch to the warning color"
            defaultValue: root.defaultWarningThreshold(resourceKey)
            minimum: 0
            maximum: 100
            unit: ""
            leftIcon: "warning"
        }

        InlineSliderSetting {
            visible: valueColorToggle.value
            settingKey: resourceKey + "DangerThreshold"
            label: "Danger Threshold"
            description: "Values at or above this point switch to the danger color"
            defaultValue: root.defaultDangerThreshold(resourceKey)
            minimum: 0
            maximum: 100
            unit: ""
            leftIcon: "priority_high"
        }
    }

    StyledText {
        width: parent.width
        text: "System Monitor Plus Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Choose which resources are visible, rearrange their order, and tune each one independently."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Item {
        width: parent.width
        height: 45 + Theme.spacingM

        DankTabBar {
            id: settingsTabBar
            width: Math.min(parent.width, 620)
            height: 45
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                {
                    "text": "Order",
                    "icon": "reorder"
                },
                {
                    "text": "CPU %",
                    "icon": "memory"
                },
                {
                    "text": "CPU Temp",
                    "icon": "device_thermostat"
                },
                {
                    "text": "RAM",
                    "icon": "developer_board"
                },
                {
                    "text": "GPU Temp",
                    "icon": "thermostat"
                },
                {
                    "text": "Disk",
                    "icon": "sd_storage"
                }
            ]

            Component.onCompleted: Qt.callLater(updateIndicator)

            onTabClicked: index => {
                root.currentTab = index;
                currentIndex = index;
            }
        }
    }

    SectionCard {
        visible: root.currentTab === 0
        title: "Resource Order"
        description: "Enable the metrics you want to show, then move them up or down to control their order inside the unified widget."

        InlineToggleSetting {
            settingKey: "EnableRightClickSettings"
            label: "Open DMS Settings On Right Click"
            description: "When enabled, right clicking the widget opens the DMS plugins settings page."
            defaultValue: true
        }

        ListView {
            id: resourceOrderList
            width: parent.width
            height: contentHeight
            spacing: Theme.spacingS
            interactive: false
            model: resourceOrderModel

            delegate: RowLayout {
                width: resourceOrderList.width
                height: 34
                spacing: Theme.spacingS
                readonly property string resourceKey: model.key
                readonly property int delegateIndex: index

                DankToggle {
                    checked: root.loadValue(resourceKey + "Enabled", resourceKey === "cpuUsage")
                    onToggled: isChecked => root.saveValue(resourceKey + "Enabled", isChecked)
                }

                StyledText {
                    text: model.label
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                DankActionButton {
                    width: 26
                    height: 26
                    iconName: "keyboard_arrow_up"
                    backgroundColor: Theme.surfaceContainer
                    iconColor: Theme.surfaceText
                    enabled: delegateIndex > 0
                    onClicked: root.moveResourceOrderItem(delegateIndex, delegateIndex - 1)
                }

                DankActionButton {
                    width: 26
                    height: 26
                    iconName: "keyboard_arrow_down"
                    backgroundColor: Theme.surfaceContainer
                    iconColor: Theme.surfaceText
                    enabled: delegateIndex < resourceOrderModel.count - 1
                    onClicked: root.moveResourceOrderItem(delegateIndex, delegateIndex + 1)
                }
            }
        }
    }

    Loader {
        active: root.visible && root.currentTab > 0 && root.resourceCardActive
        width: parent.width
        sourceComponent: root.currentTab > 0 ? resourceCardComponent : null
    }

    Component {
        id: resourceCardComponent

        ResourceCard {
            width: parent.width
            resourceKey: root.resourceKeyForTab(root.currentTab)
        }
    }
}
