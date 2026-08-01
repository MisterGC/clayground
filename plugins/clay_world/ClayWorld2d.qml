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
        \brief Item the camera follows. Ignored when a camera is set.
    */
    property alias observedItem: _theCanvas.observedItem

    /*!
        \qmlproperty ClayWorld2dCamera ClayWorld2d::camera
        \brief Optional camera component for advanced observation modes.
               When set, takes over viewport positioning from observedItem.
    */
    property ClayWorld2dCamera camera: null
    onCameraChanged: _bindCamera()
    function _bindCamera() {
        if (camera) {
            _theCanvas.observedItem = null
            _theCanvas.viewPortCenterWuX = Qt.binding(function() { return camera.cameraX; })
            _theCanvas.viewPortCenterWuY = Qt.binding(function() { return camera.cameraY; })
        }
    }

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
        Component { id: _physDebug; DebugDraw {parent: _theCanvas.coordSys; anchors.fill: parent; world: _physicsWorld; flags: DebugDraw.Shape }}
        Loader { sourceComponent: debugPhysics ? _physDebug : null }

        World {
            id: _physicsWorld
            gravity: Qt.point(0,15*9.81)
            timeStep: 1/60.0
            timeScale: Clayground.timeScale
            pixelsPerMeter: _theCanvas.pixelPerUnit ? _theCanvas.pixelPerUnit : 1
            running: true
        }

        // Global pause overrides running but restores the user's value when
        // lifted; single-step advances the frozen simulation frame by frame.
        Binding {
            target: _physicsWorld
            property: "running"
            value: false
            when: Clayground.paused
            restoreMode: Binding.RestoreBindingOrValue
        }
        Connections {
            target: Clayground
            function onPhysicsStep(frames) {
                // The step driver derives timeStep from the frame delta while
                // running; manual stepping fixes it for exact reproducibility.
                _physicsWorld.timeStep = 1/60.0;
                for (let i = 0; i < frames; ++i) _physicsWorld.step();
                Clayground.ackStep(frames);
            }
        }
    }

    /*!
        \qmlmethod object ClayWorld2d::clayInspect()
        \brief Reports world bounds, entity count and camera state as plain
               JSON, for tooling.

        Pull-only and side-effect free: read on demand from the canvas, the
        room and the physics world, nothing is cached or observed. Extends
        \c _clayInspectBase() with the 2d-specific half.
    */
    function clayInspect() {
        var info = _clayInspectBase();
        info["type"] = "ClayWorld2d";
        info["worldBounds"] = {"xMin": xWuMin, "xMax": xWuMax,
                               "yMin": yWuMin, "yMax": yWuMax};
        info["worldSizeWu"] = [xWuMax - xWuMin, yWuMax - yWuMin];
        info["pixelPerUnit"] = pixelPerUnit;
        info["entityCount"] = room ? room.children.length : 0;
        info["viewPortCenterWu"] = [viewPortCenterWuX, viewPortCenterWuY];
        info["hasObservedItem"] = observedItem ? true : false;
        info["observedItem"] = (observedItem && observedItem.objectName)
                               ? observedItem.objectName : null;
        // Either a camera drives the viewport or observedItem does, never both
        // - reporting which one is in charge is half the answer to "why is the
        // view here".
        info["cameraAttached"] = camera !== null;
        info["running"] = running;
        info["gravity"] = [gravity.x, gravity.y];
        info["timeStep"] = timeStep;
        info["baseZCoord"] = baseZCoord;
        info["lastZCoord"] = lastZCoord;
        return info;
    }

    // _updateRoomContent also runs once here so declaratively room-parented
    // children get their world/pixelPerUnit wired in worlds without a map
    // (the room.childrenChanged connection is not active during
    // instantiation and onMapLoaded never fires without a scene).
    Component.onCompleted: {_moveToRoomOnDemand(); _updateRoomContent(); childrenChanged.connect(_moveToRoomOnDemand); _loadActive.restart();}
    Timer {id: _loadActive; interval: 1; onTriggered: _sceneLoader2d.active = true;}
    Connections{target: room; function onChildrenChanged(){_updateRoomContent();}}

    // MAP LOADING
    onMapLoaded: _updateRoomContent()

    function _moveToRoomOnDemand() {
        if (!_world) return;
        // Snapshot: reparenting mutates _world.children while we iterate,
        // which would silently skip every other entity.
        let candidates = Array.from(_world.children);
        for (let obj of candidates) {
            // instanceof misses anonymous subtypes (entities that declare
            // extra properties), so also accept anything with the physics
            // capability signature.
            let migrate = obj instanceof RectBoxBody  ||
                obj instanceof VisualizedPolyBody ||
                obj instanceof ImageBoxBody  ||
                obj instanceof PhysicsItem ||
                (("world" in obj) && ("xWu" in obj) && ("bodyType" in obj));

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

