// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Detailed lane model for the neoncity demo (Phase 5).
//
// This module is PURE and DETERMINISTIC: it consumes the road/intersection
// graph produced by citygen.js and layers an independent, high-detail lane
// model on top. It NEVER re-derives city geometry - it reads roads[] and
// intersections[] and offsets/curves lane lines from that.
//
// ============================================================================
// DETAILED-LANE-MODEL CONCEPTS (what this demo mirrors vs. simplifies)
// ============================================================================
// The model is inspired by real automotive lane models. It is INDEPENDENT of
// any proprietary spec - it just borrows the structural CONCEPTS below.
//
// MIRRORED:
//  * Road groups are curb-to-curb and hold BOTH travel directions in one
//    ordered set of lanes (see the per-road emission: -half .. +half).
//  * Boundaries are first-class lines BETWEEN lanes and are SHARED by the two
//    lanes they separate: N side-by-side lanes -> N+1 boundary lines, each
//    emitted ONCE (a divider is not duplicated per lane).
//  * A double line (the center of a spine) is TWO parallel boundary objects,
//    not one thick line.
//  * A boundary run is CUT where its marking changes: dashed lane dividers turn
//    SOLID as they approach an intersection (the boundary-set / element-range
//    idea in miniature - see splitDividerAlong()).
//  * Lane-count TRANSITIONS are modeled explicitly: a tapering lane is a lane
//    that terminates while its neighbour continues (the "major" lane). Its
//    centerline curves into the neighbour and the shared divider closes off
//    (see the spine taper). The road group is effectively re-segmented there.
//  * Intersections carry PER-MANEUVER turn lanes (approach lane -> compatible
//    exit lane), drawn dashed/thin inside the junction box; through lanes are
//    trimmed at the box; stop lines are transverse surface markings at each
//    approach (kept separate from lane topology, as in the real model).
//  * Tile-border continuity is structural: only interior spines change lane
//    count; feeders that reach a tile edge keep a constant, edge-deterministic
//    lane count, so neighbouring tiles agree one-to-one at the seam.
//
// DELIBERATELY SIMPLIFIED / OMITTED:
//  * No explicit group/lane/boundary ID graph, no predecessor/successor
//    connector lists or split/merge priorities - connectivity stays implicit
//    and geometric.
//  * No traversability ranges, no marking material/color taxonomy, no
//    logical/physical divider families - only painted solid vs. dashed.
//  * Lane-count changes are restricted to interior spines; feeders never
//    change count, so no border/fork groups or zero-length connector lanes are
//    needed to pad a seam mismatch.
//  * Intersections use a geometric maneuver fan, not an unordered intersection
//    group with pairwise lane relations; stop lines are drawn geometrically.
//  * No elevation-stacked crossings, no coarse "artificial" coverage groups.
//
// ============================================================================
// OUTPUT of generateLaneModel(tileData, laneY):
// {
//   tileX, tileZ, tileSize, seed,
//   lines: [                                   // the detailed lane model
//     { p:  [[x,y,z], ...],                    // polyline (world coords)
//       c:  "#rrggbb",                         // color
//       w:  <real>,                            // width (pixels)
//       s:  <int>,                             // styleId -> STYLES[s]
//       t:  "center"|"boundary"|"turn"|"stop" },// semantic tag (debug/report)
//     ...
//   ],
//   lineCount, pointCount
// }
//
// STYLES (index == styleId) is the frozen style table shared with the export:
//   0 -> solid            (dash null)
//   1 -> dashed           (dash [DASH_LEN, DASH_GAP], world units)
// ============================================================================

.pragma library

// ---- style table (index == styleId) --------------------------------------

var DASH_LEN = 4.0;
var DASH_GAP = 4.0;

// Kept as plain data so the exporter can emit it verbatim (frozen contract).
var STYLES = [
    { dash: null,               opacity: 1.0 },   // 0: solid
    { dash: [DASH_LEN, DASH_GAP], opacity: 1.0 }  // 1: dashed
];

function styles() { return STYLES; }

// Same table in the shape LineBatch3D's style texture expects
// ({ dash: [len, gap], capRound, opacity }; [0,0] == solid). This is what the
// LaneOverlay binds so styleIds render as real dashes on the GPU.
function shaderStyles() {
    return [
        { dash: [0, 0],               capRound: true,  opacity: 1.0 }, // 0 solid
        { dash: [DASH_LEN, DASH_GAP], capRound: false, opacity: 1.0 }  // 1 dashed
    ];
}

// ---- palette (synthwave / erdblick-like) ---------------------------------

var COL_CENTER   = "#00d9ff"; // lane center lines: cyan
var COL_TURN     = "#0f9d9a"; // turn fans: dimmer teal-cyan
var COL_EDGE     = "#ff9933"; // solid road edges / center divider: orange
var COL_DIVIDER  = "#ffffff"; // dashed lane dividers: white
var COL_STOP     = "#eaf6ff"; // stop / waiting lines: near-white cyan

var W_CENTER  = 2.2;
var W_TURN    = 1.4;
var W_EDGE    = 1.9;
var W_DIVIDER = 1.5;
var W_STOP    = 3.2;

// ---- taper / boundary-run tuning -----------------------------------------

var TAPER_LEN   = 16.0; // world length over which a lane merges/appears
var MIN_GAP     = 34.0; // a junction-free span must exceed this to host a taper
var TAPER_PCT   = 55;   // ~this many percent of eligible spines get a taper
var TAPER_STEPS = 8;    // curve samples across the taper
var SOLID_NEAR  = 7.0;  // half-length of the solid divider run around a junction

// ---- close-junction window tuning ----------------------------------------
//
// When two DISTINCT junctions sit closer than ~2x the intersection radius,
// their trim disks overlap and clip away the whole stretch between them - the
// road ends up with stop lines but no centerlines/boundaries. MIN_VISIBLE is
// the minimum painted length we insist on keeping between two such junctions;
// WINDOW_MIN_SEP guards against reopening across duplicate/degenerate junction
// pairs (their centers coincide, so there is no real stretch to recover).
var MIN_VISIBLE    = 10.0; // min painted length kept between two close junctions
var WINDOW_MIN_SEP = 6.0;  // junction centers must be at least this far apart

// ---- small vector helpers (XZ plane) -------------------------------------

// Unit direction of a road along its axis (constant per road, axis-aligned).
function axisDir(road) {
    return road.axis === "h" ? { x: 1, z: 0 } : { x: 0, z: 1 };
}
// Left-hand perpendicular (used to offset lanes to either side).
function perp(road) {
    // For axis "h" (runs +X) perpendicular is +Z; for "v" (runs +Z) it is -X.
    return road.axis === "h" ? { x: 0, z: 1 } : { x: -1, z: 0 };
}

// Along-axis description of a straight, axis-aligned road.
function roadRange(road) {
    var cl = road.centerline;
    var horiz = road.axis === "h";
    var a0 = horiz ? cl[0].x : cl[0].z;
    var a1 = horiz ? cl[cl.length - 1].x : cl[cl.length - 1].z;
    var cross = horiz ? cl[0].z : cl[0].x;
    return { horiz: horiz, a0: a0, a1: a1, cross: cross,
             lo: Math.min(a0, a1), hi: Math.max(a0, a1) };
}

// World point at along-position `along` and lateral offset `off` (perp units).
function ptA(rr, along, off, y) {
    return rr.horiz ? [along, y, rr.cross + off]   // perp("h") = +Z
                    : [rr.cross - off, y, along];   // perp("v") = -X
}

function smooth(t) { return t * t * (3.0 - 2.0 * t); }

// Deterministic 32-bit hash of two integers (reload-stable per tile).
function hash2(a, b) {
    var h = (u32(a) ^ 0x9e3779b9) >>> 0;
    h = Math.imul(h ^ (u32(b) + 0x85ebca6b), 0x27d4eb2f) >>> 0;
    h ^= h >>> 15;
    return h >>> 0;
}
function u32(x) { return x >>> 0; }

// ---- intersection analysis -----------------------------------------------
//
// citygen leaves intersection.roadIds empty, so arms are recovered from
// geometry: a road passes an intersection I if I sits on its centerline; the
// road then contributes one arm per direction it extends away from I.

function segReach(road, ix, iz) {
    // Returns { on, plus, minus } - whether the centerline passes through I and
    // whether it extends in the +axis / -axis direction beyond I.
    var cl = road.centerline;
    var lateralTol = 0.75;   // world units off the centerline still counts as "on"
    var endTol = 0.5;
    var horiz = road.axis === "h";
    // Constant coordinate of an axis-aligned centerline.
    var c0 = horiz ? cl[0].z : cl[0].x;
    if (Math.abs((horiz ? iz : ix) - c0) > lateralTol) return { on: false };
    var a = horiz ? cl[0].x : cl[0].z;
    var b = horiz ? cl[cl.length - 1].x : cl[cl.length - 1].z;
    var lo = Math.min(a, b), hi = Math.max(a, b);
    var along = horiz ? ix : iz;
    if (along < lo - endTol || along > hi + endTol) return { on: false };
    return { on: true, plus: along < hi - endTol, minus: along > lo + endTol };
}

// Build the list of arms at intersection I. Each arm: { road, dir:{x,z} }.
function armsAt(roads, ix, iz) {
    var arms = [];
    for (var i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var reach = segReach(r, ix, iz);
        if (!reach.on) continue;
        var d = axisDir(r);
        var through = reach.plus && reach.minus;
        if (reach.plus)  arms.push({ road: r, dir: { x: d.x, z: d.z }, through: through });
        if (reach.minus) arms.push({ road: r, dir: { x: -d.x, z: -d.z }, through: through });
    }
    return arms;
}

function intersectionRadius(arms) {
    var maxHalf = 3.0;
    for (var i = 0; i < arms.length; ++i)
        maxHalf = Math.max(maxHalf, arms[i].road.width * 0.5);
    return maxHalf * 2.2 + 2.0;
}

// ---- polyline clipping against intersection disks ------------------------
//
// A lane line is trimmed so it stops short of the intersection disks it
// crosses, leaving a clean gap the turn fans span. Works on arbitrary
// polylines (needed for tapered, curved lane centers), returning the maximal
// stretches that lie outside every disk.

// Cut the open interval (w0, w1) out of a sorted, non-overlapping list of
// [lo, hi] intervals, returning the remaining pieces (used to punch a visible
// window back through overlapping trim disks).
function subtractInterval(intervals, w0, w1, eps) {
    var out = [];
    for (var i = 0; i < intervals.length; ++i) {
        var lo = intervals[i][0], hi = intervals[i][1];
        if (w1 <= lo + eps || w0 >= hi - eps) { out.push([lo, hi]); continue; }
        if (w0 > lo + eps) out.push([lo, w0]);
        if (w1 < hi - eps) out.push([w1, hi]);
    }
    return out;
}

function clipPolyline(pts, disks, minGap) {
    var runs = [];
    var cur = [];
    var eps = 1e-4;
    var gap = (minGap === undefined) ? 0 : minGap;
    for (var i = 0; i + 1 < pts.length; ++i) {
        var a = pts[i], b = pts[i + 1];
        var dx = b[0] - a[0], dy = b[1] - a[1], dz = b[2] - a[2];
        var segXZ2 = dx * dx + dz * dz;
        if (segXZ2 < 1e-9) continue;
        var segLen = Math.sqrt(segXZ2);
        // Blocked t-intervals contributed by each disk (XZ chord math). `hits`
        // keeps each disk's along-segment projection + world centre so we can
        // reopen a window between two close-but-distinct junctions.
        var blocked = [];
        var hits = [];
        for (var k = 0; k < disks.length; ++k) {
            var cx = disks[k].x - a[0], cz = disks[k].z - a[2];
            var R = disks[k].r;
            var proj = (cx * dx + cz * dz) / segXZ2;
            var px = proj * dx, pz = proj * dz;
            var perp2 = (cx - px) * (cx - px) + (cz - pz) * (cz - pz);
            if (perp2 >= R * R) continue;
            var half = Math.sqrt(R * R - perp2) / segLen;
            var t0 = proj - half, t1 = proj + half;
            if (t1 <= 0 || t0 >= 1) continue;
            blocked.push([Math.max(0, t0), Math.min(1, t1)]);
            hits.push({ proj: proj, t0: t0, t1: t1, x: disks[k].x, z: disks[k].z });
        }
        blocked.sort(function (p, q) { return p[0] - q[0]; });
        var merged = [];
        for (k = 0; k < blocked.length; ++k) {
            if (merged.length && blocked[k][0] <= merged[merged.length - 1][1] + eps)
                merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], blocked[k][1]);
            else merged.push(blocked[k].slice());
        }

        // Reopen a central window wherever two DISTINCT junctions overlap and
        // would otherwise leave less than `gap` of painted line between them.
        if (gap > 0 && hits.length > 1) {
            hits.sort(function (p, q) { return p.proj - q.proj; });
            var windows = [];
            for (k = 0; k + 1 < hits.length; ++k) {
                var hA = hits[k], hB = hits[k + 1];
                var sep = Math.sqrt((hA.x - hB.x) * (hA.x - hB.x) +
                                    (hA.z - hB.z) * (hA.z - hB.z));
                if (sep < WINDOW_MIN_SEP) continue;          // duplicate junctions
                if ((hB.t0 - hA.t1) * segLen >= gap) continue; // already visible
                var mid = 0.5 * (hA.proj + hB.proj);
                var halfW = (gap * 0.5) / segLen;
                var w0 = Math.max(0, Math.max(hA.proj, mid - halfW));
                var w1 = Math.min(1, Math.min(hB.proj, mid + halfW));
                if (w1 > w0 + eps) windows.push([w0, w1]);
            }
            for (var wi = 0; wi < windows.length; ++wi)
                merged = subtractInterval(merged, windows[wi][0], windows[wi][1], eps);
        }
        function lerp(t) { return [a[0] + dx * t, a[1] + dy * t, a[2] + dz * t]; }
        // Visible complements of the blocked intervals, in order.
        var visible = [];
        var cursor = 0;
        for (k = 0; k < merged.length; ++k) {
            if (merged[k][0] > cursor + eps) visible.push([cursor, merged[k][0]]);
            cursor = merged[k][1];
        }
        if (cursor < 1 - eps) visible.push([cursor, 1]);
        if (merged.length === 0) visible = [[0, 1]];

        for (var v = 0; v < visible.length; ++v) {
            var t0v = visible[v][0], t1v = visible[v][1];
            var sp = t0v <= eps ? a : lerp(t0v);
            var ep = t1v >= 1 - eps ? b : lerp(t1v);
            if (cur.length && t0v <= eps) {
                cur.push(ep);
            } else {
                if (cur.length >= 2) runs.push(cur);
                cur = [sp, ep];
            }
            if (t1v < 1 - eps) {            // blocked region follows -> break run
                if (cur.length >= 2) runs.push(cur);
                cur = [];
            }
        }
    }
    if (cur.length >= 2) runs.push(cur);
    return runs;
}

// ---- quadratic Bezier (turn fans) -----------------------------------------

function bezierQuad(p0, ctrl, p2, n, y) {
    var out = [];
    for (var i = 0; i <= n; ++i) {
        var t = i / n, u = 1 - t;
        var x = u * u * p0.x + 2 * u * t * ctrl.x + t * t * p2.x;
        var z = u * u * p0.z + 2 * u * t * ctrl.z + t * t * p2.z;
        out.push([x, y, z]);
    }
    return out;
}

// ---- lane offset selection ------------------------------------------------
//
// Offsets are signed multiples of the road half-width so they scale with the
// carriageway. `right`/`left` are relative to travel direction.

function approachLanes(road, inDir) {
    var rx = inDir.z, rz = -inDir.x;           // right-of-travel vector
    var pe = perp(road);
    var sign = (rx * pe.x + rz * pe.z) >= 0 ? 1 : -1; // which perp side is "right"
    var h = road.width * 0.5;
    return road.kind === "spine"
        ? { right: sign * 0.25 * h, left: sign * 0.75 * h }
        : { right: sign * 0.5 * h,  left: sign * 0.5 * h };
}

// ---- main -----------------------------------------------------------------

function generateLaneModel(tileData, laneY) {
    var y = (laneY === undefined) ? 1.8 : laneY;
    var roads = tileData.roads;
    var inters = tileData.intersections;
    var seed = tileData.seed;

    // Precompute arms + radius for every intersection.
    var interInfo = [];
    for (var i = 0; i < inters.length; ++i) {
        var arms = armsAt(roads, inters[i].x, inters[i].z);
        var R = intersectionRadius(arms);
        interInfo.push({ x: inters[i].x, z: inters[i].z, arms: arms, r: R });
    }

    var lines = [];
    function emit(pts, c, w, s, t) {
        if (pts.length >= 2) lines.push({ p: pts, c: c, w: w, s: s, t: t });
    }

    // Disks a road is trimmed against. A THROUGH road is only trimmed at pure
    // crossings (all arms through), so spines flow continuously through minor
    // T-junctions with feeders.
    function disksForRoad(road) {
        var out = [];
        for (var k = 0; k < interInfo.length; ++k) {
            var info = interInfo[k];
            var reach = segReach(road, info.x, info.z);
            if (!reach.on) continue;
            var terminatesHere = !(reach.plus && reach.minus);
            var pureCrossing = true;
            for (var aa = 0; aa < info.arms.length; ++aa)
                if (!info.arms[aa].through) { pureCrossing = false; break; }
            if (terminatesHere || pureCrossing)
                out.push({ x: info.x, z: info.z, r: info.r });
        }
        return out;
    }

    // Emit a solid line: clip to pieces, emit each with styleId 0.
    function emitSolid(poly, disks, color, width, tag) {
        var pieces = clipPolyline(poly, disks, MIN_VISIBLE);
        for (var pc = 0; pc < pieces.length; ++pc) emit(pieces[pc], color, width, 0, tag);
    }

    // Emit a lane divider: clip to pieces, then cut each piece into runs -
    // SOLID (styleId 0) within SOLID_NEAR of every junction the piece passes,
    // DASHED (styleId 1) in between. This is the boundary-run / marking-change
    // concept: a divider becomes solid as it approaches an intersection.
    function emitDivider(poly, disks, color, width) {
        var pieces = clipPolyline(poly, disks, MIN_VISIBLE);
        for (var pc = 0; pc < pieces.length; ++pc)
            splitDividerAlong(pieces[pc], color, width);
    }

    function splitDividerAlong(piece, color, width) {
        var A = piece[0], B = piece[piece.length - 1];
        var dx = B[0] - A[0], dy = B[1] - A[1], dz = B[2] - A[2];
        var L2 = dx * dx + dz * dz;
        var L = Math.sqrt(L2 + dy * dy);
        if (L < 1e-3) { emit(piece, color, width, 1, "boundary"); return; }
        function pt(d) { var t = d / L; return [A[0] + dx * t, A[1] + dy * t, A[2] + dz * t]; }
        // Solid windows around each junction the piece runs near.
        var win = [];
        for (var k = 0; k < interInfo.length; ++k) {
            var info = interInfo[k];
            var cx = info.x - A[0], cz = info.z - A[2];
            var proj = L2 > 1e-9 ? (cx * dx + cz * dz) / L2 : 0;
            if (proj < -0.05 || proj > 1.05) continue;
            var px = proj * dx, pz = proj * dz;
            var perp2 = (cx - px) * (cx - px) + (cz - pz) * (cz - pz);
            if (perp2 > info.r * info.r) continue;
            var d = Math.max(0, Math.min(1, proj)) * L;
            win.push([Math.max(0, d - SOLID_NEAR), Math.min(L, d + SOLID_NEAR)]);
        }
        win.sort(function (p, q) { return p[0] - q[0]; });
        var merged = [];
        for (k = 0; k < win.length; ++k) {
            if (merged.length && win[k][0] <= merged[merged.length - 1][1] + 1e-3)
                merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], win[k][1]);
            else merged.push(win[k].slice());
        }
        var cursor = 0;
        for (k = 0; k < merged.length; ++k) {
            if (merged[k][0] > cursor + 1e-3) emit([pt(cursor), pt(merged[k][0])], color, width, 1, "boundary");
            emit([pt(merged[k][0]), pt(merged[k][1])], color, width, 0, "boundary");
            cursor = merged[k][1];
        }
        if (cursor < L - 1e-3) emit([pt(cursor), pt(L)], color, width, 1, "boundary");
    }

    // ---- lane-count taper decision (spines only, junction-free spans) ----
    //
    // Find the widest span between consecutive junctions on the spine; if it is
    // long enough, host a taper there so the merging geometry never collides
    // with a junction. Deterministic per tile via the tile seed + spine offset.
    function taperFor(road) {
        if (road.kind !== "spine") return null;
        var rr = roadRange(road);
        var marks = [rr.lo, rr.hi];
        for (var k = 0; k < interInfo.length; ++k) {
            var info = interInfo[k];
            if (!segReach(road, info.x, info.z).on) continue;
            marks.push(rr.horiz ? info.x : info.z);
        }
        marks.sort(function (p, q) { return p - q; });
        var g0 = 0, g1 = 0, best = 0;
        for (k = 0; k + 1 < marks.length; ++k) {
            var gap = marks[k + 1] - marks[k];
            if (gap > best) { best = gap; g0 = marks[k]; g1 = marks[k + 1]; }
        }
        if (best < MIN_GAP) return null;
        var hsh = hash2(seed, Math.round(rr.cross));
        if ((hsh % 100) >= TAPER_PCT) return null;
        var mid = 0.5 * (g0 + g1);
        return { side: ((hsh >>> 8) & 1) ? 1 : -1, // which carriageway half drops
                 tStart: mid - TAPER_LEN * 0.5,
                 tEnd:   mid + TAPER_LEN * 0.5 };
    }

    // Sample a lane center that shifts from offset `o0` to `o1` across the taper
    // window, staying straight outside it. `endAt` truncates the line (a lane
    // that terminates at the merge point).
    function taperedCenter(rr, o0, o1, t, endAt, y) {
        var pts = [ptA(rr, rr.lo, o0, y), ptA(rr, t.tStart, o0, y)];
        for (var s = 1; s <= TAPER_STEPS; ++s) {
            var f = smooth(s / TAPER_STEPS);
            var along = t.tStart + (t.tEnd - t.tStart) * (s / TAPER_STEPS);
            pts.push(ptA(rr, along, o0 + (o1 - o0) * f, y));
        }
        if (!endAt) pts.push(ptA(rr, rr.hi, o1, y));
        return pts;
    }

    // ---- lane lines per road ----
    for (i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var h = r.width * 0.5;
        var rr = roadRange(r);
        var disks = disksForRoad(r);

        // Outer curbs (orange, solid) - shared outermost boundaries.
        emitSolid(ptLine(rr, -h, y), disks, COL_EDGE, W_EDGE, "boundary");
        emitSolid(ptLine(rr,  h, y), disks, COL_EDGE, W_EDGE, "boundary");

        if (r.kind === "spine") {
            // Double solid center divider: TWO parallel boundary objects.
            var dc = Math.min(0.6, h * 0.14);
            emitSolid(ptLine(rr, -dc, y), disks, COL_EDGE, W_EDGE, "boundary");
            emitSolid(ptLine(rr,  dc, y), disks, COL_EDGE, W_EDGE, "boundary");

            var t = taperFor(r);
            for (var sgn = -1; sgn <= 1; sgn += 2) {
                if (t && sgn === t.side) {
                    // Tapered half: two lanes merge into one centered lane.
                    // Surviving lane center shifts 0.25h -> 0.5h, continues.
                    emitSolid(taperedCenter(rr, sgn * 0.25 * h, sgn * 0.5 * h, t, false, y),
                              disks, COL_CENTER, W_CENTER, "center");
                    // Vanishing outer lane center 0.75h -> 0.5h, terminates.
                    emitSolid(taperedCenter(rr, sgn * 0.75 * h, sgn * 0.5 * h, t, true, y),
                              disks, COL_CENTER, W_CENTER, "center");
                    // Shared divider between them exists only before the merge.
                    emitDivider(ptSpan(rr, rr.lo, t.tStart, sgn * 0.5 * h, y), disks, COL_DIVIDER, W_DIVIDER);
                } else {
                    // Normal half: two lanes, three boundaries already shared.
                    emitSolid(ptLine(rr, sgn * 0.25 * h, y), disks, COL_CENTER, W_CENTER, "center");
                    emitSolid(ptLine(rr, sgn * 0.75 * h, y), disks, COL_CENTER, W_CENTER, "center");
                    emitDivider(ptLine(rr, sgn * 0.5 * h, y), disks, COL_DIVIDER, W_DIVIDER);
                }
            }
        } else {
            // Feeder: one lane per direction, shared dashed center divider.
            emitSolid(ptLine(rr, -0.5 * h, y), disks, COL_CENTER, W_CENTER, "center");
            emitSolid(ptLine(rr,  0.5 * h, y), disks, COL_CENTER, W_CENTER, "center");
            emitDivider(ptLine(rr, 0, y), disks, COL_DIVIDER, W_DIVIDER);
        }
    }

    // Straight full-length line at constant offset.
    function ptLine(rr, off, y) {
        return [ptA(rr, rr.lo, off, y), ptA(rr, rr.hi, off, y)];
    }
    // Straight partial line between two along-positions at constant offset.
    function ptSpan(rr, a0, a1, off, y) {
        return [ptA(rr, a0, off, y), ptA(rr, a1, off, y)];
    }

    // ---- per-maneuver turn lanes + stop lines per intersection ----
    for (i = 0; i < interInfo.length; ++i) {
        var info2 = interInfo[i];
        var arms2 = info2.arms;
        if (arms2.length < 2) continue;
        var R2 = info2.r;

        // Pure crossing (no arm terminates) trims all through lanes, so the
        // straight-through maneuver is needed to bridge the gap; at a T with a
        // continuous spine the through lane already covers it and is skipped.
        var pure2 = true;
        for (var pa = 0; pa < arms2.length; ++pa)
            if (!arms2[pa].through) { pure2 = false; break; }

        for (var ai = 0; ai < arms2.length; ++ai) {
            var A = arms2[ai];
            var inDir = { x: -A.dir.x, z: -A.dir.z };  // travel INTO the junction
            var apA = approachLanes(A.road, inDir);
            var peA = perp(A.road);

            // Stop / waiting line: transverse bar across the approach lanes at
            // the junction box edge (a road-surface marking, not lane topology).
            var sSign = apA.right >= 0 ? 1 : -1;
            var bx = info2.x + A.dir.x * R2, bz = info2.z + A.dir.z * R2;
            var hA = A.road.width * 0.5;
            emit([[bx, y, bz], [bx + peA.x * sSign * hA, y, bz + peA.z * sSign * hA]],
                 COL_STOP, W_STOP, 0, "stop");

            for (var bi = 0; bi < arms2.length; ++bi) {
                if (ai === bi) continue;
                var B = arms2[bi];
                var outDir = B.dir;
                var dotd = inDir.x * outDir.x + inDir.z * outDir.z;
                var cr = inDir.x * outDir.z - inDir.z * outDir.x;

                var straight = dotd > 0.7;
                var sameRoadStraight = A.road === B.road &&
                    A.dir.x === -B.dir.x && A.dir.z === -B.dir.z;
                if (sameRoadStraight && !pure2) continue; // through lane covers it

                // Pick approach lane by maneuver: right turn from the rightmost
                // lane, left turn from the leftmost, straight from the through
                // (right) lane.
                var srcOff = straight ? apA.right : (cr > 0 ? apA.left : apA.right);
                var apB = approachLanes(B.road, outDir); // exit lane offsets
                var dstOff = straight ? apB.right : (cr > 0 ? apB.left : apB.right);
                var peB = perp(B.road);

                var p0 = { x: info2.x + A.dir.x * R2 + peA.x * srcOff,
                           z: info2.z + A.dir.z * R2 + peA.z * srcOff };
                var p2 = { x: info2.x + B.dir.x * R2 + peB.x * dstOff,
                           z: info2.z + B.dir.z * R2 + peB.z * dstOff };
                var ctrl = { x: info2.x, z: info2.z };
                emit(bezierQuad(p0, ctrl, p2, 12, y), COL_TURN, W_TURN, 1, "turn");
            }
        }
    }

    var pointCount = 0;
    for (i = 0; i < lines.length; ++i) pointCount += lines[i].p.length;

    return {
        tileX: tileData.tileX, tileZ: tileData.tileZ,
        tileSize: tileData.tileSize, seed: tileData.seed,
        lines: lines,
        lineCount: lines.length,
        pointCount: pointCount
    };
}

// ---- render-buffer builder (bulk path) ------------------------------------
//
// Each logical lane line maps to exactly ONE render polyline; the per-line
// styleId rides in a parallel uint16 buffer, so dashes are drawn by the GPU
// style texture (no dash-chopping into short solid segments). Returns typed
// arrays ready for LineBatch3D.setBulk(positions, starts, colors, widths,
// styleIds).

function hexToRgba(c) {
    var s = c.charAt(0) === "#" ? c.substring(1) : c;
    var r = parseInt(s.substring(0, 2), 16);
    var g = parseInt(s.substring(2, 4), 16);
    var b = parseInt(s.substring(4, 6), 16);
    var a = s.length >= 8 ? parseInt(s.substring(6, 8), 16) : 255;
    return [r, g, b, a];
}

function buildBulkArrays(laneModel) {
    var src = laneModel.lines;
    var n = src.length;
    var totalPts = 0;
    for (var i = 0; i < n; ++i) totalPts += src[i].p.length;

    var positions = new Float32Array(totalPts * 3);
    var starts = new Uint32Array(n + 1);
    var colors = new Uint8Array(n * 4);
    var widths = new Float32Array(n);
    var styleIds = new Uint16Array(n);

    var p = 0;
    for (i = 0; i < n; ++i) {
        starts[i] = p;
        var l = src[i];
        var rgba = hexToRgba(l.c);
        for (var j = 0; j < l.p.length; ++j) {
            positions[p * 3 + 0] = l.p[j][0];
            positions[p * 3 + 1] = l.p[j][1];
            positions[p * 3 + 2] = l.p[j][2];
            p++;
        }
        colors[i * 4 + 0] = rgba[0];
        colors[i * 4 + 1] = rgba[1];
        colors[i * 4 + 2] = rgba[2];
        colors[i * 4 + 3] = rgba[3];
        widths[i] = l.w;
        styleIds[i] = l.s;
    }
    starts[n] = p;

    return { positions: positions, starts: starts, colors: colors, widths: widths,
             styleIds: styleIds, lineCount: n, pointCount: totalPts };
}
