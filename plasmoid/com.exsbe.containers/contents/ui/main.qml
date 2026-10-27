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

    property var containers: []
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
        containers = rows
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
    function terminal(title, cmd) { run("setsid -f kitty --title " + shq(title) + " " + cmd + " >/dev/null 2>&1") }

    Timer {
        interval: root.expanded ? 3000 : 10000
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

        readonly property color tint: root.problems > 0 ? Kirigami.Theme.negativeTextColor
            : root.starting > 0 ? Kirigami.Theme.highlightColor
            : Kirigami.Theme.textColor

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "package-x-generic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                color: parent.parent.tint
                isMask: true
            }
            PlasmaComponents3.Label {
                text: root.running + " ▲"
                color: parent.parent.tint
                opacity: root.running > 0 || root.problems > 0 ? 1 : 0.6
            }
            PlasmaComponents3.Label {
                visible: root.stopped > 0
                text: root.stopped + " ▼"
                color: root.problems > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                opacity: root.problems > 0 ? 1 : 0.5
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
                model: root.containers
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
                    required property var modelData
                    readonly property bool up: modelData.state === "running"
                    width: ListView.view.width
                    hoverEnabled: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing * 2

                        Rectangle {
                            width: Kirigami.Units.smallSpacing * 2
                            height: width
                            radius: width / 2
                            color: item.modelData.bad ? Kirigami.Theme.negativeTextColor
                                 : item.modelData.warming ? Kirigami.Theme.neutralTextColor
                                 : item.up ? Kirigami.Theme.positiveTextColor
                                 : Kirigami.Theme.disabledTextColor
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: item.modelData.name
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: [item.modelData.image, item.modelData.status, item.modelData.ports]
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
                            onClicked: root.run("podman restart " + root.shq(item.modelData.cid))
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered
                            icon.name: "utilities-terminal"
                            PlasmaComponents3.ToolTip.text: item.modelData.isBox ? "Enter" : "Shell"
                            PlasmaComponents3.ToolTip.visible: hovered
                            enabled: item.modelData.isBox || item.up
                            onClicked: root.terminal(item.modelData.name, item.modelData.isBox
                                ? "distrobox enter " + root.shq(item.modelData.name)
                                : "podman exec -it " + root.shq(item.modelData.cid) + " sh")
                        }
                        PlasmaComponents3.ToolButton {
                            visible: item.hovered && !item.modelData.isBox
                            icon.name: "view-list-text"
                            PlasmaComponents3.ToolTip.text: "Logs"
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: root.terminal(item.modelData.name + " logs",
                                "--hold podman logs -f --tail 200 " + root.shq(item.modelData.cid))
                        }
                    }

                    function lifecycle(verb) {
                        // podman stop works for distroboxes too and, unlike distrobox stop, never prompts
                        return "podman " + verb + " " + root.shq(modelData.cid)
                    }
                }
            }
        }
    }
}
