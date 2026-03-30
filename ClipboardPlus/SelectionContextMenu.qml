import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

// Universal selection context menu that appears at cursor position
PanelWindow {
    id: root

    required property ShellScreen screen
    property var pluginApi: null
    property var menuItems: []
    property real lastMouseX: 0
    property real lastMouseY: 0
    property real menuX: 0
    property real menuY: 0

    signal itemSelected(string action)
    signal cancelled

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "dms-selection-menu-" + (screen?.name || "unknown")
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    function updateMenuPosition() {
        const sx = (screen && screen.width) ? screen.width : (Screen.width || 0);
        const sy = (screen && screen.height) ? screen.height : (Screen.height || 0);
        const rawX = mouseCapture.mouseX || root.lastMouseX || Math.round(sx / 2);
        const rawY = mouseCapture.mouseY || root.lastMouseY || Math.round(sy / 2);
        const menuW = menuContainer.implicitWidth || 200;
        const menuH = menuContainer.implicitHeight || 60;
        const px = Math.max(Theme.spacingS, Math.min(Math.max(Theme.spacingS, sx - menuW - Theme.spacingS), rawX));
        const py = Math.max(Theme.spacingS, Math.min(Math.max(Theme.spacingS, sy - menuH - Theme.spacingS), rawY));
        menuX = isFinite(px) ? px : 0;
        menuY = isFinite(py) ? py : 0;
    }

    function show(items) {
        menuItems = items || [];
        visible = true;
        updateMenuPosition();
        repositionTimer.restart();
    }

    function close() {
        visible = false;
        repositionTimer.stop();
    }

    Timer {
        id: repositionTimer
        interval: 16
        repeat: true
        property int ticks: 0

        onTriggered: {
            updateMenuPosition();
            ticks++;
            if (ticks >= 3) {
                stop();
            }
        }

        onRunningChanged: {
            if (running) {
                ticks = 0;
            }
        }
    }

    // Fullscreen mouse area to capture outside clicks
    MouseArea {
        id: mouseCapture
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 0

        onPositionChanged: function (mouse) {
            root.lastMouseX = mouse.x;
            root.lastMouseY = mouse.y;
        }

        onClicked: {
            root.cancelled();
            root.close();
        }
    }

    Rectangle {
        id: menuContainer
        x: root.menuX
        y: root.menuY
        z: 1
        width: Math.min(260, Math.max(180, (menuColumn.implicitWidth || 0) + (Theme.spacingM || 0) * 2))
        height: Math.min(400, Math.max(60, (menuColumn.implicitHeight || 0) + (Theme.spacingM || 0) * 2))
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        visible: root.visible
        focus: root.visible

        Keys.onEscapePressed: {
            root.cancelled();
            root.close();
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Theme.surfaceContainer
            z: -1
        }

        Flickable {
            id: menuFlick
            anchors.fill: parent
            clip: true
            interactive: contentHeight > height
            contentWidth: width
            contentHeight: (menuColumn.implicitHeight || 0) + (Theme.spacingM || 0) * 2

            ScrollBar.vertical: ScrollBar {
                policy: menuFlick.contentHeight > menuFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                width: 6
                minimumSize: 0.1

                contentItem: Rectangle {
                    radius: width / 2
                    color: Theme.primary
                    opacity: parent.pressed ? 0.9 : (parent.hovered ? 0.75 : 0.5)
                }

                background: Rectangle {
                    radius: width / 2
                    color: Theme.surfaceContainerHighest
                    opacity: 0.4
                }
            }

            Item {
                id: menuContent
                width: menuFlick.width
                height: menuFlick.contentHeight

                Column {
                    id: menuColumn
                    width: Math.max(0, menuContent.width - Theme.spacingM * 2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.menuItems || []

                        delegate: Column {
                            width: menuColumn.width
                            spacing: Theme.spacingXS

                            Rectangle {
                                id: entry
                                width: menuColumn.width
                                height: label.implicitHeight + Theme.spacingS
                                radius: Theme.cornerRadius
                                readonly property bool isCreate: modelData.action === "create-new"
                                color: mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                StyledText {
                                    id: label
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingS
                                    text: modelData.label || ""
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onClicked: {
                                        root.itemSelected(modelData.action || "");
                                        root.close();
                                    }
                                }
                            }

                            Rectangle {
                                width: menuColumn.width
                                height: 1
                                color: Theme.outlineVariant
                                visible: modelData.action === "create-new" && root.menuItems && root.menuItems.length > 1
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onDestruction: close
}
