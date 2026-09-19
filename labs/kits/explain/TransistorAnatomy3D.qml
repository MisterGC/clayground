// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "anatomy.js" as Anatomy

// The NPN transistor as a thing that comes apart - the SUBJECT of approach 1,
// where ExplodedView3D is the mechanism.
//
// At spread 0 this is the transistor of labs/kits/circuit/CircuitElement3D.qml,
// pose for pose: the same epoxy cylinder at (0, 1.55, -0.35), the same flat
// facet, the same three legs lying on the board half-way out to the same pads,
// the same printed footprint with C / B / E. That match is the whole mechanism:
// a learner who watches this open must see THE PART coming apart, not a
// different part appearing in its place. Only the working-region collar is left
// out - it says what the part is DOING, which an anatomy lesson is not about.
//
// Everything above the board that the circuit kit does not draw is the inside:
// the metal header on the collector lead, the three-layer die from
// anatomy.js dieStack(), and two bond wires. Those are teaching geometry, not a
// datasheet - a real die is a tenth of this and its layers are microns - and
// anatomy.js says so in its own header.
//
// The two admitted colour literals are the epoxy and the facet: physical part
// colours, the same values the circuit kit pins, not theme roles. Everything
// else comes from the role table.
ExplodedView3D {
    id: root

    /*! Goal, 0..1: how far the epoxy is ghosted so the die shows through it
        without the part having to come apart at all. */
    property real xray: 0

    /*! The interpolant \l xray eases toward, over \c glideMs. */
    readonly property real xrayNow: _xglide.value

    otherAnimating: Math.abs(_xglide.value - root.xray) > 1e-4

    // Physical part colours, not theme roles - the values the circuit kit pins
    // for the same two surfaces.
    readonly property color epoxyColor: "#2a2724"
    readonly property color facetColor: "#332f2b"

    /*! The role-to-colour table of the kit's rule 7. */
    function roleColor(role) {
        switch (role) {
        case "epoxy": return root.epoxyColor
        case "metal": return LabTheme.muted
        case "gold":  return LabTheme.highlight
        case "n":     return LabTheme.secondary
        case "p":     return LabTheme.accent
        case "print": return LabTheme.sheet
        }
        return LabTheme.ink
    }

    // --- the table, lifted -----------------------------------------------------
    // Offset, order and role come from anatomy.js for every part, so a change
    // to the teaching order or to how far a piece travels is a change in ONE
    // file that all four approaches read.

    function offsetOf(id) {
        const o = Anatomy.offsetAt(id, 1)
        return Qt.vector3d(o.x, o.y, o.z)
    }
    function orderOf(id) {
        const p = Anatomy.partById(id)
        return p ? p.order : 0
    }
    function roleOf(id) {
        const p = Anatomy.partById(id)
        return p ? p.role : ""
    }

    // --- where the inside sits -------------------------------------------------
    // The header lies ON the collector lead, so its underside clears the lead's
    // cylinder (centre 0.55, radius 0.16 -> top 0.71) and the die stack starts
    // at the header's top face. Both are derived rather than typed, so widening
    // a leg or thickening the header does not leave the die floating.

    readonly property real legY: 0.55
    readonly property real legRadius: 0.16
    readonly property real headerBottom: root.legY + root.legRadius + 0.04
    readonly property real headerTop: root.headerBottom + Anatomy.HEADER.thickness
    readonly property real axisZ: Anatomy.BODY.centreZ
    readonly property var stack: Anatomy.dieStack(root.headerTop)

    // Flat, glare-free material for the round parts - the circuit kit's.
    component Matte: PrincipledMaterial {
        roughness: 1.0
        metalness: 0.0
        specularAmount: 0.0
    }
    // The same, but able to blend: what the x-ray needs. A CustomMaterial or an
    // Opaque PrincipledMaterial has no alpha to fade, so the epoxy parts are
    // declared blendable from the start rather than switched over at xray > 0 -
    // switching alphaMode recompiles the shader mid-gesture.
    component Ghost: PrincipledMaterial {
        roughness: 1.0
        metalness: 0.0
        specularAmount: 0.0
        alphaMode: PrincipledMaterial.Blend
    }
    // Toon-shaded box with ink edges - the circuit kit's boxes. Origin is the
    // box's BOTTOM-centre, which is why every slab is positioned at its own y0.
    component Slab: Box3D {
        useToonShading: true
        edgeColorFactor: 0.55
    }

    // --- the printed footprint -------------------------------------------------
    // The one thing about a transistor a learner cannot deduce by looking at it:
    // which leg is which. Same plate, same letters, same rules as the circuit
    // kit's - opaque edge to edge, because this material does no alpha blending
    // and a cut corner comes out BLACK; any shaping has to be painted.
    ExplodePart {
        id: _print
        partId: "print"
        role: root.roleOf("print")
        order: root.orderOf("print")
        offset: root.offsetOf("print")
        position: Qt.vector3d(0, 0.52, 0)
        // Beside the B letter, on the near edge: a mark on the middle of the
        // plate lands under the part it is trying to point past.
        anchor: Qt.vector3d(0, 0.03, 3.4)

        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(0.098, 0.098, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    // An Item holding a filled Rectangle, never a Rectangle
                    // used directly as the source. Font sizes here are pixels
                    // in the texture, not UI sizes - the one place a bare
                    // pixelSize is right.
                    sourceItem: Item {
                        width: 240; height: 240
                        // The working sheet's own colour, so only the printed
                        // marks show and the plate reads as ink ON the board.
                        Rectangle { anchors.fill: parent; color: root.roleColor(_print.role) }
                        Rectangle {   // a painted rim, since a cut one goes black
                            anchors.fill: parent
                            anchors.margins: 4
                            color: "transparent"
                            border.color: LabTheme.step(LabTheme.sheet, 1.3)
                            border.width: 3
                        }
                        // Laid out the way the pads are - C left, E right, B on
                        // the near side - each letter BESIDE its pad, never on
                        // it: a pad is a raised dome and a letter under one is a
                        // letter nobody sees. Pin letters, not words.
                        Text {
                            x: 13; y: 58
                            text: "C"; color: LabTheme.inkSoft
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 13
                            y: 58
                            text: "E"; color: LabTheme.inkSoft
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            x: 152
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                            text: "B"; color: LabTheme.inkSoft
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }

    // --- the three legs --------------------------------------------------------
    // Half-way out from the part's centre to each pad, lying flat just above the
    // board, exactly as the circuit kit lays them. A #Cylinder stands along Y,
    // so the two side legs tip onto X and the base leg onto Z. The part's origin
    // is mid-leg, which is also where a fingertip belongs.
    ExplodePart {
        id: _legC
        partId: "leg.collector"
        role: root.roleOf("leg.collector")
        order: root.orderOf("leg.collector")
        offset: root.offsetOf("leg.collector")
        position: Qt.vector3d(Anatomy.PADS.collector.x * 0.5, root.legY,
                              Anatomy.PADS.collector.z * 0.5)
        Model {
            source: "#Cylinder"
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.0032, 0.035, 0.0032)
            materials: Matte { baseColor: root.roleColor(_legC.role) }
        }
    }
    ExplodePart {
        id: _legB
        partId: "leg.base"
        role: root.roleOf("leg.base")
        order: root.orderOf("leg.base")
        offset: root.offsetOf("leg.base")
        position: Qt.vector3d(Anatomy.PADS.base.x * 0.5, root.legY,
                              Anatomy.PADS.base.z * 0.5)
        Model {
            source: "#Cylinder"
            eulerRotation: Qt.vector3d(90, 0, 0)
            scale: Qt.vector3d(0.0032, 0.035, 0.0032)
            materials: Matte { baseColor: root.roleColor(_legB.role) }
        }
    }
    ExplodePart {
        id: _legE
        partId: "leg.emitter"
        role: root.roleOf("leg.emitter")
        order: root.orderOf("leg.emitter")
        offset: root.offsetOf("leg.emitter")
        position: Qt.vector3d(Anatomy.PADS.emitter.x * 0.5, root.legY,
                              Anatomy.PADS.emitter.z * 0.5)
        Model {
            source: "#Cylinder"
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.0032, 0.035, 0.0032)
            materials: Matte { baseColor: root.roleColor(_legE.role) }
        }
    }

    // --- the case and its facet ------------------------------------------------
    // The epoxy blob, and the flat face on the side the base pad is on. Both
    // ghost with the x-ray; both lift clear of the inside at full spread.
    ExplodePart {
        id: _case
        partId: "case"
        role: root.roleOf("case")
        order: root.orderOf("case")
        offset: root.offsetOf("case")
        position: Qt.vector3d(0, Anatomy.BODY.height * 0.5, root.axisZ)
        // Front-top: a ring on the rim reads as "this shell", where a ring on
        // the flank could be on anything behind it.
        anchor: Qt.vector3d(0, Anatomy.BODY.height * 0.5, Anatomy.BODY.radius * 0.67)
        ghost: 1 - root.xrayNow
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(Anatomy.BODY.radius * 2 / 100,
                               Anatomy.BODY.height / 100,
                               Anatomy.BODY.radius * 2 / 100)
            materials: Ghost { baseColor: root.epoxyColor }
        }
    }
    ExplodePart {
        id: _face
        partId: "face"
        role: root.roleOf("face")
        order: root.orderOf("face")
        offset: root.offsetOf("face")
        position: Qt.vector3d(0, Anatomy.BODY.height * 0.5, Anatomy.FACE.centreZ)
        anchor: Qt.vector3d(0, 0, Anatomy.FACE.depth * 0.5)
        ghost: 1 - root.xrayNow
        Model {
            source: "#Cube"
            scale: Qt.vector3d(Anatomy.FACE.width / 100,
                               Anatomy.FACE.height / 100,
                               Anatomy.FACE.depth / 100)
            materials: Ghost { baseColor: root.facetColor }
        }
    }

    // --- the header ------------------------------------------------------------
    // The metal tab the die is soldered onto, and the reason the collector is
    // the substrate: it IS the collector lead, flattened and folded up. Never
    // explained on its own (order 0), but a lesson about the collector layer is
    // wrong without it under the slab.
    ExplodePart {
        id: _header
        partId: "header"
        role: root.roleOf("header")
        order: root.orderOf("header")
        offset: root.offsetOf("header")
        position: Qt.vector3d(0, root.headerBottom, root.axisZ)
        anchor: Qt.vector3d(0, Anatomy.HEADER.thickness, 0)
        Slab {
            width: Anatomy.HEADER.width
            height: Anatomy.HEADER.thickness
            depth: Anatomy.HEADER.depth
            color: root.roleColor(_header.role)
        }
    }

    // --- the die, three slabs --------------------------------------------------
    // N - P - N bottom to top, from anatomy.js dieStack(): the collector is the
    // substrate the whole thing is cut from, the base is the thin filling, the
    // emitter is a small island on top. Each slab's anchor is its TOP-centre, so
    // a ring on "the base" sits on the surface a learner can see rather than
    // buried in the layer below.
    ExplodePart {
        id: _dieC
        partId: "die.collector"
        role: root.roleOf("die.collector")
        order: root.orderOf("die.collector")
        offset: root.offsetOf("die.collector")
        position: Qt.vector3d(0, root.stack[0].y0, root.axisZ)
        anchor: Qt.vector3d(0, root.stack[0].y1 - root.stack[0].y0, 0)
        Slab {
            width: root.stack[0].footprint
            height: root.stack[0].y1 - root.stack[0].y0
            depth: root.stack[0].footprint
            color: root.roleColor(_dieC.role)
        }
    }
    ExplodePart {
        id: _dieB
        partId: "die.base"
        role: root.roleOf("die.base")
        order: root.orderOf("die.base")
        offset: root.offsetOf("die.base")
        position: Qt.vector3d(0, root.stack[1].y0, root.axisZ)
        anchor: Qt.vector3d(0, root.stack[1].y1 - root.stack[1].y0, 0)
        Slab {
            width: root.stack[1].footprint
            height: root.stack[1].y1 - root.stack[1].y0
            depth: root.stack[1].footprint
            color: root.roleColor(_dieB.role)
        }
    }
    ExplodePart {
        id: _dieE
        partId: "die.emitter"
        role: root.roleOf("die.emitter")
        order: root.orderOf("die.emitter")
        offset: root.offsetOf("die.emitter")
        position: Qt.vector3d(0, root.stack[2].y0, root.axisZ)
        anchor: Qt.vector3d(0, root.stack[2].y1 - root.stack[2].y0, 0)
        Slab {
            width: root.stack[2].footprint
            height: root.stack[2].y1 - root.stack[2].y0
            depth: root.stack[2].footprint
            color: root.roleColor(_dieE.role)
        }
    }

    // --- the bond wires --------------------------------------------------------
    // Two gold hairs: emitter island -> emitter lead, exposed base -> base lead.
    // Three straight segments each, arched, because that is the shape a wire
    // bonder leaves and because a straight chord from the die to the lead would
    // cut through the die below it.
    //
    // Both wires are ONE part: what a lesson says about them ("and these two
    // hairs are the only way the outside reaches that chip") is one sentence,
    // and a learner asked to look at half a connection learns nothing.
    ExplodePart {
        id: _wires
        partId: "wires"
        role: root.roleOf("wires")
        order: root.orderOf("wires")
        offset: root.offsetOf("wires")
        position: Qt.vector3d(0, 0, 0)
        // The arch apex of the emitter wire: the highest point of the pair and
        // the only one not hidden behind a slab from most angles.
        anchor: Qt.vector3d(0.55, 2.70, -0.15)

        Repeater3D {
            model: root.wireSegments
            Model {
                id: _seg
                required property var modelData
                source: "#Cylinder"
                position: Qt.vector3d(_seg.modelData.mx, _seg.modelData.my, _seg.modelData.mz)
                rotation: Qt.quaternion(_seg.modelData.qw, _seg.modelData.qx,
                                        _seg.modelData.qy, _seg.modelData.qz)
                scale: Qt.vector3d(0.0016, _seg.modelData.len / 100, 0.0016)
                materials: Matte { baseColor: root.roleColor(_wires.role) }
            }
        }
    }

    // The wires as segments a Repeater3D can draw. Computed once from the die
    // geometry: the paths start on real surfaces (the emitter island's top, the
    // base layer's exposed +z edge) and end on the top of the lead they bond to,
    // so thickening a layer moves the wire with it.
    readonly property var wireSegments: root._buildWires()

    function _buildWires() {
        const eTop = root.stack[2].y1
        const bTop = root.stack[1].y1
        const bEdge = root.axisZ + root.stack[1].footprint * 0.5
        const leadTop = root.legY + root.legRadius + 0.04
        const paths = [
            // emitter island -> up, across, down to the emitter lead
            [[0, eTop, root.axisZ], [0.55, 2.70, -0.15],
             [1.25, 2.10, 0], [1.45, leadTop, 0]],
            // exposed base -> up, over the facet's edge, down to the base lead
            [[0, bTop, bEdge], [0, 2.35, 0.90],
             [0, 1.55, 1.20], [0, leadTop, 1.30]]
        ]
        const segs = []
        for (let p = 0; p < paths.length; ++p)
            for (let i = 0; i + 1 < paths[p].length; ++i)
                segs.push(root._segment(paths[p][i], paths[p][i + 1]))
        return segs
    }

    // One segment as a cylinder: its midpoint, its length, and the rotation that
    // lays a Y-standing cylinder along it. A quaternion from axis and angle
    // rather than euler angles, because the euler ORDER decides the result and
    // getting it wrong is a wire that is nearly right from one side only.
    function _segment(a, b) {
        const dx = b[0] - a[0], dy = b[1] - a[1], dz = b[2] - a[2]
        const len = Math.sqrt(dx * dx + dy * dy + dz * dz)
        // cross((0,1,0), d) = (dz, 0, -dx)
        let ax = dz, az = -dx
        const an = Math.sqrt(ax * ax + az * az)
        if (an < 1e-9) { ax = 1; az = 0 } else { ax /= an; az /= an }
        const ang = Math.acos(Math.max(-1, Math.min(1, dy / Math.max(len, 1e-9))))
        const h = ang * 0.5
        const s = Math.sin(h)
        return { mx: (a[0] + b[0]) * 0.5, my: (a[1] + b[1]) * 0.5,
                 mz: (a[2] + b[2]) * 0.5, len: len,
                 qw: Math.cos(h), qx: ax * s, qy: 0, qz: az * s }
    }

    // The x-ray interpolant, same shape as the base class's spread glide.
    QtObject {
        id: _xglide
        property real value: root.xray
        Behavior on value {
            NumberAnimation { duration: root.glideMs; easing.type: Easing.InOutCubic }
        }
    }
}
