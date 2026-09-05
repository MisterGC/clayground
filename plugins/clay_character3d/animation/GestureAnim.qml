// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// GestureAnim - held poses, as opposed to the cycles next to it in this
// directory. Walk, run, idle and fight loop; a gesture eases in over
// settleMs, HOLDS for as long as it is wanted, and eases back to the rest
// pose when it is not. The plugin had no way to express that before, which is
// why IdleAnim was free to zero all sixteen joints whenever a character
// stopped moving.
//
// Point, present, thumbs-up, look-at and the loose gesticulation of somebody
// explaining live in one driver on purpose. They all need the same eight
// joints, and two components animating one joint do not take turns: they
// interleave, and the arm ends up somewhere neither asked for. A sixth
// gesture is another branch in _apply(), not another file.
//
// Only one animator may own a joint at a time, so the gesture layer is
// confined to Character.Activity.Idle and Character drops the gesture before
// it starts any other activity. See "Gestures" in the plugin README.
//
// The aiming is solved in the character's own frame - the world target goes
// through mapPositionFromScene first - so the same arithmetic works wherever
// the character stands and whichever way it happens to face. Every length it
// needs comes off the character it is driving (arm segments, shoulder and
// head anchors), so a gesture fits a child and a giant equally.

import QtQuick
import QtQuick3D

/*!
    \qmltype GestureAnim
    \inqmlmodule Clayground.Character3D
    \inherits Node
    \brief Held poses - pointing, presenting, thumbs up, gesticulation and
           look-at - for one character.

    Every \l Character owns one of these and publishes it as verbs
    (\l Character::pointAt(), \l Character::presentAt(),
    \l Character::gesticulate(), \l Character::stopGesture(), ...), which is
    how it is normally used.
    Reach for the type itself only to drive a character built by hand.

    A gesture holds until it is released, so this layer and the activity
    cycles cannot both be running: it is confined to
    Character.Activity.Idle, and \l holding tells the rest of the character
    to keep off the joints while it is set.

    \qml
    GestureAnim {
        id: gestures
        entity: someCharacter
    }

    gestures.request("point", stone.scenePosition, "auto")
    \endqml

    \sa Character, IdleAnim, DetailedHand
*/
Node {
    id: root

    // Nothing to draw: this is a driver, not a visual.
    visible: false

    /*!
        \qmlproperty var GestureAnim::entity
        \brief The \l Character to drive. Null means the layer does nothing.
    */
    property var entity: null

    /*!
        \qmlproperty string GestureAnim::gesture
        \brief Which pose is wanted: "point" or "present" (both need
               \l target), "thumbsUp", "talk", or "" to release.

        "present" is the open hand offered toward a thing - palm up, at chest
        height, elbow bent - the "here we have" of a presenter. It is the
        gesture for a GROUP or an AREA: several parts, a whole circuit,
        anything where a finger at the centroid would point at nothing.
    */
    property string gesture: ""

    /*!
        \qmlproperty var GestureAnim::target
        \brief Where to point or present: a scene-space vector3d, or null
               for nowhere.
    */
    property var target: null

    /*!
        \qmlproperty var GestureAnim::lookTarget
        \brief Where the head looks, a scene-space vector3d, or null.

        Independent of \l gesture and outranks it: while it is set, the head
        aims here and the gesture keeps the arms. That is the difference
        between pointing at a thing and talking about it to someone else.
    */
    property var lookTarget: null

    /*!
        \qmlproperty string GestureAnim::hand
        \brief Which arm gestures: "auto" (the one nearer the target),
               "left" or "right".
    */
    property string hand: "auto"

    /*!
        \qmlproperty int GestureAnim::settleMs
        \brief How long a pose takes to arrive at - and to leave.
    */
    property int settleMs: 450

    /*!
        \qmlproperty real GestureAnim::beatScale
        \brief Stretches or compresses the talking rhythm. 1 is as authored,
               above 1 is a slower speaker.
    */
    property real beatScale: 1.0

    /*!
        \qmlproperty bool GestureAnim::safeSilhouette
        \brief Whether a raised arm is forced to bend at the elbow.

        On by default. See the note in _apply(): this is a policy about what
        shape the character is allowed to make, not an accuracy measure.
        Turn it off for a character whose job is a salute, a hand-raise or a
        throw.
    */
    property bool safeSilhouette: true

    /*!
        \qmlproperty bool GestureAnim::holding
        \readonly
        \brief True while this layer owns the joints - including the ease
               back to rest, which is not finished until it is false.

        Character gates IdleAnim and TalkGestureAnim on this. Nothing else
        may write a joint while it is true.
    */
    readonly property bool holding: root._live || root._holdsRoot

    /*!
        \qmlproperty bool GestureAnim::settled
        \readonly
        \brief True once the pose has arrived - the cue to start talking
               about the thing that was pointed at.
    */
    readonly property bool settled: root._settled

    /*!
        \qmlproperty string GestureAnim::activeGesture
        \readonly
        \brief Which gesture is being held: "point", "present", "thumbsUp",
               "talk" or "".

        A head-only look reports "": it is direction, not a gesture.
    */
    readonly property string activeGesture: _pose.mode === "look" ? "" : _pose.mode

    /*!
        \qmlproperty string GestureAnim::activeHand
        \readonly
        \brief Which arm is doing it: "left", "right", or "" while released
               or while talking, which is two-handed.
    */
    readonly property string activeHand: _pose.side === 0 ? ""
                                       : (_pose.side > 0 ? "right" : "left")

    /*!
        \qmlproperty string GestureAnim::rightHandPose
        \readonly
        \brief The \l DetailedHand pose for the right hand, or "" for "not
               mine to say" - then the character's own handPose applies.

        While talking this is per beat and per hand: two hands held in the
        same shape for the length of a sentence is most of what makes
        gesticulation read as a puppet. Ignored by characters whose hands
        are plain boxes; the wrist still turns either way.
    */
    readonly property string rightHandPose: _pose.mode === "talk" ? _pose.rPose
                                          : (_pose.side > 0 ? root._activePose : "")

    /*!
        \qmlproperty string GestureAnim::leftHandPose
        \readonly
        \brief The \l DetailedHand pose for the left hand, or "".
    */
    readonly property string leftHandPose: _pose.mode === "talk" ? _pose.lPose
                                         : (_pose.side < 0 ? root._activePose : "")

    /*!
        \qmlmethod void GestureAnim::request(string what, var where, string which)
        \brief Asks for a gesture, in one step.

        Set as three properties instead and the pose is recomputed after each
        of them, from a half-changed request. This applies once.
    */
    function request(what, where, which) {
        root._batch = true
        root.hand = (which === undefined || which === null || which === "")
                    ? "auto" : ("" + which)
        root.target = (where === undefined) ? null : where
        root.gesture = (what === undefined || what === null) ? "" : ("" + what)
        root._batch = false
        root._apply()
    }

    /*!
        \qmlmethod void GestureAnim::look(var where)
        \brief Aims the head at a scene position; null lets it follow the
               gesture again.
    */
    function look(where) {
        root.lookTarget = (where === undefined) ? null : where
    }

    /*!
        \qmlmethod void GestureAnim::turnTo(var where)
        \brief Turns the whole body to face a scene position.

        The turn goes through the same body animation the poses use, because
        a second animator on the character's rotation would fight this one.
        It moves the RESTING orientation, so it survives the next release.
    */
    function turnTo(where) {
        const c = root.entity
        if (!root._isVec(where) || !root._has(c))
            return
        const here = c.scenePosition
        const dx = where.x - here.x
        const dz = where.z - here.z
        if (Math.abs(dx) < 1e-4 && Math.abs(dz) < 1e-4)
            return
        const want = Math.atan2(dx, dz) * root._deg
        const yaw = c.eulerRotation.y + root._shortWay(want - c.eulerRotation.y)
        if (!root._holdsRoot) {
            root._restEuler = Qt.vector3d(c.eulerRotation.x, yaw, c.eulerRotation.z)
            root._holdsRoot = true
        } else {
            root._restEuler = Qt.vector3d(root._restEuler.x, yaw, root._restEuler.z)
        }
        root._apply()
    }

    /*!
        \qmlmethod void GestureAnim::drop()
        \brief Gives the joints up immediately, wherever they are.

        For the handover to an activity cycle: that cycle animates from
        whatever angle it finds, so easing back to rest first would be a
        second animator writing the same joints while it does. Releasing
        gracefully is \l request("") instead.
    */
    function drop() {
        _settle.stop()
        _arrival.stop()
        root._batch = true
        root.gesture = ""
        root.target = null
        root.lookTarget = null
        root._batch = false
        _pose.forget()
        root._live = false
        root._settled = false
        root._holdsRoot = false
    }

    // ------------------------------------------------------------------
    // Joint limits. Under-reaching reads as a human who cannot quite see
    // the thing; over-reaching reads as a broken rig, so every clamp errs
    // on the short side. Degrees throughout, and none of them is a length -
    // everything with a size in it comes off the character.
    // ------------------------------------------------------------------

    // Shoulder flexion: 0 is the arm hanging down, -90 straight ahead,
    // -180 straight overhead. Stopping short of overhead keeps the pose
    // out of the singularity where the aim yaw stops being defined, and
    // a few degrees behind vertical is all the extension a point needs.
    readonly property real _armPitchMin: -160
    readonly property real _armPitchMax: 15

    // Sideways swing of the upper arm. Real abduction reaches 90, but a
    // pointing arm that far out stops reading as pointing, and negative
    // values cross the chest - which is why this stays symmetric and small.
    readonly property real _armSideMax: 45

    // A pointing arm is nearly straight; it only folds for things close
    // enough that a straight arm would poke them.
    readonly property real _elbowMin: 6
    readonly property real _elbowMax: 38

    // The bend forced on a fully raised arm while safeSilhouette holds,
    // whatever the distance says - see the note in _apply().
    readonly property real _elbowRaised: 58

    // Wrist extension only has to make the hand continue the arm's line - but
    // it also has to absorb the forced bend above, so it is given more travel
    // than the geometry alone would need. Still well inside what a wrist does.
    readonly property real _wristMax: 32

    // The thumbs-up, as four numbers. Nothing is solved here - there is
    // nothing to aim at - but the forearm has to come up LEVEL, and that is a
    // hard requirement rather than a preference: the thumb stands off the BACK
    // of the fist, not off its top, so it only points upward while the forearm
    // is horizontal. Tilt the forearm and the gesture quietly starts meaning
    // nothing. The upper arm and the elbow are therefore chosen as a pair.
    //
    // The swing is the other half of it, and it is not cosmetic either: held
    // in front of the chest the hand sits ON the torso, and a thumb that does
    // not break the silhouette is a thumb nobody sees from more than a few
    // steps away. Out to the side it reads against the background.
    readonly property real _thumbUpperPitch: -30   // just forward of hanging
    readonly property real _thumbElbow: 60         // -30 - 60 = level
    readonly property real _thumbSwing: 30         // and out, clear of the body
    readonly property real _thumbRoll: 90          // palm turned to face the body
    readonly property real _thumbHeadPitch: -6     // chin up a fraction; a pleased pose

    // The present - an open hand offered toward the thing, the way a
    // presenter says "here we have". Nothing is aimed along the arm: the hand
    // stays in front of the body at chest height and only the forearm turns
    // toward the target, so the pose can never become the raised straight
    // arm the point has to guard against - the elbow is never straighter
    // than _presentElbowMin, whatever the target does.
    //
    // The forearm follows the target's elevation from the shoulder, but only
    // a little: a low target tips the hand down toward it, a high one lifts
    // it toward level, and the two clamps keep the hand between waist and
    // chest whatever is being presented. A thing further above or below than
    // that is what pointing is for. The lift shares the elevation with the
    // elbow so a low present drops the whole arm slightly rather than
    // straightening it.
    readonly property real _presentLift: 25        // upper arm forward of hanging, at level
    readonly property real _presentLiftMin: 8
    readonly property real _presentLiftMax: 30
    readonly property real _presentElbowMin: 45    // "clearly bent"
    readonly property real _presentElbowMax: 95
    readonly property real _presentDropMax: -18    // forearm below level, degrees
    readonly property real _presentRiseMax: 10     // and above it
    // The forearm turns toward the target about the shoulder's vertical axis,
    // which yaws the whole arm; capped so a hand never crosses the chest.
    readonly property real _presentYawMax: 45
    readonly property real _presentSwing: 12       // elbow out, clear of the body
    // The palm turns up by rolling the forearm - supination, the way a real
    // wrist does it - and stops a little short of flat, which is as far as a
    // forearm comfortably goes and leaves the palm tilted toward the viewer.
    readonly property real _presentRoll: 165
    // A hair of wrist lift so the fingers continue the forearm rather than
    // drooping off the end of it; positive here because the roll above has
    // turned the hand over, which flips the sense of the bend.
    readonly property real _presentWristLift: 8

    // ------------------------------------------------------------------
    // Talking, as a table of beats. Each row is one shape the character
    // makes and then holds; the loop walks the rows in order and starts over.
    //
    // Written out by hand rather than derived, because what makes
    // gesticulation read as speech is that no two beats are alike and none of
    // them is the mirror of another. It replaced two beats that WERE mirrors
    // of each other, which came out as a metronome with arms. Seven rows are
    // also the easiest thing here to retune: change a number, look at it.
    //
    // No Math.random() anywhere in it, and that is not a style preference. A
    // gesture that differed between two runs would make every screenshot
    // comparison and every waited-for joint value worthless.
    //
    // The columns, per row:
    //   rUp/lUp    how far the upper arm swings forward of hanging, in
    //              degrees. Positive here and negated at use, because "16
    //              forward" is easier to compare down a column than "-16".
    //   rEl/lEl    how far the elbow is bent. With the lift this is what
    //              decides where the hand ends up, since the forearm sits at
    //              lift + bend from hanging: 16 and 86 puts the hand up in
    //              front of the chest, 6 and 32 leaves it by the hip. The lift
    //              is kept small and the bend does the work, which is both
    //              what a talking arm looks like and what the bounds below
    //              are protecting.
    //   rOut/lOut  how far the arm is carried out from the body. Small
    //              throughout: people explain things in front of their chest,
    //              and an arm out to the side is a shrug, not a sentence.
    //   rWr/lWr    wrist bend, in the SAME sense as the elbow, which is the
    //              convention the pointing solver uses: negative carries the
    //              hand on round the way the elbow folded, and with a forearm
    //              held out in front that tips the fingers UP; positive bends
    //              it back and drops them. Fingers up is a hand presenting
    //              something, fingers down is a stressed word.
    //   rRo/lRo    wrist roll, signed per side, 90 being the palm turned fully
    //              to face the body. This is what turns two raised hands into
    //              a shape being described rather than two raised hands.
    //   rPo/lPo    which DetailedHand pose the hand takes. Skipped by
    //              characters without articulated hands.
    //   nod/yaw/tilt   the head; positive nod looks down.
    //   lean/turn  the whole body, added to wherever it was already facing.
    //              Two or three degrees is the whole budget - more and the
    //              character starts turning away from who it is talking to.
    //   ms/hold    how long the beat takes to arrive, then how long it stays.
    //   ease       the attack. Accents get OutCubic, which arrives fast and
    //              settles; drifts get InOutQuad. Never OutBack - see the
    //              bounds note below.
    readonly property var _talkBeats: [
        // 0 - opens the sentence: the right hand comes up, the left stays down
        { rUp: 16, rEl: 86, rOut: 12, rWr: -8, rRo: 55, rPo: "relax",
          lUp:  6, lEl: 32, lOut:  7, lWr:  0, lRo:  5, lPo: "relax",
          nod: -4, yaw:  6, tilt:  3, lean: 1, turn:  3,
          ms: 260, hold: 190, ease: Easing.OutCubic },
        // 1 - almost nothing happens. The hand stays where it landed while the
        //     sentence carries on, which is what makes beat 2 read as a move
        //     rather than as more of the same waving.
        { rUp: 13, rEl: 76, rOut: 13, rWr:  6, rRo: 42, rPo: "relax",
          lUp:  7, lEl: 35, lOut:  7, lWr:  2, lRo:  8, lPo: "relax",
          nod: -1, yaw:  5, tilt:  4, lean: 1, turn:  3,
          ms: 300, hold: 330, ease: Easing.InOutQuad },
        // 2 - both hands, framing something - and at deliberately different
        //     heights, since two hands level with each other is a measurement,
        //     not a gesture
        { rUp: 22, rEl: 92, rOut: 16, rWr: -12, rRo: 72, rPo: "open",
          lUp: 12, lEl: 74, lOut: 14, lWr:  -6, lRo: 52, lPo: "relax",
          nod:  4, yaw:  0, tilt: -4, lean: 2, turn:  0,
          ms: 240, hold: 210, ease: Easing.OutCubic },
        // 3 - the other hand takes the lead and the body turns with it. A
        //     talker hands the gesture across rather than running both arms.
        { rUp:  8, rEl: 38, rOut:  7, rWr:  -2, rRo: 12, rPo: "relax",
          lUp: 20, lEl: 90, lOut: 14, lWr: -12, lRo: 62, lPo: "open",
          nod: -2, yaw: -7, tilt:  4, lean: 1, turn: -4,
          ms: 280, hold: 170, ease: Easing.OutCubic },
        // 4 - the downbeat: short, and both wrists drop on the stressed word.
        //     The one beat where the two hands do agree, because that is what
        //     emphasis is - and it is over in under a fifth of a second.
        { rUp: 12, rEl: 66, rOut: 10, rWr: 20, rRo: 34, rPo: "relax",
          lUp: 16, lEl: 76, lOut: 12, lWr: 16, lRo: 46, lPo: "relax",
          nod:  6, yaw: -3, tilt:  0, lean: 2, turn: -1,
          ms: 170, hold: 120, ease: Easing.OutCubic },
        // 5 - the index finger: one raised finger says "the first thing is"
        //     the way no arm position can. Held longer than any other beat
        //     because it is a statement rather than a movement.
        //
        //     The finger is raised by the WRIST, not by the arm, and that is a
        //     measured decision. The obvious way - fold the elbow hard and
        //     bring the hand up beside the face - fails on a large-headed
        //     character: the hand lands on the face from any three-quarter
        //     angle. Swinging the arm further out does not fix it either,
        //     because a deeply folded arm keeps its hand near the shoulder and
        //     the shoulder is what the swing pivots about. So the hand stays
        //     at chest height and the wrist tips the finger up instead.
        { rUp: 18, rEl:  84, rOut: 22, rWr: -28, rRo: 25, rPo: "point",
          lUp:  5, lEl:  29, lOut:  6, lWr:  0, lRo:  0, lPo: "relax",
          nod: -5, yaw: -4, tilt: -2, lean: 0, turn:  1,
          ms: 250, hold: 340, ease: Easing.OutCubic },
        // 6 - the gap between two sentences: hands down, head level, nothing
        //     to say yet. A beat where the character does nothing is what
        //     makes the other six read as decisions.
        { rUp: 14, rEl: 52, rOut:  8, rWr:  0, rRo:  8, rPo: "relax",
          lUp:  6, lEl: 30, lOut:  5, lWr:  0, lRo:  4, lPo: "relax",
          nod:  0, yaw:  0, tilt:  0, lean: 0, turn:  0,
          ms: 330, hold: 420, ease: Easing.InOutQuad }
    ]

    // The bounds every row above is put through, and they are the reason a
    // loop that waves both arms around is allowed to exist at all: a straight
    // arm swung up and forward is the silhouette this layer must never make
    // by accident (see _apply()), and a two-armed loop is precisely where one
    // would turn up. So the loop is made incapable of the shape rather than
    // merely not asked for it - a hand-edited row that breaks a bound is
    // clamped rather than honoured. These are the table's own bounds and stay
    // in force whatever \l safeSilhouette says; no row currently leans on
    // them, they are headroom for retuning.
    //
    // This covers the MOVES as well as the beats. EulerAnim is a
    // Vector3dAnimation, so every frame between two rows is a straight mix of
    // two poses that both obey the bounds, and a mix of two values inside a
    // range is inside that range. That argument only holds while nothing
    // overshoots its target, which is why the easings above stop at OutCubic
    // and OutBack is not on the menu.
    readonly property real _talkLiftMax: 42    // degrees forward of hanging
    readonly property real _talkElbowMin: 28   // never straighter than this
    readonly property real _talkElbowMax: 118  // and never past a folded arm
    readonly property real _talkSwingMax: 26   // talking happens in front of the chest
    readonly property real _talkRollMax: 90    // a quarter turn is all a forearm gives

    // A seven-row table played straight repeats every seven beats, and at
    // roughly half a second each that is short enough to hear as a loop. The
    // pause is therefore stretched on a three-beat cycle, and three does not
    // divide seven, so the rhythm only comes back around after twenty-one
    // beats. Set to 0 to turn it off.
    readonly property int _talkDrag: 90

    // Follow-through, and it is the difference between gesticulation and a
    // puppet. Eight joints given one duration arrive together, stop together
    // and set off together, which nothing made of flesh does: an arm leads,
    // the forearm is dragged after it and the hand arrives last, still
    // settling when the shoulder has already started the next beat. These are
    // multipliers on the beat's own move time, applied ONLY while talking - a
    // point has to arrive as one piece, and settled is timed off settleMs.
    readonly property real _dragElbow: 1.18
    readonly property real _dragWrist: 1.55
    readonly property real _dragHead: 1.30
    readonly property real _dragBody: 1.40

    // How much of each row's written hold is actually kept. The table's holds
    // were authored as pauses between beats that had already finished moving,
    // and the result read as a series of held poses rather than as talking:
    // the figure was motionless for as much of the time as it was moving. Cut
    // to just over half, the next beat begins while the wrist of the last one
    // is still travelling, so the motion never fully stops - except on the two
    // rows written as rests, which are long enough to survive the cut and are
    // what keeps the rhythm from becoming a churn.
    readonly property real _talkHoldKeep: 0.55

    // And the moves themselves are given a little longer than written, for
    // the same reason: a fast move into a long pause is a snap.
    readonly property real _talkMoveStretch: 1.2

    // Neck: looking down at your own feet is easy, craning up is not.
    readonly property real _headPitchMin: -35
    readonly property real _headPitchMax: 45
    readonly property real _headYawMax: 65

    // How much of the turn the body declines to do. A person swivels the
    // whole body only for what is clearly off to the side and leaves the
    // last few degrees to neck and shoulder - without this the body always
    // ends up dead-on and head and shoulder have nothing left to express.
    readonly property real _shoulderLead: 15

    // ------------------------------------------------------------------
    // Internals
    // ------------------------------------------------------------------

    // Whether a pose is currently wanted. Decided inside _apply() rather
    // than by a binding: a binding is not guaranteed to have caught up by
    // the time the change handler that triggered it runs.
    property bool _live: false

    property bool _settled: false

    // Property assignments in the declaration can fire their change handler
    // before the animations below exist; nothing is driven until they do.
    property bool _ready: false

    // Set while request() is filling in several properties at once, so the
    // pose is solved from the finished request rather than from each
    // intermediate state of it.
    property bool _batch: false

    // The orientation the character had before the gesture borrowed it.
    // Taken once per gesture, not per re-aim, so switching targets while
    // pointing still knows where "released" was. turnTo() moves it.
    property vector3d _restEuler: Qt.vector3d(0, 0, 0)
    property bool _holdsRoot: false

    // restart() stops before it starts, and that stop must not be mistaken
    // for a finished release - it would hand the orientation back while the
    // character is still half turned.
    property bool _restarting: false

    // How the joints travel to the pose that has just been computed. Held
    // apart from settleMs because the talking beats each set their own: a
    // gesticulation whose every beat takes the same time to arrive is still a
    // metronome however varied the poses are, and the attack is half of what
    // makes an accent an accent.
    // Every gesture other than talking puts both back to the defaults, so
    // pointing and the thumbs-up move exactly as they always did.
    property int _moveMs: root.settleMs
    property int _moveEase: Easing.InOutQuad

    // Which hand shape belongs to the gesture being held. The hands are
    // separate components and have no idea a gesture is running; this is how
    // they find out, and why a new gesture only has to name a pose here.
    readonly property string _activePose: _pose.mode === "point" ? "point"
                                        : _pose.mode === "present" ? "open"
                                        : (_pose.mode === "thumbsUp" ? "thumbsUp" : "")

    readonly property real _rad: Math.PI / 180
    readonly property real _deg: 180 / Math.PI

    function _clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }

    function _isVec(v) {
        return v !== null && v !== undefined && v.x !== undefined
    }

    function _has(o) { return o !== null && o !== undefined }

    // Turning 350 degrees to end up where turning -10 would have got you is
    // the single most obvious way for a rig to look like a rig.
    function _shortWay(delta) {
        return ((delta % 360) + 540) % 360 - 180
    }

    // A character-local point, in the frame the body will be in once it has
    // turned by \a deg. Everything is solved there rather than in the frame
    // the character stands in now, otherwise arm and body chase each other
    // for the length of the settle. Azimuths here are atan2(x, z), so
    // turning the body by deg takes the point's azimuth to (azimuth - deg).
    function _afterTurn(x, z, deg) {
        const t = deg * root._rad
        return Qt.vector2d(x * Math.cos(t) - z * Math.sin(t),
                           x * Math.sin(t) + z * Math.cos(t))
    }

    // Head pitch and yaw that aim the face at a character-local point.
    // The head's rest axis is +Z, so euler (p,y,0) aims it at
    // (cos p sin y, -sin p, cos p cos y): positive pitch looks down.
    function _headAim(x, y, z) {
        const c = root.entity
        const anchor = c.headPos
        const dx = x - anchor.x
        const dy = y - anchor.y
        const dz = z - anchor.z
        const len = Math.sqrt(dx * dx + dy * dy + dz * dz)
        if (len < 1e-4)
            return Qt.vector3d(0, 0, 0)
        return Qt.vector3d(root._clamp(Math.asin(root._clamp(-dy / len, -1, 1)) * root._deg,
                                       root._headPitchMin, root._headPitchMax),
                           root._clamp(Math.atan2(dx, dz) * root._deg,
                                       -root._headYawMax, root._headYawMax),
                           0)
    }

    // What the head does this frame: the look target if there is one, the
    // gesture's own idea of it otherwise. \a turnDeg is the body turn the
    // pose asks for, so the look is solved in the frame the head will be in.
    function _headPose(fallback, turnDeg) {
        const c = root.entity
        if (!root._isVec(root.lookTarget) || !root._has(c))
            return fallback
        const local = c.mapPositionFromScene(root.lookTarget)
        const flat = root._afterTurn(local.x, local.z, turnDeg)
        return root._headAim(flat.x, local.y, flat.y)
    }

    // One talking joint each, built from a row of _talkBeats and clamped on
    // the way out - so a row cannot break the bounds no matter what is typed
    // into it. \a side is 1 for the right arm and -1 for the left: the swing
    // and the roll are the two angles whose sign says "away from the body"
    // rather than a direction in space, so they are the two that get mirrored.
    function _talkUpper(lift, out, side) {
        return Qt.vector3d(-root._clamp(lift, 0, root._talkLiftMax),
                           0,
                           side * root._clamp(out, 0, root._talkSwingMax))
    }

    function _talkLower(bend) {
        return Qt.vector3d(-root._clamp(bend, root._talkElbowMin, root._talkElbowMax), 0, 0)
    }

    function _talkWrist(bend, roll, side) {
        return Qt.vector3d(root._clamp(bend, -root._wristMax, root._wristMax),
                           side * root._clamp(roll, -root._talkRollMax, root._talkRollMax),
                           0)
    }

    function _run() {
        root._restarting = true
        _settle.restart()
        root._restarting = false
    }

    // Recomputes the whole pose and eases the joints toward it. Both arms
    // are always written - the free one to neutral - so a gesture that
    // changes sides cannot leave the previous arm hanging in the air.
    //
    // \a keepSettled is for the talking loop, which re-applies on every beat
    // and must not keep announcing that it has not arrived yet.
    function _apply(keepSettled) {
        if (!root._ready || root._batch)
            return
        const c = root.entity
        const usable = root._has(c) && root._has(c.rightArm) && root._has(c.head)
        const thumb = root.gesture === "thumbsUp"
        const talk = root.gesture === "talk"
        const point = root.gesture === "point" && root._isVec(root.target)
        const present = root.gesture === "present" && root._isVec(root.target)
        const looking = root._isVec(root.lookTarget)
        const on = usable && (thumb || talk || point || present || looking)
        if (!on && !root._holdsRoot) {
            root._live = false
            return
        }

        root._live = on
        // The default travel, which everything but the talking loop keeps -
        // including the release, which has to ease out at the same rate it
        // eased in whatever it was doing beforehand.
        root._moveMs = root.settleMs
        root._moveEase = Easing.InOutQuad
        if (!keepSettled) {
            root._settled = false
            _arrival.stop()
        }

        if (!on) {
            _pose.release(root._restEuler)
            root._run()
            return
        }

        if (!root._holdsRoot) {
            root._restEuler = Qt.vector3d(c.eulerRotation.x, c.eulerRotation.y, c.eulerRotation.z)
            root._holdsRoot = true
        }

        if (thumb) {
            // No target, so no turn: the body keeps facing wherever it was.
            // "auto" has nothing to choose between here and picks the right
            // hand, which is what a right-handed cartoon does.
            const tside = root.hand === "left" ? -1 : 1
            _pose.rootEuler = root._restEuler
            // The quarter turn at the wrist, and it is the whole gesture.
            // A thumb leaves the SIDE of a fist, so a palm-down fist has its
            // thumb pointing sideways; rolling the hand until the palm faces
            // the body is what puts that thumb up. Rolling about the hand's
            // own Y is rolling about the forearm, because the hand hangs
            // along it - the same reason the wrist bend is an X.
            _pose.aim("thumbsUp", tside,
                      Qt.vector3d(root._thumbUpperPitch, 0, tside * root._thumbSwing),
                      Qt.vector3d(-root._thumbElbow, 0, 0),
                      Qt.vector3d(0, tside * root._thumbRoll, 0),
                      root._headPose(Qt.vector3d(root._thumbHeadPitch, 0, 0), 0))
            root._run()
            _arrival.restart()
            return
        }

        if (talk) {
            // Every gesticulation opens on row 0 rather than wherever the last
            // one left off: the first row is the one written to be entered
            // from a body standing still, and the rest assume the arms are
            // already up.
            if (_pose.mode !== "talk")
                root._beatNo = 0

            const b = root._talkBeats[root._beatNo % root._talkBeats.length]
            root._moveMs = Math.round(b.ms * root._talkMoveStretch * root.beatScale)
            root._moveEase = b.ease
            root._nextBeatMs = root._moveMs
                             + Math.round(b.hold * root._talkHoldKeep * root.beatScale)
                             + (root._beatNo % 3) * root._talkDrag

            // No target and no turn to solve: the character is addressing
            // whoever it is already facing, and turning it is turnTo()'s job.
            // The lean and turn below are a weight shift ON TOP of that
            // facing, not a facing of their own, which is why they are added
            // to the rest orientation rather than replacing it - a talking
            // body that decided where to look would fight turnTo() and win.
            _pose.rootEuler = Qt.vector3d(root._restEuler.x + b.lean,
                                          root._restEuler.y + b.turn,
                                          root._restEuler.z)
            _pose.gesticulate(root._talkUpper(b.rUp, b.rOut, 1),
                              root._talkLower(b.rEl),
                              root._talkWrist(b.rWr, b.rRo, 1),
                              b.rPo,
                              root._talkUpper(b.lUp, b.lOut, -1),
                              root._talkLower(b.lEl),
                              root._talkWrist(b.lWr, b.lRo, -1),
                              b.lPo,
                              root._headPose(Qt.vector3d(root._clamp(b.nod, root._headPitchMin,
                                                                     root._headPitchMax),
                                                         root._clamp(b.yaw, -root._headYawMax,
                                                                     root._headYawMax),
                                                         b.tilt),
                                             b.turn))
            root._run()
            if (!keepSettled)
                _arrival.restart()
            return
        }

        if (!point && !present) {
            // Nothing but a look: the head aims, the rest of the body is left
            // exactly as it was standing. settled stays false - it answers
            // for a gesture, and looking somewhere is not one.
            _pose.watch(root._restEuler, root._headPose(Qt.vector3d(0, 0, 0), 0))
            root._run()
            return
        }

        // Point and present share everything up to the arm: the body turn,
        // the choice of hand and the shoulder the solve starts from.
        const local = c.mapPositionFromScene(root.target)

        // A character faces +Z: nose, eyes and mouth sit on the +Z face of
        // the head, and CharacterController walks along +Z at yaw 0.
        const off = Math.atan2(local.x, local.z) * root._deg
        const turn = off - Math.sign(off) * Math.min(Math.abs(off), root._shoulderLead)
        _pose.rootEuler = Qt.vector3d(root._restEuler.x, c.eulerRotation.y + turn, root._restEuler.z)

        const aimed = root._afterTurn(local.x, local.z, turn)
        const tx = aimed.x
        const ty = local.y
        const tz = aimed.y

        const side = root.hand === "left" ? -1
                   : root.hand === "right" ? 1
                   : (local.x >= 0 ? 1 : -1)

        // Shoulder and head sit at fixed offsets inside the character, which
        // publishes both - so the aim starts from the joint that does the
        // work instead of from the character's feet.
        const shoulder = side > 0 ? c.rightShoulderPos : c.leftShoulderPos

        let vx = tx - shoulder.x
        let vy = ty - shoulder.y
        let vz = tz - shoulder.z
        const len = Math.sqrt(vx * vx + vy * vy + vz * vz)
        if (len < 1e-4)
            return
        vx /= len; vy /= len; vz /= len

        if (present) {
            // The hand is offered, not aimed. The upper arm hangs a little
            // forward, the elbow folds until the forearm is about level, and
            // the whole arm is yawed about the shoulder toward the target -
            // the Y of the shoulder euler, which the point never uses. That
            // is the one angle that says "toward that", and it costs nothing
            // in silhouette: the arm stays folded whichever way it turns.
            const elev = root._clamp(Math.asin(root._clamp(vy, -1, 1)) * root._deg,
                                     root._presentDropMax, root._presentRiseMax)
            const lift = root._clamp(root._presentLift + 0.5 * elev,
                                     root._presentLiftMin, root._presentLiftMax)
            // pitch is -lift and the forearm sits at lift + bend from hanging,
            // so level is 90 and the elevation rides on top of it.
            const bend = root._clamp(90 + elev - lift,
                                     root._presentElbowMin, root._presentElbowMax)
            const yaw = root._clamp(Math.atan2(vx, vz) * root._deg,
                                    -root._presentYawMax, root._presentYawMax)
            _pose.aim("present", side,
                      Qt.vector3d(-lift, yaw, side * root._presentSwing),
                      Qt.vector3d(-bend, 0, 0),
                      Qt.vector3d(root._presentWristLift, side * root._presentRoll, 0),
                      root._headPose(root._headAim(tx, ty, tz), turn))
            root._run()
            _arrival.restart()
            return
        }

        // Node rotations compose as Ry * Rx * Rz, so a joint whose rest axis
        // is -Y aims at (sin r, -cos r cos p, -cos r sin p) for euler (p,0,r).
        // Inverting that gives the shoulder its two angles directly.
        let swing = Math.asin(root._clamp(vx, -1, 1)) * root._deg
        swing = root._clamp(swing, -root._armSideMax, root._armSideMax)
        let pitch = Math.atan2(-vz, -vy) * root._deg

        // Close things get a folded arm; distant ones an almost straight one.
        // Judged against the character's own reach, so "close" means the same
        // thing on a child and on a giant.
        const reach = c.armHeight
        const near = root._clamp(1 - len / (4 * reach), 0, 1)
        let elbow = root._elbowMin + near * (root._elbowMax - root._elbowMin)

        // POLICY, NOT ARITHMETIC - do not delete this as a redundant clamp.
        //
        // A STRAIGHT ARM RAISED FORWARD IS NOT AN ACCEPTABLE SILHOUETTE for a
        // character with safeSilhouette set. Pointing at something high and
        // far away produces exactly that shape, which reads as a fascist
        // salute, and a teaching character may not be capable of striking it
        // by accident. So the higher the aim, the more the elbow is forced to
        // bend: the upper arm stays low and the forearm does the reaching,
        // which is how a person points upward anyway.
        //
        // It costs no accuracy. The bend is given back to the shoulder through
        // bendOff below and to the wrist after it, so the fingertip stays on
        // the shoulder-to-target line - only the shape of the arm holding it
        // there changes. Characters whose job IS a raised straight arm - a
        // salute, a hand-raise, a throw - turn the property off.
        //
        // pitch is 0 with the arm hanging down and -90 with it forward and
        // level, so `rise` is how far above level the aim is.
        if (root.safeSilhouette) {
            const rise = root._clamp((-pitch - 90) / 60, 0, 1)
            elbow = Math.max(elbow, root._elbowRaised * rise)
        }

        // A bent elbow swings the hand forward of the upper arm's line, so
        // the shoulder has to give that angle back or the finger aims high.
        const upper = reach * c.armUpperRatio
        const lower = reach * (1 - c.armUpperRatio)
        const bendOff = Math.atan2(lower * Math.sin(elbow * root._rad),
                                   upper + lower * Math.cos(elbow * root._rad)) * root._deg
        pitch = root._clamp(pitch + bendOff, root._armPitchMin, root._armPitchMax)

        // The wrist puts the hand back on the shoulder-to-target line.
        const wrist = root._clamp(elbow - bendOff, -root._wristMax, root._wristMax)

        // And then the wrist puts the FINGER on it, which is not the same
        // thing. Everything above aims the hand's own axis - the line straight
        // out of the wrist - because that is the joint the arithmetic can
        // reach. But an index finger is not on that axis: it is one of four
        // packed across a palm, sitting about a third of a palm's width off to
        // the side, and over the length of a hand that works out to nearly ten
        // degrees. The arm was solved perfectly and the finger missed anyway,
        // which is the one failure a pointing character cannot have.
        //
        // indexTip is where the hand actually ends, in the wrist's own frame,
        // so the correction is the angle between it and the axis. Node
        // rotations compose as Ry * Rx * Rz, so the Z part lands first and
        // swings the finger onto the plane; the X part then drops it onto the
        // line. On a plain hand indexTip is straight down the axis and both
        // come out zero, so this costs nothing where there is no finger to
        // aim.
        const arm = side > 0 ? c.rightArm : c.leftArm
        const tip = arm ? arm.indexTip : Qt.vector3d(0, -1, 0)
        const fingerSwing = Math.atan2(-tip.x, -tip.y) * root._deg
        const fingerDrop = Math.atan2(tip.z, Math.hypot(tip.x, tip.y)) * root._deg

        _pose.aim("point", side, Qt.vector3d(pitch, 0, swing),
                  Qt.vector3d(-elbow, 0, 0),
                  Qt.vector3d(root._clamp(wrist + fingerDrop,
                                          -root._wristMax, root._wristMax),
                              0, fingerSwing),
                  root._headPose(root._headAim(tx, ty, tz), turn))
        root._run()
        _arrival.restart()
    }

    // A point is solved against the hand it is being made with: the correction
    // that puts the FINGER on the target instead of the wrist comes out of
    // indexTip, and a plain hand has no finger to correct for. Level of detail
    // can change under a held pose - that is the entire point of Detail.Auto,
    // and a gesture is one of the things that makes it change - so the solve
    // has to be redone when it does, or the character grows a finger that is
    // aiming where the box used to.
    Connections {
        target: root.entity
        ignoreUnknownSignals: true
        function onDetailedHandsChanged() { root._apply() }
    }

    onEntityChanged: root._apply()
    onTargetChanged: root._apply()
    onLookTargetChanged: root._apply()
    onHandChanged: root._apply()
    onGestureChanged: root._apply()
    onSafeSilhouetteChanged: root._apply()
    Component.onCompleted: { root._ready = true; root._apply() }

    // The angles the joints are easing toward. Held as plain values rather
    // than bindings: the aim depends on scene positions, which do not
    // notify, so it is recomputed on purpose and never behind our back.
    QtObject {
        id: _pose

        property int side: 0
        // Which gesture the joints are currently holding: "", "point",
        // "present", "thumbsUp", "talk" or "look". `side` cannot answer that
        // on its own since talking has no side, and the hands have to know
        // which it is.
        property string mode: ""
        property vector3d rootEuler: Qt.vector3d(0, 0, 0)
        property vector3d head: Qt.vector3d(0, 0, 0)
        property vector3d rUpper: Qt.vector3d(0, 0, 0)
        property vector3d rLower: Qt.vector3d(0, 0, 0)
        property vector3d rHand: Qt.vector3d(0, 0, 0)
        property vector3d lUpper: Qt.vector3d(0, 0, 0)
        property vector3d lLower: Qt.vector3d(0, 0, 0)
        property vector3d lHand: Qt.vector3d(0, 0, 0)

        // What each hand should be shaped like. Only the talking loop fills
        // these in: the aimed gestures have one busy hand and answer for it
        // through _activePose, whereas talking has two hands doing different
        // things on the same beat and no way to say so with one name.
        property string rPose: ""
        property string lPose: ""

        readonly property vector3d zero: Qt.vector3d(0, 0, 0)

        function aim(what, which, upper, lower, wrist, look) {
            side = which
            mode = what
            head = look
            rPose = ""; lPose = ""
            rUpper = which > 0 ? upper : zero
            rLower = which > 0 ? lower : zero
            rHand = which > 0 ? wrist : zero
            lUpper = which < 0 ? upper : zero
            lLower = which < 0 ? lower : zero
            lHand = which < 0 ? wrist : zero
        }

        // Both arms at once, wrists and hand shapes included - which is what
        // talking needs and what aim() cannot express: aim() zeroes whichever
        // side is not gesturing, and while talking neither side is idle.
        function gesticulate(rUp, rLo, rHa, rP, lUp, lLo, lHa, lP, look) {
            side = 0
            mode = "talk"
            head = look
            rUpper = rUp; rLower = rLo; rHand = rHa; rPose = rP
            lUpper = lUp; lLower = lLo; lHand = lHa; lPose = lP
        }

        // A head aim with nothing else in it. The arms are written to neutral
        // like everywhere else: they are not doing anything, and leaving them
        // out would mean the previous gesture's arms stayed up.
        function watch(rest, look) {
            side = 0
            mode = "look"
            rootEuler = rest
            head = look
            rPose = ""; lPose = ""
            rUpper = zero; rLower = zero; rHand = zero
            lUpper = zero; lLower = zero; lHand = zero
        }

        function release(rest) {
            watch(rest, zero)
            mode = ""
        }

        // Give up without moving anything: for the handover to an activity
        // cycle, which animates from wherever it finds the joints.
        function forget() {
            side = 0
            mode = ""
            rPose = ""; lPose = ""
        }
    }

    // Joint travel times. One number while a pose is being struck or released,
    // a spread of them while talking - see the follow-through note above.
    readonly property bool _dragging: _pose.mode === "talk"
    readonly property int _msElbow: root._dragging ? root._moveMs * root._dragElbow : root._moveMs
    readonly property int _msWrist: root._dragging ? root._moveMs * root._dragWrist : root._moveMs
    readonly property int _msHead: root._dragging ? root._moveMs * root._dragHead : root._moveMs
    readonly property int _msBody: root._dragging ? root._moveMs * root._dragBody : root._moveMs

    ParallelAnimation {
        id: _settle

        EulerAnim {
            target: root.entity
            duration: root._msBody
            easing.type: root._moveEase
            to: _pose.rootEuler
        }
        HeadEulerAnim {
            target: root.entity ? root.entity.head : null
            duration: root._msHead
            easing.type: root._moveEase
            to: _pose.head
        }
        EulerAnim {
            target: root.entity ? root.entity.rightArm.upperArm : null
            duration: root._moveMs
            easing.type: root._moveEase
            to: _pose.rUpper
        }
        EulerAnim {
            target: root.entity ? root.entity.rightArm.lowerArm : null
            duration: root._msElbow
            easing.type: root._moveEase
            to: _pose.rLower
        }
        EulerAnim {
            target: root.entity ? root.entity.rightArm.hand : null
            duration: root._msWrist
            easing.type: root._moveEase
            to: _pose.rHand
        }
        EulerAnim {
            target: root.entity ? root.entity.leftArm.upperArm : null
            duration: root._moveMs
            easing.type: root._moveEase
            to: _pose.lUpper
        }
        EulerAnim {
            target: root.entity ? root.entity.leftArm.lowerArm : null
            duration: root._msElbow
            easing.type: root._moveEase
            to: _pose.lLower
        }
        EulerAnim {
            target: root.entity ? root.entity.leftArm.hand : null
            duration: root._msWrist
            easing.type: root._moveEase
            to: _pose.lHand
        }

        // The character owns its orientation - and its joints - again only
        // once the release has actually run. Re-engaging mid-release must not
        // mistake the half-turned pose for the character's resting facing,
        // and IdleAnim must not start while this is still writing.
        onRunningChanged: {
            if (!_settle.running && !root._live && !root._restarting)
                root._holdsRoot = false
        }
    }

    Timer {
        id: _arrival
        interval: root.settleMs
        onTriggered: root._settled = root._live
    }

    // How many talking beats have gone by since the gesture started. Counted
    // up rather than wrapped at the table length: the row is this modulo the
    // number of rows, and the rhythm jitter rides on the count itself, so
    // wrapping it would take the jitter's whole point away.
    property int _beatNo: 0

    // How long the current beat lasts, move and pause together. A property the
    // Timer binds to rather than an assignment onto the Timer, so the binding
    // below stays a binding.
    property int _nextBeatMs: 640

    // The loop behind the "talk" gesture. It re-applies the pose rather than
    // running an animation of its own, so the gesticulation goes through the
    // same eight EulerAnims as the held poses and can be interrupted by a
    // point at any moment without two animations meeting on one joint.
    Timer {
        id: _beat
        running: root._live && root.gesture === "talk"
        interval: root._nextBeatMs
        repeat: true
        onTriggered: {
            root._beatNo += 1
            root._apply(true)
        }
    }
}
