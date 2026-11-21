// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Applying a scenario is what makes a scenario run reproducible: it resets
// the clock - time and the random stream - before the scenario's script runs
// (#532).

import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 50; height: 50

    SimClock { id: clock; seed: 11; timeScale: 0 }

    property var drawnInScript: []

    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "tstCalm"
            script: () => {
                root.drawnInScript = [clock.time, clock.random(), clock.random()]
            }
        }
        Scenario { name: "tstStorm"; script: () => clock.random() }
    }

    TestCase {
        name: "ScenarioSet"

        function test_namesInDeclarationOrder() {
            compare(scenarioSet.names(), ["tstCalm", "tstStorm"])
        }

        function test_applyResetsClockAndRandomNumbers() {
            verify(scenarioSet.apply("tstCalm"))
            const fresh = root.drawnInScript.slice()
            compare(fresh[0], 0, "the script runs on a clock at time 0")

            // run on: time passes, the stream moves on
            clock._advance(2.5)
            clock.random(); clock.random(); clock.random()

            verify(scenarioSet.apply("tstCalm"))
            compare(root.drawnInScript, fresh,
                    "the second application saw the same time and the same numbers")
            compare(Lab.scenario, "tstCalm")
        }

        function test_otherScenarioIsNamed() {
            verify(scenarioSet.apply("tstStorm"))
            compare(Lab.scenario, "tstStorm")
            compare(clock.time, 0)
        }

        function test_unknownNameWarnsAndChangesNothing() {
            verify(scenarioSet.apply("tstCalm"))
            clock._advance(1)
            ignoreWarning(/ScenarioSet: unknown scenario tstNowhere/)
            verify(!scenarioSet.apply("tstNowhere"))
            compare(clock.time, 1, "an unknown name does not reset the clock")
            compare(Lab.scenario, "tstCalm")
        }
    }
}
