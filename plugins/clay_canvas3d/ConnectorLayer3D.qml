// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype ConnectorLayer3D
    \inqmlmodule Clayground.Canvas3D
    \brief Draws many dynamic \l Connector3D lines as a single instanced batch.

    ConnectorLayer3D owns one \l LineBatch3D and collects the \l Connector3D
    items that target it, so N connectors cost a single draw call. Every frame
    it reads the scene positions of each connector's \c from and \c to nodes and,
    when any endpoint moved, patches only the changed entries of the instance
    table and issues one upload - no geometry rebuild. Connectors can be added
    and removed at runtime (Repeater3D-friendly); membership changes rebuild the
    batch once, coalesced across a frame.

    A \l Connector3D attaches to a layer either by being declared inside it or by
    setting its \l{Connector3D::layer}{layer} property (the robust choice for
    Repeater3D delegates).

    \note Place the layer at the scene root without a transform: connector
    endpoints are taken as scene positions and fed to the batch directly.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        id: view
        ConnectorLayer3D {
            id: links
            viewportSize: Qt.vector2d(view.width, view.height)
            color: "#00d9ff"
            width: 2
        }

        Repeater3D {
            model: satellites
            Node {
                id: sat
                Connector3D { layer: links; from: sat; to: hub }
            }
        }
    }
    \endqml

    \sa Connector3D, LineBatch3D
*/
Node {
    id: root

    // Marker used by Connector3D to auto-discover an enclosing layer.
    readonly property bool isConnectorLayer3D: true

    /*!
        \qmlproperty color ConnectorLayer3D::color
        \brief Default line color for connectors that do not set their own.
    */
    property color color: "#00d9ff"

    /*!
        \qmlproperty real ConnectorLayer3D::width
        \brief Default line width for connectors that do not set their own.
    */
    property real width: 2

    /*!
        \qmlproperty int ConnectorLayer3D::styleId
        \brief Default styleId for connectors that do not set their own.
    */
    property int styleId: 0

    /*!
        \qmlproperty enumeration ConnectorLayer3D::widthUnits
        \brief How connector width is interpreted, see \l LineBatch3D::widthUnits.
    */
    property int widthUnits: LineBatch3D.Pixel

    /*!
        \qmlproperty vector2d ConnectorLayer3D::viewportSize
        \brief The enclosing View3D pixel size, forwarded to the batch. Required
        in Pixel width mode.
    */
    property vector2d viewportSize: Qt.vector2d(1920, 1080)

    /*!
        \qmlproperty real ConnectorLayer3D::depthBias
        \brief Depth bias forwarded to the batch, see \l LineBatch3D::depthBias.
    */
    property real depthBias: 0

    /*!
        \qmlproperty list ConnectorLayer3D::styles
        \brief Style table forwarded to the batch, see \l LineBatch3D::styles.
    */
    property var styles: []

    /*!
        \qmlproperty int ConnectorLayer3D::count
        \readonly
        \brief The number of connectors currently drawn in the batch.
    */
    readonly property int count: _batch.count

    // --- registration API (called by Connector3D) --------------------------

    /*! \internal */
    function register(c) {
        if (_connectors.indexOf(c) < 0) {
            _connectors.push(c)
            _scheduleRebuild()
        }
    }

    /*! \internal */
    function unregister(c) {
        var i = _connectors.indexOf(c)
        if (i >= 0) {
            _connectors.splice(i, 1)
            _scheduleRebuild()
        }
    }

    /*! \internal Membership or per-connector style change: rebuild the batch. */
    function markDirty(c) {
        _scheduleRebuild()
    }

    // --- internals ---------------------------------------------------------

    property var _connectors: []
    property bool _membershipDirty: false
    property var _posBuf: null
    readonly property real _eps: 1e-4

    function _scheduleRebuild() {
        _membershipDirty = true
        Qt.callLater(_rebuild)
    }

    function _pos(node) {
        return node ? node.scenePosition : Qt.vector3d(0, 0, 0)
    }

    function _rebuild() {
        _membershipDirty = false
        var n = _connectors.length
        var arr = new Array(n)
        var buf = new Float32Array(n * 6)
        for (var i = 0; i < n; ++i) {
            var c = _connectors[i]
            var hasBoth = c.from && c.to
            var p0 = _pos(c.from)
            var p1 = _pos(c.to)
            arr[i] = {
                points: [p0, p1],
                color: c.color,
                // Unbound connectors are hidden until both endpoints exist.
                width: hasBoth ? c.width : 0,
                styleId: c.styleId
            }
            var b = i * 6
            buf[b] = p0.x; buf[b + 1] = p0.y; buf[b + 2] = p0.z
            buf[b + 3] = p1.x; buf[b + 4] = p1.y; buf[b + 5] = p1.z
        }
        _posBuf = buf
        _batch.lines = arr
    }

    function _tick() {
        if (_membershipDirty || !_posBuf)
            return
        var n = _connectors.length
        if (n === 0)
            return
        var buf = _posBuf
        var eps = _eps
        var moved = false
        for (var i = 0; i < n; ++i) {
            var c = _connectors[i]
            if (!c.from || !c.to)
                continue
            var p0 = c.from.scenePosition
            var p1 = c.to.scenePosition
            var b = i * 6
            if (Math.abs(buf[b] - p0.x) > eps || Math.abs(buf[b + 1] - p0.y) > eps ||
                Math.abs(buf[b + 2] - p0.z) > eps || Math.abs(buf[b + 3] - p1.x) > eps ||
                Math.abs(buf[b + 4] - p1.y) > eps || Math.abs(buf[b + 5] - p1.z) > eps) {
                buf[b] = p0.x; buf[b + 1] = p0.y; buf[b + 2] = p0.z
                buf[b + 3] = p1.x; buf[b + 4] = p1.y; buf[b + 5] = p1.z
                moved = true
            }
        }
        if (moved)
            _batch.updateEndpointsBulk(buf.buffer)
    }

    LineBatch3D {
        id: _batch
        widthUnits: root.widthUnits
        viewportSize: root.viewportSize
        depthBias: root.depthBias
        styles: root.styles
    }

    // Endpoint tracking. Runs every frame but only uploads when a position
    // actually changed, so a static graph costs just the comparison loop.
    FrameAnimation {
        running: true
        onTriggered: root._tick()
    }
}
