// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D

/*!
    \qmltype PathLabel3D
    \inqmlmodule Clayground.Canvas3D
    \brief Street-name style text laid flat on the ground, following a line.

    PathLabel3D writes \l text along a line of a \l LineBatch3D, the way a map
    paints a street name onto a road. It splits the text into words and places
    each word as a flat, unlit quad tangent to the path, so the label bends with
    the curve. The quads carry the words as 2x-oversampled textures, which stay
    crisp under the top-down/tactical cameras these labels are made for.

    Placement rides the line's own geometry via \l{LineBatch3D::pathLength}
    {pathLength()} and \l{LineBatch3D::positionAt}{positionAt()}: the label
    centers on the path distance \l at (or the middle of the path when \l at is
    negative), and \l repeatEvery stamps the same name at a fixed spacing along a
    long road. To keep the name from ever appearing upside-down, PathLabel3D makes
    a single flip-to-read decision per placement from the placement's dominant
    direction and applies it to every word of that placement.

    The placement is computed on demand - once, whenever an input changes - and
    then stays put. There is no per-frame tick: the quads are static geometry
    until \l lines, \l lineId, \l at, \l text or a sizing property changes.

    By default PathLabel3D places one texture quad per word (cheap, bends at word
    boundaries). Set \l glyphPlacement to \c true for per-glyph text-on-curve
    (maplibre's model): the text is shaped once and each glyph is placed and
    rotated individually so the baseline hugs tight bends, rendered through an
    internal \l LabelBatch3D that is created lazily so word-mode labels pay for no
    SDF atlas.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        LineBatch3D { id: roads }

        PathLabel3D {
            lines: roads
            lineId: 0
            text: "CLAY STREET"
            worldHeight: 30
            repeatEvery: 900
        }
    }
    \endqml

    \sa LineBatch3D, Label3D, LabelBatch3D
*/
Node {
    id: root

    /*!
        \qmlproperty QtObject PathLabel3D::lines
        \brief The LineBatch3D whose geometry the label follows.

        The label reads \c{lines.pathLength(lineId)} and
        \c{lines.positionAt(lineId, d)} to place its words; it never modifies the
        batch.
    */
    property var lines: null

    /*!
        \qmlproperty int PathLabel3D::lineId
        \brief Index of the line inside \l lines to run the text along.
    */
    property int lineId: 0

    /*!
        \qmlproperty string PathLabel3D::text
        \brief The label text; split on whitespace into per-word quads.
    */
    property string text: ""

    /*!
        \qmlproperty real PathLabel3D::at
        \brief Path distance (world units) the label centers on.

        A negative value (the default) auto-centers the label on the middle of
        the path. With \l repeatEvery set, this is the distance of the first
        placement.
    */
    property real at: -1

    /*!
        \qmlproperty real PathLabel3D::repeatEvery
        \brief Spacing in world units between repeated placements (0 = single).

        When positive, the same name is stamped every \c repeatEvery units along
        the path, each placement deciding its own flip-to-read orientation - the
        street-name-repeated-along-a-road look.
    */
    property real repeatEvery: 0

    /*!
        \qmlproperty real PathLabel3D::worldHeight
        \brief Text height in world units; the quad width follows the text aspect.
    */
    property real worldHeight: 30

    /*!
        \qmlproperty real PathLabel3D::wordSpacing
        \brief Gap in world units between consecutive words. Negative auto-derives
        it from \l worldHeight.
    */
    property real wordSpacing: -1

    /*!
        \qmlproperty real PathLabel3D::groundOffset
        \brief Height in world units the quads sit above y=0 to avoid z-fighting.
    */
    property real groundOffset: 0.5

    /*!
        \qmlproperty real PathLabel3D::oversample
        \brief Texture oversample factor for crispness (2 renders at 2x texels).
    */
    property real oversample: 2

    /*!
        \qmlproperty vector2d PathLabel3D::readingDirection
        \brief Reference reading direction in the ground (X, Z) plane.

        A placement whose dominant direction points into the opposite half-plane
        (a negative dot with this vector) is flipped 180 degrees about the quad
        normal so the text reads the right way up. The default favours the +X/+Z
        half-plane.
    */
    property vector2d readingDirection: Qt.vector2d(1, 1)

    /*!
        \qmlproperty QtObject PathLabel3D::labelStyle
        \brief Grouped ground-paint styling: color, halo, optional background, font.

        \table
        \header \li Sub-property \li Meaning
        \row \li \c textColor       \li Text color (white default).
        \row \li \c halo            \li Whether the text gets an outline halo (on by default).
        \row \li \c haloColor       \li Halo color (dark default).
        \row \li \c background      \li Whether a filled pill sits behind the text (off by default - ground paint rarely wants one).
        \row \li \c backgroundColor \li Background fill color when \c background is on.
        \row \li \c fontFamily      \li Text font family.
        \row \li \c fontSize        \li Source font pixel size (before oversample); drives texel density and aspect.
        \row \li \c bold            \li Whether the text is bold.
        \row \li \c paddingH        \li Horizontal padding in source pixels.
        \row \li \c paddingV        \li Vertical padding in source pixels.
        \endtable

        \note Layout-affecting changes (\c fontSize, \c paddingH, \c paddingV,
        \c bold, \c fontFamily) alter word aspect, so set them before the label
        completes or call \l rebuild() afterwards.
    */
    property PathLabelStyle labelStyle: PathLabelStyle {}

    /*!
        \qmlproperty int PathLabel3D::uniqueTextureCount
        \brief Number of distinct word textures currently in use (read-only).

        One oversampled texture is shared by every placement of the same word, so
        a repeated "CLAY STREET" costs two textures, not two per repeat.

        \note Only meaningful in the default per-word texture mode; it is 0 in
        \l glyphPlacement mode, which draws no word textures.
    */
    readonly property int uniqueTextureCount: root._wordGroups.length

    /*!
        \qmlproperty bool PathLabel3D::glyphPlacement
        \brief Selects per-glyph text-on-curve placement instead of per-word quads.

        \list
        \li \c false (default): each whitespace-separated word is drawn as one
            flat 2x-oversampled texture quad tangent to the path - the classic,
            cheap street-name look. Bends happen at word boundaries only.
        \li \c true: the text is shaped once into glyphs and each glyph is placed
            and rotated individually along the curve (maplibre's model), so the
            baseline hugs tight bends smoothly. Rendering routes through an
            internal \l LabelBatch3D created lazily on first use - with
            \c glyphPlacement \c false no glyph batch or SDF atlas is ever
            allocated (pay-per-use).
        \endlist

        The two modes share \l at, \l repeatEvery and auto-centering semantics
        exactly. \l worldHeight, \l groundOffset and the \l labelStyle text color
        and halo carry across; a background pill (\c labelStyle.background) is not
        supported in glyph mode v1.

        \note Magnification differs by carrier: word mode packs each word into a
        2x-oversampled raster texture, crisp down to roughly that oversample;
        glyph mode bakes an SDF atlas once and stays crisp at any zoom, at the
        cost of one atlas plus a per-glyph instance.
    */
    property bool glyphPlacement: false

    /*!
        \qmlproperty int PathLabel3D::skippedPlacements
        \brief Number of placements skipped by the curvature guard (read-only).

        In \l glyphPlacement mode a placement whose baseline would wrap too sharp
        an arc (a hairpin tighter than the label can follow) is dropped rather
        than drawn mirrored or overlapping; this counts how many were skipped on
        the last rebuild.
    */
    readonly property int skippedPlacements: root._skipped

    /*!
        \qmlproperty bool PathLabel3D::glyphBatchActive
        \brief Whether the lazy internal glyph batch currently exists (read-only).

        \c false whenever \l glyphPlacement is \c false - proof that word-mode
        labels allocate no glyph batch or atlas (the pay-per-use guarantee).
    */
    readonly property bool glyphBatchActive: _glyphRepeater.count > 0

    // Lean ground-paint style. Inline component so the sub-property set is
    // statically known (grouped assignment and qmllint both resolve it).
    component PathLabelStyle: QtObject {
        property color textColor: "#ffffff"
        property bool halo: true
        property color haloColor: "#000000"
        property bool background: false
        property color backgroundColor: "#cc16213e"
        property string fontFamily: root.monoFont
        property int fontSize: 40
        property bool bold: true
        property real paddingH: 8
        property real paddingV: 4
    }

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Texture-cache cap: each unique oversampled word costs ~260 KB, so a label
    // fed dynamically changing text could otherwise grow memory without bound.
    // A rebuild replaces the whole set with only the words in the current text,
    // and this cap keeps even a single pathological label to N textures at once
    // (oldest-first eviction - the words that fall off the far end of the road).
    readonly property int _texCacheCap: 32

    // --- computed placement model -----------------------------------------
    // One entry per distinct word: { word, aspect, pxW, pxH, instances[] } where
    // each instance is { pos, yaw, flip }. Grouping by word lets every placement
    // of a word share one Texture (see Repeater3D below).
    property var _wordGroups: []
    property int _retries: 0

    // --- glyph-mode state -------------------------------------------------
    // The lazily-created internal batch (set from the Repeater3D delegate) and
    // the last computed curved placements. _skipped feeds skippedPlacements.
    property var _glyphBatch: null
    property var _curvedPlacements: []
    property int _skipped: 0
    // Max total absolute tangent turn (radians) a single placement's baseline
    // may accumulate before the curvature guard drops it. Tuned so each straight
    // leg of a hairpin passes but a label wrapping a tight U is skipped.
    readonly property real _curvatureLimit: 2.4
    // Toward-camera depth bias handed to the internal glyph batch so the ground
    // decal draws above the (depth-writing, blended) line it sits on from any
    // camera. Small enough not to lift the text visibly off the ground.
    readonly property real groundDepthBias: 0.00015

    // Hidden metrics probe: measures each word's advance without laying out an
    // item, so placement never depends on live carrier sizes (no binding cycle).
    TextMetrics { id: _metrics }

    /*!
        \qmlmethod void PathLabel3D::rebuild()
        \brief Recomputes word placement now. Called automatically on input change.
    */
    function rebuild() {
        var lb = root.lines
        if (!lb) { root._wordGroups = []; root._curvedPlacements = []; return }
        var total = lb.pathLength(root.lineId)
        if (!(total > 0)) {
            // Geometry may upload a frame after this component completes; defer a
            // few times, then give up rather than spin.
            if (root._retries < 6) { root._retries++; Qt.callLater(root.rebuild) }
            return
        }
        root._retries = 0

        if (root.glyphPlacement) { root._rebuildGlyphs(lb, total); return }
        root._rebuildWords(lb, total)
    }

    // Placement centers along the path, shared by both modes so at / repeatEvery
    // / auto-center behave identically. blockWidth is the total world length of
    // the laid-out text (words+gaps, or the glyph advance run).
    function _placementCenters(total, blockWidth) {
        var centers = []
        if (root.repeatEvery > 0) {
            var startC = root.at >= 0 ? root.at : blockWidth * 0.5
            for (var d0 = startC; d0 <= total - blockWidth * 0.5 + 1e-3; d0 += root.repeatEvery)
                centers.push(d0)
            if (centers.length === 0) centers.push(Math.min(total * 0.5, total - blockWidth * 0.5))
        } else {
            centers.push(root.at >= 0 ? root.at : total * 0.5)
        }
        return centers
    }

    // One flip-to-read decision for a placement (maplibre model): the chord from
    // the block's first to last point gives the dominant direction; fall back to
    // the center tangent when the block nearly closes on itself. Returns true if
    // the text should be flipped 180 degrees so it reads the right way up.
    function _flipFor(lb, total, startD, blockWidth, eps) {
        var pS = lb.positionAt(root.lineId, Math.max(0, startD))
        var pE = lb.positionAt(root.lineId, Math.min(total, startD + blockWidth))
        var domX = pE.x - pS.x, domZ = pE.z - pS.z
        if (domX * domX + domZ * domZ < 1e-3) {
            var mc = Math.max(0, Math.min(total, startD + blockWidth * 0.5))
            var ma = lb.positionAt(root.lineId, Math.max(0, mc - eps))
            var mb = lb.positionAt(root.lineId, Math.min(total, mc + eps))
            domX = mb.x - ma.x; domZ = mb.z - ma.z
        }
        return (domX * root.readingDirection.x + domZ * root.readingDirection.y) < 0
    }

    function _rebuildWords(lb, total) {
        var raw = root.text.trim()
        if (raw.length === 0) { root._wordGroups = []; return }
        var words = raw.split(/\s+/)

        _metrics.font.family = root.labelStyle.fontFamily
        _metrics.font.pixelSize = root.labelStyle.fontSize
        _metrics.font.bold = root.labelStyle.bold

        var gap = root.wordSpacing >= 0 ? root.wordSpacing : root.worldHeight * 0.4

        // Measure words once: pixel size (for the carrier) and world width.
        var wm = []
        var blockWidth = 0
        for (var i = 0; i < words.length; ++i) {
            _metrics.text = words[i]
            var tw = _metrics.advanceWidth
            var th = _metrics.boundingRect.height
            if (!(th > 0)) th = root.labelStyle.fontSize * 1.4
            var pxW = tw + root.labelStyle.paddingH * 2
            var pxH = th + root.labelStyle.paddingV * 2
            var worldWidth = root.worldHeight * (pxW / pxH)
            wm.push({ word: words[i], aspect: pxW / pxH, pxW: pxW, pxH: pxH, worldWidth: worldWidth })
            blockWidth += worldWidth
        }
        blockWidth += gap * (words.length - 1)

        var centers = root._placementCenters(total, blockWidth)

        var byWord = {}
        var order = []
        function grpFor(m) {
            if (!(m.word in byWord)) {
                byWord[m.word] = { word: m.word, aspect: m.aspect, pxW: m.pxW, pxH: m.pxH, instances: [] }
                order.push(m.word)
            }
            return byWord[m.word]
        }

        var eps = Math.max(2, root.worldHeight * 0.15)
        for (var c = 0; c < centers.length; ++c) {
            var startD = centers[c] - blockWidth * 0.5
            var flip = root._flipFor(lb, total, startD, blockWidth, eps)

            var d = startD
            for (var k = 0; k < wm.length; ++k) {
                var m = wm[k]
                var cd = Math.max(0, Math.min(total, d + m.worldWidth * 0.5))
                var p = lb.positionAt(root.lineId, cd)
                var pa = lb.positionAt(root.lineId, Math.max(0, cd - eps))
                var pb = lb.positionAt(root.lineId, Math.min(total, cd + eps))
                var yaw = Math.atan2(pb.x - pa.x, pb.z - pa.z) * 180 / Math.PI
                grpFor(m).instances.push({
                    pos: Qt.vector3d(p.x, root.groundOffset, p.z),
                    yaw: yaw,
                    flip: flip
                })
                d += m.worldWidth + gap
            }
        }

        // Apply the texture-cache cap: keep the most recently laid words.
        if (order.length > root._texCacheCap)
            order = order.slice(order.length - root._texCacheCap)

        var groups = []
        for (var g = 0; g < order.length; ++g)
            groups.push(byWord[order[g]])
        root._wordGroups = groups
    }

    // Per-glyph text-on-curve placement (maplibre's model). Shape once for the
    // advances, then place each glyph at its advance-center along the path with
    // the angle from the local tangent; flip decided once per placement; the
    // curvature guard drops a placement whose baseline turns too sharply.
    function _rebuildGlyphs(lb, total) {
        root._wordGroups = []
        var batch = root._glyphBatch
        if (!batch) return // batch not created yet; its onCompleted reschedules

        var str = root.text
        if (str.trim().length === 0) {
            root._curvedPlacements = []; root._skipped = 0
            batch.setCurvedLabels([])
            return
        }

        // Map the desired world text height onto the shader's size parameter so a
        // glyph run of ascent+descent equals worldHeight (matches word-mode box).
        var textPx = batch.ascentPx + batch.descentPx
        if (!(textPx > 0)) textPx = batch.font.baseSize
        var size = root.worldHeight * batch.font.baseSize / textPx

        // Per-code-point advances in world units; positions/angles index-align.
        var adv = batch.glyphAdvances(str, size)
        var n = adv.length
        if (n === 0) { root._curvedPlacements = []; root._skipped = 0; batch.setCurvedLabels([]); return }

        var cumBefore = []
        var acc = 0
        for (var i = 0; i < n; ++i) { cumBefore.push(acc); acc += adv[i] }
        var blockWidth = acc

        var centers = root._placementCenters(total, blockWidth)
        var eps = Math.max(2, root.worldHeight * 0.15)

        function clampD(x) { return Math.max(0, Math.min(total, x)) }
        function tangentAt(d) {
            var pa = lb.positionAt(root.lineId, Math.max(0, d - eps))
            var pb = lb.positionAt(root.lineId, Math.min(total, d + eps))
            return { x: pb.x - pa.x, z: pb.z - pa.z }
        }

        var placements = []
        var skipped = 0
        for (var c = 0; c < centers.length; ++c) {
            var startD = centers[c] - blockWidth * 0.5

            // Curvature guard: sample the tangent angle across the block and sum
            // the absolute turn; a placement over too sharp an arc is dropped.
            var samples = Math.max(n, 8)
            var prevA = null, totalTurn = 0
            for (var s = 0; s <= samples; ++s) {
                var dd = clampD(startD + blockWidth * (s / samples))
                var tg = tangentAt(dd)
                var a = Math.atan2(tg.z, tg.x)
                if (prevA !== null) {
                    var delta = a - prevA
                    while (delta > Math.PI) delta -= 2 * Math.PI
                    while (delta < -Math.PI) delta += 2 * Math.PI
                    totalTurn += Math.abs(delta)
                }
                prevA = a
            }
            if (totalTurn > root._curvatureLimit) { skipped++; continue }

            var flip = root._flipFor(lb, total, startD, blockWidth, eps)

            var positions = []
            var angles = []
            for (var g = 0; g < n; ++g) {
                var glyphAdvCenter = cumBefore[g] + adv[g] * 0.5
                // Flip reverses the walk direction along the path so glyph order
                // and facing both reverse together (no mirrored / reversed text).
                var gd = clampD(flip ? (startD + blockWidth - glyphAdvCenter)
                                     : (startD + glyphAdvCenter))
                var p = lb.positionAt(root.lineId, gd)
                var t = tangentAt(gd)
                // Flat mode maps glyph local +x -> world (cos, -sin) in (X, Z),
                // so the reading axis follows the tangent when angle = atan2(-tz, tx).
                var ang = Math.atan2(-t.z, t.x)
                if (flip) ang += Math.PI
                positions.push(Qt.vector3d(p.x, root.groundOffset, p.z))
                angles.push(ang)
            }
            placements.push({
                text: str,
                color: root.labelStyle.textColor,
                size: size,
                opacity: 1.0,
                positions: positions,
                angles: angles
            })
        }

        root._skipped = skipped
        root._curvedPlacements = placements
        batch.setCurvedLabels(placements)
    }

    // On-demand contract: coalesce every input change into one deferred rebuild
    // (Qt.callLater dedups within the frame). No FrameAnimation - the quads are
    // static once placed.
    function _schedule() { Qt.callLater(root.rebuild) }
    onLinesChanged: root._schedule()
    onLineIdChanged: root._schedule()
    onTextChanged: root._schedule()
    onAtChanged: root._schedule()
    onRepeatEveryChanged: root._schedule()
    onWorldHeightChanged: root._schedule()
    onWordSpacingChanged: root._schedule()
    onGroundOffsetChanged: root._schedule()
    onOversampleChanged: root._schedule()
    onReadingDirectionChanged: root._schedule()
    onGlyphPlacementChanged: root._schedule()
    Component.onCompleted: root._schedule()

    // --- lazy internal glyph batch (glyphPlacement mode only) --------------
    // Repeater3D with a 0/1 model is the Node-compatible lazy loader: with
    // glyphPlacement false there is no delegate, hence no LabelBatch3D and no SDF
    // atlas at all (pay-per-use). The batch renders World-sized, Flat glyphs; the
    // placement feeds it via setCurvedLabels once it completes.
    Repeater3D {
        id: _glyphRepeater
        model: root.glyphPlacement ? 1 : 0
        delegate: LabelBatch3D {
            id: _glyphBatchItem
            sizeMode: LabelBatch3D.World
            orientation: LabelBatch3D.Flat
            halo: root.labelStyle.halo
            haloColor: root.labelStyle.haloColor
            font.family: root.labelStyle.fontFamily
            font.weight: root.labelStyle.bold ? 700 : 400
            // Ground-decal layering contract: the glyphs write depth and carry a
            // small toward-camera bias so they draw above the line they sit on
            // from any camera (the LineBatch3D writes depth and blends, so plain
            // draw-order sorting is not reliable). Lines first, labels above.
            writesDepth: true
            depthBias: root.groundDepthBias
            Component.onCompleted: { root._glyphBatch = _glyphBatchItem; root._schedule() }
            Component.onDestruction: { if (root._glyphBatch === _glyphBatchItem) root._glyphBatch = null }
        }
    }

    // --- rendering: one shared texture per word, quads per placement -------
    // Outer level = distinct words: each owns exactly one oversampled Texture.
    // Inner level = that word's placements: flat, unlit, tangent-aligned quads
    // referencing the shared Texture.
    Repeater3D {
        model: root._wordGroups
        delegate: Node {
            id: grp
            required property var modelData

            // The word's single shared texture. Its sourceItem is only ever a
            // texture source (never shown in the 2D scene).
            property Texture wordTex: Texture {
                sourceItem: WordCarrier {
                    word: grp.modelData.word
                    pxW: grp.modelData.pxW
                    pxH: grp.modelData.pxH
                    over: root.oversample
                }
            }

            Repeater3D {
                model: grp.modelData.instances
                delegate: Node {
                    id: cell
                    required property var modelData
                    position: cell.modelData.pos
                    // Outer node yaws about world Y to follow the tangent; the
                    // 180 flip rotates about the same axis, which is the quad
                    // normal once flattened, so the word reads upright without
                    // tipping out of the ground plane. Inner node flattens the
                    // upright quad onto the floor.
                    eulerRotation.y: 90 - cell.modelData.yaw + (cell.modelData.flip ? 180 : 0)
                    Node {
                        eulerRotation.x: -90
                        Model {
                            source: "#Rectangle"
                            // #Rectangle is a 100x100 plane; scale to world size.
                            scale: Qt.vector3d(root.worldHeight * grp.modelData.aspect / 100,
                                               root.worldHeight / 100, 1)
                            materials: CustomMaterial {
                                // Ground-decal contract ("lines first, labels
                                // above"), same mechanism as the glyph batch:
                                // inked texels blend and write depth (with a
                                // small camera bias, so the word wins against
                                // the coplanar depth-writing line no matter the
                                // blended-pass order), transparent texels are
                                // discarded and can never punch holes into the
                                // line. PrincipledMaterial cannot express this
                                // split, hence the custom shaders.
                                shadingMode: CustomMaterial.Unshaded
                                cullMode: Material.NoCulling
                                sourceBlend: CustomMaterial.SrcAlpha
                                destinationBlend: CustomMaterial.OneMinusSrcAlpha
                                depthDrawMode: Material.AlwaysDepthDraw
                                property real depthBias: 0.00020
                                property TextureInput wordTex: TextureInput {
                                    texture: grp.wordTex
                                }
                                vertexShader: "path_word.vert"
                                fragmentShader: "path_word.frag"
                            }
                        }
                    }
                }
            }
        }
    }

    // The 2D carrier rasterized into a word texture. Authored at `over` scale so
    // the texture packs more texels than the on-screen quad would need at 1x -
    // that oversampling is what keeps the paint crisp when zoomed in.
    component WordCarrier: Item {
        id: carrier
        property string word: ""
        property real pxW: 10
        property real pxH: 10
        property real over: 2
        width: Math.max(1, carrier.pxW * carrier.over)
        height: Math.max(1, carrier.pxH * carrier.over)

        Rectangle {
            anchors.fill: parent
            visible: root.labelStyle.background
            color: root.labelStyle.backgroundColor
            radius: height * 0.2
        }
        Text {
            anchors.centerIn: parent
            text: carrier.word
            color: root.labelStyle.textColor
            font.family: root.labelStyle.fontFamily
            font.pixelSize: Math.round(root.labelStyle.fontSize * carrier.over)
            font.bold: root.labelStyle.bold
            style: root.labelStyle.halo ? Text.Outline : Text.Normal
            styleColor: root.labelStyle.haloColor
        }
    }
}
