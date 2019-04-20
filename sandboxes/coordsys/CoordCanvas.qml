import QtQuick 2.0

Item {
    id: theWorld
    anchors.fill: parent

    property int pixelPerUnit: 50
    Behavior on pixelPerUnit { NumberAnimation {duration: 200}}
    onPixelPerUnitChanged: { theCanvas.requestPaint();}

    readonly property real worldXMin: -100
    readonly property real worldXMax:  100
    readonly property real worldYMin: -25
    readonly property real worldYMax: 25

    property real xInWU: screenXToWorld(flckable.contentX)
    property real yInWU: screenYToWorld(flckable.contentY)
    property real sWidthInWU: width / pixelPerUnit
    property real sHeightInWU: height/ pixelPerUnit

    onXInWUChanged: theCanvas.requestPaint()
    onYInWUChanged: theCanvas.requestPaint()


    function xToScreen(xCart) {
        var xScr = (xCart - worldXMin) * pixelPerUnit;
        return xScr;
    }

    function screenXToWorld(xScr) {
        var xW = xScr/pixelPerUnit + worldXMin;
        return xW;
    }

    function yToScreen(yCart) {
        var yScr = flckable.contentHeight - ((yCart - worldYMin) * pixelPerUnit);
        return yScr;
    }

    function screenYToWorld(yScr) {
        var yW = ((flckable.contentHeight - yScr) / pixelPerUnit) + worldYMin;
        return yW;
    }

    Canvas
    {
        id: theCanvas
        anchors.fill: parent
        property var ctx: null

        function coordinateAxis()
        {
            if (worldXMin < 0 && worldXMax > 0)
                line(0, worldYMin, 0, worldYMax, false, Qt.rgba(.2,.2,.2,1))

            if (worldYMin < 0 && worldYMax > 0)
                line(worldXMin, 0, worldXMax, 0, false, Qt.rgba(.2,.2,.2,1))
        }

        function coordinateGrid()
        {
            var minX = theWorld.worldXMin + (Math.ceil(theWorld.xInWU) - theWorld.xInWU)
            var maxX = minX + theWorld.sWidthInWU
            console.log("maxX: " + maxX + " minX: " + minX)
            for (var x=minX; x <= maxX; x++)
                line(x, theWorld.worldYMax, x, theWorld.worldYMax - theWorld.sHeightInWU, false, Qt.rgba(.5, .5, .5, .5), 2)

            var maxY = theWorld.worldYMax + (Math.floor(theWorld.yInWU) - theWorld.yInWU)
            var minY = maxY - theWorld.sHeightInWU
            console.log("maxY: " + maxY + " minY: " + minY)
            for (var y=minY; y <= maxY; y++)
                line(theWorld.worldXMin, y, theWorld.worldXMin + theWorld.sWidthInWU, y, false, Qt.rgba(.5, .5, .5, .5), 2)
        }

        function line(x1, y1, x2, y2, withLabel, color, width)
        {
            ctx.beginPath();
            ctx.lineWidth = 4;
            if (width) ctx.lineWidth = width
            ctx.moveTo(xToScreen(x1), yToScreen(y1));
            ctx.lineTo(xToScreen(x2), yToScreen(y2));
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
            ctx.arc(x * pixelPerUnit, y * pixelPerUnit, 5, 0., 2*Math.PI, true);
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(.2,.2,.2,1)
            ctx.font = "bold 15px sans-serif";
            var clabel = label + "(" + x + "," + y + ")"
            ctx.fillText(clabel, x * pixelPerUnit - 20, y * pixelPerUnit + 20)
        }

        onPaint:
        {
            ctx = getContext("2d")
            ctx.reset();
            coordinateGrid();
            coordinateAxis();
        }

        Rectangle {
            anchors.centerIn: parent
            color: "red"
            width: 10
            height: 10

            Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                property int xScr: flckable.contentX + flckable.width/2
                property int yScr: flckable.contentY + flckable.height/2

                Text {  text: "(" + col.xScr +
                              "|" +
                              col.yScr + ") " }
                Text {  text: "(" + screenXToWorld(col.xScr).toFixed(2) +
                              "|" +
                              screenYToWorld(col.yScr).toFixed(2) + ") " }
                Text {   text:
                              "(" +
                              (theWorld.xInWU).toFixed(2) +
                              "|"  +
                              (theWorld.yInWU).toFixed(2) +
                              ") -> " +
                              "(" +
                              (screenXToWorld(col.xScr + flckable.width/2)).toFixed(2) +
                              "|"  +
                              (screenYToWorld(col.yScr + flckable.height/2)).toFixed(2) +
                              ")"
                }
            }

        }

    }

    Flickable
    {

        id: flckable
        anchors.fill: parent

        contentWidth: Math.abs(worldXMax - worldXMin) * pixelPerUnit
        contentHeight: Math.abs(worldYMax - worldYMin) * pixelPerUnit
        contentX: Math.abs(worldXMin) * pixelPerUnit - width/2
        contentY: Math.abs(worldYMax) * pixelPerUnit - height/2

        Item
        {
            width: flckable.contentWidth
            height: flckable.contentHeight
        }
        Component.onCompleted: flckable.forceActiveFocus()
        Keys.onPressed: {
            console.log("Pressed: " + event.key)
            if (event.key === Qt.Key_E) {
                theWorld.pixelPerUnit += 10
                event.accepted = true;
            }
            if (event.key === Qt.Key_D) {
                if (theWorld.pixelPerUnit > 20) theWorld.pixelPerUnit -= 10
                event.accepted = true;
            }
            if (event.key === Qt.Key_I) {
                if (flckable.contentY > 10) flckable.contentY -= 10
                event.accepted = true;
            }
            if (event.key === Qt.Key_K) {
                if (flckable.contentY < flckable.contentHeight - flckable.height) flckable.contentY += 10
                event.accepted = true;
            }
            if (event.key === Qt.Key_J) {
                if (flckable.contentX > 10) flckable.contentX -= 10
                event.accepted = true;
            }
            if (event.key === Qt.Key_L) {
                if (flckable.contentX < flckable.contentWidth - flckable.width) flckable.contentX += 10
                event.accepted = true;
            }
        }

    }
}
