// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Clayground.Physics 1.0
import Clayground.World 1.0
import Box2D 2.0

Item
{
    id: builder

    required property ClayWorld world

    // Build a more complex object (automated door) based on groups in the map
    property bool _active: false
    property var _door: null
    property var _doorPath: []
    property var _switches: []

    readonly property string _doorCompName: 'Door'
    readonly property string _switchCompName: 'DoorOpener'

    Component.onCompleted: {
        world.components.set(_doorCompName, _doorComp);
        world.components.set(_switchCompName, _doorSwitchComp);
    }

    Connections{
        target: world
        function onGroupAboutToBeLoaded(id, desc) {
            builder._active = id.startsWith("door");
            _door = null;
            _doorPath = [];
            _switches = [];
        }
        function onMapEntityCreated(obj, compName) {
            if (!builder._active) return;
            if (compName === builder._doorCompName) _door = obj;
            if (compName === builder._switchCompName) _switches.push(obj);
        }
        function onPolylineLoaded(id, points, desc) {if (builder._active) _doorPath = points;}
        function onGroupLoaded() {
            if (!builder._active) return;
            _door.path = _doorPath;
            for (let s of _switches) s.door = _door;
            builder._active = false;
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
            onEntered: {door.idx = 1; closeTimer.restart(); entity.openDoorAction.start();}
            Timer{id: closeTimer; interval: 2500; onTriggered: door.idx = 0;}
        }
    }

}
