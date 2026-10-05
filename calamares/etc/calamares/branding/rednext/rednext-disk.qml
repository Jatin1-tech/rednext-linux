/* RedNext "Disk" page (rednextdisk module).
   Fedora-style flow: pick a disk tile, pick how to use it, see the exact result.
   All logic lives in /usr/libexec/rednext/rednext-disk; this page only builds a
   request, shows the engine's plan (to-scale bars + readable list + steps), and
   enables Next when the plan is valid. Nothing is written until Install. */
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#070707"

    readonly property real gib: 1073741824
    readonly property color red: "#D42A3C"
    readonly property color text1: "#EDEAEA"
    readonly property color text2: "#A0A0A0"
    readonly property color text3: "#6E6E6E"
    readonly property color amber: "#E8B04A"

    property var info: null            // rednext-disk probe
    property int diskIndex: -1
    property string mode: "erase"      // erase | free | manual
    property bool eraseOk: false
    property bool swapFile: false
    property string fs: "ext4"
    property int region: -1
    property real rootGiB: 0           // free mode: 0 = all of the region
    property var manual: ({ "delete": [], "use": [], "create": [] })
    property var result: null          // rednext-disk plan
    property string probeError: ""

    readonly property var disk: info && diskIndex >= 0 && diskIndex < info.disks.length ? info.disks[diskIndex] : null
    readonly property bool efi: info ? info.firmware === "efi" : true

    // ---------------------------------------------------------------- helpers
    function size(b) {
        if (b === undefined || b === null) return ""
        var u = ["B", "KiB", "MiB", "GiB", "TiB"], i = 0, n = b
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        return (i < 2 || n >= 100 || n === Math.floor(n) ? Math.round(n) : n.toFixed(1)) + " " + u[i]
    }
    function shortName(p) { return p ? p.replace("/dev/", "") : "" }
    function fsName(f) {
        return ({ "vfat": "FAT32", "ntfs": "NTFS", "ext4": "ext4", "swap": "swap", "biosgrub": "BIOS boot",
                  "btrfs": "Btrfs", "xfs": "XFS", "exfat": "exFAT", "": "unformatted" })[f] || f
    }
    function diskIcon(d) { return d.transport === "usb" || d.removable ? "usb" : (d.transport === "nvme" ? "memory" : "hard_drive") }
    function segColor(s) {
        if (s.kind === "free") return "#101010"
        if (s.kind === "new" || s.kind === "format") {
            if (s.mountPoint === "/boot/efi" || s.fs === "biosgrub") return "#8E1B28"
            if (s.fs === "swap") return "#6B2531"
            if (s.mountPoint === "/") return red
            return "#B5303F"
        }
        if (s.kind === "use") return "#5A2A31"
        if (s.fs === "ntfs" || s.fs === "bitlocker") return "#2C4361"
        if (s.fs === "vfat") return "#3B3B3B"
        if (s.fs === "ext4" || s.fs === "btrfs" || s.fs === "xfs") return "#46464A"
        return "#2E2E2E"
    }
    function segTitle(s) {
        if (s.kind === "free") return "Free"
        if (s.mountPoint === "/") return "RedNext"
        if (s.mountPoint === "/boot/efi") return "EFI"
        if (s.fs === "biosgrub") return "BIOS boot"
        if (s.mountPoint) return s.mountPoint
        return s.label || fsName(s.fs)
    }
    function deleted(n) {
        if (!result || !result.ok && !result.after) return false
        if (mode === "erase") return true
        return (result.deletes || []).indexOf(n) >= 0
    }
    function formatted(n) {
        var m = result && result.mounts ? result.mounts : []
        for (var i = 0; i < m.length; i++) if (!m[i].new && m[i].number === n && m[i].format) return true
        return false
    }

    // ---------------------------------------------------------------- engine
    function onActivate() { refresh() }

    function refresh() {
        var txt = config.probe(), r = null
        try { r = JSON.parse(txt) } catch (e) { r = null }
        if (!r || r.fatal) {
            info = null; probeError = r && r.errors ? r.errors.join(" ") : "The disk engine did not answer."
            result = null; config.clear(); return
        }
        probeError = ""
        var oldPath = disk ? disk.path : ""
        info = r
        if (info.filesystems.indexOf(fs) < 0) fs = info.filesystems[0]
        var pick = -1
        for (var i = 0; i < info.disks.length; i++)
            if (info.disks[i].path === oldPath && info.disks[i].usable) pick = i
        if (pick < 0)   // first usable internal disk, else any usable one
            for (i = 0; i < info.disks.length && pick < 0; i++)
                if (info.disks[i].usable && !info.disks[i].removable) pick = i
        for (i = 0; i < info.disks.length && pick < 0; i++)
            if (info.disks[i].usable) pick = i
        selectDisk(pick, oldPath !== "" && pick >= 0 && info.disks[pick].path === oldPath)
    }

    function selectDisk(i, keepMode) {
        diskIndex = i
        eraseOk = false; region = -1; rootGiB = 0
        if (!keepMode && disk) {
            var empty = disk.partitions.length === 0
            mode = (!empty && disk.largestFree >= info.minRoot) ? "free" : "erase"
            if (empty) eraseOk = true
        }
        resetManual()
        replan()
    }

    function setMode(m) {
        if (mode === m) return
        mode = m
        eraseOk = disk && disk.partitions.length === 0
        replan()
    }

    function resetManual() {
        var use = []
        if (disk && efi)
            for (var i = 0; i < disk.partitions.length; i++)
                if (disk.partitions[i].esp) { use.push({ number: disk.partitions[i].number, mountPoint: "/boot/efi", format: false }); break }
        manual = { "delete": [], "use": use, "create": [] }
    }

    function replan() { planTimer.restart() }
    Timer { id: planTimer; interval: 90; onTriggered: page.doPlan() }

    function doPlan() {
        if (!disk) { result = null; config.clear(); return }
        var req = { mode: mode, disk: disk.path, fs: fs, swap: swapFile ? "file" : "none" }
        if (mode === "free") {
            if (region >= 0) req.region = region
            if (rootGiB > 0) req.rootSize = Math.round(rootGiB * gib)
        }
        if (mode === "manual") req.manual = manual
        var txt = config.plan(JSON.stringify(req)), r
        try { r = JSON.parse(txt) } catch (e) { r = { ok: false, fatal: true, errors: ["The disk engine gave no answer."] } }
        result = r
        if (r.ok && (mode !== "erase" || eraseOk)) config.accept(txt)
        else config.clear()
    }

    // ---------------------------------------------------------------- custom-mode edits
    function useOf(n) {
        for (var i = 0; i < manual.use.length; i++) if (manual.use[i].number === n) return manual.use[i]
        return null
    }
    function setUse(n, mp, format) {
        var m = JSON.parse(JSON.stringify(manual))
        m.use = m.use.filter(function (u) { return u.number !== n })
        if (mp !== "") m.use.push({ number: n, mountPoint: mp, format: format })
        manual = m; replan()
    }
    function toggleDelete(n) {
        var m = JSON.parse(JSON.stringify(manual))
        var i = m["delete"].indexOf(n)
        if (i >= 0) m["delete"].splice(i, 1)
        else { m["delete"].push(n); m.use = m.use.filter(function (u) { return u.number !== n }) }
        manual = m; replan()
    }
    function addCreate(gibs, mp) {
        var m = JSON.parse(JSON.stringify(manual))
        m.create.push({ size: gibs > 0 ? Math.round(gibs * gib) : 0, mountPoint: mp })
        manual = m; replan()
    }
    function removeCreate(i) {
        var m = JSON.parse(JSON.stringify(manual))
        m.create.splice(i, 1)
        manual = m; replan()
    }

    // ---------------------------------------------------------------- small components
    component Icon: Text {
        font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: page.red
    }
    component Label2: Text {
        font.family: "Rubik"; font.pixelSize: 14; color: page.text1; wrapMode: Text.WordWrap
    }
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled()
        width: 46; height: 26; radius: 13
        color: on ? page.red : "#2A2A2A"
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: 20; height: 20; radius: 10; y: 3
            x: tg.on ? parent.width - width - 3 : 3
            color: tg.on ? "#F7EDEE" : "#8A8A8A"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }
    component Pill: Rectangle {
        id: pl
        property string icon
        property string label
        property bool active: false
        property bool dim: false
        signal clicked()
        height: 38; radius: 19
        implicitWidth: plRow.implicitWidth + 32
        color: active ? "#300A10" : (plMa.containsMouse && !dim ? "#1A1A1A" : "#131313")
        border.width: 1; border.color: active ? page.red : "#222222"
        opacity: dim ? 0.45 : 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Row {
            id: plRow; anchors.centerIn: parent; spacing: 8
            Icon { text: pl.icon; font.pixelSize: 18; color: pl.active ? page.red : page.text2; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pl.label; color: pl.active ? page.text1 : "#CFCACA"; font.family: "Rubik"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; cursorShape: pl.dim ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: if (!pl.dim) pl.clicked() }
    }
    component MiniButton: Rectangle {
        id: mb
        property string icon
        property string label
        property bool danger: false
        property bool active: false
        signal clicked()
        height: 30; radius: 10
        implicitWidth: mbRow.implicitWidth + 20
        color: active ? (danger ? "#4A121A" : "#300A10") : (mbMa.containsMouse ? "#222222" : "#1A1A1A")
        border.width: 1; border.color: active ? page.red : "#262626"
        Row {
            id: mbRow; anchors.centerIn: parent; spacing: 5
            Icon { text: mb.icon; font.pixelSize: 16; color: mb.danger || mb.active ? page.red : page.text2; anchors.verticalCenter: parent.verticalCenter; visible: mb.icon !== "" }
            Text { text: mb.label; color: page.text1; font.family: "Rubik"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; visible: mb.label !== "" }
        }
        MouseArea { id: mbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mb.clicked() }
    }
    component MountCombo: ComboBox {
        id: cb
        property string value: ""
        signal picked(string v)
        readonly property var choices: ["", "/", "/boot/efi", "/home", "/boot", "/var", "/opt", "/srv", "swap"]
        model: choices.map(function (c) { return c === "" ? "Not used" : (c === "swap" ? "swap" : c) })
        currentIndex: Math.max(0, choices.indexOf(value))
        onActivated: function (i) { cb.picked(cb.choices[i]) }
        implicitWidth: 130; implicitHeight: 30
        font.family: "Rubik"; font.pixelSize: 12
        background: Rectangle { radius: 10; color: cb.hovered ? "#222222" : "#1A1A1A"; border.color: cb.value !== "" ? page.red : "#262626" }
        contentItem: Text {
            leftPadding: 10; text: cb.displayText; verticalAlignment: Text.AlignVCenter
            color: cb.value !== "" ? page.text1 : page.text2; font: cb.font; elide: Text.ElideRight
        }
        indicator: Icon { text: "expand_more"; font.pixelSize: 16; color: page.text2; x: cb.width - width - 6; anchors.verticalCenter: parent.verticalCenter }
        popup.background: Rectangle { radius: 10; color: "#1A1A1A"; border.color: "#2A2A2A" }
        delegate: ItemDelegate {
            width: cb.width; height: 30
            contentItem: Text { text: modelData; color: page.text1; font.family: "Rubik"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: highlighted ? "#300A10" : "transparent"; radius: 8 }
            highlighted: cb.highlightedIndex === index
        }
    }

    // to-scale disk bar: tiny segments get a minimum width, the rest is scaled to fit
    component DiskBar: Item {
        id: bar
        property var segs: []
        property real total: 1
        property bool before: false
        implicitHeight: 42
        readonly property var widths: {
            var w = [], sum = 0, W = Math.max(1, width - Math.max(0, segs.length - 1) * 3)
            for (var i = 0; i < segs.length; i++) { var x = Math.max(8, segs[i].size / total * W); w.push(x); sum += x }
            return w.map(function (x) { return x * W / Math.max(1, sum) })
        }
        Row {
            anchors.fill: parent; spacing: 3
            Repeater {
                model: bar.segs
                Rectangle {
                    readonly property bool gone: bar.before && modelData.kind !== "free" && (page.deleted(modelData.number) || page.formatted(modelData.number))
                    width: bar.widths[index] || 8; height: bar.height; radius: 10
                    color: page.segColor(modelData)
                    border.width: modelData.kind === "free" ? 1 : (modelData.kind === "use" ? 2 : 0)
                    border.color: modelData.kind === "use" ? page.red : "#2A2A2A"
                    clip: true
                    Rectangle {      // erased in the "now" bar: red veil + icon
                        anchors.fill: parent; radius: 10; visible: parent.gone
                        color: "#B0280E14"; border.width: 2; border.color: page.red
                        Icon { anchors.centerIn: parent; text: "delete"; font.pixelSize: 18; visible: parent.width > 26 && parent.parent.width <= 80 }
                    }
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter
                        visible: parent.width > 80; spacing: 0
                        Text { text: page.segTitle(modelData); color: modelData.kind === "free" ? page.text3 : "#F4F0F0"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; width: parent.parent.width - 14; elide: Text.ElideRight }
                        Text { text: page.size(modelData.size); color: modelData.kind === "free" ? page.text3 : "#E0D6D7"; font.family: "Rubik"; font.pixelSize: 11; width: parent.parent.width - 14; elide: Text.ElideRight }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // header
        RnCard {
            Layout.fillWidth: true; implicitHeight: 66
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 12; spacing: 14
                Icon { text: "hard_drive"; font.pixelSize: 26 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: "Where should RedNext go?"; color: page.text1; font.family: "Rubik"; font.pixelSize: 19; font.weight: Font.Medium }
                    Text { text: "Pick a disk and how to use it. Nothing is written until you press Install."; color: page.red; font.family: "Rubik"; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Text { text: page.efi ? "UEFI" : "BIOS"; color: page.text2; font.family: "Rubik"; font.pixelSize: 12 }
                MiniButton { icon: "refresh"; label: "Refresh"; onClicked: page.refresh() }
            }
        }

        // disk tiles
        ListView {
            id: tiles
            Layout.fillWidth: true; Layout.preferredHeight: 76
            orientation: ListView.Horizontal; spacing: 10; clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: page.info ? page.info.disks : []
            delegate: Rectangle {
                readonly property bool sel: index === page.diskIndex
                width: 232; height: 76; radius: 18
                color: !modelData.usable ? "#0E0E0E" : (sel ? "#1E0C10" : (tMa.containsMouse ? "#181818" : "#131313"))
                border.width: sel ? 2 : 1; border.color: sel ? page.red : "#1C1C1C"
                opacity: modelData.usable ? 1 : 0.55
                Behavior on color { ColorAnimation { duration: 160 } }
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 12; color: sel ? "#300A10" : "#0B0B0B"
                        Icon { anchors.centerIn: parent; text: page.diskIcon(modelData); font.pixelSize: 24; color: modelData.usable ? page.red : page.text3 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { Layout.fillWidth: true; text: modelData.model; color: page.text1; font.family: "Rubik"; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideRight }
                        Text { text: page.size(modelData.size) + " · " + page.shortName(modelData.path); color: page.text2; font.family: "Rubik"; font.pixelSize: 12 }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight; font.family: "Rubik"; font.pixelSize: 11
                            color: modelData.usable ? (modelData.largestFree >= page.info.minRoot ? "#8FD19E" : page.text3) : page.amber
                            text: !modelData.usable ? (modelData.liveMedium ? "Live USB: can't install here" : modelData.why)
                                  : (modelData.partitions.length === 0 ? "Empty disk"
                                  : modelData.largestFree >= page.info.minRoot ? page.size(modelData.largestFree) + " free space"
                                  : modelData.partitions.length + " partitions, no free space")
                        }
                    }
                }
                MouseArea {
                    id: tMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: modelData.usable ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: if (modelData.usable && index !== page.diskIndex) page.selectDisk(index, false)
                }
            }
            Text {
                anchors.centerIn: parent; visible: tiles.count === 0
                text: page.probeError !== "" ? page.probeError : "No disks found. Connect a disk and press Refresh."
                color: page.amber; font.family: "Rubik"; font.pixelSize: 14
            }
        }

        // mode pills
        RowLayout {
            Layout.fillWidth: true; spacing: 8; visible: page.disk !== null
            Pill { icon: "delete_sweep"; label: "Use entire disk"; active: page.mode === "erase"; dim: page.disk && !page.disk.canErase; onClicked: page.setMode("erase") }
            Pill { icon: "add_circle"; label: "Use free space"; active: page.mode === "free"; dim: !page.disk || page.disk.free.length === 0 || page.disk.ptType === null || page.disk.ptType === ""; onClicked: page.setMode("free") }
            Pill { icon: "tune"; label: "Custom"; active: page.mode === "manual"; dim: !page.disk || page.disk.ptType === null || page.disk.ptType === ""; onClicked: { page.resetManual(); page.setMode("manual") } }
            Item { Layout.fillWidth: true }
        }

        ScrollView {
            id: sv
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; visible: page.disk !== null
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            contentWidth: availableWidth

            ColumnLayout {
                width: sv.availableWidth
                spacing: 10

                // ---- bars: now / after
                RnCard {
                    Layout.fillWidth: true
                    implicitHeight: barsCol.implicitHeight + 32
                    ColumnLayout {
                        id: barsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; visible: false
                            Item { Layout.fillWidth: true }
                            Text { text: page.disk ? page.disk.model + " · " + page.size(page.disk.size) + " · " + (page.disk.ptType === "dos" ? "MBR" : page.disk.ptType ? page.disk.ptType.toUpperCase() : "no partition table") : ""; color: page.text3; font.family: "Rubik"; font.pixelSize: 12 }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 12
                        Text { Layout.preferredWidth: 46; text: "Now"; color: page.text2; font.family: "Rubik"; font.pixelSize: 12 }
                        DiskBar {
                            Layout.fillWidth: true; before: true
                            segs: page.result && page.result.before ? page.result.before : (page.disk ? [{ kind: "free", start: 0, size: page.disk.size }] : [])
                            total: page.disk ? page.disk.size : 1
                        }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 12
                        Text { Layout.preferredWidth: 46; text: "After"; color: page.red; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium }
                        DiskBar {
                            Layout.fillWidth: true
                            segs: page.result && page.result.after ? page.result.after : []
                            total: page.disk ? page.disk.size : 1
                            Rectangle {
                                anchors.fill: parent; radius: 10; color: "#0B0B0B"; border.color: "#3A1418"
                                visible: !page.result || !page.result.after
                                Text { anchors.centerIn: parent; text: "No valid layout yet"; color: page.text3; font.family: "Rubik"; font.pixelSize: 12 }
                            }
                        }
                        }

                        // readable list of the final layout
                        Repeater {
                            model: page.mode !== "manual" && page.result && page.result.after ? page.result.after.filter(function (s) { return s.kind !== "free" || s.size >= 1073741824 }) : []
                            RowLayout {
                                Layout.fillWidth: true; Layout.preferredHeight: 22; spacing: 10
                                Rectangle { Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 4; color: page.segColor(modelData); border.color: modelData.kind === "use" ? page.red : "#2A2A2A"; border.width: 1 }
                                Text { Layout.preferredWidth: 96; text: modelData.path ? page.shortName(modelData.path) : "—"; color: page.text2; font.family: "Rubik"; font.pixelSize: 13 }
                                Text { Layout.preferredWidth: 82; text: page.size(modelData.size); color: page.text1; font.family: "Rubik"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
                                Text {
                                    Layout.fillWidth: true; elide: Text.ElideRight; font.family: "Rubik"; font.pixelSize: 13; color: page.text1
                                    text: modelData.kind === "free" ? "Free space (left unused)"
                                        : (modelData.mountPoint === "/" ? "RedNext system  /" : modelData.mountPoint === "/boot/efi" ? "EFI boot  /boot/efi"
                                        : modelData.fs === "biosgrub" ? "BIOS boot (for GRUB)" : modelData.mountPoint ? modelData.mountPoint
                                        : (modelData.label || "")) + "  ·  " + page.fsName(modelData.fs)
                                }
                                Rectangle {
                                    Layout.preferredHeight: 22; Layout.preferredWidth: tag.implicitWidth + 16; radius: 11
                                    color: modelData.kind === "new" ? "#300A10" : modelData.kind === "format" ? "#4A121A" : "#1C1C1C"
                                    Text {
                                        id: tag; anchors.centerIn: parent; font.family: "Rubik"; font.pixelSize: 11
                                        color: modelData.kind === "keep" || modelData.kind === "free" ? page.text2 : "#F0A0AA"
                                        text: ({ "new": "new", "format": "formatted", "use": "used as is", "keep": "untouched", "free": "free" })[modelData.kind]
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- mode options
                RnCard {
                    Layout.fillWidth: true
                    implicitHeight: optCol.implicitHeight + 32
                    ColumnLayout {
                        id: optCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 12

                        // erase: confirm
                        RowLayout {
                            visible: page.mode === "erase" && page.disk && page.disk.partitions.length > 0
                            Layout.fillWidth: true; spacing: 14
                            Icon { text: "warning"; color: page.amber; font.pixelSize: 22 }
                            Label2 {
                                Layout.fillWidth: true
                                text: page.disk ? "Everything on <b>" + page.disk.model + "</b> (" + page.size(page.disk.size) + ") is erased: "
                                      + page.disk.partitions.map(function (p) { return page.shortName(p.path) + " " + page.fsName(p.fs) + (p.label ? " “" + p.label + "”" : "") + " " + page.size(p.size) }).join(", ") + "." : ""
                                textFormat: Text.StyledText
                            }
                            Text { text: "Erase it"; color: page.text2; font.family: "Rubik"; font.pixelSize: 13 }
                            Toggle { on: page.eraseOk; onToggled: { page.eraseOk = !page.eraseOk; page.replan() } }
                        }
                        RowLayout {
                            visible: page.mode === "erase" && page.disk && page.disk.partitions.length === 0
                            Layout.fillWidth: true; spacing: 14
                            Icon { text: "check_circle"; color: "#8FD19E" }
                            Label2 { Layout.fillWidth: true; text: "The disk is empty: RedNext gets all of it, with an EFI partition when the PC boots in UEFI mode." }
                        }

                        // free: region + size
                        ColumnLayout {
                            visible: page.mode === "free" && page.disk !== null
                            Layout.fillWidth: true; spacing: 10
                            Flow {
                                Layout.fillWidth: true; spacing: 8
                                visible: page.disk && page.disk.free.length > 1
                                Repeater {
                                    model: page.disk ? page.disk.free : []
                                    MiniButton {
                                        icon: "crop_free"; label: "Free space " + (index + 1) + " · " + page.size(modelData.size)
                                        active: page.region === index || (page.region < 0 && modelData.size === page.disk.largestFree)
                                        onClicked: { page.region = index; page.rootGiB = 0; page.replan() }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 14
                                readonly property real regionGiB: {
                                    if (!page.disk || page.disk.free.length === 0) return 0
                                    var r = page.region >= 0 ? page.disk.free[page.region] : page.disk.free.reduce(function (a, b) { return b.size > a.size ? b : a })
                                    return Math.floor(r.size / page.gib)
                                }
                                Icon { text: "straighten" }
                                Text { text: "Size for RedNext"; color: page.text1; font.family: "Rubik"; font.pixelSize: 14 }
                                Slider {
                                    id: sl
                                    Layout.fillWidth: true
                                    from: page.info ? Math.ceil(page.info.minRoot / page.gib) : 20
                                    to: Math.max(from + 1, parent.regionGiB)
                                    stepSize: 1
                                    value: page.rootGiB > 0 ? page.rootGiB : to
                                    enabled: parent.regionGiB > from
                                    onMoved: { page.rootGiB = (value >= to) ? 0 : value; page.replan() }
                                    background: Rectangle {
                                        x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
                                        width: sl.availableWidth; height: 6; radius: 3; color: "#2A2A2A"
                                        Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 3; color: page.red }
                                    }
                                    handle: Rectangle {
                                        x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                                        y: sl.topPadding + sl.availableHeight / 2 - height / 2
                                        width: 22; height: 22; radius: 11; color: "#F7EDEE"; border.color: page.red; border.width: 3
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 150; horizontalAlignment: Text.AlignRight
                                    text: page.result && page.result.rootSize ? page.size(page.result.rootSize) + (page.rootGiB > 0 ? "" : " (all)") : ""
                                    color: page.text1; font.family: "Rubik"; font.pixelSize: 15; font.weight: Font.Medium
                                }
                            }
                            Label2 {
                                Layout.fillWidth: true; color: page.text2; font.pixelSize: 13
                                text: "Your other partitions are not touched." + (page.efi ? " RedNext shares the existing EFI partition, or adds one if there is none." : "")
                            }
                        }

                        // custom: per-partition controls
                        ColumnLayout {
                            visible: page.mode === "manual" && page.disk !== null
                            Layout.fillWidth: true; spacing: 6
                            Label2 { Layout.fillWidth: true; color: page.text2; font.pixelSize: 13; text: "Give each partition a job. / (RedNext) is required" + (page.efi ? ", and /boot/efi (FAT32) because this PC boots in UEFI mode." : ".") }
                            Repeater {
                                model: page.disk ? page.disk.partitions : []
                                Rectangle {
                                    readonly property var u: page.useOf(modelData.number)
                                    readonly property bool del: page.manual["delete"].indexOf(modelData.number) >= 0
                                    Layout.fillWidth: true; implicitHeight: 48; radius: 12
                                    color: del ? "#1E0C10" : "#0E0E0E"; border.color: del ? "#5A1820" : "#1C1C1C"
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                        Rectangle { Layout.preferredWidth: 10; Layout.preferredHeight: 26; radius: 3; color: page.segColor(modelData) }
                                        Text { Layout.preferredWidth: 92; text: page.shortName(modelData.path); color: del ? page.text3 : page.text1; font.family: "Rubik"; font.pixelSize: 13; font.strikeout: del }
                                        Text { Layout.preferredWidth: 74; text: page.size(modelData.size); color: page.text2; font.family: "Rubik"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
                                        Text { Layout.fillWidth: true; text: page.fsName(modelData.fs) + (modelData.label ? " · " + modelData.label : "") + (modelData.mounted.length ? " · in use" : ""); color: page.text2; font.family: "Rubik"; font.pixelSize: 13; elide: Text.ElideRight }
                                        MountCombo {
                                            visible: !parent.parent.del && !modelData.extended
                                            value: parent.parent.u ? parent.parent.u.mountPoint : ""
                                            onPicked: function (v) { page.setUse(modelData.number, v, v === "/" || v === "/boot" || v === "swap" || (v === "/boot/efi" && modelData.fs !== "vfat") ? true : (parent.parent.u ? parent.parent.u.format : false)) }
                                        }
                                        Text { visible: !!parent.parent.u && !parent.parent.del; text: "Format"; color: page.text2; font.family: "Rubik"; font.pixelSize: 12 }
                                        Toggle {
                                            visible: !!parent.parent.u && !parent.parent.del
                                            on: parent.parent.u ? parent.parent.u.format : false
                                            onToggled: page.setUse(modelData.number, parent.parent.u.mountPoint, !parent.parent.u.format)
                                        }
                                        MiniButton {
                                            icon: parent.parent.del ? "undo" : "delete"; danger: !parent.parent.del; active: parent.parent.del
                                            label: parent.parent.del ? "Keep" : ""
                                            visible: !modelData.logical && modelData.mounted.length === 0
                                            onClicked: page.toggleDelete(modelData.number)
                                        }
                                    }
                                }
                            }
                            // new partitions
                            Repeater {
                                model: page.manual.create
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 48; radius: 12; color: "#1E0C10"; border.color: "#5A1820"
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                        Icon { text: "add_circle"; font.pixelSize: 18 }
                                        Text { Layout.preferredWidth: 72; text: "New"; color: page.text1; font.family: "Rubik"; font.pixelSize: 13 }
                                        Text { Layout.preferredWidth: 74; text: modelData.size > 0 ? page.size(modelData.size) : "rest"; color: page.text2; font.family: "Rubik"; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
                                        Text { Layout.fillWidth: true; text: (modelData.mountPoint || "?") + " · " + (modelData.mountPoint === "/boot/efi" ? "FAT32" : modelData.mountPoint === "swap" ? "swap" : page.fs); color: page.text1; font.family: "Rubik"; font.pixelSize: 13 }
                                        MiniButton { icon: "close"; danger: true; onClicked: page.removeCreate(index) }
                                    }
                                }
                            }
                            // add a partition in free space
                            RowLayout {
                                Layout.fillWidth: true; Layout.topMargin: 4; spacing: 10
                                Icon { text: "add"; color: page.text2 }
                                Text { text: "New partition"; color: page.text1; font.family: "Rubik"; font.pixelSize: 13 }
                                TextField {
                                    id: newSize
                                    Layout.preferredWidth: 110; implicitHeight: 30
                                    placeholderText: "all free"; placeholderTextColor: "#5E5E5E"
                                    validator: DoubleValidator { bottom: 0.01; decimals: 2 }
                                    color: page.text1; font.family: "Rubik"; font.pixelSize: 12
                                    leftPadding: 10; rightPadding: 36
                                    background: Rectangle {
                                        radius: 10; color: "#0B0B0B"; border.color: newSize.activeFocus ? page.red : "#262626"
                                        Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "GiB"; color: page.text3; font.family: "Rubik"; font.pixelSize: 11 }
                                    }
                                }
                                MountCombo { id: newMp; value: "/"; onPicked: function (v) { newMp.value = v } }
                                MiniButton {
                                    icon: "add"; label: "Add"; active: true
                                    onClicked: { page.addCreate(parseFloat(newSize.text) || 0, newMp.value); newSize.text = "" }
                                }
                                Item { Layout.fillWidth: true }
                                MiniButton { icon: "restart_alt"; label: "Reset"; onClicked: { page.resetManual(); page.replan() } }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#232323" }

                        // shared options
                        RowLayout {
                            Layout.fillWidth: true; spacing: 14
                            Icon { text: "swap_horiz" }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { text: "Swap file"; color: page.text1; font.family: "Rubik"; font.pixelSize: 14 }
                                Text { text: "Extra memory on disk for heavy apps; sized from your RAM."; color: page.text2; font.family: "Rubik"; font.pixelSize: 12 }
                            }
                            Item { Layout.fillWidth: true }
                            Toggle { on: page.swapFile; onToggled: { page.swapFile = !page.swapFile; page.replan() } }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 14
                            visible: page.info && page.info.filesystems.length > 1
                            Icon { text: "folder_data" }
                            Text { Layout.fillWidth: true; text: "File system for RedNext"; color: page.text1; font.family: "Rubik"; font.pixelSize: 14 }
                            Repeater {
                                model: page.info ? page.info.filesystems : []
                                MiniButton { label: page.fsName(modelData); active: page.fs === modelData; onClicked: { page.fs = modelData; page.replan() } }
                            }
                        }
                    }
                }

                // ---- notes: every error and warning from the engine
                RnCard {
                    Layout.fillWidth: true
                    visible: page.result && ((page.result.errors || []).length + (page.result.warnings || []).length) > 0
                    implicitHeight: noteCol.implicitHeight + 28
                    ColumnLayout {
                        id: noteCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                        spacing: 6
                        Repeater {
                            model: page.result && page.result.errors ? page.result.errors : []
                            RowLayout { Layout.fillWidth: true; spacing: 10
                                Icon { text: "error"; font.pixelSize: 17; Layout.alignment: Qt.AlignTop }
                                Label2 { Layout.fillWidth: true; text: modelData; color: "#F0A0AA"; font.pixelSize: 13 } }
                        }
                        Repeater {
                            model: page.result && page.result.warnings ? page.result.warnings : []
                            RowLayout { Layout.fillWidth: true; spacing: 10
                                Icon { text: "info"; font.pixelSize: 17; color: page.amber; Layout.alignment: Qt.AlignTop }
                                Label2 { Layout.fillWidth: true; text: modelData; color: "#E9D3A6"; font.pixelSize: 13 } }
                        }
                    }
                }

                // ---- what will happen
                RnCard {
                    Layout.fillWidth: true
                    visible: page.result && page.result.ok && page.result.actions && page.result.actions.length > 0
                    implicitHeight: stepCol.implicitHeight + 32
                    ColumnLayout {
                        id: stepCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Icon { text: "format_list_numbered" }
                            Text { Layout.fillWidth: true; text: "What Install will do"; color: page.text1; font.family: "Rubik"; font.pixelSize: 14; font.weight: Font.Medium }
                        }
                        Repeater {
                            model: page.result && page.result.ok && page.result.actions ? page.result.actions : []
                            RowLayout { Layout.fillWidth: true; spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11; color: "#1C1C1C"
                                    Text { anchors.centerIn: parent; text: index + 1; color: page.text2; font.family: "Rubik"; font.pixelSize: 11 }
                                }
                                Label2 {
                                    Layout.fillWidth: true; font.pixelSize: 13; text: modelData.text
                                    color: modelData.kind === "destroy" || modelData.kind === "delete" || modelData.kind === "format" ? "#F0A0AA" : page.text1
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- sticky status: always visible above the navigation
        RnCard {
            Layout.fillWidth: true
            visible: page.disk !== null || page.probeError !== ""
            implicitHeight: Math.max(52, resCol.implicitHeight + 22)
            color: page.result && !page.result.ok ? "#1A0C0F" : "#131313"
            ColumnLayout {
                id: resCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 18 }
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Icon {
                        font.pixelSize: 22
                        text: !page.result ? "hourglass" : !page.result.ok ? "error" : (page.mode === "erase" && !page.eraseOk) ? "lock" : "check_circle"
                        color: page.result && page.result.ok && (page.mode !== "erase" || page.eraseOk) ? "#8FD19E" : page.red
                    }
                    Label2 {
                        Layout.fillWidth: true; font.pixelSize: 14; font.weight: Font.Medium
                        maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.StyledText
                        text: !page.result ? "Pick a disk."
                            : !page.result.ok ? "Not ready: <font color='#F0A0AA'>" + (page.result.errors || [""])[0] + "</font>" + ((page.result.errors || []).length > 1 ? "<font color='#A0A0A0'>  (+" + (page.result.errors.length - 1) + " more below)</font>" : "")
                            : (page.mode === "erase" && !page.eraseOk) ? "Turn on “Erase it” to continue"
                            : "Ready: RedNext gets " + page.size(page.result.rootSize) + (page.result.destroyBytes > 0 ? " · " + page.size(page.result.destroyBytes) + " of existing data will be erased" : " · no existing data is erased")
                    }
                }
            }
        }
    }
}
