import QtTest 1.2
import QtQuick
import Clayground.World

TestCase {
    name: "WorldSmoke"

    function test_canInstantiateWorld2d() {
        var obj = Qt.createQmlObject('import Clayground.World; ClayWorld2d {}', parent)
        verify(obj !== null)
        obj.destroy()
    }

    function test_canInstantiateWorld3d() {
        var obj = Qt.createQmlObject('import Clayground.World; ClayWorld3d {}', parent)
        verify(obj !== null)
        obj.destroy()
    }
}
