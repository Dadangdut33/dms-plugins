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

            SliderSetting {
                settingKey: "volumeScrollStep"
                label: "Output Volume Scroll Step"
                description: "How much the speaker volume changes per scroll tick"
                defaultValue: 2
                minimum: 1
                maximum: 20
                unit: "%"
            }

            SliderSetting {
                settingKey: "micVolumeScrollStep"
                label: "Input Volume Scroll Step"
                description: "How much the microphone volume changes per scroll tick"
                defaultValue: 2
                minimum: 1
                maximum: 20
                unit: "%"
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
