import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    property int size: Theme.iconSize
    property color color: Theme.surfaceText
    property bool crossed: false

    implicitWidth: size
    implicitHeight: size

    Image {
        id: iconImage
        anchors.fill: parent
        source: "./icons/netbird.svg"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.color
        }
    }

    Rectangle {
        visible: root.crossed
        anchors.centerIn: parent
        width: parent.width * 1.2
        height: parent.height * 0.15
        radius: height / 2
        color: root.color
        rotation: -45
    }
}
