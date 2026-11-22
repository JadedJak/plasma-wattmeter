import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact
    property var m

    hoverEnabled: true
    onClicked: m.expanded = !m.expanded

    Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

        Bolt {
            visible: Plasmoid.configuration.showIcon
            Layout.preferredHeight: Math.round(label.implicitHeight * 0.8)
            Layout.preferredWidth: Math.round(Layout.preferredHeight * 0.7)
            filled: compact.m.charging
            color: compact.m.charging ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
            opacity: compact.m.charging ? 1 : 0.7
        }

        PlasmaComponents.Label {
            id: label
            text: compact.m.panelText
            font.features: { "tnum": 1 }
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: metrics.width
        }
    }

    TextMetrics {
        id: metrics
        font: label.font
        text: Plasmoid.configuration.panelMetric === 2 ? "+88.8 · 88.8 W" : "+88.8 W"
    }
}
