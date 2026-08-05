// (c) Clayground Contributors - MIT License, see "LICENSE" file

// What SceneLoader3d does with the polygons of an SVG scene: where their ring
// lands in the world, and the split between a polygon that names a registered
// component and one that does not.
//
// The loader is driven against a stub world rather than a ClayWorld3d so the
// checks stay on the loader and need no 3D viewport; ClayWorld3d itself is
// covered by tst_world_smoke.

import QtQuick
import QtQuick3D
import QtTest
import Clayground.World

Item {
    id: _root
    width: 200
    height: 200

    // The map is 100 x 80 mm, so an accidental axis swap cannot hide behind
    // equal extents.
    readonly property real mapWidthWu: 100
    readonly property real mapHeightWu: 80

    component AreaStub : Node {
        property var vertices: []
        property color color: "black"
        property real extrude: 0
    }

    component MarkerStub : Node {
        property real width: 0
        property real depth: 0
    }

    Component { id: _areaComp; AreaStub {} }
    Component { id: _markerComp; MarkerStub {} }

    readonly property var registry: new Map([['Area', _areaComp], ['Marker', _markerComp]])

    // Everything SceneLoaderBase/SceneLoader3d expect of a world.
    Item {
        id: _stubWorld

        property real xWuMax: 0
        property real zWuMax: 0
        property var components: _root.registry
        property var root: _sceneRoot

        property var polygonsReported: []
        property var rectanglesReported: []
        property var created: []

        signal mapAboutToBeLoaded()
        signal mapLoaded()
        signal mapEntityAboutToBeCreated(var groupId, var cfg)
        signal mapEntityCreated(var obj, var groupId, var cfg)
        signal groupAboutToBeLoaded(var id, var description)
        signal groupLoaded(var id)
        signal polylineLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
        signal polygonLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
        signal rectangleLoaded(var id, var groupId, var x, var y, var width, var height,
                               var fillColor, var strokeColor, var description)
        signal circleLoaded(var id, var groupId, var x, var y, var radius,
                            var fillColor, var strokeColor, var description)

        onMapAboutToBeLoaded: {
            polygonsReported = [];
            rectanglesReported = [];
            created = [];
        }

        onPolygonLoaded: (id, groupId, points, fillColor, strokeColor, description) => {
            polygonsReported.push({"id": id, "groupId": groupId, "points": points,
                                   "fillColor": fillColor, "description": description});
        }

        onRectangleLoaded: (id, groupId, x, y, width, height, fillColor, strokeColor, description) => {
            rectanglesReported.push({"id": id, "x": x, "y": y, "width": width, "height": height,
                                     "fillColor": fillColor, "strokeColor": strokeColor,
                                     "description": description});
        }

        onMapEntityCreated: (obj, groupId, cfg) => { created.push(obj); }

        Node { id: _sceneRoot }
    }

    SceneLoader3d {
        id: _loader
        world: _stubWorld
        components: _root.registry
    }

    function entitiesOfType(typeName) {
        let res = [];
        for (let i = 0; i < _stubWorld.created.length; ++i) {
            let obj = _stubWorld.created[i];
            if (obj.toString().indexOf(typeName) === 0) res.push(obj);
        }
        return res;
    }

    TestCase {
        name: "SceneLoader3dPolygons"

        function initTestCase() {
            // SvgReader opens the file with QFile, so it wants a plain path.
            let path = Qt.resolvedUrl("scene_polygons.svg").toString().replace(/^file:\/\//, "");
            _loader.sceneSource = path;
            verify(_loader.loadingFinished, "scene did not finish loading");
        }

        function test_mapExtentsComeFromTheSvg() {
            compare(_stubWorld.xWuMax, _root.mapWidthWu);
            compare(_stubWorld.zWuMax, _root.mapHeightWu);
        }

        // The convention, isolated: scene coordinates are Y-up with the origin
        // at the map's bottom left, the world is Z-down-the-screen from 0 to
        // zWuMax, so y becomes zWuMax - y and x is untouched.
        function test_toWorldRingFlipsYIntoZ() {
            let ring = _loader.toWorldRing([Qt.point(10, 60), Qt.point(40, 60), Qt.point(40, 30)]);
            compare(ring.length, 3);
            compare(ring[0].x, 10); compare(ring[0].y, 20);
            compare(ring[1].x, 40); compare(ring[1].y, 20);
            compare(ring[2].x, 40); compare(ring[2].y, 50);
        }

        // A registered polygon becomes an entity, the way a registered
        // rectangle does - not a signal.
        function test_registeredPolygonIsInstantiated() {
            let areas = entitiesOfType("AreaStub");
            compare(areas.length, 2, "plaza and tower should have been created");
        }

        // The ring lands where the SVG drew it: the plaza is concave, and its
        // notch has to survive the trip.
        function test_registeredPolygonKeepsItsRing() {
            let plaza = entitiesOfType("AreaStub")[0];
            // listToPoints() closes the ring, so the first point comes back last.
            let expected = [[10, 20], [40, 20], [40, 50], [25, 50], [25, 70], [10, 70], [10, 20]];
            compare(plaza.vertices.length, expected.length);
            for (let i = 0; i < expected.length; ++i) {
                compare(plaza.vertices[i].x, expected[i][0], "vertex " + i + " x");
                compare(plaza.vertices[i].y, expected[i][1], "vertex " + i + " y");
            }
        }

        function test_fillColorBecomesTheEntityColor() {
            let plaza = entitiesOfType("AreaStub")[0];
            compare(plaza.color.toString(), "#00d9ff");
        }

        function test_polygonIsLiftedOffTheFloor() {
            let plaza = entitiesOfType("AreaStub")[0];
            compare(plaza.position.y, _loader.polygonGroundLift);
        }

        // Height rides the same "properties" channel every loaded entity has,
        // rather than a mechanism of its own.
        function test_heightComesFromTheDescription() {
            let areas = entitiesOfType("AreaStub");
            compare(areas[0].extrude, 0, "the plaza is a flat area");
            compare(areas[1].extrude, 12, "the tower extrudes per its description");
        }

        // A rectangle and a polygon from the same map have to agree about
        // where the map's Y went: the marker's near edge is the plaza's far
        // edge, both at z = 20.
        function test_rectangleAndPolygonShareTheConvention() {
            let marker = entitiesOfType("MarkerStub")[0];
            verify(marker !== undefined, "the rectangle should have been created");
            compare(marker.position.x, 20);
            compare(marker.position.z, 15);
            compare(marker.depth, 10);
            let markerFarEdge = marker.position.z + 0.5 * marker.depth;
            let plazaNearEdge = entitiesOfType("AreaStub")[0].vertices[0].y;
            compare(markerFarEdge, plazaNearEdge);
        }

        // An unregistered polygon is not dropped: it reaches the world with its
        // scene points untouched, exactly like SceneLoader2d reports it.
        function test_unregisteredPolygonIsReported() {
            compare(_stubWorld.polygonsReported.length, 1);
            let pond = _stubWorld.polygonsReported[0];
            compare(pond.id, "pond");
            compare(pond.fillColor, "#ff3366");
            compare(pond.description, "");
            // Scene coordinates, i.e. Y-up: the SVG drew 60,10 90,10 90,40.
            let expected = [[60, 70], [90, 70], [90, 40], [60, 70]];
            compare(pond.points.length, expected.length);
            for (let i = 0; i < expected.length; ++i) {
                compare(pond.points[i].x, expected[i][0], "point " + i + " x");
                compare(pond.points[i].y, expected[i][1], "point " + i + " y");
            }
        }

        function test_unregisteredPolygonCreatesNoEntity() {
            compare(_stubWorld.created.length, 3, "marker, plaza and tower only");
        }

        // Mapping what the signal reports is the sandbox's job, and the loader
        // spells the conversion out so it is not guesswork.
        function test_reportedPointsMapBackOntoTheRing() {
            let ring = _loader.toWorldRing(_stubWorld.polygonsReported[0].points);
            compare(ring[0].x, 60); compare(ring[0].y, 10);
            compare(ring[2].x, 90); compare(ring[2].y, 40);
        }
    }
}
