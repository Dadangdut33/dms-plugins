import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "mediaControlPlus"

    property int currentTab: 0
    readonly property var colorOptions: [
        {
            label: "Widget Text",
            value: "widgetText"
        },
        {
            label: "Primary",
            value: "primary"
        },
        {
            label: "Primary Text",
            value: "primaryText"
        },
        {
            label: "Primary Container",
            value: "primaryContainer"
        },
        {
            label: "Secondary",
            value: "secondary"
        },
        {
            label: "Surface",
            value: "surface"
        },
        {
            label: "Surface Text",
            value: "surfaceText"
        },
        {
            label: "Surface Variant",
            value: "surfaceVariant"
        },
        {
            label: "Surface Variant Text",
            value: "surfaceVariantText"
        },
        {
            label: "Surface Tint",
            value: "surfaceTint"
        },
        {
            label: "Background",
            value: "background"
        },
        {
            label: "Background Text",
            value: "backgroundText"
        },
        {
            label: "Outline",
            value: "outline"
        },
        {
            label: "Surface Container",
            value: "surfaceContainer"
        },
        {
            label: "Surface Container High",
            value: "surfaceContainerHigh"
        },
        {
            label: "Surface Container Highest",
            value: "surfaceContainerHighest"
        },
        {
            label: "Error",
            value: "error"
        },
        {
            label: "Warning",
            value: "warning"
        },
        {
            label: "Info",
            value: "info"
        }
    ]

    function reloadNestedSettings(item) {
        if (!item)
            return;
        if (item !== root && item.loadValue)
            item.loadValue();

        const children = item.children || [];
        for (let i = 0; i < children.length; i++)
            reloadNestedSettings(children[i]);

        const data = item.data || [];
        for (let i = 0; i < data.length; i++) {
            const child = data[i];
            if (child && children.indexOf(child) === -1)
                reloadNestedSettings(child);
        }
    }

    function refreshSettingsUi() {
        root.reloadNestedSettings(root);
        settingsTabBar.currentIndex = root.currentTab;
        Qt.callLater(() => settingsTabBar.updateIndicator());
    }

    Component.onCompleted: Qt.callLater(() => root.refreshSettingsUi())
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => root.refreshSettingsUi());
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                Qt.callLater(root.refreshSettingsUi);
        }
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

    StyledText {
        width: parent.width
        text: "Media Control Plus Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Split between horizontal, vertical, visualizer, and popout settings so it is easier to tune."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Item {
        width: parent.width
        height: 45 + Theme.spacingM

        DankTabBar {
            id: settingsTabBar
            width: Math.min(parent.width, 420)
            height: 45
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                {
                    "text": "General",
                    "icon": "tune"
                },
                {
                    "text": "Horizontal",
                    "icon": "view_stream"
                },
                {
                    "text": "Vertical",
                    "icon": "view_week"
                },
                {
                    "text": "Popout",
                    "icon": "open_in_full"
                }
            ]

            Component.onCompleted: Qt.callLater(updateIndicator)

            onTabClicked: index => {
                root.currentTab = index;
                currentIndex = index;
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: root.currentTab === 0

        SectionCard {
            title: "Widget"
            description: "General widget behavior shared across horizontal and vertical bars."

            ToggleSetting {
                settingKey: "showWhenNoPlayer"
                label: "Show When No Player"
                description: "Keep the widget visible even when no active media player is available"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "rightClickOpensSettings"
                label: "Right Click Opens Settings"
                description: "Open the plugin settings page when the widget is right clicked"
                defaultValue: true
            }

            SelectionSetting {
                settingKey: "scrollVolumeMode"
                label: "Scroll Volume Control"
                description: "Choose whether mouse wheel scrolling changes the system output volume or the active app volume"
                defaultValue: "none"
                options: [
                    {
                        label: "Disabled",
                        value: "none"
                    },
                    {
                        label: "System Volume",
                        value: "sink"
                    },
                    {
                        label: "App Volume",
                        value: "player"
                    }
                ]
            }

            SliderSetting {
                settingKey: "scrollVolumeStep"
                label: "Scroll Volume Step"
                description: "How much volume changes on each mouse wheel step"
                defaultValue: 2
                minimum: 1
                maximum: 20
                unit: "%"
                leftIcon: "swap_vert"
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: root.currentTab === 1

        SectionCard {
            title: "Horizontal Layout"
            description: "Settings for the horizontal bar widget."

            ToggleSetting {
                settingKey: "showHorizontalVisualizer"
                label: "Show Horizontal Visualizer"
                description: "Display the audio visualizer in horizontal bars when possible"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showHorizontalTitle"
                label: "Show Horizontal Title"
                description: "Display track title and artist in horizontal bars"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showHorizontalTitleBackground"
                label: "Horizontal Title Background"
                description: "Add a background behind the horizontal title to improve readability"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showHorizontalSkipControls"
                label: "Show Horizontal Previous/Next"
                description: "Show previous and next buttons in horizontal bars"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showHorizontalPlayPause"
                label: "Show Horizontal Play/Pause"
                description: "Show the play or pause button in horizontal bars"
                defaultValue: true
            }
        }

        SectionCard {
            title: "Horizontal Title"
            description: "Control how the horizontal title looks and behaves when the text is longer than the available width."

            SliderSetting {
                settingKey: "horizontalTitleExtent"
                label: "Horizontal Title Max Width"
                description: "Maximum width the horizontal title area can use"
                defaultValue: 160
                minimum: 72
                maximum: 420
                unit: "px"
                leftIcon: "width"
            }

            SelectionSetting {
                settingKey: "horizontalTitleScrollBehavior"
                label: "Horizontal Title Scroll"
                description: "Choose when the horizontal title should scroll"
                defaultValue: "never"
                options: [
                    {
                        label: "Never",
                        value: "never"
                    },
                    {
                        label: "Always Scroll",
                        value: "always"
                    },
                    {
                        label: "Scroll On Hover",
                        value: "hover"
                    },
                    {
                        label: "Pause On Hover",
                        value: "pauseOnHover"
                    }
                ]
            }

            SliderSetting {
                settingKey: "horizontalTitleScrollSpeed"
                label: "Horizontal Title Scroll Speed"
                description: "How fast the horizontal title scrolls when scrolling is enabled"
                defaultValue: 28
                minimum: 8
                maximum: 80
                unit: "px/s"
                leftIcon: "swap_horiz"
            }

            SliderSetting {
                settingKey: "horizontalTitlePadding"
                label: "Horizontal Title Padding"
                description: "Inner padding for the horizontal title background"
                defaultValue: 4
                minimum: 0
                maximum: 20
                unit: "px"
                leftIcon: "padding"
            }

            SliderSetting {
                settingKey: "horizontalTitleRadius"
                label: "Horizontal Title Radius"
                description: "Corner radius for the horizontal title background"
                defaultValue: 12
                minimum: 0
                maximum: 32
                unit: "px"
                leftIcon: "rounded_corner"
            }

            SelectionSetting {
                settingKey: "horizontalTitleBackgroundColorKey"
                label: "Horizontal Title Background Color"
                description: "Theme color used for the horizontal title background"
                defaultValue: "surfaceContainer"
                options: root.colorOptions
            }

            SelectionSetting {
                settingKey: "horizontalTitleTextColorKey"
                label: "Horizontal Title Text Color"
                description: "Theme color used for the horizontal title text"
                defaultValue: "widgetText"
                options: root.colorOptions
            }
        }

        SectionCard {
            title: "Horizontal Visualizer"
            description: "Adjust the visualizer used in horizontal bars."

            SliderSetting {
                settingKey: "horizontalVisualizerWidth"
                label: "Horizontal Visualizer Width"
                description: "Adjust the width of the horizontal visualizer"
                defaultValue: 20
                minimum: 12
                maximum: 300
                unit: "px"
                leftIcon: "graphic_eq"
            }

            SliderSetting {
                settingKey: "horizontalVisualizerBars"
                label: "Horizontal Visualizer Bars"
                description: "How many bars to show in the horizontal visualizer"
                defaultValue: 6
                minimum: 3
                maximum: 60
                unit: ""
                leftIcon: "equalizer"
            }

            ToggleSetting {
                settingKey: "horizontalVisualizerStretchToWidth"
                label: "Stretch Horizontal Visualizer"
                description: "Stretch the bars to fill the configured horizontal visualizer width"
                defaultValue: false
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: root.currentTab === 2

        SectionCard {
            title: "Vertical Layout"
            description: "Settings for the vertical bar widget."

            ToggleSetting {
                settingKey: "showVerticalVisualizer"
                label: "Show Vertical Visualizer"
                description: "Display the audio visualizer in vertical bars when possible"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showVerticalTitle"
                label: "Show Vertical Title"
                description: "Display track title and artist in vertical bars"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showVerticalTitleBackground"
                label: "Vertical Title Background"
                description: "Add a subtle background behind the vertical title to improve readability"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showVerticalSkipControls"
                label: "Show Vertical Previous/Next"
                description: "Add previous and next buttons around the play button in vertical bars"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showVerticalPlayPause"
                label: "Show Vertical Play/Pause"
                description: "Show the play or pause button in vertical bars"
                defaultValue: true
            }
        }

        SectionCard {
            title: "Vertical Title"
            description: "Control how the vertical title looks and behaves when the text is longer than the available space."

            SliderSetting {
                settingKey: "verticalTitleExtent"
                label: "Vertical Title Max Height"
                description: "Maximum height the vertical title area can use"
                defaultValue: 88
                minimum: 48
                maximum: 320
                unit: "px"
                leftIcon: "height"
            }

            SelectionSetting {
                settingKey: "verticalTitleScrollBehavior"
                label: "Vertical Title Scroll"
                description: "Choose when the vertical title should scroll"
                defaultValue: "never"
                options: [
                    {
                        label: "Never",
                        value: "never"
                    },
                    {
                        label: "Always Scroll",
                        value: "always"
                    },
                    {
                        label: "Scroll On Hover",
                        value: "hover"
                    },
                    {
                        label: "Pause On Hover",
                        value: "pauseOnHover"
                    }
                ]
            }

            SliderSetting {
                settingKey: "verticalTitleScrollSpeed"
                label: "Vertical Title Scroll Speed"
                description: "How fast the vertical title scrolls when scrolling is enabled"
                defaultValue: 28
                minimum: 8
                maximum: 80
                unit: "px/s"
                leftIcon: "swap_vert"
            }

            SliderSetting {
                settingKey: "verticalTitlePadding"
                label: "Vertical Title Padding"
                description: "Inner padding for the vertical title background"
                defaultValue: 4
                minimum: 0
                maximum: 20
                unit: "px"
                leftIcon: "padding"
            }

            SliderSetting {
                settingKey: "verticalTitleRadius"
                label: "Vertical Title Radius"
                description: "Corner radius for the vertical title background"
                defaultValue: 12
                minimum: 0
                maximum: 32
                unit: "px"
                leftIcon: "rounded_corner"
            }

            SelectionSetting {
                settingKey: "verticalTitleBackgroundColorKey"
                label: "Vertical Title Background Color"
                description: "Theme color used for the vertical title background"
                defaultValue: "surfaceContainer"
                options: root.colorOptions
            }

            SelectionSetting {
                settingKey: "verticalTitleTextColorKey"
                label: "Vertical Title Text Color"
                description: "Theme color used for the vertical title text"
                defaultValue: "widgetText"
                options: root.colorOptions
            }
        }

        SectionCard {
            title: "Vertical Visualizer"
            description: "Adjust the visualizer used in vertical bars."

            SliderSetting {
                settingKey: "verticalVisualizerWidth"
                label: "Vertical Visualizer Height"
                description: "Adjust the height of the vertical visualizer"
                defaultValue: 20
                minimum: 12
                maximum: 300
                unit: "px"
                leftIcon: "graphic_eq"
            }

            SliderSetting {
                settingKey: "verticalVisualizerBars"
                label: "Vertical Visualizer Bars"
                description: "How many bars to show in the vertical visualizer"
                defaultValue: 6
                minimum: 3
                maximum: 60
                unit: ""
                leftIcon: "equalizer"
            }

            ToggleSetting {
                settingKey: "verticalVisualizerStretchToWidth"
                label: "Stretch Vertical Visualizer"
                description: "Stretch the bars to fill the configured vertical visualizer height"
                defaultValue: false
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: root.currentTab === 3

        SectionCard {
            title: "Popout Size"
            description: "Adjust the media popout dimensions separately for horizontal and vertical bars."

            SliderSetting {
                settingKey: "popoutPanelWidthHorizontal"
                label: "Horizontal Popout Width"
                description: "Adjust the width of the media popout when the widget is used in horizontal bars"
                defaultValue: 560
                minimum: 420
                maximum: 800
                unit: "px"
                leftIcon: "width"
            }

            SliderSetting {
                settingKey: "popoutPanelHeightHorizontal"
                label: "Horizontal Popout Height"
                description: "Adjust the height of the media popout when the widget is used in horizontal bars"
                defaultValue: 420
                minimum: 320
                maximum: 720
                unit: "px"
                leftIcon: "height"
            }

            SliderSetting {
                settingKey: "popoutPanelWidthVertical"
                label: "Vertical Popout Width"
                description: "Adjust the width of the media popout when the widget is used in vertical bars"
                defaultValue: 560
                minimum: 420
                maximum: 800
                unit: "px"
                leftIcon: "width"
            }

            SliderSetting {
                settingKey: "popoutPanelHeightVertical"
                label: "Vertical Popout Height"
                description: "Adjust the height of the media popout when the widget is used in vertical bars"
                defaultValue: 420
                minimum: 320
                maximum: 720
                unit: "px"
                leftIcon: "height"
            }

            ToggleSetting {
                settingKey: "showPopoutInnerBackground"
                label: "Show Inner Popout Background"
                description: "Draw the extra rounded background panel behind the media content"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showPopoutArtworkBackdrop"
                label: "Show Artwork Backdrop"
                description: "Use the track artwork as a blurred background behind the popout content when available"
                defaultValue: true
            }
        }

        SectionCard {
            title: "Popout Title"
            description: "Control how many lines the media title can use inside the popout."

            SelectionSetting {
                settingKey: "popoutTitleMaxLines"
                label: "Popout Title Max Lines"
                description: "Choose how many lines the popout title may use"
                defaultValue: "1"
                options: [
                    {
                        label: "1 Line",
                        value: "1"
                    },
                    {
                        label: "2 Lines",
                        value: "2"
                    },
                    {
                        label: "3 Lines",
                        value: "3"
                    },
                    {
                        label: "4 Lines",
                        value: "4"
                    },
                    {
                        label: "Unlimited",
                        value: "0"
                    }
                ]
            }
        }
    }
}
