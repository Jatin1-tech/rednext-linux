// Red rounded-square icon button ("Open in folder >" in the screenshot popup)
import QtQuick
Rectangle {
    id: b
    property string icon: "chevron_right"
    signal clicked()
    width: 44; height: 44; radius: 12
    color: !enabled ? "#3A1418" : (ma.containsMouse ? "#E24253" : "#D42A3C")
    scale: ma.pressed ? 0.92 : 1
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 110 } }
    Text { anchors.centerIn: parent; text: b.icon; color: "#F7EDEE"; font.family: "Material Symbols Rounded"; font.pixelSize: 24 }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.enabled) b.clicked() }
}
