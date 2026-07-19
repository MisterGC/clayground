// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Seed-deterministic procedural city generator for the neoncity demo.
//
// This module is PURE (no QML types, no Math.random). Everything it produces
// is a function of (globalSeed, tileX, tileZ, tileSize), so the same seed
// yields a byte-identical city on every run and every machine.
//
// ============================================================================
// ROAD NETWORK - a street planner's grid, not a comb
// ============================================================================
// The network is a continuous arterial GRID:
//
//  * ONE vertical avenue per tile COLUMN, at x = xmin + f*tileSize with f in
//    [0.35,0.65] derived only from (globalSeed, col). It is IDENTICAL for every
//    tile of that column and spans the full tile edge-to-edge, so the avenue is
//    continuous over every row of the whole city.
//  * ONE horizontal avenue per tile ROW, keyed only to (globalSeed, row), same
//    idea. The two avenues cross once per tile in a real 4-way.
//  * Optional LOCAL streets subdivide the blocks. Their positions are keyed to
//    the column / row too (the canonical shared identity), so neighbouring tiles
//    agree at the seam. A minimum parallel spacing of >= 0.20*tileSize between
//    ANY two parallel carriageways is enforced deterministically (a local that
//    sits too close to the avenue is dropped for the whole column/row).
//  * A local street is a THROUGH street (edge-to-edge, a 4-way where it crosses
//    the perpendicular avenue) OR it T-terminates at the perpendicular avenue
//    (a 3-way). Which happens is decided by per-boundary crossing bits keyed to
//    the SHARED boundary index, so two tiles either both carry the street across
//    their common edge or both stop it at their avenue - a local street never
//    ends in open ground.
//
// EDGE DETERMINISM (why roads connect across tile borders):
// Every road that touches a tile edge is keyed to the tile COLUMN or ROW (for
// avenues and local through-streets) or to the shared BOUNDARY index (for the
// T-termination bits). Two tiles sharing an edge therefore compute the identical
// geometry there independently, so the grid is seamless. Purely interior detail
// (buildings, foliage jitter) is private to a tile and free to vary.
//
// ============================================================================
// PHASE-5 CONTRACT - the data shape returned by generateTile()
// ============================================================================
// generateTile() returns a plain object separating city DATA from any visual.
// Downstream consumers (detailed lane model, cars, foliage, junction asphalt)
// read the road GRAPH and the explicit junction graph below - they never
// re-derive geometry from overlaps.
//
// {
//   tileX, tileZ, tileSize, seed,              // identity
//   bounds: { xmin, zmin, xmax, zmax },        // world-space tile extents
//
//   roads: [                                   // the road GRAPH (world coords)
//     {
//       id:        <int>,                      // unique within the tile
//       kind:      "avenue" | "local",         // arterial vs. side street
//       axis:      "h" | "v",                  // h = runs along X, v = along Z
//       width:     <real>,                     // full carriageway width (world)
//       lanes:     <int>,                      // travel lanes PER DIRECTION
//       centerline:[ {x,z}, {x,z} ]            // straight polyline, 2 points
//     }, ...
//   ],
//
//   intersections: [                           // the explicit junction graph
//     { x, z,                                  // node center (world)
//       roadIds: [<int>, ...],                 // roads meeting here
//       radius,                                // junction-box radius (world)
//       legs: [                                // one per road-direction leaving
//         { roadId, dir:{x,z},                 // unit vector AWAY from the node
//           width, lanes } ] }, ...
//   ],
//
//   buildings: [ { x, z, w, d, height, colorIndex, accent, accentIndex }, ...],
//   parks:     [ { x, z, w, d }, ... ],
//   landmarks: [ { x, z, footprint, height, kind }, ... ],
//   trees:     [ { x, z, trunkH, trunkR, canopyH, canopyR }, ... ],
//   lamps:     [ { x, z, h }, ... ]
// }
//
// Trees and lamps double as LIDAR obstacles: their world footprints are pure
// data here so lidar.js can box them without touching any QML.
// ============================================================================

.pragma library

// ---- integer hashing (fmix32 / xxhash-style finalizer) --------------------

function u32(x) { return x >>> 0; }

function mix32(h) {
    h = u32(h);
    h ^= h >>> 16; h = u32(Math.imul(h, 0x7feb352d));
    h ^= h >>> 15; h = u32(Math.imul(h, 0x846ca68b));
    h ^= h >>> 16;
    return u32(h);
}

// Order-sensitive combine of an accumulator with one more integer.
function combine(acc, v) {
    return mix32(u32(acc) ^ u32(Math.imul(u32(v) + 0x9e3779b9, 0x85ebca6b)));
}

// Hash an arbitrary list of integers into a uint32. Negative coordinates are
// folded via two's complement (u32), which is stable and deterministic.
function hashN() {
    var h = 0x811c9dc5;
    for (var i = 0; i < arguments.length; ++i) h = combine(h, arguments[i]);
    return u32(h);
}

// mulberry32 PRNG seeded from a uint32; returns floats in [0, 1).
function rngFrom(seed) {
    var s = u32(seed);
    return function () {
        s = u32(s + 0x6D2B79F5);
        var t = s;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return u32(t ^ (t >>> 14)) / 4294967296;
    };
}

// A single deterministic fraction in [0,1) from an integer hash.
function hfrac(h) { return u32(h) / 4294967296; }

// ---- salts (keep the hash families disjoint) ------------------------------

var SALT_AVE_V   = 0x41564556; // "AVEV" - vertical avenue x per COLUMN
var SALT_AVE_H   = 0x41564548; // "AVEH" - horizontal avenue z per ROW
var SALT_LOC_V   = 0x4C4F4356; // "LOCV" - vertical local street per COLUMN
var SALT_LOC_H   = 0x4C4F4348; // "LOCH" - horizontal local street per ROW
var SALT_VXB     = 0x56584220; // "VXB " - vertical local crossing a Z-boundary
var SALT_HXB     = 0x48584220; // "HXB " - horizontal local crossing an X-boundary
var SALT_TILE    = 0x54494C45; // "TILE" - per-tile interior variation
var SALT_LMK     = 0x4C4D4B21; // "LMK!" - landmark placement
var SALT_FOLIAGE = 0x464F4C49; // "FOLI" - trees + lamp posts (lidar targets)

// ---- grid tuning ----------------------------------------------------------

var AVE_FRAC_MIN  = 0.35;      // avenue sits in the central [0.35,0.65] band
var AVE_FRAC_SPAN = 0.30;
var LOC_FRAC_MIN  = 0.16;      // local streets range wider, [0.16,0.84]
var LOC_FRAC_SPAN = 0.68;
var MIN_SPACING   = 0.20;      // min gap (fraction of tileSize) between parallels
var JUNCTION_APRON = 2.5;      // paved margin added around the widest leg

// ---- public: per-tile seed ------------------------------------------------

function tileSeed(globalSeed, tileX, tileZ) {
    return hashN(globalSeed, SALT_TILE, tileX, tileZ);
}

// ---- avenue positions (column / row keyed => city-wide continuous) --------

function avenueFrac(salt, g, idx) {
    return AVE_FRAC_MIN + AVE_FRAC_SPAN * hfrac(hashN(g, salt, idx));
}
function localFrac(salt, g, idx) {
    return LOC_FRAC_MIN + LOC_FRAC_SPAN * hfrac(hashN(g, salt, idx + 0x51));
}
// Does the column/row carry a local street at all (~75% of them do).
function hasLocal(salt, g, idx) { return (hashN(g, salt, idx) % 4) !== 0; }
// Does the local street reach across boundary `b` (shared identity => seamless).
function crossesBoundary(salt, g, keyIdx, b) { return (hashN(g, salt, keyIdx, b) & 1) !== 0; }

// ---- widths / lanes -------------------------------------------------------

function avenueWidth(tileSize) { return Math.max(12, tileSize * 0.055); }
function localWidth(tileSize)  { return Math.max(7,  tileSize * 0.030); }

// ---- geometry helpers -----------------------------------------------------

// squared distance from point (px,pz) to segment (x1,z1)-(x2,z2)
function distSqToSeg(px, pz, x1, z1, x2, z2) {
    var dx = x2 - x1, dz = z2 - z1;
    var len2 = dx * dx + dz * dz;
    var t = len2 > 0 ? ((px - x1) * dx + (pz - z1) * dz) / len2 : 0;
    t = t < 0 ? 0 : (t > 1 ? 1 : t);
    var cx = x1 + t * dx, cz = z1 + t * dz;
    var ex = px - cx, ez = pz - cz;
    return ex * ex + ez * ez;
}

// ---- road graph -----------------------------------------------------------
//
// Builds every road segment of the tile. Verticals run along Z (axis "v"),
// horizontals along X (axis "h"). Avenues span the tile edge-to-edge; a local
// street either spans edge-to-edge (a through street) or terminates at the
// perpendicular avenue (a T-junction), decided by the shared-boundary bits.

function buildRoads(g, tileX, tileZ, tileSize) {
    var xmin = tileX * tileSize, zmin = tileZ * tileSize;
    var xmax = xmin + tileSize,  zmax = zmin + tileSize;
    var avW = avenueWidth(tileSize), loW = localWidth(tileSize);
    var minSep = MIN_SPACING * tileSize;

    var avenueX = xmin + avenueFrac(SALT_AVE_V, g, tileX) * tileSize;
    var avenueZ = zmin + avenueFrac(SALT_AVE_H, g, tileZ) * tileSize;

    var roads = [];
    var nextId = 0;
    function addRoad(kind, axis, width, lanes, x0, z0, x1, z1) {
        roads.push({ id: nextId++, kind: kind, axis: axis, width: width, lanes: lanes,
                     centerline: [{ x: x0, z: z0 }, { x: x1, z: z1 }] });
    }

    // Avenues (always present, edge-to-edge, 2 lanes per direction).
    addRoad("avenue", "v", avW, 2, avenueX, zmin, avenueX, zmax);
    addRoad("avenue", "h", avW, 2, xmin, avenueZ, xmax, avenueZ);

    // Vertical local street: x keyed to the column, so it is identical for every
    // row and its two tiles agree at the shared boundary.
    if (hasLocal(SALT_LOC_V, g, tileX)) {
        var localX = xmin + localFrac(SALT_LOC_V, g, tileX) * tileSize;
        if (Math.abs(localX - avenueX) >= minSep) {
            var vTop = crossesBoundary(SALT_VXB, g, tileX, tileZ);      // reaches top edge
            var vBot = crossesBoundary(SALT_VXB, g, tileX, tileZ + 1);  // reaches bottom edge
            var z0 = vTop ? zmin : avenueZ;
            var z1 = vBot ? zmax : avenueZ;
            if (z1 - z0 > minSep * 0.5)
                addRoad("local", "v", loW, 1, localX, z0, localX, z1);
        }
    }

    // Horizontal local street: z keyed to the row.
    if (hasLocal(SALT_LOC_H, g, tileZ)) {
        var localZ = zmin + localFrac(SALT_LOC_H, g, tileZ) * tileSize;
        if (Math.abs(localZ - avenueZ) >= minSep) {
            var hLeft  = crossesBoundary(SALT_HXB, g, tileZ, tileX);      // reaches left edge
            var hRight = crossesBoundary(SALT_HXB, g, tileZ, tileX + 1);  // reaches right edge
            var x0 = hLeft  ? xmin : avenueX;
            var x1 = hRight ? xmax : avenueX;
            if (x1 - x0 > minSep * 0.5)
                addRoad("local", "h", loW, 1, x0, localZ, x1, localZ);
        }
    }

    return { roads: roads, avenueX: avenueX, avenueZ: avenueZ,
             bounds: { xmin: xmin, zmin: zmin, xmax: xmax, zmax: zmax } };
}

// Along-span + cross-coordinate of an axis-aligned road.
function roadSpan(road) {
    var cl = road.centerline;
    if (road.axis === "h")
        return { cross: cl[0].z, lo: Math.min(cl[0].x, cl[1].x), hi: Math.max(cl[0].x, cl[1].x) };
    return { cross: cl[0].x, lo: Math.min(cl[0].z, cl[1].z), hi: Math.max(cl[0].z, cl[1].z) };
}

// ---- explicit junction graph ----------------------------------------------
//
// Every crossing of a vertical with a horizontal road becomes a node. Each node
// records the legs (one per road-direction leaving it) plus a box radius, so a
// 4-way carries 4 legs and a T carries 3. Downstream consumers use THIS graph
// rather than re-deriving overlaps.

function buildJunctions(roads) {
    var EPS = 0.5;
    var vs = [], hs = [];
    for (var i = 0; i < roads.length; ++i)
        (roads[i].axis === "v" ? vs : hs).push(roads[i]);

    var nodes = {};
    function node(x, z) {
        var key = Math.round(x) + "," + Math.round(z);
        if (!nodes[key]) nodes[key] = { x: x, z: z, legs: [], roadIds: [], _seen: {} };
        return nodes[key];
    }
    function addLeg(n, road, dx, dz) {
        var tag = road.id + ":" + dx + ":" + dz;
        if (n._seen[tag]) return;
        n._seen[tag] = 1;
        n.legs.push({ roadId: road.id, dir: { x: dx, z: dz }, width: road.width, lanes: road.lanes });
        if (n.roadIds.indexOf(road.id) < 0) n.roadIds.push(road.id);
    }

    for (var vi = 0; vi < vs.length; ++vi) {
        var V = vs[vi], vsp = roadSpan(V);           // vsp.cross = x, span in z
        for (var hi = 0; hi < hs.length; ++hi) {
            var H = hs[hi], hsp = roadSpan(H);        // hsp.cross = z, span in x
            var x = vsp.cross, z = hsp.cross;
            if (x < hsp.lo - EPS || x > hsp.hi + EPS) continue;
            if (z < vsp.lo - EPS || z > vsp.hi + EPS) continue;
            var n = node(x, z);
            if (vsp.lo < z - EPS) addLeg(n, V, 0, -1);  // vertical extends up
            if (vsp.hi > z + EPS) addLeg(n, V, 0,  1);  // ... and down
            if (hsp.lo < x - EPS) addLeg(n, H, -1, 0);  // horizontal extends left
            if (hsp.hi > x + EPS) addLeg(n, H,  1, 0);  // ... and right
        }
    }

    var out = [];
    for (var k in nodes) {
        var nd = nodes[k];
        if (nd.legs.length < 2) continue;
        var maxHalf = 3.0;
        for (var li = 0; li < nd.legs.length; ++li)
            maxHalf = Math.max(maxHalf, nd.legs[li].width * 0.5);
        out.push({ x: nd.x, z: nd.z, roadIds: nd.roadIds, legs: nd.legs,
                   radius: maxHalf + JUNCTION_APRON });
    }
    return out;
}

// ---- roadside foliage + lamps (deterministic, also lidar obstacles) -------
//
// Walks every road and drops lamp posts at a fixed spacing, offset to the curb
// and alternating sides, plus a sparse scatter of trees in the same curb band.
// Every candidate is REJECTED if it falls on ANY carriageway (within halfWidth +
// margin of a road segment) or inside any junction box, so nothing ever stands
// on the road. Parks get a small deterministic tree cluster.
function generateFoliage(seed, roads, junctions, parks) {
    var trees = [];
    var lamps = [];

    var LAMP_SP = 32.0;        // world units between lamp posts along a road
    var CURB = 3.0;            // gap from the carriageway edge to the pole
    var TREE_OUT = 2.5;        // trees sit a touch further out than the lamps
    var CLEAR = 1.5;           // keep-clear margin beyond each road's own edge

    // Reject a point that sits on / too near any carriageway or junction box.
    function onRoad(px, pz) {
        for (var i = 0; i < roads.length; ++i) {
            var cl = roads[i].centerline;
            var thr = roads[i].width * 0.5 + CLEAR;
            if (distSqToSeg(px, pz, cl[0].x, cl[0].z, cl[1].x, cl[1].z) < thr * thr) return true;
        }
        for (var j = 0; j < junctions.length; ++j) {
            var dx = px - junctions[j].x, dz = pz - junctions[j].z;
            var r = junctions[j].radius + CLEAR;
            if (dx * dx + dz * dz < r * r) return true;
        }
        return false;
    }

    for (var i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var cl = r.centerline;
        var a = cl[0], b = cl[1];
        var dx = b.x - a.x, dz = b.z - a.z;
        var len = Math.sqrt(dx * dx + dz * dz);
        if (len < LAMP_SP) continue;
        var ux = dx / len, uz = dz / len;
        var pex = uz, pez = -ux;                 // unit perpendicular (right)
        var half = r.width * 0.5;
        var rng = rngFrom(hashN(seed, SALT_FOLIAGE, r.id));
        var n = Math.floor(len / LAMP_SP);
        for (var k = 1; k < n; ++k) {
            var s = k * LAMP_SP;
            var side = (k % 2 === 0) ? 1 : -1;
            var lx = a.x + ux * s + pex * side * (half + CURB);
            var lz = a.z + uz * s + pez * side * (half + CURB);
            if (!onRoad(lx, lz)) lamps.push({ x: lx, z: lz, h: 9.0 + rng() * 1.5 });
            // Sparse trees on the opposite curb, so they never sit under a lamp.
            if (rng() < 0.45) {
                var tx = a.x + ux * s - pex * side * (half + CURB + TREE_OUT);
                var tz = a.z + uz * s - pez * side * (half + CURB + TREE_OUT);
                if (!onRoad(tx, tz)) trees.push(_makeTree(tx, tz, rng));
            }
        }
    }

    // Park clusters: a handful of trees jittered inside each green parcel.
    for (i = 0; i < parks.length; ++i) {
        var pk = parks[i];
        var prng = rngFrom(hashN(seed, SALT_FOLIAGE, 0x50524B00 + i)); // "PRK"
        var cnt = 2 + Math.floor(prng() * 3);    // 2..4
        for (var j = 0; j < cnt; ++j) {
            var jx = pk.x + (prng() - 0.5) * pk.w * 0.7;
            var jz = pk.z + (prng() - 0.5) * pk.d * 0.7;
            if (!onRoad(jx, jz)) trees.push(_makeTree(jx, jz, prng));
        }
    }

    return { trees: trees, lamps: lamps };
}

// Canopy sized so a tree reads as a tree next to a car (~1.4u wide) - a modest
// crown, never the road-swallowing giant the old radius produced.
function _makeTree(x, z, rng) {
    var scale = 0.85 + rng() * 0.5;
    return {
        x: x, z: z,
        trunkH: 2.6 * scale, trunkR: 0.42 * scale,
        canopyH: 4.0 * scale, canopyR: 1.35 * scale
    };
}

// ---- main generator -------------------------------------------------------

function generateTile(globalSeed, tileX, tileZ, tileSize) {
    var seed = tileSeed(globalSeed, tileX, tileZ);
    var rng = rngFrom(seed);

    var built = buildRoads(globalSeed, tileX, tileZ, tileSize);
    var roads = built.roads;
    var bounds = built.bounds;
    var xmin = bounds.xmin, zmin = bounds.zmin, xmax = bounds.xmax, zmax = bounds.zmax;
    var avenueX = built.avenueX, avenueZ = built.avenueZ;

    var intersections = buildJunctions(roads);

    // Segment list for fast "is this cell on a road?" tests.
    var segs = [];
    for (var i = 0; i < roads.length; ++i) {
        var cl = roads[i].centerline;
        segs.push([cl[0].x, cl[0].z, cl[1].x, cl[1].z, roads[i].width * 0.5]);
    }

    // ---- parcels: grid the tile, drop cells that a road runs through ------
    var N = 7;
    var cell = tileSize / N;
    var buildable = cell * 0.68; // footprint side, leaves a gap to the street
    var clearance = avenueWidth(tileSize) * 0.5 + cell * 0.18;

    var downtown = rng();            // 0..1 tile-wide tallness
    var buildings = [];
    var parks = [];
    var landmarks = [];

    // Reserve one landmark cell on some tiles (deterministic).
    var wantLandmark = (hashN(seed, SALT_LMK) % 100) < 32; // ~1/3 of tiles
    var lmCol = Math.floor(rng() * N), lmRow = Math.floor(rng() * N);

    for (var cz = 0; cz < N; ++cz) {
        for (var cx = 0; cx < N; ++cx) {
            var wx = xmin + (cx + 0.5) * cell;
            var wz = zmin + (cz + 0.5) * cell;

            // On a road? -> street, nothing to place.
            var isRoad = false;
            for (var k = 0; k < segs.length; ++k) {
                var g = segs[k];
                if (distSqToSeg(wx, wz, g[0], g[1], g[2], g[3]) < (g[4] + clearance) * (g[4] + clearance)) {
                    isRoad = true; break;
                }
            }
            if (isRoad) continue;

            var cellRng = rngFrom(hashN(seed, cx, cz));

            if (wantLandmark && cx === lmCol && cz === lmRow) {
                landmarks.push({ x: wx, z: wz, footprint: buildable * 1.05,
                                 height: 200 + cellRng() * 130, kind: "tower" });
                continue;
            }

            // A few open plazas / parks.
            if (cellRng() < 0.10) {
                parks.push({ x: wx, z: wz, w: buildable * 1.15, d: buildable * 1.15 });
                continue;
            }

            // Height: taller near the central avenue crossing and downtown tiles.
            var ddx = (wx - avenueX) / (tileSize * 0.6);
            var ddz = (wz - avenueZ) / (tileSize * 0.6);
            var prox = 1.0 - Math.min(1.0, Math.sqrt(ddx * ddx + ddz * ddz));
            var hMax = 14 + (0.25 + 0.75 * downtown) * 210;
            var h = 10 + (prox * 0.55 + cellRng() * 0.45) * (hMax - 10);

            var jitterX = (cellRng() - 0.5) * cell * 0.12;
            var jitterZ = (cellRng() - 0.5) * cell * 0.12;
            var fw = buildable * (0.8 + cellRng() * 0.2);
            var fd = buildable * (0.8 + cellRng() * 0.2);

            buildings.push({
                x: wx + jitterX, z: wz + jitterZ,
                w: fw, d: fd, height: h,
                colorIndex: Math.floor(cellRng() * 5),
                accent: cellRng() < 0.6,
                accentIndex: Math.floor(cellRng() * 4)
            });
        }
    }

    var foliage = generateFoliage(seed, roads, intersections, parks);

    return {
        tileX: tileX, tileZ: tileZ, tileSize: tileSize, seed: seed,
        bounds: { xmin: xmin, zmin: zmin, xmax: xmax, zmax: zmax },
        roads: roads,
        intersections: intersections,
        buildings: buildings,
        parks: parks,
        landmarks: landmarks,
        trees: foliage.trees,
        lamps: foliage.lamps
    };
}
