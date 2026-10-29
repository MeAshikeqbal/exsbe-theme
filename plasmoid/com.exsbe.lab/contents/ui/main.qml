// Exsbe Lab dashboard: a desktop card with the Lab cluster at a glance, through
// `exsbe-pve status`. Only shown (and only polling) while the Lab workspace is current.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string workspace: "Lab"
    readonly property string env: "PATH=\"$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH\" "
    readonly property real warn: 0.85

    property var snap: null
    property string error: ""
    property var issues: []
    property date updated: new Date(0)

    readonly property bool onLab: desktops.desktopNames[desktops.desktopIds.indexOf(desktops.currentDesktop)] === workspace
                                  || (Plasmoid.containment?.corona?.editMode ?? false) // visible while arranging widgets

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    TaskManager.VirtualDesktopInfo { id: desktops }

    function pct(x) { return Math.round(x * 100) + "%" }
    function gib(b) {
        return b >= 1099511627776 ? (b / 1099511627776).toFixed(1) + " TiB"
             : b >= 1073741824 ? (b / 1073741824).toFixed(b >= 10737418240 ? 0 : 1) + " GiB"
             : Math.round(b / 1048576) + " MiB"
    }
    function dur(s) { return s < 3600 ? Math.round(s / 60) + " min" : s < 86400 ? Math.round(s / 3600) + " h" : Math.round(s / 86400) + " d" }

    function parse(stdout) {
        let s
        try { s = JSON.parse(stdout.trim()) } catch (e) { error = "exsbe-pve output could not be read"; return }
        if (s.error) { error = s.error; return }
        error = ""
        const list = []
        for (const n of s.nodes) if (n.status !== "online") list.push("Node " + n.name + " is " + n.status)
        if (!s.quorate) list.push("Cluster has lost quorum")
        for (const st of s.storage) if (st.used / st.total >= warn) list.push(st.name + " is " + pct(st.used / st.total) + " full")
        for (const b of s.backup.failed) list.push("Backup " + (b.id || "job") + " on " + b.node + " failed")
        const pbs = s.pbs
        if (pbs && pbs.error) list.push("Backup server unreachable")
        else if (pbs) {
            for (const st of pbs.stores) if (st.total && st.used / st.total >= warn) list.push("PBS " + st.name + " is " + pct(st.used / st.total) + " full")
            for (const j of pbs.jobs) if (j.state && j.state.toLowerCase() !== "ok") list.push("PBS " + j.kind + " job " + j.id + " failed")
            for (const t of pbs.failed) list.push("PBS " + t.type + " " + t.id + " failed")
        }
        issues = list
        s.guests = s.guests.filter(g => !g.template)
        snap = s
        updated = new Date()
    }

    P5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if ((data.stdout || "").trim() === "") root.error = "exsbe-pve failed: " + (data.stderr || "").trim()
            else root.parse(data.stdout)
            disconnectSource(source)
        }
    }
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source) => disconnectSource(source)
    }
    function refresh() { poller.connectSource(env + "exsbe-pve status") }
    function run(cmd) { runner.connectSource(env + "systemd-run --user --scope --quiet --collect setsid -f " + cmd + " >/dev/null 2>&1") }

    Timer {
        interval: 15000
        running: root.onLab
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 40

        clip: true
        opacity: root.onLab ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        // the card: solid enough to read over any wallpaper
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.92)
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing

            // header
            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: "network-server"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        level: 1
                        text: root.snap ? root.snap.cluster : "Lab"
                    }
                    PlasmaComponents3.Label {
                        opacity: 0.65
                        text: root.error !== "" ? "unreachable"
                            : !root.snap ? "connecting…"
                            : (root.snap.quorate ? "quorate" : "no quorum") + " · "
                              + root.snap.nodes.filter(n => n.status === "online").length + "/" + root.snap.nodes.length + " nodes · "
                              + root.snap.guests.filter(g => g.status === "running").length + "/" + root.snap.guests.length + " running"
                    }
                }
                Rectangle {
                    readonly property bool ok: root.error === "" && root.issues.length === 0
                    radius: height / 2
                    color: Qt.alpha(ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor, 0.18)
                    implicitWidth: pill.implicitWidth + Kirigami.Units.gridUnit
                    implicitHeight: pill.implicitHeight + Kirigami.Units.smallSpacing * 2
                    PlasmaComponents3.Label {
                        id: pill
                        anchors.centerIn: parent
                        font.weight: Font.DemiBold
                        color: parent.ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                        text: root.error !== "" ? "Offline" : parent.ok ? "All good"
                            : root.issues.length + (root.issues.length === 1 ? " issue" : " issues")
                    }
                }
            }

            // problems first
            Repeater {
                model: root.error !== "" ? [root.error] : root.issues
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    radius: 10
                    color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.14)
                    implicitHeight: issueRow.implicitHeight + Kirigami.Units.largeSpacing
                    RowLayout {
                        id: issueRow
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        Kirigami.Icon {
                            source: "dialog-warning"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        PlasmaComponents3.Label {
                            text: modelData
                            color: Kirigami.Theme.negativeTextColor
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // nodes
            SectionLabel { text: "Nodes" }
            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: root.snap ? root.snap.nodes : []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool up: modelData.status === "online"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        radius: 12
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                        implicitHeight: nodeCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                        ColumnLayout {
                            id: nodeCol
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.smallSpacing
                            RowLayout {
                                Dot { on: up; bad: !up }
                                PlasmaComponents3.Label { text: modelData.name; font.weight: Font.DemiBold; Layout.fillWidth: true }
                            }
                            Meter { label: "cpu"; value: up ? modelData.cpu : 0 }
                            Meter { label: "mem"; value: up && modelData.maxmem ? modelData.mem / modelData.maxmem : 0 }
                            PlasmaComponents3.Label {
                                text: up ? "up " + root.dur(modelData.uptime) : modelData.status
                                font: Kirigami.Theme.smallFont
                                opacity: 0.55
                            }
                        }
                    }
                }
            }

            // storage + backups
            SectionLabel { text: "Storage" }
            Repeater {
                model: root.snap ? root.snap.storage.filter(s => s.type === "zfspool" || s.type === "pbs") : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        PlasmaComponents3.Label { text: modelData.name; Layout.fillWidth: true }
                        PlasmaComponents3.Label {
                            text: root.gib(modelData.used) + " / " + root.gib(modelData.total) + " · " + root.pct(modelData.used / modelData.total)
                            color: modelData.used / modelData.total >= root.warn ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            opacity: modelData.used / modelData.total >= root.warn ? 1 : 0.65
                        }
                    }
                    Bar { value: modelData.used / modelData.total }
                }
            }
            RowLayout {
                visible: root.snap !== null
                Kirigami.Icon {
                    source: root.snap && root.snap.backup.failed.length > 0 ? "dialog-error" : "backup"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    opacity: 0.8
                    text: !root.snap ? ""
                        : root.snap.backup.failed.length > 0 ? root.snap.backup.failed.length + " backup(s) failed in the last 24 h"
                        : root.snap.backup.last ? "Last backup " + root.dur(Date.now() / 1000 - root.snap.backup.last) + " ago · " + root.snap.backup.lastStatus
                        : "No backup runs found"
                }
            }
            RowLayout {
                visible: !!(root.snap && root.snap.pbs && !root.snap.pbs.error && root.snap.pbs.jobs.length)
                Kirigami.Icon {
                    source: "server-database"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    opacity: 0.8
                    elide: Text.ElideRight
                    // e.g. "PBS  verify ok 3 h ago · prune ok 1 d ago"
                    text: !(root.snap && root.snap.pbs && root.snap.pbs.jobs) ? ""
                        : "PBS  " + root.snap.pbs.jobs.map(j => j.kind + " " + (j.state || "pending")
                            + (j.end ? " " + root.dur(Date.now() / 1000 - j.end) + " ago" : "")).join(" · ")
                }
            }

            // the five running guests using the most memory
            SectionLabel { text: "Busiest" }
            Repeater {
                model: root.snap ? root.snap.guests.filter(g => g.status === "running" && g.maxmem)
                                       .sort((a, b) => b.mem - a.mem).slice(0, 5) : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    PlasmaComponents3.Label {
                        text: modelData.name
                        elide: Text.ElideRight
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    }
                    Bar { value: modelData.mem / modelData.maxmem; Layout.alignment: Qt.AlignVCenter }
                    PlasmaComponents3.Label {
                        text: root.gib(modelData.mem) + " · cpu " + root.pct(modelData.cpu)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.65
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    }
                }
            }

            // guests
            SectionLabel { text: "Guests" }
            PlasmaComponents3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 3
                contentWidth: availableWidth
                Flow {
                    width: parent.width
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.snap ? root.snap.guests : []
                        delegate: PlasmaComponents3.ItemDelegate {
                            id: chip
                            required property var modelData
                            readonly property bool up: modelData.status === "running"
                            hoverEnabled: true
                            padding: Kirigami.Units.smallSpacing
                            leftPadding: Kirigami.Units.largeSpacing
                            rightPadding: Kirigami.Units.largeSpacing
                            background: Rectangle {
                                radius: height / 2
                                color: Qt.alpha(Kirigami.Theme.textColor, chip.hovered ? 0.12 : 0.05)
                            }
                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Dot { on: chip.up }
                                PlasmaComponents3.Label {
                                    text: chip.modelData.name
                                    opacity: chip.up ? 1 : 0.5
                                }
                            }
                            PlasmaComponents3.ToolTip.text: (modelData.type === "lxc" ? "Container " : "VM ") + modelData.vmid + " on " + modelData.node
                                + (up ? " · cpu " + root.pct(modelData.cpu) + " · mem " + root.gib(modelData.mem) + " · up " + root.dur(modelData.uptime) : " · " + modelData.status)
                                + "\nClick: open in Proxmox"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: root.run("exsbe-pve web " + modelData.vmid)
                        }
                    }
                }
            }

            // footer
            RowLayout {
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                    opacity: 0.45
                    elide: Text.ElideRight
                    text: root.updated.getTime() > 0
                        ? "updated " + Qt.formatTime(root.updated, "hh:mm:ss") + (root.snap ? " · " + root.snap.endpoint.replace("https://", "") : "")
                        : ""
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "search"
                    text: "Guests"
                    PlasmaComponents3.ToolTip.text: "Guest picker (Meta+Shift+P)"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: root.run("kitty --title lab pvepick")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "internet-web-browser"
                    text: "Proxmox"
                    onClicked: root.run("exsbe-pve web")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    onClicked: root.refresh()
                }
            }
        }
    }

    component SectionLabel: PlasmaComponents3.Label {
        Layout.topMargin: Kirigami.Units.smallSpacing
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2
        font.weight: Font.DemiBold
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.45
    }

    component Dot: Rectangle {
        property bool on: true
        property bool bad: false
        width: Kirigami.Units.smallSpacing * 2
        height: width
        radius: width / 2
        color: bad ? Kirigami.Theme.negativeTextColor : on ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
    }

    component Bar: Rectangle {
        property real value: 0
        Layout.fillWidth: true
        height: 5
        radius: 2.5
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        Rectangle {
            width: parent.width * Math.min(1, Math.max(0, parent.value))
            height: parent.height
            radius: parent.radius
            color: parent.value >= root.warn ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
            Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }
    }

    component Meter: ColumnLayout {
        property string label
        property real value: 0
        spacing: 2
        Layout.fillWidth: true
        RowLayout {
            PlasmaComponents3.Label { text: label; font: Kirigami.Theme.smallFont; opacity: 0.55; Layout.fillWidth: true }
            PlasmaComponents3.Label { text: root.pct(value); font: Kirigami.Theme.smallFont }
        }
        Bar { value: parent.value }
    }
}
