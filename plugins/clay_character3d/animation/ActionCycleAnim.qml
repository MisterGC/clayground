// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ActionCycleAnim - the one animator behind Character.Activity.Using and
// Character.Activity.Fighting.
//
// It animates ONE number, the phase, and writes whatever action.js answers for
// it. Every other cycle here spells its poses out as a wall of EulerAnims and
// keeps a pure poseAt() beside them for the sheets to draw from - which works,
// and asks the two to be kept in step by hand (see the note in GaitCycleAnim's
// StepLift). A cycle that is written once and read twice cannot get out of
// step at all: the frozen columns of the character lab's gesture sheet
// (labs/kits/character/GestureSheet.qml) are the same function this plays, so
// a pose that reads wrong on the sheet is wrong on screen and a pose fixed on
// the sheet is fixed on screen.
//
// The cost is a per-frame JS write of sixteen joints instead of a declarative
// animation the scene graph can run on its own. That is affordable here and
// nowhere near the gait: a character walks for minutes at a time and there may
// be a crowd of them, whereas working and boxing are one character in front of
// the camera doing one thing.

import QtQuick
import "action.js" as ActionLib

/*!
    \qmltype ActionCycleAnim
    \inqmlmodule Clayground.Character3D
    \inherits SequentialAnimation
    \brief A looping whole-body action - working at something, or boxing -
           replayed from the pure pose model in \c action.js.

    \l UseAnim and \l FightAnim are this with \l action set. Every angle comes
    from \c {action.js}; nothing is authored here.

    \sa UseAnim, FightAnim, Character::actionPoseAt()
*/
SequentialAnimation {
    id: _cycle

    /*!
        \qmlproperty var ActionCycleAnim::entity
        \brief The \l Character whose joints this writes.
    */
    required property var entity

    /*! \qmlproperty string ActionCycleAnim::action
        \brief Which action: "use" or "fight". */
    property string action: "use"

    /*!
        \qmlproperty real ActionCycleAnim::intensity
        \brief 0 is unhurried, 1 is hard at it. Changes the speed of the cycle
               and the size of the movement, never the shape of the pose.
    */
    property real intensity: 0.5

    /*!
        \qmlproperty real ActionCycleAnim::workHeight
        \brief Where the work is: 0 a table at the waist, 0.5 a counter at
               the chest, 1 a shelf at head height. Ignored by the fight.
    */
    property real workHeight: 0.35

    /*!
        \qmlproperty var ActionCycleAnim::table
        \readonly
        \brief The derived numbers the cycle is replayed from.
    */
    readonly property var table: ActionLib.derive(_cycle.action,
                                                  { intensity: _cycle.intensity,
                                                    workHeight: _cycle.workHeight,
                                                    // The body, so the hands can be
                                                    // placed against it: a fixed angle
                                                    // crossed a thin figure's hands.
                                                    shoulderWidth: _cycle.entity ? _cycle.entity.shoulderWidth : 0,
                                                    armLength: _cycle.entity ? _cycle.entity.armHeight : 0,
                                                    handWidth: _cycle.entity && _cycle.entity.rightArm
                                                               ? _cycle.entity.rightArm.handWidth : 0 })

    /*! \qmlproperty real ActionCycleAnim::cycleMs
        \readonly
        \brief One full cycle in milliseconds. */
    readonly property real cycleMs: _cycle.table.cycleMs

    /*!
        \qmlproperty string ActionCycleAnim::handPose
        \readonly
        \brief What the hands are shaped like while this runs, "" when it is
               not running - a fist for the fight, a loose hand for the work.

        \l Character reads it: an activity that closes the hands has to be able
        to say so, and before this existed a punch was thrown with an open
        hand.
    */
    readonly property string handPose: _cycle.running ? _cycle.table.hand : ""

    /*! \qmlproperty real ActionCycleAnim::phase
        \brief Where in the cycle it is, 0..1. Set it with the animation
               stopped to hold one frame of the action. */
    property real phase: 0

    /*!
        \qmlproperty int ActionCycleAnim::cycle
        \readonly
        \brief How many whole cycles have played since this started.

        The model reads it: a working loop that is the same every time is
        noticed as a loop within a minute and a half, so \c action.js makes
        every fourth cycle's settle a proper look up. Deterministic - the
        variation is a function of the count, never of a random draw - so a
        recording of the loop is the same recording twice.
    */
    readonly property int cycle: _cycle._cycle
    property int _cycle: 0
    property real _lastPhase: 0

    onPhaseChanged: {
        // The phase runs 0 to 1 and jumps back: that jump is one cycle.
        if (_cycle.phase < _cycle._lastPhase - 0.5)
            _cycle._cycle++
        _cycle._lastPhase = _cycle.phase
        _cycle._write()
    }
    onTableChanged: if (_cycle.running) _cycle._write()
    onRunningChanged: if (_cycle.running) { _cycle._cycle = 0; _cycle._lastPhase = 0 }

    // Writing stops the moment the cycle does: the joints stay where the last
    // frame left them, and IdleAnim - or whatever activity comes next - takes
    // them from there, which is the handover every other animator here makes.
    function _write() {
        if (!_cycle.running)
            return
        _cycle.apply(_cycle.phase)
    }

    /*!
        \qmlmethod void ActionCycleAnim::apply(real t)
        \brief Writes the pose at phase \a t onto the entity, running or not.

        What the sheet uses to freeze a figure mid-action.
    */
    function apply(t) {
        const c = _cycle.entity
        if (!c || !c.rightArm || !c.head)
            return
        const p = ActionLib.poseAt(_cycle.table, t, _cycle._cycle)
        const roll = c.handRestRoll === undefined ? 90 : c.handRestRoll

        function limb(m, a) {
            m.upperArm.eulerRotation = Qt.vector3d(a.upper[0], a.upper[1], a.upper[2])
            m.lowerArm.eulerRotation = Qt.vector3d(a.lower[0], a.lower[1], a.lower[2])
            // The roll arrives as a fraction of a quarter turn; the degrees
            // are the character's, not the action's.
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
        // The bounce, in leg heights, through the same slot the gait uses -
        // a stance with bent knees sits lower than a standing figure, and a
        // boxer's guard dips. IdleAnim eases it back to zero afterwards.
        if (p.lift !== undefined && c._heldLift !== undefined)
            c._heldLift = p.lift * c.legHeight
    }

    // The phase is driven linearly and the SHAPE of the motion lives in
    // action.js - punchAt() and strokeAt(). Easing the phase instead would ease
    // every joint by the same curve, and the whole difference between a punch
    // and a working stroke is that their curves are not the same.
    NumberAnimation {
        target: _cycle
        property: "phase"
        from: 0
        to: 1
        duration: Math.max(1, Math.round(_cycle.cycleMs))
        easing.type: Easing.Linear
    }
}
