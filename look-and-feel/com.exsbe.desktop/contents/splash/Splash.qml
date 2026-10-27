// Exsbe login splash: same background, logo and breathing pulse as the Plymouth boot theme.
import QtQuick

Rectangle {
    id: root
    color: "#262629"

    property int stage

    onStageChanged: {
        if (stage == 2) pulse.start()
    }

    Image {
        anchors.fill: parent
        source: "images/background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Image {
        id: logo
        anchors.centerIn: parent
        source: "images/logo.png"
        asynchronous: true
        opacity: 0

        SequentialAnimation {
            id: pulse
            NumberAnimation { target: logo; property: "opacity"; from: 0; to: 1; duration: 400 }
            SequentialAnimation {
                loops: Animation.Infinite
                NumberAnimation { target: logo; property: "opacity"; to: 0.56; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 1100; easing.type: Easing.InOutSine }
            }
        }
    }
}
