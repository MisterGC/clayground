// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// TransistorInterior3D - the die as a place, not as a picture of a die.
//
// This is the content half of approach 4. The three doped layers are slabs you
// can stand between, the two junctions are marked where they actually are, and
// the carriers move through them as fast as the lab's own currents say - so
// "the base current lets the collector current through" stops being a sentence
// and becomes something happening in front of the learner. Nothing here has a
// timer: `time` comes from the lab clock and every carrier is a pure function
// of it (carriers.js), which is what makes a frozen picture at zero current
// checkable rather than merely claimed.
//
// Geometry is anatomy.js's - the same table the exploded view and the callouts
// build from - at part scale, so the die is ~1.6 units across and the caller
// positions this node with its BOTTOM on the header's top face. Local y 0 is
// that bottom face, which is also the origin carriers.js works in.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "anatomy.js" as Anatomy
import "carriers.js" as Carriers

// The delegates below read the root's own arrays, which is an outer id from
// inside a component. Bound is the legal way to do that - and safe here
// because nothing in a delegate is animated by a Behavior, which is the
// combination that segfaults on a republishing model (see the lab pitfalls).
pragma ComponentBehavior: Bound

Node {
    id: root

    /*! Lab time, in seconds. Bind it to the clock; everything moving reads it. */
    property real time: 0

    /*! Base current, normalised 0..1. Drives the sideways stream. */
    property real baseCurrent: 0

    /*! Collector current, normalised 0..1. Drives the top-to-bottom stream. */
    property real collectorCurrent: 0

    /*! How many carriers are drawn at once, both kinds together. */
    property int carrierCount: 48

    /*! 0 gone .. 1 fully there - what the dive's depth drives. */
    property real reveal: 1

    opacity: root.reveal
    visible: root.reveal > 0.001

    // --- the geometry, from the one table -----------------------------------

    readonly property var stack: Anatomy.dieStack(0)
    readonly property var dims: Carriers.defaultDims()
    readonly property var levels: Carriers.levels(root.dims)
    readonly property real half: root.dims.footprint / 2
    readonly property real isleHalf: root.dims.emitterFootprint / 2

    /*!
        Where the shrunken presenter stands: on the emitter island's top face,
        at its -x edge, so it is beside the fan of carriers rather than in it.
        Scene coordinates.

        Read off a real child node rather than computed with
        mapPositionToScene: that is a function call, and a binding on it would
        never notice the die being moved, while a node's scenePosition is a
        property and notifies.
    */
    readonly property vector3d standPoint: _standAnchor.scenePosition

    Node {
        id: _standAnchor
        position: Qt.vector3d(-root.isleHalf * 0.8, root.levels.top, 0)
    }

    /*!
        The scene point a finger or a mark lands on, for
        emitter | base | collector | junction.eb | junction.bc. An unknown id
        answers NaN rather than the origin, as ExplodedView3D's partAt does.
    */
    function partAt(id) {
        const L = root.levels
        const local = id === "collector" ? Qt.vector3d(0, L.bc * 0.5, 0)
                    : id === "base" ? Qt.vector3d(0, (L.bc + L.eb) * 0.5, 0)
                    : id === "emitter" ? Qt.vector3d(0, (L.eb + L.top) * 0.5, 0)
                    : id === "junction.eb" ? Qt.vector3d(0, L.eb, 0)
                    : id === "junction.bc" ? Qt.vector3d(0, L.bc, 0)
                    : null
        if (!local) return Qt.vector3d(NaN, NaN, NaN)
        return root.mapPositionToScene(local)
    }

    /*!
        The die's two opposite corners in scene coordinates - what a rig fits
        when the camera goes inside.
    */
    function bounds() {
        return [root.mapPositionToScene(Qt.vector3d(-root.half, 0, -root.half)),
                root.mapPositionToScene(Qt.vector3d(root.half, root.levels.top, root.half))]
    }

    // --- the doped layers ---------------------------------------------------
    // Translucent, because the carriers are INSIDE them and a solid slab hides
    // the only thing worth watching.
    //
    // NOT Box3D, which is what the kit's other boxes are: Box3D's material is a
    // CustomMaterial with no blending, so an alpha in its colour is silently
    // ignored and the slabs come out solid (measured - the first render of this
    // file was three opaque bricks). A #Cube with a PrincipledMaterial does
    // blend, so the layers are cubes and the toon outline Box3D would have
    // given them is drawn separately below. #Cube is centred on its origin,
    // unlike Box3D, which is why each slab sits at the MIDDLE of its y range.

    /*!
        How solid the silicon is. Above ~0.65 the carriers stop showing
        through; below ~0.45 the layer stops reading as its own doping,
        because what shows through it is then mostly the layer behind.
    */
    property real siliconAlpha: 0.55

    Repeater3D {
        model: root.stack
        Model {
            id: slab
            required property var modelData
            // n doping is the theme's interactive blue, p its warm accent -
            // the kit's role table, so a layer is the same colour in the
            // exploded view, on the chalkboard and in here.
            readonly property color tone: slab.modelData.doping === "n"
                                        ? LabTheme.secondary : LabTheme.accent
            readonly property real thickness: slab.modelData.y1 - slab.modelData.y0
            source: "#Cube"
            position: Qt.vector3d(0, (slab.modelData.y0 + slab.modelData.y1) / 2, 0)
            scale: Qt.vector3d(slab.modelData.footprint / 100, slab.thickness / 100,
                               slab.modelData.footprint / 100)
            castsShadows: false
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(slab.tone.r, slab.tone.g, slab.tone.b,
                                   root.siliconAlpha)
                alphaMode: PrincipledMaterial.Blend
                roughness: 1; metalness: 0; specularAmount: 0
            }
        }
    }

    // The layer boundaries as solid lines. A translucent box has no outline of
    // its own, and the boundaries ARE the structure: without these the inside
    // of the die is three clouds. One stroke per slab, doubling back up the
    // four verticals - LineInstancing draws segments between consecutive
    // points, so a box is a single path.
    property bool wireEdges: true

    Repeater3D {
        model: root.wireEdges ? root.stack : []
        BoxLine3D {
            id: frame
            required property var modelData
            readonly property real fh: frame.modelData.footprint / 2
            readonly property real y0: frame.modelData.y0
            readonly property real y1: frame.modelData.y1
            width: 0.014
            // A contrast step away from the room, so the outline survives a
            // dark theme as well as a light one.
            color: frame.modelData.doping === "n"
                 ? LabTheme.step(LabTheme.secondary, 1.25)
                 : LabTheme.step(LabTheme.accent, 1.25)
            positions: [
                Qt.vector3d(-frame.fh, frame.y0, -frame.fh),
                Qt.vector3d(frame.fh, frame.y0, -frame.fh),
                Qt.vector3d(frame.fh, frame.y0, frame.fh),
                Qt.vector3d(-frame.fh, frame.y0, frame.fh),
                Qt.vector3d(-frame.fh, frame.y0, -frame.fh),
                Qt.vector3d(-frame.fh, frame.y1, -frame.fh),
                Qt.vector3d(frame.fh, frame.y1, -frame.fh),
                Qt.vector3d(frame.fh, frame.y0, -frame.fh),
                Qt.vector3d(frame.fh, frame.y1, -frame.fh),
                Qt.vector3d(frame.fh, frame.y1, frame.fh),
                Qt.vector3d(frame.fh, frame.y0, frame.fh),
                Qt.vector3d(frame.fh, frame.y1, frame.fh),
                Qt.vector3d(-frame.fh, frame.y1, frame.fh),
                Qt.vector3d(-frame.fh, frame.y0, frame.fh),
                Qt.vector3d(-frame.fh, frame.y1, frame.fh),
                Qt.vector3d(-frame.fh, frame.y1, -frame.fh)
            ]
        }
    }

    // --- the two junctions --------------------------------------------------
    // Thin plates straddling the interfaces they mark, a touch wider than the
    // layer above so the line is visible from inside. The E-B junction is only
    // as wide as the island - which is the reason the island is small, and
    // worth being able to see.

    // A RING at the interface, not a plate across it. A filled plate is the
    // obvious shape and it is the wrong one: an opaque ceiling inside a box
    // seen from 18 degrees above hides almost the whole interior beneath it,
    // and the first dive lost sixteen of the nineteen carriers that were in
    // the collector at the time (counted through carrierPos, which is what
    // caught it - they were in the array and not in the picture).
    component Junction: BoxLine3D {
        id: junc
        property real atY: 0
        property real span: 1
        readonly property real h: junc.span / 2
        width: 0.03
        color: LabTheme.highlight
        positions: [
            Qt.vector3d(-junc.h, junc.atY, -junc.h),
            Qt.vector3d(junc.h, junc.atY, -junc.h),
            Qt.vector3d(junc.h, junc.atY, junc.h),
            Qt.vector3d(-junc.h, junc.atY, junc.h),
            Qt.vector3d(-junc.h, junc.atY, -junc.h)
        ]
    }

    Junction {
        objectName: "junction.bc"
        atY: root.levels.bc
        span: root.dims.footprint * 1.02
    }
    Junction {
        objectName: "junction.eb"
        atY: root.levels.eb
        span: root.dims.emitterFootprint * 1.04
    }

    // --- the contacts -------------------------------------------------------
    // Where the current gets in: a metal pad on the emitter island's top face
    // and one on the base layer's +x edge, which is the side carriers.js sends
    // the base stream in from. Both half-buried, so they read as bonded to the
    // silicon rather than as bricks resting on it.

    Box3D {                        // the emitter contact
        objectName: "contact.emitter"
        position: Qt.vector3d(0, root.levels.top - 0.03, 0)
        width: root.dims.emitterFootprint * 0.4
        depth: root.dims.emitterFootprint * 0.4
        height: 0.09
        color: LabTheme.muted
        useToonShading: true
        edgeColorFactor: 0.55
        castsShadows: false
    }

    Box3D {                        // the base contact
        objectName: "contact.base"
        position: Qt.vector3d(root.half, root.levels.bc + 0.02, 0)
        width: 0.22
        depth: 0.42
        height: root.dims.layers.base * 0.8
        color: LabTheme.muted
        useToonShading: true
        edgeColorFactor: 0.55
        castsShadows: false
    }

    // --- the carriers -------------------------------------------------------
    // The model is the count, not the array: Repeater3D copies plain-JS model
    // objects, so a delegate that was handed a position object would keep
    // showing the position it was created with. Indexing back into the root's
    // own array through the count is the shape that survives (see the lab
    // pitfalls, "Repeater3D COPIES").

    // The tracks the carriers ride, drawn as faint lines. A still picture of
    // moving dots is a picture of dots: with the paths under them the same
    // frame reads as a current going somewhere, and the fan - many streams
    // from a small island spreading into a wide collector - becomes visible
    // instead of having to be inferred from one frozen frame.
    property bool showPaths: true

    Repeater3D {
        model: root.showPaths ? Carriers.paths(root.dims) : []
        BoxLine3D {
            id: track
            required property var modelData
            // Neutral and thin: a track in the carrier's own colour reads as a
            // pin through the dot rather than as the way it came.
            width: 0.005
            color: LabTheme.inkFaint
            positions: track.modelData.points.map(p => Qt.vector3d(p.x, p.y, p.z))
        }
    }

    /*!
        Every carrier's die-local position, recomputed whenever time or a
        current changes. Read by the delegates and by a check: this is the
        numeric seam for "did anything move?".
    */
    readonly property var carrierPos: Carriers.carriersAt(
        root.time, root.baseCurrent, root.collectorCurrent, root.carrierCount)

    /*! How big one carrier is drawn, in units. */
    property real carrierSize: 0.07

    Repeater3D {
        model: root.carrierCount
        Model {
            id: dot
            required property int index
            readonly property var carrier: root.carrierPos[dot.index]
            source: "#Sphere"
            position: dot.carrier ? Qt.vector3d(dot.carrier.x, dot.carrier.y, dot.carrier.z)
                                  : Qt.vector3d(0, 0, 0)
            visible: dot.carrier !== undefined
            // #Sphere is 100 units across, so this is carrierSize in units.
            scale: Qt.vector3d(root.carrierSize / 100, root.carrierSize / 100,
                               root.carrierSize / 100)
            castsShadows: false
            materials: PrincipledMaterial {
                // Unlit on purpose: these are charge, not beads. Lit spheres
                // inside a translucent box come out as grey pebbles.
                lighting: PrincipledMaterial.NoLighting
                // Each kind is its own layer's colour pushed away from it: a
                // base carrier drawn in plain `accent` disappears into the
                // accent-coloured base it is crossing (measured - the first
                // pass lost every sideways carrier in the P layer).
                // `step` is a CONTRAST step, not a brightening: it divides
                // the lightness on a light theme and multiplies it on a dark
                // one, so one number pushes a carrier away from its layer in
                // both (measured - 0.7 made the base carriers paler than the
                // base they cross, which is the wrong way in a light room).
                baseColor: dot.carrier && dot.carrier.kind === "b"
                         ? LabTheme.step(LabTheme.accent, 1.45)
                         : LabTheme.step(LabTheme.secondary, 1.55)
            }
        }
    }
}
