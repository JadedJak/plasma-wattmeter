import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string script: Qt.resolvedUrl("../code/read.sh").toString().replace(/^file:\/\//, "")
    readonly property int historyLength: Math.round(600 / Math.max(1, Plasmoid.configuration.interval)) // 10 minutes

    // ---- live state --------------------------------------------------------
    property bool ready: false
    property string status: "Unknown"
    property int percent: 0
    property real batteryW: 0          // signed: + into battery, − out of battery
    property real smoothW: 0           // smoothed batteryW, used for time estimates
    property real systemW: NaN         // whole-platform draw
    property bool psysAvailable: false
    property real energyNowWh: NaN
    property real energyFullWh: NaN
    property real energyDesignWh: NaN
    property real voltage: NaN
    property real current: NaN
    property int cycles: -1
    property real tempC: NaN
    property string batteryModel: ""
    property bool pluggedIn: false
    property real contractV: NaN
    property real contractA: NaN
    property real chargerMaxW: NaN
    property var pdos: []
    property string pdRevision: ""
    property string portLocation: ""
    property var historyBattery: []
    property var historySystem: []
    property var session: null
    property var sessions: []

    property real _lastPsys: -1
    property real _lastT: 0

    readonly property bool charging: status === "Charging"
    readonly property bool discharging: status === "Discharging"
    readonly property bool full: status === "Full" || (pluggedIn && !charging && !discharging && percent >= 99)
    readonly property real healthPct: energyDesignWh > 0 ? 100 * energyFullWh / energyDesignWh : NaN
    readonly property string condition: isNaN(healthPct) ? "" : healthPct >= 80 ? i18n("Good") : healthPct >= 60 ? i18n("Fair") : i18n("Service recommended")
    readonly property real hoursLeft: {
        if (charging && smoothW > 0.3) return Math.max(0, energyFullWh - energyNowWh) / smoothW;
        if (discharging && smoothW < -0.3) return energyNowWh / -smoothW;
        return NaN;
    }
    readonly property real negotiatedW: contractV * contractA
    readonly property string portLabel: {
        if (!portLocation) return "—";
        const parts = portLocation.split(" ");
        const cap = w => w.charAt(0).toUpperCase() + w.slice(1);
        const side = parts.find(p => p === "left" || p === "right");
        const rest = parts.filter(p => p !== side && p !== "center").join(", ");
        return side ? i18n("%1 side", cap(side)) + (rest ? " (" + rest + ")" : "") : cap(parts.join(" "));
    }
    readonly property color stateColor: charging ? Kirigami.Theme.positiveTextColor
                                      : discharging ? Kirigami.Theme.neutralTextColor
                                      : Kirigami.Theme.textColor

    readonly property string headline: !ready ? "…"
                                     : (charging || discharging) ? fmtSigned(batteryW)
                                     : full ? i18n("Full") : i18n("Idle")
    readonly property string subline: {
        if (!ready) return "";
        if (charging) return isNaN(hoursLeft) ? i18n("Charging") : i18n("Charging · %1 to full", fmtDuration(hoursLeft));
        if (discharging) return isNaN(hoursLeft) ? i18n("On battery") : i18n("On battery · %1 left", fmtDuration(hoursLeft));
        if (full) return i18n("Plugged in · fully charged");
        return pluggedIn ? i18n("Plugged in · not charging") : status;
    }
    readonly property string panelText: {
        if (!ready) return "…";
        const sys = isNaN(systemW) ? "—" : systemW.toFixed(1);
        const bat = (charging || discharging) ? fmtSigned(batteryW, false) : (full ? i18n("Full") : "0.0");
        switch (Plasmoid.configuration.panelMetric) {
        case 1: return sys + " W";
        case 2: return bat + " · " + sys + " W";
        default: return (charging || discharging) ? bat + " W" : bat === i18n("Full") ? bat : bat + " W";
        }
    }

    // ---- formatting --------------------------------------------------------
    function fmtSigned(w, unit) {
        const s = (w >= 0.05 ? "+" : w <= -0.05 ? "−" : "") + Math.abs(w).toFixed(1);
        return unit === false ? s : s + " W";
    }
    function fmtW(w, digits) {
        return isNaN(w) ? "—" : w.toFixed(digits === undefined ? 1 : digits) + " W";
    }
    function fmtDuration(h) {
        if (isNaN(h) || !isFinite(h)) return "—";
        const mins = Math.round(h * 60);
        if (mins < 60) return i18n("%1 min", mins);
        return i18n("%1 h %2 min", Math.floor(mins / 60), mins % 60);
    }
    function fmtTime(ms) {
        return Qt.formatDateTime(new Date(ms), "ddd h:mm AP");
    }
    function capWatts(c) {
        if (c.mw !== null) return c.mw / 1000;
        const v = c.max_mv !== null ? c.max_mv : c.mv;
        return v !== null && c.ma !== null ? v * c.ma / 1e6 : 0;
    }
    function profilesText() {
        if (!pdos.length) return "—";
        const fixed = [], currents = [], extra = [];
        for (const c of pdos) {
            if (c.type === "fixed_supply" && c.mv !== null) {
                const v = c.mv / 1000;
                if (fixed.indexOf(v) < 0) fixed.push(v);
                if (currents.indexOf(c.ma / 1000) < 0) currents.push(c.ma / 1000);
            } else if (c.min_mv !== null && c.max_mv !== null) {
                const kind = c.type.indexOf("programmable") >= 0 ? "PPS" : c.type.split("_")[0];
                extra.push(kind + " " + (c.min_mv / 1000) + "–" + (c.max_mv / 1000) + " V");
            }
        }
        fixed.sort((a, b) => a - b);
        let s = fixed.join(" · ") + " V";
        if (currents.length === 1) s += " @ " + currents[0] + " A";
        return extra.length ? s + ", " + extra.join(", ") : s;
    }
    function chargerLabel(w) {
        return isNaN(w) || w <= 0 ? i18n("Charger") : i18n("%1 W charger", Math.round(w));
    }

    // ---- sampling ----------------------------------------------------------
    function ingest(text) {
        let s;
        try { s = JSON.parse(text); } catch (e) { return; }
        const b = s.bat;
        if (!b) return;

        const st = b.status || "Unknown";
        status = st;
        percent = b.capacity !== null ? b.capacity : 0;
        voltage = b.voltage_now !== null ? b.voltage_now / 1e6 : NaN;
        const vNom = b.voltage_min_design !== null ? b.voltage_min_design / 1e6 : voltage;
        if (b.energy_now !== null) {
            energyNowWh = b.energy_now / 1e6;
            energyFullWh = b.energy_full / 1e6;
            energyDesignWh = b.energy_full_design / 1e6;
        } else if (b.charge_now !== null) {
            energyNowWh = b.charge_now * vNom / 1e6;
            energyFullWh = b.charge_full * vNom / 1e6;
            energyDesignWh = b.charge_full_design * vNom / 1e6;
        }

        let w = 0;
        if (b.power_now !== null) {
            w = Math.abs(b.power_now) / 1e6;
            current = voltage > 0 ? w / voltage : NaN;
        } else if (b.current_now !== null) {
            current = Math.abs(b.current_now) / 1e6;
            w = current * voltage;
        }
        if (st === "Discharging") w = -w;
        else if (st !== "Charging") w = 0;
        batteryW = w;
        smoothW = (ready && Math.sign(smoothW) === Math.sign(w)) ? smoothW * 0.85 + w * 0.15 : w;

        cycles = b.cycle_count !== null ? b.cycle_count : -1;
        tempC = s.temp !== null ? s.temp / 1000 : NaN;
        batteryModel = [b.manufacturer, b.model].filter(x => x).join(" ") + (b.technology ? " · " + b.technology : "");

        pluggedIn = s.ac === 1;
        const u = (s.usb || []).find(x => x.online === 1 && x.voltage_now > 0);
        contractV = u ? u.voltage_now / 1e6 : NaN;
        contractA = u ? u.current_max / 1e6 : NaN;
        if (s.pd && pluggedIn) {
            pdos = s.pd.caps;
            chargerMaxW = pdos.reduce((m, c) => Math.max(m, capWatts(c)), 0) || NaN;
            pdRevision = s.pd.revision && s.pd.revision !== "0.0" ? s.pd.revision : "";
            portLocation = s.pd.location;
        } else {
            pdos = [];
            chargerMaxW = NaN;
            pdRevision = "";
            portLocation = "";
        }

        if (s.psys !== null) {
            if (_lastPsys >= 0 && s.t > _lastT) {
                let dE = s.psys - _lastPsys;
                if (dE < 0 && s.psys_max) dE += s.psys_max;
                systemW = dE / 1e6 / ((s.t - _lastT) / 1000);
            }
            _lastPsys = s.psys;
            _lastT = s.t;
            psysAvailable = true;
        } else {
            psysAvailable = false;
            systemW = st === "Discharging" ? -w : NaN;
        }

        const hb = historyBattery.slice(-(historyLength - 1));
        hb.push(Math.abs(w));
        historyBattery = hb;
        const hs = historySystem.slice(-(historyLength - 1));
        hs.push(isNaN(systemW) ? null : systemW);
        historySystem = hs;

        trackSession(w);
        ready = true;
    }

    function trackSession(w) {
        if (pluggedIn) {
            const cur = session || { start: Date.now(), startPct: percent, chargerW: chargerMaxW,
                                     port: portLocation, sum: 0, n: 0, peak: 0 };
            const next = Object.assign({}, cur, { end: Date.now(), endPct: percent });
            if (isNaN(next.chargerW) && !isNaN(chargerMaxW)) next.chargerW = chargerMaxW;
            if (w > 0.3) {
                next.sum += w;
                next.n += 1;
                next.peak = Math.max(next.peak, w);
            }
            session = next;
        } else if (session) {
            const sess = session;
            session = null;
            if (sess.end - sess.start > 120000 && sess.n > 0) {
                const list = sessions.concat([{ start: sess.start, end: sess.end, startPct: sess.startPct,
                                                endPct: sess.endPct, chargerW: sess.chargerW, port: sess.port,
                                                avg: sess.sum / sess.n, peak: sess.peak }]).slice(-30);
                sessions = list;
                Plasmoid.configuration.sessions = JSON.stringify(list);
            }
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onSessionsChanged() {
            try { root.sessions = JSON.parse(Plasmoid.configuration.sessions); } catch (e) { root.sessions = []; }
        }
    }
    Component.onCompleted: {
        try { sessions = JSON.parse(Plasmoid.configuration.sessions); } catch (e) { sessions = []; }
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            root.ingest(data["stdout"]);
        }
    }
    Timer {
        interval: Math.max(1, Plasmoid.configuration.interval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource("sh '" + root.script + "'")
    }

    // ---- representations ---------------------------------------------------
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    compactRepresentation: CompactRepresentation { m: root }
    fullRepresentation: FullRepresentation { m: root }

    toolTipMainText: headline
    toolTipSubText: subline + (isNaN(systemW) ? "" : "\n" + i18n("System draw: %1", fmtW(systemW)))
    Plasmoid.icon: "battery-080-charging"
}
