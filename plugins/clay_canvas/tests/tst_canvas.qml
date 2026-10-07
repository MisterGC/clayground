// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The rules the new Canvas items follow, checked as numbers on a canvas that
// never scrolls: a progress that trims instead of rebuilding, a pen that
// resamples a stroke without ever moving one of its vertices, an arrow head
// that starts only once its shaft is done, a text that reveals whole letters,
// and the framing fit() computes. Nothing here compares pixels - every
// assertion reads a property off an item - so the suite needs no GPU and runs
// under QT_QPA_PLATFORM=minimal with the rest.
//
// The canvas is 800x600 showing 16x12 world units at pixelPerUnit 50, so its
// content item is exactly the size of the view: contentX and contentY stay 0,
// world (0, 0) is the bottom left pixel, and every expected pixel below
// follows from xToScreen/yToScreen alone.

import QtQuick
import QtQuick.Shapes
import QtTest
import Clayground.Canvas as Canv

Item {
    id: root
    width: 800; height: 600

    // One open polyline, 10 world units long (500 px), used by every Poly so
    // the sketched and the plain pen are compared on the same stroke.
    readonly property var verts: [{x: 0, y: 0}, {x: 4, y: 0}, {x: 4, y: 3}, {x: 7, y: 3}]
    readonly property var curve: [{x: 1, y: 1}, {x: 3, y: 4}, {x: 6.5, y: 4}]

    Canv.ClayCanvas {
        id: canvas
        anchors.fill: parent
        interactive: false
        worldXMin: 0; worldXMax: 16
        worldYMin: 0; worldYMax: 12
        pixelPerUnit: 50
    }

    // One Poly per pen: `sketch` is read by _look, by _pieces and by the
    // refresh handlers, and a suite that flipped it on a single item would be
    // asserting the order those three settle in, not the pen.
    Canv.Poly { id: poly;       canvas: canvas; vertices: root.verts }
    Canv.Poly { id: polyChalk;  canvas: canvas; vertices: root.verts; sketch: "chalk" }
    Canv.Poly { id: polyMarker; canvas: canvas; vertices: root.verts; sketch: "marker" }

    // Two boxes side by side, 6 world units apart, so an edge attach has an
    // unambiguous side to meet: the right of one, the left of the other.
    Canv.Rectangle { id: boxA; canvas: canvas; xWu: 2; yWu: 6; widthWu: 2; heightWu: 2; color: "red" }
    Canv.Rectangle { id: boxB; canvas: canvas; xWu: 8; yWu: 6; widthWu: 2; heightWu: 2; color: "blue" }

    Canv.Connector { id: conn;      canvas: canvas; from: boxA; to: boxB }
    Canv.Connector { id: connChalk; canvas: canvas; from: boxA; to: boxB; sketch: "chalk" }
    Canv.Connector { id: connPt;    canvas: canvas; from: ({x: 1, y: 2}); to: ({x: 5, y: 9}) }

    Canv.Text { id: label;      canvas: canvas; xWu: 1; yWu: 10; fontSizeWu: 0.5; text: "hello world" }
    Canv.Text { id: labelChalk; canvas: canvas; xWu: 1; yWu: 9;  fontSizeWu: 0.5; text: "hello world"; sketch: "chalk" }

    Canv.Axes {
        id: axes
        canvas: canvas
        xWu: 1; yWu: 1
        widthWu: 6; heightWu: 4
        strokeWidth: 2
        fontSizeWu: 0.4
        xLabel: "Ib"; yLabel: "Ic"
        series: root.curve
    }

    TestCase {
        name: "ClaygroundCanvas"
        when: windowShown

        readonly property real eps: 1e-6

        function init() {
            canvas.pixelPerUnit = 50
            canvas.viewPortCenterWuX = 8
            canvas.viewPortCenterWuY = 6
            for (const p of [poly, polyChalk, polyMarker]) {
                p.vertices = root.verts
                p.fillColor = "transparent"
                p.progress = 1
                p.seed = 0
            }
            for (const c of [conn, connChalk]) {
                c.attach = "center"
                c.arrow = "none"
                c.progress = 1
                c.seed = 0
            }
            connPt.progress = 1
            label.progress = 1
            labelChalk.progress = 1
            axes.series = root.curve
            axes.progress = 1
        }

        // The absolute position, in the canvas' coordinate system, of a Poly's
        // first point: the item sits at the top left of its own bounding box
        // and the ShapePath's start is relative to that.
        function startPixel(p) {
            return { x: p.x + p._shapePath.startX, y: p.y + p._shapePath.startY }
        }
        function lastPixel(p) {
            const els = p._shapePath.pathElements
            const e = els[els.length - 1]
            return { x: p.x + e.x, y: p.y + e.y }
        }

        // --- Poly ------------------------------------------------------------

        function test_polyProgressTrimsTheOutline() {
            poly.progress = 0.5
            fuzzyCompare(poly._shapePath.trim.end, 0.5, eps)
            fuzzyCompare(poly._grainPath.trim.end, 0.5, eps)
        }

        function test_polyProgressIsClampedToZeroAndOne() {
            poly.progress = 2
            compare(poly._shapePath.trim.end, 1)
            poly.progress = -1
            compare(poly._shapePath.trim.end, 0)
        }

        function test_polyWithoutSketchDrawsOneElementPerSegment() {
            compare(poly._shapePath.pathElements.length, root.verts.length - 1)
            compare(poly._grainPath.pathElements.length, 0)
            compare(poly._pieces, 1)
        }

        function test_polyChalkResamplesTheStrokeIntoManyPieces() {
            verify(polyChalk._pieces > 3)
            verify(polyChalk._shapePath.pathElements.length > root.verts.length - 1)
            compare(polyChalk._grainPath.pathElements.length,
                    polyChalk._shapePath.pathElements.length)
        }

        function test_polyMarkerResamplesButLeavesNoGrain() {
            verify(polyMarker._pieces > 3)
            verify(polyMarker._shapePath.pathElements.length > root.verts.length - 1)
            compare(polyMarker._grainPath.pathElements.length, 0)
        }

        function test_polyNeverMovesAVertex() {
            const first = root.verts[0]
            const last = root.verts[root.verts.length - 1]
            for (const p of [poly, polyChalk, polyMarker]) {
                const s = startPixel(p)
                fuzzyCompare(s.x, canvas.xToScreen(first.x), eps)
                fuzzyCompare(s.y, canvas.yToScreen(first.y), eps)
                const e = lastPixel(p)
                fuzzyCompare(e.x, canvas.xToScreen(last.x), eps)
                fuzzyCompare(e.y, canvas.yToScreen(last.y), eps)
            }
        }

        function test_polyIsClosedOnlyWhenItIsFilled() {
            compare(poly.closed, false)
            poly.fillColor = "green"
            compare(poly.closed, true)
        }

        function test_aClosedPolyDrawsOneElementMore() {
            const open = poly._shapePath.pathElements.length
            poly.fillColor = "green"
            compare(poly._shapePath.pathElements.length, open + 1)
        }

        function test_anotherSeedIsAnotherWobble() {
            const els = polyChalk._shapePath.pathElements
            const before = []
            for (let i = 0; i < els.length; ++i)
                before.push({ x: els[i].x, y: els[i].y })
            polyChalk.seed = 7
            const after = polyChalk._shapePath.pathElements
            compare(after.length, before.length)
            let moved = false
            for (let i = 0; i < before.length; ++i) {
                if (Math.abs(after[i].x - before[i].x) > eps ||
                    Math.abs(after[i].y - before[i].y) > eps) { moved = true; break }
            }
            verify(moved)
        }

        function test_aSketchedStrokeGetsRoundCaps() {
            compare(polyChalk._shapePath.capStyle, ShapePath.RoundCap)
            compare(polyMarker._shapePath.capStyle, ShapePath.RoundCap)
            compare(poly._shapePath.capStyle, ShapePath.SquareCap)
        }

        // --- Connector -------------------------------------------------------

        function test_connectorEndsAreTheItemCentres() {
            const a = conn.mapFromItem(canvas.coordSys, boxA.x + boxA.width / 2, boxA.y + boxA.height / 2)
            const b = conn.mapFromItem(canvas.coordSys, boxB.x + boxB.width / 2, boxB.y + boxB.height / 2)
            fuzzyCompare(conn.fromPos.x, a.x, eps)
            fuzzyCompare(conn.fromPos.y, a.y, eps)
            fuzzyCompare(conn.toPos.x, b.x, eps)
            fuzzyCompare(conn.toPos.y, b.y, eps)
        }

        function test_edgeAttachMeetsTheBoxBoundary() {
            conn.attach = "edge"
            const right = conn.mapFromItem(canvas.coordSys, boxA.x + boxA.width, boxA.y + boxA.height / 2)
            const left = conn.mapFromItem(canvas.coordSys, boxB.x, boxB.y + boxB.height / 2)
            fuzzyCompare(conn._a.x, right.x, eps)
            fuzzyCompare(conn._a.y, right.y, eps)
            fuzzyCompare(conn._b.x, left.x, eps)
            fuzzyCompare(conn._b.y, left.y, eps)
            // An edge attach is strictly shorter than the centre line it cuts.
            verify(conn._len < Math.abs(conn.toPos.x - conn.fromPos.x))
        }

        function test_noArrowLeavesBothHeadsTransparent() {
            verify(Qt.colorEqual(conn._headToPath.strokeColor, "transparent"))
            verify(Qt.colorEqual(conn._headFromPath.strokeColor, "transparent"))
            compare(conn._headToPath.trim.end, 0)
            compare(conn._headFromPath.trim.end, 0)
        }

        function test_arrowToInksOnlyTheHeadAtTo() {
            conn.arrow = "to"
            verify(Qt.colorEqual(conn._headToPath.strokeColor, conn.color))
            verify(Qt.colorEqual(conn._headFromPath.strokeColor, "transparent"))
            compare(conn._headToPath.trim.end, 1)
        }

        function test_headsWaitForTheShaft() {
            conn.arrow = "both"
            conn.progress = 0.5
            verify(conn._fractions[0] > 0.5)
            verify(conn._fractions[0] < 1)
            compare(conn._fractions[1], 0)
            compare(conn._fractions[2], 0)
        }

        function test_fullProgressDrawsShaftAndBothHeads() {
            conn.arrow = "both"
            conn.progress = 1
            compare(conn._fractions.length, 3)
            for (const f of conn._fractions) compare(f, 1)
        }

        function test_aWorldPointEndLandsOnTheCanvas() {
            const a = connPt.mapFromItem(canvas.coordSys, canvas.xToScreen(1), canvas.yToScreen(2))
            const b = connPt.mapFromItem(canvas.coordSys, canvas.xToScreen(5), canvas.yToScreen(9))
            fuzzyCompare(connPt.fromPos.x, a.x, eps)
            fuzzyCompare(connPt.fromPos.y, a.y, eps)
            fuzzyCompare(connPt.toPos.x, b.x, eps)
            fuzzyCompare(connPt.toPos.y, b.y, eps)
            fuzzyCompare(connPt._a.x, a.x, eps)
            fuzzyCompare(connPt._b.y, b.y, eps)
        }

        function test_aChalkShaftHasOneElementPerPiece() {
            verify(connChalk._pieces > 1)
            compare(connChalk._shaftPath.pathElements.length, connChalk._pieces)
            compare(connChalk._grainPath.pathElements.length, connChalk._pieces)
            compare(conn._shaftPath.pathElements.length, 1)
        }

        function test_theShaftTrimFollowsProgress() {
            conn.progress = 0.4
            fuzzyCompare(conn._shaftPath.trim.end, 0.4, eps)
            fuzzyCompare(conn._grainPath.trim.end, 0.4, eps)
            conn.progress = 0
            compare(conn._shaftPath.trim.end, 0)
        }

        // --- Text ------------------------------------------------------------

        function test_textRevealsWholeCharacters() {
            compare(label.text.length, 11)
            label.progress = 0
            compare(label.shownCharacters, 0)
            label.progress = 0.5
            compare(label.shownCharacters, 6)
            label.progress = 1
            compare(label.shownCharacters, 11)
        }

        function test_fullTextIsUnclippedAndFullWidth() {
            label.progress = 1
            compare(label.clip, false)
            tryCompare(label, "width", label.implicitWidth)
        }

        function test_partialTextIsClippedAndNarrower() {
            label.progress = 0.5
            compare(label.clip, true)
            verify(label.width > 0)
            verify(label.width < label.implicitWidth)
        }

        function test_returningToFullProgressRestoresTheWidth() {
            const full = label.implicitWidth
            label.progress = 0.5
            verify(label.width < full)
            label.progress = 1
            tryCompare(label, "width", full)
            compare(label.clip, false)
        }

        // A sketched Text writes in the shipped hand once the loader has it,
        // and in the application font until then - the rule holds whether or
        // not the font ever arrives.
        function test_chalkWritesInTheShippedHand() {
            wait(250)
            compare(labelChalk.font.family,
                    labelChalk.handFont !== "" ? labelChalk.handFont
                                               : Qt.application.font.family)
            // The `minimal` platform this suite runs on has no font database
            // ("This plugin does not support application fonts"), so the other
            // half - that the hand is Caveat - cannot be checked here.
            if (labelChalk.handFont === "")
                skip("QT_QPA_PLATFORM=minimal loads no application fonts")
            verify(labelChalk.handFont.indexOf("Caveat") >= 0)
        }

        function test_noSketchKeepsTheApplicationFont() {
            compare(label.font.family, Qt.application.font.family)
        }

        // --- Axes ------------------------------------------------------------

        function test_axesAtZeroProgressDrawNothing() {
            axes.progress = 0
            compare(axes.fractions.length, 5)
            for (const f of axes.fractions) compare(f, 0)
        }

        function test_axesAtFullProgressDrawEveryPart() {
            axes.progress = 1
            compare(axes.fractions.length, 5)
            for (const f of axes.fractions) compare(f, 1)
        }

        function test_axesPartsAreDrawnOneAfterAnother() {
            axes.progress = 0.5
            const f = axes.fractions
            compare(f.length, 5)
            compare(f[0], 1)
            for (let i = 1; i < f.length; ++i)
                verify(f[i] <= f[i - 1])
        }

        function test_anEmptySeriesStillHasFiveParts() {
            axes.series = []
            axes.progress = 1
            const f = axes.fractions
            compare(f.length, 5)
            // A free part is done once the cursor has REACHED it, so at
            // progress 1 a drawing with a free last part is still whole.
            for (let i = 0; i < 5; ++i) compare(f[i], 1)
            axes.progress = 0
            compare(axes.fractions[4], 0)
        }

        // --- ClayCanvas.fit --------------------------------------------------

        function test_fitFramesTheRectangle() {
            canvas.fit(0, 0, 16, 12)
            fuzzyCompare(canvas.pixelPerUnit, 50, eps)
            fuzzyCompare(canvas.viewPortCenterWuX, 8, eps)
            fuzzyCompare(canvas.viewPortCenterWuY, 6, eps)
        }

        function test_fitIsBoundByTheTighterAxis() {
            // 8 wu wide in 800 px would be 100 px/wu; the 12 wu of height in
            // 600 px allow only 50, and the whole rect has to fit.
            canvas.fit(0, 0, 8, 12)
            fuzzyCompare(canvas.pixelPerUnit, 50, eps)
            fuzzyCompare(canvas.viewPortCenterWuX, 4, eps)
        }

        function test_fitAddsTheMarginOnEverySide() {
            // 16x12 plus 1 on each side is 18x14: 800/18 across, 600/14 down,
            // and fit takes the smaller of the two - here the height.
            canvas.fit(0, 0, 16, 12, 1)
            fuzzyCompare(canvas.pixelPerUnit, Math.min(800 / 18, 600 / 14), eps)
        }

        function test_fitIgnoresAnEmptyRectangle() {
            canvas.fit(0, 0, 16, 12)
            const ppu = canvas.pixelPerUnit
            canvas.fit(3, 3, 3, 3)
            compare(canvas.pixelPerUnit, ppu)
            fuzzyCompare(canvas.viewPortCenterWuX, 8, eps)
            fuzzyCompare(canvas.viewPortCenterWuY, 6, eps)
        }

        function test_clayInspectReportsTheFraming() {
            canvas.fit(0, 0, 16, 12)
            const info = canvas.clayInspect()
            compare(info.type, "ClayCanvas")
            fuzzyCompare(info.pixelPerUnit, 50, eps)
            compare(info.canvasSize[0], 800)
            compare(info.canvasSize[1], 600)
            fuzzyCompare(info.visibleWorldRect.width, 16, eps)
            fuzzyCompare(info.visibleWorldRect.height, 12, eps)
        }
    }
}
