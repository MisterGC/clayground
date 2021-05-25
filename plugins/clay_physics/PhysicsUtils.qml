// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0

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
