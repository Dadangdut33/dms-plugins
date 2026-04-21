import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    property bool localPrivate: note && note.isPrivate === true
    property real storedWidth: note ? note.width : 350
    property real storedHeight: note ? note.height : 280
    property bool actionsMenuOpen: false
    readonly property real noteScale: Math.max(0.7, (pluginApi?.pluginSettings?.noteCardScale ?? 100) / 100)
    readonly property var currentFocusItem: Window.activeFocusItem
    readonly property bool noteFocused: {
        let item = currentFocusItem;
        while (item) {
            if (item === root)
                return true;
            item = item.parent;
        }
        return false;
    }
    readonly property bool privacyBlurActive: localPrivate && !noteFocused

    onNoteChanged: {
        if (note && note.color) {
            localColor = note.color;
        }
        localPrivate = note && note.isPrivate === true;
        storedWidth = note && note.width ? note.width : 350;
        storedHeight = note && note.height ? note.height : 280;
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
    readonly property int baseMinHeight: 200
    readonly property int baseMaxHeight: 600
    readonly property int baseMinWidth: 305
    readonly property int baseMaxWidth: 900
    readonly property int baseHeaderHeight: 40
    readonly property int baseMargins: 24
    readonly property int minHeight: Math.round(baseMinHeight * noteScale)
    readonly property int maxHeight: Math.round(baseMaxHeight * noteScale)
    readonly property int minWidth: Math.round(baseMinWidth * noteScale)
    readonly property int maxWidth: Math.round(baseMaxWidth * noteScale)
    readonly property int headerHeight: Math.round(baseHeaderHeight * noteScale)
    readonly property int margins: Math.round(baseMargins * noteScale)

    // Position and size from note data
    x: note ? note.x : 0
    y: note ? note.y : 0
    width: Math.round(storedWidth * noteScale)
    height: Math.round(storedHeight * noteScale)
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
    focus: true

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.forceActiveFocus()
    }

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
                anchors.leftMargin: Math.round(10 * root.noteScale)
                anchors.rightMargin: Math.round(6 * root.noteScale)
                spacing: Math.round(10 * root.noteScale)
                z: 1
                clip: true

                // Icon - DRAG HANDLE
                Item {
                    Layout.preferredWidth: Math.round(24 * root.noteScale)
                    Layout.fillHeight: true

                    DankIcon {
                        anchors.centerIn: parent
                        name: "sticky_note_2"
                        size: Math.round(15 * root.noteScale)
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
                            root.forceActiveFocus();
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
                    Layout.minimumWidth: 0
                    layer.enabled: root.privacyBlurActive
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.9
                        blurMax: 48
                    }

                    TextInput {
                        id: titleInput
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(4 * root.noteScale)
                        anchors.rightMargin: Math.round(4 * root.noteScale)
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignLeft
                        color: {
                            const noteColor = localColor;
                            const scheme = colorSchemes[noteColor];
                            return scheme ? scheme.fg : "#000000";
                        }
                        font.pixelSize: Math.round(14 * root.noteScale)
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
                    id: noteActionsButton
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    width: Math.max(20, Math.round(28 * root.noteScale))
                    height: Math.max(20, Math.round(28 * root.noteScale))
                    buttonSize: width
                    iconSize: Math.max(14, Math.round(16 * root.noteScale))
                    iconName: "more_vert"
                    tooltipText: "Note Actions"
                    iconColor: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.fg : "#000000";
                    }
                    backgroundColor: root.actionsMenuOpen ? Qt.rgba(0, 0, 0, 0.14) : "transparent"
                    onClicked: root.actionsMenuOpen = !root.actionsMenuOpen
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
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Math.round(12 * root.noteScale)
            clip: true

            ScrollView {
                id: contentScroll
                anchors.fill: parent
                clip: true
                background: Rectangle {
                    color: "transparent"
                }
                layer.enabled: root.privacyBlurActive
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.9
                    blurMax: 48
                }
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    id: textArea
                    width: contentScroll.availableWidth
                    height: Math.max(implicitHeight, contentScroll.availableHeight)
                    wrapMode: TextEdit.WrapAnywhere
                    selectByMouse: true
                    activeFocusOnPress: true
                    color: {
                        const noteColor = localColor;
                        const scheme = colorSchemes[noteColor];
                        return scheme ? scheme.fg : "#000000";
                    }
                    font.pixelSize: Math.round(14 * root.noteScale)
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

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.12)
                visible: root.privacyBlurActive
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: root.privacyBlurActive

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "visibility_off"
                    size: Math.round(20 * root.noteScale)
                    color: Qt.rgba(0, 0, 0, 0.55)
                }

                StyledText {
                    text: "Private"
                    font.pixelSize: Math.round(12 * root.noteScale)
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
            }
        }

        // Note ID footer
        Rectangle {
            Layout.fillWidth: true
            height: Math.round(18 * root.noteScale)
            color: "transparent"
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                StyledText {
                    id: noteIdText
                    text: note && note.id ? ("ID: " + note.id) : ""
                    font.pixelSize: Math.round(10 * root.noteScale)
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                DankActionButton {
                    width: Math.round(10 * root.noteScale)
                    height: Math.round(10 * root.noteScale)
                    iconSize: Math.round(10 * root.noteScale)
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

    component NoteActionRow: Rectangle {
        id: actionRow
        required property string text
        required property string iconName
        signal triggered

        width: parent.width
        height: 38
        radius: Theme.cornerRadius
        color: actionArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: actionRow.iconName
                size: 16
                color: Theme.surfaceText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: actionRow.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
            }
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRow.triggered()
        }
    }

    Rectangle {
        id: noteActionsMenu
        visible: root.actionsMenuOpen
        z: 999
        width: Math.min(Math.round(220 * root.noteScale), Math.max(Math.round(140 * root.noteScale), root.width - Theme.spacingM * 2))
        height: actionsMenuColumn.implicitHeight + Theme.spacingS * 2
        x: Math.max(Theme.spacingS, root.width - width - Theme.spacingS)
        y: root.headerHeight + Theme.spacingXS
        radius: Theme.cornerRadius * 1.25
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)

        Column {
            id: actionsMenuColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingXS

            NoteActionRow {
                width: parent.width
                text: root.localPrivate ? "Disable Privacy Mode" : "Enable Privacy Mode"
                iconName: root.localPrivate ? "visibility_off" : "visibility"
                onTriggered: {
                    root.actionsMenuOpen = false;
                    if (root.pluginApi && root.pluginApi.mainInstance && root.note) {
                        localPrivate = !localPrivate;
                        root.pluginApi.mainInstance.updateNoteCard(root.note.id, {
                            isPrivate: localPrivate
                        });
                    }
                }
            }

            NoteActionRow {
                width: parent.width
                text: "Change Color"
                iconName: "palette"
                onTriggered: {
                    root.actionsMenuOpen = false;
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

            NoteActionRow {
                width: parent.width
                text: "Export to .txt"
                iconName: "file_upload"
                onTriggered: {
                    root.actionsMenuOpen = false;
                    if (root.pluginApi && root.pluginApi.mainInstance)
                        root.pluginApi.mainInstance.exportNoteCard(root.note.id);
                }
            }

            NoteActionRow {
                width: parent.width
                text: "Delete Note"
                iconName: "delete"
                onTriggered: {
                    root.actionsMenuOpen = false;
                    if (root.pluginApi && root.pluginApi.mainInstance)
                        root.pluginApi.mainInstance.deleteNoteCard(root.note.id);
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
        width: Math.round(16 * root.noteScale)
        height: Math.round(16 * root.noteScale)
        radius: 4
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.round(6 * root.noteScale)
        anchors.bottomMargin: Math.round(6 * root.noteScale)
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

            onPressed: function (mouse) {
                startW = root.width;
                startH = root.height;
                startX = mouse.x;
                startY = mouse.y;
                root.forceActiveFocus();
                if (root.pluginApi && root.pluginApi.mainInstance) {
                    root.pluginApi.mainInstance.bringNoteToFront(root.note.id);
                }
            }

            onPositionChanged: function (mouse) {
                const dx = mouse.x - startX;
                const dy = mouse.y - startY;
                const newW = Math.max(root.minWidth, Math.min(root.maxWidth, startW + dx));
                const newH = Math.max(root.minHeight, Math.min(root.maxHeight, startH + dy));
                root.storedWidth = newW / root.noteScale;
                root.storedHeight = newH / root.noteScale;
            }

            onReleased: {
                if (root.pluginApi && root.pluginApi.mainInstance && root.note) {
                    root.pluginApi.mainInstance.updateNoteCard(root.note.id, {
                        width: Math.round(root.storedWidth),
                        height: Math.round(root.storedHeight)
                    });
                }
            }
        }
    }
}
