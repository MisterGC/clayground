// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Canvas 1.0
import Clayground.Physics 1.0
import Clayground.Common 1.0

ClayCanvas
{
    id: _world
    property var components: new Map()

    // General/Sandbox Mode
    property alias room: coordSys
    property string map: ""
    readonly property string _fullmappath: (map.length === 0 ? ""
        : ((!Clayground.runsInSandbox ? ":/" : ClayLiveLoader.sandboxDir) + "/" + map))

    property alias running: _physicsWorld.running

    // Physics
    property World physics: _physicsWorld
    property bool physicsDebugging: false
    property alias gravity: _physicsWorld.gravity
    property alias timeStep: _physicsWorld.timeStep
    property alias physicsEnabled: _physicsWorld.running

    signal worldAboutToBeCreated()
    signal worldCreated()
    signal objectCreated(var obj, var compName)

    // Signals which are emitted when elements have
    // been loaded which are not yet processed by
    // ClayWorld functionality
    signal polylineLoaded(var points, var description)
    signal polygonLoaded(var points, var description)
    signal rectangleLoaded(var x, var y, var width, var height, var description)
    signal circleLoaded(var x, var y, var radius, var description)

    onWidthChanged: _refreshMap();
    on_FullmappathChanged: _refreshMap();

    function _refreshMap() {
        if (width > 0 || height > 0) {
            mapLoader.setSource(_fullmappath);
            _createdNotify.start();
        }
    }

    Timer {id: _createdNotify; interval: 10; onTriggered: _world.worldCreated()}

    World {
        id: _physicsWorld
        gravity: Qt.point(0,15*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
        running: _world.running
    }
    Component { id: _physDebug; DebugDraw {parent: coordSys; world: _physicsWorld }}
    Loader { sourceComponent: physicsDebugging ? _physDebug : null }

    Component.onCompleted: { _syncTimer.start();}

    Timer {id: _syncTimer; interval: 50; onTriggered: {
            _world.childrenChanged.connect(_moveToRoomOnDemand);
            _world.room.childrenChanged.connect(_updateRoomContent);
            _moveToRoomOnDemand(); }
    }

    function _bindRoomPropertiesOnDemand(obj){
        if ('pixelPerUnit' in obj)
            obj.pixelPerUnit = Qt.binding( _ => {return _world.pixelPerUnit;} );
        if ('world' in obj)
            obj.world = Qt.binding( _ => {return _world.physics;} );
    }

    function _moveToRoomOnDemand() {
        if (!_world) return;
        for (let i=1; i< _world.children.length; ++i){
            let o = _world.children[i];
            // Skip object that may be already destroyed
            if (!o) continue;
            let migrate = o instanceof RectBoxBody  ||
                o instanceof VisualizedPolyBody ||
                o instanceof ImageBoxBody  ||
                o instanceof PhysicsItem
            if (migrate){
                _bindRoomPropertiesOnDemand(o);
                o.parent = _world.room;
            }
        }
    }

    function _updateRoomContent() {
        if (!_world) return;
        let children = _world.room.children;
        for (let i=1; i< children.length; ++i){
            let o = children[i];
            // Skip object that may be already destroyed
            if (!o) continue;
            _bindRoomPropertiesOnDemand(o);
        }
    }

    MapLoader {id: mapLoader; world: _world}
}
