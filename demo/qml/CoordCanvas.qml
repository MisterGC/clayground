import QtQuick 2.0

Canvas
{
    id: theCanvas
    anchors.fill: parent
    property var ctx: getContext("2d")
    property int pixelPerUnit: 100

    function board(bw, bh, p)
    {
        for (var x = 0; x <= bw; x += 40) {
            ctx.moveTo(0.5 + x + p, p);
            ctx.lineTo(0.5 + x + p, bh + p);
        }

        for (x = 0; x <= bh; x += 40) {
            ctx.moveTo(p, 0.5 + x + p);
            ctx.lineTo(bw + p, 0.5 + x + p);
        }
        ctx.strokeStyle = Qt.rgba(0,0,0,.2)
        ctx.stroke();
    }

    function line(x1, y1, x2, y2)
    {
        ctx.beginPath();
        ctx.lineWidth = 4;
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.strokeStyle = Qt.rgba(.2,1,.4,1)
        ctx.stroke();
        point(x1, y1, "A")
        point(x2, y2, "B")
        ctx.fill();
    }

    function point(x, y, label)
    {
        var oldStyle = ctx.strokeStyle
        ctx.arc(x, y, 5, 0., 2*Math.PI, true);
        ctx.lineWidth = 1;
        ctx.strokeStyle = Qt.rgba(.2,.2,.2,1)
        ctx.font = "bold 15px sans-serif";
        var clabel = label + "(" + x/pixelPerUnit + "," + y/pixelPerUnit + ")"
        ctx.fillText(clabel, x - 20, y + 20)
    }

    onPaint:
    {
        ctx = getContext("2d")
        ctx.reset();
        board(width, height, 0)
        line(width/4, height/2, 3*width/4, height/2)
    }

}
