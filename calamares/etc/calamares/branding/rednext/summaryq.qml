/* RedNext summary page (summaryq): one card per step, popup-style rows. */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#070707"

    function iconFor(t) {
        t = t.toLowerCase()
        if (t.indexOf("locat") >= 0 || t.indexOf("time") >= 0) return "public"
        if (t.indexOf("keyboard") >= 0) return "keyboard"
        if (t.indexOf("partition") >= 0 || t.indexOf("disk") >= 0) return "hard_drive"
        if (t.indexOf("user") >= 0) return "person"
        if (t.indexOf("app") >= 0 || t.indexOf("package") >= 0) return "apps"
        return "check_circle"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RnCard {
            Layout.fillWidth: true
            implicitHeight: hdr.implicitHeight + 36
            RnHeader {
                id: hdr
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                icon: "checklist"; title: "Ready to install"
                subtitle: "Check everything below. Nothing is written to disk until you press Install."
            }
        }

        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 12
            model: config.summaryModel
            ScrollBar.vertical: ScrollBar {
                visible: size < 1.0
                contentItem: Rectangle { implicitWidth: 6; radius: 3; color: "#3A3A3A" }
            }
            delegate: RnCard {
                width: ListView.view.width - 10
                implicitHeight: body.implicitHeight + 36
                RowLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 16
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 44; height: 44; radius: 12; color: "#300A10"
                        Text { anchors.centerIn: parent; text: page.iconFor(model.title); color: "#D42A3C"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 6
                        Text { text: model.title; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 17; font.weight: Font.Medium }
                        Text {
                            Layout.fillWidth: true
                            text: model.message; textFormat: Text.RichText; wrapMode: Text.WordWrap
                            color: "#BDB8B8"; linkColor: "#E24253"; font.family: "Rubik"; font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
