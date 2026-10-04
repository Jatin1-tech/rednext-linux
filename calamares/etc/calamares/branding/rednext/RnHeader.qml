// Centered icon + title, red subtitle, then a divider (screenshot-popup header)
import QtQuick
import QtQuick.Layouts
ColumnLayout {
    property string icon
    property string title
    property string subtitle
    property color subtitleColor: "#D42A3C"
    spacing: 6
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 10
        Text { text: icon; color: "#EDEAEA"; font.family: "Material Symbols Rounded"; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }
        Text { text: title; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 22; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    Text {
        Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
        visible: subtitle !== ""
        text: subtitle; color: subtitleColor; font.family: "Rubik"; font.pixelSize: 15
    }
    Rectangle { Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 6; height: 1; color: "#3A3A3A" }
}
