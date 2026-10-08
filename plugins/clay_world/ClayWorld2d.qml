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
            // hitStop() multiplies on top of the global time scale, so the
            // dojo's time control and a hit stop never overwrite each other.
            // A view-only hit stop leaves the simulation at full speed.
            timeScale: Clayground.timeScale
                       * (_world.hitStopMode === "view" ? 1 : _world._hitStopScale)
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
        \qmlmethod void ClayWorld2d::hitStop(int ms, real scale)
        \brief Freezes or slows the world for \a ms milliseconds of wall
        clock - the freeze frame that sells a heavy hit.

        What freezes follows \l hitStopMode. In \c "physics" mode (the
        default) \a scale is the physics speed meanwhile: 0 (default) stops
        it, 0.2 is slow motion. It multiplies with the global time scale and
        does not touch pause. In \c "view" mode \a scale is the rate at
        which the held picture advances: 0 holds one frame, 0.25 shows a new
        one every fourth frame. Overlapping calls merge: the lower scale and
        the later end win. QML timers and animations of the game keep their
        pace either way, as they do through the dojo's pause and single
        step: game logic that must stand still with the world (enemy AI,
        cooldowns, telegraphs) belongs on a PhysicsTimer, which counts the
        simulated time of \l physics. Typical: 50..90 ms at 0 on a heavy
        hit, 120 ms at 0.2 on a parry.
    */
    function hitStop(ms, scale) {
        var s = (scale === undefined || scale === null) ? 0 : Math.max(0, Math.min(1, scale));
        var until = Date.now() + Math.max(0, ms);
        if (_hitStopTimer.running) {
            s = Math.min(s, _hitStopScale);
            until = Math.max(until, _hitStopUntil);
        }
        _hitStopScale = s;
        _hitStopUntil = until;
        _hitStopTimer.interval = Math.max(1, until - Date.now());
        _hitStopTimer.restart();
    }

    /*!
        \qmlproperty string ClayWorld2d::hitStopMode
        \brief What a hitStop() freezes: \c "physics" (default) or
        \c "view".

        \c "physics" scales the physics world's time, so the simulation
        itself halts. \c "view" keeps the physics stepping at full rate and
        holds the drawn world instead: the canvas is captured when the stop
        begins and that frame is shown until it ends. Use \c "view" where
        the simulation must not stall - a networked game whose node owns
        shared objects and streams their state. Items beside the canvas (a
        HUD) stay live.

        The camera's shake and kick go on through the stop: the held frame
        moves by how far they have moved the view since it was captured,
        and stops at the world's edge where the live view would. The strip
        that move uncovers at the side of the screen shows the frame's own
        edge mirrored. On the software Qt Quick backend, which runs no
        shaders, that strip stays empty.

        A stop with a \c scale above 0 cannot slow the picture down - the
        simulation runs at full speed and only its present state can be
        drawn. It captures the canvas again every 1 / \c scale frames
        instead, so the world moves on in steps at that rate: at 0.25 every
        fourth frame is shown, each one held for four.
    */
    property string hitStopMode: "physics"

    /*!
        \qmlproperty bool ClayWorld2d::hitStopActive
        \readonly
        \brief True while a hitStop() is slowing the physics or holding
        the picture.
    */
    readonly property bool hitStopActive: _hitStopTimer.running

    /*!
        \qmlproperty Item ClayWorld2d::picture
        \readonly
        \brief The item that shows the world: the \l canvas, or the held
        frame while a view-only hitStop() runs. Effects that redraw the
        world from a texture read this item, so they see what is shown.
    */
    readonly property Item picture: !_holding ? _theCanvas
                                              : (_softwareHold ? _held : _heldView)

    property real _hitStopScale: 1
    property real _hitStopUntil: 0
    Timer {
        id: _hitStopTimer
        repeat: false
        onTriggered: _world._hitStopScale = 1
    }

    readonly property bool _holding: hitStopActive && hitStopMode === "view"
    // The software backend runs no ShaderEffect: there the capture itself is
    // shown, moved by a plain translation.
    readonly property bool _softwareHold: GraphicsInfo.api === GraphicsInfo.Software

    // Where the held frame was captured: the viewport centre and the
    // camera's shake plus kick, in world units. The frame moves by how far
    // shake and kick have moved since, not by the follow - the followed
    // body moves on with the simulation, the picture of it does not.
    property point _heldCenter: Qt.point(0, 0)
    property point _heldJuice: Qt.point(0, 0)
    property int _heldGrabs: 0
    property real _heldDue: 0
    property bool _heldPending: false
    readonly property point _juice: camera
        ? Qt.point(camera.shakeXWu + camera.kickXWu, camera.shakeYWu + camera.kickYWu)
        : Qt.point(0, 0)

    // The viewport centre the canvas really shows for a wanted one: it keeps
    // the viewport inside the world, which also clamps the shake.
    function _shownCenterX(v) {
        var half = _theCanvas.sWidthInWU / 2;
        return Math.min(Math.max(v, xWuMin + half), xWuMax - half);
    }
    function _shownCenterY(v) {
        var half = _theCanvas.sHeightInWU / 2;
        return Math.min(Math.max(v, yWuMin + half), yWuMax - half);
    }

    // On screen the content moves against the viewport; world y points up.
    readonly property point _heldShiftPx: _holding
        ? Qt.point(-(_shownCenterX(_heldCenter.x + _juice.x - _heldJuice.x)
                     - _shownCenterX(_heldCenter.x)) * pixelPerUnit,
                   (_shownCenterY(_heldCenter.y + _juice.y - _heldJuice.y)
                    - _shownCenterY(_heldCenter.y)) * pixelPerUnit)
        : Qt.point(0, 0)

    on_HoldingChanged: {
        _heldDue = 0;
        if (!_holding) return;
        _heldGrabs = 0;
        _captureHeld();
    }

    // scheduleUpdate() on every capture, because a ShaderEffectSource with
    // live: false grabs by itself only the first time. The capture happens in
    // the next scene graph sync, so where the view stood is noted right before
    // it, after the frame's animations (the camera's shake among them) have
    // run - noted earlier, the frame would jump by one frame of shake.
    function _captureHeld() {
        _noteHeld();
        _heldPending = true;
        _heldGrabs += 1;
        _held.scheduleUpdate();
    }
    function _noteHeld() {
        _heldCenter = Qt.point(viewPortCenterWuX, viewPortCenterWuY);
        _heldJuice = _juice;
    }
    Connections {
        target: _world.Window.window
        enabled: _world._heldPending
        function onAfterAnimating() {
            _world._heldPending = false;
            _world._noteHeld();
        }
    }

    // A slowed view stop: a new capture every 1 / scale frames.
    FrameAnimation {
        running: _world._holding && _world._hitStopScale > 0
        onTriggered: {
            _world._heldDue += _world._hitStopScale;
            if (_world._heldDue >= 1) {
                _world._heldDue -= 1;
                _world._captureHeld();
            }
        }
    }

    // The held frame of a view-only hit stop. live: false renders the canvas
    // only on _captureHeld(). sourceItem is released at rest, so no texture is
    // kept.
    ShaderEffectSource {
        id: _held
        anchors.fill: _theCanvas
        visible: _world._holding && _world._softwareHold
        sourceItem: _world._holding ? _theCanvas : null
        hideSource: _world._holding
        live: false
        transform: Translate { x: _world._heldShiftPx.x; y: _world._heldShiftPx.y }
    }
    ShaderEffect {
        id: _heldView
        anchors.fill: _theCanvas
        visible: _world._holding && !_world._softwareHold
        property var source: _held
        property point shift: Qt.point(_world._heldShiftPx.x / Math.max(1, width),
                                       _world._heldShiftPx.y / Math.max(1, height))
        fragmentShader: "held_frame.frag.qsb"
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
        info["hitStop"] = {"active": hitStopActive, "mode": hitStopMode,
                           "scale": _hitStopScale,
                           // How far the held frame is moved by shake and
                           // kick, and how often the latest view stop
                           // captured the canvas.
                           "heldShiftPx": [_heldShiftPx.x, _heldShiftPx.y],
                           "heldCaptures": _heldGrabs,
                           "remainingMs": hitStopActive
                               ? Math.max(0, _hitStopUntil - Date.now()) : 0};
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
        // A child an entity owns but parents into the room (a trail, a
        // shadow) is marked deleted together with the entity, before the
        // entity leaves the room; that leave runs this over room.children,
        // where the part then reads as null and `in` throws (#335).
        if (!obj) return;
        if ("pixelPerUnit" in obj)
            obj.pixelPerUnit = Qt.binding( _ => {return _theCanvas.pixelPerUnit;} );
        if ("world" in obj)
            obj.world = Qt.binding( _ => {return _world.physics;} );
    }
}

