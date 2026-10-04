// Info row: red line icon + text (screenshot-popup detail rows)
import QtQuick
import QtQuick.Layouts
RowLayout {
    property string icon
    property string text
    property color iconColor: "#D42A3C"
    property color textColor: "#EDEAEA"
    property int textFormat: Text.PlainText
    spacing: 14
    Text { Layout.alignment: Qt.AlignTop; text: parent.icon; color: parent.iconColor; font.family: "Material Symbols Rounded"; font.pixelSize: 20 }
    Text {
        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
        text: parent.text; color: parent.textColor; textFormat: parent.textFormat
        wrapMode: Text.WordWrap; font.family: "Rubik"; font.pixelSize: 15; lineHeight: 1.15
    }
}
