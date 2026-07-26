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
        \qmlproperty real ConnectorLayer3D::flowTime
        \brief Animation clock forwarded to the batch, see \l LineBatch3D::flowTime.

        Drive it from your own clock (typically a \c FrameAnimation's
        \c elapsedTime) to march flowing/pulsing connector styles. Gate that clock
        on the layer's visibility so idle connectors cost nothing.
    */
    property real flowTime: 0

    /*!
        \qmlproperty int ConnectorLayer3D::segmentsPerLink
        \brief Number of straight segments each connector is drawn with.

        The default \c 1 draws every connector as a single straight segment and
        keeps the fast endpoint-only per-frame path unchanged. A value \c{> 1}
        samples each connector as a quadratic bezier arc (lifted by \l arcHeight)
        with \c segmentsPerLink segments, so flowing patterns curve along a
        mail-style arc while the whole layer stays one draw call. Changing this at
        runtime rebuilds the batch.
    */
    property int segmentsPerLink: 1

    /*!
        \qmlproperty real ConnectorLayer3D::arcHeight
        \brief Arc lift as a fraction of link length (only when \l segmentsPerLink > 1).

        The bezier control point sits at the link midpoint raised by
        \c{arcHeight * linkLength} along world +Y, so longer links bow higher.
        Ignored while \l segmentsPerLink is \c 1 (straight links).
    */
    property real arcHeight: 0.18

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
    // Curved-link state: _endptBuf holds the current from/to positions (6 floats
    // per link) for the move test; _sampleBuf holds the sampled arc points
    // (segmentsPerLink+1 points per link) uploaded via updatePolylinesBulk.
    property var _endptBuf: null
    property var _sampleBuf: null
    readonly property real _eps: 1e-4

    onSegmentsPerLinkChanged: _scheduleRebuild()
    onArcHeightChanged: _scheduleRebuild()

    function _scheduleRebuild() {
        _membershipDirty = true
        Qt.callLater(_rebuild)
    }

    function _pos(node) {
        return node ? node.scenePosition : Qt.vector3d(0, 0, 0)
    }

    // Write a quadratic bezier arc (p0 -> ctrl -> p2, ctrl = midpoint lifted by
    // arcHeight * linkLength along +Y) sampled at pts points into buf at off.
    function _writeArc(p0x, p0y, p0z, p2x, p2y, p2z, pts, buf, off) {
        var dx = p2x - p0x, dy = p2y - p0y, dz = p2z - p0z
        var linkLen = Math.sqrt(dx * dx + dy * dy + dz * dz)
        var cx = (p0x + p2x) * 0.5
        var cy = (p0y + p2y) * 0.5 + root.arcHeight * linkLen
        var cz = (p0z + p2z) * 0.5
        var last = pts - 1
        for (var k = 0; k < pts; ++k) {
            var t = k / last
            var u = 1 - t
            var b0 = u * u, b1 = 2 * u * t, b2 = t * t
            var o = off + k * 3
            buf[o]     = b0 * p0x + b1 * cx + b2 * p2x
            buf[o + 1] = b0 * p0y + b1 * cy + b2 * p2y
            buf[o + 2] = b0 * p0z + b1 * cz + b2 * p2z
        }
    }

    function _rebuild() {
        _membershipDirty = false
        if (segmentsPerLink > 1) {
            _rebuildCurved()
            return
        }
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
        if (segmentsPerLink > 1) {
            _tickCurved()
            return
        }
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

    // --- curved-link path (segmentsPerLink > 1) ----------------------------

    function _rebuildCurved() {
        var n = _connectors.length
        var pts = segmentsPerLink + 1
        var stride = pts * 3
        var arr = new Array(n)
        var endpts = new Float32Array(n * 6)
        var samples = new Float32Array(n * stride)
        for (var i = 0; i < n; ++i) {
            var c = _connectors[i]
            var hasBoth = c.from && c.to
            var p0 = _pos(c.from)
            var p2 = _pos(c.to)
            var e = i * 6
            endpts[e] = p0.x; endpts[e + 1] = p0.y; endpts[e + 2] = p0.z
            endpts[e + 3] = p2.x; endpts[e + 4] = p2.y; endpts[e + 5] = p2.z
            var off = i * stride
            _writeArc(p0.x, p0.y, p0.z, p2.x, p2.y, p2.z, pts, samples, off)
            var linePoints = new Array(pts)
            for (var k = 0; k < pts; ++k) {
                var o = off + k * 3
                linePoints[k] = Qt.vector3d(samples[o], samples[o + 1], samples[o + 2])
            }
            arr[i] = {
                points: linePoints,
                color: c.color,
                // Unbound connectors are hidden until both endpoints exist.
                width: hasBoth ? c.width : 0,
                styleId: c.styleId
            }
        }
        _endptBuf = endpts
        _sampleBuf = samples
        _batch.lines = arr
    }

    function _tickCurved() {
        if (_membershipDirty || !_sampleBuf)
            return
        var n = _connectors.length
        if (n === 0)
            return
        var pts = segmentsPerLink + 1
        var stride = pts * 3
        var endpts = _endptBuf
        var samples = _sampleBuf
        var eps = _eps
        var moved = false
        for (var i = 0; i < n; ++i) {
            var c = _connectors[i]
            if (!c.from || !c.to)
                continue
            var p0 = c.from.scenePosition
            var p2 = c.to.scenePosition
            var e = i * 6
            if (Math.abs(endpts[e] - p0.x) > eps || Math.abs(endpts[e + 1] - p0.y) > eps ||
                Math.abs(endpts[e + 2] - p0.z) > eps || Math.abs(endpts[e + 3] - p2.x) > eps ||
                Math.abs(endpts[e + 4] - p2.y) > eps || Math.abs(endpts[e + 5] - p2.z) > eps) {
                endpts[e] = p0.x; endpts[e + 1] = p0.y; endpts[e + 2] = p0.z
                endpts[e + 3] = p2.x; endpts[e + 4] = p2.y; endpts[e + 5] = p2.z
                _writeArc(p0.x, p0.y, p0.z, p2.x, p2.y, p2.z, pts, samples, i * stride)
                moved = true
            }
        }
        if (moved)
            _batch.updatePolylinesBulk(samples.buffer, pts)
    }

    LineBatch3D {
        id: _batch
        widthUnits: root.widthUnits
        viewportSize: root.viewportSize
        depthBias: root.depthBias
        styles: root.styles
        flowTime: root.flowTime
    }

    // Endpoint tracking. Runs every frame but only uploads when a position
    // actually changed, so a static graph costs just the comparison loop.
    FrameAnimation {
        running: true
        onTriggered: root._tick()
    }
}
