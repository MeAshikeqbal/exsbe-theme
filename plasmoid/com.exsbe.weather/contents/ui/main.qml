// Exsbe weather: current conditions and a 7-day forecast from Open-Meteo (no API key),
// drawn on the theme's desktop card with monochrome weather icons.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // set in the widget's settings (right-click > Configure)
    readonly property string place: Plasmoid.configuration.place || "Set a location"
    readonly property real latitude: Plasmoid.configuration.latitude
    readonly property real longitude: Plasmoid.configuration.longitude
    readonly property bool located: Plasmoid.configuration.latitude !== 0 || Plasmoid.configuration.longitude !== 0
    onLatitudeChanged: refresh()
    onLongitudeChanged: refresh()

    property var now: null
    property var days: []
    property string error: ""
    property date updated: new Date(0)

    preferredRepresentation: fullRepresentation
    toolTipMainText: place
    toolTipSubText: now ? Math.round(now.temperature_2m) + "° · " + describe(now.weather_code) : ""

    // WMO weather code -> [label, icon]
    function info(code, day) {
        const n = day === 0 ? "-night" : ""
        if (code === 0) return ["Clear", "weather-clear" + n + "-symbolic"]
        if (code <= 2) return [code === 1 ? "Mostly clear" : "Partly cloudy", "weather-few-clouds" + n + "-symbolic"]
        if (code === 3) return ["Overcast", "weather-overcast-symbolic"]
        if (code === 45 || code === 48) return ["Fog", "weather-fog-symbolic"]
        if (code >= 51 && code <= 57) return ["Drizzle", "weather-showers-scattered-symbolic"]
        if (code === 66 || code === 67) return ["Freezing rain", "weather-freezing-rain-symbolic"]
        if (code >= 61 && code <= 65) return [code === 65 ? "Heavy rain" : "Rain", "weather-showers-symbolic"]
        if (code >= 80 && code <= 82) return ["Showers", "weather-showers-scattered-symbolic"]
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return ["Snow", "weather-snow-symbolic"]
        if (code >= 95) return ["Thunderstorm", "weather-storm-symbolic"]
        return ["–", "weather-clouds-symbolic"]
    }
    function describe(code) { return info(code, 1)[0] }

    function refresh() {
        if (!located) { error = "right-click > Configure to set a location"; return }
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=7"
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { error = "weather unavailable"; return }
            try {
                const d = JSON.parse(xhr.responseText)
                now = d.current
                days = d.daily.time.map((t, i) => ({
                    date: new Date(t + "T12:00:00"), code: d.daily.weather_code[i],
                    max: d.daily.temperature_2m_max[i], min: d.daily.temperature_2m_min[i],
                    rain: d.daily.precipitation_probability_max[i]
                }))
                error = ""
                updated = new Date()
            } catch (e) { error = "weather unavailable" }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    Timer {
        interval: 20 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // header
            RowLayout {
                PlasmaComponents3.Label {
                    text: root.place
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2
                    font.weight: Font.DemiBold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.5
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: root.error !== "" ? root.error : root.updated.getTime() > 0 ? Qt.formatTime(root.updated, "hh:mm") : ""
                    font: Kirigami.Theme.smallFont
                    opacity: 0.4
                }
            }

            // now
            RowLayout {
                spacing: Kirigami.Units.gridUnit
                Kirigami.Icon {
                    source: root.now ? root.info(root.now.weather_code, root.now.is_day)[1] : "weather-clouds-symbolic"
                    isMask: true
                    color: Kirigami.Theme.textColor
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                }
                ColumnLayout {
                    spacing: 0
                    PlasmaComponents3.Label {
                        text: root.now ? Math.round(root.now.temperature_2m) + "°" : "–"
                        font.pixelSize: Kirigami.Units.gridUnit * 3
                        font.weight: Font.Light
                        font.features: { "tnum": 1 }
                    }
                    PlasmaComponents3.Label {
                        text: root.now ? root.info(root.now.weather_code, root.now.is_day)[0] : ""
                        font.weight: Font.DemiBold
                    }
                }
                Item { Layout.fillWidth: true }
                GridLayout {
                    columns: 2
                    rowSpacing: 2
                    columnSpacing: Kirigami.Units.largeSpacing
                    Repeater {
                        model: root.now ? [
                            ["feels", Math.round(root.now.apparent_temperature) + "°"],
                            ["humidity", Math.round(root.now.relative_humidity_2m) + "%"],
                            ["wind", Math.round(root.now.wind_speed_10m) + " km/h"]
                        ] : []
                        delegate: RowLayout {
                            required property var modelData
                            Layout.columnSpan: 2
                            PlasmaComponents3.Label { text: modelData[0]; opacity: 0.5; font: Kirigami.Theme.smallFont; Layout.fillWidth: true }
                            PlasmaComponents3.Label { text: modelData[1]; font.pointSize: Kirigami.Theme.smallFont.pointSize; font.features: { "tnum": 1 } }
                        }
                    }
                }
            }

            // forecast
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Repeater {
                    model: root.days
                    delegate: ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents3.Label {
                            text: index === 0 ? "Today" : Qt.formatDate(modelData.date, "ddd")
                            font: Kirigami.Theme.smallFont
                            opacity: index === 0 ? 1 : 0.6
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Kirigami.Icon {
                            source: root.info(modelData.code, 1)[1]
                            isMask: true
                            color: Kirigami.Theme.textColor
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PlasmaComponents3.Label {
                            text: Math.round(modelData.max) + "°"
                            font.features: { "tnum": 1 }
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PlasmaComponents3.Label {
                            text: Math.round(modelData.min) + "°"
                            opacity: 0.5
                            font: Kirigami.Theme.smallFont
                            Layout.alignment: Qt.AlignHCenter
                        }
                        PlasmaComponents3.Label {
                            text: modelData.rain > 0 ? modelData.rain + "%" : ""
                            color: Kirigami.Theme.highlightColor
                            font: Kirigami.Theme.smallFont
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
