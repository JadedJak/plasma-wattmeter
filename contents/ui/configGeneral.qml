import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_panelMetric: metric.currentIndex
    property alias cfg_showIcon: icon.checked
    property alias cfg_showChargeBar: chargeBar.checked
    property alias cfg_interval: interval.value
    property alias cfg_profileInPanel: profile.currentIndex
    property string cfg_sessions
    property string cfg_sessionsDefault

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: metric
            Kirigami.FormData.label: i18n("Panel shows:")
            model: [i18n("Battery charge / discharge rate"), i18n("System power draw"), i18n("Both")]
        }
        QQC2.CheckBox {
            id: icon
            Kirigami.FormData.label: i18n("Icon:")
            text: i18n("Show charging bolt")
        }
        QQC2.CheckBox {
            id: chargeBar
            text: i18n("Show charge level bar under the readout")
        }
        QQC2.ComboBox {
            id: profile
            Kirigami.FormData.label: i18n("Power profile icon:")
            model: [i18n("Never"), i18n("When not Balanced"), i18n("Always")]
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Update every:")
            QQC2.SpinBox { id: interval; from: 1; to: 30 }
            QQC2.Label { text: i18n("seconds") }
        }
        QQC2.Button {
            Kirigami.FormData.label: i18n("Charging history:")
            text: i18n("Clear history")
            icon.name: "edit-clear-history"
            enabled: cfg_sessions !== "[]"
            onClicked: cfg_sessions = "[]"
        }
    }
}
