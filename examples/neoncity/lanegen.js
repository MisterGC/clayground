// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Detailed lane model for the neoncity demo (Phase 5).
//
// This module is PURE and DETERMINISTIC: it consumes the road/intersection
// graph produced by citygen.js and layers an independent, high-detail lane
// model on top. It NEVER re-derives city geometry - it reads roads[] and
// intersections[] and offsets/curves lane lines from that.
//
// Because citygen's road crossings are edge-deterministic, and every lane line
// here is a pure perpendicular offset of a road centerline, lane lines join
// seamlessly across tile borders with no extra bookkeeping.
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
//       t:  "center"|"boundary"|"turn" },      // semantic tag (debug/report)
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

// Kept as plain data so the exporter can emit it verbatim.
var STYLES = [
    { dash: null,               opacity: 1.0 },   // 0: solid
    { dash: [DASH_LEN, DASH_GAP], opacity: 1.0 }  // 1: dashed
];

function styles() { return STYLES; }

// ---- palette (synthwave / erdblick-like) ---------------------------------

var COL_CENTER   = "#00d9ff"; // lane center lines: cyan
var COL_TURN     = "#0f9d9a"; // turn fans: dimmer teal-cyan
var COL_EDGE     = "#ff9933"; // solid road edges / center divider: orange
var COL_DIVIDER  = "#ffffff"; // dashed lane dividers: white

var W_CENTER  = 2.2;
var W_TURN    = 1.8;
var W_EDGE    = 1.9;
var W_DIVIDER = 1.5;

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

function addPt(pts, x, y, z) { pts.push([x, y, z]); }

// Offset a road's straight centerline sideways by `off` (world units) and emit
// a polyline at height y. Returns the array of [x,y,z].
function offsetLine(road, off, y) {
    var pe = perp(road);
    var cl = road.centerline;
    var out = [];
    for (var i = 0; i < cl.length; ++i)
        out.push([cl[i].x + pe.x * off, y, cl[i].z + pe.z * off]);
    return out;
}

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

// ---- lane offset tables ---------------------------------------------------
//
// Offsets are signed multiples of the road half-width, so they scale with the
// carriageway and stay symmetric about the centerline.

function laneCenterOffsets(road) {
    var h = road.width * 0.5;
    return road.kind === "spine"
        ? [-0.75 * h, -0.25 * h, 0.25 * h, 0.75 * h]  // 2 lanes / direction
        : [-0.5 * h, 0.5 * h];                        // 1 lane / direction
}

// ---- clipping a straight lane line against intersection disks -------------
//
// A lane CENTER is trimmed so it stops short of the intersections it crosses,
// leaving a clean gap the turn fans span. Boundaries are trimmed the same way.

function clipAgainstDisks(line, disks) {
    // line: [[x,y,z],...] straight (2 points). Returns array of sub-polylines.
    if (line.length < 2) return [line];
    var a = line[0], b = line[line.length - 1];
    var y = a[1];
    var ax = a[0], az = a[2], bx = b[0], bz = b[2];
    var dx = bx - ax, dz = bz - az;
    var len = Math.sqrt(dx * dx + dz * dz);
    if (len < 1e-6) return [line];
    // Collect [tEnter, tExit] blocked intervals in parameter t in [0,1].
    var blocked = [];
    for (var i = 0; i < disks.length; ++i) {
        var cx = disks[i].x - ax, cz = disks[i].z - az;
        var R = disks[i].r;
        // Project disk center onto the line, then find chord half-length.
        var proj = (cx * dx + cz * dz) / (len * len);
        var px = proj * dx, pz = proj * dz;
        var d2 = (cx - px) * (cx - px) + (cz - pz) * (cz - pz);
        if (d2 >= R * R) continue;
        var half = Math.sqrt(R * R - d2) / len;
        var t0 = proj - half, t1 = proj + half;
        if (t1 <= 0 || t0 >= 1) continue;
        blocked.push([Math.max(0, t0), Math.min(1, t1)]);
    }
    if (blocked.length === 0) return [line];
    blocked.sort(function (p, q) { return p[0] - q[0]; });
    // Merge overlaps.
    var merged = [blocked[0].slice()];
    for (i = 1; i < blocked.length; ++i) {
        var last = merged[merged.length - 1];
        if (blocked[i][0] <= last[1] + 1e-6) last[1] = Math.max(last[1], blocked[i][1]);
        else merged.push(blocked[i].slice());
    }
    // Emit the visible complements.
    var out = [];
    var cursor = 0;
    function pt(t) { return [ax + dx * t, y, az + dz * t]; }
    for (i = 0; i < merged.length; ++i) {
        if (merged[i][0] > cursor + 1e-4) out.push([pt(cursor), pt(merged[i][0])]);
        cursor = merged[i][1];
    }
    if (cursor < 1 - 1e-4) out.push([pt(cursor), pt(1)]);
    return out;
}

// ---- turn fan (quadratic Bezier) ------------------------------------------

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

// Right-hand side offset (relative to travel direction d) as a signed value to
// pass to perp(): picks the lane a right-hand-driving car would use.
function rightLaneOffset(road, dirIntoI) {
    // perp(road) is the +offset direction. Determine its sign relative to the
    // right of travel: right(d) = rotate d by -90 deg in XZ -> (d.z, -d.x).
    var rx = dirIntoI.z, rz = -dirIntoI.x;
    var pe = perp(road);
    var dot = rx * pe.x + rz * pe.z;
    var h = road.width * 0.5;
    var mag = road.kind === "spine" ? 0.25 * h : 0.5 * h;
    return dot >= 0 ? mag : -mag;
}

// ---- main -----------------------------------------------------------------

function generateLaneModel(tileData, laneY) {
    var y = (laneY === undefined) ? 1.8 : laneY;
    var roads = tileData.roads;
    var inters = tileData.intersections;

    // Precompute arms + radius for every intersection.
    var interInfo = [];
    var disks = [];
    for (var i = 0; i < inters.length; ++i) {
        var arms = armsAt(roads, inters[i].x, inters[i].z);
        var R = intersectionRadius(arms);
        interInfo.push({ x: inters[i].x, z: inters[i].z, arms: arms, r: R });
    }

    var lines = [];

    function emit(pts, c, w, s, t) {
        if (pts.length >= 2) lines.push({ p: pts, c: c, w: w, s: s, t: t });
    }

    // For each road: disks are the intersections that road actually passes,
    // but a THROUGH road is only trimmed at pure crossings (all arms through),
    // so spines flow continuously through minor T-junctions with feeders.
    function disksForRoad(road, trimThrough) {
        var out = [];
        for (var k = 0; k < interInfo.length; ++k) {
            var info = interInfo[k];
            var reach = segReach(road, info.x, info.z);
            if (!reach.on) continue;
            var terminatesHere = !(reach.plus && reach.minus);
            var pureCrossing = true;
            for (var a = 0; a < info.arms.length; ++a)
                if (!info.arms[a].through) { pureCrossing = false; break; }
            // Always trim a road that terminates at the intersection; trim a
            // through road only where it is a pure crossing (or forced).
            if (terminatesHere || pureCrossing || trimThrough)
                out.push({ x: info.x, z: info.z, r: info.r });
        }
        return out;
    }

    // ---- lane lines per road ----
    for (i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var h = r.width * 0.5;
        var centerDisks = disksForRoad(r, false);

        // Lane centers (cyan, solid) - trimmed so turn fans can span the gap.
        var offs = laneCenterOffsets(r);
        for (var o = 0; o < offs.length; ++o) {
            var line = offsetLine(r, offs[o], y);
            var pieces = clipAgainstDisks(line, centerDisks);
            for (var pc = 0; pc < pieces.length; ++pc)
                emit(pieces[pc], COL_CENTER, W_CENTER, 0, "center");
        }

        // Edge boundaries (orange, solid).
        var edges = [-h, h];
        for (var e = 0; e < edges.length; ++e) {
            var el = offsetLine(r, edges[e], y);
            var ep = clipAgainstDisks(el, centerDisks);
            for (pc = 0; pc < ep.length; ++pc)
                emit(ep[pc], COL_EDGE, W_EDGE, 0, "boundary");
        }

        if (r.kind === "spine") {
            // Double solid center divider (two close parallel orange lines).
            var dc = Math.min(0.6, h * 0.14);
            var cds = [-dc, dc];
            for (var c2 = 0; c2 < cds.length; ++c2) {
                var dl = offsetLine(r, cds[c2], y);
                var dp = clipAgainstDisks(dl, centerDisks);
                for (pc = 0; pc < dp.length; ++pc)
                    emit(dp[pc], COL_EDGE, W_EDGE, 0, "boundary");
            }
            // Dashed lane dividers (white) at +-0.5*half.
            var divs = [-0.5 * h, 0.5 * h];
            for (var d2 = 0; d2 < divs.length; ++d2) {
                var vl = offsetLine(r, divs[d2], y);
                var vp = clipAgainstDisks(vl, centerDisks);
                for (pc = 0; pc < vp.length; ++pc)
                    emit(vp[pc], COL_DIVIDER, W_DIVIDER, 1, "boundary");
            }
        } else {
            // Feeder: single dashed center divider (white).
            var fl = offsetLine(r, 0, y);
            var fp = clipAgainstDisks(fl, centerDisks);
            for (pc = 0; pc < fp.length; ++pc)
                emit(fp[pc], COL_DIVIDER, W_DIVIDER, 1, "boundary");
        }
    }

    // ---- turn fans per intersection ----
    for (i = 0; i < interInfo.length; ++i) {
        var info2 = interInfo[i];
        var arms2 = info2.arms;
        if (arms2.length < 2) continue;
        var R2 = info2.r;
        var yc = y;

        // A pure crossing (no arm terminates) trims all through lanes, so a
        // straight-through fan is needed to bridge the gap there; at a T with a
        // continuous spine the through lanes are NOT trimmed, so that straight
        // fan would just double the visible lane and is skipped.
        var pure2 = true;
        for (var pa = 0; pa < arms2.length; ++pa)
            if (!arms2[pa].through) { pure2 = false; break; }

        // Connect the right-hand lane of each arm into the right-hand lane of
        // every other arm.
        for (var ai = 0; ai < arms2.length; ++ai) {
            for (var bi = 0; bi < arms2.length; ++bi) {
                if (ai === bi) continue;
                var A = arms2[ai], B = arms2[bi];
                var straightSameRoad = A.road === B.road &&
                    A.dir.x === -B.dir.x && A.dir.z === -B.dir.z;
                if (straightSameRoad && !pure2)
                    continue; // continuous through lane already covers this

                // Incoming point: travel goes toward I along -A.dir, using the
                // right lane for that inbound direction.
                var inDir = { x: -A.dir.x, z: -A.dir.z };
                var offIn = rightLaneOffset(A.road, inDir);
                var peA = perp(A.road);
                var p0 = {
                    x: info2.x + A.dir.x * R2 + peA.x * offIn,
                    z: info2.z + A.dir.z * R2 + peA.z * offIn
                };
                // Outgoing point: travel leaves along B.dir on its right lane.
                var offOut = rightLaneOffset(B.road, B.dir);
                var peB = perp(B.road);
                var p2 = {
                    x: info2.x + B.dir.x * R2 + peB.x * offOut,
                    z: info2.z + B.dir.z * R2 + peB.z * offOut
                };
                // Control point: intersection of the two tangent rays, approx'd
                // by the intersection center pulled toward both stubs.
                var ctrl = { x: info2.x, z: info2.z };
                var fan = bezierQuad(p0, ctrl, p2, 12, yc);
                emit(fan, COL_TURN, W_TURN, 0, "turn");
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
// The LineBatch3D bulk path hard-codes styleId 0 (solid), so dashed lines are
// baked into short solid dash-segments here. The LOGICAL model (one polyline
// per lane line, carrying styleId) is kept intact for the export; only the GPU
// buffer expands dashes. Returns typed arrays ready for LineBatch3D.setBulk.

function hexToRgba(c) {
    var s = c.charAt(0) === "#" ? c.substring(1) : c;
    var r = parseInt(s.substring(0, 2), 16);
    var g = parseInt(s.substring(2, 4), 16);
    var b = parseInt(s.substring(4, 6), 16);
    var a = s.length >= 8 ? parseInt(s.substring(6, 8), 16) : 255;
    return [r, g, b, a];
}

// Break a polyline into on-dash sub-segments (each a [p0, p1] pair).
function dashSegments(pts, dashLen, gapLen) {
    var segs = [];
    var period = dashLen + gapLen;
    var acc = 0;
    for (var i = 0; i + 1 < pts.length; ++i) {
        var a = pts[i], b = pts[i + 1];
        var dx = b[0] - a[0], dy = b[1] - a[1], dz = b[2] - a[2];
        var L = Math.sqrt(dx * dx + dy * dy + dz * dz);
        if (L < 1e-6) continue;
        var ux = dx / L, uy = dy / L, uz = dz / L;
        var t = 0;
        while (t < L - 1e-6) {
            var ph = (acc + t) % period;
            if (ph < dashLen) {
                var end = Math.min(L, t + (dashLen - ph));
                segs.push([[a[0] + ux * t, a[1] + uy * t, a[2] + uz * t],
                           [a[0] + ux * end, a[1] + uy * end, a[2] + uz * end]]);
                t = end;
            } else {
                t += (period - ph);
            }
        }
        acc += L;
    }
    return segs;
}

// laneModel -> { positions, starts, colors, widths, lineCount, pointCount }.
function buildBulkArrays(laneModel, dash) {
    var dashLen = dash ? dash[0] : DASH_LEN;
    var gapLen = dash ? dash[1] : DASH_GAP;
    var src = laneModel.lines;

    // Expand into render polylines (dashed -> many short segments).
    var render = [];
    for (var i = 0; i < src.length; ++i) {
        var l = src[i];
        var rgba = hexToRgba(l.c);
        if (l.s === 1) {
            var ds = dashSegments(l.p, dashLen, gapLen);
            for (var d = 0; d < ds.length; ++d) render.push({ p: ds[d], rgba: rgba, w: l.w });
        } else {
            render.push({ p: l.p, rgba: rgba, w: l.w });
        }
    }

    var n = render.length;
    var totalPts = 0;
    for (i = 0; i < n; ++i) totalPts += render[i].p.length;

    var positions = new Float32Array(totalPts * 3);
    var starts = new Uint32Array(n + 1);
    var colors = new Uint8Array(n * 4);
    var widths = new Float32Array(n);

    var p = 0;
    for (i = 0; i < n; ++i) {
        starts[i] = p;
        var r = render[i];
        for (var j = 0; j < r.p.length; ++j) {
            positions[p * 3 + 0] = r.p[j][0];
            positions[p * 3 + 1] = r.p[j][1];
            positions[p * 3 + 2] = r.p[j][2];
            p++;
        }
        colors[i * 4 + 0] = r.rgba[0];
        colors[i * 4 + 1] = r.rgba[1];
        colors[i * 4 + 2] = r.rgba[2];
        colors[i * 4 + 3] = r.rgba[3];
        widths[i] = r.w;
    }
    starts[n] = p;

    return { positions: positions, starts: starts, colors: colors, widths: widths,
             lineCount: n, pointCount: totalPts };
}
