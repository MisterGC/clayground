// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayCanvas
    \inqmlmodule Clayground.Canvas
    \brief A 2D canvas with world coordinate mapping and camera controls.

    ClayCanvas provides a complete 2D rendering system with world unit coordinates,
    viewport management, camera following, and debug visualization. It transforms
    between screen pixels and world units automatically.

    The coordinate system uses Y-up orientation (like standard math coordinates).

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.ClayCanvas {
        id: canvas
        anchors.fill: parent
        worldXMin: -10; worldXMax: 10
        worldYMin: -10; worldYMax: 10
        pixelPerUnit: 50
        observedItem: player
    }
    \endqml

    \qmlproperty real ClayCanvas::deviceScalingFactor
    \brief Automatic scaling factor based on device height (height / 1080).

    \qmlproperty real ClayCanvas::zoomFactor
    \brief Zoom level multiplier. Default is 1.0.

    \qmlproperty real ClayCanvas::pixelPerUnit
    \brief Number of screen pixels per world unit. Computed from deviceScalingFactor and zoomFactor.

    \qmlproperty bool ClayCanvas::interactive
    \brief Whether the canvas viewport can be panned interactively.

    \qmlproperty real ClayCanvas::worldXMin
    \brief Minimum X coordinate boundary in world units.

    \qmlproperty real ClayCanvas::worldXMax
    \brief Maximum X coordinate boundary in world units.

    \qmlproperty real ClayCanvas::worldYMin
    \brief Minimum Y coordinate boundary in world units.

    \qmlproperty real ClayCanvas::worldYMax
    \brief Maximum Y coordinate boundary in world units.

    \qmlproperty real ClayCanvas::xInWU
    \readonly
    \brief Current viewport left edge position in world units.

    \qmlproperty real ClayCanvas::yInWU
    \readonly
    \brief Current viewport top edge position in world units.

    \qmlproperty real ClayCanvas::sWidthInWU
    \readonly
    \brief Viewport width in world units.

    \qmlproperty real ClayCanvas::sHeightInWU
    \readonly
    \brief Viewport height in world units.

    \qmlproperty real ClayCanvas::viewPortCenterWuX
    \brief X coordinate of viewport center in world units.

    \qmlproperty real ClayCanvas::viewPortCenterWuY
    \brief Y coordinate of viewport center in world units.

    \qmlproperty bool ClayCanvas::showDebugInfo
    \brief Whether to show the debug overlay with coordinate grid. Toggle with Space key.

    \qmlproperty bool ClayCanvas::keyBoardNavigationEnabled
    \brief Enable keyboard navigation (IJKL for pan, E/D for zoom).

    \qmlproperty Item ClayCanvas::coordSys
    \readonly
    \brief The coordinate system container. Child items should be parented to this.

    \qmlproperty var ClayCanvas::observedItem
    \brief Item that the camera follows automatically. Set to null to disable following.

    \qmlsignal ClayCanvas::keyPressed(var event)
    \brief Emitted when a key is pressed while the canvas has focus.

    \qmlsignal ClayCanvas::keyReleased(var event)
    \brief Emitted when a key is released while the canvas has focus.

    \qmlmethod real ClayCanvas::xToScreen(real xCart)
    \brief Converts a world X coordinate to screen X coordinate.

    \qmlmethod real ClayCanvas::screenXToWorld(real xScr)
    \brief Converts a screen X coordinate to world X coordinate.

    \qmlmethod real ClayCanvas::yToScreen(real yCart)
    \brief Converts a world Y coordinate to screen Y coordinate.

    \qmlmethod real ClayCanvas::screenYToWorld(real yScr)
    \brief Converts a screen Y coordinate to world Y coordinate.
*/
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

    /*!
        \qmlmethod list ClayCanvas::find(object filters)
        \brief Search for items matching filter conditions.

        Returns an array of matching items with their properties.
        All filters are optional and combined with AND.

        Supported filters:
        \list
        \li \c type — class name pattern (* wildcard)
        \li \c objectName — objectName pattern (* wildcard)
        \li \c near — spatial filter: {objectName: "player", radius: 10} or {x: 30, y: 40, radius: 15}
        \li \c where — JS expression evaluated per candidate, e.g. "health < 50"
        \li \c props — array of property names to include in results
        \li \c limit — max results (default 50)
        \endlist

        Distance is in world units.
    */
    function find(filters) {
        if (!filters) filters = {};
        var items = coordSys.children;
        var results = [];
        var limit = filters.limit || 50;

        // Resolve 'near' reference position
        var refX = undefined, refY = undefined, radius = 0;
        if (filters.near) {
            radius = filters.near.radius || 0;
            if (filters.near.x !== undefined && filters.near.y !== undefined) {
                refX = filters.near.x;
                refY = filters.near.y;
            } else {
                // Find reference item by objectName or type
                var refName = filters.near.objectName || "";
                var refType = filters.near.type || "";
                for (var r = 0; r < items.length; r++) {
                    var ref = items[r];
                    if (refName && ref.objectName === refName) {
                        refX = ref.xWu !== undefined ? ref.xWu : screenXToWorld(ref.x);
                        refY = ref.yWu !== undefined ? ref.yWu : screenYToWorld(ref.y);
                        break;
                    }
                    if (refType && _matchPattern(ref.toString(), refType)) {
                        refX = ref.xWu !== undefined ? ref.xWu : screenXToWorld(ref.x);
                        refY = ref.yWu !== undefined ? ref.yWu : screenYToWorld(ref.y);
                        break;
                    }
                }
            }
        }

        for (var i = 0; i < items.length && results.length < limit; i++) {
            var item = items[i];
            var typeName = item.toString().split("(")[0].replace(/^QQuick/, "");

            // Type filter
            if (filters.type && !_matchPattern(typeName, filters.type))
                continue;

            // ObjectName filter
            if (filters.objectName && !_matchPattern(item.objectName || "", filters.objectName))
                continue;

            // Near filter
            var dist = -1;
            if (refX !== undefined && refY !== undefined && radius > 0) {
                var ix = item.xWu !== undefined ? item.xWu : screenXToWorld(item.x);
                var iy = item.yWu !== undefined ? item.yWu : screenYToWorld(item.y);
                dist = Math.hypot(ix - refX, iy - refY);
                if (dist > radius)
                    continue;
            }

            // Where filter
            if (filters.where) {
                try {
                    var fn = new Function("item", "with(item){return " + filters.where + ";}");
                    if (!fn(item)) continue;
                } catch (e) { continue; }
            }

            // Build result
            var match = {type: typeName};
            if (item.objectName) match.objectName = item.objectName;
            if (item.xWu !== undefined) { match.xWu = item.xWu; match.yWu = item.yWu; }
            if (dist >= 0) match.distance = Math.round(dist * 100) / 100;

            // Collect requested properties
            if (filters.props) {
                var p = {};
                for (var j = 0; j < filters.props.length; j++) {
                    var key = filters.props[j];
                    if (item[key] !== undefined) p[key] = item[key];
                }
                match.properties = p;
            }

            results.push(match);
        }

        return results;
    }

    function _matchPattern(str, pattern) {
        if (pattern === "*") return true;
        if (pattern.indexOf("*") < 0) return str.indexOf(pattern) >= 0;
        var regex = new RegExp("^" + pattern.replace(/\*/g, ".*") + "$");
        return regex.test(str);
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
