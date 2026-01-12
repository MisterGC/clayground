// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorld2d
    \inqmlmodule Clayground.World
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

    \sa ClayWorldBase, ClayWorld3d
*/
import QtQuick
import Box2D
import Clayground.Canvas
import Clayground.Physics
import Clayground.Common

ClayWorldBase {
    id: _world

    /*!
        \qmlproperty ClayCanvas ClayWorld2d::canvas
        \readonly
        \brief The rendering canvas.
    */
    readonly property ClayCanvas canvas: _theCanvas

    /*!
        \qmlproperty Item ClayWorld2d::room
        \brief Container for all world entities.
    */
    property alias room: _theCanvas.coordSys

    /*!
        \qmlproperty bool ClayWorld2d::running
        \brief Whether physics simulation is running.
    */
    property alias running: _physicsWorld.running

    /*!
        \qmlproperty real ClayWorld2d::xWuMin
        \brief Minimum X coordinate in world units.
    */
    property alias xWuMin: _theCanvas.worldXMin

    /*!
        \qmlproperty real ClayWorld2d::xWuMax
        \brief Maximum X coordinate in world units.
    */
    property alias xWuMax: _theCanvas.worldXMax

    /*!
        \qmlproperty real ClayWorld2d::yWuMin
        \brief Minimum Y coordinate in world units.
    */
    property alias yWuMin: _theCanvas.worldYMin

    /*!
        \qmlproperty real ClayWorld2d::yWuMax
        \brief Maximum Y coordinate in world units.
    */
    property alias yWuMax: _theCanvas.worldYMax

    /*!
        \qmlproperty real ClayWorld2d::pixelPerUnit
        \brief Pixels per world unit for rendering.
    */
    property alias pixelPerUnit: _theCanvas.pixelPerUnit

    /*!
        \qmlproperty real ClayWorld2d::viewPortCenterWuX
        \brief Viewport center X in world units.
    */
    property alias viewPortCenterWuX: _theCanvas.viewPortCenterWuX

    /*!
        \qmlproperty real ClayWorld2d::viewPortCenterWuY
        \brief Viewport center Y in world units.
    */
    property alias viewPortCenterWuY: _theCanvas.viewPortCenterWuY

    /*!
        \qmlproperty var ClayWorld2d::observedItem
        \brief Item the camera follows.
    */
    property alias observedItem: _theCanvas.observedItem

    // MAP LOADING
    _sceneLoader: SceneLoader2d {
        id: _sceneLoader2d
        loadEntitiesAsync: _world.loadMapAsync
        world: _world
    }

    /*!
        \qmlproperty real ClayWorld2d::baseZCoord
        \brief Base Z coordinate for loaded entities.
    */
    property alias baseZCoord: _sceneLoader2d.baseZCoord

    /*!
        \qmlproperty real ClayWorld2d::lastZCoord
        \brief Last used Z coordinate.
    */
    property alias lastZCoord: _sceneLoader2d.lastZCoord

    /*!
        \qmlproperty World ClayWorld2d::physics
        \brief The Box2D physics world.
    */
    property alias physics: _physicsWorld

    /*!
        \qmlproperty point ClayWorld2d::gravity
        \brief Gravity vector for physics.
    */
    property alias gravity: _physicsWorld.gravity

    /*!
        \qmlproperty real ClayWorld2d::timeStep
        \brief Physics simulation timestep.
    */
    property alias timeStep: _physicsWorld.timeStep

    /*!
        \qmlproperty bool ClayWorld2d::physicsEnabled
        \brief Whether physics is enabled.
    */
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

