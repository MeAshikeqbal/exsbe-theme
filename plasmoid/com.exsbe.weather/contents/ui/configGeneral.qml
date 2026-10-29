// Weather location: a name to show, and the coordinates Open-Meteo is asked about.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_place: place.text
    property real cfg_latitude
    property real cfg_longitude

    Kirigami.FormLayout {
        QQC2.TextField {
            id: place
            Kirigami.FormData.label: "Place:"
            placeholderText: "shown on the card"
        }
        QQC2.TextField {
            Kirigami.FormData.label: "Latitude:"
            text: cfg_latitude
            validator: DoubleValidator { bottom: -90; top: 90 }
            onTextEdited: cfg_latitude = Number(text)
        }
        QQC2.TextField {
            Kirigami.FormData.label: "Longitude:"
            text: cfg_longitude
            validator: DoubleValidator { bottom: -180; top: 180 }
            onTextEdited: cfg_longitude = Number(text)
        }
    }
}
