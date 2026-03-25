import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    // Properties
    property var pluginApi: null
    property var note: null
    property int noteIndex: 0
    property string localColor: (note && note.color) ? note.color : "yellow"

    onNoteChanged: {
        if (note && note.color) {
            localColor = note.color;
        }
    }

    // Color schemes
    property var colorSchemes: ({
            "yellow": {
                bg: "#FFF9C4",
                fg: "#000000",
                header: "#FDD835"
            },
            "pink": {
                bg: "#FCE4EC",
                fg: "#000000",
                header: "#F06292"
            },
            "blue": {
                bg: "#E3F2FD",
                fg: "#000000",
                header: "#42A5F5"
            },
            "green": {
                bg: "#E8F5E9",
                fg: "#000000",
                header: "#66BB6A"
            },
            "purple": {
                bg: "#F3E5F5",
                fg: "#000000",
                header: "#AB47BC"
            }
        })

    // Constants for sizing
    readonly property int minHeight: 200
    readonly property int maxHeight: 600
    readonly property int minWidth: 305
    readonly property int maxWidth: 900
    readonly property int headerHeight: 40
    readonly property int margins: 24

    // Position and size from note data
    x: note ? note.x : 0
    y: note ? note.y : 0
    width: note ? note.width : 350
    height: note ? note.height : minHeight
    z: note ? note.zIndex : 0

    // Color from note data
    color: {
        const noteColor = localColor;
        const scheme = colorSchemes[noteColor];
        return scheme ? scheme.bg : "#FFF9C4";
    }
    border.color: Theme.surfaceVariantText
    border.width: 1
    radius: Theme.cornerRadius

    // Main layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            color: {
                const noteColor = localColor;
                const scheme = colorSchemes[noteColor];
                return scheme ? scheme.header : "#FDD835";
            }
            topLeftRadius: Theme.cornerRadius
            topRightRadius: Theme.cornerRadius
            bottomLeftRadius: 0
            bottomRightRadius: 0
            clip: true

            RowLayout {
                id: headerContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 10
                z: 1
                clip: true

                // Icon - DRAG HANDLE
                Item {
                    Layout.preferredWidth: 24
                    Layout.fillHeight: true

                    DankIcon {
                        anchors.centerIn: parent
                        name: "sticky_note_2"
                        size: 15
                        color: {
                            const noteColor = localColor;
                            const scheme = colorSchemes[noteColor];
                            return scheme ? scheme.fg : "#000000";
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor

                        drag.target: root
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 0
                        drag.maximumX: root.parent ? (root.parent.width - root.width) : 1200
                        drag.minimumY: 0
                        drag.maximumY: root.parent ? (root.parent.height - root.height) : 700

                        onPressed: {
                            if (root.pluginApi && root.pluginApi.mainInstance) {
                                root.pluginApi.mainInstance.bringNoteToFront(root.note.id);
                            }
                        }

                        onReleased: {
                            if (root.pluginApi && root.pluginApi.mainInstance) {
                                root.pluginApi.mainInstance.updateNoteCard(root.note.id, {
                                    x: root.x,
                                    y: root.y
                                });
                            }
                        }
                    }
                }

                // Title
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 125

                    TextInput {
                        id: titleInput
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignLeft
                        color: {
                            const noteColor = localColor;
                            const scheme = colorSchemes[noteColor];
                            return scheme ? scheme.fg : "#000000";
                        }
                        font.pixelSize: 14
                        font.bold: false
                        selectByMouse: true
                        clip: true
                        wrapMode: TextInput.Wrap
                        activeFocusOnPress: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            text: "Untitled"
                            color: parent.color
                            opacity: 0.5
                            visible: titleInput.text.length === 0
                            font: titleInput.font
                        }

                        Component.onCompleted: {
                            if (note) {
                                text = note.title || "";
                            }
                        }

                        onEditingFinished: root.scheduleSave()
                        onTextChanged: root.scheduleSave()
                    }
                }
                DankActionButton {
                    iconName: "palette"
                    tooltipText: "Change Color"
                    iconColor: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.fg : "#000000";
                    }
                    backgroundColor: "transparent"

                    onClicked: {
                        const colors = ["yellow", "pink", "blue", "green", "purple"];
                        const noteColor = localColor;
                        const currentIndex = colors.indexOf(noteColor);
                        const nextIndex = (currentIndex + 1) % colors.length;
                        const nextColor = colors[nextIndex];

                        if (root.pluginApi && root.pluginApi.mainInstance) {
                            localColor = nextColor;
                            root.pluginApi.mainInstance.updateNoteCard(root.note.id, {
                                color: nextColor
                            });
                        }
                    }
                }

                DankActionButton {
                    iconName: "file_upload"
                    tooltipText: "Export to .txt"
                    iconColor: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.fg : "#000000";
                    }
                    backgroundColor: "transparent"

                    onClicked: {
                        if (root.pluginApi && root.pluginApi.mainInstance) {
                            root.pluginApi.mainInstance.exportNoteCard(root.note.id);
                        }
                    }
                }

                DankActionButton {
                    iconName: "delete"
                    tooltipText: "Delete Note"
                    iconColor: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.fg : "#000000";
                    }
                    backgroundColor: "transparent"

                    onClicked: {
                        if (root.pluginApi && root.pluginApi.mainInstance) {
                            root.pluginApi.mainInstance.deleteNoteCard(root.note.id);
                        }
                    }
                }
            }
        }

        // Separator
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
                    color: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.header : "#FDD835";
                    }
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // Content area with ScrollView
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            clip: true

            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    id: textArea
                    width: parent.width
                    wrapMode: TextEdit.WrapAnywhere
                    selectByMouse: true
                    activeFocusOnPress: true
                    color: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.fg : "#000000";
                    }
                    font.pixelSize: 14
                    background: Rectangle {
                        color: "transparent"
                    }

                    Component.onCompleted: {
                        if (note) {
                            text = note.content || "";
                        }
                        // Check if we need to expand card on load
                        Qt.callLater(checkAndExpandHeight);
                    }

                    onTextChanged: root.scheduleSave()
                }
            }
        }

        // Note ID footer
        Rectangle {
            Layout.fillWidth: true
            height: 18
            color: "transparent"
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                StyledText {
                    id: noteIdText
                    text: note && note.id ? ("ID: " + note.id) : ""
                    font.pixelSize: 10
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                DankActionButton {
                    width: 10
                    height: 10
                    iconSize: 10
                    iconName: "content_copy"
                    tooltipText: "Copy ID"
                    backgroundColor: "transparent"
                    iconColor: Theme.surfaceVariantText
                    onClicked: {
                        if (root.pluginApi && root.pluginApi.mainInstance && root.note && root.note.id) {
                            root.pluginApi.mainInstance.copyTextToClipboard(root.note.id);
                        }
                    }
                }
            }
        }
    }

    // Check if card needs to be expanded to fit content
    function checkAndExpandHeight() {
        if (!textArea || !note)
            return;

        const contentHeight = textArea.contentHeight;
        const availableHeight = root.height - root.headerHeight - root.margins - 1; // 1 = separator

        // If content doesn't fit, expand card
        if (contentHeight > availableHeight) {
            let newHeight = root.headerHeight + root.margins + contentHeight + 1;
            newHeight = Math.min(newHeight, root.maxHeight);

            if (newHeight !== root.height && root.pluginApi && root.pluginApi.mainInstance) {
                root.pluginApi.mainInstance.updateNoteCard(root.note.id, {
                    height: newHeight
                });
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 300
        repeat: false
        onTriggered: root.syncChanges()
    }

    function scheduleSave() {
        if (!note || !root.pluginApi || !root.pluginApi.mainInstance)
            return;
        // Keep in-memory note data up to date immediately
        root.pluginApi.mainInstance.updateNoteCardInMemory(note.id, {
            title: titleInput.text,
            content: textArea.text
        });
        saveTimer.restart();
    }

    function syncChanges() {
        if (root.pluginApi && root.pluginApi.mainInstance && note) {
            root.pluginApi.mainInstance.updateNoteCardInMemory(note.id, {
                title: titleInput.text,
                content: textArea.text
            });
            root.pluginApi.mainInstance.saveNoteCardById(note.id);
        }
    }
    Component.onDestruction: {
        root.syncChanges();
    }

    // Resize handle (bottom-right)
    Rectangle {
        id: resizeHandle
        width: 16
        height: 16
        radius: 4
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 6
        anchors.bottomMargin: 6
        color: Qt.rgba(0, 0, 0, 0.12)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.18)
        z: 10

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            property real startW: 0
            property real startH: 0
            property real startX: 0
            property real startY: 0

            onPressed: function(mouse) {
                startW = root.width;
                startH = root.height;
                startX = mouse.x;
                startY = mouse.y;
                if (root.pluginApi && root.pluginApi.mainInstance) {
                    root.pluginApi.mainInstance.bringNoteToFront(root.note.id);
                }
            }

            onPositionChanged: function(mouse) {
                const dx = mouse.x - startX;
                const dy = mouse.y - startY;
                const newW = Math.max(root.minWidth, Math.min(root.maxWidth, startW + dx));
                const newH = Math.max(root.minHeight, Math.min(root.maxHeight, startH + dy));
                root.width = newW;
                root.height = newH;
            }

            onReleased: {
                if (root.pluginApi && root.pluginApi.mainInstance && root.note) {
                    root.pluginApi.mainInstance.updateNoteCard(root.note.id, {
                        width: root.width,
                        height: root.height
                    });
                }
            }
        }
    }
}
