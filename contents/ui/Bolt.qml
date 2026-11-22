import QtQuick

// Lightning bolt glyph: filled while charging, outlined otherwise.
Canvas {
    id: bolt
    property color color: "white"
    property bool filled: true

    onColorChanged: requestPaint()
    onFilledChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const sx = width / 10, sy = height / 16, lw = Math.max(1, width / 9);
        ctx.save();
        ctx.translate(filled ? 0 : lw / 2, filled ? 0 : lw / 2);
        ctx.scale((width - (filled ? 0 : lw)) / width, (height - (filled ? 0 : lw)) / height);
        ctx.beginPath();
        ctx.moveTo(6.2 * sx, 0);
        ctx.lineTo(0.4 * sx, 9.2 * sy);
        ctx.lineTo(4.6 * sx, 9.2 * sy);
        ctx.lineTo(3.6 * sx, 16 * sy);
        ctx.lineTo(9.6 * sx, 6.4 * sy);
        ctx.lineTo(5.4 * sx, 6.4 * sy);
        ctx.closePath();
        ctx.restore();
        if (filled) {
            ctx.fillStyle = color;
            ctx.fill();
        } else {
            ctx.lineJoin = "round";
            ctx.lineWidth = lw;
            ctx.strokeStyle = color;
            ctx.stroke();
        }
    }
}
