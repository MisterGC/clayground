// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// DiveIn - the controller that takes the lesson INSIDE the part.
//
// The mechanism is one number. `inside` is the goal, `depth` eases towards it,
// and everything the dive consists of is a function of `depth`: the camera's
// one glide to a fit of the interior, the presenter shrinking to a sixteenth of
// itself and walking onto the die, the case fading to a ghost, the interior
// fading up. One number, because a dive assembled from five independent
// animations arrives in five different places when any of them is interrupted -
// and this one can be interrupted at any frame by an `O` press.
//
// Nothing here is about transistors. What it needs of a scene is: a rig that
// can fit points and say where it is, a presenter that has a height and can
// walk, an `interior` that can state its own bounds and a standing spot, and a
// list of things to ghost. That is the argument for promoting it to the kernel
// as another CameraDirector shot - see EVALUATION.md.
//
// The floors are the delicate part. An orbit rig's minDistance / minHeight /
// near plane exist to stop a learner skimming the board; inside a 1.6-unit die
// all three are walls, and the default near plane of 10 units (Qt's, which the
// rig does not change) would leave the die entirely on the wrong side of the
// lens. They are relaxed for as long as the dive lasts and put back exactly as
// they were found, the way CameraDirector treats its portrait floors.
import QtQuick

Item {
    id: root

    // Nothing to draw - this is a controller.
    visible: false
    width: 0
    height: 0

    /*! The OrbitCamera3D to fly. Null does nothing at all. */
    property var rig: null

    /*!
        Who shrinks and walks in. Duck-typed: \c height3d, \c travelSpeed,
        \c stand, \c travelling, \c present and \c travelTo().
    */
    property var presenter: null

    /*! The View3D the scene renders through. Informational; nothing reads it yet. */
    property var view: null

    /*!
        The assembled part, for scenes where the interior is not the thing the
        camera can measure: anything with \c partAt(id). Used only as a
        fallback when \l interior is not set.
    */
    property var target: null

    /*! The interior to dive into: \c bounds(), \c standPoint, \c reveal. */
    property var interior: null

    /*! What fades to \l ghostOpacity while inside - the case, usually. */
    property var ghosts: []

    /*! The goal: true is inside. \l enter and \l leave set it. */
    property bool inside: false

    /*! How long one dive takes, camera and presenter together. */
    property int diveMs: 2200

    /*! The presenter's height inside, as a factor of its height outside. */
    property real presenterScale: 0.06

    /*! The camera's near plane while inside. The die is 1.6 units across. */
    property real clipNearInside: 0.04

    /*! How much of a ghosted part is left at full depth. */
    property real ghostOpacity: 0.12

    /*! The rig floors the dive needs, and the only two it touches. */
    property real insideMinDistance: 0.3
    property real insideMinHeight: 0.1

    /*!
        0 outside .. 1 inside, eased. The interpolant every visible part of the
        dive is driven from; a flow asserts \l inside, never this.
    */
    readonly property real depth: _depth

    /*! True while any part of the dive is still moving. */
    readonly property bool travelling: _depthA.running
        || (root.rig ? root.rig.travelling : false)
        || (root.presenter ? root.presenter.travelling : false)

    /*! Goes in. */
    function enter() { root.inside = true }

    /*! Comes back out. */
    function leave() { root.inside = false }

    /*! What a check reads instead of the picture. */
    function report() {
        return { inside: root.inside, depth: root.depth,
                 rigDistance: root.rig ? root.rig.distance : NaN,
                 presenterHeight: root.presenter ? root.presenter.height3d : NaN }
    }

    property real _depth: 0
    property var _saved: null

    onInsideChanged: root.inside ? root._dive() : root._surface()

    // What the camera composes around: the interior's own two corners - or,
    // for a scene that has no interior node yet, a small box around the part
    // the dive is aimed at, so a dive is still a dive.
    function _divePoints() {
        var box = []
        if (root.interior && root.interior.bounds) box = root.interior.bounds()
        else if (root.target && root.target.partAt) {
            const p = root.target.partAt("die.base")
            if (p && !isNaN(p.x))
                box = [Qt.vector3d(p.x - 0.8, p.y - 0.6, p.z - 0.8),
                       Qt.vector3d(p.x + 0.8, p.y + 0.6, p.z + 0.8)]
        }
        if (box.length < 2) return []
        // All EIGHT corners, not the two that were handed over. fit() keeps
        // exactly the points it is given inside the frame; from this close, a
        // box fitted by its main diagonal alone hangs its other six corners
        // off the edges of the picture - which is what the first dive did.
        const pts = _corners(box[0], box[1])
        // The presenter is part of the shot: a dive that frames the die and
        // cuts the figure standing on it in half has nothing to show scale
        // against. Its height is taken from where it is GOING, not from what
        // it is now - the shrink is still to come when this is asked.
        if (root.presenter && root.interior && root.interior.standPoint) {
            const s = root.interior.standPoint
            const h = (root._saved ? root._saved.height3d : root.presenter.height3d)
                    * root.presenterScale * 1.4
            pts.push(s, Qt.vector3d(s.x, s.y + h, s.z))
        }
        return pts
    }

    function _corners(a, b) {
        const out = []
        for (let i = 0; i < 8; ++i)
            out.push(Qt.vector3d(i & 1 ? b.x : a.x, i & 2 ? b.y : a.y, i & 4 ? b.z : a.z))
        return out
    }

    // Taken once, the first time the dive moves anything, and never refreshed:
    // what comes back on leaving is the scene as it was BEFORE any of this,
    // not as it was midway through a previous dive. The stand is copied out of
    // the vector - a vector3d read off a property is a live reference to it,
    // so keeping the property would "restore" wherever the presenter ended up.
    function _capture() {
        if (root._saved) return
        const r = root.rig, p = root.presenter
        root._saved = {
            cam: r ? r.state() : null,
            minDistance: r ? r.minDistance : 0,
            minHeight: r ? r.minHeight : 0,
            clipNear: r && r.camera ? r.camera.clipNear : 10,
            height3d: p ? p.height3d : 1,
            travelSpeed: p ? p.travelSpeed : 1,
            stand: p ? Qt.vector3d(p.stand.x, p.stand.y, p.stand.z) : Qt.vector3d(0, 0, 0)
        }
    }

    function _dive() {
        const pts = root._divePoints()
        if (!root.rig || pts.length === 0) return
        _capture()
        _restoreFloors.stop()
        // Floors down BEFORE the fit: fit() clamps the distance it computes
        // against minDistance and minHeight, so relaxing them afterwards
        // would leave the camera parked outside the part it just framed.
        root.rig.minDistance = root.insideMinDistance
        root.rig.minHeight = root.insideMinHeight
        if (root.rig.camera) root.rig.camera.clipNear = root.clipNearInside
        // One move. A pitch this low is a floor-level look along the layers,
        // which is what makes them read as layers rather than as a target.
        root.rig.fit(pts, { pitch: 18, pad: 1.25, ms: root.diveMs })
        _shrink(root._saved.height3d * root.presenterScale,
                root._saved.travelSpeed * root.presenterScale)
        if (root.presenter && root.presenter.present && root.interior)
            root.presenter.travelTo(root.interior.standPoint)
        _glide(1)
    }

    function _surface() {
        if (!root._saved) return
        _glide(0)
        _returnPose()
        // The floors go back only once the glide has landed: restored now,
        // minDistance would fight the move that is still running.
        _restoreFloors.interval = root.diveMs + 120
        _restoreFloors.restart()
        _shrink(root._saved.height3d, root._saved.travelSpeed)
        if (root.presenter && root.presenter.present)
            root.presenter.travelTo(root._saved.stand)
    }

    // One glide back to the pose the dive started from. The rig can restore a
    // pose (applyState) and it can glide for a stated time (fit, goTo), but not
    // both in one call - so the saved pose is registered as a viewpoint under a
    // name no lab would use and travelled to. Registered by mutating the
    // dictionary rather than replacing it: goTo reads the entry directly, and
    // replacing the property would throw away whatever bindings a lab put on
    // its own viewpoints.
    function _returnPose() {
        const r = root.rig
        if (!r || !root._saved.cam) return
        if (r.viewpoints) {
            r.viewpoints["__diveIn.return"] = root._saved.cam
            if (r.goTo("__diveIn.return", root.diveMs)) return
        }
        r.applyState(root._saved.cam)
    }

    function _shrink(toHeight, toSpeed) {
        const p = root.presenter
        if (!p) return
        _heightA.stop()
        _heightA.to = toHeight
        _heightA.restart()
        // Not animated: travelSpeed is read once, when travelTo() works out how
        // long the flight takes. A tenth-scale figure crossing the board at
        // full speed is a figure being dragged.
        p.travelSpeed = toSpeed
    }

    function _glide(to) {
        _depthA.stop()
        _depthA.to = to
        _depthA.restart()
    }

    NumberAnimation {
        id: _depthA
        target: root
        property: "_depth"
        duration: root.diveMs
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: _heightA
        target: root.presenter
        property: "height3d"
        duration: root.diveMs
        easing.type: Easing.InOutCubic
    }

    Timer {
        id: _restoreFloors
        onTriggered: {
            const s = root._saved
            if (!root.rig || !s) return
            root.rig.minDistance = s.minDistance
            root.rig.minHeight = s.minHeight
            if (root.rig.camera) root.rig.camera.clipNear = s.clipNear
        }
    }

    // What depth actually does to the scene. Written from one handler rather
    // than declared as a Binding per ghost, because the ghosts are a list of
    // whatever the lab handed over: there is no component to attach a binding
    // to. One writer, one number, every frame of the dive.
    on_DepthChanged: root._paint()

    function _paint() {
        const g = root.ghosts || []
        const o = 1 - (1 - root.ghostOpacity) * root._depth
        for (let i = 0; i < g.length; ++i)
            if (g[i]) g[i].opacity = o
        if (root.interior) root.interior.reveal = root._depth
    }

    Component.onCompleted: root._paint()
}
