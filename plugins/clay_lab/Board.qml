// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import "board.js" as B

/*!
    \qmltype Board
    \inqmlmodule Clayground.Lab
    \brief The store behind a build-type lab: typed parts on a grid, wires between their pads.

    Everything a lab that places parts does with them that has no domain in
    it - the cell arithmetic, where a pad is once the part is turned, the hit
    test, keep-out and the search for a free cell, adding, moving, turning and
    removing, tapping a wire to branch from it, batching the mutations so a
    preset that makes eighty of them publishes once, and the serialization
    that survives a reload. The domain hands over a \l spec describing its
    part types (see \c board.js) and reads the parts back through
    \l changed to solve them; the board never interprets a part's fields.

    \section2 Mutations publish once

    Every mutation edits \l parts / \l wires \e {in place} and then says so.
    Outside a batch that publishes immediately - a fresh array so QML sees a
    change, a bumped \l rev, and \l changed - which is what one click wants.
    Inside \l beginBatch / \l endBatch it only marks what changed: reassigning
    the array hands a Repeater3D a new model and it rebuilds \e every part
    (22 ms at 38 parts, measured), so a preset making 85 mutations would
    rebuild roughly 740 parts to end up with 38. Every bulk edit path must go
    through a batch or it quietly reintroduces that cost.

    \qml
    Board {
        id: board
        cols: 28; rows: 16; cell: 5
        spec: Parts.spec
        router: ({ all: Route.routeAll, one: (a, b, lane) => Route.routeOne(a, b, [], null, lane) })
        onChanged: (kind) => { if (kind !== "view") root.resolve() }
    }
    \endqml

    \sa BoardInput, BoardWires3D, PartCard, BoardOverlay, BoardPalette, PartPlacer
*/
QtObject {
    id: root

    /*! \qmlproperty int Board::cols \brief Cells across. */
    property int cols: 20
    /*! \qmlproperty int Board::rows \brief Cells deep. */
    property int rows: 12
    /*! \qmlproperty real Board::cell \brief World units per cell. */
    property real cell: 5

    /*!
        \qmlproperty var Board::spec
        \brief The domain's part types: \c {{ type: { terminals, half, actuator, keepOut, fields, rows, watch } }}.
    */
    property var spec: ({})

    /*!
        \qmlproperty var Board::parts
        \brief \c {[{ id, type, col, row, rot, ...fields }]} - col/row are fractional cells.

        Mutated in place by the board's own verbs; read it, never assign it.
        A binding that reads a part must list \l rev as well: a mutation
        hands back the same object, and re-assigning an identical reference is
        not a change as far as QML is concerned.
    */
    property var parts: []

    /*! \qmlproperty var Board::wires \brief \c {[{ id, a: [partId, ti], b: [partId, ti] }]}. */
    property var wires: []

    /*! \qmlproperty int Board::nextId \brief The next id handed out, shared by parts and wires. */
    property int nextId: 1

    /*!
        \qmlproperty int Board::rev
        \brief Bumped by every mutation and every move; the dependency in-place edits need.
    */
    property int rev: 0

    /*!
        \qmlproperty var Board::router
        \brief Optional: \c {{ all(links, obstacles, lane), one(a, b, lane) }} choosing wire paths.

        Without one a wire is the straight line between its pads. The circuit
        kit's \c route.js draws Manhattan paths; it stays in the kit, the board
        only asks it. \c all is handed every wire at once (a wire has to know
        which lanes are taken) and returns \c {{ wireId: [{x, z}, ...] }};
        \c one routes the dangling preview.
    */
    property var router: null

    /*! \qmlproperty real Board::lane \brief The raster a router turns on; half a cell by default. */
    property real lane: cell / 2

    // --- interaction state, shared by the input, the card and the overlays --
    /*! \qmlproperty int Board::selectedId \brief The selected part, -1 for none. */
    property int selectedId: -1
    /*! \qmlproperty var Board::hoverHit \brief What is under the cursor, as \l hitAt reports it. */
    property var hoverHit: null
    /*! \qmlproperty var Board::wiringFrom \brief \c {{el, ti}} while a wire is dangling. */
    property var wiringFrom: null
    /*! \qmlproperty bool Board::eraser \brief The eraser tool is on. */
    property bool eraser: false
    /*! \qmlproperty var Board::cursorW \brief The cursor on the board, in world units. */
    property var cursorW: Qt.vector3d(0, 1.9, 0)
    /*! \qmlproperty real Board::cursorHeight \brief The y \l cursorW is reported at. */
    property real cursorHeight: 1.9

    /*!
        \qmlsignal Board::changed(string kind)
        \brief The board was mutated: \c "solve" after anything the domain must re-solve, \c "view" after a move or a turn.
    */
    signal changed(string kind)
    /*! \qmlsignal Board::removed(int id) \brief A part left the board (its wires went with it). */
    signal removed(int id)
    /*! \qmlsignal Board::cleared() \brief Everything left the board. */
    signal cleared()

    readonly property var geom: ({ cols: cols, rows: rows, cell: cell })

    // --- grid -------------------------------------------------------------
    /*! \qmlmethod real Board::cellX(real col) */
    function cellX(col) { return B.cellX(geom, col) }
    /*! \qmlmethod real Board::cellZ(real row) */
    function cellZ(row) { return B.cellZ(geom, row) }
    /*! \qmlmethod real Board::colOf(real x) */
    function colOf(x) { return B.colOf(geom, x) }
    /*! \qmlmethod real Board::rowOf(real z) */
    function rowOf(z) { return B.rowOf(geom, z) }

    // --- lookups ----------------------------------------------------------
    /*! \qmlmethod var Board::partAt(int id) \brief The live part object, or null. */
    function partAt(id) { return B.partById(parts, id) }
    /*! \qmlmethod var Board::specOf(string type) */
    function specOf(type) { return B.specOf(spec, type) }
    /*! \qmlmethod int Board::terminalCount(string type) */
    function terminalCount(type) { return B.terminalCount(spec, type) }
    /*! \qmlmethod var Board::terminalLocal(string type, int ti) \brief \c {{x, y}} in the part's own frame. */
    function terminalLocal(type, ti) { return B.terminalLocal(spec, type, ti) }
    /*! \qmlmethod var Board::bodyHalf(string type) \brief \c {{x, y}} footprint half-extents. */
    function bodyHalf(type) { return B.bodyHalf(spec, type) }
    /*! \qmlmethod var Board::actuatorHalf(string type) \brief \c {{x, y}} or null. */
    function actuatorHalf(type) { return B.actuatorHalf(spec, type) }
    /*! \qmlmethod int Board::keepOut(string type) */
    function keepOut(type) { return B.keepOut(spec, geom, type) }

    /*!
        \qmlmethod vector3d Board::terminalPos(int id, int ti)
        \brief A pad in world space, turned with its part; y is \l padY.
    */
    property real padY: 0.35
    function terminalPos(id, ti) {
        rev
        const el = partAt(id)
        if (!el) return Qt.vector3d(0, 0, 0)
        const p = B.terminalPos(spec, geom, el, ti)
        return Qt.vector3d(p.x, padY, p.z)
    }
    /*! \qmlmethod var Board::terminalDir(int id, int ti) \brief Which way a lead leaves its pad, \c {{x, z}} or null. */
    function terminalDir(id, ti) {
        rev
        const el = partAt(id)
        return el ? B.terminalDir(spec, el, ti) : null
    }

    /*! \qmlmethod bool Board::cellFree(real col, real row, int ignoreId, string type) */
    function cellFree(col, row, ignoreId, type) {
        return B.cellFree(spec, geom, parts, col, row, ignoreId, type)
    }
    /*! \qmlmethod var Board::nearestFreeCell(real col, real row, string type) \brief \c {{col, row}} or null. */
    function nearestFreeCell(col, row, type) {
        return B.nearestFreeCell(spec, geom, parts, col, row, type)
    }

    // --- wires as geometry ---------------------------------------------------
    /*!
        \qmlproperty var Board::routes
        \brief Every wire's drawn path, \c {{ wireId: [{x, z}, ...] }}, from the \l router.

        Routing is GEOMETRY: it follows \l rev and never the solve, so a
        search over candidate paths cannot end up inside the solve loop.
    */
    readonly property var routes: {
        rev
        if (!router || !router.all) return ({})
        return router.all(B.linksOf(spec, geom, parts, wires), B.obstaclesOf(spec, geom, parts), lane)
    }

    /*! \qmlmethod var Board::wirePath(var wire) \brief The drawn path as \c {[{x, z}]}; the straight line when unrouted. */
    function wirePath(w) {
        const p = routes[w.id]
        if (p && p.length > 1) return p
        const a = partAt(w.a[0]), b = partAt(w.b[0])
        if (!a || !b) return []
        return B.straightPath(B.terminalPos(spec, geom, a, w.a[1]), B.terminalPos(spec, geom, b, w.b[1]))
    }
    /*! \qmlmethod var Board::wireMid(var wire) \brief Half the wire's length along it, \c {{x, z}}. */
    function wireMid(w) { return B.midOfPath(wirePath(w)) }
    /*!
        \qmlmethod var Board::previewPath(var from, var to)
        \brief The path a wire from pad \a from (\c {{el, ti}}) to the point \a to (\c {{x, z}}) would take.
    */
    function previewPath(from, to) {
        const a = terminalPos(from.el, from.ti)
        const ends = { x: a.x, z: a.z, dir: terminalDir(from.el, from.ti) }
        if (router && router.one) return router.one(ends, { x: to.x, z: to.z, dir: null }, lane)
        return B.straightPath(ends, to)
    }
    /*! \qmlmethod var Board::closestOnPath(var path, real x, real z) */
    function closestOnPath(path, x, z) { return B.closestOnPath(path, x, z) }

    /*!
        \qmlmethod var Board::hitAt(real wx, real wz)
        \brief What is at a board point: an actuator, a terminal, an element or a wire - in that order - or null.
    */
    function hitAt(wx, wz) {
        return B.hitAt(spec, geom, parts, wires, wx, wz, (w) => wirePath(w))
    }

    // --- batching ------------------------------------------------------------
    property int batchDepth: 0
    property bool _partsDirty: false
    property bool _wiresDirty: false
    property bool _revDirty: false

    /*! \qmlmethod void Board::beginBatch() */
    function beginBatch() { ++batchDepth }
    /*! \qmlmethod void Board::endBatch() \brief Publishes once, whatever happened inside. */
    function endBatch() {
        if (batchDepth > 0) --batchDepth
        if (batchDepth === 0) _flush()
    }
    // what: "parts", "wires", or anything else for both
    function _touch(what) {
        if (what !== "wires") _partsDirty = true
        if (what !== "parts") _wiresDirty = true
        _revDirty = true
        if (batchDepth === 0) _flush()
    }
    // A view-only change (a part moved or turned): no re-solve, because
    // geometry is not the domain - but the bindings still have to re-read.
    function _touchView() {
        _revDirty = true
        if (batchDepth === 0) { ++rev; _revDirty = false; changed("view") }
    }
    function _flush() {
        if (_partsDirty) { parts = parts.slice(); _partsDirty = false }
        if (_wiresDirty) { wires = wires.slice(); _wiresDirty = false }
        if (_revDirty) { ++rev; _revDirty = false }
        changed("solve")
    }

    // --- mutations -------------------------------------------------------------
    /*!
        \qmlmethod int Board::addPart(string type, real col, real row)
        \brief Places a part on the nearest free cell; returns its id, -1 when the board is full.
    */
    function addPart(type, col, row) {
        const spot = nearestFreeCell(col === undefined ? Math.floor(cols / 2) : col,
                                     row === undefined ? Math.floor(rows / 2) : row, type)
        if (!spot) return -1
        const el = B.newPart(spec, nextId++, type, spot.col, spot.row)
        parts.push(el)
        _touch("parts")
        return el.id
    }
    /*!
        \qmlmethod int Board::addRotated(string type, real col, real row, int quarters)
        \brief Place and turn in one go - a quarter turn is 90 degrees counter-clockwise seen from above.
    */
    function addRotated(type, col, row, quarters) {
        const id = addPart(type, col, row)
        for (let i = 0; i < (quarters || 0); ++i) rotatePart(id)
        return id
    }
    /*!
        \qmlmethod int Board::addJunction(real col, real row)
        \brief A solder dot, placed exactly (never snapped): wires meet here.
    */
    function addJunction(col, row) {
        const j = B.newPart(spec, nextId++, "junction", col, row)
        parts.push(j)
        _touch("parts")
        return j.id
    }
    /*!
        \qmlmethod int Board::splitWireAt(int wireId, real wx, real wz)
        \brief Drops a junction onto a wire where it was clicked and splits it in two; returns the junction id.
    */
    function splitWireAt(wireId, wx, wz) {
        let w = null
        for (const x of wires) if (x.id === wireId) w = x
        if (!w) return -1
        // on the DRAWN path, so the dot lands under the cursor and on the wire
        const p = B.closestOnPath(wirePath(w), wx, wz)
        beginBatch()
        const j = addJunction(colOf(p.x), rowOf(p.z))
        for (let i = wires.length - 1; i >= 0; --i)
            if (wires[i].id === wireId) wires.splice(i, 1)
        wires.push({ id: nextId++, a: w.a, b: [j, 0] })
        wires.push({ id: nextId++, a: [j, 0], b: w.b })
        _touch("wires")
        endBatch()
        return j
    }
    /*! \qmlmethod void Board::removePart(int id) \brief Takes a part and every wire on it off the board. */
    function removePart(id) {
        beginBatch()
        for (let i = wires.length - 1; i >= 0; --i)
            if (wires[i].a[0] === id || wires[i].b[0] === id) wires.splice(i, 1)
        for (let i = parts.length - 1; i >= 0; --i)
            if (parts[i].id === id) parts.splice(i, 1)
        if (selectedId === id) selectedId = -1
        removed(id)
        _touch("both")
        endBatch()
    }
    /*!
        \qmlmethod void Board::movePart(int id, real col, real row, bool snap)
        \brief Moves a part; snapping lands on a free peg cell, else it follows freely.
    */
    function movePart(id, col, row, snap) {
        const el = partAt(id)
        if (!el) return
        col = Math.max(0, Math.min(cols - 1, col))
        row = Math.max(0, Math.min(rows - 1, row))
        if (snap) {
            col = Math.round(col); row = Math.round(row)
            if (!cellFree(col, row, id, el.type)) return
        }
        el.col = col; el.row = row
        _touchView()
    }
    /*! \qmlmethod void Board::rotatePart(int id) \brief A quarter turn; kept unbounded so the animation always turns forward. */
    function rotatePart(id) {
        const el = partAt(id)
        if (!el) return
        el.rot = (el.rot || 0) + 90
        _touchView()
    }
    /*!
        \qmlmethod bool Board::setField(int id, string key, var value)
        \brief Sets one domain field and publishes; false when nothing changed.
    */
    function setField(id, key, value) {
        const el = partAt(id)
        if (!el || el[key] === value) return false
        el[key] = value
        _touch("fields")
        return true
    }
    /*! \qmlmethod void Board::addWire(var a, var b) \brief Joins two pads \c {[partId, ti]}; a duplicate or a self-loop is ignored. */
    function addWire(a, b) {
        if (a[0] === b[0] && a[1] === b[1]) return
        for (const w of wires) if (B.sameWire(w, a, b)) return
        wires.push({ id: nextId++, a: a, b: b })
        _touch("wires")
    }
    /*! \qmlmethod void Board::removeWire(int id) */
    function removeWire(id) {
        for (let i = wires.length - 1; i >= 0; --i)
            if (wires[i].id === id) wires.splice(i, 1)
        _touch("wires")
    }
    /*! \qmlmethod void Board::clear() \brief Empties the board and drops the interaction state. */
    function clear() {
        parts.length = 0; wires.length = 0
        wiringFrom = null
        selectedId = -1
        cleared()
        _touch("both")
    }

    // --- serialization ------------------------------------------------------------
    /*! \qmlmethod var Board::state() \brief \c {{ parts, wires, nextId }} - the built thing, for \c viewState(). */
    function state() { return B.toState(parts, wires, nextId) }
    /*! \qmlmethod void Board::load(var s) \brief Restores a \l state (an older payload under \c elements loads too). */
    function load(s) {
        const r = B.fromState(spec, s)
        parts = r.parts
        wires = r.wires
        nextId = r.nextId
        wiringFrom = null
        selectedId = -1
        ++rev
        changed("solve")
    }

    // --- for cameras, keys and jump labels ------------------------------------------
    /*!
        \qmlmethod var Board::bounds(var which, real pad)
        \brief Corner points framing these parts (a list of parts, of ids, or nothing for all), padded.
    */
    function bounds(which, pad) {
        let list = parts
        if (which && which.length !== undefined) {
            list = []
            for (const w of which) {
                const el = typeof w === "number" ? partAt(w) : w
                if (el) list.push(el)
            }
        }
        return B.boundsOf(geom, list, pad === undefined ? 7 : pad)
            .map(p => Qt.vector3d(p.x, 2, p.z))
    }

    /*!
        \qmlmethod var Board::keys(var grid, var overlay)
        \brief The board's half of the key map, as LabKeys entries: C clear, E eraser, V values, Q plot, R turn, # grid, Del remove.
    */
    function keys(grid, overlay) {
        const out = [
            { key: "C", label: "key.clear", action: () => root.clear() },
            { key: "E", label: "key.eraser", action: () => { root.eraser = !root.eraser } }
        ]
        if (overlay)
            out.push({ key: "V", label: "key.values", action: () => overlay.cycleValueAttr() })
        return out
    }
    /*!
        \qmlmethod var Board::selectionKeys(var monitor, var grid)
        \brief The keys that act on the selection: Q plot, R turn, Del remove - and # / G for the grid.
    */
    function selectionKeys(monitor, grid) {
        const out = []
        if (monitor)
            out.push({ key: "Q", label: "key.watch", action: () => {
                if (root.selectedId !== -1) monitor.toggle(root.selectedId) } })
        out.push({ key: "R", label: "key.rotate", action: () => {
            if (root.selectedId !== -1) root.rotatePart(root.selectedId) } })
        if (grid) {
            out.push({ key: "#", label: "key.grid", action: () => grid.toggle() })
            out.push({ key: "G", label: "key.grid", hidden: true, action: () => grid.toggle() })
        }
        out.push({ key: "Del", label: "key.delete", action: () => {
            if (root.selectedId !== -1) root.removePart(root.selectedId) } })
        return out
    }

    /*!
        \qmlmethod var Board::jumpTargets(var labelOf, var groupOf, real y)
        \brief HintJump targets, one per part, labelled by the domain.
    */
    function jumpTargets(labelOf, groupOf, y) {
        return parts.map(el => ({
            id: el.id,
            pos: Qt.vector3d(cellX(el.col), y === undefined ? 3 : y, cellZ(el.row)),
            name: labelOf ? labelOf(el.id) : String(el.id),
            group: groupOf ? groupOf(el) : el.type
        }))
    }
}
