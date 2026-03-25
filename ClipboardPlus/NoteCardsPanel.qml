import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: root

    property var pluginApi: null
    property var screen: null

    // Function to sync all notecard changes before saving
    function syncAllChanges() {
        for (let i = 0; i < noteCardsRepeater.count; i++) {
            const card = noteCardsRepeater.itemAt(i);
            if (card && card.syncChanges) {
                card.syncChanges();
            }
        }
    }

    // Background MouseArea - closes panel when clicking empty note area
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true

        onClicked: {
            const closeOnOutside = root.pluginApi?.pluginSettings?.closeOnOutsideClick ?? true;
            if (closeOnOutside && root.pluginApi && root.screen) {
                root.pluginApi.closePanel(root.screen);
            }
        }
    }

    // Empty state UI (shown when no notes)
    Item {
        anchors.centerIn: parent
        width: 400
        height: 200
        visible: !(root.pluginApi && root.pluginApi.mainInstance && root.pluginApi.mainInstance.noteCards) || root.pluginApi.mainInstance.noteCards.length === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            DankIcon {
                Layout.alignment: Qt.AlignHCenter
                name: "sticky_note_2"
                size: 64
                color: Theme.surfaceVariantText
                opacity: 0.5
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "No notes yet"
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.surfaceVariantText
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Click the button below to create your first note"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                opacity: 0.7
            }

            DankButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                text: "Create Note"
                iconName: "add"

                onClicked: {
                    if (root.pluginApi && root.pluginApi.mainInstance) {
                        root.pluginApi.mainInstance.createNoteCard("");
                    }
                }
            }
        }
    }

    // Repeater for note cards
    Repeater {
        id: noteCardsRepeater
        model: root.pluginApi?.mainInstance?.noteCards || []

        NoteCard {
            pluginApi: root.pluginApi
            note: modelData
            noteIndex: index
            z: 2  // Above background MouseArea
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        width: contentRow.width + 16
        height: 40
        color: Theme.surfaceContainer
        border.color: Theme.surfaceVariantText
        border.width: 1
        radius: Theme.cornerRadius
        visible: (root.pluginApi && root.pluginApi.mainInstance && root.pluginApi.mainInstance.noteCards) ? root.pluginApi.mainInstance.noteCards.length > 0 : false
        z: 3  // Above everything

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            // Add note button
            DankActionButton {
                width: 28
                height: 28
                iconName: "add"
                tooltipText: "Create Note"
                backgroundColor: Theme.primary
                iconColor: Theme.onPrimary

                onClicked: {
                    if (root.pluginApi && root.pluginApi.mainInstance) {
                        const count = root.pluginApi.mainInstance.noteCards ? root.pluginApi.mainInstance.noteCards.length : 0;
                        const max = root.pluginApi.mainInstance.maxNoteCards || 20;

                        if (count >= max) {
                            ToastService.showWarning(("Maximum {max} notes reached").replace("{max}", max));
                        } else {
                            root.pluginApi.mainInstance.createNoteCard("");
                        }
                    }
                }
            }

            // Vertical separator
            Rectangle {
                width: 1
                height: 24
                color: Theme.surfaceVariantText
                opacity: 0.3
            }

            // Note icon
            DankIcon {
                name: "sticky_note_2"
                size: 16
                color: Theme.surfaceVariantText
            }

            // Count text
            StyledText {
                text: {
                    const count = (root.pluginApi && root.pluginApi.mainInstance && root.pluginApi.mainInstance.noteCards) ? root.pluginApi.mainInstance.noteCards.length : 0;
                    const max = (root.pluginApi && root.pluginApi.mainInstance) ? (root.pluginApi.mainInstance.maxNoteCards || 20) : 20;
                    return count + " / " + max;
                }
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                color: {
                    const count = (root.pluginApi && root.pluginApi.mainInstance && root.pluginApi.mainInstance.noteCards) ? root.pluginApi.mainInstance.noteCards.length : 0;
                    const max = (root.pluginApi && root.pluginApi.mainInstance) ? (root.pluginApi.mainInstance.maxNoteCards || 20) : 20;
                    return count >= max ? Theme.error : Theme.surfaceVariantText;
                }
            }
        }
    }
    Component.onDestruction: {}
}
