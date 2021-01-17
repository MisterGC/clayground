// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

function connectOnEntered(fixture, method, fixtureCheck) {
    fixture.beginContact.connect((f) => {
                                     if (!fixtureCheck ||
                                         (fixtureCheck && fixtureCheck(f)))
                                         method(f.getBody().target);
                                 });
}

function connectOnLeft(fixture, method) {
    fixture.endContact.connect((f) => {method(f.getBody().target);});
}

