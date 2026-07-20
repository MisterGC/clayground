// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Road paint + detailed lane model for the neoncity demo.
//
// This module is PURE and DETERMINISTIC. It consumes the road / junction graph
// produced by citygen.js and emits TWO independent line sets:
//
//   generateMarkings(tileData, y)  -> real painted road markings. This is road
//       FURNITURE, always drawn (grey asphalt, classic paint): a solid white
//       edge line on both carriageway edges of every road; on avenues a dashed
//       white divider between same-direction lanes and a DOUBLE solid yellow
//       centre between the two directions; on local streets a single dashed
//       white centre line; white stop bars at every junction approach. All
//       markings are trimmed at the junction boxes, so no paint runs through the
//       middle of a crossing.
//
//   generateLaneModel(tileData, y) -> the toggleable "detailed lane model" map
//       overlay (teal / cyan). ONLY the per-direction lane centerlines - the
//       tracks cars actually drive along, offset to the RIGHT half of the road
//       for right-hand traffic - plus junction maneuver curves (bezier fans)
//       connecting each incoming right-hand lane to the legal outgoing lanes.
//       It carries NO boundary / edge lines; those live in the markings set.
//
// Both sets share the frozen STYLES table and the render-buffer builder below,
// so either can be pushed straight into a LineBatch3D.
//
// OUTPUT of both:
// {
//   tileX, tileZ, tileSize, seed,
//   lines: [ { p:[[x,y,z],...], c:"#rrggbb", w:<real>, s:<int styleId>,
//              t:<semantic tag> }, ... ],
//   lineCount, pointCount
// }
//
// STYLES (index == styleId), shared with the export contract:
//   0 -> solid    (dash null)
//   1 -> dashed   (dash [DASH_LEN, DASH_GAP], world units)
//   2 -> chevron  (native direction glyphs marching in travel direction)
//   3 -> arrowhead (native end arrowhead on a single-segment connector tip)
//
// Styles 2 + 3 use LineBatch3D's native pattern/head styling (no hand-built
// glyph geometry). The deck.gl twin only understands the `dash` field, so the
// EXPORTED table (styles()) maps chevron -> a dash so it still renders as a
// direction-hint dashed line, and the arrowhead tip -> solid (a tiny segment).

.pragma library

// ---- style table (index == styleId) --------------------------------------

var DASH_LEN = 4.0;
var DASH_GAP = 4.0;

// Native chevron direction glyphs: period (world units) and flow speed. Flow is
// only visible while the batch's flowTime is advanced (Flow toggle); with a
// static clock the chevrons sit still and just point in the travel direction.
var CHEV_LEN  = 10.0;   // glyph extent along the path (world units)
var CHEV_GAP  = 22.0;   // gap between glyphs (world units) -> ~32u period
var CHEV_FLOW = 18.0;   // march speed (world units / s of flowTime)
var W_CHEV    = 11.0;   // chevron ribbon width (screen px) so the V reads clearly

// Native arrowhead on the connector tip segment. head = [length, width] in
// multiples of the tip line's width; length is generous so the whole (short)
// tip segment becomes the triangle.
var HEAD_LEN_M = 40.0;
var HEAD_WID_M = 4.2;
var W_HEADTIP  = 3.4;   // tip segment width (screen px)
var HEAD_TIP_WORLD = 6.0; // tip segment length (world units) == arrowhead length

// Kept as plain data so the exporter can emit it verbatim (frozen contract).
// The twin reads only `dash`, so chevron exports as a dashed direction line and
// the arrowhead tip exports as a plain solid segment.
var STYLES = [
    { dash: null,                 opacity: 1.0 },  // 0: solid
    { dash: [DASH_LEN, DASH_GAP], opacity: 1.0 },  // 1: dashed
    { dash: [CHEV_LEN, CHEV_GAP], opacity: 1.0 },  // 2: chevron -> dashed in twin
    { dash: null,                 opacity: 1.0 }   // 3: arrowhead -> solid in twin
];

function styles() { return STYLES; }

// Same table in the shape LineBatch3D's style texture expects
// ({ dash: [len, gap], capRound, opacity, ... }; [0,0] == solid).
function shaderStyles() {
    return [
        { dash: [0, 0],               capRound: true,  opacity: 1.0 }, // 0 solid
        { dash: [DASH_LEN, DASH_GAP], capRound: false, opacity: 1.0 }, // 1 dashed
        { dash: [CHEV_LEN, CHEV_GAP], capRound: true,  opacity: 1.0,   // 2 chevron
          pattern: "chevron", flow: CHEV_FLOW },
        { dash: [0, 0],               capRound: true,  opacity: 1.0,   // 3 arrowhead
          head: [HEAD_LEN_M, HEAD_WID_M] }
    ];
}

// ---- palette --------------------------------------------------------------

var COL_EDGE   = "#ffffff"; // solid white carriageway edge lines
var COL_DIVIDE = "#ffffff"; // dashed white lane dividers / local centre
var COL_CENTER = "#ffd93d"; // double solid yellow centre (between directions)
var COL_STOP   = "#ffffff"; // white stop bars at junction approaches

var COL_LANE   = "#00d9ff"; // lane-model centerlines + junction connectors: cyan

var W_EDGE   = 2.0;
var W_DIVIDE = 1.6;
var W_CENTER = 2.0;
var W_STOP   = 3.4;
var W_LANE   = 2.2;

// ---- small helpers (XZ plane, axis-aligned roads) -------------------------

function roadRange(road) {
    var cl = road.centerline;
    var horiz = road.axis === "h";
    var a0 = horiz ? cl[0].x : cl[0].z;
    var a1 = horiz ? cl[1].x : cl[1].z;
    var cross = horiz ? cl[0].z : cl[0].x;
    return { horiz: horiz, lo: Math.min(a0, a1), hi: Math.max(a0, a1), cross: cross };
}

function axisPoint(rr, along) {
    return rr.horiz ? { x: along, z: rr.cross } : { x: rr.cross, z: along };
}

// Lane centre offsets (world units off the centreline) for one carriageway half.
function laneDists(width, lanes) {
    var h = width * 0.5;
    return lanes >= 2 ? [0.25 * h, 0.75 * h] : [0.5 * h];
}
// Disks a road is trimmed against: every junction box the road passes through.
function disksForRoad(road, inters) {
    var out = [];
    for (var k = 0; k < inters.length; ++k)
        if (inters[k].roadIds.indexOf(road.id) >= 0)
            out.push({ x: inters[k].x, z: inters[k].z, r: inters[k].radius });
    return out;
}

// Clip one straight segment (p0->p1, XZ) against a set of disks, returning the
// visible sub-segments as [ [ptA, ptB], ... ] (world 3-tuples, y preserved).
function clipSegment(p0, p1, disks) {
    var dx = p1[0] - p0[0], dy = p1[1] - p0[1], dz = p1[2] - p0[2];
    var L2 = dx * dx + dz * dz;
    if (L2 < 1e-9) return [];
    var segLen = Math.sqrt(L2);
    var blocked = [];
    for (var k = 0; k < disks.length; ++k) {
        var cx = disks[k].x - p0[0], cz = disks[k].z - p0[2];
        var proj = (cx * dx + cz * dz) / L2;
        var px = proj * dx, pz = proj * dz;
        var perp2 = (cx - px) * (cx - px) + (cz - pz) * (cz - pz);
        var R = disks[k].r;
        if (perp2 >= R * R) continue;
        var halfT = Math.sqrt(R * R - perp2) / segLen;
        var t0 = proj - halfT, t1 = proj + halfT;
        if (t1 <= 0 || t0 >= 1) continue;
        blocked.push([Math.max(0, t0), Math.min(1, t1)]);
    }
    blocked.sort(function (a, b) { return a[0] - b[0]; });
    var merged = [];
    for (k = 0; k < blocked.length; ++k) {
        if (merged.length && blocked[k][0] <= merged[merged.length - 1][1] + 1e-4)
            merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], blocked[k][1]);
        else merged.push(blocked[k].slice());
    }
    function lerp(t) { return [p0[0] + dx * t, p0[1] + dy * t, p0[2] + dz * t]; }
    var out = [];
    var cursor = 0, eps = 1e-4;
    for (k = 0; k < merged.length; ++k) {
        if (merged[k][0] > cursor + eps)
            out.push([cursor <= eps ? p0 : lerp(cursor),
                      lerp(merged[k][0])]);
        cursor = merged[k][1];
    }
    if (cursor < 1 - eps) out.push([cursor <= eps ? p0 : lerp(cursor), p1]);
    return out;
}

// ---- cubic Bezier (junction connectors) -----------------------------------
//
// A connector is a cubic Bezier whose control points lie ALONG the incoming and
// outgoing track tangents, so it flows out of one lane centerline and into the
// next with no kink. p0/p3 are the exact recorded track endpoints; d0/d3 are the
// unit travel directions there.
function connectorCurve(p0, d0, p3, d3, y) {
    var dx = p3[0] - p0[0], dz = p3[2] - p0[2];
    var span = Math.sqrt(dx * dx + dz * dz);
    var k = Math.max(2.0, span * 0.42);
    var c1 = { x: p0[0] + d0.x * k, z: p0[2] + d0.z * k };
    var c2 = { x: p3[0] - d3.x * k, z: p3[2] - d3.z * k };
    // Sample finely (~1 world unit / segment) so the curve stays smooth at a
    // close-up junction zoom - never 3-4 straight chords.
    var n = Math.max(14, Math.min(64, Math.ceil(span * 1.4)));
    var out = [];
    for (var i = 0; i <= n; ++i) {
        var t = i / n, u = 1 - t;
        var x = u * u * u * p0[0] + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3[0];
        var z = u * u * u * p0[2] + 3 * u * u * t * c1.z + 3 * u * t * t * c2.z + t * t * t * p3[2];
        out.push([x, y, z]);
    }
    return out;
}

// A native end arrowhead: a single dedicated tip SEGMENT ending AT `tip` and
// pointing in `dir`, styled with styleId 3 (head). LineBatch3D renders the
// arrowhead triangle over this segment (heads are single-segment only), so the
// whole short segment becomes the arrow tip. `tip` is [x, y, z].
function emitArrowTip(lines, tip, dir) {
    var bx = tip[0] - dir.x * HEAD_TIP_WORLD;
    var bz = tip[2] - dir.z * HEAD_TIP_WORLD;
    lines.push({ p: [[bx, tip[1], bz], [tip[0], tip[1], tip[2]]],
                 c: COL_LANE, w: W_HEADTIP, s: 3, t: "arrow" });
}

// ===========================================================================
// MARKINGS - real painted road furniture, ALWAYS drawn
// ===========================================================================

function generateMarkings(tileData, laneY) {
    var y = (laneY === undefined) ? 1.8 : laneY;
    var roads = tileData.roads;
    var inters = tileData.intersections;

    var lines = [];
    function emit(pts, c, w, s, t) { if (pts.length >= 2) lines.push({ p: pts, c: c, w: w, s: s, t: t }); }

    // Emit a straight offset line, trimmed at every junction box it passes.
    function emitOffset(rr, off, disks, color, width, styleId, tag) {
        var pe = rr.horiz ? { x: 0, z: 1 } : { x: 1, z: 0 };
        var lo = axisPoint(rr, rr.lo), hi = axisPoint(rr, rr.hi);
        var p0 = [lo.x + pe.x * off, y, lo.z + pe.z * off];
        var p1 = [hi.x + pe.x * off, y, hi.z + pe.z * off];
        var pieces = clipSegment(p0, p1, disks);
        for (var i = 0; i < pieces.length; ++i) emit(pieces[i], color, width, styleId, tag);
    }

    for (var i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var h = r.width * 0.5;
        var rr = roadRange(r);
        var disks = disksForRoad(r, inters);

        // Solid white edge lines on both carriageway edges (every road).
        emitOffset(rr, -h, disks, COL_EDGE, W_EDGE, 0, "edge");
        emitOffset(rr,  h, disks, COL_EDGE, W_EDGE, 0, "edge");

        if (r.lanes >= 2) {
            // Dashed white divider between the two same-direction lanes, one per
            // carriageway half (at +-0.5h).
            emitOffset(rr, -0.5 * h, disks, COL_DIVIDE, W_DIVIDE, 1, "divider");
            emitOffset(rr,  0.5 * h, disks, COL_DIVIDE, W_DIVIDE, 1, "divider");
            // Double solid yellow centre between the two travel directions.
            var dc = Math.min(0.7, h * 0.12);
            emitOffset(rr, -dc, disks, COL_CENTER, W_CENTER, 0, "center");
            emitOffset(rr,  dc, disks, COL_CENTER, W_CENTER, 0, "center");
        } else {
            // Single dashed white centre line splitting the two directions.
            emitOffset(rr, 0, disks, COL_DIVIDE, W_DIVIDE, 1, "center");
        }
    }

    // Stop bars: a transverse white bar across each junction approach's lanes,
    // sitting at the junction-box edge.
    for (i = 0; i < inters.length; ++i) {
        var node = inters[i];
        var legs = node.legs;
        for (var li = 0; li < legs.length; ++li) {
            var leg = legs[li];
            var d = leg.dir;                          // points AWAY from the node
            var inx = -d.x, inz = -d.z;               // approaching-travel direction
            var rvx = -inz, rvz = inx;                // right of the approach (right-hand traffic)
            var ex = node.x + d.x * node.radius, ez = node.z + d.z * node.radius;
            var half = leg.width * 0.5;
            emit([[ex, y, ez], [ex + rvx * half, y, ez + rvz * half]],
                 COL_STOP, W_STOP, 0, "stop");
        }
    }

    var pointCount = 0;
    for (i = 0; i < lines.length; ++i) pointCount += lines[i].p.length;
    return { tileX: tileData.tileX, tileZ: tileData.tileZ,
             tileSize: tileData.tileSize, seed: tileData.seed,
             lines: lines, lineCount: lines.length, pointCount: pointCount };
}

// ===========================================================================
// LANE MODEL - toggleable teal map overlay (lane centerlines + maneuvers)
// ===========================================================================

function generateLaneModel(tileData, laneY) {
    var y = (laneY === undefined) ? 1.8 : laneY;
    var roads = tileData.roads;
    var inters = tileData.intersections;

    var lines = [];
    function emit(pts, c, w, s, t) { if (pts.length >= 2) lines.push({ p: pts, c: c, w: w, s: s, t: t }); }

    // A stable per-node key (coordinate based) so a track names the EXACT
    // junction at each end - never an object coerced to "[object Object]".
    function keyOf(nd) { return Math.round(nd.x) + "," + Math.round(nd.z); }
    function nodeOnRoad(roadId, horiz, along) {
        for (var k = 0; k < inters.length; ++k) {
            if (inters[k].roadIds.indexOf(roadId) < 0) continue;
            var a = horiz ? inters[k].x : inters[k].z;
            if (Math.abs(a - along) < 1.0) return inters[k];
        }
        return null;
    }

    // ---- STEP 1: trimmed, directed lane tracks (recorded with endpoints) ----
    // Each road is split at its junctions; every lane/direction becomes a track
    // trimmed back to the junction-box circle at both ends. We RECORD each
    // track's junction-side endpoints + travel direction so connectors are built
    // purely from these, never re-derived from road geometry.
    var tracks = [];
    for (var i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var horiz = r.axis === "h";
        var rr = roadRange(r);
        var dists = laneDists(r.width, r.lanes);
        var nLanes = dists.length;

        var breaks = [rr.lo, rr.hi];
        for (var j = 0; j < inters.length; ++j) {
            if (inters[j].roadIds.indexOf(r.id) < 0) continue;
            var av = horiz ? inters[j].x : inters[j].z;
            if (av > rr.lo + 1e-3 && av < rr.hi - 1e-3) breaks.push(av);
        }
        breaks.sort(function (p, q) { return p - q; });

        for (var bi = 0; bi + 1 < breaks.length; ++bi) {
            var s0 = breaks[bi], s1 = breaks[bi + 1];
            if (s1 - s0 < 4.0) continue;
            var n0 = nodeOnRoad(r.id, horiz, s0);
            var n1 = nodeOnRoad(r.id, horiz, s1);
            var R0 = n0 ? n0.radius : 0;
            var R1 = n1 ? n1.radius : 0;

            for (var d = 0; d < nLanes; ++d) {
                var dist = dists[d];
                // Trim each end to where this lane crosses the box circle.
                var cut0 = R0 > dist ? Math.sqrt(R0 * R0 - dist * dist) : 0;
                var cut1 = R1 > dist ? Math.sqrt(R1 * R1 - dist * dist) : 0;
                var a0 = s0 + cut0, a1 = s1 - cut1;
                if (a1 - a0 < 2.0) continue;

                for (var sgn = -1; sgn <= 1; sgn += 2) {
                    var dir = horiz ? { x: sgn, z: 0 } : { x: 0, z: sgn };
                    var rvx = -dir.z, rvz = dir.x;   // right of travel (right-hand traffic)
                    // Entry is the up-travel end, exit the down-travel end.
                    var entAlong = sgn > 0 ? a0 : a1;
                    var exAlong  = sgn > 0 ? a1 : a0;
                    var entNode  = sgn > 0 ? n0 : n1;
                    var exNode   = sgn > 0 ? n1 : n0;
                    var ep = axisPoint(rr, entAlong), xp = axisPoint(rr, exAlong);
                    var entry = [ep.x + rvx * dist, y, ep.z + rvz * dist];
                    var exit  = [xp.x + rvx * dist, y, xp.z + rvz * dist];
                    emit([entry, exit], COL_LANE, W_LANE, 0, "lane");
                    emitChevronLine(lines, entry, exit);
                    tracks.push({ entry: entry, exit: exit, dir: dir, laneIdx: d,
                                  nLanes: nLanes, roadId: r.id,
                                  entKey: entNode ? keyOf(entNode) : null,
                                  exKey:  exNode ? keyOf(exNode) : null,
                                  width: r.width, lanes: r.lanes });
                }
            }
        }
    }

    // ---- STEP 2: connectors purely from recorded track endpoints ----
    // Group incoming (tracks EXITING at a node) and outgoing (tracks ENTERING a
    // node), then fan every incoming lane out to each legal outgoing lane.
    var incoming = {}, outgoing = {};
    for (i = 0; i < tracks.length; ++i) {
        var t = tracks[i];
        if (t.exKey)  (incoming[t.exKey]  || (incoming[t.exKey]  = [])).push(t);
        if (t.entKey) (outgoing[t.entKey] || (outgoing[t.entKey] = [])).push(t);
    }
    for (var key in incoming) {
        var inc = incoming[key], outs = outgoing[key] || [];
        for (var ii = 0; ii < inc.length; ++ii) {
            var A = inc[ii];
            for (var oo = 0; oo < outs.length; ++oo) {
                var B = outs[oo];
                var dot = A.dir.x * B.dir.x + A.dir.z * B.dir.z;
                var cr = A.dir.x * B.dir.z - A.dir.z * B.dir.x;  // >0 right, <0 left
                if (A.roadId === B.roadId && dot < -0.7) continue;   // U-turn: never
                // Right-hand-traffic lane selection: straight stays in-lane, a
                // right turn uses the kerb-side (outer) lanes, a left turn the
                // centre-side (inner) lanes. One connector per legal outgoing
                // road, so each incoming lane fans left/straight/right cleanly.
                if (dot > 0.7) {
                    if (A.laneIdx !== B.laneIdx) continue;       // straight: same lane
                } else if (dot > -0.3) {
                    if (cr > 0) {                                // right turn
                        if (A.laneIdx !== A.nLanes - 1 || B.laneIdx !== B.nLanes - 1) continue;
                    } else {                                     // left turn
                        if (A.laneIdx !== 0 || B.laneIdx !== 0) continue;
                    }
                } else {
                    continue;                                    // too sharp to be legal
                }
                // A connector IS a lane track: same cyan colour, same width, same
                // solid style - only the curvature + arrowhead differ.
                var curve = connectorCurve(A.exit, A.dir, B.entry, B.dir, y);
                emit(curve, COL_LANE, W_LANE, 0, "lane");
                // Native chevron direction glyphs along the maneuver curve.
                if (curve.length >= 2) lines.push({ p: curve, c: COL_LANE, w: W_CHEV, s: 2, t: "chevron" });
                // Native arrowhead at the connector tip (single dedicated segment).
                var tip = curve[curve.length - 1];
                emitArrowTip(lines, tip, B.dir);
            }
        }
    }

    var pointCount = 0;
    for (i = 0; i < lines.length; ++i) pointCount += lines[i].p.length;
    return { tileX: tileData.tileX, tileZ: tileData.tileZ,
             tileSize: tileData.tileSize, seed: tileData.seed,
             lines: lines, lineCount: lines.length, pointCount: pointCount };
}

// Native direction chevrons along a straight lane track: one chevron-patterned
// overlay line (styleId 2) sharing the track's path. The glyphs point in the
// travel direction and march when the batch's flowTime is advanced. Skipped for
// stubs too short to carry a single glyph.
function emitChevronLine(lines, a, b) {
    var dx = b[0] - a[0], dz = b[2] - a[2];
    if (Math.sqrt(dx * dx + dz * dz) < CHEV_LEN + CHEV_GAP) return;
    lines.push({ p: [a, b], c: COL_LANE, w: W_CHEV, s: 2, t: "chevron" });
}

// ---- render-buffer builder (bulk path) ------------------------------------
//
// Each logical line maps to exactly ONE render polyline; the per-line styleId
// rides in a parallel uint16 buffer, so dashes are drawn by the GPU style
// texture. Returns typed arrays ready for
// LineBatch3D.setBulk(positions, starts, colors, widths, styleIds).

function hexToRgba(c) {
    var s = c.charAt(0) === "#" ? c.substring(1) : c;
    var r = parseInt(s.substring(0, 2), 16);
    var g = parseInt(s.substring(2, 4), 16);
    var b = parseInt(s.substring(4, 6), 16);
    var a = s.length >= 8 ? parseInt(s.substring(6, 8), 16) : 255;
    return [r, g, b, a];
}

function buildBulkArrays(model) {
    var src = model.lines;
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
