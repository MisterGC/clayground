// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype VisualizedPolyBody
    \inqmlmodule Clayground.Physics
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

    \sa PhysicsItem, RectBoxBody
*/
import QtQuick
import Box2D
import Clayground.Canvas

Poly {
    id: thePoly

    onVerticesChanged: refresh();
    onWidthChanged: refresh();
    Component.onCompleted: refresh();

    /*!
        \qmlmethod void VisualizedPolyBody::refresh()
        \brief Refreshes visual and physics geometry from vertices.
    */
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

    /*!
        \qmlproperty Body VisualizedPolyBody::body
        \brief The Box2D body instance.
    */
    property alias body: theBody

    /*!
        \qmlproperty Fixture VisualizedPolyBody::fixture
        \brief The Box2D polygon fixture.
    */
    property alias fixture: theFixture

    /*!
        \qmlproperty World VisualizedPolyBody::world
        \brief Physics world reference.
    */
    property alias world: theBody.world

    /*!
        \qmlproperty real VisualizedPolyBody::linearDamping
        \brief Linear motion damping coefficient.
    */
    property alias linearDamping: theBody.linearDamping

    /*!
        \qmlproperty real VisualizedPolyBody::angularDamping
        \brief Angular motion damping coefficient.
    */
    property alias angularDamping: theBody.angularDamping

    /*!
        \qmlproperty Body.BodyType VisualizedPolyBody::bodyType
        \brief Body type: Body.Static, Body.Kinematic, or Body.Dynamic.
    */
    property alias bodyType: theBody.bodyType

    /*!
        \qmlproperty bool VisualizedPolyBody::bullet
        \brief Enable continuous collision detection.
    */
    property alias bullet: theBody.bullet

    /*!
        \qmlproperty bool VisualizedPolyBody::sleepingAllowed
        \brief Whether the body can sleep.
    */
    property alias sleepingAllowed: theBody.sleepingAllowed

    /*!
        \qmlproperty bool VisualizedPolyBody::fixedRotation
        \brief Prevent the body from rotating.
    */
    property alias fixedRotation: theBody.fixedRotation

    /*!
        \qmlproperty bool VisualizedPolyBody::active
        \brief Whether the body is active.
    */
    property alias active: theBody.active

    /*!
        \qmlproperty bool VisualizedPolyBody::awake
        \brief Whether the body is awake.
    */
    property alias awake: theBody.awake

    /*!
        \qmlproperty point VisualizedPolyBody::linearVelocity
        \brief Linear velocity vector.
    */
    property alias linearVelocity: theBody.linearVelocity

    /*!
        \qmlproperty real VisualizedPolyBody::angularVelocity
        \brief Angular velocity.
    */
    property alias angularVelocity: theBody.angularVelocity

    /*!
        \qmlproperty list VisualizedPolyBody::fixtures
        \brief List of fixtures.
    */
    property alias fixtures: theBody.fixtures

    /*!
        \qmlproperty real VisualizedPolyBody::gravityScale
        \brief Gravity effect multiplier.
    */
    property alias gravityScale: theBody.gravityScale

    /*!
        \qmlproperty real VisualizedPolyBody::density
        \brief Fixture density.
    */
    property alias density: theFixture.density

    /*!
        \qmlproperty real VisualizedPolyBody::friction
        \brief Friction coefficient.
    */
    property alias friction: theFixture.friction

    /*!
        \qmlproperty real VisualizedPolyBody::restitution
        \brief Bounciness coefficient.
    */
    property alias restitution: theFixture.restitution

    /*!
        \qmlproperty bool VisualizedPolyBody::sensor
        \brief If true, detects collisions without physical response.
    */
    property alias sensor: theFixture.sensor

    /*!
        \qmlproperty int VisualizedPolyBody::categories
        \brief Collision category bits.
    */
    property alias categories: theFixture.categories

    /*!
        \qmlproperty int VisualizedPolyBody::collidesWith
        \brief Collision mask bits.
    */
    property alias collidesWith: theFixture.collidesWith

    /*!
        \qmlproperty int VisualizedPolyBody::groupIndex
        \brief Collision group index.
    */
    property alias groupIndex: theFixture.groupIndex

    Body {
        id: theBody
        target: thePoly
        Polygon { id: theFixture; vertices:[Qt.point(0,0),
                                            Qt.point(10,0),
                                            Qt.point(10,10)] }
    }
}


