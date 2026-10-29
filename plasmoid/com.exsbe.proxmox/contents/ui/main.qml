// Exsbe Proxmox: cluster nodes, storage, backups and guests, through `exsbe-pve status`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // plasmashell may not have Homebrew / ~/.local/bin on PATH
    readonly property string env: "PATH=\"$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH\" "
    readonly property string pollCmd: "exsbe-pve status; echo; echo '@@TS@@'; tailscale status --json 2>/dev/null | jq -r .BackendState"
    readonly property real storageWarn: 0.85

    property var snap: ({ nodes: [], guests: [], storage: [], backup: { failed: [] } })
    ListModel { id: rowModel }
    property string error: ""
    property string tailscale: ""
    property int nodesUp: 0
    property int guestsUp: 0
    property int problems: 0

    Plasmoid.icon: "network-server"
    toolTipMainText: snap.cluster || "Proxmox"
    toolTipSubText: error !== "" ? error
        : nodesUp + "/" + snap.nodes.length + " nodes, " + guestsUp + "/" + snap.guests.length + " guests running"
          + (problems > 0 ? ", " + problems + " need attention" : "")

    preferredRepresentation: compactRepresentation

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function pct(x) { return Math.round(x * 100) + "%" }
    function gib(b) { return b >= 1099511627776 ? (b / 1099511627776).toFixed(1) + " TiB" : (b / 1073741824).toFixed(1) + " GiB" }
    function ago(t) {
        const s = Date.now() / 1000 - t
        return s < 3600 ? Math.round(s / 60) + " min ago" : s < 86400 ? Math.round(s / 3600) + " h ago" : Math.round(s / 86400) + " d ago"
    }

    // update the list in place so it keeps its scroll position; rebuild only when the rows change
    function sync(model, rows) {
        let same = model.count === rows.length
        for (let i = 0; same && i < rows.length; i++)
            same = model.get(i).key === rows[i].key
        if (!same) {
            model.clear()
            for (const r of rows) model.append(r)
        } else {
            for (let i = 0; i < rows.length; i++) model.set(i, rows[i])
        }
    }

    function parse(stdout) {
        const parts = stdout.split("@@TS@@")
        tailscale = (parts[1] || "").trim()
        let s
        try { s = JSON.parse(parts[0].trim()) } catch (e) { error = "exsbe-pve output could not be read"; return }
        if (s.error) { error = s.error; return }
        error = ""
        snap = s
        nodesUp = s.nodes.filter(n => n.status === "online").length
        guestsUp = s.guests.filter(g => g.status === "running").length
        const full = s.storage.filter(st => st.used / st.total >= storageWarn)
        problems = (s.nodes.length - nodesUp) + (s.quorate ? 0 : 1) + full.length + s.backup.failed.length

        // one flat list, sectioned: Cluster (nodes, storage, backups), then guests per node
        const r = []
        for (const n of s.nodes)
            r.push({ kind: "node", group: "Cluster", name: n.name, bad: n.status !== "online",
                     detail: n.status === "online" ? "cpu " + pct(n.cpu) + " · mem " + pct(n.mem / n.maxmem) + " of " + gib(n.maxmem) : n.status,
                     load: n.status === "online" ? Math.max(n.cpu, n.mem / n.maxmem) : 0 })
        for (const st of s.storage)
            if (st.type === "pbs" || st.type === "zfspool")
                r.push({ kind: "storage", group: "Storage", name: st.name, bad: st.used / st.total >= storageWarn,
                         detail: gib(st.used) + " of " + gib(st.total) + " · " + pct(st.used / st.total), load: st.used / st.total })
        const b = s.backup
        r.push({ kind: "backup", group: "Storage", name: "Backups", bad: b.failed.length > 0,
                 detail: b.failed.length > 0 ? b.failed.length + " failed in the last 24 h"
                       : b.last ? "last run " + ago(b.last) + " · " + b.lastStatus : "no backup tasks", load: -1 })
        for (const g of s.guests)
            if (!g.template)
                r.push({ kind: "guest", group: "On " + g.node, name: g.name, vmid: g.vmid, type: g.type, up: g.status === "running",
                         bad: false, load: -1,
                         detail: (g.type === "lxc" ? "ct " : "vm ") + g.vmid
                                 + (g.status === "running" ? " · cpu " + pct(g.cpu) + " · mem " + gib(g.mem) : " · " + g.status)
                                 + (g.tags ? " · " + g.tags.split(";").join(" ") : "") })
        // every row carries every role (ListModel roles are fixed by the first row)
        sync(rowModel, r.map(x => Object.assign({ vmid: 0, type: "", up: false, key: x.kind + ":" + (x.vmid || x.name) }, x)))
    }

    P5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if ((data.stdout || "").trim() === "")
                root.error = "exsbe-pve failed: " + (data.stderr || "").trim()
            else
                root.parse(data.stdout)
            disconnectSource(source)
        }
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => { disconnectSource(source); delayed.restart() }
    }
    Timer { id: delayed; interval: 1500; onTriggered: root.refresh() }

    function refresh() { poller.connectSource(env + pollCmd) }
    function run(cmd) { runner.connectSource(env + cmd) }
    function detach(cmd) { run("setsid -f " + cmd + " >/dev/null 2>&1") }

    Timer {
        interval: root.expanded ? 5000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        readonly property color tint: root.error !== "" ? Kirigami.Theme.disabledTextColor
            : root.problems > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "network-server"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                color: parent.parent.tint
                isMask: true
            }
            PlasmaComponents3.Label {
                text: root.error !== "" ? "–" : root.guestsUp + " ▲"
                color: parent.parent.tint
            }
            PlasmaComponents3.Label {
                visible: root.problems > 0 && root.error === ""
                text: root.problems + " !"
                color: Kirigami.Theme.negativeTextColor
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 32
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    level: 3
                    text: root.snap.cluster || "Proxmox"
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                }
                PlasmaComponents3.Label {
                    text: root.error !== "" ? "unreachable"
                        : (root.snap.quorate ? "quorate" : "no quorum") + " · " + root.nodesUp + "/" + root.snap.nodes.length + " nodes"
                    color: root.error !== "" || !root.snap.quorate ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    opacity: 0.6
                    Layout.fillWidth: true
                }
                PlasmaComponents3.ToolButton {
                    visible: root.tailscale !== ""
                    icon.name: root.tailscale === "Running" ? "network-vpn" : "network-vpn-disconnected"
                    checkable: true
                    checked: root.tailscale === "Running"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Tailscale: " + root.tailscale + " (click to " + (checked ? "disconnect" : "connect") + ")"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: root.run(root.tailscale === "Running" ? "tailscale down" : "tailscale up")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "search"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Guest picker (Meta+Shift+P)"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.detach("kitty --title lab pvepick"); root.expanded = false }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "internet-web-browser"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Proxmox web UI"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.run("exsbe-pve web"); root.expanded = false }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    onClicked: root.refresh()
                }
            }
        }

        PlasmaComponents3.ScrollView {
            anchors.fill: parent

            ListView {
                id: list
                model: rowModel
                clip: true
                section.property: "group"
                section.criteria: ViewSection.FullString
                section.delegate: Kirigami.ListSectionHeader {
                    required property string section
                    width: ListView.view.width
                    label: section
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: list.count === 0
                    iconName: "network-server"
                    text: root.error !== "" ? root.error : "Loading…"
                    explanation: root.error !== "" ? "Away from home? Connect Tailscale or add an endpoint in ~/.config/exsbe/pve.conf" : ""
                }

                delegate: PlasmaComponents3.ItemDelegate {
                    id: item
                    required property var model
                    readonly property bool guest: model.kind === "guest"
                    // shutdown / reboot need a second click within 3 s
                    property string armed: ""
                    function confirm(action) {
                        if (armed === action) { armed = ""; root.run("exsbe-pve do " + model.vmid + " " + action) }
                        else { armed = action; disarm.restart() }
                    }
                    Timer { id: disarm; interval: 3000; onTriggered: item.armed = "" }
                    onHoveredChanged: if (!hovered) armed = ""
                    width: ListView.view.width
                    hoverEnabled: true
                    onClicked: if (guest) root.run("exsbe-pve web " + model.vmid)

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing * 2

                        Rectangle {
                            width: Kirigami.Units.smallSpacing * 2
                            height: width
                            radius: width / 2
                            color: item.model.bad ? Kirigami.Theme.negativeTextColor
                                 : item.guest && !item.model.up ? Kirigami.Theme.disabledTextColor
                                 : item.model.load >= root.storageWarn ? Kirigami.Theme.neutralTextColor
                                 : Kirigami.Theme.positiveTextColor
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: item.model.name
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: item.model.detail
                                font: Kirigami.Theme.smallFont
                                color: item.model.bad ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                opacity: item.model.bad ? 1 : 0.65
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            // usage bar for nodes and storage
                            Rectangle {
                                visible: item.model.load >= 0
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                height: 3
                                radius: 1.5
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                                Rectangle {
                                    width: parent.width * Math.min(1, item.model.load)
                                    height: parent.height
                                    radius: parent.radius
                                    color: item.model.load >= root.storageWarn ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                                }
                            }
                        }

                        PlasmaComponents3.ToolButton {
                            visible: item.guest && item.hovered
                            icon.name: item.armed === "shutdown" ? "dialog-warning" : item.model.up ? "system-shutdown" : "media-playback-start"
                            PlasmaComponents3.ToolTip.text: item.armed === "shutdown" ? "Click again to shut down" : item.model.up ? "Shut down" : "Start"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: item.model.up ? item.confirm("shutdown") : root.run("exsbe-pve do " + item.model.vmid + " start")
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.guest && item.hovered && item.model.up
                            icon.name: item.armed === "reboot" ? "dialog-warning" : "view-refresh"
                            PlasmaComponents3.ToolTip.text: item.armed === "reboot" ? "Click again to reboot" : "Reboot"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: item.confirm("reboot")
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.guest && item.hovered && item.model.up
                            icon.name: "utilities-terminal"
                            PlasmaComponents3.ToolTip.text: item.model.type === "lxc" ? "Console (pct enter)" : "Console (noVNC)"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: { root.detach("exsbe-pve console " + item.model.vmid); root.expanded = false }
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.guest && item.hovered && item.model.up
                            icon.name: "network-connect"
                            PlasmaComponents3.ToolTip.text: "SSH"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: { root.detach("kitty --title " + root.shq(item.model.name) + " ssh " + root.shq(item.model.name)); root.expanded = false }
                        }
                    }
                }
            }
        }
    }
}
