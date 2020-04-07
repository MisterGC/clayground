/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.0
import Box2D 2.0
import Clayground.ScalingCanvas 1.0

ScalingPoly {
    id: thePoly

    property var vertices: []
    onVerticesChanged: syncShape();
    Component.onCompleted: syncShape();
    function onGeoUpdate() {
        _syncShape();
        _syncPhys();
    }
    function _syncPhys() {
        const xOff = thePoly.x
        const yOff = thePoly.y
        let pVerts = [Qt.point(0,0)];
        for (const pe of _shapePath.pathElements)
            pVerts.push(Qt.point(pe.x-xOff, pe.y-yOff));
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
        target: theImage
        Polygon {
            id: theFixture
            width: theImage.width
            height: theImage.height
        }
    }
}


