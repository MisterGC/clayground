// (c) Clayground Contributors - MIT License, see "LICENSE" file

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
