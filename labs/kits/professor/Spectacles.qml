// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Spectacles - wire, glass, and the two arms that make it read as an object
// somebody put on rather than a decal painted on the face.
//
// Everything is placed from the head's eye and nose geometry (recomputed here
// from the same dimensions Head.qml uses), not from numbers that happened to
// look right once. Change eyeSize, noseSize or the head dimensions and the
// glasses land on the eyes again by themselves.
//
// Like Beard, it parents itself to the head node so it turns with the face.
//
// The rims are rings of small boxes rather than curves: at twelve segments a
// ring reads as round while staying the same faceted, edge-lined thing the
// rest of the character is made of.

import QtQuick
import QtQuick3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Node {
    id: root

    /*! The Character to put them on. null leaves them inert - nothing drawn. */
    property var character: null

    /*! The wire: rims, bridge and arms. */
    property color frameTone: "#2f3437"

    /*! The glass. Expected to carry an alpha - solid lenses hide the eyes. */
    property color lensTone: "#33cfe8ef"

    /*! Lens size relative to the eyes. 1.0 already overhangs them a little. */
    property real size: 1.0

    /*! How far down the nose they have slipped. 0 on the eyes, 1 at its tip. */
    property real slip: 0.15

    // --- what they sit on ----------------------------------------------------

    readonly property var _head: (root.character !== null && root.character !== undefined)
                                 ? root.character.head : null

    parent: root._head
    visible: root._head !== null

    readonly property real _uw: root._head ? root._head.upperHeadWidth : 0
    readonly property real _uh: root._head ? root._head.upperHeadHeight : 0
    readonly property real _ud: root._head ? root._head.upperHeadDepth : 0
    readonly property real _lh: root._head ? root._head.lowerHeadHeight : 0

    // Head.qml pushes both head boxes this far forward of the head node, and
    // the upper head starts just under a full jaw height up.
    readonly property real _zOff: root._head ? root._head.depth * 0.09 : 0
    readonly property real _upperBase: root._lh * 0.99
    readonly property real _faceZ: _zOff + root._ud * 0.5

    // The eyes, as Head.qml places them: two cubes of this width, one width
    // out from the centre line, sitting on the front face.
    readonly property real _eyeW: root._uw * 0.22 * (root._head ? root._head.eyeSize : 1)
    readonly property real _eyeX: _eyeW
    readonly property real _eyeY: _upperBase + 0.3 * root._uh + _eyeW * 0.5

    // The nose hangs off the eye line; its underside is how far down the
    // glasses can slip before they fall off.
    readonly property real _noseH: root._uh * 0.2 * (root._head ? root._head.noseSize : 1)
    readonly property real _noseBottom: _upperBase + 0.3 * root._uh - 1.1 * _noseH

    readonly property real _lensY: _eyeY - root.slip * (_eyeY - _noseBottom)
    readonly property real _lensR: Math.max(0.001, _eyeW * 0.85 * root.size)
    // Clear of the EYE boxes, not just of the face: the eyes are cubes as deep
    // as they are wide and they stand proud of the skull, so a rim placed off
    // the face plane has its top arc swallowed by them. The nose still pokes
    // through the plane, which is what resting on a nose looks like.
    readonly property real _lensZ: _faceZ + _eyeW * 0.5 + root._ud * 0.04
    readonly property real _gauge: Math.max(0.0005, root._uw * 0.03 * root.size)
    // Where the rims actually sit. On the eyes until the lenses get big enough
    // to collide over the nose, then pushed apart - two rims crossing in the
    // middle of a face reads as a mistake, not as large glasses.
    readonly property real _lensX: Math.max(_eyeX, _lensR * 1.08)

    // The ear the arm reaches for: Head.qml puts it at 0.55 head widths out,
    // a quarter of the head height tall, centred on the head's depth.
    readonly property real _earX: 0.55 * root._uw
    readonly property real _earTopY: _upperBase + 0.3 * root._uh + 0.22 * root._uh
    readonly property real _earZ: _zOff + 0.06 * root._ud

    // The side hair is a slab straddling the skull's side face, and it is deep
    // enough to swallow the whole temple. An arm routed straight to the ear
    // disappears into it, so the arm is pushed to whichever is further out -
    // the ear, or the hair.
    readonly property real _hairOut: root._uw * (0.5 + 0.1 * (root._head ? root._head.hairVolume : 0))
    readonly property real _armX: Math.max(_earX + 0.09 * root._uh, _hairOut + _gauge)

    // --- pieces --------------------------------------------------------------

    // A straight run of wire between two points. The maths is here once so the
    // bridge and both arms are one-liners: Quick3D applies eulerRotation as
    // Ry*Rx*Rz, so yaw and pitch come straight off the direction vector, and
    // the box origin (bottom-centre, not centre) is backed out afterwards.
    component Wire: BodyPart {
        id: _wire
        property vector3d from: Qt.vector3d(0, 0, 0)
        property vector3d to: Qt.vector3d(0, 0, 0)
        readonly property vector3d _d: _wire.to.minus(_wire.from)
        readonly property real _len: _wire._d.length()
        readonly property vector3d _u: _wire._len > 1e-9 ? _wire._d.times(1 / _wire._len)
                                                         : Qt.vector3d(0, 0, 1)
        readonly property real _pitch: -Math.asin(Math.max(-1, Math.min(1, _wire._u.y)))
        readonly property real _yaw: Math.atan2(_wire._u.x, _wire._u.z)

        color: root.frameTone
        showEdges: false
        castsShadows: false
        width: root._gauge
        height: root._gauge
        depth: Math.max(0.001, _wire._len)
        baseEuler: Qt.vector3d(_wire._pitch * 180 / Math.PI,
                               _wire._yaw * 180 / Math.PI,
                               0)
        basePos: _wire.from.plus(_wire.to).times(0.5).minus(
                     Qt.vector3d(0.5 * _wire.height * Math.sin(_wire._pitch) * Math.sin(_wire._yaw),
                                 0.5 * _wire.height * Math.cos(_wire._pitch),
                                 0.5 * _wire.height * Math.sin(_wire._pitch) * Math.cos(_wire._yaw)))
    }

    // One rim plus its glass, centred on the node's own origin.
    component Lens: Node {
        id: _lens
        readonly property int segs: 12
        // Overlapped a touch so the corners of the ring meet instead of
        // leaving twelve pinholes of skin.
        readonly property real chord: 2 * root._lensR * Math.tan(Math.PI / _lens.segs) * 1.12

        Repeater3D {
            model: _lens.segs

            BodyPart {
                id: _seg
                required property int index
                readonly property real a: _seg.index * 2 * Math.PI / _lens.segs
                color: root.frameTone
                showEdges: false
                castsShadows: false
                width: root._gauge
                depth: root._gauge
                height: _lens.chord
                baseEuler: Qt.vector3d(0, 0, _seg.a * 180 / Math.PI)
                basePos: Qt.vector3d(root._lensR * Math.cos(_seg.a)
                                     + 0.5 * _seg.height * Math.sin(_seg.a),
                                     root._lensR * Math.sin(_seg.a)
                                     - 0.5 * _seg.height * Math.cos(_seg.a),
                                     0)
            }
        }

        // Plain PrincipledMaterial rather than the toon Box3D everything else
        // is made of: Box3D's custom material declares no blending, so an
        // alpha in lensTone would come back fully opaque and the professor
        // would be wearing two coins.
        Model {
            source: "#Cube"
            castsShadows: false
            scale: Qt.vector3d(root._lensR * 2 / 100,
                               root._lensR * 2 / 100,
                               root._gauge * 0.4 / 100)
            materials: PrincipledMaterial {
                baseColor: root.lensTone
                alphaMode: PrincipledMaterial.Blend
                lighting: PrincipledMaterial.NoLighting
            }
        }
    }

    Lens { x: -root._lensX; y: root._lensY; z: root._lensZ }
    Lens { x: root._lensX; y: root._lensY; z: root._lensZ }

    // Bridge, across the top of the gap the two rims leave over the nose.
    Wire {
        from: Qt.vector3d(-root._lensX + root._lensR * 0.62,
                          root._lensY + root._lensR * 0.42, root._lensZ)
        to: Qt.vector3d(root._lensX - root._lensR * 0.62,
                        root._lensY + root._lensR * 0.42, root._lensZ)
    }

    // Arms, leaving the outer rim and running back past the skull to the ear.
    Wire {
        from: Qt.vector3d(-(root._lensX + root._lensR * 0.92),
                          root._lensY + root._lensR * 0.30, root._lensZ)
        to: Qt.vector3d(-root._armX, root._earTopY, root._earZ)
    }

    Wire {
        from: Qt.vector3d(root._lensX + root._lensR * 0.92,
                          root._lensY + root._lensR * 0.30, root._lensZ)
        to: Qt.vector3d(root._armX, root._earTopY, root._earZ)
    }
}
