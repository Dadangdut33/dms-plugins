import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    focus: true
    clip: false
    property var clipboardItem: null
    property var pluginApi: null
    property var screen: null
    property var panelRoot: null
    property string clipboardId: clipboardItem ? clipboardItem.id : ""
    property string mime: clipboardItem ? clipboardItem.mime : ""
    property string preview: clipboardItem ? clipboardItem.preview : ""
    property string pinnedImageDataUrl: ""  // For pinned images - data URL

    // Content type detection
    readonly property bool isImage: clipboardItem && clipboardItem.isImage
    readonly property bool isColor: {
        if (isImage || !preview)
            return false;
        const trimmed = preview.trim();
        return /^#[A-Fa-f0-9]{6}$/.test(trimmed) || /^#[A-Fa-f0-9]{3}$/.test(trimmed) || /^[A-Fa-f0-9]{6}$/.test(trimmed) || /^rgba?\(.*\)$/i.test(trimmed);
    }
    readonly property bool isLink: !isImage && !isColor && preview && /^https?:\/\//.test(preview.trim())
    readonly property bool isCode: !isImage && !isColor && !isLink && preview && (preview.includes("function") || preview.includes("import ") || preview.includes("const ") || preview.includes("let ") || preview.includes("var ") || preview.includes("class ") || preview.includes("def ") || preview.includes("return ") || /^[\{\[\(<]/.test(preview.trim()))
    readonly property bool isEmoji: {
        if (isImage || isColor || isLink || isCode || !preview)
            return false;
        const trimmed = preview.trim();
        return trimmed.length <= 4 && trimmed.charCodeAt(0) > 255;
    }
    readonly property bool isFile: !isImage && !isColor && !isLink && !isCode && !isEmoji && preview && /^(\/|~|file:\/\/)/.test(preview.trim())
    readonly property bool isText: !isImage && !isColor && !isLink && !isCode && !isEmoji && !isFile

    readonly property string colorValue: {
        if (!isColor || !preview)
            return "";
        const trimmed = preview.trim();
        if (/^#[A-Fa-f0-9]{3,6}$/.test(trimmed))
            return trimmed;
        if (/^[A-Fa-f0-9]{6}$/.test(trimmed))
            return "#" + trimmed;
        return trimmed;
    }

    readonly property string typeLabel: isImage ? "Image" : isColor ? "Color" : isLink ? "Link" : isCode ? "Code" : isEmoji ? "Emoji" : isFile ? "File" : "Text"
    readonly property string typeIcon: isImage ? "image" : isColor ? "palette" : isLink ? "link" : isCode ? "code" : isEmoji ? "sentiment_satisfied" : isFile ? "description" : "format_align_left"

    function paletteForType() {
        switch (typeLabel) {
        case "Image":
            return { bg: Theme.surfaceContainer, fg: Theme.surfaceText, sep: Theme.outline };
        case "Link":
            return { bg: Theme.primaryBackground, fg: Theme.surfaceText, sep: Theme.surfaceContainer };
        case "Code":
            return { bg: Theme.surfaceContainerHighest, fg: Theme.surfaceText, sep: Theme.outline };
        case "Color":
            return { bg: Theme.surfaceVariant, fg: Theme.surfaceText, sep: Theme.outline };
        case "File":
            return { bg: Theme.surface, fg: Theme.surfaceText, sep: Theme.outline };
        case "Emoji":
            return { bg: Theme.surfaceVariant, fg: Theme.surfaceText, sep: Theme.outline };
        default:
            return { bg: Theme.surfaceVariant, fg: Theme.surfaceVariantText, sep: Theme.outline };
        }
    }

    readonly property color accentColor: paletteForType().bg || Theme.surfaceContainerHigh
    readonly property color accentFgColor: paletteForType().fg || Theme.surfaceText
    readonly property color separatorColor: paletteForType().sep || Theme.outline

    signal clicked
    signal deleteClicked
    signal addToTodoClicked
    signal pinClicked
    signal rightClicked
    property bool selected: false
    property bool enableTodoIntegration: false
    property bool isPinned: false
    property bool expandToContent: false
    property int maxExpandedHeight: 420

    width: 250
    implicitHeight: 0
    height: fixedHeight > 0 ? fixedHeight : computedHeight

    readonly property int headerHeight: 35
    readonly property int bodyPadding: 8
    readonly property int imageBodyHeight: 160
    // Use root.width to compute body width directly, avoiding a dependency on bodyItem.height
    readonly property int bodyWidth: root.width - bodyPadding * 2
    readonly property int contentImplicitHeight: root.isImage
                                              ? imageBodyHeight
                                              : Math.max(24, Math.ceil(previewMeasure.contentHeight))
    readonly property int separatorHeight: 1
    readonly property int computedHeight: Math.min(maxExpandedHeight, headerHeight + separatorHeight + bodyPadding * 2 + contentImplicitHeight)
    property int extraCardPadding: 16
    property int fixedHeight: -1

    readonly property bool isHover: mouseArea.containsMouse
    readonly property color hoverColor: Qt.lighter(accentColor, 1.25)
    readonly property color selectedColor: Qt.darker(accentColor, 1.15)

    color: isHover ? hoverColor : (selected ? selectedColor : accentColor)

    radius: (typeof Style !== "undefined") ? Theme.cornerRadius : 16
    border.width: 0
    border.color: "transparent"

    // Top center indicator pill for hover/selected
    Rectangle {
        width: 40
        height: 4
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6
        color: isHover ? Theme.primary : Theme.secondary
        opacity: isHover || selected ? 0.9 : 0
        radius: 2
        z: 20
    }

    // Hover/selected outline
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: isHover || selected ? 2 : 0
        border.color: isHover ? Theme.primary : Theme.secondary
        antialiasing: true
        z: 30
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: headerHeight
            color: root.accentColor
            topLeftRadius: (typeof Style !== "undefined") ? Theme.cornerRadius : 16
            topRightRadius: (typeof Style !== "undefined") ? Theme.cornerRadius : 16
            bottomLeftRadius: 0
            bottomRightRadius: 0

            RowLayout {
                id: headerContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 8
                spacing: 8

                DankIcon {
                    name: root.typeIcon
                    size: 13
                    color: root.accentFgColor
                }

                StyledText {
                    text: root.typeLabel
                    color: root.accentFgColor
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                DankActionButton {
                    id: todoButton
                    visible: root.enableTodoIntegration && !root.isImage
                    iconName: "playlist_add_check"
                    iconColor: root.accentFgColor
                    backgroundColor: "transparent"
                    tooltipText: pluginApi?.tr("card.add-todo") || "Add to ToDo"
                    onClicked: {
                        if (root.preview) {
                            root.pluginApi?.mainInstance?.addTodoWithText(root.preview.substring(0, 200), 0);
                        }
                    }
                }

                DankActionButton {
                    visible: !root.isPinned && (pluginApi?.pluginSettings?.pincardsEnabled ?? true)
                    iconName: "push_pin"
                    iconColor: root.accentFgColor
                    backgroundColor: "transparent"
                    tooltipText: pluginApi?.tr("card.pin") || "Pin"
                    onClicked: root.pinClicked()
                }

                DankActionButton {
                    iconName: "delete"
                    iconColor: root.accentFgColor
                    backgroundColor: "transparent"
                    tooltipText: pluginApi?.tr("card.delete") || "Delete"
                    onClicked: root.deleteClicked()
                }
            }
        }

        Rectangle {
            width: parent.width - 10
            Layout.alignment: Qt.AlignHCenter
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: root.separatorColor
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        Item {
            id: bodyItem
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            clip: true

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        root.rightClicked()
                    } else {
                        root.clicked()
                    }
                }
            }

            Rectangle {
                visible: root.isColor
                anchors.fill: parent
                radius: 8
                color: root.colorValue || "transparent"
                border.width: 1
                border.color: root.accentFgColor
            }

            StyledText {
                id: previewText
                visible: !root.isColor && !root.isImage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: root.preview || ""
                wrapMode: Text.Wrap
                elide: root.expandToContent ? Text.ElideNone : Text.ElideRight
                color: root.accentFgColor
                font.pixelSize: 11
                verticalAlignment: Text.AlignTop
            }

            // Measurement text — width bound to root.bodyWidth, not bodyItem.width,
            // to avoid a layout feedback loop through computedHeight.
            Text {
                id: previewMeasure
                visible: false
                text: root.preview || ""
                wrapMode: Text.Wrap
                font.pixelSize: previewText.font.pixelSize
                font.family: previewText.font.family
                font.weight: previewText.font.weight
                width: root.bodyWidth
            }

            Rectangle {
                visible: root.isImage
                anchors.fill: parent
                radius: 8
                color: "transparent"
                clip: true

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: {
                        if (root.pinnedImageDataUrl) {
                            return root.pinnedImageDataUrl;
                        }
                        if (root.isImage && root.pluginApi?.mainInstance) {
                            const revision = root.pluginApi.mainInstance.imageCacheRevision;
                            const cache = root.pluginApi.mainInstance.imageCache;
                            return cache[root.clipboardId] || "";
                        }
                        return "";
                    }
                }

                Component.onCompleted: {
                    if (!root.pinnedImageDataUrl && root.isImage && root.clipboardId && root.pluginApi?.mainInstance) {
                        root.pluginApi.mainInstance.decodeToDataUrl(root.clipboardId, root.mime, null);
                    }
                }
            }
        }
    }

    Component.onDestruction: {}
}
