import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "netbirdStatus"

    StyledText {
        width: parent.width
        text: "NetBird Plugin Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure NetBird VPN status display and behavior"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Display Options ──
    StyledRect {
        width: parent.width
        height: displayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: displayColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Display Options"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                id: compactModeToggle
                settingKey: "compactMode"
                label: "Compact Mode"
                description: "Show only icon in the bar"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showIpAddress"
                label: "Show IP Address"
                description: "Display NetBird IP in the bar widget"
                defaultValue: true
                enabled: !compactModeToggle.checked
            }

            ToggleSetting {
                settingKey: "hideDisconnected"
                label: "Hide Disconnected Peers"
                description: "Only show online peers in the panel"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showPing"
                label: "Show Ping Latency"
                description: "Ping all connected peers and display latency"
                defaultValue: false
            }

            StyledText {
                visible: root.pluginData["showPing"] === true
                width: parent.width
                text: "⚠ This feature sends ICMP packets to each connected peer at every refresh interval. It may increase network usage and CPU load."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Behavior Options ──
    StyledRect {
        width: parent.width
        height: behaviorColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: behaviorColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Behavior Options"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Timer {
                id: refreshIntervalDebounceTimer
                interval: 300
                repeat: false
                onTriggered: {
                    root.saveValue("refreshInterval", Math.round(refreshIntervalSlider.value))
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    id: refreshIntervalRow
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Refresh Interval"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: refreshIntervalSlider
                        width: parent.width - 180 - Theme.spacingM - refreshIntervalValueText.width - Theme.spacingM
                        minimum: 1000
                        maximum: 60000
                        step: 500
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: refreshIntervalSlider
                            property: "value"
                            value: loadValue("refreshInterval", 30000)
                        }

                        onSliderValueChanged: (newValue) => {
                            refreshIntervalDebounceTimer.restart()
                        }
                    }

                    StyledText {
                        id: refreshIntervalValueText
                        text: Math.round(refreshIntervalSlider.value) + " ms"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "How often to check NetBird status"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: pingCountDebounceTimer
                interval: 300
                repeat: false
                onTriggered: {
                    root.saveValue("pingCount", Math.round(pingCountSlider.value))
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    id: pingCountRow
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Ping Count"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: pingCountSlider
                        width: parent.width - 180 - Theme.spacingM - pingCountValueText.width - Theme.spacingM
                        minimum: 1
                        maximum: 20
                        step: 1
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: pingCountSlider
                            property: "value"
                            value: loadValue("pingCount", 5)
                        }

                        onSliderValueChanged: (newValue) => {
                            pingCountDebounceTimer.restart()
                        }
                    }

                    StyledText {
                        id: pingCountValueText
                        text: Math.round(pingCountSlider.value)
                        font.pixelSize: Theme.fontSizeSmall
                        width: 40
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Number of ping packets to send when testing connectivity"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── Terminal Configuration Info ──
    StyledRect {
        width: parent.width
        height: terminalColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: terminalColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Terminal Configuration"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "terminalCommand"
                label: "Terminal Command Override"
                description: "Custom terminal to use for SSH and Ping. Leave blank to auto-detect."
                placeholder: "alacritty, kitty, wezterm..."
                defaultValue: ""
            }

            StyledText {
                width: parent.width
                text: "The plugin will attempt to auto-detect a compatible terminal emulator (ghostty, alacritty, kitty, wezterm, etc.) if this is left empty."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Peer Click Action ──
    StyledRect {
        width: parent.width
        height: actionColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: actionColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Peer Click Action"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Default Action"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankDropdown {
                        id: defaultActionDropdown
                        width: parent.width - 180 - Theme.spacingM
                        options: [
                            "Copy IP",
                            "SSH to host",
                            "Ping host"
                        ]
                        compactMode: true

                        Binding {
                            target: defaultActionDropdown
                            property: "currentValue"
                            value: loadValue("defaultPeerAction", "Copy IP")
                        }

                        onValueChanged: (value) => {
                            saveValue("defaultPeerAction", value)
                        }
                    }
                }

                StyledText {
                    text: "Action when clicking on a peer in the panel"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
