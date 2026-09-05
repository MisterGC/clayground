// (c) Clayground Contributors - MIT License, see "LICENSE" file
// SPIKE (lab-flows groundwork, awaiting review): shape may still change.

import QtQuick

/*!
    \qmltype FlowStep
    \inqmlmodule Clayground.Lab
    \brief One stop of a lab Flow: what is said, what the lab does, what the learner does.

    A step is either a demonstration (\l demo runs, the learner watches), a
    task (\l task waits for the learner) or narration only.

    \sa Flow
*/
QtObject {
    /*!
        \qmlproperty string FlowStep::key
        \brief Stable step name; also the narration key suffix.

        The narration is looked up as \c {flow.<flowId>.<key>} in \l LabLang,
        which is what makes a flow translatable. \l say is the fallback.
    */
    property string key: ""

    /*!
        \qmlproperty string FlowStep::say
        \brief Narration text, used when no dictionary entry exists for \l key.
    */
    property string say: ""

    /*!
        \qmlproperty var FlowStep::demo
        \brief Actions the lab performs on entering, as \c {[[verb, args...], ...]}.

        Verbs are resolved against the lab's \c flowActions() map. The form
        \c {["let", "name", verb, args...]} binds the verb's return value to a
        flow-local name usable as an argument in later actions.
    */
    property var demo: []

    /*!
        \qmlproperty var FlowStep::task
        \brief What the learner must do: \c {{until, allow, hint, hintAfter, solve}}.

        \c until is a predicate receiving a name lookup function and returning
        true once the step is satisfied; \c solve is an action list that
        performs it (used by "show me" and by the headless verification run).

        \c allow is what the task hands over: the parts the learner may touch
        while it runs, named the way \c until and \c solve name them
        (\c {"allow": ["sw"]}), everything else on the board being inert until
        the task is done. A step whose subject is whatever the preset it just
        applied put there names it with a function of the same name lookup
        instead (\c {"allow": (n) => root.logicInputs}). Leaving it out keeps
        the whole board live, which is what a flow written before
        \l {Flow::control} existed still gets.
    */
    property var task: null

    /*!
        \qmlproperty var FlowStep::watch
        \brief Wait for the simulation, as \c {{until}}.

        The sibling of \l task for continuous labs: nothing is asked of the
        learner, the step simply ends when the world reaches a state ("the car
        enters the tunnel", "sigma passes 2 m"). Same predicate, different
        promise - so the narrator says "watching" rather than "your turn".
    */
    property var watch: null

    /*!
        \qmlproperty var FlowStep::dwell
        \brief Sim seconds to linger, or "auto" to estimate from reading time.
    */
    property var dwell: "auto"

    /*!
        \qmlproperty var FlowStep::view
        \brief Where the camera should be for this step. Null leaves it alone.

        A narrated step that talks about the far corner of the board while the
        camera is still on the near one teaches nothing, and moving it from a
        \l demo verb means every lab has to invent that verb. Three forms, all
        applied \e after the demo has run, so a step can frame what it just
        built:

        \list
        \li \c {{ viewpoint: "top" }} - a name from
            \c {OrbitCamera3D.viewpoints};
        \li \c {{ focus: [points], pad: 1.3 }} - frame these world points, or
            a single point to re-centre on it;
        \li \c {{ pose: {yaw, pitch, distance, px, py, pz} }} - a literal pose,
            as \c {OrbitCamera3D.state()} spells one.
        \endlist

        Add \c {ms:} to any of them to set the travel time. Applied only when
        the \l Flow has a \c camera; a flow without one ignores the property
        entirely, which is what keeps it non-breaking.
    */
    property var view: null

    /*!
        \qmlproperty var FlowStep::expect
        \brief Optional predicate asserted after the step, for headless checks.
    */
    property var expect: null
}
