// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype PhysicsItem
    \inqmlmodule Clayground.Physics
    \brief Base component for physics-enabled items with world unit support.

    PhysicsItem provides the foundation for all physics-enabled components,
    handling bidirectional coordinate synchronization between world units and
    screen pixels, and wrapping a Box2D Body.

    Example usage:
    \qml
    import Clayground.Physics
    import Box2D

    PhysicsItem {
        xWu: 5; yWu: 10
        widthWu: 2; heightWu: 1
        pixelPerUnit: 50
        bodyType: Body.Dynamic
    }
    \endqml

    \note When declaring fixtures inline, use an explicit ID to reference
    the item's dimensions — \b not \c parent. Box2D fixture types (Box, Circle,
    Polygon, etc.) are QObjects. In QML, \c parent inside a QObject resolves
    via the scope chain to the PhysicsItem's visual parent, not the PhysicsItem
    itself. Use \c {width: myItem.width} instead of \c {width: parent.width}.
    Prefer RectBoxBody or ImageBoxBody which handle this correctly.

    \sa RectBoxBody, ImageBoxBody, VisualizedPolyBody
*/
import QtQuick
import Box2D

Item {
    id: item

    /*!
        \qmlproperty real PhysicsItem::pixelPerUnit
        \brief Conversion factor between pixels and world units.
    */
    property real pixelPerUnit: 1

    /*!
        \qmlproperty real PhysicsItem::xWu
        \brief X position in world units.
    */
    property real xWu: 0

    /*!
        \qmlproperty real PhysicsItem::yWu
        \brief Y position in world units.
    */
    property real yWu: 0

    // Bidirectional updates as phyics item's x-y coords may be controlled by
    // physics or by canvas world units -> no unidirection binding possible.
    // World units are authoritative whenever the pixel frame shifts: the
    // wu->pixel direction re-runs on completion (initial values fire no
    // change handlers), on pixelPerUnit changes, and on parent (re)size or
    // reparenting - otherwise bodies created before the room finished
    // layouting would keep a stale y-frame and never collide with later
    // ones. The pixel->wu direction is guarded so a not-yet-laid-out
    // pixelPerUnit of 0 cannot poison the world units with NaN, and it is
    // suppressed while a wu-side write is in flight - the float round-trip
    // otherwise echoes a slightly different value back into xWu/yWu, which
    // retargets any Behavior animating them and stalls it short of its
    // target (issue #139).
    property bool _wuSyncActive: false
    onXWuChanged: { _wuSyncActive = true; x = xWu * pixelPerUnit; _wuSyncActive = false; }
    onYWuChanged: { _wuSyncActive = true; y = parent ? parent.height - yWu * pixelPerUnit : 0; _wuSyncActive = false; }
    onXChanged: if (!_wuSyncActive && pixelPerUnit > 0) xWu = (1/pixelPerUnit) * x;
    onYChanged: if (!_wuSyncActive && pixelPerUnit > 0) yWu = item.parent ? (1/pixelPerUnit) * (item.parent.height - y) : 0
    onPixelPerUnitChanged: _syncFromWu()
    onParentChanged: _syncFromWu()
    Component.onCompleted: _syncFromWu()
    Connections {
        target: item.parent
        function onHeightChanged() { item._syncFromWu(); }
    }
    function _syncFromWu() {
        _wuSyncActive = true;
        x = xWu * pixelPerUnit;
        y = parent ? parent.height - yWu * pixelPerUnit : 0;
        _wuSyncActive = false;
    }

    /*!
        \qmlproperty real PhysicsItem::widthWu
        \brief Width in world units.
    */
    property real widthWu: 1

    /*!
        \qmlproperty real PhysicsItem::heightWu
        \brief Height in world units.
    */
    property real heightWu: 1

    width: widthWu * pixelPerUnit
    height: heightWu * pixelPerUnit

    /*!
        \qmlproperty Body PhysicsItem::body
        \brief The Box2D body instance.
    */
    property alias body: itemBody

    /*!
        \qmlproperty World PhysicsItem::world
        \brief Physics world reference. Auto-detected if physicsWorld exists in context.
    */
    property alias world: itemBody.world

    /*!
        \qmlproperty real PhysicsItem::linearDamping
        \brief Linear motion damping coefficient.
    */
    property alias linearDamping: itemBody.linearDamping

    /*!
        \qmlproperty real PhysicsItem::angularDamping
        \brief Angular motion damping coefficient.
    */
    property alias angularDamping: itemBody.angularDamping

    /*!
        \qmlproperty Body.BodyType PhysicsItem::bodyType
        \brief Body type: Body.Static, Body.Kinematic, or Body.Dynamic.
    */
    property alias bodyType: itemBody.bodyType

    /*!
        \qmlproperty bool PhysicsItem::bullet
        \brief Enable continuous collision detection for fast-moving objects.
    */
    property alias bullet: itemBody.bullet

    /*!
        \qmlproperty bool PhysicsItem::sleepingAllowed
        \brief Whether the body can sleep when inactive.
    */
    property alias sleepingAllowed: itemBody.sleepingAllowed

    /*!
        \qmlproperty bool PhysicsItem::fixedRotation
        \brief Prevent the body from rotating.
    */
    property alias fixedRotation: itemBody.fixedRotation

    /*!
        \qmlproperty bool PhysicsItem::active
        \brief Whether the body is active in the physics simulation.
    */
    property alias active: itemBody.active

    /*!
        \qmlproperty bool PhysicsItem::awake
        \brief Whether the body is awake (not sleeping).
    */
    property alias awake: itemBody.awake

    /*!
        \qmlproperty point PhysicsItem::linearVelocity
        \brief Linear velocity vector (x, y).
    */
    property alias linearVelocity: itemBody.linearVelocity

    /*!
        \qmlproperty real PhysicsItem::angularVelocity
        \brief Angular velocity in radians per second.
    */
    property alias angularVelocity: itemBody.angularVelocity

    /*!
        \qmlproperty list PhysicsItem::fixtures
        \brief List of fixtures attached to this body.
    */
    property alias fixtures: itemBody.fixtures

    /*!
        \qmlproperty real PhysicsItem::gravityScale
        \brief Gravity effect multiplier for this body.
    */
    property alias gravityScale: itemBody.gravityScale

    /*!
        \qmlmethod object PhysicsItem::clayInspect()
        \brief Reports position, size and body state as plain JSON, for tooling.

        Pull-only and side-effect free: everything is read from the live body on
        demand, nothing is cached or observed. Answers "where is this thing and
        what is it doing" in world units, without taking a screenshot.
    */
    function clayInspect() {
        var typeNames = ["Static", "Kinematic", "Dynamic"];
        // sensor/categories live on the FIXTURES, not on the body - a body with
        // no fixture has neither, which is not the same as "not a sensor".
        var sensor = null;
        var categories = null;
        var collidesWith = null;
        var fixtureCount = 0;
        if (itemBody.fixtures) {
            fixtureCount = itemBody.fixtures.length;
            if (fixtureCount > 0) {
                var f = itemBody.fixtures[0];
                sensor = f.sensor;
                categories = f.categories;
                collidesWith = f.collidesWith;
            }
        }
        return {
            "type": "PhysicsItem",
            "objectName": objectName ? objectName : null,
            "xWu": xWu, "yWu": yWu,
            "widthWu": widthWu, "heightWu": heightWu,
            "positionPx": [x, y],
            "sizePx": [width, height],
            "pixelPerUnit": pixelPerUnit,
            "bodyType": typeNames[itemBody.bodyType] !== undefined
                        ? typeNames[itemBody.bodyType] : itemBody.bodyType,
            "linearVelocity": itemBody.linearVelocity
                              ? [itemBody.linearVelocity.x, itemBody.linearVelocity.y]
                              : null,
            "angularVelocity": itemBody.angularVelocity,
            "active": itemBody.active,
            "awake": itemBody.awake,
            "bullet": itemBody.bullet,
            "fixedRotation": itemBody.fixedRotation,
            "gravityScale": itemBody.gravityScale,
            "fixtureCount": fixtureCount,
            "sensor": sensor,
            "categories": categories,
            "collidesWith": collidesWith,
            "hasWorld": itemBody.world !== null,
            "visible": visible,
            "rotation": rotation
        };
    }

    Body {
        id: itemBody

        target: item
        world: typeof physicsWorld !== 'undefined' ? physicsWorld : null
    }
}
