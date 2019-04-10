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

    function xToScreen(xCart) {
        var xScr = (xCart - xMin) * pixelPerUnitX
        console.log("Screen X: " + xScr)
        return xScr;
    }

    function yToScreen(yCart) {
        var yScr = (yCart - yMin) * pixelPerUnitY
        console.log("Screen Y: " + yScr)
        return yScr;
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
        ctx.moveTo(xToScreen(x1) * pixelPerUnitX, yToScreen(y1) * pixelPerUnitY);
        ctx.lineTo(xToScreen(x2) * pixelPerUnitX, yToScreen(y2) * pixelPerUnitY);
        ctx.strokeStyle = color;
        ctx.stroke();

        ctx.beginPath();
        if (withLabel) {
            point(xToScreen(x1), yToScreen(y1), "A")
            point(xToScreen(x2), yToScreen(y2), "B")
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

    property real lY: 2.
    Behavior on lY { NumberAnimation {duration: 500}}
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (lY < 3.)
                lY = 3.;
            else
                lY = 1.;
        }
    }
    onLYChanged: requestPaint()

    onPaint:
    {
        ctx = getContext("2d")
        ctx.reset();
        coordinateGrid();
        coordinateAxis();
        line(1.2, 2.4, 3.6, lY, true, Qt.rgba(.2,1,.4,1));
    }

}
