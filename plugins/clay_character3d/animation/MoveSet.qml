// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// MoveSet - the animator behind a LOADABLE set of moves, as against the basic
// set of animations every Character always carries.
//
// The difference is what each is for. Walking, running, standing, gazing,
// listening, gesturing, talking, working and boxing are what a character IS -
// every character in every game does them, so they are children of
// Character.qml and cost what they cost. A martial art, a dance, a trade's
// hand-work: those are what a character KNOWS, one game wants them and the
// next does not, and there is no reason for a crowd of villagers to carry the
// machinery for a spinning back kick. So a set is loaded onto a character by
// name or by URL, replaces whatever set was loaded before it, and can be
// unloaded again.
//
// A set brings its own model - Qt-free, node-checkable, exactly as gait.js
// and action.js are - and this type is the replay machinery they share:
//
//   * ONE number is animated, the phase, and whatever the model answers for
//     it is written onto the joints. The pose function is therefore the same
//     one a sheet of stills or a unit suite reads, and cannot drift from what
//     plays on screen.
//   * A move is entered by BLENDING out of wherever the body actually is
//     over blendMs, rather than by snapping to the move's first frame. A set
//     is triggered from arbitrary states - mid-gesture, mid-stance, from
//     another set's last pose - and a cut on every trigger is the one thing
//     that makes a loadable set look bolted on.
//   * A one-shot hands back to the set's own resting move when it ends
//     (autoRest), unless the model marks it as one that HOLDS its last frame
//     - which is how a knockdown stays on the floor for the get-up to start
//     from.
//
// WHAT A SET DOES NOT DO is move the character across the floor. The model's
// lift and drift move the BODY over its own feet, in leg heights, and both
// return to zero by the end of a move; walking a character to where the kick
// lands is the caller's business.

import QtQuick

/*!
    \qmltype MoveSet
    \inqmlmodule Clayground.Character3D
    \inherits QtObject
    \brief A loadable set of named moves, played onto one \l Character.

    Sets are optional and are loaded on demand, unlike the basic animations
    every character carries; see \l {Character::moveSet}{Character.moveSet},
    which is the way one is normally loaded and the way it is given its
    \l entity.

    A set is this type plus a model: a Qt-free JavaScript library answering
    \c {moves()}, \c {derive(move, opts)}, \c {poseAt(table, t)},
    \c {mixPose(a, b, k)} and \c {restMove()}. \l MartialArts is the set that
    ships with the plugin and the worked example of the shape.

    \qml
    // movesets/MartialArts.qml
    import "../animation"
    import "martialarts.js" as MA

    MoveSet {
        name: "martial arts"
        model: ({ moves: MA.moves, derive: MA.derive, poseAt: MA.poseAt,
                  mixPose: MA.mixPose, restMove: MA.restMove })
    }
    \endqml

    \sa Character::moveSet, MartialArts, ActionCycleAnim
*/
QtObject {
    id: _set

    /*!
        \qmlproperty var MoveSet::entity
        \brief The \l Character whose joints this writes.

        Set by \l Character when it loads the set; a set with no entity does
        nothing rather than failing.
    */
    property var entity: null

    /*!
        \qmlproperty string MoveSet::name
        \brief What the set is called, for a UI to show.
    */
    property string name: ""

    /*!
        \qmlproperty var MoveSet::model
        \brief The set's pose model - the object answering \c {moves()},
               \c {derive()}, \c {poseAt()}, \c {mixPose()} and
               \c {restMove()}.
    */
    property var model: null

    /*!
        \qmlproperty real MoveSet::intensity
        \brief How hard the moves are thrown, 0..1.

        Speed and size, never a different pose - the same contract
        \l {Character::actionIntensity}{actionIntensity} has, and it is fed
        from there.
    */
    property real intensity: 0.5

    /*!
        \qmlproperty int MoveSet::blendMs
        \brief How long a move takes to ease out of the pose the body was
               already in, in milliseconds.

        Zero cuts straight to the move's first frame.
    */
    property int blendMs: 140

    /*!
        \qmlproperty bool MoveSet::autoRest
        \brief Whether a one-shot hands back to \l restMove when it ends.

        On by default: a jab that leaves the body wherever the punch finished
        reads as the animation stopping rather than as a punch being thrown.
        A move the model marks as holding its last frame is exempt.
    */
    property bool autoRest: true

    /*!
        \qmlproperty var MoveSet::moves
        \readonly
        \brief What the set offers: a list of
               \c {{name, label, group, loop, holds}}, in the model's own
               order.
    */
    readonly property var moves: _set.model ? _set.model.moves() : []

    /*!
        \qmlproperty string MoveSet::restMove
        \readonly
        \brief The move a character in this set stands in when it is doing
               nothing else, "" when the set names none.
    */
    readonly property string restMove: _set.model && _set.model.restMove
                                     ? _set.model.restMove() : ""

    /*!
        \qmlproperty string MoveSet::move
        \readonly
        \brief The move being played, or the one whose last frame is being
               held; "" when the set is idle.
    */
    readonly property string move: _set._move

    /*!
        \qmlproperty bool MoveSet::playing
        \readonly
        \brief True while a move is actually animating.
    */
    readonly property bool playing: _set._drive.running

    /*!
        \qmlproperty bool MoveSet::holding
        \readonly
        \brief True while the set owns the joints - playing a move, or sitting
               on the last frame of one that holds.

        What \l Character consults before it lets the idle pose take the body
        back: a knockdown that is handed to the idle animation stands up
        again within a fifth of a second.
    */
    readonly property bool holding: _set._drive.running || _set._held

    /*!
        \qmlproperty string MoveSet::handPose
        \readonly
        \brief What the current frame wants the hands to be doing, "" when the
               set is idle - a fist through most of a fighting set, a flat
               hand where one is planted on the floor.
    */
    readonly property string handPose: _set.holding ? _set._handPose : ""

    /*!
        \qmlproperty real MoveSet::phase
        \brief Where in the move it is, 0..1. Set it with the animation
               stopped to hold one frame.
    */
    property real phase: 0

    /*!
        \qmlsignal MoveSet::finished(string move)
        \brief Emitted when a one-shot move reaches its end, before any
               hand-back to \l restMove.
    */
    signal finished(string move)

    /*!
        \qmlmethod bool MoveSet::has(string move)
        \brief Whether the set offers \a move.
    */
    function has(what) {
        const m = _set.moves
        for (let i = 0; i < m.length; ++i)
            if (m[i].name === what)
                return true
        return false
    }

    /*!
        \qmlmethod bool MoveSet::play(string move)
        \brief Starts \a move, easing out of whatever the body is holding.
               Returns false, and does nothing, when the set has no such move.
    */
    function play(what) {
        if (!_set.model || !_set.entity || !_set.has(what))
            return false
        _set._drive.stop()
        _set._blendAnim.stop()
        // Where the body actually is, so the move can be entered from it.
        _set._from = _set.blendMs > 0 ? _set._snapshot() : null
        _set._blend = _set._from ? 0 : 1
        _set._move = what
        _set._held = false
        _set._table = _set.model.derive(what, _set._opts())
        _set.phase = 0
        _set._drive.loops = _set._table.loop ? Animation.Infinite : 1
        _set._drive.duration = Math.max(1, Math.round(_set._table.cycleMs))
        _set._drive.start()
        if (_set._from) {
            _set._blendAnim.duration = _set.blendMs
            _set._blendAnim.start()
        }
        _set._write()
        return true
    }

    /*!
        \qmlmethod void MoveSet::stop()
        \brief Stops whatever is playing and lets go of the joints, which stay
               where the last frame left them.
    */
    function stop() {
        _set._drive.stop()
        _set._blendAnim.stop()
        _set._move = ""
        _set._held = false
        _set._table = null
        _set._from = null
        _set._blend = 1
    }

    /*!
        \qmlmethod var MoveSet::tableFor(string move)
        \brief The derived numbers \a move is replayed from at this set's
               \l intensity and this character's build - its \c cycleMs among
               them. Null when the set has no such move.
    */
    function tableFor(what) {
        return _set.model && _set.has(what)
             ? _set.model.derive(what, _set._opts()) : null
    }

    /*!
        \qmlmethod var MoveSet::poseAt(string move, real t)
        \brief The joint angles \a move holds at phase \a t, 0..1, with
               nothing running.

        Pure, and the same answer the running move gives at that moment - this
        type plays this very function. The wrist roll comes back as a fraction
        of a quarter turn; the degrees are the character's.
    */
    function poseAt(what, t) {
        const table = _set.tableFor(what)
        return table === null ? null : _set.model.poseAt(table, t)
    }

    /*!
        \qmlmethod void MoveSet::apply(string move, real t)
        \brief Freezes the joints at phase \a t of \a move, running or not.

        For looking, not for playing: a row of characters frozen at successive
        phases is the move on one sheet.
    */
    function apply(what, t) {
        const p = _set.poseAt(what, t)
        if (p !== null)
            _set._writePose(p)
    }

    // --- the machinery --------------------------------------------------------

    property string _move: ""
    property bool _held: false
    property var _table: null
    property var _from: null
    property real _blend: 1
    property string _handPose: ""

    function _opts() {
        const c = _set.entity
        return {
            intensity: _set.intensity,
            // The body, so a fall lands on the floor of THIS figure: the
            // model drops the waist by whatever the waist stands at, and a
            // tall character's waist stands higher than a short one's.
            legHeight: c ? c.legHeight : 0,
            hipHeight: c ? c.hipHeight : 0,
            footHeight: c ? c.footHeight : 0,
            torsoDepth: c ? c.torsoDepth : 0
        }
    }

    // The phase is written every frame while a move runs, so that is the one
    // hook needed: play() writes the first frame itself, and nothing else
    // changes the table while a move is in flight.
    onPhaseChanged: _set._write()

    function _write() {
        if (!_set._table || !_set.model)
            return
        let p = _set.model.poseAt(_set._table, _set.phase)
        if (_set._blend < 1 && _set._from)
            p = _set.model.mixPose(_set._from, p, _set._blend)
        _set._writePose(p)
    }

    function _writePose(p) {
        const c = _set.entity
        if (!c || !c.rightArm || !c.head)
            return
        const roll = c.handRestRoll === undefined ? 90 : c.handRestRoll

        function limb(m, a) {
            m.upperArm.eulerRotation = Qt.vector3d(a.upper[0], a.upper[1], a.upper[2])
            m.lowerArm.eulerRotation = Qt.vector3d(a.lower[0], a.lower[1], a.lower[2])
            // The roll arrives as a fraction of a quarter turn; the degrees
            // are the character's, not the move's.
            m.hand.eulerRotation = Qt.vector3d(a.hand[0], a.hand[1] / 90 * roll, a.hand[2])
        }
        function foot(l, a) {
            l.upperLeg.eulerRotation = Qt.vector3d(a.upper[0], a.upper[1], a.upper[2])
            l.lowerLeg.eulerRotation = Qt.vector3d(a.lower[0], a.lower[1], a.lower[2])
            l.foot.eulerRotation = Qt.vector3d(a.foot[0], a.foot[1], a.foot[2])
        }
        limb(c.rightArm, p.rightArm)
        limb(c.leftArm, p.leftArm)
        foot(c.rightLeg, p.rightLeg)
        foot(c.leftLeg, p.leftLeg)
        c.hip.eulerRotation = Qt.vector3d(p.hip[0], p.hip[1], p.hip[2])
        c.torso.eulerRotation = Qt.vector3d(p.torso[0], p.torso[1], p.torso[2])
        c.belly.eulerRotation = Qt.vector3d(p.belly[0], p.belly[1], p.belly[2])
        c.chest.eulerRotation = Qt.vector3d(p.chest[0], p.chest[1], p.chest[2])
        c.head.poseEuler = Qt.vector3d(p.head[0], p.head[1], p.head[2])
        // The body over its own feet, in leg heights, through the same two
        // slots the gait uses. IdleAnim eases both back to zero afterwards.
        if (p.lift !== undefined && c._heldLift !== undefined)
            c._heldLift = p.lift * c.legHeight
        if (p.drift !== undefined && c._heldDrift !== undefined)
            c._heldDrift = p.drift * c.legHeight
        _set._handPose = p.hand === undefined ? "" : p.hand
    }

    // Where the body is right now, in the shape the model's poses come in, so
    // a move can be eased out of it. Read from the joints rather than
    // remembered: what was holding them may have been a gait, a gesture, or
    // another set entirely.
    function _snapshot() {
        const c = _set.entity
        if (!c || !c.rightArm || !c.head)
            return null
        const roll = c.handRestRoll === undefined || c.handRestRoll === 0
                   ? 90 : c.handRestRoll
        function limb(m) {
            return { upper: [m.upperArm.eulerRotation.x, m.upperArm.eulerRotation.y,
                             m.upperArm.eulerRotation.z],
                     lower: [m.lowerArm.eulerRotation.x, m.lowerArm.eulerRotation.y,
                             m.lowerArm.eulerRotation.z],
                     // Back into the fraction of a quarter turn the model
                     // speaks, so the two ends of the blend are the same unit.
                     hand: [m.hand.eulerRotation.x, m.hand.eulerRotation.y / roll * 90,
                            m.hand.eulerRotation.z] }
        }
        function foot(l) {
            return { upper: [l.upperLeg.eulerRotation.x, l.upperLeg.eulerRotation.y,
                             l.upperLeg.eulerRotation.z],
                     lower: [l.lowerLeg.eulerRotation.x, l.lowerLeg.eulerRotation.y,
                             l.lowerLeg.eulerRotation.z],
                     foot: [l.foot.eulerRotation.x, l.foot.eulerRotation.y,
                            l.foot.eulerRotation.z] }
        }
        function v3(v) { return [v.x, v.y, v.z] }
        const leg = c.legHeight > 0 ? c.legHeight : 1
        return {
            rightArm: limb(c.rightArm), leftArm: limb(c.leftArm),
            rightLeg: foot(c.rightLeg), leftLeg: foot(c.leftLeg),
            hip: v3(c.hip.eulerRotation),
            torso: v3(c.torso.eulerRotation),
            belly: v3(c.belly.eulerRotation),
            chest: v3(c.chest.eulerRotation),
            head: v3(c.head.poseEuler),
            lift: c.gaitLift / leg,
            drift: c.bodyDrift / leg,
            hand: c.handPose
        }
    }

    // A one-shot has reached its end. Either it holds its last frame - the
    // knockdown - or the set stands back up in its resting move.
    function _done() {
        const what = _set._move
        if (_set._table && _set._table.holds) {
            _set._held = true
            _set.finished(what)
            return
        }
        _set.finished(what)
        // finished() may itself have started something; only fall back to the
        // rest move when nothing else has taken over.
        if (_set._drive.running || _set._move !== what)
            return
        if (_set.autoRest && _set.restMove !== "" && _set.restMove !== what)
            _set.play(_set.restMove)
        else
            _set.stop()
    }

    // The phase is driven linearly: the SHAPE of a move lives in the model's
    // keys and the curves they arrive on, and easing the phase instead would
    // ease every joint by the same curve - which is the whole difference
    // between a jab and a step.
    property NumberAnimation _drive: NumberAnimation {
        target: _set
        property: "phase"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.Linear
        onFinished: _set._done()
    }

    property NumberAnimation _blendAnim: NumberAnimation {
        target: _set
        property: "_blend"
        from: 0
        to: 1
        duration: 140
        easing.type: Easing.InOutQuad
    }
}
