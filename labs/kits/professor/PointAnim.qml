// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// PointAnim - the held gestures. The cycles in Clayground.Character3D loop;
// these are poses: one eases in over settleMs, holds for as long as it is
// wanted, and eases back to the idle pose when it is not.
//
// Two of them now - "there, look at that" and "well done" - and they live in
// one driver on purpose. Both need the same eight joints, and two components
// animating one joint do not take turns: they interleave, and the arm ends up
// somewhere neither asked for. Adding a third gesture means another branch in
// _apply(), not another file.
//
// The pointing angles are solved in the character's own frame - the world
// target goes through mapPositionFromScene first - so the same arithmetic
// works wherever the character stands and whichever way it happens to face.
// The thumb is a fixed pose and needs none of that.

import QtQuick
import Clayground.Character3D

Item {
    id: root

    // Nothing to draw: this is a driver, not a visual.
    visible: false
    width: 0
    height: 0

    /*! The Character to drive. Null means the gesture does nothing at all. */
    property var character: null

    /*! Where to point: a world-space Qt.vector3d, or null for "nowhere". */
    property var target: null

    /*!
        Which pose: "point" needs a \l target, "thumbsUp" needs nothing and
        ignores one.
    */
    property string gesture: "point"

    /*! False releases the pose and hands the joints back to the idle animation. */
    property bool active: false

    /*! Which arm points: "auto" (the one nearer the target), "left" or "right". */
    property string hand: "auto"

    /*! How long the arm takes to arrive at - and to leave - the pose. */
    property int settleMs: 450

    /*! True while a pose is being aimed at or held. */
    readonly property bool pointing: _live

    /*! True once the arm has arrived - the cue to start talking about the thing. */
    readonly property bool settled: _settled

    /*! Which arm is doing the pointing right now: "left", "right" or "" while released. */
    readonly property string activeHand: _pose.side === 0 ? ""
                                       : (_pose.side > 0 ? "right" : "left")

    /*!
        What the busy hand should be doing - the DetailedHand pose name that
        matches the gesture, or "" while released. The hand is a separate
        component and has no idea a gesture is running; this is how it finds
        out, and why a new gesture only has to name a pose here.
    */
    readonly property string activePose: _pose.side === 0 ? ""
                                       : (root.gesture === "thumbsUp" ? "thumbsUp" : "point")

    // ------------------------------------------------------------------
    // Joint limits. Under-reaching reads as a human who cannot quite see
    // the thing; over-reaching reads as a broken rig, so every clamp errs
    // on the short side.
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

    // The bend forced on a fully raised arm, whatever the distance says - see
    // the silhouette note in _apply(). Not a style choice: it is the shape this
    // gesture is not allowed to make.
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
    readonly property real _thumbSwing: 30         // and out, clear of the coat
    readonly property real _thumbRoll: 90          // palm turned to face the body
    readonly property real _thumbHeadPitch: -6     // chin up a fraction; this is a pleased pose

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

    // The orientation the character had before the gesture borrowed it.
    // Taken once per gesture, not per re-aim, so switching targets while
    // pointing still knows where "released" was.
    property vector3d _restEuler: Qt.vector3d(0, 0, 0)
    property bool _holdsRoot: false

    // restart() stops before it starts, and that stop must not be mistaken
    // for a finished release - it would hand the orientation back while the
    // character is still half turned.
    property bool _restarting: false

    readonly property real _rad: Math.PI / 180
    readonly property real _deg: 180 / Math.PI

    function _clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }

    function _run() {
        root._restarting = true
        _settle.restart()
        root._restarting = false
    }

    // Recomputes the whole pose and eases the joints toward it. Both arms
    // are always written - the free one to neutral - so a gesture that
    // changes sides cannot leave the previous arm hanging in the air.
    function _apply() {
        if (!root._ready)
            return
        const c = root.character
        const thumb = root.gesture === "thumbsUp"
        const on = root.active
                   && c !== null && c !== undefined
                   && (thumb || (root.target !== null && root.target !== undefined
                                 && root.target.x !== undefined))
        if (!on && !root._holdsRoot) {
            root._live = false
            return
        }

        root._live = on
        root._settled = false
        _arrival.stop()

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
            _pose.aim(tside,
                      Qt.vector3d(root._thumbUpperPitch, 0, tside * root._thumbSwing),
                      Qt.vector3d(-root._thumbElbow, 0, 0),
                      Qt.vector3d(0, tside * root._thumbRoll, 0),
                      Qt.vector3d(root._thumbHeadPitch, 0, 0))
            root._run()
            _arrival.restart()
            return
        }

        const local = c.mapPositionFromScene(root.target)
        const flat = Math.sqrt(local.x * local.x + local.z * local.z)

        // A character faces +Z: nose, eyes and mouth sit on the +Z face of
        // the head, and CharacterController walks along +Z at yaw 0.
        const off = Math.atan2(local.x, local.z) * root._deg
        const turn = off - Math.sign(off) * Math.min(Math.abs(off), root._shoulderLead)
        _pose.rootEuler = Qt.vector3d(root._restEuler.x, c.eulerRotation.y + turn, root._restEuler.z)

        // Solve the limbs in the frame the character will stand in once the
        // turn has finished, not the one it is standing in now - otherwise
        // arm and body would chase each other for the length of the settle.
        const rest = (off - turn) * root._rad
        const tx = flat * Math.sin(rest)
        const ty = local.y
        const tz = flat * Math.cos(rest)

        const side = root.hand === "left" ? -1
                   : root.hand === "right" ? 1
                   : (local.x >= 0 ? 1 : -1)
        const arm = side > 0 ? c.rightArm : c.leftArm

        // Shoulder and head sit at fixed offsets inside the character, so
        // the aim can start from the joint that actually does the work
        // instead of from the character's feet.
        const sx = c.torso.basePos.x + arm.basePos.x
        const sy = c.torso.basePos.y + arm.basePos.y
        const sz = c.torso.basePos.z + arm.basePos.z

        let vx = tx - sx
        let vy = ty - sy
        let vz = tz - sz
        const len = Math.sqrt(vx * vx + vy * vy + vz * vz)
        if (len < 1e-4)
            return
        vx /= len; vy /= len; vz /= len

        // Node rotations compose as Ry * Rx * Rz, so a joint whose rest axis
        // is -Y aims at (sin r, -cos r cos p, -cos r sin p) for euler (p,0,r).
        // Inverting that gives the shoulder its two angles directly.
        let swing = Math.asin(root._clamp(vx, -1, 1)) * root._deg
        swing = root._clamp(swing, -root._armSideMax, root._armSideMax)
        let pitch = Math.atan2(-vz, -vy) * root._deg

        // Close things get a folded arm; distant ones an almost straight one.
        const reach = c.armHeight
        const near = root._clamp(1 - len / (4 * reach), 0, 1)
        let elbow = root._elbowMin + near * (root._elbowMax - root._elbowMin)

        // A STRAIGHT ARM RAISED FORWARD IS NOT AN ACCEPTABLE SILHOUETTE.
        // Pointing at something high and far away produced exactly that shape,
        // which reads as a fascist salute, and no teaching character may be
        // capable of striking it by accident. So the higher the aim, the more
        // the elbow is forced to bend: the upper arm stays low and the forearm
        // does the reaching, which is how a person points upward anyway.
        //
        // This costs no accuracy. The bend is already given back to the
        // shoulder through bendOff below and to the wrist after it, so the
        // fingertip stays on the shoulder-to-target line - only the shape of
        // the arm holding it there changes.
        //
        // pitch is 0 with the arm hanging down and -90 with it forward and
        // level, so `rise` is how far above level the aim is.
        const rise = root._clamp((-pitch - 90) / 60, 0, 1)
        elbow = Math.max(elbow, root._elbowRaised * rise)

        // A bent elbow swings the hand forward of the upper arm's line, so
        // the shoulder has to give that angle back or the finger aims high.
        const upper = reach * c.armUpperRatio
        const lower = reach * (1 - c.armUpperRatio)
        const bendOff = Math.atan2(lower * Math.sin(elbow * root._rad),
                                   upper + lower * Math.cos(elbow * root._rad)) * root._deg
        pitch = root._clamp(pitch + bendOff, root._armPitchMin, root._armPitchMax)

        // The wrist puts the hand back on the shoulder-to-target line.
        const wrist = root._clamp(elbow - bendOff, -root._wristMax, root._wristMax)

        const hdx = tx - c.torso.basePos.x - c.head.basePos.x
        const hdy = ty - c.torso.basePos.y - c.head.basePos.y
        const hdz = tz - c.torso.basePos.z - c.head.basePos.z
        const hlen = Math.sqrt(hdx * hdx + hdy * hdy + hdz * hdz)
        let headPitch = 0
        let headYaw = 0
        if (hlen > 1e-4) {
            // The head's rest axis is +Z, so euler (p,y,0) aims it at
            // (cos p sin y, -sin p, cos p cos y): positive pitch looks down.
            headPitch = root._clamp(Math.asin(root._clamp(-hdy / hlen, -1, 1)) * root._deg,
                                    root._headPitchMin, root._headPitchMax)
            headYaw = root._clamp(Math.atan2(hdx, hdz) * root._deg,
                                  -root._headYawMax, root._headYawMax)
        }

        _pose.aim(side, Qt.vector3d(pitch, 0, swing),
                  Qt.vector3d(-elbow, 0, 0), Qt.vector3d(wrist, 0, 0),
                  Qt.vector3d(headPitch, headYaw, 0))
        root._run()
        _arrival.restart()
    }

    onCharacterChanged: root._apply()
    onTargetChanged: root._apply()
    onActiveChanged: root._apply()
    onHandChanged: root._apply()
    onGestureChanged: root._apply()
    Component.onCompleted: { root._ready = true; root._apply() }

    // The angles the joints are easing toward. Held as plain values rather
    // than bindings: the aim depends on scene positions, which do not
    // notify, so it is recomputed on purpose and never behind our back.
    QtObject {
        id: _pose

        property int side: 0
        property vector3d rootEuler: Qt.vector3d(0, 0, 0)
        property vector3d head: Qt.vector3d(0, 0, 0)
        property vector3d rUpper: Qt.vector3d(0, 0, 0)
        property vector3d rLower: Qt.vector3d(0, 0, 0)
        property vector3d rHand: Qt.vector3d(0, 0, 0)
        property vector3d lUpper: Qt.vector3d(0, 0, 0)
        property vector3d lLower: Qt.vector3d(0, 0, 0)
        property vector3d lHand: Qt.vector3d(0, 0, 0)

        function aim(which, upper, lower, wrist, look) {
            const zero = Qt.vector3d(0, 0, 0)
            side = which
            head = look
            rUpper = which > 0 ? upper : zero
            rLower = which > 0 ? lower : zero
            rHand = which > 0 ? wrist : zero
            lUpper = which < 0 ? upper : zero
            lLower = which < 0 ? lower : zero
            lHand = which < 0 ? wrist : zero
        }

        function release(rest) {
            const zero = Qt.vector3d(0, 0, 0)
            side = 0
            rootEuler = rest
            head = zero
            rUpper = zero; rLower = zero; rHand = zero
            lUpper = zero; lLower = zero; lHand = zero
        }
    }

    ParallelAnimation {
        id: _settle

        EulerAnim {
            target: root.character
            duration: root.settleMs
            to: _pose.rootEuler
        }
        EulerAnim {
            target: root.character ? root.character.head : null
            duration: root.settleMs
            to: _pose.head
        }
        EulerAnim {
            target: root.character ? root.character.rightArm.upperArm : null
            duration: root.settleMs
            to: _pose.rUpper
        }
        EulerAnim {
            target: root.character ? root.character.rightArm.lowerArm : null
            duration: root.settleMs
            to: _pose.rLower
        }
        EulerAnim {
            target: root.character ? root.character.rightArm.hand : null
            duration: root.settleMs
            to: _pose.rHand
        }
        EulerAnim {
            target: root.character ? root.character.leftArm.upperArm : null
            duration: root.settleMs
            to: _pose.lUpper
        }
        EulerAnim {
            target: root.character ? root.character.leftArm.lowerArm : null
            duration: root.settleMs
            to: _pose.lLower
        }
        EulerAnim {
            target: root.character ? root.character.leftArm.hand : null
            duration: root.settleMs
            to: _pose.lHand
        }

        // The character owns its orientation again only once the release has
        // actually run - re-engaging mid-release must not mistake the
        // half-turned pose for the character's resting facing.
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
}
