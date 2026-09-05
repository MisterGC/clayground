// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import "gait.js" as GaitLib

/*!
    \qmltype GaitCycleAnim
    \inqmlmodule Clayground.Character3D
    \inherits ProceduralAnim
    \brief The one locomotion cycle: two mirrored steps over a table that
           gait.js derives from a base (walk or run) and a factor vector.

    \l WalkAnim and \l RunAnim are this with \l base set. Every angle comes
    from \l table, which \c {gait.js} derives from the base's authored numbers
    and the entity's \l {Character::gaitFactors}{gaitFactors}; with no factors
    the table is the base, and the base is the cycle exactly as it was before
    the gait model existed - \c {gait.test.js} pins that to the digit.

    A change of factors lands at the next half-cycle, when the phase that is
    starting reads its targets; there is no blend, which is how every other
    activity switch here behaves too.

    Beyond the joints the cycle animates one number of its own, \l lift, the
    up-and-down of the whole figure; \l Character adds it to the torso's
    height. It is zero whenever the cycle is not running.
*/
ProceduralAnim {
    id: _cycle

    /*! \qmlproperty string GaitCycleAnim::base
        \brief "walk" or "run": whose authored numbers the table starts from. */
    property string base: "walk"

    /*!
        \qmlproperty var GaitCycleAnim::factors
        \brief The composed factor vector, or null for neutral. Taken from the
               entity's \c gaitFactors when it has one.
    */
    property var factors: (entity && entity.gaitFactors !== undefined)
                          ? entity.gaitFactors : null

    /*!
        \qmlproperty var GaitCycleAnim::table
        \readonly
        \brief The derived angles and cycle length the phases animate to.
    */
    readonly property var table: GaitLib.derive(_cycle.base, _cycle.factors)

    /*! \qmlproperty real GaitCycleAnim::cycleMs
        \readonly
        \brief One full cycle, two steps, in milliseconds. */
    readonly property real cycleMs: _cycle.table.cycleMs

    // Half the cycle: each of the two phases is one step.
    duration: Math.round(_cycle.cycleMs / 2)

    /*!
        \qmlproperty real GaitCycleAnim::derivedSpeed
        \readonly
        \brief Ground speed that keeps the feet from sliding, from the hip
               angles, the leg and the cycle length.
    */
    readonly property real derivedSpeed: GaitLib.speedFor(_cycle.table, entity.legHeight,
                                                          _cycle._upperRatio)

    /*! \qmlproperty real GaitCycleAnim::strideLength
        \readonly
        \brief How far the feet travel in one full cycle. */
    readonly property real strideLength: GaitLib.strideLength(_cycle.table, entity.legHeight,
                                                              _cycle._upperRatio)

    // Thigh share of the leg, for the ankle's travel; 0.5 when the entity
    // does not say (a stub, or a body built before the ratio existed).
    readonly property real _upperRatio: (entity && entity.legUpperRatio !== undefined)
                                        ? entity.legUpperRatio : 0.5

    /*!
        \qmlproperty real GaitCycleAnim::lift
        \readonly
        \brief How far the figure is raised right now, in world units: up to
               \c {bounce x legHeight} at mid-step, zero at contact, and zero
               whenever the cycle is not running.
    */
    readonly property real lift: _cycle._lift
    property real _lift: 0
    readonly property real _liftPeak: _cycle.table.bounce * entity.legHeight

    onRunningChanged: if (!running) _cycle._lift = 0

    // The lift within one step: up and back down, both halves eased. The same
    // shape as gait.js liftAt(), which the cycle sheet draws from - if one
    // changes, change the other.
    component StepLift: SequentialAnimation {
        NumberAnimation {
            target: _cycle; property: "_lift"
            to: _cycle._liftPeak
            duration: Math.round(_cycle.duration / 2)
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: _cycle; property: "_lift"
            to: 0
            duration: _cycle.duration - Math.round(_cycle.duration / 2)
            easing.type: Easing.InOutQuad
        }
    }

    // One step. `lead` is the leg swinging forward this phase and `trail` the
    // one pushing back; the arms oppose their legs. Sign conventions are the
    // joints' own: positive x pitches forward and down, so a forward limb is
    // negative x. Sway is a hip yaw with the torso countering by half, rock a
    // torso roll over the planted leg; `s` flips both between the phases.
    component Step: ParallelAnimation {
        id: _step
        required property var lead
        required property var trail
        required property var leadArm
        required property var trailArm
        required property real s

        // Posture: lean and head hold, sway and rock alternate.
        EulerAnim {
            target: entity.torso
            duration: _cycle.duration
            to: Qt.vector3d(_cycle.table.lean,
                            _cycle.table.sway * 0.5 * _step.s,
                            _cycle.table.rock * _step.s)
        }
        // The hip hangs off the torso, so it counters the waist share of the
        // lean - legs stay planted while the chest tips - and carries the sway.
        EulerAnim {
            target: entity.hip
            duration: _cycle.duration
            to: Qt.vector3d(-_cycle.table.waistLean, -_cycle.table.sway * _step.s, 0)
        }
        HeadEulerAnim {
            target: entity.head
            duration: _cycle.duration
            to: Qt.vector3d(_cycle.table.headPitch, 0, 0)
        }
        // Hands back to rest (e.g. tilted by UseAnim/FightAnim)
        EulerAnim {
            target: entity.rightArm.hand
            duration: _cycle.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.hand
            duration: _cycle.duration
            to: Qt.vector3d(0, 0, 0)
        }

        // The leg swinging forward. The hips move LINEARLY, both legs: the
        // planted foot must travel under the body at the body's own speed,
        // and an eased hip parks it at the ends of the step and rushes it
        // through the middle, which is the skating this cycle used to have.
        // Knees and feet keep their ease; they shape the swing, not the
        // contact.
        EulerAnim {
            target: _step.lead.upperLeg
            duration: _cycle.duration
            easing.type: Easing.Linear
            from: Qt.vector3d(_cycle.table.hipBack, 0, 0)
            to: Qt.vector3d(-_cycle.table.hipFwd, 0, 0)
        }
        EulerAnim {
            target: _step.lead.lowerLeg
            duration: _cycle.duration
            from: Qt.vector3d(_cycle.table.kneeLift, 0, 0)
            to: Qt.vector3d(_cycle.table.kneeExtend, 0, 0)
        }
        EulerAnim {
            target: _step.lead.foot
            duration: _cycle.duration
            from: Qt.vector3d(_cycle.table.footDown, 0, 0)
            to: Qt.vector3d(-_cycle.table.footUp, 0, 0)
        }

        // The leg pushing back
        EulerAnim {
            target: _step.trail.upperLeg
            duration: _cycle.duration
            easing.type: Easing.Linear
            from: Qt.vector3d(-_cycle.table.hipFwd, 0, 0)
            to: Qt.vector3d(_cycle.table.hipBack, 0, 0)
        }
        EulerAnim {
            target: _step.trail.lowerLeg
            duration: _cycle.duration
            from: Qt.vector3d(_cycle.table.kneeExtend, 0, 0)
            to: Qt.vector3d(_cycle.table.kneeLift, 0, 0)
        }
        EulerAnim {
            target: _step.trail.foot
            duration: _cycle.duration
            from: Qt.vector3d(-_cycle.table.footUp, 0, 0)
            to: Qt.vector3d(_cycle.table.footDown, 0, 0)
        }

        // The arm on the leading leg's side goes back
        EulerAnim {
            target: _step.leadArm.upperArm
            duration: _cycle.duration
            from: Qt.vector3d(-_cycle.table.armFwd, 0, 0)
            to: Qt.vector3d(_cycle.table.armBack, 0, 0)
        }
        EulerAnim {
            target: _step.leadArm.lowerArm
            duration: _cycle.duration
            from: Qt.vector3d(-_cycle.table.elbow, 0, 0)
            to: Qt.vector3d(-_cycle.table.elbow, 0, 0)
        }

        // The arm on the trailing leg's side comes forward
        EulerAnim {
            target: _step.trailArm.upperArm
            duration: _cycle.duration
            from: Qt.vector3d(_cycle.table.armBack, 0, 0)
            to: Qt.vector3d(-_cycle.table.armFwd, 0, 0)
        }
        EulerAnim {
            target: _step.trailArm.lowerArm
            duration: _cycle.duration
            from: Qt.vector3d(-_cycle.table.elbow, 0, 0)
            to: Qt.vector3d(-_cycle.table.elbow, 0, 0)
        }

        StepLift {}
    }

    // Phase 1: right leg forward, left leg back
    Step {
        lead: entity.rightLeg; trail: entity.leftLeg
        leadArm: entity.rightArm; trailArm: entity.leftArm
        s: 1
    }

    // Phase 2: left leg forward, right leg back
    Step {
        lead: entity.leftLeg; trail: entity.rightLeg
        leadArm: entity.leftArm; trailArm: entity.rightArm
        s: -1
    }
}
