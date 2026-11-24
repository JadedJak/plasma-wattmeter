import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact
    property var m

    readonly property color textColor: Kirigami.Theme.textColor

    // Fixed footprint: always reserve room for the bolt, the profile icon (unless
    // set to Never) and the widest readout, so the widget never changes width.
    // Icons sit on the left, the number is right-aligned; spare room is the gap
    // between them.
    readonly property int gap: Math.round(Kirigami.Units.smallSpacing * 0.75)
    readonly property int boltW: Math.round(Math.round(label.implicitHeight * 0.8) * 0.7)
    readonly property int iconW: Math.round(label.implicitHeight * 0.9)
    readonly property int contentW: (Plasmoid.configuration.showIcon ? boltW + gap : 0)
                                  + (Plasmoid.configuration.profileInPanel > 0 ? iconW + gap : 0)
                                  + Math.ceil(metrics.width)

    hoverEnabled: true
    onClicked: m.expanded = !m.expanded

    Layout.minimumWidth: contentW + Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth

    ColumnLayout {
        anchors.centerIn: parent
        width: compact.contentW
        spacing: Math.max(1, Math.round(Kirigami.Units.smallSpacing * 0.5))

        RowLayout {
            id: row
            Layout.fillWidth: true
            spacing: 0   // gaps are per-item margins so hidden items take no room

            Bolt {
                visible: Plasmoid.configuration.showIcon
                Layout.preferredHeight: Math.round(label.implicitHeight * 0.8)
                Layout.preferredWidth: compact.boltW
                Layout.rightMargin: compact.gap
                filled: compact.m.charging
                color: compact.m.charging ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                opacity: compact.m.charging ? 1 : 0.7
            }

            Kirigami.Icon {
                visible: compact.m.profileInPanel
                source: compact.m.profileIcon
                Layout.preferredHeight: compact.iconW
                Layout.preferredWidth: compact.iconW
                Layout.rightMargin: compact.gap
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                id: label
                text: compact.m.panelText
                font.features: { "tnum": 1 }
            }
        }

        // Charge level: thin bar under the readout. Green while charging, red at
        // 20 % or less on battery, otherwise the panel text colour.
        Rectangle {
            visible: Plasmoid.configuration.showChargeBar && compact.m.ready
            Layout.fillWidth: true
            implicitHeight: Math.max(2, Math.round(label.implicitHeight * 0.14))
            radius: height / 2
            color: Qt.rgba(compact.textColor.r, compact.textColor.g, compact.textColor.b, 0.2)

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(100, Math.max(0, compact.m.percent)) / 100)
                height: parent.height
                radius: parent.radius
                color: compact.m.charging ? Kirigami.Theme.positiveTextColor
                     : compact.m.discharging && compact.m.percent <= 20 ? Kirigami.Theme.negativeTextColor
                     : Qt.rgba(compact.textColor.r, compact.textColor.g, compact.textColor.b, 0.7)
                Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }
        }
    }

    TextMetrics {
        id: metrics
        font: label.font
        text: Plasmoid.configuration.panelMetric === 2 ? "+88.8 · 88.8 W" : "+88.8 W"
    }
}
