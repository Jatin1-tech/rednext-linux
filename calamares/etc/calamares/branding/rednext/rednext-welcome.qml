/* RedNext welcome page (welcomeq): big wallpaper preview on the left, info card
   + language card on the right, laid out like the screenshot popup. */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#070707"
    readonly property bool ok: config.requirementsModel.satisfiedMandatory

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // hero preview
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            RnImage { anchors.fill: parent; source: "hero.jpg" }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: parent.height * 0.45; radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00070707" }
                    GradientStop { position: 1.0; color: "#E6070707" }
                }
            }
            ColumnLayout {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 26
                spacing: 4
                Image { source: "logo.png"; Layout.preferredWidth: 58; Layout.preferredHeight: 58; sourceSize.width: 116; smooth: true; mipmap: true }
                Text { Layout.fillWidth: true; text: "RedNext Linux"; color: "#FFFFFF"; font.family: "Rubik"; font.pixelSize: 34; font.weight: Font.Medium; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: "Built from source. Hyprland + Caelestia and KDE Plasma."; wrapMode: Text.WordWrap; color: "#D9D4D4"; font.family: "Rubik"; font.pixelSize: 15 }
                Flow {
                    Layout.fillWidth: true; Layout.topMargin: 8; spacing: 8
                    Repeater {
                        model: [ ["new_releases", "2026.10"], ["memory", "x86-64"], ["bolt", "Linux 6.18 LTS"] ]
                        Rectangle {
                            height: 28; radius: 14; width: r.implicitWidth + 22; color: "#B3131313"; border.color: "#33FFFFFF"
                            Row {
                                id: r; anchors.centerIn: parent; spacing: 5
                                Text { text: modelData[0]; color: "#D42A3C"; font.family: "Material Symbols Rounded"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData[1]; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }
        }

        // right column
        ColumnLayout {
            Layout.preferredWidth: 360; Layout.maximumWidth: 360; Layout.fillHeight: true
            spacing: 12

            RnCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; anchors.topMargin: 26
                    spacing: 10
                    RnHeader {
                        Layout.fillWidth: true
                        icon: "install_desktop"; title: "Install RedNext"
                        subtitle: page.ok ? "This PC is ready" : "This PC can't install RedNext yet"
                    }
                    Repeater {
                        model: config.requirementsModel
                        RnRow {
                            Layout.fillWidth: true
                            icon: satisfied ? "check_circle" : (mandatory ? "error" : "warning")
                            text: { var t = satisfied ? details : negatedText; return t.charAt(0).toUpperCase() + t.slice(1) }
                            textColor: satisfied ? "#EDEAEA" : (mandatory ? "#F0A0AA" : "#F6C27A")
                        }
                    }
                    RnRow { Layout.fillWidth: true; icon: "schedule"; text: "Takes about 10 minutes" }
                    RnRow { Layout.fillWidth: true; icon: "hard_drive"; text: "Needs 20 GB of disk space" }
                    Item { Layout.fillHeight: true }
                }
            }

            // language card
            RnCard {
                Layout.fillWidth: true
                implicitHeight: 104
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 16
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Text { text: "translate"; color: "#D42A3C"; font.family: "Material Symbols Rounded"; font.pixelSize: 20 }
                        Text { text: "Language"; color: "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 15 }
                    }
                    ComboBox {
                        id: lang
                        Layout.fillWidth: true
                        model: config.languagesModel
                        textRole: "label"
                        currentIndex: config.localeIndex
                        onActivated: config.localeIndex = currentIndex
                        font.family: "Rubik"; font.pixelSize: 14
                        contentItem: Text {
                            leftPadding: 14; text: lang.displayText; color: "#EDEAEA"; font: lang.font
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                        indicator: Text {
                            x: lang.width - width - 12; anchors.verticalCenter: parent.verticalCenter
                            text: "expand_more"; color: "#A0A0A0"; font.family: "Material Symbols Rounded"; font.pixelSize: 20
                        }
                        background: Rectangle {
                            implicitHeight: 40; radius: 20; color: "#0B0B0B"
                            border.color: lang.popup.visible || lang.activeFocus ? "#D42A3C" : "#262626"
                        }
                        delegate: ItemDelegate {
                            width: lang.width - 12
                            highlighted: lang.highlightedIndex === index
                            contentItem: Text { text: model.label; color: highlighted ? "#F0A0AA" : "#EDEAEA"; font.family: "Rubik"; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 10; color: highlighted ? "#300A10" : "transparent" }
                        }
                        popup: Popup {
                            y: -implicitHeight - 6; width: lang.width; implicitHeight: Math.min(contentItem.implicitHeight + 12, 320); padding: 6
                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: lang.popup.visible ? lang.delegateModel : null; currentIndex: lang.highlightedIndex }
                            background: Rectangle { radius: 16; color: "#131313"; border.color: "#2A2A2A" }
                        }
                    }
                }
            }
        }
    }
}
