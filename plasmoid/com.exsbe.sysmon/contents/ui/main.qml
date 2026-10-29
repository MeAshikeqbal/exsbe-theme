// Exsbe system: CPU, memory and GPU in the top bar, with a popup of history graphs,
// temperatures, clocks, fans and top processes. Values come from Plasma's own sensors
// (ksystemstats), the same ones the stock System Monitor widgets use.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int historyLength: 60   // samples, one per second

    // --- sensors ---------------------------------------------------------------------
    component S: Sensors.Sensor { updateRateLimit: 1000 }
    S { id: cpu; sensorId: "cpu/all/usage" }
    S { id: cpuUser; sensorId: "cpu/all/user" }
    S { id: cpuSystem; sensorId: "cpu/all/system" }
    S { id: cpuWait; sensorId: "cpu/all/wait" }
    S { id: cpuTemp; sensorId: "cpu/all/maximumTemperature" }
    S { id: cpuFreq; sensorId: "cpu/all/averageFrequency" }
    S { id: cpuName; sensorId: "cpu/all/name" }
    S { id: cpuCores; sensorId: "cpu/all/coreCount" }
    S { id: memUsed; sensorId: "memory/physical/used" }
    S { id: memApp; sensorId: "memory/physical/application" }
    S { id: memCache; sensorId: "memory/physical/cache" }
    S { id: memTotal; sensorId: "memory/physical/total" }
    S { id: swapUsed; sensorId: "memory/swap/used" }
    S { id: swapTotal; sensorId: "memory/swap/total" }
    S { id: gpu; sensorId: "gpu/gpu0/usage" }
    S { id: gpuName; sensorId: "gpu/gpu0/name" }
    S { id: gpuTemp; sensorId: "gpu/gpu0/temperature" }
    S { id: gpuPower; sensorId: "gpu/gpu0/power" }
    S { id: gpuFreq; sensorId: "gpu/gpu0/coreFrequency" }
    S { id: vramUsed; sensorId: "gpu/gpu0/usedVram" }
    S { id: vramTotal; sensorId: "gpu/gpu0/totalVram" }
    S { id: igpu; sensorId: "gpu/gpu1/usage" }
    S { id: cpuFan; sensorId: "lmsensors/asus-isa-0000/fan1" }
    S { id: gpuFan; sensorId: "lmsensors/asus-isa-0000/fan2" }

    function n(s) { return Number(s.value) || 0 }
    readonly property real cpuPct: n(cpu)
    readonly property real memPct: n(memTotal) ? n(memUsed) / n(memTotal) * 100 : 0
    readonly property real gpuPct: n(gpu)
    // the dGPU is "awake" when it does work or draws noticeable power
    readonly property bool gpuActive: gpuPct >= 3 || n(gpuPower) >= 8

    function level(v, warn, crit) { return v >= crit ? 2 : v >= warn ? 1 : 0 }
    function tint(l) { return l === 2 ? Kirigami.Theme.negativeTextColor : l === 1 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor }
    readonly property int cpuLevel: Math.max(level(cpuPct, 85, 97), level(n(cpuTemp), 85, 95))
    readonly property int memLevel: level(memPct, 85, 95)
    readonly property int gpuLevel: Math.max(level(gpuPct, 90, 99), level(n(gpuTemp), 80, 87))

    function gib(b) { return (b / 1073741824).toFixed(b >= 10737418240 ? 0 : 1) + " GiB" }
    function deg(v) { return v > 0 ? Math.round(v) + "°" : "" }

    // --- history -----------------------------------------------------------------------
    property var cpuHist: []
    property var memHist: []
    property var gpuHist: []
    function push(arr, v) { const a = arr.concat([v]); return a.length > historyLength ? a.slice(a.length - historyLength) : a }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.cpuHist = root.push(root.cpuHist, root.cpuPct)
            root.memHist = root.push(root.memHist, root.memPct)
            root.gpuHist = root.push(root.gpuHist, root.gpuPct)
        }
    }

    // --- top processes (only while the popup is open) ---------------------------------
    property var topCpu: []
    property var topMem: []
    P5Support.DataSource {
        id: ps
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const parts = (data.stdout || "").split("@@")
            const rows = t => t.trim().split("\n").filter(l => l.trim()).map(l => {
                const f = l.trim().split(/\s+/)
                return { pcpu: Number(f[0]), rss: Number(f[1]) * 1024, name: f.slice(2).join(" ") }
            })
            root.topCpu = rows(parts[0] || "")
            root.topMem = rows(parts[1] || "")
            disconnectSource(source)
        }
    }
    Timer {
        interval: 2000
        running: root.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: ps.connectSource("ps -eo pcpu=,rss=,comm= --sort=-pcpu | head -5; echo @@; ps -eo pcpu=,rss=,comm= --sort=-rss | head -5")
    }
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source) => disconnectSource(source)
    }
    function run(cmd) { runner.connectSource("PATH=\"$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH\" systemd-run --user --scope --quiet --collect setsid -f " + cmd + " >/dev/null 2>&1") }

    preferredRepresentation: compactRepresentation
    toolTipMainText: "System"
    toolTipSubText: "CPU " + Math.round(cpuPct) + "% " + deg(n(cpuTemp)) + " · RAM " + Math.round(memPct) + "%"
                    + (gpuActive ? " · GPU " + Math.round(gpuPct) + "% " + deg(n(gpuTemp)) : "")

    // --- top bar ---------------------------------------------------------------------------
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
                icon: "exsbe-cpu-symbolic"
                value: Math.round(root.cpuPct) + "%"; widestValue: "88%"
                detail: root.deg(root.n(cpuTemp)); widestDetail: "88°"
                valueColor: root.tint(root.cpuLevel); detailColor: root.tint(root.level(root.n(cpuTemp), 85, 95))
            }
            Chip {
                icon: "exsbe-memory-symbolic"
                value: Math.round(root.memPct) + "%"; widestValue: "88%"
                valueColor: root.tint(root.memLevel)
            }
            // always present so the bar never jumps; dimmed while the dGPU sleeps
            Chip {
                icon: "gpu-symbolic"
                opacity: root.gpuActive ? 1 : 0.45
                value: root.gpuActive ? Math.round(root.gpuPct) + "%" : "–"; widestValue: "88%"
                detail: root.gpuActive ? root.deg(root.n(gpuTemp)) : ""; widestDetail: "88°"
                valueColor: root.tint(root.gpuLevel); detailColor: root.tint(root.level(root.n(gpuTemp), 80, 87))
            }
        }
    }

    // --- popup -------------------------------------------------------------------------
    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: content.implicitHeight + Kirigami.Units.gridUnit * 4
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    level: 3
                    text: "System"
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "utilities-terminal"
                    text: "btop"
                    onClicked: { root.run("kitty --title btop btop"); root.expanded = false }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "utilities-system-monitor"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "System Monitor"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.run("plasma-systemmonitor"); root.expanded = false }
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            Card {
                title: "CPU"
                big: Math.round(root.cpuPct) + "%"
                lvl: root.cpuLevel
                sub: String(cpuName.value || "").replace(/\(R\)|\(TM\)|CPU|@.*$/g, "").replace(/\s+/g, " ").trim()
                history: root.cpuHist
                facts: [
                    ["user", Math.round(root.n(cpuUser)) + "%"], ["system", Math.round(root.n(cpuSystem)) + "%"],
                    ["io wait", Math.round(root.n(cpuWait)) + "%"],
                    ["temp", root.deg(root.n(cpuTemp)) || "–"], ["clock", (root.n(cpuFreq) / 1000).toFixed(1) + " GHz"],
                    ["fan", root.n(cpuFan) ? Math.round(root.n(cpuFan)) + " rpm" : "off"]
                ]
                procs: root.topCpu.map(p => [p.name, p.pcpu.toFixed(0) + "%"])
            }
            Card {
                title: "Memory"
                big: Math.round(root.memPct) + "%"
                lvl: root.memLevel
                sub: root.gib(root.n(memUsed)) + " of " + root.gib(root.n(memTotal))
                history: root.memHist
                stack: root.n(memTotal) ? [root.n(memApp) / root.n(memTotal), root.n(memCache) / root.n(memTotal)] : []
                facts: [
                    ["apps", root.gib(root.n(memApp))], ["cache", root.gib(root.n(memCache))],
                    ["free", root.gib(Math.max(0, root.n(memTotal) - root.n(memUsed)))],
                    ["swap", root.n(swapTotal) ? root.gib(root.n(swapUsed)) + " / " + root.gib(root.n(swapTotal)) : "none"]
                ]
                procs: root.topMem.map(p => [p.name, root.gib(p.rss)])
            }
            Card {
                title: "GPU"
                big: root.gpuActive ? Math.round(root.gpuPct) + "%" : "idle"
                lvl: root.gpuLevel
                sub: String(gpuName.value || "dGPU").replace(/NVIDIA |GeForce |Laptop GPU/g, "").trim()
                history: root.gpuHist
                facts: [
                    ["vram", root.n(vramTotal) ? root.gib(root.n(vramUsed)) + " / " + root.gib(root.n(vramTotal)) : "–"],
                    ["temp", root.deg(root.n(gpuTemp)) || "–"], ["power", root.n(gpuPower) ? Math.round(root.n(gpuPower)) + " W" : "–"],
                    ["clock", root.n(gpuFreq) ? Math.round(root.n(gpuFreq)) + " MHz" : "–"],
                    ["fan", root.n(gpuFan) ? Math.round(root.n(gpuFan)) + " rpm" : "off"],
                    ["iGPU", Math.round(root.n(igpu)) + "%"]
                ]
            }
        }
    }

    // a section: title + big number, history graph (optional stacked bar), facts grid, top processes
    component Card: Rectangle {
        property string title
        property string big
        property string sub
        property int lvl: 0
        property var history: []
        property var stack: []
        property var facts: []
        property var procs: []

        Layout.fillWidth: true
        radius: 12
        color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
        implicitHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                PlasmaComponents3.Label {
                    text: title
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.5
                }
                PlasmaComponents3.Label {
                    text: sub
                    opacity: 0.6
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                }
                Kirigami.Heading {
                    level: 2
                    text: big
                    color: root.tint(lvl)
                    font.features: { "tnum": 1 }
                }
            }

            Graph { values: history; lvl: parent.parent.lvl; Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5 }

            // apps vs cache, for memory
            Rectangle {
                visible: stack.length > 0
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                clip: true
                Row {
                    anchors.fill: parent
                    Rectangle { width: parent.width * (stack[0] || 0); height: parent.height; color: Kirigami.Theme.highlightColor }
                    Rectangle { width: parent.width * (stack[1] || 0); height: parent.height; color: Qt.alpha(Kirigami.Theme.highlightColor, 0.4) }
                }
            }

            GridLayout {
                columns: 3
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: 2
                Layout.fillWidth: true
                Repeater {
                    model: facts
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        PlasmaComponents3.Label { text: modelData[0]; opacity: 0.55; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                        PlasmaComponents3.Label {
                            text: modelData[1]
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            horizontalAlignment: Text.AlignRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            ColumnLayout {
                visible: procs.length > 0
                spacing: 0
                Layout.fillWidth: true
                Layout.topMargin: 2
                Repeater {
                    model: procs
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        PlasmaComponents3.Label {
                            text: modelData[0]
                            elide: Text.ElideRight
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.8
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            text: modelData[1]
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            opacity: 0.65
                        }
                    }
                }
            }
        }
    }

    // area graph of the last minute (0-100)
    component Graph: Canvas {
        property var values: []
        property int lvl: 0
        readonly property color line: lvl ? root.tint(lvl) : Kirigami.Theme.highlightColor
        onValuesChanged: requestPaint()
        onLineChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height, n = root.historyLength
            ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.08)
            ctx.lineWidth = 1
            for (const f of [0.5]) { ctx.beginPath(); ctx.moveTo(0, h * f); ctx.lineTo(w, h * f); ctx.stroke() }
            if (values.length < 2) return
            const x = i => w - (values.length - 1 - i) * (w / (n - 1))
            const y = v => h - 1 - Math.min(100, Math.max(0, v)) / 100 * (h - 2)
            ctx.beginPath()
            ctx.moveTo(x(0), h)
            for (let i = 0; i < values.length; i++) ctx.lineTo(x(i), y(values[i]))
            ctx.lineTo(x(values.length - 1), h)
            ctx.closePath()
            ctx.fillStyle = Qt.alpha(line, 0.18)
            ctx.fill()
            ctx.beginPath()
            for (let i = 0; i < values.length; i++) i ? ctx.lineTo(x(i), y(values[i])) : ctx.moveTo(x(i), y(values[i]))
            ctx.strokeStyle = line
            ctx.lineWidth = 1.5
            ctx.stroke()
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
