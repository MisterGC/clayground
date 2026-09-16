// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype Label3D
    \inqmlmodule Clayground.Canvas3D
    \brief A camera-facing callout label anchored to a 3D node or position.

    Label3D draws crisp, readable text (a rounded "pill" background with an
    optional icon) that names or annotates scene content the way technical
    illustrations do. It tracks either a moving \l anchorNode or a fixed
    \l anchorPosition, sits at that anchor plus a world-space \l labelOffset, and
    turns to face the \l camera every frame. The text is rendered as a Qt Quick
    item parented under a QtQuick3D \c Node (an Item2D), so it stays razor-sharp
    at any zoom and is never lit or shadowed.

    By default the label keeps a constant on-screen pixel size
    (\c{sizeMode: Label3D.Screen}); switch to \c Label3D.World to let it scale
    with the scene. An optional \l showLeader draws a thin line from the pill edge
    to the anchor - the offset-callout look.

    \note Place Label3D at the scene root (a direct child of the View3D or of an
    untransformed node): its position is derived from anchor scene positions, and
    the optional leader is drawn in that same untransformed space.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        id: view

        Label3D {
            view: view
            anchorNode: reactor
            text: "REACTOR CORE"
            labelOffset: Qt.vector3d(0, 40, 0)
            showLeader: true
        }
    }
    \endqml

    \sa PathLabel3D, LabelBatch3D, ConnectorLayer3D
*/
Node {
    id: root

    /*!
        \qmlproperty enumeration Label3D::sizeMode
        \brief Whether the label keeps a constant on-screen size or scales with the scene.

        \value Label3D.Screen The pill holds a constant on-screen height of
               \l screenHeight pixels regardless of camera distance (the default,
               UI-like behaviour).
        \value Label3D.World The pill has a fixed world height of \l worldHeight
               units and shrinks/grows with zoom like scene geometry.
    */
    enum SizeMode { Screen, World }

    /*!
        \qmlproperty int Label3D::sizeMode
        \brief The active size mode, see \l{Label3D::sizeMode}{SizeMode}.
    */
    property int sizeMode: Label3D.Screen

    /*!
        \qmlproperty string Label3D::text
        \brief The label text.
    */
    property string text: ""

    /*!
        \qmlproperty url Label3D::iconSource
        \brief Optional icon shown left of the text. Empty hides it.
    */
    property url iconSource: ""

    /*!
        \qmlproperty QtObject Label3D::anchorNode
        \brief The node the label tracks; its scene position drives placement.

        When set, it takes precedence over \l anchorPosition and the label follows
        the node as it moves.
    */
    property var anchorNode: null

    /*!
        \qmlproperty vector3d Label3D::anchorPosition
        \brief Fixed scene position to anchor to when \l anchorNode is null.
    */
    property vector3d anchorPosition: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty vector3d Label3D::labelOffset
        \brief World-space offset of the pill from the anchor.

        The pill is placed at \c{anchor + labelOffset}. A small upward offset is
        the default; larger offsets combined with \l showLeader produce the
        offset-callout look.
    */
    property vector3d labelOffset: Qt.vector3d(0, 8, 0)

    /*!
        \qmlproperty QtObject Label3D::view
        \brief The enclosing View3D, used to resolve the \l camera, size the
        leader and register with the per-view label registry.
    */
    property var view: null

    /*!
        \qmlproperty QtObject Label3D::camera
        \brief The camera the label faces. Defaults to \c{view.camera}.
    */
    property var camera: root.view ? root.view.camera : null

    /*!
        \qmlproperty real Label3D::screenHeight
        \brief Target on-screen pill height in pixels (Screen size mode).
    */
    property real screenHeight: 26

    /*!
        \qmlproperty real Label3D::worldHeight
        \brief Pill height in world units (World size mode).
    */
    property real worldHeight: 24

    /*!
        \qmlproperty real Label3D::minScreenSize
        \brief Lower clamp for the on-screen pill height in pixels (0 disables).
    */
    property real minScreenSize: 0

    /*!
        \qmlproperty real Label3D::maxScreenSize
        \brief Upper clamp for the on-screen pill height in pixels (0 disables).
    */
    property real maxScreenSize: 0

    /*!
        \qmlproperty bool Label3D::distanceFade
        \brief When true, fade the label out with camera distance (Screen mode).
    */
    property bool distanceFade: false

    /*!
        \qmlproperty real Label3D::fadeNear
        \brief Camera distance at and below which the label is fully opaque.
    */
    property real fadeNear: 800

    /*!
        \qmlproperty real Label3D::fadeFar
        \brief Camera distance at and beyond which the label is fully transparent.
    */
    property real fadeFar: 2500

    /*!
        \qmlproperty bool Label3D::showLeader
        \brief When true, draw a thin line from the pill edge to the anchor.
    */
    property bool showLeader: false

    /*!
        \qmlproperty int Label3D::priority
        \brief Ordering hint for the future declutter manager; higher wins.

        No behaviour is attached yet: the property is shipped now so scenes can
        express relative label importance before the manager exists. When it
        arrives it will greedily keep non-overlapping labels highest-priority
        first, hiding lower-priority labels that would collide.
    */
    property int priority: 0

    /*!
        \qmlproperty real Label3D::scaleQuantum
        \brief Relative scale change required before the pill is re-scaled (0 disables).

        In Screen size mode the pill's scale follows the camera distance, so a
        moving camera would re-scale - and therefore re-rasterize - the text
        every single frame, which reads as high-frequency shimmer. Holding the
        scale until it drifts past this fraction (2% by default) keeps the
        glyphs stable while the label still tracks depth.
    */
    property real scaleQuantum: 0.02

    /*!
        \qmlproperty QtObject Label3D::labelStyle
        \brief Grouped pill styling: colors, radius, padding, halo and font.

        \table
        \header \li Sub-property \li Meaning
        \row \li \c background   \li Pill fill color (dark semi-transparent default).
        \row \li \c textColor    \li Text color.
        \row \li \c borderColor  \li Pill border color.
        \row \li \c borderWidth  \li Pill border width in pixels (0 = no border).
        \row \li \c radius       \li Corner radius; negative means a full pill (height/2).
        \row \li \c paddingH     \li Horizontal padding in pixels.
        \row \li \c paddingV     \li Vertical padding in pixels.
        \row \li \c halo         \li Whether the text gets an outline halo for busy backgrounds.
        \row \li \c haloColor    \li Halo color.
        \row \li \c fontFamily   \li Text font family.
        \row \li \c fontSize     \li Text pixel size.
        \row \li \c bold         \li Whether the text is bold.
        \endtable
    */
    property LabelStyle labelStyle: LabelStyle {}

    /*!
        \qmlproperty QtObject Label3D::leaderStyle
        \brief Grouped leader-line styling: \c color and \c width (pixels).
    */
    property LeaderStyle leaderStyle: LeaderStyle {}

    // Grouped-style value types. Defined as inline components so the sub-property
    // set is statically known (grouped assignment and qmllint both resolve them).
    component LabelStyle: QtObject {
        property color background: "#cc16213e"
        property color textColor: "#ffffff"
        property color borderColor: "#00d9ff"
        property real borderWidth: 0
        property real radius: -1
        property real paddingH: 14
        property real paddingV: 8
        property bool halo: true
        property color haloColor: "#000000"
        property string fontFamily: root.monoFont
        property int fontSize: 22
        property bool bold: true
    }
    component LeaderStyle: QtObject {
        property color color: "#00d9ff"
        property real width: 2
    }

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Placement: anchor scene position plus the world-space offset. Reading
    // _tick keeps a physics-/programmatically-moved anchor tracked without lag.
    position: {
        root._tick
        var a = root.anchorNode ? root.anchorNode.scenePosition : root.anchorPosition
        return Qt.vector3d(a.x + root.labelOffset.x, a.y + root.labelOffset.y,
                           a.z + root.labelOffset.z)
    }

    // --- on-demand rendering tick ------------------------------------------
    // A billboard/scale binding returns the same value while the camera is
    // static and so never marks the View3D dirty; a frame tick drives
    // re-evaluation. The tick is not a per-label FrameAnimation: Label3DRegistry
    // owns one shared ticker per view and calls _applyTick() on this label only
    // while it is visible and only when the camera or this label's anchor moved,
    // so N labels cost one animation and a still scene costs nothing.
    property real _tick: 0
    property bool _warnedNoCamera: false

    // Cached pill logical height, updated imperatively when the content resizes.
    // The scale binding reads this value instead of _pill.implicitHeight live, so
    // scaling the carrier does not form a dependency cycle through the Item2D.
    property real _pillLogicalHeight: 0

    // Bumps the frame tick (re-evaluating the tick-dependent bindings) and keeps
    // the leader in step. Called by the registry's shared per-view ticker.
    function _applyTick(elapsed) {
        root._tick = elapsed
        root._updateScale()
        root._maybeUpdateLeader()
    }

    // Quantized scale: recomputed every tick, applied only when it has moved
    // more than scaleQuantum. Written imperatively so the binding that reads
    // it never feeds itself.
    property real _appliedScale: 0
    function _updateScale() {
        var s = root._computeScale()
        if (root._appliedScale <= 0 || root.scaleQuantum <= 0
            || Math.abs(s - root._appliedScale) > root._appliedScale * root.scaleQuantum)
            root._appliedScale = s
    }
    onScreenHeightChanged: _updateScale()
    onWorldHeightChanged: _updateScale()
    onSizeModeChanged: _updateScale()
    on_PillLogicalHeightChanged: _updateScale()

    // Cheap movement probe the shared ticker uses to skip still labels: reports
    // whether the anchor's scene position changed since the last pass (a moving
    // anchorNode must keep tracking even when the camera is static).
    property var _anchorCache: null
    function _anchorMoved() {
        var a = root.anchorNode ? root.anchorNode.scenePosition : root.anchorPosition
        var c = root._anchorCache
        if (c && c.x === a.x && c.y === a.y && c.z === a.z)
            return false
        root._anchorCache = { x: a.x, y: a.y, z: a.z }
        return true
    }

    // --- billboard + sizing helpers ----------------------------------------

    function _distanceToCamera() {
        if (!root.camera)
            return 1000
        var c = root.camera.scenePosition
        var p = root.scenePosition
        var dx = c.x - p.x, dy = c.y - p.y, dz = c.z - p.z
        return Math.sqrt(dx * dx + dy * dy + dz * dz)
    }

    // Screen-constant scale: on-screen size of a perspective object is ~1/dist,
    // so the pill's authored pixel height maps to screenHeight px at any depth.
    function _computeScale() {
        var l = root._pillLogicalHeight
        if (l <= 0)
            return 0.001
        if (root.sizeMode === Label3D.World)
            return root.worldHeight / l
        if (!root.camera) {
            // Screen sizing needs a camera; stay readable and say why (#159)
            // instead of scaling by the 1000-unit distance fallback.
            if (!root._warnedNoCamera) {
                root._warnedNoCamera = true
                console.warn("Label3D: no camera resolvable (set view or camera) - " +
                             "falling back to world sizing for '" + root.text + "'")
            }
            return root.worldHeight / l
        }
        var target = root.screenHeight
        if (root.minScreenSize > 0)
            target = Math.max(target, root.minScreenSize)
        if (root.maxScreenSize > 0)
            target = Math.min(target, root.maxScreenSize)
        var d = _distanceToCamera()
        if (root.view && root.camera && root.view.height > 0) {
            var fov = root.camera.fieldOfView ? root.camera.fieldOfView : 60
            var tanHalf = Math.tan(fov * 0.5 * Math.PI / 180)
            return target * 2 * d * tanHalf / (l * root.view.height)
        }
        // Fallback when the view/camera geometry is not resolvable.
        return d * target * 4.0e-5
    }

    function _computeOpacity() {
        if (!root.distanceFade)
            return 1.0
        var d = _distanceToCamera()
        if (d <= root.fadeNear)
            return 1.0
        if (d >= root.fadeFar)
            return 0.0
        return 1.0 - (d - root.fadeNear) / (root.fadeFar - root.fadeNear)
    }

    // --- carrier: billboard + screen-constant scale + 2D pill content ------
    Node {
        id: _carrier

        // Face the camera by wearing the camera's own orientation, which keeps
        // the pill PARALLEL to the image plane. Aiming it at the camera's
        // position instead - yaw plus pitch from the camera-minus-label delta -
        // is the other reading of "faces the camera", and it leaves the quad
        // tilted against the projection: under a camera looking 48 degrees down
        // at a board the pill tips back the same 48 degrees, and perspective
        // keystones the text into something lying on the floor. A quad parallel
        // to the image plane cannot be keystoned, at any camera pitch. It is
        // also the assumption the Screen-mode scale math already makes.
        //
        // Composed back into the parent's frame because this is a LOCAL
        // rotation: a label whose parent is rotated would otherwise inherit
        // that rotation on top of the billboard. Reads _tick so it recomputes
        // each frame.
        rotation: {
            root._tick
            if (!root.camera)
                return Qt.quaternion(1, 0, 0, 0)
            return root.sceneRotation.inverted().times(root.camera.sceneRotation)
        }

        scale: {
            var s = root._appliedScale > 0 ? root._appliedScale : root._computeScale()
            return Qt.vector3d(s, s, s)
        }

        // A QtQuick Item as a direct child of a Node => Quick3D Item2D: unlit,
        // never shadow-casting, resolution-independent. NB an Item2D child's
        // `parent` is an internal wrapper - reach the label via ids (root/_pill).
        Item {
            id: _pill
            implicitWidth: _content.implicitWidth + root.labelStyle.paddingH * 2
            implicitHeight: _content.implicitHeight + root.labelStyle.paddingV * 2
            width: implicitWidth
            height: implicitHeight
            x: -width * 0.5
            y: -height * 0.5
            onImplicitHeightChanged: root._pillLogicalHeight = implicitHeight
            Component.onCompleted: root._pillLogicalHeight = implicitHeight
            opacity: {
                root._tick
                return root._computeOpacity()
            }

            Rectangle {
                id: _bg
                anchors.fill: parent
                radius: root.labelStyle.radius < 0 ? height * 0.5 : root.labelStyle.radius
                color: root.labelStyle.background
                border.color: root.labelStyle.borderColor
                border.width: root.labelStyle.borderWidth
            }

            Row {
                id: _content
                anchors.centerIn: parent
                spacing: root.iconSource.toString() !== "" ? 6 : 0

                Image {
                    id: _icon
                    visible: root.iconSource.toString() !== ""
                    source: root.iconSource
                    height: _text.implicitHeight
                    width: visible ? height : 0
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: _text
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.text
                    color: root.labelStyle.textColor
                    font.family: root.labelStyle.fontFamily
                    font.pixelSize: root.labelStyle.fontSize
                    font.bold: root.labelStyle.bold
                    style: root.labelStyle.halo ? Text.Outline : Text.Normal
                    styleColor: root.labelStyle.haloColor
                }
            }
        }
    }

    // --- leader line -------------------------------------------------------
    // Drawn in the label's own (untransformed) local space: the anchor sits at
    // -labelOffset and the pill at the origin, so a single straight segment from
    // the pill's near edge to the anchor needs no scene-position tracking. This
    // is the LineBatch3D single-segment fallback (D3): a per-label ConnectorLayer
    // would add a draw call per label and a transform inversion for one line.
    LineBatch3D {
        id: _leader
        visible: root.showLeader
        widthUnits: LineBatch3D.Pixel
        viewportSize: root.view ? Qt.vector2d(root.view.width, root.view.height)
                                : Qt.vector2d(1920, 1080)
    }

    property bool _leaderReady: false
    property vector3d _leaderStartCache: Qt.vector3d(0, 0, 0)

    function _anchorLocal() {
        return Qt.vector3d(-root.labelOffset.x, -root.labelOffset.y, -root.labelOffset.z)
    }

    // Start the leader just outside the pill's near edge (half its current world
    // height along the direction to the anchor) so it emerges from the pill.
    function _leaderStart(end) {
        var len = Math.sqrt(end.x * end.x + end.y * end.y + end.z * end.z)
        if (len <= 1e-3)
            return Qt.vector3d(0, 0, 0)
        var half = _carrier.scale.y * root._pillLogicalHeight * 0.5
        var f = Math.min(half / len, 0.9)
        return Qt.vector3d(end.x * f, end.y * f, end.z * f)
    }

    function _initLeader() {
        if (!root.showLeader)
            return
        var end = _anchorLocal()
        var start = _leaderStart(end)
        _leader.lines = [{
            points: [start, end],
            color: root.leaderStyle.color,
            width: root.leaderStyle.width,
            styleId: 0
        }]
        _leaderStartCache = start
        _leaderReady = true
    }

    function _maybeUpdateLeader() {
        if (!root.showLeader)
            return
        if (!_leaderReady) {
            _initLeader()
            return
        }
        var end = _anchorLocal()
        var start = _leaderStart(end)
        var d = start.minus(_leaderStartCache)
        if (Math.abs(d.x) + Math.abs(d.y) + Math.abs(d.z) < 1e-3)
            return
        _leader.updateLinePoints(0, [start, end])
        _leaderStartCache = start
    }

    onShowLeaderChanged: {
        if (root.showLeader)
            _initLeader()
        else if (_leaderReady) {
            _leader.lines = []
            _leaderReady = false
        }
    }
    onLabelOffsetChanged: {
        if (_leaderReady) {
            _leaderReady = false
            _initLeader()
        }
    }

    // --- per-view registry hook (D7) + shared ticker ----------------------
    // Auto-register with the per-View3D registry: it enumerates a view's labels
    // (for a future declutter manager) and drives the shared frame ticker. The
    // label also reports its visibility so a hidden label is dropped from the
    // ticker pass (fully dormant) and the ticker stops when a view has none.
    property var _registeredView: null
    function _syncRegistration() {
        if (_registeredView === root.view)
            return
        if (_registeredView)
            Label3DRegistry.unregister(_registeredView, root)
        _registeredView = root.view
        if (_registeredView) {
            Label3DRegistry.register(_registeredView, root)
            Label3DRegistry.setVisible(_registeredView, root, root.visible)
        }
    }
    onViewChanged: _syncRegistration()
    onVisibleChanged: {
        if (_registeredView)
            Label3DRegistry.setVisible(_registeredView, root, root.visible)
    }

    Component.onCompleted: {
        _updateScale()
        _syncRegistration()
        _initLeader()
    }
    Component.onDestruction: {
        if (_registeredView)
            Label3DRegistry.unregister(_registeredView, root)
    }
}
