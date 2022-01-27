// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Canvas
import Clayground.Physics
import Clayground.Common

ClayCanvas
{
    id: _world

    // GENERAL PROPERTIES
    property alias room: _world.coordSys
    property alias running: _physicsWorld.running
    property alias xWuMin: _world.worldXMin
    property alias xWuMax: _world.worldXMax
    property alias yWuMin: _world.worldYMin
    property alias yWuMax: _world.worldYMax


    // MAP LOADING
    // Path to SVG which contains the initial world content
    property string map: ""
    // Base z-coord that is used when loading entities from the map
    property alias baseZCoord: mapLoader.baseZCoord
    property alias lastZCoord: mapLoader.lastZCoord
    // true -> entities get loaded without block UI
    property alias loadMapAsync: mapLoader.loadEntitiesAsync

    Component.onCompleted: {_moveToRoomOnDemand(); childrenChanged.connect(_moveToRoomOnDemand); _loadActive.restart();}
    Timer {id: _loadActive; interval: 1; onTriggered: mapLoader.active = true;}
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
        if (width > 0 && height > 0) {
            mapLoader.mapSource = "";
            mapLoader.mapSource = _fullmappath;
        }
    }
    onMapLoaded: _updateRoomContent()

    // Signals informing about the loading process
    signal mapAboutToBeLoaded()
    signal mapLoaded()
    signal mapEntityAboutToBeCreated(var groupId, var compName)
    signal mapEntityCreated(var obj, var groupId, var compName)

    // All elements that haven't been instantiated via registred comp.
    signal polylineLoaded(var id, var groupId, var points, var description)
    signal polygonLoaded(var id, var groupId, var points, var description)
    signal rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var description)
    signal circleLoaded(var id, var groupId, var x, var y, var radius, var description)
    signal groupAboutToBeLoaded(var id, var description)
    signal groupLoaded(var id)


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
