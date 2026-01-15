// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype CollisionTracker
    \inqmlmodule Clayground.Physics
    \brief Tracks entities currently colliding with a fixture.

    CollisionTracker maintains a set of entities currently in contact with a
    monitored fixture and emits signals when contacts begin or end. Useful for
    implementing trigger zones, ground detection, and proximity sensors.

    Example usage:
    \qml
    import Clayground.Physics

    CollisionTracker {
        fixture: player.fixture
        debug: true
        onBeginContact: (entity) => {
            if (entity.objectName === "ground")
                player.onGround = true
        }
        onEndContact: (entity) => {
            if (entity.objectName === "ground")
                player.onGround = false
        }
    }
    \endqml

    \sa PhysicsUtils
*/
import QtQuick
import Box2D

Item {
    id: _collisionTracker

    /*!
        \qmlproperty Set CollisionTracker::entities
        \brief Set of entities currently in collision with the fixture.
    */
    property var entities: new Set()

    /*!
        \qmlproperty bool CollisionTracker::debug
        \brief Shows debug visualization markers on colliding entities.
    */
    property bool debug: false

    property var debugMarkers: debug ? new Map() : null

    /*!
        \qmlproperty Fixture CollisionTracker::fixture
        \brief The fixture to monitor for collisions.
    */
    property var fixture: null
    onFixtureChanged: {
        if (fixture) {
            PhysicsUtils.connectOnEntered(fixture, _onEntered);
            PhysicsUtils.connectOnLeft(fixture, _onLeft);
        }
    }

    /*!
        \qmlsignal CollisionTracker::beginContact(var entity)
        \brief Emitted when an entity enters collision with the fixture.
    */
    signal beginContact(entity: var)

    /*!
        \qmlsignal CollisionTracker::endContact(var entity)
        \brief Emitted when an entity leaves collision with the fixture.
    */
    signal endContact(entity: var)

    function _onDestruction(entity) {
        // TODO Clean solution, disconnect when entity left
        // -> this check would be obsolete
        if (entities.has(entity))
            _onLeft(entity);
    }

    function _onEntered(entity) {
        entity.Component.destruction.connect(_ => {_collisionTracker._onDestruction(entity);})
        entities.add(entity);
        if (debug){
            let obj = debugMarker.createObject(entity, {width: (entity.width * 1.25)});
            debugMarkers.set(entity, obj);
        }
        beginContact(entity);
        entitiesChanged();
    }

    function _onLeft(entity) {
        if (entities.has(entity)){
            entities.delete(entity);
            if (debugMarkers && debugMarkers.has(entity)) {
                let m = debugMarkers.get(entity);
                m.destroy();
                debugMarkers.delete(entity);
            }
        }
        endContact(entity)
        entitiesChanged();
    }

    Component {id: debugMarker;
        Rectangle{color: "red"; opacity: .75; z: -1
                  radius: width * .1
                  height: width; anchors.centerIn: parent}}

}
