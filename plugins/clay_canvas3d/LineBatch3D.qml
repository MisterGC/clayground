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
        \qmlmethod void LineBatch3D::setBulk(ByteArray positions, ByteArray startIndices, ByteArray colors, ByteArray widths)
        \brief Fast path for building the batch from packed binary buffers.

        \list
        \li \a positions - float32 xyz triples for every point, concatenated.
        \li \a startIndices - uint32 offsets into the point array, one per line
            plus a trailing sentinel (length N+1); line i uses points
            \c{[startIndices[i], startIndices[i+1])}.
        \li \a colors - rgba8 (4 bytes) per line.
        \li \a widths - float32 per line.
        \endlist

        styleId defaults to 0 for every line on this path.
    */
    function setBulk(positions, startIndices, colors, widths) {
        _inst.setBulk(positions, startIndices, colors, widths)
    }

    /*!
        \qmlmethod void LineBatch3D::updateLinePoints(int lineIndex, list points)
        \brief Moves a single line by patching only its instance-table region.

        \a points is a list of Qt.vector3d. When the point count keeps the same
        number of segments, only that line's entries are rewritten; otherwise
        the whole table is rebuilt.
    */
    function updateLinePoints(lineIndex, points) {
        _inst.updateLinePoints(lineIndex, points)
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
            property vector2d viewportSize: root.viewportSize
            property real widthMode: root.widthUnits
            property real depthBias: root.depthBias
            vertexShader: "line_batch.vert"
            fragmentShader: "line_batch.frag"
        }
    ]
}
