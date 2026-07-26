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
        \brief What the learner must do: \c {{until, hint, hintAfter, solve}}.

        \c until is a predicate receiving a name lookup function and returning
        true once the step is satisfied; \c solve is an action list that
        performs it (used by "show me" and by the headless verification run).
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
        \qmlproperty var FlowStep::expect
        \brief Optional predicate asserted after the step, for headless checks.
    */
    property var expect: null
}
