/* RedNext users page (usersq): account card + password card, popup style. */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#070707"

    function initials(n) {
        var p = n.trim().split(/\s+/).filter(function(s) { return s.length > 0 })
        if (p.length === 0) return ""
        return (p[0][0] + (p.length > 1 ? p[p.length - 1][0] : "")).toUpperCase()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // account
        RnCard {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 22
                spacing: 14

                // avatar with live initials
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6
                    width: 84; height: 84; radius: 42
                    color: "#300A10"; border.color: "#D42A3C"; border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: page.initials(config.fullName) || "person"
                        font.family: page.initials(config.fullName) ? "Rubik" : "Material Symbols Rounded"
                        font.pixelSize: page.initials(config.fullName) ? 32 : 40; font.weight: Font.Medium
                        color: "#F0A0AA"
                    }
                }
                RnHeader {
                    Layout.fillWidth: true
                    icon: ""; title: config.fullName !== "" ? config.fullName : "Who's using this PC?"
                    subtitle: config.loginName !== "" ? "@" + config.loginName + " on " + (config.hostname || "rednext") : "Your account gets administrator (sudo) rights"
                }
                RnField {
                    id: nameField
                    Layout.fillWidth: true
                    label: "Your name"; icon: "badge"; placeholder: "e.g. Alex Doe"
                    text: config.fullName
                    onEdited: (v) => config.fullName = v
                }
                RnField {
                    Layout.fillWidth: true
                    label: "Login name"; icon: "alternate_email"; placeholder: "alex"
                    text: config.loginName; status: config.loginNameStatus
                    onEdited: (v) => config.loginName = v
                }
                RnField {
                    Layout.fillWidth: true
                    label: "Computer name"; icon: "computer"; placeholder: "rednext-pc"
                    text: config.hostname; status: config.hostnameStatus
                    onEdited: (v) => config.hostname = v
                }
                Item { Layout.fillHeight: true }
            }
        }

        // password
        ColumnLayout {
            Layout.preferredWidth: 360; Layout.maximumWidth: 360; Layout.fillHeight: true
            spacing: 12

            RnCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 22; anchors.topMargin: 28
                    spacing: 14
                    RnHeader {
                        Layout.fillWidth: true
                        icon: "lock"; title: "Password"
                        subtitle: "Used to log in and for sudo"
                    }
                    RnField {
                        id: pw
                        Layout.fillWidth: true
                        label: "Password"; icon: "key"; echoMode: TextInput.Password; revealable: true
                        text: config.userPassword
                        onEdited: (v) => config.userPassword = v
                    }
                    RnField {
                        Layout.fillWidth: true
                        label: "Repeat password"; icon: "key"; echoMode: TextInput.Password; revealable: true
                        text: config.userPasswordSecondary
                        onEdited: (v) => config.userPasswordSecondary = v
                    }
                    // strength meter: length + character variety (a guide only; any password works)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: config.userPassword !== ""
                        spacing: 6
                        property int score: {
                            var p = config.userPassword, n = 0
                            if (p.length >= 6) n++
                            if (p.length >= 10) n++
                            if (/[a-z]/.test(p) && /[A-Z]/.test(p)) n++
                            if (/[0-9]/.test(p) && /[^A-Za-z0-9]/.test(p)) n++
                            return Math.max(1, n)
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: 4
                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3
                                    color: index < parent.parent.score ? ["#8E1424", "#B81D30", "#D42A3C", "#E24253"][parent.parent.score - 1] : "#262626"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }
                        Text {
                            text: ["Weak", "Okay", "Good", "Strong"][parent.score - 1] + " password"
                            color: "#A0A0A0"; font.family: "Rubik"; font.pixelSize: 12
                        }
                    }
                    RnRow {
                        Layout.fillWidth: true
                        visible: config.userPassword !== "" || config.userPasswordSecondary !== ""
                        // 0 valid, 1 weak but allowed, 2 invalid
                        icon: config.userPasswordValidity === 0 ? "verified_user" : (config.userPasswordValidity === 1 ? "shield" : "gpp_bad")
                        iconColor: config.userPasswordValidity === 2 ? "#E24253" : "#D42A3C"
                        text: config.userPasswordMessage !== "" ? config.userPasswordMessage
                              : (config.userPasswordValidity === 0 ? "Passwords match" : "")
                        textColor: config.userPasswordValidity === 2 ? "#F0A0AA" : "#EDEAEA"
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // what is still missing before Next turns on
            RnCard {
                Layout.fillWidth: true
                implicitHeight: todo.implicitHeight + 32
                ColumnLayout {
                    id: todo
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16; leftMargin: 20 }
                    spacing: 7
                    Text {
                        text: config.ready ? "All set, press Next" : "To continue"
                        color: config.ready ? "#D42A3C" : "#A0A0A0"; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Repeater {
                        model: [
                            ["Your name", config.fullName !== ""],
                            ["Login name", config.loginName !== "" && config.loginNameStatus === ""],
                            ["Computer name", config.hostname !== "" && config.hostnameStatus === ""],
                            ["Password typed twice", config.userPassword !== "" && config.userPasswordValidity !== 2]
                        ]
                        RowLayout {
                            spacing: 10
                            Text {
                                text: modelData[1] ? "check_circle" : "radio_button_unchecked"
                                color: modelData[1] ? "#D42A3C" : "#5E5E5E"
                                font.family: "Material Symbols Rounded"; font.pixelSize: 18
                            }
                            Text { text: modelData[0]; color: modelData[1] ? "#EDEAEA" : "#8A8A8A"; font.family: "Rubik"; font.pixelSize: 14 }
                        }
                    }
                    Text {
                        Layout.topMargin: 2
                        text: "The root account stays locked; you use sudo."
                        color: "#6E6E6E"; font.family: "Rubik"; font.pixelSize: 11
                    }
                }
            }
        }
    }

    // Calamares calls this when the page opens: put the cursor in the first field
    function onActivate() { nameField.focusInput() }
    function onLeave() { }
}
