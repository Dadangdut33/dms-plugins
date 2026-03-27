import QtQuick
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "simpleAudioControl"

    StyledText {
        width: parent.width
        text: "Simple Audio Control Plugin Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure bar display and volume scroll behavior"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Bar Display ──
    StyledRect {
        width: parent.width
        height: barDisplayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: barDisplayColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Bar Display"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "showSpeaker"
                label: "Show Speaker"
                description: "Display speaker icon in the bar"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showSpeakerValue"
                label: "Show Speaker Volume"
                description: "Display numeric volume percentage next to speaker icon"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showMic"
                label: "Show Microphone"
                description: "Display microphone icon in the bar"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showMicValue"
                label: "Show Microphone Volume"
                description: "Display numeric input level next to microphone icon"
                defaultValue: false
            }

            ToggleSetting {
                id: customTabRadiusToggle
                settingKey: "useCustomTabRadius"
                label: "Custom Tab Radius"
                description: "Override the theme's tab radius"
                defaultValue: false
            }

            Timer {
                id: tabRadiusDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    saveValue("tabRadius", Math.round(tabRadiusSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2
                visible: customTabRadiusToggle.value

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Tab Radius"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: tabRadiusSlider
                        width: parent.width - 180 - Theme.spacingM - tabRadiusValue.width - Theme.spacingM
                        minimum: 0
                        maximum: 40
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: tabRadiusSlider
                            property: "value"
                            value: loadValue("tabRadius", Theme.cornerRadius)
                        }

                        onSliderValueChanged: newValue => {
                            tabRadiusDebounce.restart();
                        }
                    }

                    StyledText {
                        id: tabRadiusValue
                        text: Math.round(tabRadiusSlider.value) + "px"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Corner radius for the Volumes/Devices tabs"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Scroll Behavior ──
    StyledRect {
        width: parent.width
        height: scrollColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: scrollColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Scroll Behavior"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Timer {
                id: speakerStepDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    saveValue("volumeScrollStep", Math.round(speakerStepSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Output Volume Scroll Step"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: speakerStepSlider
                        width: parent.width - 180 - Theme.spacingM - speakerStepValue.width - Theme.spacingM
                        minimum: 1
                        maximum: 20
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: speakerStepSlider
                            property: "value"
                            value: loadValue("volumeScrollStep", 2)
                        }

                        onSliderValueChanged: newValue => {
                            speakerStepDebounce.restart();
                        }
                    }

                    StyledText {
                        id: speakerStepValue
                        text: Math.round(speakerStepSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "How much the speaker volume changes per scroll tick"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: micStepDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    saveValue("micVolumeScrollStep", Math.round(micStepSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Input Volume Scroll Step"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: micStepSlider
                        width: parent.width - 180 - Theme.spacingM - micStepValue.width - Theme.spacingM
                        minimum: 1
                        maximum: 20
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: micStepSlider
                            property: "value"
                            value: loadValue("micVolumeScrollStep", 2)
                        }

                        onSliderValueChanged: newValue => {
                            micStepDebounce.restart();
                        }
                    }

                    StyledText {
                        id: micStepValue
                        text: Math.round(micStepSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "How much the microphone volume changes per scroll tick"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: maxVolumeDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    saveValue("maxVolumePercent", Math.round(maxVolumeSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Max Volume"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: maxVolumeSlider
                        width: parent.width - 180 - Theme.spacingM - maxVolumeValue.width - Theme.spacingM
                        minimum: 100
                        maximum: 500
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: maxVolumeSlider
                            property: "value"
                            value: loadValue("maxVolumePercent", 100)
                        }

                        onSliderValueChanged: newValue => {
                            maxVolumeDebounce.restart();
                        }
                    }

                    StyledText {
                        id: maxVolumeValue
                        text: Math.round(maxVolumeSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Maximum allowed per-app volume (up to 500%)"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Info ──
    StyledRect {
        width: parent.width
        height: infoColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: infoColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Usage"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "• Scroll on the widget to change volume (input / output)\n• Click the widget to open the audio panel\n• Use the Volumes tab to adjust output, input, and per-app volumes\n• Use the Devices tab to switch audio devices."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
