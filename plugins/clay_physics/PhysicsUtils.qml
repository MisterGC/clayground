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

    \sa CollisionTracker
*/
import QtQuick
import Box2D

pragma Singleton
Item {
    /*!
        \qmlmethod void PhysicsUtils::connectOnEntered(Fixture fixture, function method, function fixtureCheck)
        \brief Connects a callback to the fixture's beginContact signal.

        \a fixture is the fixture to monitor for collisions.
        \a method is called with the colliding entity's target item.
        \a fixtureCheck optional filter function receiving the contacting fixture.
    */
    function connectOnEntered(fixture, method, fixtureCheck) {
        fixture.beginContact.connect((f) => {
                                         if (!fixtureCheck ||
                                             (fixtureCheck && fixtureCheck(f)))
                                         method(f.getBody().target);
                                     });
    }

    /*!
        \qmlmethod void PhysicsUtils::connectOnLeft(Fixture fixture, function method, function fixtureCheck)
        \brief Connects a callback to the fixture's endContact signal.

        \a fixture is the fixture to monitor for collision exits.
        \a method is called with the entity's target item that left collision.
        \a fixtureCheck optional filter function receiving the contacting fixture.
    */
    function connectOnLeft(fixture, method, fixtureCheck) {
        fixture.endContact.connect((f) => {
                                         if (!fixtureCheck ||
                                             (fixtureCheck && fixtureCheck(f)))
                                         method(f.getBody().target);
                                   });
    }

    // Remembers which fixtures of other bodies the fixtures of `body` touch,
    // and end() sends each of them its endContact while the body's item can
    // still be named (#371). Box2D ends the contacts of a body only when it
    // destroys the body - by then the item is gone - and qml-box2d drops
    // those events anyway (World::SayGoodbye), so a sensor never heard that
    // a destroyed item left it. end() is called from the item's
    // Component.onDestruction. Only fixtures the body has when this is called
    // are tracked.
    function _trackContacts(body) {
        // own fixture -> Map(other fixture -> number of open contacts)
        let pairs = new Map();
        let fixtures = [];
        for (let i = 0; i < body.fixtures.length; ++i) {
            let own = body.fixtures[i];
            fixtures.push(own);
            pairs.set(own, new Map());
            own.beginContact.connect((other) => {
                let touching = pairs.get(own);
                touching.set(other, (touching.get(other) || 0) + 1);
            });
            own.endContact.connect((other) => {
                let touching = pairs.get(own);
                let n = (touching.get(other) || 0) - 1;
                if (n > 0) touching.set(other, n);
                else touching.delete(other);
            });
        }
        return {
            end: () => {
                for (let own of fixtures) {
                    let touching = pairs.get(own);
                    for (let [other, n] of Array.from(touching)) {
                        touching.delete(other);
                        // A raw Body (no PhysicsItem around it) ends nothing
                        // when it goes, so its fixture can be gone already.
                        if (!other || typeof other.getBody !== "function")
                            continue;
                        for (let k = 0; k < n; ++k) other.endContact(own);
                    }
                }
            }
        };
    }
}
