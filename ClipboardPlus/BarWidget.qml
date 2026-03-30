import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    width: button.buttonSize
    height: button.buttonSize
    implicitWidth: width
    implicitHeight: height

    DankActionButton {
        id: button
        anchors.fill: parent

        iconName: "content_paste"
        iconColor: Theme.surfaceText
        backgroundColor: Theme.surfaceContainerHigh
        tooltipText: "Clipboard History"
        tooltipSide: "bottom"

        onClicked: {
            if (pluginApi?.openPanel) {
                pluginApi.openPanel(screen, root);
            }
        }
    }

    Popup {
        id: contextMenu
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: Rectangle {
            color: Theme.surfaceContainerHigh
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            width: 200

            Column {
                id: menuColumn
                width: parent.width
                spacing: Theme.spacingS
                padding: Theme.spacingM

                Repeater {
                    model: [
                        {
                            label: "Toggle ClipBoard+",
                            action: "toggle-clipboardPlus"
                        },
                        {
                            label: "Open Settings",
                            action: "open-settings"
                        }
                    ]

                    delegate: Rectangle {
                        width: menuColumn.width
                        height: label.implicitHeight + Theme.spacingS
                        radius: Theme.cornerRadius / 2
                        color: mouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        StyledText {
                            id: label
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            text: modelData.label
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                contextMenu.close();
                                if (modelData.action === "toggle-clipboardPlus") {
                                    pluginApi?.togglePanel && pluginApi.togglePanel(screen);
                                } else if (modelData.action === "open-settings") {
                                    PopoutService.openSettingsWithTab("plugins");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: {
            const pos = root.mapToItem(Overlay.overlay, 0, root.height);
            contextMenu.x = pos.x;
            contextMenu.y = pos.y;
            contextMenu.open();
        }
    }
}
