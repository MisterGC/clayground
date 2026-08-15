import QtTest 1.2
import QtQuick
import Clayground.World

TestCase {
    name: "WorldSmoke"

    // ClayWorldBase::components is required, so a world that gets none fails
    // before it reaches any of its own code - the smoke check has to hand one
    // over.
    function test_canInstantiateWorld2d() {
        var obj = Qt.createQmlObject(
            'import Clayground.World; ClayWorld2d { components: new Map() }', parent)
        verify(obj !== null)
        obj.destroy()
    }

    function test_canInstantiateWorld3d() {
        var obj = Qt.createQmlObject(
            'import Clayground.World; ClayWorld3d { components: new Map() }', parent)
        verify(obj !== null)
        obj.destroy()
    }
}
