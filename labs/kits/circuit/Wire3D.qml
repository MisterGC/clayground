// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

// A wire drawn as real tube geometry: one cylinder per polyline segment.
//
// MultiLine3D would be cheaper (one instanced draw call), but its ribbons
// are camera-facing quads with an unshaded material, which the shadow pass
// skips - so a line batch can never drop a shadow. A handful of wires as
// actual tubes is worth the draw calls: they cast and receive real shadows
// and they still read as round from a grazing camera angle.
Node {
    id: root

    property var points: []          // array of vector3d along the wire
    property color color: "#555555"
    property real radius: 0.3

    // segments overlap slightly so the joints do not open up on tight bends
    readonly property real overlap: 1.08

    function _rotationFor(dir) {
        const d = dir.normalized()
        const up = Qt.vector3d(0, 1, 0)
        const dot = Math.max(-1, Math.min(1, up.dotProduct(d)))
        if (dot > 0.999999) return Qt.quaternion(1, 0, 0, 0)
        if (dot < -0.999999) return Quaternion.fromAxisAndAngle(Qt.vector3d(1, 0, 0), 180)
        return Quaternion.fromAxisAndAngle(up.crossProduct(d).normalized(),
                                           Math.acos(dot) * 180 / Math.PI)
    }

    Repeater3D {
        model: Math.max(0, (root.points ? root.points.length : 0) - 1)
        Model {
            id: seg
            readonly property vector3d a: root.points[index]
            readonly property vector3d b: root.points[index + 1]
            readonly property real len: b.minus(a).length()

            source: "#Cylinder"
            position: a.plus(b).times(0.5)
            rotation: root._rotationFor(b.minus(a))
            scale: Qt.vector3d(root.radius * 2 / 100,
                               Math.max(1e-4, seg.len * root.overlap / 100),
                               root.radius * 2 / 100)
            castsShadows: true
            receivesShadows: true
            materials: PrincipledMaterial {
                baseColor: root.color
                roughness: 1.0
                metalness: 0.0
                specularAmount: 0.0
            }
        }
    }
}
