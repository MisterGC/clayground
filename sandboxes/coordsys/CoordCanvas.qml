import QtQuick 2.0

Item {
    id: theWorld
    anchors.fill: parent

    property int pixelPerUnit: 50
    Behavior on pixelPerUnit { NumberAnimation {duration: 2000}}
    //Component.onCompleted: pixelPerUnit = 100
    onPixelPerUnitChanged: { theCanvas.requestPaint();}

    readonly property real worldXMin: -10
    readonly property real worldXMax:  10
    readonly property real worldYMin: -10
    readonly property real worldYMax: 10

    property real contentWorldX: screenXToWorld(flckable.contentX)
    property real contentWorldY: screenYToWorld(flckable.contentY)

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
            for (var x=Math.ceil(worldXMin); x <= Math.floor(worldXMax); x++)
                line(x, worldYMin, x, worldYMax, false, Qt.rgba(.5, .5, .5, .5), 2)

            for (var y=Math.ceil(worldYMin); y <= Math.floor(worldYMax); y++)
                line(worldXMin, y, worldXMax, y, false, Qt.rgba(.5, .5, .5, .5), 2)
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

        property real lY: 2.
        //       Behavior on lY { NumberAnimation {duration: 500}}
        //       Timer {
        //           interval: 1000
        //           repeat: true
        //           running: true
        //           onTriggered: {
        //               if (theCanvas.lY < 3.) theCanvas.lY = 3.;
        //               else theCanvas.lY = 1.;
        //           }
        //       }
        //       onLYChanged: requestPaint()

        onPaint:
        {
            ctx = getContext("2d")
            ctx.reset();
            coordinateGrid();
            coordinateAxis();
            //line(1, 2, 4, lY, true, Qt.rgba(.2,.2,.6,1));
            //line(1, 4, 4, lY, true, Qt.rgba(.2,.2,.6,1));
            //line(1, 2, 1, 4, true, Qt.rgba(.6,.0,.0,1));
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
                property int xScr: Math.floor(flckable.contentX + flckable.width/2)
                property int yScr: Math.floor(flckable.contentY + flckable.height/2)

                Text {  text: "(" + col.xScr + "|" + col.yScr + ") " }
                Text {   text:
                              "(" +
                              Math.round(theWorld.contentWorldX) +
                              "|"  +
                              Math.round(theWorld.contentWorldY) +
                              ") -> " +
                              "(" +
                              Math.round(screenXToWorld(col.xScr + flckable.width/2)) +
                              "|"  +
                              Math.round(screenYToWorld(col.yScr + flckable.height/2)) +
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

    }
}
