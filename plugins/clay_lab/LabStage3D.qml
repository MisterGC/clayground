// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype LabStage3D
    \inqmlmodule Clayground.Lab
    \brief The ground every 3D lab stands on: an endless sheet of squared
    paper, plus the light rig and the environment that go with it.

    Whatever a lab is about, it starts on the same well-made surface. The stage
    owns the \l environment a lab hands to its \c View3D, the three-light rig
    with its measured shadow tuning, and a ground plane whose raster is
    computed in the fragment shader from world coordinates - millimeter paper
    on the light palette, blueprint on the dark one, one line weight at any
    zoom, dissolving into the sky colour long before the quad runs out. There
    is no image anywhere in it, and no edge to see.

    It also carries the two things a lab has to be able to do with its ground:
    \l worldAt() answers "what world point is under this pixel", and the
    overlay budget below says how far above the plane a flat marking has to sit
    before it stops fighting for the same depth.

    Three labs used to build this themselves - a table Model, a sheet Model, a
    rim, three lights, and between them 585 individual peg Models to draw the
    grid. A lab now wires the whole stage in about ten lines:

    \qml
    import QtQuick3D
    import Clayground.Lab

    View3D {
        id: view3d

        LabStage3D {
            id: stage
            cellSize: root.cell
            gridMode: grid                            // crosses vs dots
            workExtent: Qt.vector2d(root.boardW, root.boardH)
            shadowMapFar: 250                         // measured, per lab
        }
        environment: stage.environment

        OrbitCamera3D { id: rig }
        camera: rig.camera
    }
    \endqml

    \sa GridMode, LabTheme, SelectionFrame3D
*/
Node {
    id: root

    // --- the raster --------------------------------------------------------

    /*!
        \qmlproperty real LabStage3D::cellSize
        \brief Spacing of the fine rules and of the snap cue, in world units.

        Match it to whatever the lab's placement rounds to - it is the raster a
        learner is being shown, so it has to be the raster they land on.
    */
    property real cellSize: 5

    /*!
        \qmlproperty real LabStage3D::majorEvery
        \brief How many cells make one heavy rule. Defaults to 5, as paper does.
    */
    property real majorEvery: 5

    /*!
        \qmlproperty vector2d LabStage3D::rasterOrigin
        \brief A world point that an intersection of the raster sits on.

        Defaults to the origin, which is what a lab whose raster is centred on
        it wants. A board with an even number of cells is not: electronics-101
        has 20 columns of 5, so its pegs land on the half-cells and the crosses
        have to land with them. Any point on the raster does - the shader only
        reads it modulo the cell.
    */
    property vector2d rasterOrigin: Qt.vector2d(0, 0)

    /*!
        \qmlproperty var LabStage3D::gridMode
        \brief The \l GridMode whose mode the surface shows, or a plain bool.

        GridMode itself draws nothing; this is what draws it. While it snaps the
        intersections carry crosses, and when placement is free they carry dots
        - so the board says which mode you are in without being asked. Leave it
        null on a lab with no placement at all and the cue stays at crosses.
    */
    property var gridMode: null

    /*! \qmlproperty bool LabStage3D::snapping \readonly \brief The mode the surface is showing. */
    readonly property bool snapping: {
        if (gridMode === null || gridMode === undefined) return true
        if (typeof gridMode === "boolean") return gridMode
        return gridMode.snap === undefined ? true : gridMode.snap
    }

    /*!
        \qmlproperty vector2d LabStage3D::workExtent
        \brief Full width and depth of the area the lab actually works in.

        The sheet is drawn over it, a quiet rule marks where it ends, the snap
        cue is kept inside it, and the shadow and horizon defaults are sized
        from it. \c {(0, 0)}, the default, means "no boundary": the surface is
        then one continuous table.
    */
    property vector2d workExtent: Qt.vector2d(0, 0)

    /*! \qmlproperty real LabStage3D::workRadius \readonly \brief Half the work area's diagonal. */
    readonly property real workRadius:
        Math.max(1, Math.hypot(workExtent.x, workExtent.y) * 0.5)

    // --- how far it reaches ------------------------------------------------

    /*!
        \qmlproperty real LabStage3D::horizonNear
        \brief Distance from the origin at which the surface starts dissolving.
    */
    property real horizonNear: workRadius * 2.5

    /*!
        \qmlproperty real LabStage3D::horizonFar
        \brief Distance at which it has become the sky exactly.

        Past this the plane is drawn in the environment's own clear colour, so
        where it ends cannot be seen - that is what makes it read as endless
        rather than as a very large table.
    */
    property real horizonFar: workRadius * 7

    // --- line weights, in pixels -------------------------------------------

    /*! \qmlproperty real LabStage3D::minorWidth \brief Fine rule weight, in pixels. */
    property real minorWidth: 1.0
    /*! \qmlproperty real LabStage3D::majorWidth \brief Heavy rule weight, in pixels. */
    property real majorWidth: 1.6
    /*! \qmlproperty real LabStage3D::edgeWidth \brief Work-area boundary weight, in pixels; 0 hides it. */
    property real edgeWidth: 1.6
    /*! \qmlproperty real LabStage3D::cueSize \brief Arm length of a snap cross / diameter of a free dot, in pixels. */
    property real cueSize: 5.0
    /*! \qmlproperty real LabStage3D::cueWidth \brief Stroke weight of the snap cue, in pixels. */
    property real cueWidth: 1.6

    // --- colours -----------------------------------------------------------
    // All from LabTheme, so a mode flip re-themes the ground live. The board
    // roles invert as a whole between the palettes and these follow them: on
    // paper the sky is the brightest thing and the working sheet the darkest,
    // in the dark it is the sheet that lifts. Rules are a step() off the sheet
    // rather than a darker() of it, because there is nothing to darken on a
    // low-key ground - see the header of palette.js.

    /*! \qmlproperty color LabStage3D::sheetColor \brief The working surface. */
    property color sheetColor: LabTheme.sheet
    /*! \qmlproperty color LabStage3D::tableColor \brief Outside the work area. */
    property color tableColor: LabTheme.table
    /*! \qmlproperty color LabStage3D::skyColor \brief What the surface dissolves into - the environment's clear colour. */
    property color skyColor: LabTheme.board
    /*! \qmlproperty color LabStage3D::minorColor \brief The fine rules. */
    property color minorColor: LabTheme.step(LabTheme.sheet, 1.09)
    /*! \qmlproperty color LabStage3D::majorColor \brief The heavy rules. */
    property color majorColor: LabTheme.step(LabTheme.sheet, 1.22)
    /*!
        \qmlproperty color LabStage3D::cueColor
        \brief The snap cue: the peg role, one step further from the paper.

        A peg used to be a solid little tile on an otherwise blank sheet, where
        the plain \c grid role carried it. Here it lands on top of the rules, so
        it needs a step of its own to still read as a mark rather than as a
        thickening of the line it sits on.
    */
    property color cueColor: LabTheme.step(LabTheme.grid, 1.35)
    /*! \qmlproperty color LabStage3D::edgeColor \brief The work-area boundary. */
    property color edgeColor: LabTheme.inkSolid

    /*!
        \qmlproperty real LabStage3D::toneScale
        \brief What the light rig gives back on a flat, upward-facing surface.

        The ground is lit by the same half-lambert rule as the toon objects
        standing on it, and three lights all shining down onto one plane add up
        to more than one - so a paper colour handed over raw comes back white
        and the sheet/table step disappears into the clipping. This divides it
        back out, and it is measured against the palette rather than chosen:
        the plain table region of a render lands on \c LabTheme.table within a
        couple of levels per channel (\c 0.71 puts the table on 230/226/222
        against the palette's 232/228/221). Retune it if \l keyBrightness or
        the fill lights change.
    */
    property real toneScale: 0.71

    // --- the overlay budget ------------------------------------------------
    // What a lab has to know to put a flat marking on this ground without
    // fighting it. depthBias settles which of two tied surfaces is drawn first;
    // it does NOT settle the per-pixel fight, so a marking is LIFTED as well.

    /*!
        \qmlproperty real LabStage3D::overlayMinY
        \readonly
        \brief The lowest a flat overlay may sit and still clear the plane.
    */
    readonly property real overlayMinY: 0.012

    /*!
        \qmlproperty real LabStage3D::overlayMaxY
        \readonly
        \brief The highest it may sit and still read as a marking ON the ground.

        Above this a ribbon starts to float: its shadow-side gap opens up at
        grazing angles and it stops belonging to the surface.
    */
    readonly property real overlayMaxY: 0.12

    /*!
        \qmlproperty real LabStage3D::overlayStep
        \readonly
        \brief Vertical gap between two overlays that must not fight each other.
    */
    readonly property real overlayStep: 0.02

    /*!
        \qmlmethod real LabStage3D::overlayY(int layer)
        \brief Height for the \a layer-th flat overlay, counted from the ground.
    */
    function overlayY(layer) {
        return Math.min(overlayMaxY, overlayMinY + layer * overlayStep)
    }

    /*! \qmlproperty int LabStage3D::overlayMinBias \readonly \brief Lowest sensible \c depthBias for a marking. */
    readonly property int overlayMinBias: 1
    /*! \qmlproperty int LabStage3D::overlayMaxBias \readonly \brief Highest one worth using. */
    readonly property int overlayMaxBias: 10

    // --- the light rig -----------------------------------------------------

    /*!
        \qmlproperty real LabStage3D::shadowMapFar
        \brief How far the shadow volume reaches, measured from the camera.

        It has to cover the scene at maximum zoom-out and no further: the
        cascades spend their texels over whatever it is told to cover, so a
        range set to the horizon buys a blurry smudge instead of a shadow. The
        default is sized from \l workExtent; a lab that has measured its own
        number keeps it.
    */
    property real shadowMapFar: Math.max(200, workRadius * 3.5)

    /*! \qmlproperty real LabStage3D::keyBrightness \brief Strength of the shadow-casting key light. */
    property real keyBrightness: 0.9

    /*!
        \qmlproperty bool LabStage3D::lightsEnabled
        \brief Set false for a lab that brings its own lighting.
    */
    property bool lightsEnabled: true

    /*!
        \qmlproperty SceneEnvironment LabStage3D::environment
        \brief The environment the lab assigns to its \c View3D.

        The clear colour is the sky the ground fades into, so the two have to
        come from the same place or the horizon reappears as a ring.
    */
    property SceneEnvironment environment: SceneEnvironment {
        clearColor: root.skyColor
        backgroundMode: SceneEnvironment.Color
        antialiasingMode: SceneEnvironment.MSAA
    }

    /*!
        \qmlmethod var LabStage3D::worldAt(var view, real mx, real my)
        \brief The point on the ground under viewport pixel (\a mx, \a my).

        Returns a \c vector3d on the y = 0 plane, or null when the ray misses
        the ground entirely (it is aimed at the sky, or something opaque is in
        the way). Mouse editing in a lab goes through here rather than through
        an intersection of its own: the plane is the only pickable thing the
        stage puts in the scene, so what comes back is unambiguous.
    */
    function worldAt(view, mx, my) {
        if (!view) return null
        const res = view.pick(mx, my)
        return (res && res.objectHit === _ground) ? res.scenePosition : null
    }

    /*!
        \qmlproperty Model LabStage3D::ground
        \readonly
        \brief The pick plane itself, for a lab that has to compare hits.
    */
    readonly property alias ground: _ground

    // The plane. Big enough that the horizon fade has finished long before the
    // quad's own edge could come into view, and it casts nothing: a ground that
    // cast shadows would only ever shadow itself, and it would drag the whole
    // shadow volume out to its own size (#Rectangle is 100x100 in XY, so the
    // scale is the size over 100 and the -90 turn lays it into XZ, normal +Y).
    Model {
        id: _ground
        source: "#Rectangle"
        pickable: true
        castsShadows: false
        receivesShadows: true
        eulerRotation.x: -90
        scale: {
            const s = root.horizonFar * 2.6 / 100
            return Qt.vector3d(s, s, 1)
        }
        materials: CustomMaterial {
            property color sheetColor: root.sheetColor
            property color tableColor: root.tableColor
            property color boardColor: root.skyColor
            property color minorColor: root.minorColor
            property color majorColor: root.majorColor
            property color cueColor: root.cueColor
            property color edgeColor: root.edgeColor

            property real cellSize: Math.max(0.001, root.cellSize)
            property vector2d rasterOrigin: root.rasterOrigin
            property real majorEvery: Math.max(1, root.majorEvery)
            property real minorWidth: root.minorWidth
            property real majorWidth: root.majorWidth
            property real edgeWidth: root.edgeWidth
            property real cueArm: root.cueSize
            property real cueWidth: root.cueWidth
            property real cueRadius: root.cueSize * 0.5
            property bool snapping: root.snapping
            property real toneScale: root.toneScale
            property vector2d workHalf: Qt.vector2d(root.workExtent.x * 0.5,
                                                    root.workExtent.y * 0.5)
            property real horizonNear: root.horizonNear
            property real horizonFar: Math.max(root.horizonNear + 1, root.horizonFar)

            vertexShader: "lab_stage.vert"
            fragmentShader: "lab_stage.frag"
            shadingMode: CustomMaterial.Shaded
            cullMode: Material.BackFaceCulling
        }
    }

    // Three soft lights rather than one hard one: a key that casts, a side fill
    // and a low camera-side fill so an unlit face still separates from its
    // neighbour. Nothing in a lab is glossy, so depth comes from value.
    //
    // The shadow knobs are measured, not chosen: shadowBias 3 works, 10 or more
    // pushes a thin shadow off the surface and 0 floods it with acne - and both
    // failures look like "no shadows" from across the room.
    DirectionalLight {
        id: _key
        visible: root.lightsEnabled
        eulerRotation.x: -36
        eulerRotation.y: -26
        brightness: root.keyBrightness
        ambientColor: LabTheme.ambient3d
        castsShadow: true
        shadowFactor: LabTheme.shadowFactor
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
        shadowMapFar: root.shadowMapFar
        csmNumSplits: 2
        shadowBias: 3
        softShadowQuality: Light.PCF4
        pcfFactor: 1
    }
    DirectionalLight {
        visible: root.lightsEnabled
        eulerRotation.x: -60
        eulerRotation.y: 142
        brightness: 0.35
    }
    DirectionalLight {
        visible: root.lightsEnabled
        eulerRotation.x: -24
        eulerRotation.y: 19
        brightness: 0.27
    }
}
