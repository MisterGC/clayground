// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorld2d
    \inqmlmodule Clayground.World
    \inherits ClayWorldBase
    \brief Complete 2D game world with physics, rendering, and scene loading.

    ClayWorld2d integrates ClayCanvas for rendering, Box2D for physics, and
    SVG-based scene loading into a single component. Physics bodies added as
    children are automatically parented to the room and configured.

    Example usage:
    \qml
    import Clayground.World
    import Clayground.Physics

    ClayWorld2d {
        anchors.fill: parent
        xWuMax: 100; yWuMax: 50
        gravity: Qt.point(0, 10)
        observedItem: player

        RectBoxBody {
            id: player
            xWu: 10; yWu: 10
            widthWu: 2; heightWu: 2
            bodyType: Body.Dynamic
        }
    }
    \endqml

    \qmlproperty ClayCanvas ClayWorld2d::canvas
    \readonly
    \brief The rendering canvas.

    \qmlproperty Item ClayWorld2d::room
    \brief Container for all world entities.

    \qmlproperty bool ClayWorld2d::running
    \brief Whether physics simulation is running.

    \qmlproperty real ClayWorld2d::xWuMin
    \brief Minimum X coordinate in world units.

    \qmlproperty real ClayWorld2d::xWuMax
    \brief Maximum X coordinate in world units.

    \qmlproperty real ClayWorld2d::yWuMin
    \brief Minimum Y coordinate in world units.

    \qmlproperty real ClayWorld2d::yWuMax
    \brief Maximum Y coordinate in world units.

    \qmlproperty real ClayWorld2d::pixelPerUnit
    \brief Pixels per world unit for rendering.

    \qmlproperty real ClayWorld2d::viewPortCenterWuX
    \brief Viewport center X in world units.

    \qmlproperty real ClayWorld2d::viewPortCenterWuY
    \brief Viewport center Y in world units.

    \qmlproperty var ClayWorld2d::observedItem
    \brief Item the camera follows.

    \qmlproperty World ClayWorld2d::physics
    \brief The Box2D physics world.

    \qmlproperty point ClayWorld2d::gravity
    \brief Gravity vector for physics.

    \qmlproperty real ClayWorld2d::timeStep
    \brief Physics simulation timestep.

    \qmlproperty bool ClayWorld2d::physicsEnabled
    \brief Whether physics is enabled.

    \qmlproperty real ClayWorld2d::baseZCoord
    \brief Base Z coordinate for loaded entities.

    \qmlproperty real ClayWorld2d::lastZCoord
    \brief Last used Z coordinate.
*/
import QtQuick
import Box2D
import Clayground.Canvas
import Clayground.Physics
import Clayground.Common

ClayWorldBase
{
    id: _world

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
            pixelsPerMeter: _theCanvas.pixelPerUnit ? _theCanvas.pixelPerUnit : 1
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

