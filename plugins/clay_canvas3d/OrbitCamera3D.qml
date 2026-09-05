// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype OrbitCamera3D
    \inqmlmodule Clayground.Canvas3D
    \brief An orbit camera on a leash: circles a pivot, never dives through the floor.

    The camera every 3D lab and demo ends up hand-rolling. It looks at \l pivot
    from a yaw/pitch/distance rig, clamps itself so the viewer cannot get lost,
    and can frame a set of world points so a scene arrives properly composed.
    It also \e travels: \l panBy slides the pivot along the ground plane on a
    soft leash, and \l viewpoints gives the scene named places to go.

    The anti-clip rule is a \b {minimum height above the pivot plane}, not a
    minimum distance: a distance sphere wrongly blocks zooming onto a small
    focused object, while a height floor pushes the rig outward as the angle
    flattens and can never end up under the ground.

    \section2 The goal pose

    The rig has two poses, and the difference is the whole reason the mutators
    exist. \l yaw, \l pitch, \l distance and \l pivot are where the camera
    \e is - with \l smoothMs above zero they are animated, so mid-glide they
    hold an interpolant. \l goalYaw, \l goalPitch, \l goalDistance and
    \l goalPivot are where it is \e headed, and that is what the limits are
    applied to, what \l state() serializes and what the next \l orbitBy adds
    to. A rig read back mid-animation therefore round-trips to the move that
    was asked for, not to the frame it happened to be caught on.

    \note Move the rig with \l orbitBy, \l zoomBy, \l zoomToward,
    \l setDistance, \l setPivot, \l reanchor, \l panBy, \l frame, \l fit,
    \l focusOn and \l goTo rather than by writing the pose properties. Every one of them computes the limited value first and writes
    it \e once, which is what makes an animated rig correct: a Behavior defers
    the write, so a write-then-clamp reads back what was there before and
    silently cancels its own move. Direct writes are for the declared initial
    pose (they are adopted as the goal while nothing is animating).

    \section2 Where you have been

    An endless ground has nothing to navigate back by, so the rig keeps two
    memories. \l pushJump / \l jumpBack / \l jumpForward are vim's jumplist:
    every deliberate jump records the place it left, travel records nothing.
    \l frameWithReturn is the shorter loop - dive onto something, press again,
    and the overview you left comes back exactly.

    Example usage:
    \qml
    import Clayground.Canvas3D

    View3D {
        id: view3d
        camera: rig.camera
        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 0, 0)
            distance: 60
            panLeash: 120                      // how far you may wander
            viewpoints: ({ "top": { pitch: 84, distance: 140 } })
        }
    }
    OrbitInput3D { id: nav; rig: rig; view: view3d; mode: "use" }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (m) => nav.begin(m.x, m.y, m.button, m.modifiers)
        onPositionChanged: (m) => nav.move(m.x, m.y)
        onReleased: nav.end()
        onWheel: (w) => nav.wheel(w.angleDelta.y, w.x, w.y)
    }
    \endqml

    \sa Label3D, OrbitInput3D
*/
Node {
    id: root

    /*!
        \qmlproperty vector3d OrbitCamera3D::pivot
        \brief The point the camera looks at.
    */
    property vector3d pivot: Qt.vector3d(0, 0, 0)
    /*!
        \qmlproperty real OrbitCamera3D::yaw
        \brief Angle around the pivot, degrees.
    */
    property real yaw: 0
    /*!
        \qmlproperty real OrbitCamera3D::pitch
        \brief Angle above the pivot plane, degrees.
    */
    property real pitch: 45
    /*!
        \qmlproperty real OrbitCamera3D::distance
        \brief Distance to the pivot.
    */
    property real distance: 60

    /*!
        \qmlproperty real OrbitCamera3D::minPitch
        \brief Flattest allowed angle.
    */
    property real minPitch: 12
    /*!
        \qmlproperty real OrbitCamera3D::maxPitch
        \brief Steepest allowed angle (< 90).
    */
    property real maxPitch: 84
    /*!
        \qmlproperty real OrbitCamera3D::minDistance
        \brief Closest allowed approach.
    */
    property real minDistance: 8
    /*!
        \qmlproperty real OrbitCamera3D::maxDistance
        \brief Furthest allowed retreat.
    */
    property real maxDistance: 400
    /*!
        \qmlproperty real OrbitCamera3D::minHeight
        \brief Lowest the camera may sit above the pivot plane.

        The leash: flattening the angle backs the rig off instead of letting it
        sink through the ground.
    */
    property real minHeight: 4

    // --- the pan leash -----------------------------------------------------
    // The other half of "never get lost". An endless ground plane has no edge
    // to stop at, so the pivot is tethered to a home point instead - softly,
    // because a hard wall reads as a bug ("the drag stopped working") while a
    // rubber band reads as a boundary.

    /*!
        \qmlproperty vector3d OrbitCamera3D::homePivot
        \brief The point \l panLeash measures from. Defaults to the origin.
    */
    property vector3d homePivot: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty real OrbitCamera3D::panLeash
        \brief Furthest the pivot may wander from \l homePivot; 0 is no limit.

        Measured in the ground plane (XZ), so height never counts against it.
    */
    property real panLeash: 0

    /*!
        \qmlproperty real OrbitCamera3D::leashSoftness
        \brief How much overshoot the leash allows, as a fraction of itself.

        Past \l panLeash the pull-back grows exponentially, so the pivot can
        never get further than \c {panLeash * (1 + leashSoftness)} but the drag
        never stops dead either.
    */
    property real leashSoftness: 0.25

    // --- smoothing ---------------------------------------------------------

    /*!
        \qmlproperty int OrbitCamera3D::smoothMs
        \brief Glide time for every move, in milliseconds; 0 snaps.

        Built in rather than left to the lab so that all four pose properties
        ease together - a rig with a \c {Behavior on distance} and none on
        \c pivot swings while it zooms. Declaring your own Behavior on a pose
        property is a duplicate-binding error; change this instead.
    */
    property int smoothMs: 150

    /*!
        \qmlproperty int OrbitCamera3D::travelMs
        \brief Glide time for a \l goTo / \l focusOn journey, in milliseconds.

        Longer than \l smoothMs on purpose: a hand-driven orbit wants to feel
        immediate, a jump across the scene wants to be followed with the eye.
    */
    property int travelMs: 550

    /*!
        \qmlproperty bool OrbitCamera3D::gripped
        \brief A hand is driving the pose right now, so it does not glide.

        The distinction \l smoothMs was missing. A glide is right for a move
        the rig makes on its own - a \l focusOn, a scenario reframing itself,
        an arrow key - because there the eye needs to be carried along. It is
        \e wrong for a drag: grab-the-ground panning promises that the point
        under the cursor stays under the cursor, and a pose easing towards its
        goal over 150 ms mathematically cannot keep that promise. The ground
        trails the hand, and the rig reads as something heavy being nudged
        rather than as a sheet being pushed.

        \l OrbitInput3D sets this for the length of a drag (and of the coast
        out of a flick, which is the same gesture still finishing). Everything
        else keeps its glide.
    */
    property bool gripped: false

    /*!
        \qmlproperty int OrbitCamera3D::gripMs
        \brief Glide while \l gripped. Zero, and rarely anything else.
    */
    property int gripMs: 0

    /*!
        \qmlproperty real OrbitCamera3D::fieldOfView
        \brief Vertical FOV of the camera.
    */
    property real fieldOfView: 60

    /*!
        \qmlproperty var OrbitCamera3D::viewpoints
        \brief Named poses, as \c {{ name: {yaw, pitch, distance, px, py, pz} }}.

        Any subset of the fields a \l state() carries; what is left out keeps
        its current value, so \c {{ pitch: 84 }} is a legal "look straight
        down from wherever you are". \l goTo travels to one.
    */
    property var viewpoints: ({})

    /*!
        \qmlproperty var OrbitCamera3D::view
        \brief The View3D this rig renders through. Optional.

        What tells the rig the shape of its frame. Without it every fit is
        made against the vertical field alone, which is right for a landscape
        window and too tight for a portrait one; with it \l aspect is known
        and \l fit composes against the real picture. Nothing else reads it.
    */
    property var view: null

    /*!
        \qmlproperty real OrbitCamera3D::aspect
        \readonly
        \brief Width over height of the frame; 0 while \l view is not set.
    */
    readonly property real aspect: (view && view.height > 0) ? view.width / view.height : 0

    // --- following ---------------------------------------------------------
    // A moving subject and a camera that only ever cuts is the one thing a
    // television audience will not forgive: the presenter walks out of the
    // side of the picture and the cut lands on an empty frame. A follow is
    // the operator's pan - the subject may wander inside a central zone
    // freely, and the rig moves only once it reaches the edge of that zone,
    // and then just far enough to keep it there. That lag is the point: a
    // camera locked to a moving thing reads as the thing standing still and
    // the world sliding, which is the opposite of what happened.

    /*!
        \qmlproperty var OrbitCamera3D::follow
        \brief What to keep in frame while it moves: a function returning a
               \c vector3d or an array of them, called every frame. Null is off.

        The subject may drift within the inner part of the frame without the
        rig reacting (\l followSlack); once any point crosses that zone the
        pivot pans along the ground - never zooms - just far enough to bring
        it back, over \l followMs. A \l frame, \l fit or \l goTo made while a
        follow is on still happens; the follow only corrects what leaves the
        picture after it. The pan leash still applies, so a subject that walks
        past \l panLeash does get left behind - back the shot off, that is
        what \l fit's \c pad is for.
    */
    property var follow: null

    /*!
        \qmlproperty real OrbitCamera3D::followSlack
        \brief How much of the half-frame the subject may cross before the
               rig pans: 0 pans at the first pixel, 0.25 (default) lets it
               reach three quarters of the way to the edge.
    */
    property real followSlack: 0.25

    /*!
        \qmlproperty int OrbitCamera3D::followMs
        \brief How long one follow correction glides; the lag of the pan.
    */
    property int followMs: 500

    /*!
        \qmlproperty PerspectiveCamera OrbitCamera3D::camera
        \readonly
    */
    readonly property alias camera: _cam

    // --- where the rig is HEADED -------------------------------------------
    // Bound to the declared pose, so an untouched rig reports what its QML
    // says; the first mutator breaks the binding and owns it from then on.

    /*!
        \qmlproperty real OrbitCamera3D::goalYaw
        \readonly
        \brief Yaw the rig is travelling to.
    */
    readonly property real goalYaw: _goal.yaw
    /*!
        \qmlproperty real OrbitCamera3D::goalPitch
        \readonly
        \brief Pitch the rig is travelling to.
    */
    readonly property real goalPitch: _goal.pitch
    /*!
        \qmlproperty real OrbitCamera3D::goalDistance
        \readonly
        \brief Distance the rig is travelling to.
    */
    readonly property real goalDistance: _goal.distance
    /*!
        \qmlproperty vector3d OrbitCamera3D::goalPivot
        \readonly
        \brief Pivot the rig is travelling to.
    */
    readonly property vector3d goalPivot: _goal.pivot

    /*!
        \qmlproperty bool OrbitCamera3D::travelling
        \readonly
        \brief A glide is in progress.
    */
    readonly property bool travelling: _yawA.running || _pitchA.running
                                       || _distA.running || _pivotA.running

    /*!
        \qmlproperty vector3d OrbitCamera3D::goalPosition
        \readonly
        \brief Where the camera ends up, in world coordinates.

        The rig's own \c position is the interpolant; this is the same point
        computed from the goal pose, which is what \l reanchor and
        \l zoomToward do their arithmetic in.
    */
    readonly property vector3d goalPosition: {
        const d = _dirTo(_goal.yaw, _goal.pitch)
        return Qt.vector3d(_goal.pivot.x + _goal.distance * d.x,
                           _goal.pivot.y + _goal.distance * d.y,
                           _goal.pivot.z + _goal.distance * d.z)
    }

    // The unit vector from the pivot towards the camera - the view axis,
    // pointing backwards. The one piece of trigonometry the rig has, and the
    // position binding at the bottom is the same formula.
    function _dirTo(y, p) {
        const a = y * Math.PI / 180, b = p * Math.PI / 180
        return Qt.vector3d(Math.cos(b) * Math.sin(a), Math.sin(b),
                           Math.cos(b) * Math.cos(a))
    }

    QtObject {
        id: _goal
        property real yaw: root.yaw
        property real pitch: root.pitch
        property real distance: root.distance
        property vector3d pivot: root.pivot
    }

    // The limits as pure functions: they RETURN the allowed value instead of
    // writing it. Everything below computes first and writes once, because a
    // Behavior on distance defers the write - a mutator that wrote and then
    // read back would clamp against the old value and cancel its own change.
    function _fitPitch(p) {
        return Math.max(minPitch, Math.min(maxPitch, p))
    }

    // The height floor is absolute - measured from homePivot's plane, not from
    // wherever the pivot currently sits. The two are the same thing for a pivot
    // on the ground, which is every ordinary pose; they part company after a
    // reanchor, which parks the pivot on the view axis and therefore possibly
    // below the floor. Measured from THERE the rule would happily let the
    // camera under the ground, which is the one thing it exists to prevent.
    function _fitDistance(d, p, pivotY) {
        d = Math.max(minDistance, Math.min(maxDistance, d))
        if (minHeight > 0) {
            const py = pivotY === undefined ? _goal.pivot.y : pivotY
            const need = minHeight + (homePivot.y - py)
            const sinP = Math.sin(p * Math.PI / 180)
            if (need > 0 && d * sinP < need)
                d = Math.min(maxDistance, need / Math.max(0.08, sinP))
        }
        return d
    }

    // The soft leash. Beyond the radius the excess is compressed through
    // 1 - e^-x, which is smooth at the boundary (so a drag does not visibly
    // change gear as it crosses) and bounded (so there is a furthest point).
    // Then the depth limit, which applies leash or no leash.
    function _fitPivot(p) {
        var out = p
        if (panLeash > 0) {
            const dx = p.x - homePivot.x, dz = p.z - homePivot.z
            const r = Math.hypot(dx, dz)
            if (r > panLeash && r >= 1e-9) {
                const slack = Math.max(1e-6, panLeash * Math.max(0, leashSoftness))
                const k = (panLeash + slack * (1 - Math.exp(-(r - panLeash) / slack))) / r
                out = Qt.vector3d(homePivot.x + dx * k, p.y, homePivot.z + dz * k)
            }
        }
        const floor = minPivotY
        if (out.y < floor) out = Qt.vector3d(out.x, floor, out.z)
        return out
    }

    /*!
        \qmlproperty real OrbitCamera3D::minPivotY
        \readonly
        \brief How deep the pivot may sink: exactly as far as it can climb out of.

        The height floor is a rule about the \e camera, and \l _fitDistance
        enforces it by backing the rig off - but backing off runs out at
        \l maxDistance. From a pivot deeper than that, \e no legal pose keeps
        the eye above ground, and the floor silently stops being a floor.

        This is the missing half, and it is why the rule is a property rather
        than a line inside \l reanchor, which is where it used to live: only
        that one method consulted it, so \l orbitAround - which rotates the
        pivot rigidly and can therefore drive it hundreds of units under the
        ground - walked straight through. Every mutator goes through
        \l _fitPivot, so putting it there is what makes "never under the
        floor" true of the rig rather than of one method.
    */
    readonly property real minPivotY: {
        const reach = maxDistance * Math.max(0.08, Math.sin(minPitch * Math.PI / 180))
        return homePivot.y - Math.max(0, reach - minHeight)
    }

    // Every move goes through here: limit first, record the goal, write once.
    // _writing tells the change handlers below that this move is ours - an
    // un-animated rig notifies synchronously from inside these four writes.
    property int _writing: 0
    function _apply(y, p, d, pv) {
        p = _fitPitch(p)
        // the pivot first: the leash never touches its height, and the height
        // is what the distance's floor is measured against
        pv = _fitPivot(pv)
        d = _fitDistance(d, p, pv.y)
        _goal.yaw = y; _goal.pitch = p; _goal.distance = d; _goal.pivot = pv
        _writing += 1
        yaw = y; pitch = p; distance = d; pivot = pv
        _writing -= 1
    }

    // A pose property written from outside while nothing is gliding is a
    // declarative pose change (a lab binding its pivot to something that
    // moved); adopt it, or the next orbitBy would spring back to the old goal.
    onYawChanged: if (_writing === 0 && !travelling) _goal.yaw = yaw
    onPitchChanged: if (_writing === 0 && !travelling) _goal.pitch = pitch
    onDistanceChanged: if (_writing === 0 && !travelling) _goal.distance = distance
    onPivotChanged: if (_writing === 0 && !travelling) _goal.pivot = pivot

    /*!
        \qmlmethod void OrbitCamera3D::orbitBy(real dYaw, real dPitch)
        \brief Turns the rig, then re-applies the leash.
    */
    function orbitBy(dYaw, dPitch) {
        _apply(_goal.yaw + dYaw, _goal.pitch + dPitch, _goal.distance, _goal.pivot)
    }

    /*!
        \qmlmethod void OrbitCamera3D::orbitAround(var anchor, real dYaw, real dPitch)
        \brief Turns the rig about \a anchor instead of about the pivot.

        The point of the gesture: \a anchor keeps its place on screen while
        everything else swings around it, because the rig is rotated
        \e rigidly - camera and pivot together, about the axes through
        \a anchor. \l orbitBy turns about the pivot, so anything else you were
        looking at slides off; this is what "turn about what I am pointing at"
        actually means.

        The rotation is applied to the pivot, so the pivot generally leaves the
        ground plane - that is the price, and \l reanchor is what keeps it
        small: from a pivot already at the anchor's depth the two are almost
        the same point. Pitch clamping is honoured (only the allowed part of
        \a dPitch is applied to both), and the leash and the height floor still
        outrank the anchor - they are the only things that can shift it on
        screen. With no \a anchor it is \l orbitBy.
    */
    function orbitAround(anchor, dYaw, dPitch) {
        if (!anchor) { orbitBy(dYaw, dPitch); return }
        const p1 = _fitPitch(_goal.pitch + dPitch)
        const dp = p1 - _goal.pitch          // what the clamp actually allowed
        const y1 = _goal.yaw + dYaw
        var v = Qt.vector3d(_goal.pivot.x - anchor.x, _goal.pivot.y - anchor.y,
                            _goal.pivot.z - anchor.z)
        v = _spin(v, dYaw)
        // ...then about the camera's right axis AT THE NEW YAW, which is the
        // axis the pitch is measured around once the yaw has moved
        v = _tilt(v, y1, dp)
        _apply(y1, p1, _goal.distance,
               Qt.vector3d(anchor.x + v.x, anchor.y + v.y, anchor.z + v.z))
    }

    // Rotation about the world vertical, in the sense the yaw is measured in:
    // it maps the rig's own offset vector at yaw a to the one at yaw a + t.
    function _spin(v, t) {
        const c = Math.cos(t * Math.PI / 180), s = Math.sin(t * Math.PI / 180)
        return Qt.vector3d(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
    }

    // Rotation about the camera's right axis (cos y, 0, -sin y). Raising the
    // pitch by t turns the offset by -t about it, which is the same sign trap
    // the drag handlers keep rediscovering - here it is written down once.
    function _tilt(v, y, t) {
        const a = y * Math.PI / 180, f = -t * Math.PI / 180
        const k = Qt.vector3d(Math.cos(a), 0, -Math.sin(a))
        const c = Math.cos(f), s = Math.sin(f)
        const kv = Qt.vector3d(k.y * v.z - k.z * v.y,
                               k.z * v.x - k.x * v.z,
                               k.x * v.y - k.y * v.x)
        const kd = (k.x * v.x + k.y * v.y + k.z * v.z) * (1 - c)
        return Qt.vector3d(v.x * c + kv.x * s + k.x * kd,
                           v.y * c + kv.y * s + k.y * kd,
                           v.z * c + kv.z * s + k.z * kd)
    }

    /*!
        \qmlmethod void OrbitCamera3D::zoomBy(real factor)
        \brief Multiplies the distance (0.9 zooms in, 1.1 out).
    */
    function zoomBy(factor) { setDistance(_goal.distance * factor) }

    /*!
        \qmlmethod void OrbitCamera3D::setDistance(real d)
        \brief Moves to \a d with the leash applied - the safe way to set it.

        Prefer this over writing \l distance directly: it limits the value
        before the single write, so it stays correct on a rig that animates
        its distance.
    */
    function setDistance(d) {
        _apply(_goal.yaw, _goal.pitch, d, _goal.pivot)
    }

    /*!
        \qmlmethod bool OrbitCamera3D::reanchor(var p)
        \brief Moves the pivot to what you pointed at, without moving the camera.

        The turn-around-what-I-am-looking-at gesture: press over a rooftop and
        the orbit that follows circles \e that, not the middle of the scene.

        The pivot lands on the view axis at \a p's depth - the point of the
        axis nearest \a p - and the distance is re-derived so that
        \l goalPosition and the rig's rotation come out bit-for-bit unchanged.
        That last part is the whole point: a rig whose rotation is \e derived
        from the pivot cannot both aim somewhere else and keep the picture, so
        re-anchoring \e onto an off-centre point would swing the picked thing
        into the middle of the screen - exactly the jump this is meant to
        avoid. Anchoring at its depth turns about it instead, and the image
        does not move at all.

        Returns false when there was nothing to anchor to. The leash still
        applies: re-anchoring outside \l panLeash is pulled back like any
        other pivot move, and that pull is the only thing that can shift the
        camera here. A point so far away that the axis has already dived under
        the ground anchors as deep as the rig can still climb back out of -
        see \l minHeight.
    */
    function reanchor(p) {
        if (!p) return false
        const dir = _dirTo(_goal.yaw, _goal.pitch)
        const c = goalPosition
        // depth of p along the view axis: how far in front of the camera it is
        const depth = (c.x - p.x) * dir.x + (c.y - p.y) * dir.y + (c.z - p.z) * dir.z
        // clamp FIRST, then place the pivot from the clamped distance - that
        // way pivot + d * dir is the old camera position whether or not a limit
        // bit, instead of the limit dragging the camera along with it. The
        // height floor is not consulted: it is a rule about where the camera
        // may be, and the camera does not move here.
        //
        // What IS consulted is how deep the pivot may go. Anchoring past the
        // point where the view axis meets the ground parks the pivot under it,
        // and from far enough under, no legal pose can still hold the camera
        // above the floor - the rig would have to back off further than
        // maxDistance. So the pivot may sink exactly as far as it can climb
        // back out of, and a point beyond that anchors as deep as it may.
        const d = Math.max(minDistance,
                           Math.min(maxDistance, depth, _maxDepth(dir, c)))
        _apply(_goal.yaw, _goal.pitch, d,
               Qt.vector3d(c.x - d * dir.x, c.y - d * dir.y, c.z - d * dir.z))
        return true
    }

    function _maxDepth(dir, c) {
        if (dir.y <= 1e-6) return Infinity
        return (c.y - minPivotY) / dir.y
    }

    /*!
        \qmlmethod void OrbitCamera3D::zoomToward(var p, real factor)
        \brief Zooms along the ray to \a p, so \a p keeps its place on screen.

        Wheel-to-cursor. \l zoomBy pulls the camera towards the pivot, which
        walks whatever you were aiming at off the edge of the screen; this
        moves the camera along the line towards \a p instead and slides the
        pivot the same fraction, so the rotation is untouched and \a p stays
        on exactly the pixel it was on.

        \a factor is \l zoomBy's (0.9 in, 1.1 out), and the limits still cut
        it short: what the distance was actually allowed to do is what the
        pivot moves by, so a zoom that hits \l minDistance stops travelling
        too. With no \a p it is \l zoomBy.
    */
    function zoomToward(p, factor) {
        if (!p) { zoomBy(factor); return }
        const d0 = _goal.distance
        // twice, because the height floor is measured against the pivot's own
        // height and the pivot is about to move: the first pass says how far,
        // the second fits the distance where the pivot will actually be. Both
        // passes agree whenever the pivot and the point share a plane, which
        // is every zoom on flat ground.
        let d1 = _fitDistance(d0 * factor, _goal.pitch, _goal.pivot.y)
        let k = d0 > 1e-9 ? d1 / d0 : 1
        d1 = _fitDistance(d0 * factor, _goal.pitch,
                          _goal.pivot.y + (p.y - _goal.pivot.y) * (1 - k))
        // the limits may have granted less than was asked for; the pivot moves
        // by what was granted, or the point under the cursor drifts off it
        k = d0 > 1e-9 ? d1 / d0 : 1
        _apply(_goal.yaw, _goal.pitch, d1,
               Qt.vector3d(_goal.pivot.x + (p.x - _goal.pivot.x) * (1 - k),
                           _goal.pivot.y + (p.y - _goal.pivot.y) * (1 - k),
                           _goal.pivot.z + (p.z - _goal.pivot.z) * (1 - k)))
    }

    /*!
        \qmlmethod void OrbitCamera3D::setPivot(var p)
        \brief Moves what the camera looks at, on the leash.
    */
    function setPivot(p) {
        if (!p) return
        _apply(_goal.yaw, _goal.pitch, _goal.distance,
               Qt.vector3d(p.x, p.y === undefined ? _goal.pivot.y : p.y, p.z))
    }

    /*!
        \qmlmethod void OrbitCamera3D::panBy(real dRight, real dAway)
        \brief Slides the pivot along the ground, in world units.

        \a dRight is screen-right and \a dAway is screen-up projected onto the
        ground - both relative to the current \l yaw, which is what makes a
        drag feel like it is moving the scene rather than the axes. The height
        of the pivot is untouched, and \l panLeash still applies.
    */
    function panBy(dRight, dAway) {
        const a = _goal.yaw * Math.PI / 180
        const rx = Math.cos(a), rz = -Math.sin(a)     // screen right, on the ground
        const ax = -Math.sin(a), az = -Math.cos(a)    // screen up, on the ground
        setPivot(Qt.vector3d(_goal.pivot.x + rx * dRight + ax * dAway,
                             _goal.pivot.y,
                             _goal.pivot.z + rz * dRight + az * dAway))
    }

    /*!
        \qmlmethod real OrbitCamera3D::worldPerPixel(real viewportHeight)
        \brief World units one pixel covers at the pivot's depth.

        What turns a drag in pixels into a pan in metres. Exact in the middle
        of the view at the pivot plane, which is where a grab-the-ground drag
        is judged.
    */
    function worldPerPixel(viewportHeight) {
        const h = Math.max(1, viewportHeight)
        return 2 * distance * Math.tan(fieldOfView * 0.5 * Math.PI / 180) / h
    }

    /*!
        \qmlmethod void OrbitCamera3D::clamp()
        \brief Re-applies the limits to the pose the rig is in right now.

        For after a \e limit changes (a new \l maxDistance, a tighter
        \l minHeight, a shorter \l panLeash). It is not the way to apply a pose
        - see the note on \l setDistance.
    */
    function clamp() {
        _apply(_goal.yaw, _goal.pitch, _goal.distance, _goal.pivot)
    }

    /*!
        \qmlmethod void OrbitCamera3D::frame(var points, real pad, var angles)
        \brief Centres on the given world points and backs off until they fit.

        \a points is an array of vector3d (or {x, y, z}); \a pad is a headroom
        factor (1.0 = tight, 1.3 = comfortable). Keeps the current yaw/pitch,
        so framing never disorients the viewer - unless \a angles asks for a
        specific one: an optional \c {{yaw, pitch}} (either field alone is
        fine) folded into the same single glide. For the framing that IS a
        deliberate change of viewpoint - a lab dropping to eye level while a
        character presents - where framing first and pitching second would
        move the camera twice.
    */
    function frame(points, pad, angles) {
        if (!points || points.length === 0) return
        const b = _boundsOf(points)
        var tanHalf = Math.tan(fieldOfView * 0.5 * Math.PI / 180)
        // one move, not a setPivot followed by a setDistance: two writes to an
        // animated rig start two glides that arrive at different times, and the
        // scene visibly slides while it zooms
        const aYaw = angles && angles.yaw !== undefined ? angles.yaw : _goal.yaw
        const aPitch = angles && angles.pitch !== undefined ? angles.pitch : _goal.pitch
        clearReturn()          // framing IS the reset F comes home from
        _apply(aYaw, aPitch,
               (b.radius / Math.max(0.05, tanHalf)) * (pad === undefined ? 1.3 : pad),
               Qt.vector3d(b.cx, b.cy, b.cz))
    }

    // What framing works from, split out so \l frameWithReturn can ask "is this
    // the same selection?" without moving anything. Centre and radius only:
    // they depend on the points alone, while the pose framing produces also
    // carries the yaw and pitch the viewer has turned to since.
    function _boundsOf(points) {
        var minX = Infinity, maxX = -Infinity, minY = Infinity
        var maxY = -Infinity, minZ = Infinity, maxZ = -Infinity
        for (var i = 0; i < points.length; ++i) {
            var p = points[i]
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
            minZ = Math.min(minZ, p.z); maxZ = Math.max(maxZ, p.z)
        }
        return { cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, cz: (minZ + maxZ) / 2,
                 radius: Math.max(maxX - minX, maxZ - minZ, maxY - minY) / 2 }
    }

    // --- composing a shot ----------------------------------------------------
    // frame() fits a bounding sphere against the vertical field of view, which
    // is safe and often loose: a presenter beside a part is a flat, wide set
    // of points, and a sphere around it backs off for a height it does not
    // have. What a shot actually needs is every point INSIDE the picture with
    // a margin, and the picture is not the whole window - the bottom carries
    // a flow bar, the top a hint strip. fit() does that in screen space.

    // The camera's axes at a yaw/pitch: right (on the ground), up (in the
    // image) and forward (from the camera INTO the scene) - the three a shot
    // is composed in. dir is the view axis the rest of the rig uses,
    // pointing the other way.
    function _axes(y, p) {
        const a = y * Math.PI / 180
        const dir = _dirTo(y, p)
        const r = Qt.vector3d(Math.cos(a), 0, -Math.sin(a))
        const f = Qt.vector3d(-dir.x, -dir.y, -dir.z)
        const u = Qt.vector3d(r.y * f.z - r.z * f.y,
                              r.z * f.x - r.x * f.z,
                              r.x * f.y - r.y * f.x)
        return { r: r, u: u, f: f, dir: dir }
    }

    function _dot(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z }

    // Half-extents of the frame at unit depth. Without a view the frame is
    // assumed landscape (16:9): a fit that assumed square would back off for
    // width no real window lacks.
    function _tanHV(asp) {
        const tanV = Math.tan(fieldOfView * 0.5 * Math.PI / 180)
        const a = asp !== undefined && asp > 0 ? asp : (aspect > 0 ? aspect : 16 / 9)
        return { v: tanV, h: tanV * a }
    }

    /*!
        \qmlmethod bool OrbitCamera3D::fit(var points, var opts)
        \brief Composes a shot: every point inside the picture, as close as that allows.

        The screen-space fit. \a points is an array of \c vector3d (or
        \c {{x, y, z}}); \a opts is an optional object:

        \list
        \li \c yaw, \c pitch - the angles to shoot from; either alone is fine,
            what is left out keeps its goal value. Folded into the same glide.
        \li \c pad - headroom factor on the distance found (default 1.15).
        \li \c safe - \c {{top, bottom, left, right}}, each the fraction of the
            frame that is NOT picture: chrome, a flow bar, a hint strip. The
            points are fitted into what is left and centred in it, so a bar
            along the bottom moves the subject \e up rather than shrinking it.
        \li \c aspect - overrides \l aspect for this shot.
        \li \c ms - glide time for this move; left out, the rig's current
            glide applies (\l smoothMs, or \l travelMs inside a journey).
        \endlist

        Where \l frame fits a sphere against the vertical field and keeps the
        pivot on the centre of the points, this projects every point and finds
        the nearest distance at which all of them sit inside the safe
        rectangle, shifting the pivot within the image plane to centre them
        there. The pivot may therefore leave the ground; \l minPivotY still
        bounds it. Returns false when there is nothing to fit. Clears the
        \l frameWithReturn excursion, like \l frame.
    */
    function fit(points, opts) {
        if (!points || points.length === 0) return false
        opts = opts || {}
        const y = opts.yaw !== undefined ? opts.yaw : _goal.yaw
        const p = _fitPitch(opts.pitch !== undefined ? opts.pitch : _goal.pitch)
        const pad = opts.pad === undefined ? 1.15 : Math.max(0.5, opts.pad)
        const safe = opts.safe || {}
        const b = _boundsOf(points)
        const ax = _axes(y, p)
        const t = _tanHV(opts.aspect)
        // the safe rectangle, normalized: +1 is the top and the right
        const xmin = -1 + 2 * (safe.left || 0), xmax = 1 - 2 * (safe.right || 0)
        const ymin = -1 + 2 * (safe.bottom || 0), ymax = 1 - 2 * (safe.top || 0)
        if (xmin >= xmax || ymin >= ymax) return false
        // every point in the camera's axes, relative to the centre of them all
        const rel = []
        for (let i = 0; i < points.length; ++i) {
            const q = points[i]
            const v = Qt.vector3d(q.x - b.cx, q.y - b.cy, q.z - b.cz)
            rel.push({ r: _dot(v, ax.r), u: _dot(v, ax.u), f: _dot(v, ax.f) })
        }
        // At distance d the camera sits d behind the centre, so a point is
        // d + f deep, and it needs a pivot offset (ro, uo) in the image plane
        // that keeps it between the safe edges. Intersect those intervals
        // over all points: non-empty means d is enough. They only widen as d
        // grows, which is what lets the nearest d be found by bisection.
        function offsets(d) {
            let rLo = -Infinity, rHi = Infinity, uLo = -Infinity, uHi = Infinity
            for (let i = 0; i < rel.length; ++i) {
                const e = rel[i]
                const depth = d + e.f
                if (depth <= 1e-6) return null
                rLo = Math.max(rLo, e.r - xmax * depth * t.h)
                rHi = Math.min(rHi, e.r - xmin * depth * t.h)
                uLo = Math.max(uLo, e.u - ymax * depth * t.v)
                uHi = Math.min(uHi, e.u - ymin * depth * t.v)
            }
            if (rLo > rHi || uLo > uHi) return null
            return { ro: (rLo + rHi) / 2, uo: (uLo + uHi) / 2 }
        }
        let lo = Math.max(1e-3, minDistance), hi = Math.max(lo, maxDistance)
        let d, off
        if (!offsets(hi)) {
            // not even the furthest allowed pose holds them all: take it, and
            // centre on the middle of the set as frame() would
            d = hi
            off = { ro: 0, uo: 0 }
        } else {
            if (offsets(lo)) {
                hi = lo
            } else {
                for (let i = 0; i < 40 && hi - lo > 1e-4; ++i) {
                    const mid = (lo + hi) / 2
                    if (offsets(mid)) hi = mid; else lo = mid
                }
            }
            d = Math.min(maxDistance, hi * pad)
            off = offsets(d) || offsets(hi)
        }
        const pv = Qt.vector3d(b.cx + ax.r.x * off.ro + ax.u.x * off.uo,
                               b.cy + ax.r.y * off.ro + ax.u.y * off.uo,
                               b.cz + ax.r.z * off.ro + ax.u.z * off.uo)
        clearReturn()
        if (opts.ms !== undefined && opts.ms !== null) _travel(opts.ms)
        _apply(y, p, d, pv)
        return true
    }

    /*!
        \qmlmethod var OrbitCamera3D::project(var p, bool goal)
        \brief Where a world point lands in the frame, without a View3D.

        Returns \c {{x, y, depth}}: \c x and \c y normalized so that -1..1 is
        the picture (\c y up), \c depth the distance in front of the lens - a
        point at or behind it has \c depth <= 0 and its x/y mean nothing.
        Computed from the rig's own pose, so it answers for a rig that is not
        rendering at all; \a goal true projects through the goal pose rather
        than the interpolant, which is what a follow correction needs.
    */
    function project(p, goal) {
        const y = goal ? _goal.yaw : yaw, pt = goal ? _goal.pitch : pitch
        const d = goal ? _goal.distance : distance, pv = goal ? _goal.pivot : pivot
        const ax = _axes(y, pt)
        const t = _tanHV()
        const cx = pv.x + ax.dir.x * d, cy = pv.y + ax.dir.y * d, cz = pv.z + ax.dir.z * d
        const v = Qt.vector3d(p.x - cx, p.y - cy, p.z - cz)
        const depth = _dot(v, ax.f)
        if (depth <= 1e-9) return { x: 0, y: 0, depth: depth }
        return { x: _dot(v, ax.r) / (depth * t.h), y: _dot(v, ax.u) / (depth * t.v),
                 depth: depth }
    }

    /*!
        \qmlmethod bool OrbitCamera3D::covers(var points, real margin, bool goal)
        \brief Whether every point is inside the frame, \a margin (0..1, a
               fraction of the half-frame) away from its edges.

        The question a shot is verified by: not "did the camera move" but
        "is the thing still in the picture". \a goal as for \l project.
    */
    function covers(points, margin, goal) {
        if (!points) return false
        const pts = Array.isArray(points) ? points : [points]
        const lim = 1 - (margin === undefined ? 0 : margin)
        for (let i = 0; i < pts.length; ++i) {
            const n = project(pts[i], goal)
            if (n.depth <= 0 || Math.abs(n.x) > lim || Math.abs(n.y) > lim)
                return false
        }
        return pts.length > 0
    }

    // One frame of the follow: find how far past the inner zone the subject
    // has got, and pan the goal pivot by exactly the ground move that puts it
    // back on the zone's edge. Screen right is a ground direction already, so
    // that half is a division; screen up is "away" along the ground, and a
    // pan away changes a point's depth as well as its height, so that half
    // solves the projection for the move (the depth term is what made the
    // first version overshoot by a third). A flat shot cannot pan a tall
    // thing into frame at all - the solve degenerates - and then the point
    // is left where it is rather than chased the wrong way. Nothing happens
    // while the subject is inside the zone, so a follow at rest costs a
    // projection per point and no writes.
    function _followTick() {
        if (typeof follow !== "function") return
        let pts = follow()
        if (!pts) return
        if (!Array.isArray(pts)) pts = [pts]
        if (pts.length === 0) return
        const lim = 1 - Math.max(0, Math.min(0.9, followSlack))
        const t = _tanHV()
        const s = Math.sin(_goal.pitch * Math.PI / 180)
        const c = Math.cos(_goal.pitch * Math.PI / 180)
        let dR = 0, dA = 0
        for (let i = 0; i < pts.length; ++i) {
            const n = project(pts[i], true)
            if (n.depth <= 0) continue
            if (Math.abs(n.x) > lim) {
                const want = n.x > 0 ? lim : -lim
                const m = (n.x - want) * n.depth * t.h
                dR = m > 0 ? Math.max(dR, m) : Math.min(dR, m)
            }
            if (Math.abs(n.y) > lim) {
                const want = n.y > 0 ? lim : -lim
                const up = n.y * n.depth * t.v
                const den = s - want * t.v * c
                if (Math.abs(den) < 0.05) continue
                const m = (up - want * t.v * n.depth) / den
                dA = m > 0 ? Math.max(dA, m) : Math.min(dA, m)
            }
        }
        if (Math.abs(dR) < 1e-4 && Math.abs(dA) < 1e-4) return
        const a = _goal.yaw * Math.PI / 180
        const rx = Math.cos(a), rz = -Math.sin(a)
        const ax = -Math.sin(a), az = -Math.cos(a)
        _travel(followMs)
        _apply(_goal.yaw, _goal.pitch, _goal.distance,
               Qt.vector3d(_goal.pivot.x + rx * dR + ax * dA, _goal.pivot.y,
                           _goal.pivot.z + rz * dR + az * dA))
    }

    FrameAnimation {
        running: typeof root.follow === "function"
        onTriggered: root._followTick()
    }

    /*!
        \qmlmethod void OrbitCamera3D::focusOn(var what, real pad, int ms)
        \brief Travels to a point or a set of points and frames them.

        \a what is a single \c vector3d (or \c {{x, y, z}}) or an array of
        them. A single point keeps the current distance and only re-centres -
        framing a point has no extent to fit, and diving at it is never what
        was meant. \a ms overrides \l travelMs for this journey.

        The verb a lab's own picking calls: the input layer never decides what
        is worth looking at, it only offers the ride.

        A journey, so it \l pushJump s: this is where you were before you dived
        at something, and \l jumpBack is how you get back.
    */
    function focusOn(what, pad, ms) {
        if (!what) return
        // Array.isArray, not a duck-typed `length` check: a vector3d HAS a
        // length - it is the method that measures the vector - so the obvious
        // test says "array" for exactly the single point this branch is for.
        const pts = Array.isArray(what) ? what : [what]
        if (pts.length === 0) return
        // after the guards, so a refused focus leaves no trace on the jumplist
        pushJump()
        clearReturn()
        _travel(ms)
        if (pts.length === 1) setPivot(pts[0])
        else frame(pts, pad)
        _settleJump()
    }

    /*!
        \qmlmethod bool OrbitCamera3D::goTo(string name, int ms)
        \brief Travels to the named \l viewpoint; false if there is no such name.

        Yaw takes the short way round: a rig turned three times over does not
        unwind on the way to a viewpoint that says \c {yaw: 0}.

        Named places are jumps, so this \l pushJump s - and a name that does not
        exist does not, because it did not go anywhere.
    */
    function goTo(name, ms) {
        const vp = viewpoints ? viewpoints[name] : undefined
        if (vp === undefined || vp === null) return false
        pushJump()
        clearReturn()
        _travel(ms)
        const s = {}
        for (const k in vp) s[k] = vp[k]
        if (s.yaw !== undefined) s.yaw = _nearestYaw(_goal.yaw, s.yaw)
        applyState(s)
        _settleJump()
        return true
    }

    /*!
        \qmlmethod var OrbitCamera3D::viewpointNames()
        \brief The names \l goTo accepts.
    */
    function viewpointNames() {
        return viewpoints ? Object.keys(viewpoints) : []
    }

    function _nearestYaw(from, to) {
        return from + ((((to - from) % 360) + 540) % 360) - 180
    }

    // One journey's worth of a longer glide, handed back afterwards so an
    // ordinary drag stays snappy.
    function _travel(ms) {
        _travelMs = ms !== undefined && ms !== null ? ms : travelMs
        _travelBack.restart()
    }
    property int _travelMs: 0
    readonly property int _glideMs: gripped ? gripMs
                                   : _travelMs > 0 ? _travelMs : smoothMs
    property Timer _travelBack: Timer {
        interval: root._glideMs + 40
        onTriggered: root._travelMs = 0
    }

    /*!
        \qmlmethod var OrbitCamera3D::state()
        \brief Pose as a JSON-serializable object, for the viewState convention.

        The \e goal pose, so a rig serialized mid-glide restores where it was
        going rather than the frame it was caught on.
    */
    function state() {
        return { yaw: _goal.yaw, pitch: _goal.pitch, distance: _goal.distance,
                 px: _goal.pivot.x, py: _goal.pivot.y, pz: _goal.pivot.z }
    }

    /*!
        \qmlmethod void OrbitCamera3D::applyState(var s)
        \brief Restores a pose produced by \l state(). Missing fields keep theirs.
    */
    function applyState(s) {
        if (!s) return
        _apply(s.yaw !== undefined ? s.yaw : _goal.yaw,
               s.pitch !== undefined ? s.pitch : _goal.pitch,
               s.distance !== undefined ? s.distance : _goal.distance,
               s.px !== undefined ? Qt.vector3d(s.px, s.py, s.pz) : _goal.pivot)
    }

    // --- where you have been -----------------------------------------------
    //
    // Two kinds of memory, and they are different questions. The jumplist
    // answers "where was I before this?" over a whole session (vim's Ctrl+O /
    // Ctrl+I, imported as-is); the return pose answers "where do I go back to
    // when I am done looking at this?" for one dive.
    //
    // Both hold GOAL poses, never the interpolant, for the reason state() does:
    // a jump taken mid-glide has to remember where the rig was headed, or
    // coming back lands on whichever frame the key happened to fall on.
    //
    // The stacks are REASSIGNED rather than mutated in place, so jumpsBack and
    // jumpsAhead actually notify - an array pushed into is the same array, and
    // a binding on its length never fires again.

    /*!
        \qmlproperty int OrbitCamera3D::jumpDepth
        \brief How many places back the jumplist remembers.

        Bounded because the alternative is a session-long leak of poses nobody
        will ever walk back to; the oldest entry falls off the bottom.
    */
    property int jumpDepth: 50

    /*!
        \qmlproperty int OrbitCamera3D::jumpsBack
        \readonly
        \brief Places \l jumpBack can still take you.
    */
    readonly property int jumpsBack: _back.length
    /*!
        \qmlproperty int OrbitCamera3D::jumpsAhead
        \readonly
        \brief Places \l jumpForward can still take you.
    */
    readonly property int jumpsAhead: _fwd.length

    /*!
        \qmlproperty bool OrbitCamera3D::hasReturnPose
        \readonly
        \brief A \l frameWithReturn dive is open, so the next one comes home.

        What a lab shows in its hint bar, so the second press of the framing key
        is offered rather than discovered.
    */
    readonly property bool hasReturnPose: _returnPose !== null

    property var _back: []
    property var _fwd: []
    property var _returnPose: null
    property var _returnTarget: null

    /*!
        \qmlmethod void OrbitCamera3D::pushJump()
        \brief Records the pose the rig is in as a place worth coming back to.

        \l goTo, \l focusOn and \l frameWithReturn call it themselves; anything
        else that means a \e jump rather than travel calls it first - a lab's
        reset-the-view key, a flow step that aims the camera, a hint label
        selected and flown to. Travel deliberately does not: a jumplist that
        filled up with every drag would have nothing recognisable left in it,
        which is exactly why vim distinguishes the two.

        Clears the forward list, because history that was walked back and then
        left is no longer where you are going - unless the jump turns out not to
        move the rig at all, and then nothing about the memory changes. A key
        that went nowhere must leave no trace, or the next \l jumpBack answers
        for a press that did nothing.
    */
    function pushJump() {
        const here = state()
        _jumpPending = true
        _jumpPrevFwd = _fwd
        _fwd = []
        // the pose already on top is not a place you left - but the entry is
        // still what _settleJump measures the move against, so the flag says
        // whether it is ours to take back off again
        _jumpPushed = _back.length === 0 || !_samePose(_back[_back.length - 1], here)
        if (!_jumpPushed) return
        var b = _back.concat([here])
        if (b.length > Math.max(1, jumpDepth)) b = b.slice(b.length - Math.max(1, jumpDepth))
        _back = b
    }

    // Every jump verb ends here: whatever the move did, the recorded pose is on
    // top of the list, so comparing it against the goal pose says whether the
    // rig actually went anywhere. It did not for a goTo to the viewpoint you
    // are standing on, or a focusOn onto what is already centred - and those
    // must not consume the way forward either.
    property bool _jumpPending: false
    property bool _jumpPushed: false
    property var _jumpPrevFwd: null
    function _settleJump() {
        if (!_jumpPending) return
        _jumpPending = false
        const pushed = _jumpPushed, prevFwd = _jumpPrevFwd
        _jumpPrevFwd = null
        if (_back.length === 0) return
        if (!_samePose(_back[_back.length - 1], state())) return   // it moved
        if (pushed) _back = _back.slice(0, _back.length - 1)
        _fwd = prevFwd ? prevFwd : []
    }

    /*!
        \qmlmethod bool OrbitCamera3D::jumpBack(int ms)
        \brief Travels to the place before the last jump; false at the end.

        False is the interesting half: nothing moves and the caller is expected
        to say so, because a key that silently does nothing reads as broken.
        The pose being left is put on the forward list, so the walk is
        reversible by \l jumpForward for as long as no new jump happens.
    */
    function jumpBack(ms) {
        if (_back.length === 0) return false
        const to = _back[_back.length - 1]
        _back = _back.slice(0, _back.length - 1)
        _fwd = _fwd.concat([state()]).slice(-Math.max(1, jumpDepth))
        clearReturn()
        _travel(ms)
        applyState(to)
        return true
    }

    /*!
        \qmlmethod bool OrbitCamera3D::jumpForward(int ms)
        \brief Undoes a \l jumpBack; false when there is nothing ahead.
    */
    function jumpForward(ms) {
        if (_fwd.length === 0) return false
        const to = _fwd[_fwd.length - 1]
        _fwd = _fwd.slice(0, _fwd.length - 1)
        // NOT pushJump(): that clears the forward list, which is the one thing
        // walking it must not do
        _back = _back.concat([state()]).slice(-Math.max(1, jumpDepth))
        clearReturn()
        _travel(ms)
        applyState(to)
        return true
    }

    /*!
        \qmlmethod bool OrbitCamera3D::frameWithReturn(var points, real pad)
        \brief Dives onto \a points, and the next call on the same thing comes back.

        The framing key pressed twice is a round trip: dive in to read a value
        up close, press it again, and the overview you left is restored exactly
        - including the yaw you had turned to, which is what "exactly" has to
        mean or the second press is just another reframing.

        \list
        \li No return pose stored: remembers where you are and frames
            \a points.
        \li Stored, and \a points is the same extent again (or nothing is
            selected at all): flies home and forgets.
        \li Stored, and \a points is a \e different extent: reframes onto it and
            \b keeps the original return pose. The loop always closes where it
            began - walking from part to part is one excursion, not a chain of
            them, and the way home does not drift with it.
        \endlist

        Sameness is the extent, not the selection: this layer has never been
        told what a part is, and the centre and radius of what it was asked to
        frame is the whole of what it can compare. Two different selections that
        occupy the same box are one place as far as the camera is concerned,
        which is also how they look.

        Returns false only when there was nothing to do - no points and no way
        home. Any jump (\l goTo, \l focusOn, \l jumpBack) and any plain \l frame
        drops the return pose: those are departures, not the end of an
        excursion.
    */
    function frameWithReturn(points, pad) {
        const target = points && points.length > 0 ? _boundsOf(points) : null
        if (_returnPose !== null && (target === null || _sameTarget(target, _returnTarget))) {
            const home = _returnPose
            pushJump()             // the close-up is a place too: Ctrl+O dives back in
            clearReturn()
            _travel()
            applyState(home)
            _settleJump()
            return true
        }
        if (target === null) return false
        const home = _returnPose !== null ? _returnPose : state()
        pushJump()
        _travel()
        frame(points, pad)         // clears the return pose...
        _returnPose = home         // ...which is why it is stored afterwards
        _returnTarget = target
        _settleJump()
        return true
    }

    /*!
        \qmlmethod void OrbitCamera3D::clearJumps()
        \brief Forgets everywhere the rig has been.

        For a scene that has been replaced under the camera - a scenario
        applied, a board cleared - where the recorded poses now describe places
        in a world that no longer exists. Walking the list cannot do this:
        \l jumpBack and \l jumpForward only move an entry from one side to the
        other, which is what makes them reversible.
    */
    function clearJumps() {
        _back = []
        _fwd = []
    }

    /*!
        \qmlmethod void OrbitCamera3D::clearReturn()
        \brief Forgets the open \l frameWithReturn excursion.

        For a lab that ends one by other means - a scenario change, a scene
        rebuilt under the camera - where the pose the dive began from no longer
        describes anywhere the viewer would recognise.
    */
    function clearReturn() {
        _returnPose = null
        _returnTarget = null
    }

    function _samePose(a, b) {
        return Math.abs(a.yaw - b.yaw) < 1e-4 && Math.abs(a.pitch - b.pitch) < 1e-4
               && Math.abs(a.distance - b.distance) < 1e-4
               && Math.abs(a.px - b.px) < 1e-4 && Math.abs(a.py - b.py) < 1e-4
               && Math.abs(a.pz - b.pz) < 1e-4
    }

    // Relative to the extent's own size, so "the same selection" survives the
    // float noise of a rebuilt scene without calling two neighbouring parts one
    // place.
    function _sameTarget(a, b) {
        if (!a || !b) return false
        const eps = Math.max(1e-3, Math.max(a.radius, b.radius) * 0.01)
        return Math.abs(a.cx - b.cx) < eps && Math.abs(a.cy - b.cy) < eps
               && Math.abs(a.cz - b.cz) < eps && Math.abs(a.radius - b.radius) < eps
    }

    Behavior on yaw {
        enabled: root._glideMs > 0
        NumberAnimation { id: _yawA; duration: root._glideMs; easing.type: Easing.OutCubic }
    }
    Behavior on pitch {
        enabled: root._glideMs > 0
        NumberAnimation { id: _pitchA; duration: root._glideMs; easing.type: Easing.OutCubic }
    }
    Behavior on distance {
        enabled: root._glideMs > 0
        NumberAnimation { id: _distA; duration: root._glideMs; easing.type: Easing.OutCubic }
    }
    Behavior on pivot {
        enabled: root._glideMs > 0
        Vector3dAnimation { id: _pivotA; duration: root._glideMs; easing.type: Easing.OutCubic }
    }

    position: {
        const a = root.yaw * Math.PI / 180
        const b = root.pitch * Math.PI / 180
        return Qt.vector3d(root.pivot.x + root.distance * Math.cos(b) * Math.sin(a),
                           root.pivot.y + root.distance * Math.sin(b),
                           root.pivot.z + root.distance * Math.cos(b) * Math.cos(a))
    }
    eulerRotation: Qt.vector3d(-root.pitch, root.yaw, 0)

    PerspectiveCamera {
        id: _cam
        fieldOfView: root.fieldOfView
    }
}
