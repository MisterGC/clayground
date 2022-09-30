// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D

Item {
    id: _collisionTracker
    property var entities: new Set()
    property bool debug: false
    property var debugMarkers: debug ? new Map() : null

    property var fixture: null
    onFixtureChanged: {
        if (fixture) {
            PhysicsUtils.connectOnEntered(fixture, _onEntered);
            PhysicsUtils.connectOnLeft(fixture, _onLeft);
        }
    }

    signal beginContact(entity: var)
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
