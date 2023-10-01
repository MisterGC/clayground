// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Canvas
import Clayground.Physics
import Clayground.Common

ClayWorldBase
{
    id: _world
    anchors.fill: parent

    // GENERAL PROPERTIES
    readonly property ClayCanvas canvas: _theCanvas
    property alias room: _theCanvas.coordSys
    property alias running: _physicsWorld.running
    property alias xWuMin: _theCanvas.worldXMin
    property alias xWuMax: _theCanvas.worldXMax
    property alias yWuMin: _theCanvas.worldYMin
    property alias yWuMax: _theCanvas.worldYMax

    property alias pixelPerUnit: _theCanvas.pixelPerUnit
    property alias viewPortCenterWuX: _theCanvas.viewPortCenterWuX
    property alias viewPortCenterWuY: _theCanvas.viewPortCenterWuY

    property alias observedItem: _theCanvas.observedItem


    // MAP LOADING
    _sceneLoader: SceneLoader2d {
        id: _sceneLoader2d
        loadEntitiesAsync: _world.loadMapAsync
        world: _world
     }
    // true -> entities get loaded without block UI
    // already in base
    //property alias loadMapAsync: _sceneLoader2d.loadEntitiesAsync
    // Base z-coord that is used when loading entities from the map
    property alias baseZCoord: _sceneLoader2d.baseZCoord
    property alias lastZCoord: _sceneLoader2d.lastZCoord

    // PHYSICS
    property alias physics: _physicsWorld
    property alias gravity: _physicsWorld.gravity
    property alias timeStep: _physicsWorld.timeStep
    property alias physicsEnabled: _physicsWorld.running

    ClayCanvas {
        id: _theCanvas

        showDebugInfo: _world.debugRendering
        anchors.fill: parent
        Component { id: _physDebug; DebugDraw {parent: _theCanvas.coordSys; world: _physicsWorld }}
        Loader { sourceComponent: debugPhysics ? _physDebug : null }

        World {
            id: _physicsWorld
            gravity: Qt.point(0,15*9.81)
            timeStep: 1/60.0
            pixelsPerMeter: _theCanvas.pixelPerUnit
            running: true
        }
    }

    Component.onCompleted: {_moveToRoomOnDemand(); childrenChanged.connect(_moveToRoomOnDemand); _loadActive.restart();}
    Timer {id: _loadActive; interval: 1; onTriggered: _sceneLoader2d.active = true;}
    Connections{target: room; function onChildrenChanged(){_updateRoomContent();}}

    // MAP LOADING
    onMapLoaded: _updateRoomContent()

    function _moveToRoomOnDemand() {
        if (!_world) return;
        for (let obj of _world.children) {
            let migrate = obj instanceof RectBoxBody  ||
                obj instanceof VisualizedPolyBody ||
                obj instanceof ImageBoxBody  ||
                obj instanceof PhysicsItem;

            if (migrate) {
                _updatePropertyBindingsOnDemand(obj);
                obj.parent = _world.room;
            }
        }
    }

    function _updateRoomContent() {
        if (!_world) return;
        _world.room.children.forEach(_updatePropertyBindingsOnDemand);
    }

    function _updatePropertyBindingsOnDemand(obj){
        if ("pixelPerUnit" in obj)
            obj.pixelPerUnit = Qt.binding( _ => {return _theCanvas.pixelPerUnit;} );
        if ("world" in obj)
            obj.world = Qt.binding( _ => {return _world.physics;} );
    }
}

