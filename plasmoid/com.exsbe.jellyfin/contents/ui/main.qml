// Exsbe Jellyfin: every active stream on the server (all users), how it plays
// (direct play / direct stream / transcode, with codecs and reasons) and from where,
// through `exsbe-jellyfin status`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string env: "PATH=\"$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH\" "

    property var info: ({ sessions: [], online: [] })
    property string error: ""
    property int playing: 0
    property int transcoding: 0

    ListModel { id: streamModel }

    Plasmoid.icon: "video-television"
    toolTipMainText: "Jellyfin"
    toolTipSubText: error !== "" ? error
        : playing === 0 ? "Nothing playing · " + info.online.length + " online"
        : playing + (playing === 1 ? " stream" : " streams") + (transcoding > 0 ? ", " + transcoding + " transcoding" : "")

    preferredRepresentation: compactRepresentation

    function hms(s) {
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = Math.floor(s % 60)
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(sec).padStart(2, "0")
    }
    // "VideoCodecNotSupported" -> "video codec not supported"
    function reason(r) { return r.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase() }

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
        let s
        try { s = JSON.parse(stdout.trim()) } catch (e) { error = "exsbe-jellyfin output could not be read"; return }
        if (s.error) { error = s.error; return }
        error = ""
        info = s
        playing = s.sessions.length
        transcoding = s.transcoding
        // flat rows: ListModel roles are fixed by the first row
        sync(streamModel, s.sessions.map(r => {
            const src = r.source, tc = r.transcode
            const srcText = [src.video, src.audio, src.bitrate, src.container].filter(x => x).join(" · ")
            return {
                key: r.id, title: r.title, subtitle: r.subtitle, image: r.image, itemId: r.itemId,
                user: r.user, device: r.device + (r.client ? " · " + r.client : ""),
                paused: r.paused, position: r.position, runtime: r.runtime,
                method: tc ? "Transcode" : r.method === "DirectStream" ? "Direct stream" : "Direct play",
                how: !tc ? srcText
                    : [tc.video === "copy" ? "video copy" : src.video + " → " + tc.video,
                       tc.audio === "copy" ? "audio copy" : src.audio + " → " + tc.audio,
                       tc.bitrate, tc.hw === "software" ? "CPU" : tc.hw.toUpperCase(),
                       tc.fps ? tc.fps + " fps" : ""].filter(x => x).join(" · "),
                why: tc && tc.reasons.length ? "because " + tc.reasons.map(root.reason).join(", ") : "",
                subs: src.subtitle ? "subtitles: " + src.subtitle : "",
                whereKind: r.where.kind, whereLabel: r.where.label, whereDetail: r.where.detail
            }
        }))
    }

    P5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if ((data.stdout || "").trim() === "") root.error = "exsbe-jellyfin failed: " + (data.stderr || "").trim()
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
    function refresh() { poller.connectSource(env + "exsbe-jellyfin status") }
    function run(cmd) { runner.connectSource(env + "systemd-run --user --scope --quiet --collect setsid -f " + cmd + " >/dev/null 2>&1") }

    Timer {
        interval: root.expanded ? 3000 : 15000
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
                icon: "video-television-symbolic"
                opacity: root.error !== "" || root.playing === 0 ? 0.45 : 1
                value: root.error !== "" ? "–" : String(root.playing)
                valueColor: root.transcoding > 0 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                detail: root.transcoding > 0 ? root.transcoding + " tc" : ""
                detailColor: Kirigami.Theme.neutralTextColor
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    level: 3
                    text: "Jellyfin"
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    opacity: 0.6
                    elide: Text.ElideRight
                    text: root.error !== "" ? "unreachable"
                        : root.playing + " playing" + (root.transcoding ? " · " + root.transcoding + " transcoding" : "")
                          + " · online: " + (root.info.online.join(", ") || "nobody")
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "internet-web-browser"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: "Open Jellyfin"
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.run("exsbe-jellyfin web"); root.expanded = false }
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
                model: streamModel
                clip: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: list.count === 0
                    iconName: "video-television"
                    text: root.error !== "" ? root.error : "Nothing playing"
                    explanation: root.error === "" && root.info.online.length ? "Online: " + root.info.online.join(", ") : ""
                }

                delegate: Item {
                    id: card
                    required property var model
                    width: ListView.view.width
                    implicitHeight: body.implicitHeight + Kirigami.Units.largeSpacing * 2

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        radius: 12
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                    }

                    RowLayout {
                        id: body
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        anchors.leftMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing

                        // poster
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 5.25
                            radius: 8
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: card.model.image
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                opacity: card.model.paused ? 0.5 : 1
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: card.model.paused
                                source: "media-playback-pause"
                                width: Kirigami.Units.iconSizes.medium
                                height: width
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            PlasmaComponents3.Label {
                                text: card.model.title
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                visible: text !== ""
                                text: card.model.subtitle
                                opacity: 0.75
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            // who
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Layout.topMargin: 2
                                Kirigami.Icon {
                                    source: "user-identity"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                PlasmaComponents3.Label {
                                    text: "<b>" + card.model.user + "</b> · " + card.model.device
                                    textFormat: Text.StyledText
                                    font: Kirigami.Theme.smallFont
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            // progress
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 4
                                    radius: 2
                                    color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                                    Rectangle {
                                        width: card.model.runtime ? parent.width * Math.min(1, card.model.position / card.model.runtime) : 0
                                        height: parent.height
                                        radius: parent.radius
                                        color: Kirigami.Theme.highlightColor
                                    }
                                }
                                PlasmaComponents3.Label {
                                    text: root.hms(card.model.position) + (card.model.runtime ? " / " + root.hms(card.model.runtime) : "")
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.65
                                }
                            }
                            // how
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Layout.topMargin: 2
                                Rectangle {
                                    readonly property color c: card.model.method === "Transcode" ? Kirigami.Theme.neutralTextColor
                                        : card.model.method === "Direct stream" ? Kirigami.Theme.highlightColor : Kirigami.Theme.positiveTextColor
                                    radius: height / 2
                                    color: Qt.alpha(c, 0.18)
                                    implicitWidth: chip.implicitWidth + Kirigami.Units.largeSpacing
                                    implicitHeight: chip.implicitHeight + 2
                                    PlasmaComponents3.Label {
                                        id: chip
                                        anchors.centerIn: parent
                                        text: card.model.method
                                        color: parent.c
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        font.weight: Font.DemiBold
                                    }
                                }
                                PlasmaComponents3.Label {
                                    text: card.model.how
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.8
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            PlasmaComponents3.Label {
                                visible: text !== ""
                                text: card.model.why
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.neutralTextColor
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                visible: text !== ""
                                text: card.model.subs
                                font: Kirigami.Theme.smallFont
                                opacity: 0.55
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            // where
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Layout.topMargin: 2
                                Kirigami.Icon {
                                    source: ({ lan: "go-home", tailscale: "network-vpn", wan: "globe", proxy: "dialog-warning" })[card.model.whereKind] || "network-wired"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                PlasmaComponents3.Label {
                                    text: card.model.whereLabel
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.weight: Font.DemiBold
                                    color: card.model.whereKind === "proxy" ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                                }
                                PlasmaComponents3.Label {
                                    text: card.model.whereDetail
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
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
