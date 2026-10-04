// Labelled text input: dark rounded field that glows red when focused
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
ColumnLayout {
    id: f
    property alias label: lbl.text
    property alias text: input.text
    property alias placeholder: input.placeholderText
    property alias echoMode: input.echoMode
    property string icon
    property string status       // error/info line under the field
    property bool revealable: false   // eye button to show/hide a password
    signal edited(string value)
    function focusInput() { input.forceActiveFocus() }
    spacing: 6
    Text { id: lbl; color: "#A0A0A0"; font.family: "Rubik"; font.pixelSize: 13 }
    TextField {
        id: input
        Layout.fillWidth: true
        leftPadding: f.icon !== "" ? 44 : 14; rightPadding: f.revealable ? 44 : 14; topPadding: 11; bottomPadding: 11
        color: "#EDEAEA"; placeholderTextColor: "#5E5E5E"
        selectionColor: "#D42A3C"; selectedTextColor: "#F7EDEE"
        font.family: "Rubik"; font.pixelSize: 15
        onTextEdited: f.edited(text)
        background: Rectangle {
            radius: 14
            color: input.activeFocus ? "#0F0F0F" : "#0B0B0B"
            border.width: 1
            border.color: input.activeFocus ? "#D42A3C" : (f.status !== "" ? "#7A1E28" : "#262626")
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Text {
                visible: f.revealable
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: input.echoMode === TextInput.Password ? "visibility" : "visibility_off"
                color: eye.containsMouse ? "#EDEAEA" : "#7A7A7A"
                font.family: "Material Symbols Rounded"; font.pixelSize: 19
                MouseArea {
                    id: eye; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: input.echoMode = input.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
                }
            }
            Text {
                visible: f.icon !== ""; text: f.icon
                anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                color: input.activeFocus ? "#D42A3C" : "#7A7A7A"
                font.family: "Material Symbols Rounded"; font.pixelSize: 19
            }
        }
    }
    Text {
        Layout.fillWidth: true; visible: f.status !== ""; text: f.status
        color: "#F0A0AA"; wrapMode: Text.WordWrap; font.family: "Rubik"; font.pixelSize: 12
    }
}
