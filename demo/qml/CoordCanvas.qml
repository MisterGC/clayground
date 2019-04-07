import QtQuick 2.0

Canvas
{
    id: theCanvas
    anchors.fill: parent
    property var ctx: getContext("2d")
    property int pixelPerUnitX: 100
    property int pixelPerUnitY: 100

    property real xMin: -.5
    property real xMax: 5.
    property real yMin: -.5
    property real yMax: 5.

    Component.onCompleted: {
        pixelPerUnitX = width / (xMax - xMin)
        pixelPerUnitY = height / (yMax - yMin)
    }

    function coordinateGrid()
    {
        ctx.beginPath()
        var dx = xMax - xMin;
        var dy = yMax - yMin;

        for (var x = 0; x <= width; x += width/dx) {
            ctx.moveTo(x, 0);
            ctx.lineTo(x, height);
        }

        for (var y = 0; y <=height; y += height/dy){
            ctx.moveTo(0, y);
            ctx.lineTo(width, y);
        }

        ctx.strokeStyle = Qt.rgba(0,0,0,.2)
        ctx.stroke();

        ctx.beginPath()
        ctx.strokeStyle = Qt.rgba(0,0,0,1)
        ctx.stroke();
    }

    function line(x1, y1, x2, y2, withLabel, color)
    {
        ctx.beginPath();
        ctx.lineWidth = 4;
        ctx.moveTo(x1 * pixelPerUnitX, y1 * pixelPerUnitY);
        ctx.lineTo(x2 * pixelPerUnitX, y2 * pixelPerUnitY);
        ctx.strokeStyle = color;
        ctx.stroke();

        if (withLabel) {
            point(x1, y1, "A")
            point(x2, y2, "B")
            ctx.fill();
        }
    }

    function point(x, y, label)
    {
        var oldStyle = ctx.strokeStyle
        ctx.arc(x * pixelPerUnitX, y * pixelPerUnitY, 5, 0., 2*Math.PI, true);
        ctx.lineWidth = 1;
        ctx.strokeStyle = Qt.rgba(.2,.2,.2,1)
        ctx.font = "bold 15px sans-serif";
        var clabel = label + "(" + x + "," + y + ")"
        ctx.fillText(clabel, x * pixelPerUnitX - 20, y * pixelPerUnitY + 20)
    }

    function coordinateAxis()
    {
        if (xMin < 0 && xMax > 0)
            line(Math.abs(xMin), yMin, Math.abs(xMin), yMax, false, Qt.rgba(.2,.2,.2,1))

        if (yMin < 0 && yMax > 0)
            line(xMin, Math.abs(yMin), xMax, Math.abs(yMin), false, Qt.rgba(.2,.2,.2,1))
    }

    onPaint:
    {
        ctx = getContext("2d")
        ctx.reset();
        coordinateGrid();
        coordinateAxis();
        line(1.2, 2.4, 3.6, 2.4, true, Qt.rgba(.2,1,.4,1));
    }

}
