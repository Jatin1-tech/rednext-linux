/* RedNext installer bottom bar: a card like the screenshot popup's action card.
   Cancel and Back as ghost pills, Next as label + red rounded-square button. */
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: nav
    color: "#070707"
    height: 64

    component Ghost: Rectangle {
        id: g
        property string label
        property string icon
        property color fg: "#EDEAEA"
        property color hoverFill: Qt.rgba(0.93, 0.92, 0.92, 0.08)
        signal clicked()
        implicitWidth: row.implicitWidth + 32; height: 40; radius: 20
        opacity: enabled ? 1 : 0.35
        color: ma.containsMouse && enabled ? hoverFill : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: row; anchors.centerIn: parent; spacing: 6
            Text { text: g.icon; color: g.fg; font.family: "Material Symbols Rounded"; font.pixelSize: 19; anchors.verticalCenter: parent.verticalCenter }
            Text { text: g.label.replace("&", ""); color: g.fg; font.family: "Rubik"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: g.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (g.enabled) g.clicked() }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 6; anchors.bottomMargin: 6
        radius: 16
        color: "#131313"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 6
            spacing: 6

            Ghost {
                label: ViewManager.quitLabel; icon: "close"
                fg: "#F0A0AA"; hoverFill: "#300A10"
                enabled: ViewManager.quitEnabled; visible: ViewManager.quitVisible
                onClicked: ViewManager.quit()
            }
            Item { Layout.fillWidth: true }
            Ghost {
                label: ViewManager.backLabel; icon: "arrow_back"
                enabled: ViewManager.backEnabled; visible: ViewManager.backAndNextVisible
                onClicked: ViewManager.back()
            }
            // Next: label + red rounded-square chevron, clickable as one
            Rectangle {
                id: next
                visible: ViewManager.backAndNextVisible
                enabled: ViewManager.nextEnabled
                opacity: enabled ? 1 : 0.4
                implicitWidth: nl.implicitWidth + 64; height: 40; radius: 12
                color: nm.containsMouse && enabled ? Qt.rgba(0.93, 0.92, 0.92, 0.06) : "transparent"
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Text {
                    id: nl; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: ViewManager.nextLabel.replace("&", ""); color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 15; font.weight: Font.Medium
                }
                RnSquareButton {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40
                    icon: ViewManager.nextLabel.indexOf("Install") >= 0 ? "download" : "chevron_right"
                    enabled: next.enabled
                    onClicked: ViewManager.next()
                }
                MouseArea { id: nm; anchors.fill: parent; anchors.rightMargin: 44; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (next.enabled) ViewManager.next() }
            }
        }
    }
}
