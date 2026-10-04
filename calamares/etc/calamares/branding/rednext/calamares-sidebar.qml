/* RedNext installer sidebar: same look as the Caelestia shell / screenshot popup.
   #070707 surface, #131313 card, Rubik text, Material Symbols icons in RedNext red. */
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: side
    color: "#070707"
    anchors.fill: parent

    readonly property color card: "#131313"
    readonly property color primary: "#D42A3C"
    readonly property color mainText: "#EDEAEA"
    readonly property color variant: "#A0A0A0"
    readonly property color primaryContainer: "#300A10"
    readonly property color accentText: "#F0A0AA"
    // icon per page, picked by the step's name (English) so it never shifts if pages change
    function iconFor(name, index) {
        var n = name.toLowerCase()
        var map = [ ["welcome", "waving_hand"], ["location", "public"], ["keyboard", "keyboard"],
                    ["partition", "hard_drive"], ["user", "person"], ["app", "apps"],
                    ["summary", "checklist"], ["install", "download"], ["set up", "download"],
                    ["finish", "celebration"] ]
        for (var i = 0; i < map.length; i++)
            if (n.indexOf(map[i][0]) >= 0) return map[i][1]
        return "radio_button_unchecked"
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        anchors.rightMargin: 0
        radius: 20
        color: side.card

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                width: 64; height: 64
                sourceSize.width: 64; sourceSize.height: 64
                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                source: "file:/" + Branding.imagePath(Branding.ProductLogo)
                smooth: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                text: "RedNext"
                color: side.mainText
                font.family: "Rubik"; font.pixelSize: 19; font.weight: Font.Medium
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 14
                text: "Installer"
                color: side.primary
                font.family: "Rubik"; font.pixelSize: 13
            }

            Repeater {
                id: steps
                model: ViewManager
                Rectangle {
                    id: row
                    readonly property bool current: index === ViewManager.currentStepIndex
                    readonly property bool done: index < ViewManager.currentStepIndex
                    Layout.fillWidth: true
                    height: 38
                    radius: 19
                    color: current ? side.primaryContainer : "transparent"
                    Behavior on color { ColorAnimation { duration: 220 } }

                    Text {
                        id: ic
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.done ? "check_circle" : side.iconFor(display, index)
                        color: row.current || row.done ? side.primary : side.variant
                        font.family: "Material Symbols Rounded"; font.pixelSize: 19
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                    Text {
                        anchors.left: ic.right; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: display
                        elide: Text.ElideRight
                        color: row.current ? side.accentText : (row.done ? side.mainText : side.variant)
                        font.family: "Rubik"; font.pixelSize: 14
                        font.weight: row.current ? Font.Medium : Font.Normal
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // progress: "Step 3 of 9" + thin bar
            Text {
                Layout.leftMargin: 6
                text: "Step " + (ViewManager.currentStepIndex + 1) + " of " + steps.count
                color: side.variant
                font.family: "Rubik"; font.pixelSize: 11
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 6; Layout.rightMargin: 6; Layout.bottomMargin: 6
                height: 4; radius: 2
                color: "#3A3A3A"
                Rectangle {
                    height: parent.height; radius: 2
                    color: side.primary
                    width: steps.count > 0 ? parent.width * (ViewManager.currentStepIndex + 1) / steps.count : 0
                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: debug && debug.enabled ? [ ["info", "About"], ["bug_report", "Debug"] ] : [ ["info", "About"] ]
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30; radius: 15
                        color: ma.containsMouse ? Qt.rgba(0.93, 0.92, 0.92, 0.08) : "transparent"
                        Row {
                            anchors.centerIn: parent; spacing: 5
                            Text { text: modelData[0]; color: side.variant; font.family: "Material Symbols Rounded"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData[1]; color: side.variant; font.family: "Rubik"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: index === 0 ? debug.about() : debug.toggle()
                        }
                    }
                }
            }
        }
    }
}
