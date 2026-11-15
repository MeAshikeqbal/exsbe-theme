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
    property var issues: []          // [{ text, level }], level 2 = broken, 1 = worth a look
    readonly property int problems: issues.length
    readonly property int worst: issues.reduce((m, i) => Math.max(m, i.level), 0)
    property var pools: []           // storage shown in the popup

    Plasmoid.icon: "network-server"
    toolTipMainText: snap.cluster || "Proxmox"
    toolTipSubText: error !== "" ? error
        : nodesUp + "/" + snap.nodes.length + " nodes, " + guestsUp + "/" + snap.guests.length + " guests running"
          + (problems > 0 ? "\n" + issues.map(i => i.text).join("\n") : "")

    preferredRepresentation: compactRepresentation

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function pct(x) { return Math.round(x * 100) + "%" }
    function gib(b) { return b >= 1099511627776 ? (b / 1099511627776).toFixed(1) + " TiB" : (b / 1073741824).toFixed(1) + " GiB" }
    // "21 / 110 GiB", "2.5 / 3.5 TiB": one unit for a used / total pair
    function pair(used, total) {
        const tib = total >= 1099511627776, d = tib ? 1099511627776 : 1073741824
        const f = v => total / d >= 100 ? String(Math.round(v)) : (Math.round(v * 10) / 10).toFixed(1)
        return f(used / d) + " / " + f(total / d) + (tib ? " TiB" : " GiB")
    }
    function dur(s) { return s < 3600 ? Math.round(s / 60) + " min" : s < 86400 ? Math.round(s / 3600) + " h" : Math.round(s / 86400) + " d" }
    function ago(t) { return dur(Date.now() / 1000 - t) + " ago" }
    // usage colour: amber from 75 %, red from the warning level
    function usageColor(x) { return x >= storageWarn ? Kirigami.Theme.negativeTextColor : x >= 0.75 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor }
    function levelColor(l) { return l >= 2 ? Kirigami.Theme.negativeTextColor : l === 1 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor }

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

    // the same list of problems as the Lab dashboard
    function findIssues(s) {
        const list = []
        for (const n of s.nodes) if (n.status !== "online") list.push({ level: 2, text: "Node " + n.name + " is " + n.status })
        if (!s.quorate) list.push({ level: 2, text: "Cluster has lost quorum" })
        for (const st of s.storage) if (st.total && st.used / st.total >= storageWarn) list.push({ level: 2, text: st.name + " is " + pct(st.used / st.total) + " full" })
        const b = s.backup
        for (const f of b.failed) {
            // a failure that a later successful run has superseded is only worth a look
            const later = b.last && f.end && b.last > f.end && String(b.lastStatus).toUpperCase() === "OK"
            list.push({ level: later ? 1 : 2,
                        text: "Backup" + (f.id ? " " + f.id : "") + " on " + f.node + " failed" + (f.end ? " " + ago(f.end) : "")
                              + (f.status ? " (" + f.status + ")" : "") + (later ? " · later run OK" : "") })
        }
        const pbs = s.pbs
        if (pbs && pbs.error) list.push({ level: 2, text: "Backup server unreachable" })
        else if (pbs) {
            for (const st of pbs.stores) if (st.total && st.used / st.total >= storageWarn) list.push({ level: 2, text: "PBS " + st.name + " is " + pct(st.used / st.total) + " full" })
            for (const j of pbs.jobs) if (j.state && j.state.toLowerCase() !== "ok") list.push({ level: 2, text: "PBS " + j.kind + " job " + j.id + " failed" })
            for (const t of pbs.failed) list.push({ level: 2, text: "PBS " + t.type + " " + t.id + " failed" })
        }
        return list.sort((x, y) => y.level - x.level)
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
        issues = findIssues(s)
        pools = s.storage.filter(st => (st.type === "pbs" || st.type === "zfspool") && st.total)

        // the list: guests, sectioned per node (nodes, storage and problems sit in its header)
        const freq = {}
        for (const g of s.guests) for (const t of (g.tags || "").split(";")) if (t) freq[t] = (freq[t] || 0) + 1
        const telling = t => t && freq[t] <= s.guests.length / 3
        const r = []
        for (const g of s.guests.slice().sort((x, y) => x.node.localeCompare(y.node) || x.vmid - y.vmid))
            if (!g.template) {
                const node = s.nodes.find(n => n.name === g.node)
                const up = g.status === "running"
                r.push({ key: "guest:" + g.vmid, group: g.node, name: g.name, vmid: g.vmid, type: g.type, up: up,
                         tags: (g.tags || "").split(";").filter(telling).join(","),
                         detail: (g.type === "lxc" ? "ct " : "vm ") + g.vmid
                                 + (up ? " · cpu " + pct(g.cpu) + " · " + gib(g.mem) : " · " + g.status) })
            }
        sync(rowModel, r)
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
    function detach(cmd) { run("systemd-run --user --scope --quiet --collect setsid -f " + cmd + " >/dev/null 2>&1") }

    Timer {
        interval: root.expanded ? 5000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: chips.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: chips
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing
            // running guests; with problems: their count, amber (worth a look) or red (broken)
            Chip {
                icon: "network-server-symbolic"
                opacity: root.error !== "" ? 0.45 : 1
                value: root.error !== "" ? "–" : String(root.guestsUp)
                valueColor: root.problems > 0 ? root.levelColor(root.worst) : Kirigami.Theme.textColor
                detail: root.error !== "" ? "" : root.problems > 0 ? root.problems + " !" : "/" + root.snap.guests.length
                detailColor: root.problems > 0 ? root.levelColor(root.worst) : Kirigami.Theme.textColor
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 34
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                ColumnLayout {
                    spacing: 0
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Kirigami.Heading { level: 3; text: root.snap.cluster || "Proxmox" }
                    PlasmaComponents3.Label {
                        text: root.error !== "" ? "unreachable"
                            : (root.snap.quorate ? "quorate" : "no quorum") + " · " + root.nodesUp + "/" + root.snap.nodes.length
                              + " nodes · " + root.guestsUp + "/" + root.snap.guests.length + " running"
                        color: root.error !== "" || !root.snap.quorate ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        opacity: 0.6
                        font: Kirigami.Theme.smallFont
                    }
                }
                PlasmaComponents3.ToolButton {
                    visible: root.tailscale !== ""
                    icon.name: root.tailscale === "Running" ? "network-vpn-symbolic" : "network-vpn-disconnected-symbolic"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    opacity: root.tailscale === "Running" ? 1 : 0.6
                    PlasmaComponents3.ToolTip.text: "Tailscale " + (root.tailscale === "Running" ? "connected" : root.tailscale.toLowerCase())
                                                    + " (click to " + (root.tailscale === "Running" ? "disconnect" : "connect") + ")"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: root.run(root.tailscale === "Running" ? "tailscale down" : "tailscale up")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "search-symbolic"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Guest picker (Meta+Shift+P)"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.detach("kitty --title lab -o initial_window_width=170c -o initial_window_height=42c -o remember_window_size=no pvepick"); root.expanded = false }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "internet-web-browser-symbolic"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Proxmox web UI"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.run("exsbe-pve web"); root.expanded = false }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh-symbolic"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Refresh"
                    PlasmaComponents3.ToolTip.visible: hovered
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
                    label: section + "  ·  " + root.snap.guests.filter(g => g.node === section && g.status === "running").length
                           + "/" + root.snap.guests.filter(g => g.node === section && !g.template).length + " running"
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: list.count === 0 && root.snap.nodes.length === 0
                    iconName: "network-server"
                    text: root.error !== "" ? root.error : "Loading…"
                    explanation: root.error !== "" ? "Away from home? Connect Tailscale or add an endpoint in ~/.config/exsbe/pve.conf" : ""
                }

                // problems, nodes and storage, scrolling with the guests
                header: ColumnLayout {
                    width: ListView.view.width
                    spacing: Kirigami.Units.smallSpacing
                    visible: root.snap.nodes.length > 0

                    Repeater {
                        model: root.issues
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            Layout.topMargin: index === 0 ? Kirigami.Units.smallSpacing : 0
                            required property int index
                            radius: 8
                            color: Qt.alpha(root.levelColor(modelData.level), 0.14)
                            implicitHeight: issueRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                            RowLayout {
                                id: issueRow
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.largeSpacing
                                anchors.rightMargin: Kirigami.Units.largeSpacing
                                Kirigami.Icon {
                                    source: modelData.level >= 2 ? "dialog-error" : "dialog-warning"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                PlasmaComponents3.Label {
                                    text: modelData.text
                                    color: root.levelColor(modelData.level)
                                    wrapMode: Text.Wrap
                                    font: Kirigami.Theme.smallFont
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Kirigami.ListSectionHeader { label: "Nodes"; Layout.fillWidth: true }
                    GridLayout {
                        columns: Math.max(1, Math.min(3, root.snap.nodes.length))
                        columnSpacing: Kirigami.Units.smallSpacing
                        rowSpacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        Repeater {
                            model: root.snap.nodes
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool up: modelData.status === "online"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                radius: 8
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                                implicitHeight: nodeCol.implicitHeight + Kirigami.Units.smallSpacing * 3
                                ColumnLayout {
                                    id: nodeCol
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing * 1.5
                                    spacing: 3
                                    RowLayout {
                                        Dot { color: up ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor }
                                        PlasmaComponents3.Label { text: modelData.name; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                    Meter { label: "cpu"; value: up ? modelData.cpu : 0 }
                                    Meter { label: "mem"; value: up && modelData.maxmem ? modelData.mem / modelData.maxmem : 0 }
                                }
                            }
                        }
                    }

                    Kirigami.ListSectionHeader { label: "Storage"; Layout.fillWidth: true; visible: root.pools.length > 0 }
                    Repeater {
                        model: root.pools
                        delegate: ColumnLayout {
                            required property var modelData
                            readonly property real used: modelData.used / modelData.total
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.largeSpacing
                            Layout.rightMargin: Kirigami.Units.largeSpacing
                            spacing: 2
                            RowLayout {
                                PlasmaComponents3.Label { text: modelData.name; elide: Text.ElideRight; Layout.fillWidth: true }
                                PlasmaComponents3.Label {
                                    text: root.pair(modelData.used, modelData.total) + " · " + root.pct(used)
                                    font: Kirigami.Theme.smallFont
                                    color: used >= 0.75 ? root.usageColor(used) : Kirigami.Theme.textColor
                                    opacity: used >= 0.75 ? 1 : 0.6
                                }
                            }
                            Bar { value: used }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.topMargin: 2
                        Kirigami.Icon {
                            source: "backup"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            opacity: 0.7
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                            text: root.snap.backup.last ? "Last backup " + root.ago(root.snap.backup.last) + " · " + root.snap.backup.lastStatus
                                : "No backup runs found"
                        }
                    }
                    Item { implicitHeight: Kirigami.Units.smallSpacing }
                }

                delegate: PlasmaComponents3.ItemDelegate {
                    id: item
                    required property var model
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
                    onClicked: root.run("exsbe-pve web " + model.vmid)

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing * 2

                        Dot { color: item.model.up ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: item.model.name
                                font.weight: Font.DemiBold
                                opacity: item.model.up ? 1 : 0.55
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: item.model.detail
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.features: { "tnum": 1 }
                                opacity: 0.55
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // tags, until the actions take their place on hover
                        Repeater {
                            model: item.hovered || !item.model.tags ? [] : item.model.tags.split(",").slice(0, 2)
                            delegate: Rectangle {
                                required property string modelData
                                radius: height / 2
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.07)
                                implicitWidth: tag.implicitWidth + Kirigami.Units.largeSpacing
                                implicitHeight: tag.implicitHeight + 2
                                PlasmaComponents3.Label {
                                    id: tag
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                                    opacity: 0.6
                                }
                            }
                        }

                        PlasmaComponents3.ToolButton {
                            visible: item.hovered
                            icon.name: item.armed === "shutdown" ? "dialog-warning" : item.model.up ? "system-shutdown" : "media-playback-start"
                            PlasmaComponents3.ToolTip.text: item.armed === "shutdown" ? "Click again to shut down" : item.model.up ? "Shut down" : "Start"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: item.model.up ? item.confirm("shutdown") : root.run("exsbe-pve do " + item.model.vmid + " start")
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered && item.model.up
                            icon.name: item.armed === "reboot" ? "dialog-warning" : "view-refresh"
                            PlasmaComponents3.ToolTip.text: item.armed === "reboot" ? "Click again to reboot" : "Reboot"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: item.confirm("reboot")
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered && item.model.up
                            icon.name: "utilities-terminal"
                            PlasmaComponents3.ToolTip.text: item.model.type === "lxc" ? "Console (pct enter)" : "Console (noVNC)"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: { root.detach("exsbe-pve console " + item.model.vmid); root.expanded = false }
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered && item.model.up
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

    component Dot: Rectangle {
        width: Kirigami.Units.smallSpacing * 2
        height: width
        radius: width / 2
    }

    component Bar: Rectangle {
        property real value: 0
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        Rectangle {
            width: parent.width * Math.min(1, Math.max(0, parent.value))
            height: parent.height
            radius: parent.radius
            color: root.usageColor(parent.value)
        }
    }

    component Meter: ColumnLayout {
        property string label
        property real value: 0
        spacing: 1
        Layout.fillWidth: true
        RowLayout {
            PlasmaComponents3.Label { text: label; font: Kirigami.Theme.smallFont; opacity: 0.55; Layout.fillWidth: true }
            PlasmaComponents3.Label { text: root.pct(value); font.pointSize: Kirigami.Theme.smallFont.pointSize; font.features: { "tnum": 1 } }
        }
        Bar { value: parent.value }
    }

    // top-bar chip, shared look across the Exsbe widgets: icon · value · dim detail.
    // widest* reserve room so the bar never shifts as numbers change.
    component Chip: RowLayout {
        property string icon
        property string value
        property string detail: ""
        property color valueColor: Kirigami.Theme.textColor
        property color detailColor: Kirigami.Theme.textColor
        property string widestValue: ""
        property string widestDetail: ""
        spacing: 4
        Kirigami.Icon {
            source: icon
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        PlasmaComponents3.Label {
            text: value
            color: valueColor
            font.features: { "tnum": 1 }
            Layout.minimumWidth: widestValue ? valueMetrics.width : 0
            TextMetrics { id: valueMetrics; text: widestValue; font.features: { "tnum": 1 } }
        }
        PlasmaComponents3.Label {
            visible: detail !== "" || widestDetail !== ""
            text: detail
            color: detailColor
            opacity: detailColor === Kirigami.Theme.textColor ? 0.5 : 1
            font.features: { "tnum": 1 }
            Layout.minimumWidth: widestDetail ? detailMetrics.width : 0
            TextMetrics { id: detailMetrics; text: widestDetail; font.features: { "tnum": 1 } }
        }
    }
}
