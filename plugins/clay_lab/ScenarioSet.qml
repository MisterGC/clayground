// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ScenarioSet
    \inqmlmodule Clayground.Lab
    \brief Declarative collection of scenarios wiring the scenarios()/applyScenario() convention.

    Delegate the sandbox root's convention functions to this set:
    \qml
    import Clayground.Lab

    ScenarioSet {
        id: scenarioSet
        Scenario { name: "tower"; script: () => buildTower() }
        Scenario { name: "rain"; script: () => spawnRain() }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }
    \endqml

    Applying a scenario resets the SimClock first (seeded randomness
    restarts), which is what makes scenario runs reproducible.

    \sa Scenario, SimClock
*/
QtObject {
    id: _set

    /*!
        \qmlproperty list<Scenario> ScenarioSet::scenarios
        \brief The scenarios (default property).
    */
    default property list<Scenario> scenarios

    /*!
        \qmlmethod var ScenarioSet::names()
        \brief Names of all scenarios, for the scenarios() convention.
    */
    function names() {
        const r = []
        for (let i = 0; i < scenarios.length; ++i) r.push(scenarios[i].name)
        return r
    }

    /*!
        \qmlmethod bool ScenarioSet::apply(string name)
        \brief Resets the clock and runs the named scenario's script.
    */
    function apply(name) {
        for (let i = 0; i < scenarios.length; ++i) {
            const s = scenarios[i]
            if (s.name !== name) continue
            if (Lab.clock) Lab.clock.reset()
            if (s.script) s.script()
            Lab.scenario = name
            return true
        }
        console.warn("ScenarioSet: unknown scenario " + name)
        return false
    }
}
