// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Canvas 1.0
import Clayground.Physics 1.0
import Clayground.Common 1.0

ClayCanvas
{
    id: _world

    // GENERAL/SANDBOX
    property string map: ""
    property alias loadMapAsync: mapLoader.loadEntitiesAsync

    property alias room: _world.coordSys
    property alias running: _physicsWorld.running
    property alias xWuMin: _world.worldXMin
    property alias xWuMax: _world.worldXMax
    property alias yWuMin: _world.worldYMin
    property alias yWuMax: _world.worldYMax

    Component.onCompleted: { _moveToRoomOnDemand(); childrenChanged.connect(_moveToRoomOnDemand);}
    Connections{target: room; function onChildrenChanged(){_updateRoomContent();}}


    // PHYSICS
    property World physics: _physicsWorld
    property bool physicsDebugging: false
    property alias gravity: _physicsWorld.gravity
    property alias timeStep: _physicsWorld.timeStep
    property alias physicsEnabled: _physicsWorld.running
    World {
        id: _physicsWorld
        gravity: Qt.point(0,15*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
        running: true
    }
    Component { id: _physDebug; DebugDraw {parent: coordSys; world: _physicsWorld }}
    Loader { sourceComponent: physicsDebugging ? _physDebug : null }


    // MAP LOADING
    readonly property string _fullmappath: (map.length === 0 ? ""
        : ((!Clayground.runsInSandbox ? ":/" : ClayLiveLoader.sandboxDir) + "/" + map))
    property alias components: mapLoader.components
    MapLoader {
        id: mapLoader;
        world: _world;
        onLoaded: world.mapLoaded()
    }

    onWidthChanged: _refreshMap()
    on_FullmappathChanged: _refreshMap()

    function _refreshMap() {
        if (width > 0 || height > 0) {
            mapLoader.setSource("");
            mapLoader.setSource(_fullmappath);
        }
    }
    onMapLoaded: _updateRoomContent()

    // Signals informing about the loading process
    signal mapAboutToBeLoaded()
    signal mapLoaded()
    signal mapEntityCreated(var obj, var groupId, var compName)

    // All elements that haven't been instantiated via registred comp.
    signal polylineLoaded(var id, var groupId, var points, var description)
    signal polygonLoaded(var id, var groupId, var points, var description)
    signal rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var description)
    signal circleLoaded(var id, var groupId, var x, var y, var radius, var description)
    signal groupAboutToBeLoaded(var id, var description)
    signal groupLoaded()


    function _moveToRoomOnDemand() {
        if (!_world) return;
        _forEachElement(_world.children,
                        (obj) => {
                            let migrate = obj instanceof RectBoxBody  ||
                            obj instanceof VisualizedPolyBody ||
                            obj instanceof ImageBoxBody  ||
                            obj instanceof PhysicsItem
                            if (migrate) {
                                _updatePropertyBindingsOnDemand(obj);
                                obj.parent = _world.room;
                            }
                        }
                        );
    }

    function _updateRoomContent() {
        if (!_world) return;
        _forEachElement(_world.room.children, _updatePropertyBindingsOnDemand);
    }

    function _updatePropertyBindingsOnDemand(obj){
        if ("pixelPerUnit" in obj)
            obj.pixelPerUnit = Qt.binding( _ => {return _world.pixelPerUnit;} );
        if ("world" in obj)
            obj.world = Qt.binding( _ => {return _world.physics;} );
    }

    function _forEachElement(objs, func){
        for (let i=0; i<objs.length; ++i){
            let o = objs[i];
            if (o) func(o);
        }
    }

}
