// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype LineBatch3D
    \inqmlmodule Clayground.Canvas3D
    \brief Renders very large sets of styled polylines in a single instanced draw call.

    LineBatch3D draws 100k+ polylines, each with its own color and width, as
    one instanced draw call. Every line segment becomes one GPU instance over
    a unit-quad base mesh; the vertex shader expands each segment into a
    camera-facing ribbon with round caps, and the per-line style rides in the
    instance attributes. This makes it suitable for map lanes, road overlays,
    flow fields and other cases where thousands of independently styled lines
    must be updated and drawn cheaply.

    There are two ways to feed data:

    \list
    \li The convenience \l lines path, a declarative JS list.
    \li The fast \l setBulk path for generators, using packed binary buffers.
    \endlist

    Individual lines can be moved cheaply with \l updateLinePoints, which
    patches only that line's region of the instance table.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        id: view
        LineBatch3D {
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.Pixel
            lines: [
                { points: [Qt.vector3d(0,0,0), Qt.vector3d(100,50,0)],
                  color: "#00d9ff", width: 3, styleId: 0 },
                { points: [Qt.vector3d(0,0,0), Qt.vector3d(0,80,60)],
                  color: "#ff3366", width: 5, styleId: 0 }
            ]
        }
    }
    \endqml

    \note In Pixel width mode the shader needs the View3D pixel size, so bind
    \l viewportSize to the enclosing View3D's width/height.

    \sa MultiLine3D, LineBatchInstancing, LineBatchGeometry
*/
Model {
    id: root

    /*!
        \qmlproperty enumeration LineBatch3D::widthUnits
        \brief How the per-line width is interpreted.

        \value LineBatch3D.Pixel Width is in screen pixels; on-screen width is
               constant regardless of camera distance (default).
        \value LineBatch3D.World Width is in world units; the ribbon is
               billboarded to face the camera.
    */
    enum WidthUnits { Pixel, World }

    /*!
        \qmlproperty enumeration LineBatch3D::orientation
        \brief How a World-width ribbon is oriented in space.

        \value LineBatch3D.Billboard The ribbon faces the camera (default,
               constant apparent width from any view). This is the historic
               behaviour and the right choice for free-floating lines.
        \value LineBatch3D.Flat The ribbon lies flat in the world \c +Y ground
               plane, so its across axis stays perpendicular to the path within
               that plane and never shears. Use it for ground overlays (road
               markings, lane direction glyphs): a billboarded ribbon tilts its
               across axis out of the ground plane at oblique/top-down views,
               which shears filled pattern glyphs. Only affects World width;
               Pixel-width batches already use the true screen perpendicular.
    */
    enum Orientation { Billboard, Flat }

    /*!
        \qmlproperty list LineBatch3D::lines
        \brief Declarative list of styled polylines (convenience path).

        Each element is an object
        \c{{ points: [Qt.vector3d, ...], color: <color>, width: <real>, styleId: <int> }}.
        A polyline with N points produces N-1 segment instances sharing that
        line's style. For large generated data sets prefer \l setBulk.
    */
    property alias lines: _inst.lines

    /*!
        \qmlproperty int LineBatch3D::widthUnits
        \brief The active width interpretation, one of the WidthUnits values.

        Defaults to LineBatch3D.Pixel.
    */
    property int widthUnits: LineBatch3D.Pixel

    /*!
        \qmlproperty int LineBatch3D::orientation
        \brief The active ribbon orientation, one of the Orientation values.

        Defaults to LineBatch3D.Billboard. Only applies in World width mode.
    */
    property int orientation: LineBatch3D.Billboard

    /*!
        \qmlproperty real LineBatch3D::depthBias
        \brief Pulls the lines toward the camera to win depth fights.

        A positive bias shifts the rendered depth toward the near plane, so
        overlay lines floating just above other geometry (for example a lane
        model above roads) draw on top without a separate render pass.
        Defaults to 0.
    */
    property real depthBias: 0

    /*!
        \qmlproperty vector2d LineBatch3D::viewportSize
        \brief The pixel size of the enclosing View3D.

        Required in Pixel width mode to keep on-screen width constant. Bind it
        to \c{Qt.vector2d(view3D.width, view3D.height)}.
    */
    property vector2d viewportSize: Qt.vector2d(1920, 1080)

    /*!
        \qmlproperty bool LineBatch3D::opaque
        \brief Renders the batch as opaque geometry with early depth rejection.

        When \c false (the default) the batch draws alpha-blended: a style's
        \c opacity multiplier applies and overlapping lines composite by draw
        order. When \c true the batch draws \e without alpha blending and with
        depth writes, so overlapping lines resolve by depth (the nearer line
        wins) instead of blending. This lets the GPU reject occluded fragments
        early and cuts overdraw where many opaque lines stack up (dense lane
        overlays, road networks).

        Visual semantics in opaque mode:
        \list
        \li No translucency: a style's \c opacity below 1.0 does not fade the
            line; the line draws fully opaque (dash gaps still cut out via
            discard, and round caps/joints are unchanged).
        \li Overlap resolves by depth, not by blending. For lines that are
            coplanar and truly coincident in depth, draw resolves in instance
            table order (a tiny deterministic per-instance depth offset breaks
            same-depth ties so the result does not shimmer frame to frame).
        \endlist

        Leave \c false for translucent or additive styling; set \c true for
        dense opaque overlays where depth-correct occlusion and lower overdraw
        matter more than per-line opacity.
    */
    property bool opaque: false

    /*!
        \qmlproperty int LineBatch3D::count
        \readonly
        \brief The number of lines currently in the batch.
    */
    property alias count: _inst.count

    /*!
        \qmlproperty list LineBatch3D::styles
        \brief Per-styleId table of pattern, cap shape, opacity and effects.

        Each element is an object. Only \c dash / \c capRound / \c opacity are
        required; every other key is optional and defaults to the plain solid
        or dashed behaviour, so existing style lists keep rendering unchanged.

        \list
        \li \c dash - \c{[dashLen, gapLen]} in world units (\c{[0, 0]} = solid).
            Also sets the repeat period for \c dot and \c chevron patterns.
        \li \c capRound - round caps when true (default), square when false.
        \li \c opacity - opacity multiplier (blended mode only).
        \li \c pattern - \c "solid"/"dash" (default), \c "dot" (round dots),
            \c "chevron" (V glyphs pointing from a line's start to its end) or
            \c "triangle" (filled isoceles direction glyphs, tip toward the end).
        \li \c glyphWidth - for the \c triangle pattern, the base width as a
            fraction of the ribbon width, range \c{(0, 1]}; \c 0 or absent means
            the full ribbon width. Ignored by the other patterns.
        \li \c patternUnits - \c "world" (default) or \c "screen": whether the
            pattern period is measured in world units or in screen pixels
            (zoom-stable, for HUD/overlay lines).
        \li \c flow - marches the pattern along the line; the on-screen speed is
            \c flow scaled by \l flowTime (0 = static, the default).
        \li \c glow - soft edge falloff across the ribbon instead of a hard edge
            (0 = hard, the default; ~0.3-1.0 for a neon look).
        \li \c pulse - opacity oscillation driven by \l flowTime (0 = none).
        \li \c head - \c{[length, width]} arrowhead at the line's flagged end(s),
            in multiples of line width; absent = no head. Drawn as a classic
            triangle with a real shoulder. The proportions are regulated so the
            head stays arrow-like whatever the request: \c width is clamped to
            \c{[1.5, 8]} (base is always wider than the shaft) and the effective
            \c length is \c{min(request, 2 x head width, segment length)},
            defaulting to \c{~1.1 x head width} when \c length is 0 or invalid.
            On a segment shorter than the head the whole head scales down with
            its proportions preserved, so an over-large fill-the-segment length
            (e.g. \c 40) still yields a well-formed head rather than a needle.
            The tip sits exactly at the segment end and the diagonal edges are
            anti-aliased at every zoom (composes with \c glow and \c pulse).
        \endlist

        The table is baked into a small RGBA32F texture the shader samples per
        fragment; the pattern phase runs continuously along each polyline. Style
        index 0 always defaults to solid, round-capped and fully opaque, so
        lines work unchanged when \c styles is left empty.

        Example:
        \code
        styles: [
            { dash: [0, 0], capRound: true, opacity: 1.0 },              // 0: solid
            { dash: [12, 8], capRound: false, opacity: 1.0 },            // 1: dashed
            { dash: [6, 34], pattern: "dot" },                           // 2: round dots
            { dash: [10, 30], pattern: "chevron", flow: 40, glow: 0.5 }, // 3: flowing chevrons
            { dash: [0, 0], glow: 0.8, head: [3.0, 2.5] }                // 4: glowing arrow
        ]
        \endcode

        \sa flowTime, flowAutoPlay
    */
    property var styles: []

    /*!
        \qmlproperty real LineBatch3D::flowTime
        \brief Animation clock (seconds) driving every flowing/pulsing style.

        A single value shared by the whole batch: each style's \c flow scales it
        to march its pattern, and \c pulse oscillates its opacity from it. The
        batch never ticks itself (rendering stays on-demand); bind this to your
        own clock (typically a \c FrameAnimation's \c elapsedTime) or set
        \l flowAutoPlay to true for the built-in one. Set it explicitly for
        deterministic, frame-exact inspection.
    */
    property real flowTime: 0

    /*!
        \qmlproperty bool LineBatch3D::flowAutoPlay
        \brief Convenience clock that advances \l flowTime automatically.

        When true, an internal \c FrameAnimation drives \l flowTime so flowing
        and pulsing styles animate without any external clock. Defaults to
        false so a batch is never self-animating (Qt renders on demand); leave
        it off and drive \l flowTime yourself when you need to pause, timescale
        or inspect deterministically.
    */
    property bool flowAutoPlay: false

    FrameAnimation {
        running: root.flowAutoPlay
        onTriggered: root.flowTime = elapsedTime
    }

    /*!
        \qmlmethod void LineBatch3D::setBulk(ByteArray positions, ByteArray startIndices, ByteArray colors, ByteArray widths, ByteArray styleIds)
        \brief Fast path for building the batch from packed binary buffers.

        \list
        \li \a positions - float32 xyz triples for every point, concatenated.
        \li \a startIndices - uint32 offsets into the point array, one per line
            plus a trailing sentinel (length N+1); line i uses points
            \c{[startIndices[i], startIndices[i+1])}.
        \li \a colors - rgba8 (4 bytes) per line.
        \li \a widths - float32 per line.
        \li \a styleIds - optional uint16 style index per line, selecting a row
            of \l styles (dash pattern, cap, opacity). Omit the argument (or
            pass an empty buffer) to render every line solid (styleId 0); the
            four-argument call is unchanged.
        \endlist
    */
    function setBulk(positions, startIndices, colors, widths, styleIds) {
        if (styleIds === undefined)
            _inst.setBulk(positions, startIndices, colors, widths)
        else
            _inst.setBulk(positions, startIndices, colors, widths, styleIds)
    }

    /*!
        \qmlmethod void LineBatch3D::updateLinePoints(int lineIndex, list points)
        \brief Moves a single line by patching only its instance-table region.

        Rewrites line \a lineIndex from \a points (a list of Qt.vector3d). When
        the point count keeps the same number of segments, only that line's
        entries are rewritten; otherwise the whole table is rebuilt.
    */
    function updateLinePoints(lineIndex, points) {
        _inst.updateLinePoints(lineIndex, points)
    }

    /*!
        \qmlmethod void LineBatch3D::updateEndpointsBulk(ByteArray positions)
        \brief Rewrites the endpoints of every single-segment line in one pass.

        \a positions is a packed float32 buffer with 6 floats per line
        (\c{p0.xyz, p1.xyz}) in line order. This is the fast per-frame path used
        by ConnectorLayer3D: it patches the affected instance entries in place
        and triggers a single upload, with no geometry rebuild. Lines that are
        not single-segment (two points) are skipped.

        \sa ConnectorLayer3D
    */
    function updateEndpointsBulk(positions) {
        _inst.updateEndpointsBulk(positions)
    }

    /*!
        \qmlmethod void LineBatch3D::updatePolylinesBulk(ByteArray positions, int pointsPerLine)
        \brief Rewrites the points of every uniform-topology line in one pass.

        \a positions is a packed float32 buffer with \c{pointsPerLine * 3} floats
        per line (\c{p0.xyz, p1.xyz, ...}) in line order. This is the fast
        per-frame path used by ConnectorLayer3D for curved connectors: it rewrites
        the matching lines' points and re-uploads once, recomputing per-segment
        path distances so patterns stay continuous along the new curve. Lines
        whose topology does not match (\c{instanceCount != pointsPerLine - 1}) are
        skipped.

        \sa ConnectorLayer3D
    */
    function updatePolylinesBulk(positions, pointsPerLine) {
        _inst.updatePolylinesBulk(positions, pointsPerLine)
    }

    /*!
        \qmlmethod real LineBatch3D::pathLength(int lineId)
        \brief Returns the total length of line \a lineId in world units.

        Read-only query over the batch geometry (0 for an unknown index or a
        line with fewer than two points). Together with \l positionAt this lets
        objects and labels ride along a line without duplicating its geometry.
    */
    function pathLength(lineId) {
        return _inst.pathLength(lineId)
    }

    /*!
        \qmlmethod vector3d LineBatch3D::positionAt(int lineId, real distance)
        \brief Returns the point \a distance world units along line \a lineId.

        The distance is clamped to the line, so 0 gives its first point and any
        value past \l pathLength gives its last. Unknown indices return
        \c{Qt.vector3d(0, 0, 0)}.
    */
    function positionAt(lineId, distance) {
        return _inst.positionAt(lineId, distance)
    }

    // Instanced shadow bounds are O(n) on the CPU without explicit bounds, so
    // keep shadows off (overlay/map lines are unlit anyway).
    castsShadows: false
    receivesShadows: false

    geometry: LineBatchGeometry {
        boundsMin: _inst.boundsMin
        boundsMax: _inst.boundsMax
    }

    instancing: LineBatchInstancing {
        id: _inst
    }

    materials: [
        CustomMaterial {
            id: _mat
            shadingMode: CustomMaterial.Unshaded
            cullMode: Material.NoCulling
            // Default (opaque == false): alpha blending lets styles apply an
            // opacity multiplier; overlapping lines composite by draw order.
            // Depth is still written so lines occlude other geometry.
            // opaque == true: no blending + depth write, so overlapping opaque
            // lines resolve by depth and the GPU can early-reject occluded
            // fragments (lower overdraw). Cap/dash cutouts still discard.
            sourceBlend: root.opaque ? CustomMaterial.NoBlend : CustomMaterial.SrcAlpha
            destinationBlend: root.opaque ? CustomMaterial.NoBlend : CustomMaterial.OneMinusSrcAlpha
            depthDrawMode: Material.AlwaysDepthDraw
            property vector2d viewportSize: root.viewportSize
            property real widthMode: root.widthUnits
            property real orientationMode: root.orientation
            property real depthBias: root.depthBias
            // Shared animation clock for flowing/pulsing styles (seconds).
            property real flowTime: root.flowTime
            // 1.0 in opaque mode enables the deterministic per-instance depth
            // tie-break in the vertex shader; 0.0 disables it when blending.
            property real depthJitter: root.opaque ? 1.0 : 0.0
            property real styleCount: _styleData.styleCount
            property TextureInput styleTable: TextureInput {
                texture: Texture {
                    minFilter: Texture.Nearest
                    magFilter: Texture.Nearest
                    tilingModeHorizontal: Texture.ClampToEdge
                    tilingModeVertical: Texture.ClampToEdge
                    textureData: LineStyleTextureData {
                        id: _styleData
                        styles: root.styles
                    }
                }
            }
            vertexShader: "line_batch.vert"
            fragmentShader: "line_batch.frag"
        }
    ]
}
