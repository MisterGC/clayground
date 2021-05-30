// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0
import Clayground.Canvas 1.0

Poly {
    id: thePoly

    // TODO Fix coord syncing x,y -> canvas world coord if item is physics controlled
    // see https://github.com/MisterGC/clayground/issues/68

    onVerticesChanged: refresh();
    onWidthChanged: refresh();
    Component.onCompleted: refresh();
    function refresh() {
        _syncVisu();
        _syncPhys();
    }
    function _syncPhys() {
        let pVerts = [Qt.point(_shapePath.startX, _shapePath.startY)];
        let pes = _shapePath.pathElements;
        for (let i=0; i<pes.length; ++i){
            let pe = pes[i];
            pVerts.push(Qt.point(pe.x, pe.y));
        }
        theFixture.vertices = pVerts;
    }

    property alias body: theBody
    property alias fixture: theFixture

    // Body properties
    property alias world: theBody.world
    property alias linearDamping: theBody.linearDamping
    property alias angularDamping: theBody.angularDamping
    property alias bodyType: theBody.bodyType
    property alias bullet: theBody.bullet
    property alias sleepingAllowed: theBody.sleepingAllowed
    property alias fixedRotation: theBody.fixedRotation
    property alias active: theBody.active
    property alias awake: theBody.awake
    property alias linearVelocity: theBody.linearVelocity
    property alias angularVelocity: theBody.angularVelocity
    property alias fixtures: theBody.fixtures
    property alias gravityScale: theBody.gravityScale

    // Fixture properties
    property alias density: theFixture.density
    property alias friction: theFixture.friction
    property alias restitution: theFixture.restitution
    property alias sensor: theFixture.sensor
    property alias categories: theFixture.categories
    property alias collidesWith: theFixture.collidesWith
    property alias groupIndex: theFixture.groupIndex

    Body {
        id: theBody
        target: thePoly
        Polygon { id: theFixture; vertices:[Qt.point(0,0),
                                            Qt.point(10,0),
                                            Qt.point(10,10)] }
    }
}


