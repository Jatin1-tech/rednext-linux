// Image with rounded corners (the big preview in the screenshot popup)
import QtQuick
import QtQuick.Effects
Item {
    id: root
    property alias source: img.source
    property int radius: 20
    Image { id: img; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true; smooth: true; mipmap: true }
    Rectangle { id: mask; anchors.fill: parent; radius: root.radius; visible: false; layer.enabled: true; antialiasing: true }
    MultiEffect {
        anchors.fill: parent; source: img
        maskEnabled: true; maskSource: mask
        maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
    }
}
