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

    \note v1 places one quad per word. Per-glyph curve stepping (each glyph on its
    own short tangent, for tight bends) is a named follow-up and would refine this
    component internally without changing its API.

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

    \sa LineBatch3D, Label3D
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
    */
    readonly property int uniqueTextureCount: root._wordGroups.length

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

    // Hidden metrics probe: measures each word's advance without laying out an
    // item, so placement never depends on live carrier sizes (no binding cycle).
    TextMetrics { id: _metrics }

    /*!
        \qmlmethod void PathLabel3D::rebuild()
        \brief Recomputes word placement now. Called automatically on input change.
    */
    function rebuild() {
        var lb = root.lines
        if (!lb) { root._wordGroups = []; return }
        var total = lb.pathLength(root.lineId)
        if (!(total > 0)) {
            // Geometry may upload a frame after this component completes; defer a
            // few times, then give up rather than spin.
            if (root._retries < 6) { root._retries++; Qt.callLater(root.rebuild) }
            return
        }
        root._retries = 0

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

        // Placement centers along the path.
        var centers = []
        if (root.repeatEvery > 0) {
            var startC = root.at >= 0 ? root.at : blockWidth * 0.5
            for (var d0 = startC; d0 <= total - blockWidth * 0.5 + 1e-3; d0 += root.repeatEvery)
                centers.push(d0)
            if (centers.length === 0) centers.push(Math.min(total * 0.5, total - blockWidth * 0.5))
        } else {
            centers.push(root.at >= 0 ? root.at : total * 0.5)
        }

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

            // One flip-to-read decision for the whole placement (maplibre model):
            // an individually-flipped word would mirror on an S-curve. The chord
            // from the block's first to last point gives the dominant direction;
            // fall back to the center tangent when the block nearly closes on
            // itself (a placement that doubles back within its own span).
            var pS = lb.positionAt(root.lineId, Math.max(0, startD))
            var pE = lb.positionAt(root.lineId, Math.min(total, startD + blockWidth))
            var domX = pE.x - pS.x, domZ = pE.z - pS.z
            if (domX * domX + domZ * domZ < 1e-3) {
                var mc = Math.max(0, Math.min(total, centers[c]))
                var ma = lb.positionAt(root.lineId, Math.max(0, mc - eps))
                var mb = lb.positionAt(root.lineId, Math.min(total, mc + eps))
                domX = mb.x - ma.x; domZ = mb.z - ma.z
            }
            var flip = (domX * root.readingDirection.x + domZ * root.readingDirection.y) < 0

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
    Component.onCompleted: root._schedule()

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
                            materials: PrincipledMaterial {
                                lighting: PrincipledMaterial.NoLighting
                                alphaMode: PrincipledMaterial.Blend
                                baseColorMap: grp.wordTex
                                // A word quad is mostly transparent (glyphs on a
                                // clear ground). Without this it still writes the
                                // depth buffer across its whole rectangle, so the
                                // bright line underneath fails the depth test and
                                // the transparent gaps punch a dark hole in it.
                                // As ground paint the quad must never occlude what
                                // it lies on - never write depth.
                                depthDrawMode: PrincipledMaterial.NeverDepthDraw
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
