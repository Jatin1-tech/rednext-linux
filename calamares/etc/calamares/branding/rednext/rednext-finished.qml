/* RedNext finished page (finishedq): preview left, result card right,
   "Restart now" action card like the screenshot popup's "Open in folder". */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#070707"

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            RnImage { anchors.fill: parent; source: "hero.jpg" }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: parent.height * 0.4; radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00070707" }
                    GradientStop { position: 1.0; color: "#E6070707" }
                }
            }
            Text {
                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 26
                text: config.failed ? "Something went wrong" : "Welcome home."
                color: "#FFFFFF"; font.family: "Rubik"; font.pixelSize: 34; font.weight: Font.Medium
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 360; Layout.maximumWidth: 360; Layout.fillHeight: true
            spacing: 12

            RnCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; anchors.topMargin: 26
                    spacing: 12
                    RnHeader {
                        Layout.fillWidth: true
                        icon: config.failed ? "error" : "celebration"
                        title: config.failed ? "Install failed" : "All done!"
                        subtitle: config.failed ? "RedNext was not installed" : "RedNext is installed"
                    }
                    RnRow { visible: !config.failed; Layout.fillWidth: true; icon: "usb"; text: "Remove the USB stick when the screen goes dark" }
                    RnRow { visible: !config.failed; Layout.fillWidth: true; icon: "login"; text: "Log in with the account you just made" }
                    RnRow { visible: !config.failed; Layout.fillWidth: true; icon: "desktop_windows"; text: "Pick Hyprland or Plasma at the login screen" }
                    RnRow { visible: !config.failed; Layout.fillWidth: true; icon: "keyboard_command_key"; text: "Super opens the launcher, Super+L locks" }
                    ScrollView {
                        visible: config.failed
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        Text {
                            width: parent.width
                            text: config.failureMessage + (config.failureDetails ? "<br><br>" + config.failureDetails : "")
                            textFormat: Text.RichText; wrapMode: Text.WordWrap
                            color: "#F0A0AA"; font.family: "Rubik"; font.pixelSize: 13
                        }
                    }
                    Item { Layout.fillHeight: true; visible: !config.failed }
                }
            }

            RnCard {
                Layout.fillWidth: true
                implicitHeight: 72
                visible: !config.failed
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 14
                    Text { Layout.fillWidth: true; text: "Restart now"; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 16 }
                    RnSquareButton { icon: "restart_alt"; onClicked: config.doRestart(true) }
                }
            }
        }
    }

    function onActivate() { }
    function onLeave() { }
}
