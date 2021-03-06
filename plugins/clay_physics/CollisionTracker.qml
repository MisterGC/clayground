// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0

Item {
    property var entities: new Set()
    property var fixture: null
    onFixtureChanged: {
        if (fixture) {
            PhysicsUtils.connectOnEntered(fixture, _onEntered);
            PhysicsUtils.connectOnLeft(fixture, _onLeft);
        }
    }

    signal entered(var entity)
    signal left(var entity)

    function _onDestruction(entity) {
        // TODO Clean solution, disconnect when entity left
        // -> this check would be obsolete
        if (entities.has(entity))
            _onLeft(entity);
    }

    function _onEntered(entity) {
        entity.Component.destruction.connect(_ => {_onDestruction(entity);})
        entities.add(entity);
        entered(entity);
        entitiesChanged();
    }

    function _onLeft(entity) {
        if (entities.has(entity))
            entities.delete(entity);
        left(entity)
        entitiesChanged();
    }

}
