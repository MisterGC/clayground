// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype PhysicsUtils
    \inqmlmodule Clayground.Physics
    \brief Singleton utility providing physics collision connection helpers.

    PhysicsUtils offers convenience functions for connecting to Box2D fixture
    collision signals, automatically extracting the target item from contacted fixtures.

    Example usage:
    \qml
    import Clayground.Physics

    Component.onCompleted: {
        PhysicsUtils.connectOnEntered(myFixture, (entity) => {
            console.log("Collided with:", entity)
        })
    }
    \endqml

    \qmlmethod void PhysicsUtils::connectOnEntered(Fixture fixture, function method, function fixtureCheck)
    \brief Connects a callback to the fixture's beginContact signal.

    \a fixture is the fixture to monitor for collisions.
    \a method is called with the colliding entity's target item.
    \a fixtureCheck optional filter function receiving the contacting fixture.

    \qmlmethod void PhysicsUtils::connectOnLeft(Fixture fixture, function method, function fixtureCheck)
    \brief Connects a callback to the fixture's endContact signal.

    \a fixture is the fixture to monitor for collision exits.
    \a method is called with the entity's target item that left collision.
    \a fixtureCheck optional filter function receiving the contacting fixture.
*/
import QtQuick
import Box2D

pragma Singleton
Item {
    function connectOnEntered(fixture, method, fixtureCheck) {
        fixture.beginContact.connect((f) => {
                                         if (!fixtureCheck ||
                                             (fixtureCheck && fixtureCheck(f)))
                                         method(f.getBody().target);
                                     });
    }

    function connectOnLeft(fixture, method, fixtureCheck) {
        fixture.endContact.connect((f) => {
                                         if (!fixtureCheck ||
                                             (fixtureCheck && fixtureCheck(f)))
                                         method(f.getBody().target);
                                   });
    }
}
