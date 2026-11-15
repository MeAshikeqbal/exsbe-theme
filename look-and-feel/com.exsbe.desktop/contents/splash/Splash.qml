// Exsbe splash (after login). The same animation as the boot splash (plymouth/exsbe/exsbe.script):
// the five bars slide in along their own 17.63° axis from alternating sides, the wordmark rises
// into place along its italic slant, then a soft light runs down the bars while Plasma loads.
// Everything is a function of one clock, t (seconds), so both splashes stay frame-for-frame alike.
import QtQuick

Rectangle {
    id: root
    color: "#18181b"

    property int stage   // set by ksplash; the animation does not wait for it

    // --- timing (keep in step with exsbe.script) ---------------------------------------------
    readonly property real dirX: 0.953    // the bars' long axis: cos / sin 17.63°
    readonly property real dirY: 0.303
    property real t: 0
    NumberAnimation on t { from: 0; to: 3600; duration: 3600 * 1000; running: true }

    function clamp01(x) { return Math.max(0, Math.min(1, x)) }
    function easeOut(p) { const q = 1 - clamp01(p); return 1 - q * q * q }
    // bar i (0 = top): starts at 0.15 + 0.12 i s, takes 0.7 s, from alternating ends of its axis
    function barP(i) { return easeOut((t - 0.15 - 0.12 * i) / 0.7) }
    function barShift(i) { return (1 - barP(i)) * (i % 2 ? 1 : -1) * 0.18 * logo.width }
    // after the intro, a light runs down the bars every 2.2 s
    function barGlow(i) {
        const idle = clamp01((t - 1.8) / 0.6)
        const c = Math.cos((t - 1.8) * 2 * Math.PI / 2.2 - i * 0.8)
        const w = c > 0 ? c * c : 0
        return (1 - idle) + idle * (0.6 + 0.4 * w)
    }
    // wordmark shape j (0 = left): rises along the italic slant from 0.8 + 0.09 j s, in 0.6 s
    function wordP(j) { return easeOut((t - 0.8 - 0.09 * j) / 0.6) }
    function wordShift(j) { return (1 - wordP(j)) * 0.22 * logo.height }

    Image {
        anchors.fill: parent
        source: "images/background.png"
        fillMode: Image.PreserveAspectCrop
    }

    Item {
        id: logo
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.34)
        height: Math.round(width * 354 / 1357)   // the lockup's proportions (plymouth/logo.svg)

        Repeater {
            model: 5
            Image {
                required property int index
                anchors.fill: parent
                source: "images/bar-" + (index + 1) + ".png"
                smooth: true
                mipmap: true
                opacity: root.barP(index) * root.barGlow(index)
                transform: Translate { x: root.barShift(index) * root.dirX; y: root.barShift(index) * root.dirY }
            }
        }
        Repeater {
            model: 4
            Image {
                required property int index
                anchors.fill: parent
                source: "images/word-" + (index + 1) + ".png"
                smooth: true
                mipmap: true
                opacity: root.wordP(index) * 0.95
                transform: Translate { x: -root.wordShift(index) * root.dirY; y: root.wordShift(index) * root.dirX }
            }
        }
    }
}
