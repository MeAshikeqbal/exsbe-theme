// Exsbe network: download / upload rate, a one-minute graph of both and session totals,
// from Plasma's ksystemstats sensors, drawn on the theme's desktop card.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int historyLength: 60
    readonly property color downColor: "#7fa8d6"
    readonly property color upColor: "#b494d6"

    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: 1000 }
    Sensors.Sensor { id: up; sensorId: "network/all/upload"; updateRateLimit: 1000 }
    Sensors.Sensor { id: totalDown; sensorId: "network/all/totalDownload"; updateRateLimit: 5000 }
    Sensors.Sensor { id: totalUp; sensorId: "network/all/totalUpload"; updateRateLimit: 5000 }

    property var downHist: []
    property var upHist: []
    function push(arr, v) { const a = arr.concat([v]); return a.length > historyLength ? a.slice(a.length - historyLength) : a }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.downHist = root.push(root.downHist, Number(down.value) || 0)
            root.upHist = root.push(root.upHist, Number(up.value) || 0)
        }
    }

    // bytes/s -> "12.4 Mbit/s"; bytes -> "8.9 GiB"
    function rate(b) {
        const bits = b * 8
        return bits >= 1e9 ? (bits / 1e9).toFixed(1) + " Gbit/s" : bits >= 1e6 ? (bits / 1e6).toFixed(1) + " Mbit/s"
             : bits >= 1e3 ? Math.round(bits / 1e3) + " kbit/s" : Math.round(bits) + " bit/s"
    }
    function size(b) {
        return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GiB" : b >= 1048576 ? Math.round(b / 1048576) + " MiB" : Math.round(b / 1024) + " KiB"
    }

    preferredRepresentation: fullRepresentation
    toolTipMainText: "Network"
    toolTipSubText: "↓ " + rate(Number(down.value) || 0) + "   ↑ " + rate(Number(up.value) || 0)

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 14

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                text: "Network"
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
            }

            RowLayout {
                spacing: Kirigami.Units.gridUnit * 2
                Rate { arrow: "↓"; label: "download"; value: Number(down.value) || 0; total: Number(totalDown.value) || 0; tint: root.downColor }
                Rate { arrow: "↑"; label: "upload"; value: Number(up.value) || 0; total: Number(totalUp.value) || 0; tint: root.upColor }
                Item { Layout.fillWidth: true }
            }

            // both rates on one graph, scaled to the busier one
            Canvas {
                id: graph
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 3
                readonly property var series: [[root.downHist, root.downColor], [root.upHist, root.upColor]]
                onSeriesChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, n = root.historyLength
                    ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.08)
                    ctx.lineWidth = 1
                    for (const f of [0.25, 0.5, 0.75]) { ctx.beginPath(); ctx.moveTo(0, h * f); ctx.lineTo(w, h * f); ctx.stroke() }
                    const peak = Math.max(1024, ...root.downHist, ...root.upHist)
                    for (const [vals, col] of series) {
                        if (vals.length < 2) continue
                        const x = i => w - (vals.length - 1 - i) * (w / (n - 1))
                        const y = v => h - 1 - (v / peak) * (h - 2)
                        ctx.beginPath()
                        ctx.moveTo(x(0), h)
                        for (let i = 0; i < vals.length; i++) ctx.lineTo(x(i), y(vals[i]))
                        ctx.lineTo(x(vals.length - 1), h)
                        ctx.closePath()
                        ctx.fillStyle = Qt.alpha(col, 0.15)
                        ctx.fill()
                        ctx.beginPath()
                        for (let i = 0; i < vals.length; i++) i ? ctx.lineTo(x(i), y(vals[i])) : ctx.moveTo(x(i), y(vals[i]))
                        ctx.strokeStyle = col
                        ctx.lineWidth = 1.5
                        ctx.stroke()
                    }
                    // scale label
                    ctx.fillStyle = Qt.alpha(Kirigami.Theme.textColor, 0.4)
                    ctx.font = Kirigami.Theme.smallFont.pixelSize + "px sans-serif"
                    ctx.fillText(root.rate(peak), 4, 12)
                }
            }
        }
    }

    component Rate: ColumnLayout {
        property string arrow
        property string label
        property real value
        property real total
        property color tint
        spacing: 0
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents3.Label { text: arrow; color: tint; font.weight: Font.Bold }
            PlasmaComponents3.Label {
                text: root.rate(value)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                font.features: { "tnum": 1 }
            }
        }
        PlasmaComponents3.Label {
            text: label + " · " + root.size(total) + " this session"
            font: Kirigami.Theme.smallFont
            opacity: 0.5
        }
    }
}
