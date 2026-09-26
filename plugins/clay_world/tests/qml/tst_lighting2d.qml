// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// LightLayer2d's CPU half: which lights reach the shader, how an occluder
// grid is built, and that lights follow what they are declared in. What the
// shader draws is checked by eye in demo/SandboxLighting2d.qml.

import QtQuick
import QtTest
import Clayground.World

Item {
    id: root
    width: 800; height: 600

    ClayWorld2d {
        id: world
        components: new Map()
        anchors.fill: parent
        xWuMax: 100; yWuMax: 100
        pixelPerUnit: 20
        gravity: Qt.point(0, 0)
        viewPortCenterWuX: 20
        viewPortCenterWuY: 85

        LightLayer2d { id: layer; world: world }
        LightLayer2d { id: other; world: world; active: false }
    }

    Component { id: lightComp; Light2d {} }

    QtObject {
        id: carrier
        property real xWu: 5
        property real yWu: 80
    }

    TestCase {
        name: "Lighting2d"
        when: windowShown

        property var made: []
        function make(props) {
            var l = lightComp.createObject(root, props);
            made.push(l);
            return l;
        }
        function cleanup() {
            for (var i = 0; i < made.length; ++i) made[i].destroy();
            made = [];
            wait(0);
            layer.clearOccluders();
        }

        function test_layerMovesIntoTheCanvas() {
            compare(layer.parent, world.canvas);
        }

        function test_cullsToTheViewport() {
            // View: x 0..40, y 70..100.
            make({xWu: 10, yWu: 90, radius: 5});
            make({xWu: 90, yWu: 10, radius: 5});
            make({xWu: 44, yWu: 90, radius: 5});   // reaches in from the right
            layer._update();
            compare(layer.lightCount, 2);
        }

        function test_disabledLightsAreSkipped() {
            make({xWu: 10, yWu: 90, enabled: false});
            make({xWu: 12, yWu: 90, intensity: 0});
            layer._update();
            compare(layer.lightCount, 0);
        }

        function test_capsAtMaxLights() {
            for (var i = 0; i < 20; ++i)
                make({xWu: 2 + i, yWu: 90, radius: 3 + i * 0.1});
            layer._update();
            compare(layer.lightCount, layer.maxLights);
        }

        function test_layerFilter() {
            make({xWu: 10, yWu: 90, lightLayer: other});
            layer._update();
            compare(layer.lightCount, 0);
        }

        function test_followsTargetAndParent() {
            var l = make({target: carrier, offsetXWu: 1});
            var p = l.positionWu();
            compare(p.x, 6);
            compare(p.y, 80);
            carrier.xWu = 7;
            compare(l.positionWu().x, 8);

            var holder = Qt.createQmlObject(
                'import QtQuick; Item { property real xWu: 30; property real yWu: 75 }', root);
            var child = lightComp.createObject(holder, {});
            compare(child.positionWu().x, 30);
            compare(child.positionWu().y, 75);
            holder.destroy();
        }

        function test_occluderGrid() {
            layer.setOccluderGrid(4, 3, 2, (cx, cy) => cx === 1 && cy === 2, 10, 20);
            verify(layer.isOccluded(13, 25));     // cell (1, 2)
            verify(!layer.isOccluded(11, 25));    // cell (0, 2)
            verify(!layer.isOccluded(13, 23));    // cell (1, 1)
            verify(!layer.isOccluded(0, 0));      // outside the grid
            layer.setOccluderCell(1, 2, false);
            verify(!layer.isOccluded(13, 25));
            var info = layer.clayInspect();
            compare(info.occluderGrid.cols, 4);
            compare(info.occluderGrid.cellSizeWu, 2);
        }

        function test_occluderRects() {
            // A wall body shape: yWu is the top edge.
            layer.setOccluderRects([{xWu: 10, yWu: 50, widthWu: 4, heightWu: 2}], 1);
            verify(layer.isOccluded(10.5, 49.5));
            verify(layer.isOccluded(13.5, 48.5));
            verify(!layer.isOccluded(14.5, 49.5));
            verify(!layer.isOccluded(10.5, 50.5));
            verify(!layer.isOccluded(10.5, 47.5));
        }

        function test_clayInspect() {
            make({xWu: 10, yWu: 90, radius: 5, objectName: "torch"});
            layer._update();
            var info = layer.clayInspect();
            compare(info.type, "LightLayer2d");
            compare(info.lightsDrawn.length, 1);
            compare(info.lightsDrawn[0].objectName, "torch");
            compare(info.occluderGrid, null);
        }
    }
}
