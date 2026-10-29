// Exsbe containers: local Podman containers, compose projects, pods and distroboxes.
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
    readonly property string pollCmd: "podman ps -a --format json; echo '@@PODS@@'; podman pod ps --format json"

    ListModel { id: containerModel }
    property int running: 0
    property int stopped: 0
    property int problems: 0
    property int starting: 0
    property string error: ""

    Plasmoid.icon: "package-x-generic"
    toolTipMainText: "Containers"
    toolTipSubText: error !== "" ? error
        : running + " running, " + stopped + " stopped"
          + (problems > 0 ? ", " + problems + " need attention" : "")

    preferredRepresentation: compactRepresentation

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

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
        const parts = stdout.split("@@PODS@@")
        let list = []
        try { list = JSON.parse(parts[0].trim() || "[]") || [] } catch (e) { error = "podman output could not be read"; return }
        error = ""
        let r = 0, s = 0, p = 0, st = 0
        const rows = []
        for (const c of list) {
            if (c.IsInfra) continue
            const labels = c.Labels || {}
            const isBox = labels.manager === "distrobox"
            const health = (c.Status || "").includes("(unhealthy)") ? "unhealthy"
                         : (c.Status || "").includes("(starting)") ? "starting" : ""
            const cleanExit = [0, 130, 137, 143].includes(c.ExitCode)
            let state = c.State
            const bad = health === "unhealthy" || state === "dead"
                     || (!isBox && state === "exited" && !cleanExit)
            const warming = !bad && (health === "starting" || state === "created" || state === "restarting" || state === "paused")
            if (state === "running") r++; else s++
            if (bad) p++
            if (warming) st++

            const ports = (c.Ports || []).map(pt => pt.host_port + "→" + pt.container_port).join("  ")
            let group = "Containers"
            if (isBox) group = "Distrobox"
            else if (labels["com.docker.compose.project"]) group = "Compose · " + labels["com.docker.compose.project"]
            else if (c.PodName) group = "Pod · " + c.PodName

            rows.push({
                cid: c.Id, name: (c.Names || ["?"])[0], image: (c.Image || "").replace(/^docker\.io\/(library\/)?/, ""),
                status: c.Status || state, state: state, ports: ports, group: group, isBox: isBox,
                bad: bad, warming: warming
            })
        }
        // groups alphabetically, but Distrobox last; running first inside a group
        rows.sort((a, b) => {
            const ga = a.group === "Distrobox" ? "~" : a.group, gb = b.group === "Distrobox" ? "~" : b.group
            if (ga !== gb) return ga < gb ? -1 : 1
            if ((a.state === "running") !== (b.state === "running")) return a.state === "running" ? -1 : 1
            return a.name < b.name ? -1 : 1
        })
        sync(containerModel, rows.map(x => Object.assign({ key: x.cid }, x)))
        running = r; stopped = s; problems = p; starting = st
    }

    P5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (data["exit code"] !== 0 && (data.stdout || "") === "")
                root.error = "podman failed: " + (data.stderr || "").trim()
            else
                root.parse(data.stdout || "")
            disconnectSource(source)
        }
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => { disconnectSource(source); refresh() }
    }

    function refresh() { poller.connectSource(env + pollCmd) }
    function run(cmd) { runner.connectSource(env + cmd) }
    // a container's conmon stays in the cgroup of whoever started it; give it its own scope
    // so restarting plasmashell (or closing a terminal) doesn't stop the container
    function scoped(cmd) { return "systemd-run --user --scope --quiet --collect " + cmd }
    function terminal(title, cmd) { run("systemd-run --user --scope --quiet --collect setsid -f kitty --title " + shq(title) + " " + cmd + " >/dev/null 2>&1") }

    Timer {
        interval: root.expanded ? 3000 : 10000
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
            Chip {
                icon: "package-x-generic-symbolic"
                value: String(root.running)
                valueColor: root.problems > 0 ? Kirigami.Theme.negativeTextColor
                    : root.starting > 0 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                detail: root.problems > 0 ? root.problems + " !" : "/" + (root.running + root.stopped)
                detailColor: root.problems > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    level: 3
                    text: "Containers"
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                }
                PlasmaComponents3.Label {
                    text: root.running + " running · " + root.stopped + " stopped"
                    opacity: 0.6
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "utilities-terminal"
                    text: "lazydocker"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Open lazydocker (Meta+Shift+C)"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.terminal("lazydocker", "lazypod"); root.expanded = false }
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
                model: containerModel
                clip: true
                spacing: 0
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
                    iconName: "package-x-generic"
                    text: root.error !== "" ? root.error : "No containers"
                }

                delegate: PlasmaComponents3.ItemDelegate {
                    id: item
                    required property var model
                    readonly property bool up: model.state === "running"
                    width: ListView.view.width
                    hoverEnabled: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing * 2

                        Rectangle {
                            width: Kirigami.Units.smallSpacing * 2
                            height: width
                            radius: width / 2
                            color: item.model.bad ? Kirigami.Theme.negativeTextColor
                                 : item.model.warming ? Kirigami.Theme.neutralTextColor
                                 : item.up ? Kirigami.Theme.positiveTextColor
                                 : Kirigami.Theme.disabledTextColor
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: item.model.name
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: [item.model.image, item.model.status, item.model.ports]
                                      .filter(x => x).join("  ·  ")
                                font: Kirigami.Theme.smallFont
                                opacity: 0.65
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        PlasmaComponents3.ToolButton {
                            visible: item.hovered
                            icon.name: item.up ? "media-playback-stop" : "media-playback-start"
                            PlasmaComponents3.ToolTip.text: item.up ? "Stop" : "Start"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: root.run(item.lifecycle(item.up ? "stop" : "start"))
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered && item.up
                            icon.name: "view-refresh"
                            PlasmaComponents3.ToolTip.text: "Restart"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: root.run(root.scoped("podman restart " + root.shq(item.model.cid)))
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered
                            icon.name: "utilities-terminal"
                            PlasmaComponents3.ToolTip.text: item.model.isBox ? "Enter" : "Shell"
                            PlasmaComponents3.ToolTip.visible: hovered
                            enabled: item.model.isBox || item.up
                            onClicked: root.terminal(item.model.name, item.model.isBox
                                ? "distrobox enter " + root.shq(item.model.name)
                                : "podman exec -it " + root.shq(item.model.cid) + " sh")
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered && !item.model.isBox
                            icon.name: "view-list-text"
                            PlasmaComponents3.ToolTip.text: "Logs"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: root.terminal(item.model.name + " logs",
                                "--hold podman logs -f --tail 200 " + root.shq(item.model.cid))
                        }
                    }

                    function lifecycle(verb) {
                        // podman stop works for distroboxes too and, unlike distrobox stop, never prompts
                        return root.scoped("podman " + verb + " " + root.shq(model.cid))
                    }
                }
            }
        }
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
