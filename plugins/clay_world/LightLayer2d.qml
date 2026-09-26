// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import "lightregistry.js" as LightRegistry

/*!
    \qmltype LightLayer2d
    \inqmlmodule Clayground.World
    \brief Lights a ClayWorld2d with coloured Light2d lights and wall shadows.

    One full-viewport overlay darkens the world to \l ambient and lets the
    Light2d lights brighten and tint it again. Walls block light: hand the
    layer a grid (\l setOccluderGrid()) or a list of rectangles
    (\l setOccluderRects()) and every light that \c castsShadows throws soft
    shadows behind them.

    Walls themselves are lit on the side that faces a light and cast their
    shadow behind them: the part of a ray inside the wall the pixel belongs
    to does not count, nor the part inside a wall a torch is set into.

    Place it as a child of ClayWorld2d and set \l world. The layer moves itself
    into the world's canvas, so it stays locked to the viewport, sits above
    the world's content and below HUD items declared beside it - and a
    ScreenFx2d on the same world grades the lit picture, not the unlit one.

    \qml
    ClayWorld2d {
        id: theWorld
        // ...
        LightLayer2d {
            id: lighting
            world: theWorld
            ambient: "#0b0a12"          // a dungeon; "#6a6a88" is dusk
        }
        Component.onCompleted: lighting.setOccluderGrid(
            cols, rows, cellSize, (cx, cy) => grid[cy][cx] === cellWall)
    }
    \endqml

    How it blends: Qt Quick composes premultiplied, so the layer writes the
    darkening into alpha and the colour of the light into rgb, and the
    screen shows \c{glow + scene * (1 - darkness)}. The scene is scaled by
    the brightest channel of the light that reaches it; the part of the light
    that is colour rather than grey is added on top, scaled by \l glow. It is
    an approximation of multiplying the scene by the light colour - exact for
    white light, and warm light turns grey stone warm.

    At most 16 lights are drawn at once: the lights whose circle reaches
    into the viewport, the brightest and closest first.

    Cost: a pixel pays only for the lights that reach it, and a shadowed
    light marches two occluder samples per grid cell between light and pixel.
    \l resolutionScale renders the layer at a fraction of the viewport's
    resolution and scales it up.

    \sa Light2d, ScreenFx2d, AnchoredMask
*/
Item {
    id: root

    /*!
        \qmlproperty var LightLayer2d::world
        \brief The ClayWorld2d to light.
    */
    property var world: null

    /*!
        \qmlproperty color LightLayer2d::ambient
        \brief Light level where no light reaches.

        Its brightest channel is how much of the scene is visible in the
        dark; its hue tints the dark like a light's colour does. \c "#000000"
        is pitch black, \c "#ffffff" switches darkness off.
    */
    property color ambient: "#101018"

    /*!
        \qmlproperty real LightLayer2d::glow
        \brief How strongly the colour of a light is added on top of the
        brightened scene (0 = lights only brighten).
    */
    property real glow: 0.3

    /*!
        \qmlproperty real LightLayer2d::falloff
        \brief How fast light fades with distance: the light at a fraction
        \c x of the radius is \c{(1 - x)^falloff}. 2 (default) pools light
        around its source, 1 fills the circle more evenly.
    */
    property real falloff: 2

    /*!
        \qmlproperty int LightLayer2d::bands
        \brief Quantises the light level into this many steps, for a retro
        look; 0 (default) is a smooth falloff.
    */
    property int bands: 0

    /*!
        \qmlproperty real LightLayer2d::dither
        \brief Ordered (Bayer 4x4) dither amount in 0..1.

        With \l bands it breaks the band edges into a pattern; without, it
        hides the 8-bit steps of long gradients.
    */
    property real dither: 0

    /*!
        \qmlproperty real LightLayer2d::shadowHardness
        \brief How much wall a ray must cross to be fully blocked, as
        1 / cells. The default 2.5 blocks behind 0.4 cells of wall; lower
        values let light seep through thin walls.
    */
    property real shadowHardness: 2.5

    /*!
        \qmlproperty real LightLayer2d::resolutionScale
        \brief Renders the lighting at this fraction of the viewport's
        resolution (0.25..1) and scales it up linearly.

        Light is smooth, so 0.5 is hard to tell apart from 1 and costs a
        quarter of the fragment work. The dither and band edges get coarser.
    */
    property real resolutionScale: 1

    /*!
        \qmlproperty bool LightLayer2d::active
        \brief When false the layer is not drawn at all.
    */
    property bool active: true

    /*!
        \qmlproperty Item LightLayer2d::emissive
        \readonly
        \brief Parent for things that give off light themselves.

        Items parented here are drawn above the darkness, so a flame, a spark
        or a pair of eyes in the dark keeps its full colour where the floor
        around it is black. The item scrolls with the world and has the size
        of \c{world.room}, so children place themselves exactly as they
        would in the room (\c{y: parent.height - yWu * pixelPerUnit}). It is
        hidden together with the layer, and it does not cast or receive
        light - pair a glowing thing with a Light2d if it should light its
        surroundings.
    */
    readonly property Item emissive: _emissive

    /*!
        \qmlproperty int LightLayer2d::maxLights
        \readonly
        \brief How many lights the shader takes at once.
    */
    readonly property int maxLights: 16

    /*!
        \qmlproperty int LightLayer2d::lightCount
        \readonly
        \brief How many lights were drawn in the last frame.
    */
    readonly property int lightCount: _fx.lightCount

    /*!
        \qmlmethod void LightLayer2d::setOccluderGrid(int cols, int rows, real cellSizeWu, var isSolid, real originXWu, real originYWu)
        \brief Makes the cells of a grid block light.

        \a isSolid is called as \c{isSolid(cx, cy)} for every cell and
        returns true for a wall. Cell (0, 0) is the lower-left one; its
        lower-left corner is at \a originXWu / \a originYWu (optional,
        default: the world's minimum). One call for a whole level: the
        grid becomes a texture of one pixel per cell.
    */
    function setOccluderGrid(cols, rows, cellSizeWu, isSolid, originXWu, originYWu) {
        var cells = new Uint8Array(cols * rows);
        for (var cy = 0; cy < rows; ++cy)
            for (var cx = 0; cx < cols; ++cx)
                cells[cy * cols + cx] = isSolid(cx, cy) ? 1 : 0;
        _setGrid(cols, rows, cellSizeWu, cells, originXWu, originYWu);
    }

    /*!
        \qmlmethod void LightLayer2d::setOccluderRects(list rects, real cellSizeWu)
        \brief Makes rectangles block light.

        Each entry has \c xWu, \c yWu (the top edge, as for a RectBoxBody),
        \c widthWu and \c heightWu - so a list of wall bodies can be passed
        as is. The rectangles are rasterised onto a grid over the world
        bounds with \a cellSizeWu cells (default 1); a cell blocks when a
        rectangle covers its centre.
    */
    function setOccluderRects(rects, cellSizeWu) {
        if (!world) return;
        var cs = cellSizeWu > 0 ? cellSizeWu : 1;
        var ox = world.xWuMin, oy = world.yWuMin;
        var cols = Math.max(1, Math.ceil((world.xWuMax - ox) / cs));
        var rows = Math.max(1, Math.ceil((world.yWuMax - oy) / cs));
        var cells = new Uint8Array(cols * rows);
        for (var i = 0; i < rects.length; ++i) {
            var r = rects[i];
            if (!r) continue;
            var x0 = Math.max(0, Math.round((r.xWu - ox) / cs));
            var x1 = Math.min(cols, Math.round((r.xWu + r.widthWu - ox) / cs));
            var y0 = Math.max(0, Math.round((r.yWu - r.heightWu - oy) / cs));
            var y1 = Math.min(rows, Math.round((r.yWu - oy) / cs));
            for (var cy = y0; cy < y1; ++cy)
                for (var cx = x0; cx < x1; ++cx)
                    cells[cy * cols + cx] = 1;
        }
        _setGrid(cols, rows, cs, cells, ox, oy);
    }

    /*!
        \qmlmethod void LightLayer2d::setOccluderCell(int cx, int cy, bool solid)
        \brief Changes one cell of the current occluder grid - a door opens,
        a wall crumbles.
    */
    function setOccluderCell(cx, cy, solid) {
        if (!_cells || cx < 0 || cy < 0 || cx >= _cols || cy >= _rows) return;
        _cells[cy * _cols + cx] = solid ? 1 : 0;
        _occCanvas.requestPaint();
    }

    /*!
        \qmlmethod bool LightLayer2d::isOccluded(real xWu, real yWu)
        \brief Whether the occluder grid blocks light at this world position.
    */
    function isOccluded(xWu, yWu) {
        if (!_cells) return false;
        var cx = Math.floor((xWu - _originX) / _cellSize);
        var cy = Math.floor((yWu - _originY) / _cellSize);
        if (cx < 0 || cy < 0 || cx >= _cols || cy >= _rows) return false;
        return _cells[cy * _cols + cx] === 1;
    }

    /*!
        \qmlmethod void LightLayer2d::clearOccluders()
        \brief Removes all occluders; lights no longer cast shadows.
    */
    function clearOccluders() {
        _cells = null;
        _cols = 0;
        _rows = 0;
    }

    /*!
        \qmlmethod list LightLayer2d::visibleLights()
        \brief The Light2d items drawn right now, brightest and closest first.
    */
    function visibleLights() {
        return _picked.slice();
    }

    /*!
        \qmlmethod object LightLayer2d::clayInspect()
        \brief Reports the layer's settings, lights and occluder grid as
        plain JSON, for tooling. Pull-only and side-effect free.
    */
    function clayInspect() {
        var drawn = [];
        for (var i = 0; i < _picked.length; ++i) {
            var l = _picked[i];
            var p = l.positionWu();
            drawn.push({"objectName": l.objectName || null,
                        "positionWu": [p.x, p.y], "radius": l.radius,
                        "color": l.color.toString(), "intensity": l.intensity,
                        "flicker": l.flicker, "castsShadows": l.castsShadows});
        }
        return {
            "type": "LightLayer2d",
            "active": active,
            "ambient": ambient.toString(),
            "glow": glow,
            "bands": bands,
            "dither": dither,
            "falloff": falloff,
            "resolutionScale": resolutionScale,
            "lightsRegistered": _mine().length,
            "lightsDrawn": drawn,
            "maxLights": maxLights,
            "occluderGrid": _cells ? {"cols": _cols, "rows": _rows,
                                      "cellSizeWu": _cellSize,
                                      "originWu": [_originX, _originY]} : null,
            "shadowHardness": shadowHardness
        };
    }

    // -- internals ------------------------------------------------------

    property var _cells: null
    property int _cols: 0
    property int _rows: 0
    property real _cellSize: 1
    property real _originX: 0
    property real _originY: 0
    property var _picked: []

    function _setGrid(cols, rows, cellSize, cells, ox, oy) {
        _originX = (ox !== undefined && ox !== null) ? ox : (world ? world.xWuMin : 0);
        _originY = (oy !== undefined && oy !== null) ? oy : (world ? world.yWuMin : 0);
        _cellSize = cellSize;
        _cols = cols;
        _rows = rows;
        _cells = cells;
        _occCanvas.requestPaint();
    }

    function _mine() {
        var all = LightRegistry.lights;
        var out = [];
        for (var i = 0; i < all.length; ++i) {
            var l = all[i];
            if (l && (l.lightLayer === null || l.lightLayer === undefined || l.lightLayer === root))
                out.push(l);
        }
        return out;
    }

    readonly property var _canvas: world ? world.canvas : null

    // Collects the lights that reach into the viewport and hands them to the
    // shader. Runs every frame: lights follow physics bodies, and reading a
    // few dozen positions is cheaper than wiring change signals to each.
    function _update(elapsed) {
        var c = _canvas;
        if (!c) return;
        var vx0 = c.xInWU, vy1 = c.yInWU;
        var vw = c.sWidthInWU, vh = c.sHeightInWU;
        var vx1 = vx0 + vw, vy0 = vy1 - vh;
        var cx = vx0 + vw / 2, cy = vy0 + vh / 2;
        var all = _mine();
        var cand = [];
        for (var i = 0; i < all.length; ++i) {
            var l = all[i];
            if (!l.enabled || l.radius <= 0 || l.intensity <= 0) continue;
            var p = l.positionWu();
            var r = l.radius;
            // Circle vs. viewport rectangle.
            var nx = Math.max(vx0, Math.min(p.x, vx1));
            var ny = Math.max(vy0, Math.min(p.y, vy1));
            var dx = p.x - nx, dy = p.y - ny;
            if (dx * dx + dy * dy >= r * r) continue;
            var dc = Math.hypot(p.x - cx, p.y - cy);
            cand.push({"l": l, "p": p, "score": l.intensity * r / (1 + dc)});
        }
        if (cand.length > maxLights)
            cand.sort(function(a, b) { return b.score - a.score; });
        var n = Math.min(cand.length, maxLights);
        var picked = [];
        for (var k = 0; k < n; ++k) {
            var e = cand[k];
            var li = e.l;
            var col = li.color;
            var ph = li.phase % 1000;
            _fx["p" + k] = Qt.vector4d(e.p.x, e.p.y, li.radius,
                                       li.castsShadows ? ph : -1 - ph);
            _fx["c" + k] = Qt.vector4d(col.r * li.intensity, col.g * li.intensity,
                                       col.b * li.intensity,
                                       Math.max(0, Math.min(1, li.flicker)));
            picked.push(li);
        }
        _fx.lightCount = n;
        _fx.view = Qt.vector4d(vx0, vy1, vw, vh);
        _picked = picked;
        if (elapsed !== undefined)
            _fx.time = elapsed;
    }

    onWorldChanged: _adopt()
    Component.onCompleted: _adopt()
    function _adopt() {
        // Inside the canvas the layer is part of what a ScreenFx2d captures,
        // and it stays below HUD items that are siblings in the world.
        if (world && world.canvas && parent !== world.canvas)
            parent = world.canvas;
    }

    anchors.fill: parent
    z: 100
    visible: active && !!_canvas

    // Above the darkness, moving with the room: the room is the canvas'
    // scrolling content item, so mirroring its geometry keeps world
    // coordinates identical for everything placed in here.
    Item {
        id: _emissive
        parent: root._canvas ? root._canvas : root
        readonly property var _room: root.world ? root.world.room : null
        property real pixelPerUnit: root.world ? root.world.pixelPerUnit : 1
        x: _room ? _room.x : 0
        y: _room ? _room.y : 0
        width: _room ? _room.width : 0
        height: _room ? _room.height : 0
        z: 101
        visible: root.visible
    }

    FrameAnimation {
        running: root.visible
        onTriggered: root._update(elapsedTime)
    }

    Canvas {
        id: _occCanvas
        width: Math.max(1, root._cols)
        height: Math.max(1, root._rows)
        canvasSize: Qt.size(width, height)
        smooth: false
        antialiasing: false
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "#000000";
            ctx.fillRect(0, 0, width, height);
            var cells = root._cells;
            if (!cells) return;
            ctx.fillStyle = "#ffffff";
            var cols = root._cols, rows = root._rows;
            // Row 0 of the canvas is the top, cell row 0 is the bottom. Runs
            // of solid cells become one rect each.
            for (var cy = 0; cy < rows; ++cy) {
                var y = rows - 1 - cy;
                var cx = 0;
                while (cx < cols) {
                    if (cells[cy * cols + cx] !== 1) { ++cx; continue; }
                    var start = cx;
                    while (cx < cols && cells[cy * cols + cx] === 1) ++cx;
                    ctx.fillRect(start, y, cx - start, 1);
                }
            }
        }
    }

    ShaderEffectSource {
        id: _occSource
        sourceItem: _occCanvas
        hideSource: true
        visible: false
        smooth: true
        live: true
        // Exactly one texel per cell: linear filtering between cell centres
        // is what softens the shadow edges.
        textureSize: Qt.size(Math.max(1, root._cols), Math.max(1, root._rows))
    }

    Item {
        id: _lowRes
        readonly property real s: Math.max(0.25, Math.min(1, root.resolutionScale))
        width: root.width * s
        height: root.height * s
        scale: 1 / s
        transformOrigin: Item.TopLeft
        layer.enabled: s < 1
        layer.smooth: true

        ShaderEffect {
            id: _fx
            anchors.fill: parent
            fragmentShader: "light_layer.frag.qsb"

            property var occluders: _occSource
            property vector4d view: Qt.vector4d(0, 0, 1, 1)
            property color ambient: root.ambient
            property vector4d occ: Qt.vector4d(root._originX, root._originY,
                                               root._cellSize, root._cells ? 1 : 0)
            property vector4d occParams: Qt.vector4d(Math.max(1, root._cols),
                                                     Math.max(1, root._rows),
                                                     root.shadowHardness, 0)
            property real time: 0
            property real lightCount: 0
            property real glow: root.glow
            property real bands: root.bands
            property real dither: root.dither
            property real falloff: Math.max(0.1, root.falloff)

            property vector4d p0; property vector4d c0
            property vector4d p1; property vector4d c1
            property vector4d p2; property vector4d c2
            property vector4d p3; property vector4d c3
            property vector4d p4; property vector4d c4
            property vector4d p5; property vector4d c5
            property vector4d p6; property vector4d c6
            property vector4d p7; property vector4d c7
            property vector4d p8; property vector4d c8
            property vector4d p9; property vector4d c9
            property vector4d p10; property vector4d c10
            property vector4d p11; property vector4d c11
            property vector4d p12; property vector4d c12
            property vector4d p13; property vector4d c13
            property vector4d p14; property vector4d c14
            property vector4d p15; property vector4d c15
        }
    }
}
