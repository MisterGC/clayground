// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The algebra of a part table - what ExplodedView3D computes from the rows
// its ExplodePart children declare. Qt-free on purpose (no vector3d, no
// clock): `node plugins/clay_lab/explode.test.js` checks it in a second, and
// a kit's own table (labs/kits/circuit/anatomy.js) is validated by the same
// rules before a single Model is built from it.
//
// A row:
//   { id, parent, role, order, stage, offset: {x, y, z}, anchor: {x, y, z} }
//
//   id      the authoring token every mechanism names the part by ("die.base"),
//           identical in every language
//   parent  the id of the part this one sits inside, "" at the top level -
//           a nested sub-assembly travels with its parent and then comes
//           apart on its own
//   role    what it is made of; informational, the subject colours by it
//   order   1-based place in the lesson; 0 = drawn but never explained on
//           its own (a silkscreen, a header)
//   stage   which spread interval moves it: stage 1 travels while spread
//           goes 0 -> 1, stage 2 while it goes 1 -> 2 - the shell comes off
//           first, then what is inside
//   offset  the whole displacement at the end of its stage, in the part's
//           local frame (relative to the parent it sits in)
//   anchor  where a mark, an assembly line or a fingertip lands, local to
//           the part's own origin

function clamp01(v) { return v < 0 ? 0 : (v > 1 ? 1 : v) }

// How far a part of `stage` has travelled at `spread`: 0 before its stage
// begins, 1 once it is over, linear in between. Linear on purpose - easing is
// the animator's business, and an eased travel would make "half way" mean
// two different distances for two parts.
function travelAt(stage, spread) {
    var s = stage === undefined || stage === null || stage < 1 ? 1 : stage
    var v = spread === undefined || spread === null ? 0 : spread
    return clamp01(v - (s - 1))
}

// A part's displacement at `spread`, as a plain triple, scaled by `unit`.
function displacement(offset, stage, spread, unit) {
    var t = travelAt(stage, spread) * (unit === undefined ? 1 : unit)
    var o = offset || {}
    return { x: (o.x || 0) * t, y: (o.y || 0) * t, z: (o.z || 0) * t }
}

// How many stages a table has: the largest stage any row declares, never
// below 1 - so a subject that names no stages spreads over 0..1 exactly as a
// flat one does.
function stagesOf(table) {
    var n = 1
    for (var i = 0; i < (table || []).length; ++i) {
        var s = table[i].stage
        if (s !== undefined && s > n) n = s
    }
    return n
}

function rowOf(table, id) {
    for (var i = 0; i < (table || []).length; ++i)
        if (table[i].id === id) return table[i]
    return null
}

// The ids a lesson walks: every row with order > 0, ascending; equal orders
// keep table order.
function idsInOrder(table) {
    var rows = []
    for (var i = 0; i < (table || []).length; ++i)
        if (table[i].order > 0) rows.push({ r: table[i], i: i })
    rows.sort(function (a, b) { return a.r.order - b.r.order || a.i - b.i })
    return rows.map(function (e) { return e.r.id })
}

// The parent chain above `id`, nearest first; empty at the top level. A
// cycle stops the walk rather than hanging it - validate() reports it.
function ancestorsOf(table, id) {
    var out = []
    var seen = {}
    var r = rowOf(table, id)
    while (r && r.parent) {
        if (seen[r.parent]) break
        seen[r.parent] = true
        out.push(r.parent)
        r = rowOf(table, r.parent)
    }
    return out
}

// Every row inside `id`, at any depth, in table order.
function descendantsOf(table, id) {
    var out = []
    for (var i = 0; i < (table || []).length; ++i) {
        var a = ancestorsOf(table, table[i].id)
        if (a.indexOf(id) >= 0) out.push(table[i].id)
    }
    return out
}

// Which rows dim while `focus` holds a part: every one that is not the part,
// not above it and not inside it. Opacity inherits down a Node tree, so a
// dimmed parent would take the part it contains down with it; and focusing
// a sub-assembly means looking at all of it.
function dimmedIds(table, focus) {
    if (!focus) return []
    var keep = ancestorsOf(table, focus).concat(descendantsOf(table, focus))
    keep.push(focus)
    var out = []
    for (var i = 0; i < (table || []).length; ++i)
        if (keep.indexOf(table[i].id) < 0) out.push(table[i].id)
    return out
}

// The ids that carry a label: "all" is every explained part in teaching
// order; a list is kept in its own order, minus the ids the table does not
// have (a lesson naming a part the subject lacks gets no mark, not a mark at
// the origin).
function labelledIds(table, labelled) {
    if (labelled === "all") return idsInOrder(table)
    if (!labelled || labelled.length === undefined) return []
    var out = []
    for (var i = 0; i < labelled.length; ++i)
        if (rowOf(table, labelled[i])) out.push(labelled[i])
    return out
}

// What a label says: the dictionary's entry for the id, or the id itself, so
// a table with no vocabulary yet still tells its parts apart on screen.
function labelOf(id, labels) {
    if (labels && labels[id] !== undefined && labels[id] !== null && labels[id] !== "")
        return String(labels[id])
    return id
}

// Dashes along the segment from `from` to `to`: pairs of triples, `dash`
// long with `gap` between, starting at the assembled end so the line reads
// as growing out of the place the part left; the last dash is clipped at
// `to`. A segment shorter than a tenth of a dash draws nothing - a part
// that has not moved has no assembly line.
function dashes(from, to, dash, gap) {
    var d = dash === undefined || dash <= 0 ? 0.35 : dash
    var g = gap === undefined || gap < 0 ? d * 0.7 : gap
    var dx = to.x - from.x, dy = to.y - from.y, dz = to.z - from.z
    var len = Math.sqrt(dx * dx + dy * dy + dz * dz)
    var out = []
    if (len < d * 0.1) return out
    var ux = dx / len, uy = dy / len, uz = dz / len
    var at = function (t) { return { x: from.x + ux * t, y: from.y + uy * t, z: from.z + uz * t } }
    for (var s = 0; s < len; s += d + g) {
        var e = Math.min(s + d, len)
        out.push([at(s), at(e)])
    }
    return out
}

function _num(v) { return v === undefined || v === null ? 0 : v }
function _finite(v) {
    return v !== undefined && v !== null
        && isFinite(_num(v.x)) && isFinite(_num(v.y)) && isFinite(_num(v.z))
}

// Problems with a table; empty means fine. Ids unique and non-empty, every
// parent a row of the table with no cycle, orders whole and dense 1..n over
// the explained parts, stages whole and at least 1, offsets and anchors
// finite.
function validate(table) {
    var problems = []
    var seen = {}
    var orders = []
    var t = table || []
    for (var i = 0; i < t.length; ++i) {
        var r = t[i]
        if (!r.id) problems.push("row " + i + " has no id")
        else if (seen[r.id]) problems.push("duplicate id " + r.id)
        seen[r.id] = true
        if (r.parent) {
            if (!rowOf(t, r.parent)) problems.push("unknown parent " + r.parent + " on " + r.id)
            else if (ancestorsOf(t, r.id).indexOf(r.id) >= 0 || r.parent === r.id)
                problems.push("cycle through " + r.id)
        }
        var o = r.order === undefined ? 0 : r.order
        if (o !== Math.floor(o) || o < 0) problems.push("order is not a whole number on " + r.id)
        else if (o > 0) orders.push(o)
        var s = r.stage === undefined ? 1 : r.stage
        if (s !== Math.floor(s) || s < 1) problems.push("stage below 1 on " + r.id)
        if (!_finite(r.offset)) problems.push("non-finite offset on " + r.id)
        if (r.anchor !== undefined && !_finite(r.anchor)) problems.push("non-finite anchor on " + r.id)
    }
    orders.sort(function (a, b) { return a - b })
    for (var k = 0; k < orders.length; ++k)
        if (orders[k] !== k + 1) { problems.push("order is not 1.." + orders.length); break }
    return problems
}
