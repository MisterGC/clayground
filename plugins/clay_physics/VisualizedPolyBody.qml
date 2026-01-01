// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype VisualizedPolyBody
    \inqmlmodule Clayground.Physics
    \inherits Clayground.Canvas::Poly
    \brief Polygon-shaped physics body with Canvas visualization.

    VisualizedPolyBody combines a visual Poly shape with a Box2D polygon fixture.
    The physics shape automatically synchronizes with the visual vertices.

    Example usage:
    \qml
    import Clayground.Physics
    import Box2D

    VisualizedPolyBody {
        canvas: myCanvas
        vertices: [
            {x: 0, y: 0},
            {x: 2, y: 0},
            {x: 1, y: 2}
        ]
        fillColor: "green"
        bodyType: Body.Dynamic
        density: 2
    }
    \endqml

    \qmlproperty Body VisualizedPolyBody::body
    \brief The Box2D body instance.

    \qmlproperty Fixture VisualizedPolyBody::fixture
    \brief The Box2D polygon fixture.

    \qmlproperty World VisualizedPolyBody::world
    \brief Physics world reference.

    \qmlproperty real VisualizedPolyBody::linearDamping
    \brief Linear motion damping coefficient.

    \qmlproperty real VisualizedPolyBody::angularDamping
    \brief Angular motion damping coefficient.

    \qmlproperty Body.BodyType VisualizedPolyBody::bodyType
    \brief Body type: Body.Static, Body.Kinematic, or Body.Dynamic.

    \qmlproperty bool VisualizedPolyBody::bullet
    \brief Enable continuous collision detection.

    \qmlproperty bool VisualizedPolyBody::sleepingAllowed
    \brief Whether the body can sleep.

    \qmlproperty bool VisualizedPolyBody::fixedRotation
    \brief Prevent the body from rotating.

    \qmlproperty bool VisualizedPolyBody::active
    \brief Whether the body is active.

    \qmlproperty bool VisualizedPolyBody::awake
    \brief Whether the body is awake.

    \qmlproperty point VisualizedPolyBody::linearVelocity
    \brief Linear velocity vector.

    \qmlproperty real VisualizedPolyBody::angularVelocity
    \brief Angular velocity.

    \qmlproperty list VisualizedPolyBody::fixtures
    \brief List of fixtures.

    \qmlproperty real VisualizedPolyBody::gravityScale
    \brief Gravity effect multiplier.

    \qmlproperty real VisualizedPolyBody::density
    \brief Fixture density.

    \qmlproperty real VisualizedPolyBody::friction
    \brief Friction coefficient.

    \qmlproperty real VisualizedPolyBody::restitution
    \brief Bounciness coefficient.

    \qmlproperty bool VisualizedPolyBody::sensor
    \brief If true, detects collisions without physical response.

    \qmlproperty int VisualizedPolyBody::categories
    \brief Collision category bits.

    \qmlproperty int VisualizedPolyBody::collidesWith
    \brief Collision mask bits.

    \qmlproperty int VisualizedPolyBody::groupIndex
    \brief Collision group index.

    \qmlmethod void VisualizedPolyBody::refresh()
    \brief Refreshes visual and physics geometry from vertices.
*/
import QtQuick
import Box2D
import Clayground.Canvas

Poly {
    id: thePoly

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


