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
        \qmlproperty int LineBatch3D::count
        \readonly
        \brief The number of lines currently in the batch.
    */
    property alias count: _inst.count

    /*!
        \qmlproperty list LineBatch3D::styles
        \brief Per-styleId table of dash pattern, cap shape and opacity.

        Each element is an object
        \c{{ dash: [dashLen, gapLen], capRound: <bool>, opacity: <real> }}
        where \c dashLen and \c gapLen are in world units (\c{[0, 0]} = solid).
        A line's \c styleId (set per line via \l lines) selects the row.

        The table is baked into a tiny RGBA32F texture the shader samples per
        fragment; the dash phase runs continuously along each polyline. Style
        index 0 always defaults to solid, round-capped and fully opaque, so
        lines work unchanged when \c styles is left empty.

        Example:
        \code
        styles: [
            { dash: [0, 0], capRound: true, opacity: 1.0 },   // 0: solid
            { dash: [12, 8], capRound: false, opacity: 1.0 }, // 1: dashed
            { dash: [1, 6], capRound: true, opacity: 0.8 }    // 2: dotted
        ]
        \endcode
    */
    property var styles: []

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
            // Alpha blending lets styles apply an opacity multiplier; fully
            // opaque lines (the default) render identically. Depth is still
            // written so lines occlude each other as before.
            sourceBlend: CustomMaterial.SrcAlpha
            destinationBlend: CustomMaterial.OneMinusSrcAlpha
            depthDrawMode: Material.AlwaysDepthDraw
            property vector2d viewportSize: root.viewportSize
            property real widthMode: root.widthUnits
            property real depthBias: root.depthBias
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
