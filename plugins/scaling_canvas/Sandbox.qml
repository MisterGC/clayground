import QtQuick 2.12
import "qrc:/" as LivLd
import Clayground.ScalingCanvas 1.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent
    pixelPerUnit: 50
    keyBoardNavigationEnabled: true

    worldXMin: 0
    worldXMax:  10
    worldYMin: 0
    worldYMax: 10

    Flickable
    {
        z: -1
        anchors.fill: parent
        contentWidth: coordDrawer.width
        contentHeight: coordDrawer.height
        contentX: theCanvas.xToScreen(xInWU)
        contentY: theCanvas.yToScreen(yInWU)

        onContentXChanged: console.log("New X: " + contentX)
        onContentYChanged: console.log("New Y: " + contentY)

        ScalingText {
           canvas: theCanvas
           xWu: 5;  yWu: 5
           fontSizeWu: 1
           text: "Example Text"
        }

        Canvas
        {
            id: coordDrawer
            width: theCanvas.coordSys.width
            height: theCanvas.coordSys.height
            Component.onCompleted: {
                console.log("Width: " + width + " Height: " + height)
            }

            property var context: null

            function point(x, y, label){
              let xP = theCanvas.xToScreen(x);
              let yP = theCanvas.yToScreen(y);
              context.fillStyle = "black";
              context.beginPath();
              context.arc(xP, yP, theCanvas.xToScreen(.1), 0, 2 * Math.PI, true);
              context.fill();
              if (label.length > 0) {
                 context.fillStyle = "green";
                 let xL = theCanvas.xToScreen(x - .1);
                 let yL = theCanvas.yToScreen(y - .5);
                 context.font = '20px monospace';
                 context.fillText(label, xL, yL);
              }
            }

            function drawLine(x1,y1,x2,y2) {
                let x1P = theCanvas.xToScreen(x1);
                let y1P = theCanvas.yToScreen(y1);
                let x2P = theCanvas.xToScreen(x2);
                let y2P = theCanvas.yToScreen(y2);
                console.log("x: " + x1P + " x2:" + x2P )
                console.log("y: " + y1P + " y2:" + y2P )

                context.lineWidth = 4;
                context.strokeStyle = "grey";

                context.beginPath();
                context.moveTo(x1P, y1P);
                context.lineTo(x2P, y2P);
                context.stroke();
            }

            onPaint: {
                context = coordDrawer.getContext("2d");
                drawLine(1., 19, 2, 20);
                point(1, 19, "A");
                drawLine(2, 20, 3, 17);
                point(2, 20, "B");
                point(3, 17, "C");
            }
        }
    }

}
