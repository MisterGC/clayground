// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// What fill() hands down to the voxel store, for every colour spelling it
// accepts.
//
// fill() used to run its normalizer only on the compact array form; the object
// form passed `colors` straight through (#178). So the two forms disagreed
// about what they accepted: `colors: someColor` threw from the object form and
// worked from the compact one, `colors: ["#fff"]` reached the store as a shape
// it drops on the floor, and a record without a `weight` was silently ignored.
// The cases here assert both forms produce the same [{ color, weight }] list.
//
// The store is a recorder rather than the real thing: `import ".."` picks up
// the plugin's QML sources directly, so the suite needs no compiled plugin and
// runs anywhere qmltestrunner does. What the C++ side then does with a QColor
// variant is tst_voxelmapdata.cpp's business.

import QtQuick
import QtTest
import ".."

Item {
    id: root
    width: 50; height: 50

    // The shape that broke: a colour reaching fill() through a property.
    property color boundColor: "#00d9ff"

    // Stands in for VoxelMapInstancing / VoxelMapGeometry - records the
    // distribution it was handed instead of painting anything.
    QtObject {
        id: store
        property string call: ""
        property var colors: null

        function fillSphere(x, y, z, r, colorDistribution, noise) {
            call = "sphere"; colors = colorDistribution
        }
        function fillCylinder(x, y, z, r, h, colorDistribution, noise) {
            call = "cylinder"; colors = colorDistribution
        }
        function fillBox(x, y, z, w, h, d, colorDistribution, noise) {
            call = "box"; colors = colorDistribution
        }
        function commit() {}
    }

    VoxelMap {
        id: map
        model: store
        voxelCountX: 4; voxelCountY: 4; voxelCountZ: 4
    }

    TestCase {
        name: "VoxelFillColors"

        function sameColor(a, b) {
            return Math.abs(a.r - b.r) < 1e-3 && Math.abs(a.g - b.g) < 1e-3
                && Math.abs(a.b - b.b) < 1e-3 && Math.abs(a.a - b.a) < 1e-3
        }

        // Whatever spelling went in, a { color, weight } list comes out and
        // each colour still reads as the colour that was asked for.
        function checkNormalized(entries, expected, tag) {
            verify(Array.isArray(entries), tag + ": not a list - " + entries)
            compare(entries.length, expected.length, tag + ": entry count")
            for (let i = 0; i < expected.length; ++i) {
                const got = Qt.color(entries[i].color)
                verify(sameColor(got, expected[i].color),
                       tag + " [" + i + "]: color " + got + " wanted " + expected[i].color)
                compare(entries[i].weight, expected[i].weight, tag + " [" + i + "]: weight")
            }
        }

        function test_fill_normalizes_every_color_spelling_data() {
            const cyan = Qt.color("#00d9ff")
            const pink = Qt.color("#ff3366")
            return [
                // The shape from the issue - a colour VALUE in a record.
                { tag: "value in a record", colors: [{ color: root.boundColor, weight: 1.0 }],
                  expected: [{ color: cyan, weight: 1.0 }] },
                { tag: "string in a record", colors: [{ color: "#00d9ff", weight: 1.0 }],
                  expected: [{ color: cyan, weight: 1.0 }] },
                { tag: "record without a weight", colors: [{ color: root.boundColor }],
                  expected: [{ color: cyan, weight: 1 }] },
                { tag: "Qt.rgba value", colors: [{ color: Qt.rgba(0, 217 / 255, 1, 1), weight: 1.0 }],
                  expected: [{ color: cyan, weight: 1.0 }] },
                // Shorthands.
                { tag: "bare string", colors: "#00d9ff", expected: [{ color: cyan, weight: 1 }] },
                { tag: "bare value", colors: root.boundColor, expected: [{ color: cyan, weight: 1 }] },
                { tag: "list of one string", colors: ["#00d9ff"], expected: [{ color: cyan, weight: 1 }] },
                { tag: "list of one value", colors: [root.boundColor], expected: [{ color: cyan, weight: 1 }] },
                { tag: "list of values", colors: [root.boundColor, "#ff3366"],
                  expected: [{ color: cyan, weight: 1 }, { color: pink, weight: 1 }] },
                { tag: "value and weight pair", colors: [root.boundColor, 0.5],
                  expected: [{ color: cyan, weight: 0.5 }] },
                { tag: "list of pairs", colors: [[root.boundColor, 0.25], ["#ff3366", 0.75]],
                  expected: [{ color: cyan, weight: 0.25 }, { color: pink, weight: 0.75 }] },
                { tag: "records with weights",
                  colors: [{ color: "#00d9ff", weight: 0.25 }, { color: root.boundColor, weight: 0.75 }],
                  expected: [{ color: cyan, weight: 0.25 }, { color: cyan, weight: 0.75 }] }
            ]
        }

        // THE REGRESSION: object form and compact form must agree, on every
        // shape and for all three primitives.
        function test_fill_normalizes_every_color_spelling(data) {
            map.fill([{ box: { pos: Qt.vector3d(0, 0, 0), width: 4, height: 4, depth: 4,
                               colors: data.colors } }])
            compare(store.call, "box")
            checkNormalized(store.colors, data.expected, "object box: " + data.tag)

            map.fill([["box", [0, 0, 0, 4, 4, 4, data.colors]]])
            compare(store.call, "box")
            checkNormalized(store.colors, data.expected, "compact box: " + data.tag)

            map.fill([{ sphere: { pos: Qt.vector3d(2, 2, 2), radius: 2, colors: data.colors } }])
            compare(store.call, "sphere")
            checkNormalized(store.colors, data.expected, "object sphere: " + data.tag)

            map.fill([["sphere", [2, 2, 2, 2, data.colors]]])
            compare(store.call, "sphere")
            checkNormalized(store.colors, data.expected, "compact sphere: " + data.tag)

            map.fill([{ cylinder: { pos: Qt.vector3d(2, 0, 2), radius: 2, height: 4,
                                    colors: data.colors } }])
            compare(store.call, "cylinder")
            checkNormalized(store.colors, data.expected, "object cylinder: " + data.tag)

            map.fill([["cylinder", [2, 0, 2, 2, 4, data.colors]]])
            compare(store.call, "cylinder")
            checkNormalized(store.colors, data.expected, "compact cylinder: " + data.tag)
        }

        // No colours named at all still has to reach the store in one piece.
        function test_the_default_color_survives_normalization() {
            map.fill([{ box: { pos: Qt.vector3d(0, 0, 0), width: 4, height: 4, depth: 4 } }])
            checkNormalized(store.colors, [{ color: Qt.color("transparent"), weight: 1.0 }],
                            "no colors given")
        }
    }
}
