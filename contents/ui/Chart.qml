import QtQuick
import org.kde.kirigami as Kirigami

// Rolling line chart of two power series (W), newest sample at the right edge.
Canvas {
    id: chart
    property var seriesA: []        // battery |W|
    property var seriesB: []        // system W (nulls allowed)
    property int capacity: 300
    property color colorA: Kirigami.Theme.positiveTextColor
    property color colorB: Kirigami.Theme.highlightColor
    property color gridColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
    property color labelColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.55)

    onSeriesAChanged: requestPaint()
    onSeriesBChanged: requestPaint()
    onColorAChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function niceMax(v) {
        const steps = [5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 120, 150, 200, 300];
        for (const s of steps) if (v <= s) return s;
        return Math.ceil(v / 100) * 100;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const fontPx = Math.round(Kirigami.Units.gridUnit * 0.6);
        const labelW = fontPx * 3.2;
        const W = width - labelW, H = height, top = fontPx * 0.6, bottom = H - 1;
        let max = 0;
        for (const v of seriesA) if (v !== null && v > max) max = v;
        for (const v of seriesB) if (v !== null && v > max) max = v;
        max = niceMax(max * 1.1);
        const y = v => bottom - (bottom - top) * Math.min(v, max) / max;
        const step = W / Math.max(1, capacity - 1);

        // grid + labels
        ctx.font = fontPx + "px sans-serif";
        ctx.textBaseline = "middle";
        ctx.lineWidth = 1;
        for (const frac of [0, 0.5, 1]) {
            const gy = Math.round(y(max * frac)) + 0.5;
            ctx.strokeStyle = gridColor;
            ctx.beginPath();
            ctx.moveTo(0, gy);
            ctx.lineTo(W, gy);
            ctx.stroke();
            ctx.fillStyle = labelColor;
            ctx.fillText(Math.round(max * frac) + " W", W + fontPx * 0.5, Math.min(Math.max(gy, fontPx / 2), H - fontPx / 2));
        }

        function plot(series, color, fill) {
            const n = series.length;
            if (n < 2) return;
            const x0 = W - (n - 1) * step;
            ctx.beginPath();
            let started = false, firstX = 0, lastX = 0;
            for (let i = 0; i < n; i++) {
                const v = series[i];
                if (v === null || isNaN(v)) continue;
                const x = x0 + i * step;
                if (!started) { ctx.moveTo(x, y(v)); firstX = x; started = true; }
                else ctx.lineTo(x, y(v));
                lastX = x;
            }
            if (!started) return;
            ctx.lineWidth = Math.max(1.5, Kirigami.Units.devicePixelRatio * 1.5);
            ctx.lineJoin = "round";
            ctx.strokeStyle = color;
            ctx.stroke();
            if (fill) {
                ctx.lineTo(lastX, bottom);
                ctx.lineTo(firstX, bottom);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.16);
                ctx.fill();
            }
        }
        plot(seriesB, colorB, false);
        plot(seriesA, colorA, true);
    }
}
