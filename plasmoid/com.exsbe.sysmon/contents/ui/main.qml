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

    // --- history (memory changes too slowly to be worth a graph) --------------------------
    property var cpuHist: []
    property var gpuHist: []
    function push(arr, v) { const a = arr.concat([v]); return a.length > historyLength ? a.slice(a.length - historyLength) : a }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.cpuHist = root.push(root.cpuHist, root.cpuPct)
            root.gpuHist = root.push(root.gpuHist, root.gpuPct)
        }
    }

    // --- top processes (only while the popup is open) ---------------------------------
    // CPU is measured between two samples of /proc/*/stat (ps reports a lifetime average), as a
    // share of the whole machine like the CPU total above, and summed per program: an app's
    // helper processes count as one row ("brave ×14").
    property var topCpu: []
    property var topMem: []
    property var prevTicks: ({})
    property real prevTime: 0
    onExpandedChanged: if (!root.expanded) { prevTicks = {}; prevTime = 0; topCpu = [] }
    function parseProcs(stdout) {
        const now = Date.now() / 1000, ticks = {}, apps = {}
        for (const line of stdout.split("\n")) {
            const a = line.indexOf("("), b = line.lastIndexOf(")")
            if (a < 0 || b < a) continue
            const pid = line.slice(0, a).trim(), name = line.slice(a + 1, b)
            const f = line.slice(b + 2).split(" ")   // f[0] is field 3 (state)
            const t = Number(f[11]) + Number(f[12])  // utime + stime, in clock ticks (100/s)
            const rss = Number(f[21]) * 4096
            if (!(rss > 0) && !(t > 0)) continue
            ticks[pid] = t
            const app = apps[name] || (apps[name] = { name: name, cpu: 0, rss: 0, count: 0 })
            app.rss += rss
            app.count++
            if (pid in prevTicks) app.cpu += Math.max(0, t - prevTicks[pid])
        }
        const list = Object.values(apps)
        topMem = list.slice().sort((x, y) => y.rss - x.rss).slice(0, 5)
        if (prevTime > 0) {
            const scale = 100 / (100 * (now - prevTime) * Math.max(1, n(cpuCores)))
            for (const app of list) app.cpu *= scale
            topCpu = list.filter(x => x.cpu >= 0.05).sort((x, y) => y.cpu - x.cpu).slice(0, 5)
        }
        prevTicks = ticks
        prevTime = now
    }
    P5Support.DataSource {
        id: ps
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => { root.parseProcs(data.stdout || ""); disconnectSource(source) }
    }
    Timer {
        // a quick second sample after opening, so the CPU list fills in at once
        interval: root.prevTime > 0 ? 2000 : 400
        running: root.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: ps.connectSource("cat /proc/[0-9]*/stat 2>/dev/null")
    }
    function pctText(v) { return v < 9.95 ? v.toFixed(1) + "%" : Math.round(v) + "%" }
    // "0.2 / 8 GiB": one unit for a used / total pair
    function pair(used, total) {
        const g = b => b / 1073741824
        const f = v => v >= 10 ? String(Math.round(v)) : v < 0.05 ? "0" : String(Math.round(v * 10) / 10)
        return f(g(used)) + " / " + f(g(total)) + " GiB"
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
                    icon.name: "utilities-terminal-symbolic"
                    text: "btop"
                    onClicked: { root.run("kitty --title btop btop"); root.expanded = false }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "utilities-system-monitor-symbolic"
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
                sub: root.n(cpuCores) ? root.n(cpuCores) + " threads" : ""
                history: root.cpuHist
                facts: [
                    ["user", Math.round(root.n(cpuUser)) + "%"], ["system", Math.round(root.n(cpuSystem)) + "%"],
                    ["io wait", Math.round(root.n(cpuWait)) + "%"],
                    ["temp", root.deg(root.n(cpuTemp)) || "–"], ["clock", (root.n(cpuFreq) / 1000).toFixed(1) + " GHz"],
                    ["fan", root.n(cpuFan) ? Math.round(root.n(cpuFan)) + " rpm" : "off"]
                ]
                procs: root.topCpu.map(p => [p.name, root.pctText(p.cpu), p.count])
                procsTitle: "using the cpu now"
            }
            Card {
                title: "Memory"
                big: Math.round(root.memPct) + "%"
                lvl: root.memLevel
                sub: root.pair(root.n(memUsed), root.n(memTotal))
                graph: false
                stack: root.n(memTotal) ? [root.n(memApp) / root.n(memTotal), root.n(memCache) / root.n(memTotal)] : []
                facts: [
                    ["apps", root.gib(root.n(memApp)), Kirigami.Theme.highlightColor],
                    ["cache", root.gib(root.n(memCache)), Qt.alpha(Kirigami.Theme.highlightColor, 0.4)],
                    ["free", root.gib(Math.max(0, root.n(memTotal) - root.n(memUsed))), Qt.alpha(Kirigami.Theme.textColor, 0.15)],
                    ["swap", root.n(swapTotal) ? root.pair(root.n(swapUsed), root.n(swapTotal)) : "none"]
                ]
                procs: root.topMem.map(p => [p.name, root.gib(p.rss), p.count])
                procsTitle: "using the most memory"
            }
            Card {
                title: "GPU"
                big: root.gpuActive ? Math.round(root.gpuPct) + "%" : "idle"
                bigDim: !root.gpuActive
                lvl: root.gpuLevel
                sub: String(gpuName.value || "dGPU").replace(/NVIDIA |GeForce |Laptop GPU/g, "").trim()
                history: root.gpuHist
                facts: [
                    ["vram", root.n(vramTotal) ? root.pair(root.n(vramUsed), root.n(vramTotal)) : "–"],
                    ["temp", root.deg(root.n(gpuTemp)) || "–"], ["power", root.n(gpuPower) ? Math.round(root.n(gpuPower)) + " W" : "–"],
                    ["clock", root.n(gpuFreq) ? Math.round(root.n(gpuFreq)) + " MHz" : "–"],
                    ["fan", root.n(gpuFan) ? Math.round(root.n(gpuFan)) + " rpm" : "off"],
                    ["iGPU", Math.round(root.n(igpu)) + "%"]
                ]
            }
        }
    }

    // a section: title + big number, history graph (or a stacked bar), facts grid, top processes
    component Card: Rectangle {
        id: card
        property string title
        property string big
        property bool bigDim: false
        property string sub
        property int lvl: 0
        property bool graph: true
        property var history: []
        property var stack: []
        property var facts: []       // [label, value, optional legend colour]
        property var procs: []       // [name, value, process count]
        property string procsTitle: ""

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
                    text: card.title
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.5
                }
                PlasmaComponents3.Label {
                    text: card.sub
                    opacity: 0.6
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    Layout.fillWidth: true
                }
                Kirigami.Heading {
                    level: 2
                    text: card.big
                    color: root.tint(card.lvl)
                    opacity: card.bigDim ? 0.5 : 1
                    font.features: { "tnum": 1 }
                }
            }

            Graph {
                visible: card.graph
                values: card.history
                lvl: card.lvl
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
            }

            // apps | cache | free, for memory (colours match the dots in the facts below)
            Rectangle {
                visible: card.stack.length > 0
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                height: 8
                radius: 4
                color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                clip: true
                Row {
                    anchors.fill: parent
                    spacing: 0
                    Rectangle { width: parent.width * (card.stack[0] || 0); height: parent.height; color: Kirigami.Theme.highlightColor
                                Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } } }
                    Rectangle { width: parent.width * (card.stack[1] || 0); height: parent.height; color: Qt.alpha(Kirigami.Theme.highlightColor, 0.4)
                                Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } } }
                }
            }

            GridLayout {
                columns: 3
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: 2
                Layout.fillWidth: true
                Repeater {
                    model: card.facts
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 4
                        Rectangle {
                            visible: modelData.length > 2
                            width: 6; height: 6; radius: 3
                            color: modelData[2] || "transparent"
                        }
                        PlasmaComponents3.Label { text: modelData[0]; opacity: 0.55; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                        PlasmaComponents3.Label {
                            text: modelData[1]
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // top processes, grouped per program
            Rectangle {
                visible: card.procsTitle !== ""
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                height: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
            }
            PlasmaComponents3.Label {
                visible: card.procsTitle !== ""
                text: card.procs.length ? card.procsTitle : "measuring…"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.4
            }
            ColumnLayout {
                visible: card.procs.length > 0
                spacing: 0
                Layout.fillWidth: true
                Repeater {
                    model: card.procs
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        PlasmaComponents3.Label {
                            text: modelData[0]
                            elide: Text.ElideRight
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.85
                            Layout.maximumWidth: col.width * 0.65
                        }
                        PlasmaComponents3.Label {
                            visible: modelData[2] > 1
                            text: "×" + modelData[2]
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            opacity: 0.35
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents3.Label {
                            text: modelData[1]
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.features: { "tnum": 1 }
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }

    // area graph of the last minute. The scale grows with the data (10 / 25 / 50 / 100 %) so
    // light load still shows its shape; the ceiling is labelled when it is below 100.
    component Graph: Canvas {
        id: graph
        property var values: []
        property int lvl: 0
        readonly property color line: lvl ? root.tint(lvl) : Kirigami.Theme.highlightColor
        readonly property real ceiling: {
            const peak = values.length ? Math.max.apply(null, values) : 0
            return [10, 25, 50, 100].find(c => c >= peak * 1.15) || 100
        }
        onValuesChanged: requestPaint()
        onLineChanged: requestPaint()
        onCeilingChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height, n = root.historyLength
            ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.07)
            ctx.lineWidth = 1
            for (const f of [0, 0.5]) { ctx.beginPath(); ctx.moveTo(0, Math.round(h * f) + 0.5); ctx.lineTo(w, Math.round(h * f) + 0.5); ctx.stroke() }
            if (values.length < 2) return
            const x = i => w - (values.length - 1 - i) * (w / (n - 1))
            const y = v => h - 1 - Math.min(ceiling, Math.max(0, v)) / ceiling * (h - 3)
            ctx.beginPath()
            ctx.moveTo(x(0), h)
            for (let i = 0; i < values.length; i++) ctx.lineTo(x(i), y(values[i]))
            ctx.lineTo(x(values.length - 1), h)
            ctx.closePath()
            const grad = ctx.createLinearGradient(0, 0, 0, h)
            grad.addColorStop(0, Qt.alpha(line, 0.30))
            grad.addColorStop(1, Qt.alpha(line, 0.02))
            ctx.fillStyle = grad
            ctx.fill()
            ctx.beginPath()
            for (let i = 0; i < values.length; i++) i ? ctx.lineTo(x(i), y(values[i])) : ctx.moveTo(x(i), y(values[i]))
            ctx.strokeStyle = line
            ctx.lineWidth = 1.5
            ctx.lineJoin = "round"
            ctx.stroke()
        }
        PlasmaComponents3.Label {
            visible: graph.ceiling < 100
            anchors.top: parent.top
            anchors.left: parent.left
            text: graph.ceiling + "%"
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
            font.features: { "tnum": 1 }
            opacity: 0.35
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
