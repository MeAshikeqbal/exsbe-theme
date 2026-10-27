// Exsbe workspaces: the current workspace shows icon + name in an accent pill,
// the others collapse to their icon (dimmed when no windows are on them).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // workspace name -> icon; unknown names fall back to the generic icon
    readonly property var icons: ({
        "Code": "code-context-symbolic",
        "Web": "globe-symbolic",
        "Lab": "network-server-symbolic",
        "Play": "input-gaming-symbolic"
    })
    readonly property string fallbackIcon: "virtual-desktops"

    property var occupied: ({})

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    TaskManager.VirtualDesktopInfo { id: desktops }

    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: false
        filterByActivity: true
        filterByScreen: false
        onCountChanged: root.recount()
        onDataChanged: root.recount()
    }

    Component.onCompleted: recount()

    function recount() {
        const used = {}
        for (let i = 0; i < tasks.count; i++) {
            const idx = tasks.index(i, 0)
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops)) continue
            for (const id of tasks.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops) || [])
                used[id] = true
        }
        occupied = used
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source) => disconnectSource(source)
    }

    function activate(id) {
        runner.connectSource("busctl --user set-property org.kde.KWin /VirtualDesktopManager "
                             + "org.kde.KWin.VirtualDesktopManager current s " + id)
    }

    function step(delta) {
        const ids = desktops.desktopIds
        const i = ids.indexOf(desktops.currentDesktop)
        activate(ids[(i + delta + ids.length) % ids.length])
    }

    fullRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => root.step(wheel.angleDelta.y > 0 ? -1 : 1)

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: desktops.desktopIds

                delegate: MouseArea {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property string name: desktops.desktopNames[index] || ""
                    readonly property bool current: modelData === desktops.currentDesktop
                    readonly property bool used: root.occupied[modelData] === true

                    Layout.preferredHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 3
                    Layout.preferredWidth: content.implicitWidth + Kirigami.Units.smallSpacing * (current ? 5 : 3)
                    hoverEnabled: true
                    onClicked: root.activate(modelData)

                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }

                    PlasmaComponents3.ToolTip.text: name
                    PlasmaComponents3.ToolTip.visible: containsMouse && !current
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay

                    // soft glow in the wallpaper accent behind the current pill
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: height / 2
                        color: Kirigami.Theme.highlightColor
                        opacity: cell.current ? 0.14 : 0
                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: cell.current ? Kirigami.Theme.highlightColor
                             : cell.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.12)
                             : "transparent"
                        opacity: cell.current ? 0.35 : 1
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.7)
                        visible: cell.current
                    }

                    RowLayout {
                        id: content
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: root.icons[cell.name] || root.fallbackIcon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            isMask: true
                            color: Kirigami.Theme.textColor
                            opacity: cell.current || cell.used || cell.containsMouse ? 1 : 0.45
                        }
                        PlasmaComponents3.Label {
                            visible: cell.current
                            text: cell.name
                            font.weight: Font.DemiBold
                        }
                    }

                    // small dot under workspaces that have windows
                    Rectangle {
                        visible: cell.used && !cell.current
                        width: 3; height: 3; radius: 1.5
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                    }
                }
            }
        }
    }
}
