// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import Clayground.Physics
import Clayground.World
import Box2D

Item
{
    id: builder

    required property ClayWorld world

    // Build a more complex object (automated door) based on groups in the map
    property var _producedDoors: new Map()

    function _getDoor(groupId) {
        if (!_producedDoors.has(groupId)) {
            return null;
        }
        else
            return _producedDoors.get(groupId);
    }

    readonly property string _doorCompName: 'Door'
    readonly property string _switchCompName: 'DoorOpener'

    Component.onCompleted: {
        world.components.set(_doorCompName, _doorComp);
        world.components.set(_switchCompName, _doorSwitchComp);
    }

    Connections{
        target: world
        function onGroupAboutToBeLoaded(id, desc) {
            if (!id.startsWith("door")) return;
            builder._producedDoors.set(id, {
                                           _door: null,
                                           _doorPath: [],
                                           _switches: []
                                       });
        }
        function onGroupLoaded(id) {
            if (!id.startsWith("door")) return;
            let door = builder._producedDoors.get(id);
            door._door.path = door._doorPath;
            for (let s of door._switches) s.door = door._door;
        }
        function onMapEntityCreated(obj, groupId, compName) {
            let door = builder._getDoor(groupId);
            if (!door) return;
            if (compName === builder._doorCompName) door._door = obj;
            if (compName === builder._switchCompName) door._switches.push(obj);
        }
        function onPolylineLoaded(id, groupId, points, desc) {
            let door = builder._getDoor(groupId);
            if (!door) return;
            door._doorPath = points;
        }
    }

    Component {
        id: _doorComp
        RectBoxBody {
            color: "#398bbf"; z: -1
            bodyType: Body.Kinematic; friction: 0
            categories: collCat.door; collidesWith: collCat.player

            property var path: []
            property int idx: 0;  onIdxChanged: {let p = path[idx]; _b.destXWu = p.x; _b.destYWu = p.y; _b.running = true}
            MoveTo {id: _b; world: builder.world; onArrived: running = false; anchors.centerIn: parent; running: false; debug: running && world.behaviorDebug; debugColor: parent.color}
        }
    }

    Component{
        id: _doorSwitchComp
        RectTrigger{
            property var door: null
            visible: builder.world.behaviorDebug; color: "#92c0df"
            categories: collCat.door; collidesWith: collCat.npc
            onEntered: (entity) =>  {
                door.idx = 1;
                closeTimer.restart();
                entity.openDoorAction.start();}
            Timer{id: closeTimer; interval: 2500; onTriggered: door.idx = 0;}
        }
    }

}
