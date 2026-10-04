/* RedNext install slideshow: Caelestia-style cards while files are copied. */
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Rectangle { anchors.fill: parent; color: "#070707"; z: -1 }

    Timer {
        interval: 7000; repeat: true
        running: presentation.activatedInCalamares
        onTriggered: presentation.goToNextSlide()
    }

    component Card: Slide {
        id: slide
        property string icon
        property string title
        property string body
        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 18
            Image {
                source: "welcome.png"; fillMode: Image.PreserveAspectFit
                width: Math.min(parent.width * 0.55, 480); anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width * 0.8, 620); height: col.implicitHeight + 40
                radius: 20; color: "#131313"
                Column {
                    id: col; anchors.centerIn: parent; width: parent.width - 48; spacing: 10
                    Row {
                        spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            width: 40; height: 40; radius: 12; color: "#D42A3C"
                            Text { anchors.centerIn: parent; text: slide.icon; color: "#F7EDEE"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 }
                        }
                        Text { text: slide.title; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 22; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        width: parent.width; text: slide.body; color: "#A0A0A0"; wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter; font.family: "Rubik"; font.pixelSize: 15; lineHeight: 1.2
                    }
                }
            }
            // page dots
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Repeater {
                    model: presentation.slides.length
                    Rectangle {
                        width: index === presentation.currentSlide ? 22 : 8; height: 8; radius: 4
                        color: index === presentation.currentSlide ? "#D42A3C" : "#3A3A3A"
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
            }
        }
    }

    Card { icon: "rocket_launch"; title: "Welcome to RedNext"; body: "Built from source, one package at a time. Sit back while your new system is copied to disk." }
    Card { icon: "desktop_windows"; title: "Three sessions, one login"; body: "Pick Hyprland with the Caelestia shell, Plasma Wayland or Plasma X11 at the login screen." }
    Card { icon: "palette"; title: "Make it yours"; body: "Caelestia takes its colours from your wallpaper. Super opens the launcher, Super+L locks the screen." }
    Card { icon: "download"; title: "Almost there"; body: "Extra apps you ticked are downloaded at the end, so this step can take a while on a slow connection." }

    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() { }
}
