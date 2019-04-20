import QtQuick 2.0

Flickable
{
   id: theFlickable
   anchors.fill: parent
   contentWidth: theCanvas.width
   contentHeight: theCanvas.height

   property int pixelPerUnitX: 100
   property int pixelPerUnitY: 100

   Canvas
   {
       id: theCanvas
       width: theFlickable.width
       height: theFlickable.height
       property var ctx: null

       property real xMin: -.5
       property real xMax: 5.
       property real yMin: -.5
       property real yMax: 5.

       Component.onCompleted: {
           pixelPerUnitX = width / (xMax - xMin)
           pixelPerUnitY = height / (yMax - yMin)
           requestPaint()
       }

       function xToScreen(xCart) {
           var xScr = (xCart - xMin) * pixelPerUnitX
           return xScr;
       }

       function yToScreen(yCart) {
           var yScr = height - ((yCart - yMin) * pixelPerUnitY)
           return yScr;
       }

       function coordinateAxis()
       {
           if (xMin < 0 && xMax > 0)
               line(0, yMin, 0, yMax, false, Qt.rgba(.2,.2,.2,1))

           if (yMin < 0 && yMax > 0)
               line(xMin, 0, xMax, 0, false, Qt.rgba(.2,.2,.2,1))
       }

       function coordinateGrid()
       {
           for (var x=Math.ceil(xMin); x <= Math.floor(xMax); x++)
               line(x, yMin, x, yMax, false, Qt.rgba(.5, .5, .5, .5), 2)

           for (var y=Math.ceil(yMin); y <= Math.floor(yMax); y++)
               line(xMin, y, xMax, y, false, Qt.rgba(.5, .5, .5, .5), 2)
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
           ctx.arc(x * pixelPerUnitX, y * pixelPerUnitY, 5, 0., 2*Math.PI, true);
           ctx.lineWidth = 1;
           ctx.strokeStyle = Qt.rgba(.2,.2,.2,1)
           ctx.font = "bold 15px sans-serif";
           var clabel = label + "(" + x + "," + y + ")"
           ctx.fillText(clabel, x * pixelPerUnitX - 20, y * pixelPerUnitY + 20)
       }

       property real lY: 2.
       Behavior on lY { NumberAnimation {duration: 500}}
       Timer {
           interval: 1000
           //repeat: true
           //running: true
           onTriggered: {
               if (lY < 3.) lY = 3.;
               else lY = 1.;
           }
       }
       onLYChanged: requestPaint()

       onPaint:
       {
           console.log("About to paint")
           ctx = getContext("2d")
           ctx.reset();
           coordinateGrid();
           coordinateAxis();
           line(1, 2, 4, lY, true, Qt.rgba(.2,.2,.6,1));
           line(1, 4, 4, lY, true, Qt.rgba(.2,.2,.6,1));
           line(1, 2, 1, 4, true, Qt.rgba(.6,.0,.0,1));
       }

   }
}
