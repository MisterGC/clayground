// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import "animation/gait.js" as GaitLib

/*!
    \qmltype Gait
    \inqmlmodule Clayground.Character3D
    \inherits QtObject
    \brief How a character walks and runs: a named preset, thirteen factors, or both.

    Every factor is 1 (the multiplicative ones) or 0 (the additive ones) at
    neutral, and a neutral Gait is the walk and run the framework always had.
    A preset is a factor vector chosen by name; the factors set here compose
    with it rather than replace it, so this

    \qml
    Character {
        gait: Gait { preset: "elderly"; tempo: 1.2 }
    }
    \endqml

    is "elderly, a fifth quicker" and reads that way. The result composes once
    more, on the character, with what its build and its emotion say - see
    \l {Character::gaitFactors}.

    Amplitudes are expressive rather than measured, and clamped: no
    combination of preset, factors, build and mood folds a knee backwards or
    stops the legs.

    \sa Character::gait, Character::gaitFactors, ParametricCharacter
*/
QtObject {
    id: _gait

    /*!
        \qmlproperty string Gait::preset
        \brief A gait by name, or empty for none.

        Shipped: \c neutral, \c cheerful, \c dejected, \c furious, \c elderly,
        \c toddler, \c heavy, \c sneak, \c proud, \c march. The first three are
        exactly what the emotions of the same mood do to a walk, so a preset
        and a \l {Character::setEmotion}{setEmotion()} cannot disagree. A name
        that is not in the list does nothing and clears \l presetKnown.
    */
    property string preset: ""

    /*!
        \qmlproperty bool Gait::presetKnown
        \readonly
        \brief False while \l preset names something the table does not have.
    */
    readonly property bool presetKnown: GaitLib.presetKnown(_gait.preset)

    /*!
        \qmlproperty list Gait::presetNames
        \readonly
        \brief Every name \l preset accepts, for a picker.
    */
    readonly property var presetNames: GaitLib.PRESET_NAMES

    /*! \qmlproperty real Gait::tempo
        \brief Cadence. 1 is as authored; 1.2 takes steps a fifth quicker
               and covers ground a fifth faster, since speed follows the feet. */
    property real tempo: 1

    /*! \qmlproperty real Gait::stride
        \brief How far the legs swing. 1 is as authored; below it shortens
               the step and the speed with it. */
    property real stride: 1

    /*! \qmlproperty real Gait::bounce
        \brief How high the whole figure rises at mid-step, as a fraction of
               leg height. 0 is flat, 0.05 is a visible spring, 0.1 the cap. */
    property real bounce: 0

    /*! \qmlproperty real Gait::lean
        \brief Torso pitch in degrees on top of the cycle's own. Positive
               leans forward (a slump, a charge), negative back (chest out).
               Bends at the waist: the hip counters it, so the legs stay
               planted and only belly, chest, head and arms tip. It is shared
               between the two trunk segments and brings a little curve with
               it; \l spineCurve asks for more. */
    property real lean: 0

    /*!
        \qmlproperty real Gait::spineCurve
        \brief How round the back is, in degrees: the angle between belly and
               chest at the waist joint. Positive rounds it forward (sad,
               elderly, sneaking), negative arches it and lifts the chest
               (proud, marching).

        Differential, not a tilt: it bends the belly back by as much as it
        bends the chest forward, so it changes the SHAPE of the trunk without
        moving where the head ends up. That is \l lean's job, and the two are
        meant to be used together - a slump is both.
    */
    property real spineCurve: 0

    /*! \qmlproperty real Gait::headPitch
        \brief Head pitch in degrees. Positive looks down, negative lifts
               the chin. */
    property real headPitch: 0

    /*! \qmlproperty real Gait::armSwing
        \brief Arm swing amplitude. 1 is as authored, 0 hangs the arms. */
    property real armSwing: 1

    /*! \qmlproperty real Gait::armForward
        \brief Degrees the whole arm swing is carried ahead of the body:
               more reach in front, less behind, the same amplitude. Bent
               elbows plus this is fists pumping before the chest. */
    property real armForward: 0

    /*!
        \qmlproperty real Gait::armOut
        \brief How far the upper arms are carried out from the ribs, in
               degrees. 0 hangs them against the body.

        Held through the cycle rather than alternating with it - a carriage,
        not a movement - and signed by the side, so both arms go outward. It
        is what separates a walk with somewhere to be from one ready to hit
        something, and it only reads head-on: a profile cannot see it.
    */
    property real armOut: 0

    /*! \qmlproperty real Gait::elbow
        \brief Elbow bend in degrees on top of the cycle's own (a walk bends
               10, a run 70). Bent elbows with a quick tempo read as fists
               pumping. */
    property real elbow: 0

    /*! \qmlproperty real Gait::kneeLift
        \brief Knee lift. 1 is as authored; below it drags the feet, above
               it high-steps. The foot angles follow it. */
    property real kneeLift: 1

    /*! \qmlproperty real Gait::sway
        \brief Hip yaw in degrees, alternating with the step, the torso
               countering by half. 0 is none. */
    property real sway: 0

    /*! \qmlproperty real Gait::rock
        \brief Torso roll in degrees over the planted leg, alternating with
               the step - the side-to-side shift of weight. 0 is none. */
    property real rock: 0

    /*!
        \qmlproperty var Gait::factors
        \readonly
        \brief The preset and the factors above composed into one clamped
               factor vector - this object's whole contribution to a gait.
    */
    readonly property var factors: GaitLib.compose([
        GaitLib.presetFactors(_gait.preset),
        {
            tempo: _gait.tempo, stride: _gait.stride, bounce: _gait.bounce,
            lean: _gait.lean, spineCurve: _gait.spineCurve,
            headPitch: _gait.headPitch, armSwing: _gait.armSwing,
            armForward: _gait.armForward, armOut: _gait.armOut,
            elbow: _gait.elbow, kneeLift: _gait.kneeLift, sway: _gait.sway,
            rock: _gait.rock
        }
    ])
}
