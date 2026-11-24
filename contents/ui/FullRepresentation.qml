import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: full
    property var m

    readonly property real u: Kirigami.Units.gridUnit
    readonly property real pad: Kirigami.Units.largeSpacing * 1.5
    readonly property color subtle: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.07)

    Layout.minimumWidth: u * 23
    Layout.preferredWidth: u * 23
    Layout.minimumHeight: col.implicitHeight + pad * 2
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

    // ---- building blocks ---------------------------------------------------
    component SectionTitle: PlasmaComponents.Label {
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
        opacity: 0.55
        Layout.topMargin: Kirigami.Units.smallSpacing
    }

    component Field: ColumnLayout {
        property alias label: l.text
        property alias value: v.text
        property alias valueColor: v.color
        spacing: 0
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        PlasmaComponents.Label {
            id: l
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
            opacity: 0.6
        }
        PlasmaComponents.Label {
            id: v
            font.features: { "tnum": 1 }
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component Tile: Rectangle {
        property string title
        property string value
        property string detail
        property color accent: Kirigami.Theme.textColor
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: tc.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.07)
        ColumnLayout {
            id: tc
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Kirigami.Units.largeSpacing }
            spacing: 0
            PlasmaComponents.Label {
                text: title
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                opacity: 0.6
            }
            PlasmaComponents.Label {
                text: value
                color: accent
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            PlasmaComponents.Label {
                text: detail
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                opacity: 0.6
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    component LegendDot: RowLayout {
        property alias text: lt.text
        property color dot
        spacing: Kirigami.Units.smallSpacing
        Rectangle { width: 8; height: 8; radius: 4; color: dot }
        PlasmaComponents.Label { id: lt; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85; opacity: 0.7 }
    }

    // ---- layout ------------------------------------------------------------
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: full.pad }
        spacing: Kirigami.Units.largeSpacing

        // Header: big live wattage + percentage
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 0
                PlasmaComponents.Label {
                    text: m.headline
                    color: m.stateColor
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.3
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                PlasmaComponents.Label {
                    text: m.subline
                    opacity: 0.7
                }
                RowLayout {
                    visible: m.profileIcon !== ""
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: m.profileIcon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: i18n("Power profile: %1", m.profileName)
                        opacity: 0.7
                    }
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 0
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: m.percent + "%"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: isNaN(m.energyNowWh) ? "" : m.energyNowWh.toFixed(1) + " / " + m.energyFullWh.toFixed(1) + " Wh"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                    font.features: { "tnum": 1 }
                    opacity: 0.6
                }
            }
        }

        // Charge level bar
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: -Kirigami.Units.smallSpacing
            implicitHeight: 6
            radius: 3
            color: full.subtle
            Rectangle {
                width: parent.width * Math.min(100, m.percent) / 100
                height: parent.height
                radius: 3
                color: m.charging ? Kirigami.Theme.positiveTextColor
                     : m.discharging && m.percent <= 20 ? Kirigami.Theme.negativeTextColor
                     : m.discharging ? Kirigami.Theme.neutralTextColor
                     : Kirigami.Theme.highlightColor
                Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }
        }

        // Power flow tiles
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Tile {
                title: i18n("Charger")
                value: m.pluggedIn ? (isNaN(m.chargerMaxW) ? i18n("AC") : Math.round(m.chargerMaxW) + " W") : "—"
                detail: !m.pluggedIn ? i18n("Unplugged")
                      : isNaN(m.contractV) ? i18n("Connected")
                      : m.contractV.toFixed(0) + " V · " + m.contractA.toFixed(1) + " A"
                opacity: m.pluggedIn ? 1 : 0.55
            }
            Tile {
                title: i18n("System")
                value: m.fmtW(m.systemW)
                detail: m.psysAvailable ? i18n("whole laptop") : m.discharging ? i18n("from battery") : i18n("unavailable")
                accent: Kirigami.Theme.highlightColor
            }
            Tile {
                title: i18n("Battery")
                value: m.charging || m.discharging ? m.fmtSigned(m.batteryW) : "0.0 W"
                detail: m.charging ? i18n("charging") : m.discharging ? i18n("discharging") : i18n("idle")
                accent: m.stateColor
            }
        }

        // Live chart
        RowLayout {
            Layout.fillWidth: true
            SectionTitle { text: i18n("Last 10 minutes") }
            Item { Layout.fillWidth: true }
            LegendDot { text: i18n("Battery"); dot: m.stateColor }
            LegendDot { text: i18n("System"); dot: Kirigami.Theme.highlightColor; visible: m.psysAvailable || m.discharging }
        }
        Chart {
            Layout.fillWidth: true
            Layout.preferredHeight: full.u * 5
            seriesA: m.historyBattery
            seriesB: m.historySystem
            capacity: m.historyLength
            colorA: m.stateColor
        }

        // Battery details
        SectionTitle { text: i18n("Battery") }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing * 2
            Field {
                label: i18n("Health")
                value: isNaN(m.healthPct) ? "—" : Math.round(m.healthPct) + "% · " + m.condition
                valueColor: m.healthPct < 60 ? Kirigami.Theme.negativeTextColor
                          : m.healthPct < 80 ? Kirigami.Theme.neutralTextColor
                          : Kirigami.Theme.textColor
            }
            Field { label: i18n("Cycles"); value: m.cycles >= 0 ? m.cycles : "—" }
            Field { label: i18n("Temperature"); value: isNaN(m.tempC) ? "—" : m.tempC.toFixed(1) + " °C" }
            Field {
                label: i18n("Capacity")
                value: isNaN(m.energyFullWh) ? "—" : i18n("%1 Wh (design %2)", m.energyFullWh.toFixed(1), m.energyDesignWh.toFixed(1))
                Layout.columnSpan: 2
                Layout.preferredWidth: 2
            }
            Field {
                label: i18n("Voltage · current")
                value: isNaN(m.voltage) ? "—" : m.voltage.toFixed(2) + " V · " + (isNaN(m.current) ? "—" : m.current.toFixed(2) + " A")
            }
        }

        // Charger details
        SectionTitle { text: i18n("Charger"); visible: m.pluggedIn }
        GridLayout {
            visible: m.pluggedIn
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing * 2
            Field {
                label: i18n("Negotiated")
                value: isNaN(m.negotiatedW) ? "—" : Math.round(m.negotiatedW) + " W"
            }
            Field {
                label: i18n("Protocol")
                value: m.pdos.length ? "USB-PD" + (m.pdRevision ? " " + m.pdRevision : "") : (m.pluggedIn ? i18n("AC") : "—")
            }
            Field {
                label: i18n("Port")
                value: m.portLabel
            }
            Field {
                label: i18n("Charger offers")
                value: m.profilesText()
                Layout.columnSpan: 3
                Layout.preferredWidth: 3
            }
            Field {
                visible: m.session !== null && m.session.n > 0
                label: i18n("This session")
                value: m.session && m.session.n > 0
                       ? i18n("avg %1 · peak %2 · %3% → %4%",
                              m.fmtW(m.session.sum / m.session.n), m.fmtW(m.session.peak),
                              m.session.startPct, m.session.endPct)
                       : ""
                Layout.columnSpan: 3
                Layout.preferredWidth: 3
            }
        }

        // Recent charging sessions
        SectionTitle { text: i18n("Recent charging"); visible: m.sessions.length > 0 }
        Repeater {
            model: Math.min(4, m.sessions.length)
            delegate: RowLayout {
                required property int index
                readonly property var modelData: m.sessions[m.sessions.length - 1 - index]
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                PlasmaComponents.Label {
                    text: m.fmtTime(modelData.start)
                    opacity: 0.7
                    Layout.preferredWidth: full.u * 5.5
                    font.features: { "tnum": 1 }
                }
                PlasmaComponents.Label {
                    text: m.chargerLabel(modelData.chargerW)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    text: modelData.startPct + "→" + modelData.endPct + "%"
                    opacity: 0.7
                    font.features: { "tnum": 1 }
                }
                PlasmaComponents.Label {
                    text: i18n("avg %1", m.fmtW(modelData.avg, 0))
                    font.features: { "tnum": 1 }
                    Layout.preferredWidth: full.u * 4
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
