import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import Quickshell
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "clipboardPlus"

    StyledText {
        width: parent.width
        text: "ClipBoard+ Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure panel behavior and features"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Panel Options ──
    StyledRect {
        width: parent.width
        height: panelColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: panelColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Panel Options"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "fullscreenMode"
                label: "Fullscreen Mode"
                description: "Expand the clipboard panel to fill the entire screen"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showCloseButton"
                label: "Show Close Button"
                description: "Display an X button to close the panel"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showBarWidget"
                label: "Show Bar Widget"
                description: "Display the ClipBoard+ icon in the bar"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "closeOnOutsideClick"
                label: "Close On Outside Click"
                description: "Close panel when clicking outside the main container"
                defaultValue: true
            }

            ToggleSetting {
                id: hideBackgroundToggle
                settingKey: "hidePanelBackground"
                label: "Hide Panel Background"
                description: "Disable background dimming"
                defaultValue: false
            }

            Timer {
                id: dimmingDebounce
                interval: 300
                repeat: false
                onTriggered: root.saveValue("panelDimOpacity", Math.round(dimmingSlider.value))
            }

            Column {
                width: parent.width
                spacing: 2
                visible: !hideBackgroundToggle.value

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Background Dimming"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 160
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: dimmingSlider
                        width: parent.width - 160 - Theme.spacingM - dimmingValue.width - Theme.spacingM
                        minimum: 0
                        maximum: 80
                        step: 5
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: dimmingSlider
                            property: "value"
                            value: loadValue("panelDimOpacity", 35)
                        }

                        onSliderValueChanged: () => {
                            dimmingDebounce.restart()
                        }
                    }

                    StyledText {
                        id: dimmingValue
                        text: Math.round(dimmingSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Controls the background dimming opacity"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Feature Toggles ──
    StyledRect {
        width: parent.width
        height: featureColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: featureColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Features"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "pincardsEnabled"
                label: "Enable Pin Cards"
                description: "Show pinned items panel and allow pinning clipboard items"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "notecardsEnabled"
                label: "Enable Note Cards"
                description: "Show notecards panel for quick notes"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "todoEnabled"
                label: "Enable ToDo"
                description: "Show the ToDo list in the pinned panel"
                defaultValue: true
            }
        }
    }

    // ── Pinned Data Limits ──
    StyledRect {
        width: parent.width
        height: limitsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: limitsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Pinned Data Limits"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Timer {
                id: textLimitDebounce
                interval: 300
                repeat: false
                onTriggered: root.saveValue("maxPinnedTextMb", Math.round(textLimitSlider.value))
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Max Pinned Text Size"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 160
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: textLimitSlider
                        width: parent.width - 160 - Theme.spacingM - textLimitValue.width - Theme.spacingM
                        minimum: 1
                        maximum: 10
                        step: 1
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: textLimitSlider
                            property: "value"
                            value: loadValue("maxPinnedTextMb", 1)
                        }

                        onSliderValueChanged: () => {
                            textLimitDebounce.restart()
                        }
                    }

                    StyledText {
                        id: textLimitValue
                        text: Math.round(textLimitSlider.value) + " MB"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 60
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Limit for pinned text size"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: imageLimitDebounce
                interval: 300
                repeat: false
                onTriggered: root.saveValue("maxPinnedImageMb", Math.round(imageLimitSlider.value))
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Max Pinned Image Size"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 160
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: imageLimitSlider
                        width: parent.width - 160 - Theme.spacingM - imageLimitValue.width - Theme.spacingM
                        minimum: 5
                        maximum: 100
                        step: 1
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: imageLimitSlider
                            property: "value"
                            value: loadValue("maxPinnedImageMb", 5)
                        }

                        onSliderValueChanged: () => {
                            imageLimitDebounce.restart()
                        }
                    }

                    StyledText {
                        id: imageLimitValue
                        text: Math.round(imageLimitSlider.value) + " MB"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 60
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Limit for pinned image size & image preview in clipboard"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Auto-Paste ──
    StyledRect {
        width: parent.width
        height: autoPasteColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: autoPasteColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Auto-Paste"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                id: autoPasteToggle
                settingKey: "autoPasteOnClick"
                label: "Auto-Paste on Click"
                description: "Automatically paste after selecting with mouse"
                defaultValue: false
            }

            ToggleSetting {
                id: autoPasteRightClickToggle
                settingKey: "autoPasteOnRightClick"
                label: "Right-Click Only"
                description: "Use right-click for auto-paste"
                defaultValue: false
                visible: autoPasteToggle.value === true
            }

            ToggleSetting {
                id: autoPasteEnterToggle
                settingKey: "autoPasteOnEnterSelect"
                label: "Auto-Paste on Enter"
                description: "Auto-paste when selecting with Enter"
                defaultValue: false
            }

            Timer {
                id: autoPasteDelayDebounce
                interval: 300
                repeat: false
                onTriggered: root.saveValue("autoPasteDelay", Math.round(autoPasteDelaySlider.value))
            }

            Column {
                width: parent.width
                spacing: 2
                visible: autoPasteToggle.value === true || autoPasteEnterToggle.value === true

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Paste Delay"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 160
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: autoPasteDelaySlider
                        width: parent.width - 160 - Theme.spacingM - autoPasteDelayValue.width - Theme.spacingM
                        minimum: 100
                        maximum: 1000
                        step: 50
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: autoPasteDelaySlider
                            property: "value"
                            value: loadValue("autoPasteDelay", 300)
                        }

                        onSliderValueChanged: () => {
                            autoPasteDelayDebounce.restart()
                        }
                    }

                    StyledText {
                        id: autoPasteDelayValue
                        text: Math.round(autoPasteDelaySlider.value) + " ms"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 60
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Delay before auto-paste runs"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Paths ──
    StyledRect {
        width: parent.width
        height: pathsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: pathsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Paths"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: 6

                StyledText {
                    text: "Base Data Path"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                DankTextField {
                    id: dataPathInput
                    width: parent.width
                    placeholderText: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dms-clipboardPlus"
                    text: loadValue("dataBasePath", "")
                    onEditingFinished: root.saveValue("dataBasePath", text.trim())
                }

                StyledText {
                    text: "Leave empty to use the default path"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Column {
                width: parent.width
                spacing: 6

                StyledText {
                    text: "Export Path (.txt)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                DankTextField {
                    id: exportPathInput
                    width: parent.width
                    placeholderText: Quickshell.env("HOME") + "/Documents"
                    text: loadValue("exportPath", "")
                    onEditingFinished: root.saveValue("exportPath", text.trim())
                }

                StyledText {
                    text: "Leave empty to export to ~/Documents"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.6
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Clipboard Listen ──
    StyledRect {
        width: parent.width
        height: listenColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: listenColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Clipboard"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "listenClipboardWhileOpen"
                label: "Listen for clipboard when widget is opened"
                description: "Update clipboard list automatically while the panel is open"
                defaultValue: false
            }
        }
    }
}
