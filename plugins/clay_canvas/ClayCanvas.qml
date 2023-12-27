// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

Item {
    id: theWorld

    property alias deviceScalingFactor: flckable.deviceScalingFactor
    property alias zoomFactor: flckable.zoomFactor
    property alias pixelPerUnit: flckable.pixelPerUnit
    property alias interactive: flckable.interactive

    property alias worldXMin: flckable.worldXMin
    property alias worldXMax:  flckable.worldXMax
    property alias worldYMin: flckable.worldYMin
    property alias worldYMax: flckable.worldYMax

    property alias xInWU: flckable.xInWU
    property alias yInWU: flckable.yInWU
    property alias sWidthInWU: flckable.sWidthInWU
    property alias sHeightInWU: flckable.sHeightInWU
    property alias viewPortCenterWuX: flckable.viewPortCenterWuX
    property alias viewPortCenterWuY: flckable.viewPortCenterWuY

    property alias showDebugInfo: theOverlayLoader.active

    property bool keyBoardNavigationEnabled: false
    signal keyPressed(var event)
    signal keyReleased(var event)

    readonly property var coordSys: flckable.contentItem

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

    /** Item that the 'camera' of the canvas follows automatically - set to null to disable. */
    property var observedItem: null
    onObservedItemChanged: {
        if (observedItem) {
            viewPortCenterWuX = Qt.binding(function() {return screenXToWorld(observedItem.x);});
            viewPortCenterWuY = Qt.binding(function() {return screenYToWorld(observedItem.y);});
        }
        else {
            viewPortCenterWuX = (worldXMax - worldXMin) * .5;
            viewPortCenterWuY = (worldYMax - worldYMin) * .5;
        }
    }

    Loader {
        id: theUnderlayLoader

        anchors.fill: parent
        active: theOverlayLoader.active
        sourceComponent: active ? theUnderlayComp : null
        function redrawOnDemand() { if (item) item.requestPaint(); }
    }

    Component {
        id: theUnderlayComp

        Canvas
        {
            id: theUnderlay
            anchors.fill: parent
            opacity: 0.0
            Behavior on opacity { NumberAnimation {duration: 250}}
            Component.onCompleted: { opacity = 1.0; }

            property var ctx: null
            function coordinateGrid()
            {
                ctx.beginPath();
                ctx.lineWidth = 2;
                ctx.strokeStyle = Qt.rgba(.6,.6,.6,1.);
                var minX = theWorld.worldXMin + (Math.ceil(theWorld.xInWU) - theWorld.xInWU)
                var maxX = minX + theWorld.sWidthInWU
                for (var x= theWorld.xToScreen(minX); x <= theWorld.xToScreen(maxX); x+=theWorld.pixelPerUnit) {
                    var xCanv = theUnderlay.mapFromItem(theWorld, x, 0).x;
                    ctx.moveTo(xCanv, 0);
                    ctx.lineTo(xCanv, height);
                }

                var maxY = theWorld.worldYMax + (Math.floor(theWorld.yInWU) - theWorld.yInWU)
                var minY = maxY - theWorld.sHeightInWU
                for (var y=theWorld.yToScreen(maxY); y <= theWorld.yToScreen(minY); y+=theWorld.pixelPerUnit) {
                    var yCanv = theUnderlay.mapFromItem(theWorld, 0, y).y;
                    ctx.moveTo(0, yCanv);
                    ctx.lineTo(width, yCanv);
                }
                ctx.stroke();
            }

            onPaint:
            {
                ctx = getContext("2d")
                ctx.reset();
                coordinateGrid();
            }
        }
    }

    Flickable
    {
        id: flckable
        anchors.fill: parent
        clip: true

        property real deviceScalingFactor: height / 1080
        property real zoomFactor: 1.0
        property real pixelPerUnit: 50 * deviceScalingFactor * zoomFactor
        onPixelPerUnitChanged: { theUnderlayLoader.redrawOnDemand();}

        property real worldXMin: 0
        property real worldXMax:  20
        property real worldYMin: 0
        property real worldYMax: 25

        property real xInWU: screenXToWorld(flckable.contentX)
        property real yInWU: screenYToWorld(flckable.contentY)
        property real sWidthInWU: width / pixelPerUnit
        property real sHeightInWU: height/ pixelPerUnit
        property real viewPortCenterWuX: worldXMin
        property real viewPortCenterWuY: worldYMax

        onXInWUChanged: theUnderlayLoader.redrawOnDemand()
        onYInWUChanged: theUnderlayLoader.redrawOnDemand()

        contentWidth: Math.abs(worldXMax - worldXMin) * pixelPerUnit
        contentHeight: Math.abs(worldYMax - worldYMin) * pixelPerUnit
        contentX: _updateContentX(viewPortCenterWuX, pixelPerUnit)
        contentY: _updateContentY(viewPortCenterWuY, pixelPerUnit)

        function _updateContentX(vpX, ppu) {
            var cx = theWorld.xToScreen(vpX) - width/2;
            if (cx < 0) cx = 0;
            if (cx > (contentWidth - width)) cx = contentWidth - width;
            return cx;
        }

        function _updateContentY(vpY, ppu) {
            var cy = theWorld.yToScreen(vpY) - height/2;
            if (cy < 0) cy = 0
            if (cy > (contentHeight - height)) cy = contentHeight - height;
            return cy;
        }

        Item
        {
            width: flckable.contentWidth
            height: flckable.contentHeight
        }
        Component.onCompleted: flckable.forceActiveFocus()
        Keys.onPressed: (event) => {
            if (theWorld.keyBoardNavigationEnabled) {
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
                if (event.key === Qt.Key_E) {
                    theWorld.zoomFactor += .1
                    event.accepted = true;
                }
                if (event.key === Qt.Key_D) {
                    if (theWorld.zoomFactor > .2) theWorld.zoomFactor -= .1
                    event.accepted = true;
                }
            }
            if (event.key === Qt.Key_Space) {
                theOverlayLoader.active = !theOverlayLoader.active;
            }
            theWorld.keyPressed(event)
        }
        Keys.onReleased: (event) => {
            theWorld.keyReleased(event)
        }

    }

    Loader {
        id: theOverlayLoader
        active: false
        anchors.fill: parent
        sourceComponent: active ? theOverlayComp : null
    }

    Component {
        id: theOverlayComp
        Item {
            id: theOverlay
            anchors.fill: parent
            opacity: 0.0
            Behavior on opacity { NumberAnimation {duration: 250}}
            Component.onCompleted: { opacity = 1.0; }
            Text {

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.02
                    height: parent.height * 1.02
                    color: "white"
                    z: -1
                    opacity: 0.5
                }

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: parent.height / 100
                anchors.leftMargin: anchors.topMargin
                font.bold: true
                font.family: "Monospace"
                color: "#2087c0"
                text: "D-Scale: " + flckable.deviceScalingFactor.toFixed(2)  + "\n" +
                      "Zoom:    " + flckable.zoomFactor.toFixed(2)  + "\n" +
                      "PPU:     " + flckable.pixelPerUnit.toFixed(2)
            }

            Rectangle {
                anchors.centerIn: parent
                border.color: "black"
                color: Qt.rgba(1., 0, 0, .5)
                width: 10
                height: 10

                Rectangle {
                    opacity: 0.5
                    anchors.centerIn: col
                    width: col.width
                    height: col.height
                }

                Column {
                    id: col
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    property int xScr: flckable.contentX + flckable.width/2
                    property int yScr: flckable.contentY + flckable.height/2

                    Text {
                        font.family: "Monospace"
                        color: "#2087c0"
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:  "(" + col.xScr +
                               "|" +
                               col.yScr + ") / " +
                               "(" + screenXToWorld(col.xScr).toFixed(2) +
                               "|" +
                               screenYToWorld(col.yScr).toFixed(2) + ") "
                    }
                    Text {
                        font.family: "Monospace"
                        color: "#2087c0"
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:
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
    }
}
