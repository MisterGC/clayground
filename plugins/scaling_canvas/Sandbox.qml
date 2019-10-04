/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.12
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
