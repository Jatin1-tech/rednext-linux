/* RedNext "Extra apps" page (packagechooserq@apps).
   App-store style tiles: official logo, name, tagline, chips, red toggle.
   The ticked ids go to config.packageChoice as "a,b,c"; the rednextapps job
   downloads them from their official sources at the end of the install. */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#070707"

    property var apps: [
        { id: "blender",  name: "Blender",       maker: "Blender Foundation", logo: "apps/blender.svg",  tag: "3D modelling, sculpting, animation and rendering", cat: "Graphics",    mb: 400 },
        { id: "spotify",  name: "Spotify",       maker: "Spotify AB",         logo: "apps/spotify.png",  tag: "Stream music and podcasts",                        cat: "Music",       mb: 130 },
        { id: "intellij", name: "IntelliJ IDEA", maker: "JetBrains",          logo: "apps/intellij.svg", tag: "Java and Kotlin IDE, with its own Java runtime",   cat: "Development", mb: 1500 },
        { id: "pycharm",  name: "PyCharm",       maker: "JetBrains",          logo: "apps/pycharm.svg",  tag: "Python IDE for scripts, web and data science",     cat: "Development", mb: 1200 },
        { id: "rider",    name: "Rider",         maker: "JetBrains",          logo: "apps/rider.svg",    tag: ".NET and C# IDE, games and Unity included",        cat: "Development", mb: 2300 }
    ]
    property var picked: ({})
    property int count: 0
    property int totalMb: 0

    function size(mb) { return mb >= 1000 ? (mb / 1000).toFixed(1) + " GB" : mb + " MB" }
    function toggle(id) {
        var p = Object.assign({}, picked)
        p[id] = !p[id]
        picked = p
        var ids = [], mb = 0
        for (var i = 0; i < apps.length; i++)
            if (picked[apps[i].id]) { ids.push(apps[i].id); mb += apps[i].mb }
        count = ids.length; totalMb = mb
        config.packageChoice = ids.join(",")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // header card
        RnCard {
            Layout.fillWidth: true
            implicitHeight: hdr.implicitHeight + 36
            RnHeader {
                id: hdr
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                icon: "apps"; title: "Extra apps"
                subtitle: "Optional. Ticked apps are downloaded from their official sources during the install."
            }
        }

        // tiles
        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            contentWidth: availableWidth

            GridLayout {
                width: parent.width
                columns: width > 760 ? 2 : 1
                columnSpacing: 12; rowSpacing: 12

                Repeater {
                    model: page.apps
                    Rectangle {
                        id: tile
                        readonly property bool sel: page.picked[modelData.id] === true
                        Layout.fillWidth: true
                        implicitHeight: 112
                        radius: 20
                        color: sel ? "#1E0C10" : (ma.containsMouse ? "#181818" : "#131313")
                        border.width: sel ? 2 : 1
                        border.color: sel ? "#D42A3C" : "#1C1C1C"
                        scale: ma.pressed ? 0.985 : 1
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                        Behavior on scale { NumberAnimation { duration: 110 } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 16

                            Rectangle {
                                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                                radius: 18; color: "#0B0B0B"; border.color: "#222222"
                                Image {
                                    anchors.centerIn: parent; width: 48; height: 48
                                    source: modelData.logo; sourceSize.width: 96; sourceSize.height: 96
                                    fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                RowLayout {
                                    spacing: 8
                                    Text { text: modelData.name; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 17; font.weight: Font.Medium }
                                    Text { text: modelData.maker; color: "#7A7A7A"; font.family: "Rubik"; font.pixelSize: 12; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 2 }
                                }
                                Text {
                                    Layout.fillWidth: true; text: modelData.tag; elide: Text.ElideRight
                                    color: "#A0A0A0"; font.family: "Rubik"; font.pixelSize: 13
                                }
                                Row {
                                    Layout.topMargin: 5; spacing: 6
                                    Repeater {
                                        model: [ ["category", modelData.cat], ["download", page.size(modelData.mb)] ]
                                        Rectangle {
                                            height: 24; radius: 12; width: chip.implicitWidth + 20
                                            color: tile.sel ? "#300A10" : "#1C1C1C"
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                            Row {
                                                id: chip; anchors.centerIn: parent; spacing: 4
                                                Text { text: modelData[0]; color: "#D42A3C"; font.family: "Material Symbols Rounded"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                                Text { text: modelData[1]; color: "#CFCACA"; font.family: "Rubik"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                            }
                                        }
                                    }
                                }
                            }
                            // toggle switch
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 46; height: 26; radius: 13
                                color: tile.sel ? "#D42A3C" : "#2A2A2A"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Rectangle {
                                    width: 20; height: 20; radius: 10; y: 3
                                    x: tile.sel ? parent.width - width - 3 : 3
                                    color: tile.sel ? "#F7EDEE" : "#8A8A8A"
                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Text {
                                        anchors.centerIn: parent; visible: tile.sel; text: "check"
                                        color: "#D42A3C"; font.family: "Material Symbols Rounded"; font.pixelSize: 14
                                    }
                                }
                            }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.toggle(modelData.id) }
                    }
                }
            }
        }

        // footer card: what will be downloaded
        RnCard {
            Layout.fillWidth: true
            implicitHeight: 64
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                spacing: 14
                Text { text: page.count ? "download" : "check_circle"; color: "#D42A3C"; font.family: "Material Symbols Rounded"; font.pixelSize: 22 }
                Text {
                    Layout.fillWidth: true
                    text: page.count === 0 ? "No extra apps: RedNext is complete without them."
                                           : page.count + (page.count === 1 ? " app" : " apps") + " selected · about " + page.size(page.totalMb) + " to download"
                    color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 15
                }
                Text { visible: page.count > 0; text: "Needs internet"; color: "#D42A3C"; font.family: "Rubik"; font.pixelSize: 13 }
            }
        }
    }
}
