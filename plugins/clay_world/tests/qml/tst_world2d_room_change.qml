// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtTest 1.2
import QtQuick
import Clayground.World

// A room change destroys the room's children and fills it again. Every change
// of room.children re-wires pixelPerUnit and world on what is in the room, and
// that must neither stumble over a child on its way out (#335) nor lose the
// bindings of the children that stay.
TestCase {
    id: testCase
    name: "World2dRoomChange"
    when: windowShown

    Component {
        id: worldComp
        ClayWorld2d { components: new Map(); width: 400; height: 300 }
    }

    Component {
        id: childComp
        Item {
            property real pixelPerUnit: 0
            property var world: null
        }
    }

    // An entity that puts a part of itself into the room beside it, as a
    // trail or a shadow does. QML marks that part as deleted together with
    // the entity, before the entity leaves the room - for that moment the
    // room's children list holds an entry that reads as null.
    Component {
        id: entityComp
        Item {
            id: entity
            property real pixelPerUnit: 0
            property var world: null
            Item { parent: entity.parent }
        }
    }

    function test_rebuildingTheRoomLogsNoTypeError() {
        failOnWarning(/TypeError/)
        let world = createTemporaryObject(worldComp, testCase)
        verify(world)
        let before = world.room.children.length
        let survivor = childComp.createObject(world.room)
        let leaving = []
        for (let i = 0; i < 3; ++i)
            leaving.push(childComp.createObject(world.room))
        for (let i = 0; i < 2; ++i)
            leaving.push(entityComp.createObject(world.room))
        // each entity brings its part along
        compare(world.room.children.length, before + 8)

        // The rebuild: the old children go, new ones come in their place.
        leaving.forEach(c => c.destroy())
        wait(0)
        compare(world.room.children.length, before + 1)
        let arriving = []
        for (let i = 0; i < 5; ++i)
            arriving.push(childComp.createObject(world.room))
        compare(world.room.children.length, before + 6)

        // The child that stayed keeps both bindings: they follow the world.
        verify(survivor.pixelPerUnit > 0)
        compare(survivor.world, world.physics)
        world.pixelPerUnit = world.pixelPerUnit * 2
        compare(survivor.pixelPerUnit, world.pixelPerUnit)
        arriving.forEach(c => compare(c.pixelPerUnit, world.pixelPerUnit))
        arriving.forEach(c => compare(c.world, world.physics))
    }
}
