// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ModelState
    \inqmlmodule Clayground.Lab
    \ingroup lab-kernel
    \brief The part of a lab's state only its model knows, for Lab.snapshot().

    \l Lab::snapshot() holds the clock, the random numbers, the parameters and
    the probe samples by itself. What it cannot know is what the model has
    built up while time ran - the cars on the roads, the filter's estimate, a
    sensor's next due time. A ModelState hands that over: one per object that
    keeps such state, auto-registered with Lab like a \l Probe.

    Two ways to say what the state is. A \l target with a list of
    \l properties is enough for an object whose state is a few of its own
    properties:

    \qml
    import Clayground.Lab

    ModelState {
        name: "odometry"; target: odo
        properties: ["estX", "estY", "headingErr", "_lastT", "_lastTrue"]
    }
    \endqml

    A model held in one plain object, or one that has to rebuild something
    when its state comes back, gives \l save and \l load instead:

    \qml
    ModelState {
        name: "traffic"
        save: () => ({ plan: root.planState(), sim: root.simState })
        load: (s) => { root.loadPlan(s.plan); root.simState = s.sim }
    }
    \endqml

    The state must be plain data: numbers, strings, booleans, null, arrays
    and objects of them - what survives being written to a file. A snapshot
    copies it, so \l save may return the live object, and \l load is handed a
    copy of its own that it may keep. A property listed in \l properties that
    is bound loses its binding when the state comes back; list only
    properties the model assigns.

    \sa Lab::snapshot, Lab::restore
*/
QtObject {
    id: _state

    /*!
        \qmlproperty string ModelState::name
        \brief Unique name the state is filed under in a snapshot.

        A snapshot restores into a lab only when that lab offers the same
        names, so name what the state is of ("traffic", "gps"), not where it
        happens to live.
    */
    property string name: ""

    /*!
        \qmlproperty QtObject ModelState::target
        \brief The object whose \l properties are the state.
    */
    property var target: null

    /*!
        \qmlproperty list<string> ModelState::properties
        \brief Names of \l target's properties that make up the state.
    */
    property var properties: []

    /*!
        \qmlproperty var ModelState::save
        \brief Function returning the state as plain data; overrides \l properties.
    */
    property var save: null

    /*!
        \qmlproperty var ModelState::load
        \brief Function taking what \l save returned and putting it back.
    */
    property var load: null

    function _save() {
        if (typeof save === "function") return save()
        const out = {}
        if (target) for (const p of properties) out[p] = target[p]
        return out
    }

    function _load(s) {
        if (typeof load === "function") { load(s); return }
        if (!target || !s) return
        for (const p of properties) if (p in s) target[p] = s[p]
    }

    Component.onCompleted: Lab.registerModelState(_state)
    Component.onDestruction: Lab.unregisterModelState(_state)
}
