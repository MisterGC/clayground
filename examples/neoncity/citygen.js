// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Seed-deterministic procedural city generator for the neoncity demo.
//
// This module is PURE (no QML types, no Math.random). Everything it produces
// is a function of (globalSeed, tileX, tileZ, tileSize), so the same seed
// yields a byte-identical city on every run and every machine.
//
// ============================================================================
// PHASE-5 CONTRACT - the data shape returned by generateTile()
// ============================================================================
// generateTile() returns a plain object separating city DATA from any visual.
// Phase 5 (detailed lane model) consumes exactly this - it does NOT re-derive
// geometry, it reads the road graph below and layers lanes on top.
//
// {
//   tileX, tileZ, tileSize, seed,              // identity
//   bounds: { xmin, zmin, xmax, zmax },        // world-space tile extents
//
//   roads: [                                   // the road GRAPH (world coords)
//     {
//       id:        <int>,                      // unique within the tile
//       kind:      "spine" | "feeder",         // avenue vs. side street
//       axis:      "h" | "v",                  // h = runs along X, v = along Z
//       width:     <real>,                     // full carriageway width (world)
//       centerline:[ {x,z}, {x,z}, ... ]       // polyline, >= 2 points
//     }, ...
//   ],
//
//   intersections: [                           // where centerlines meet
//     { x, z, roadIds: [<int>, ...] }, ...
//   ],
//
//   buildings: [                               // one entry per built parcel
//     { x, z,                                  // footprint center (world)
//       w, d,                                  // footprint size (world)
//       height,                                // world units
//       colorIndex,                            // index into body palette
//       accent,                                // bool: has a neon crown
//       accentIndex }, ...                     // index into neon palette
//   ],
//
//   parks: [ { x, z, w, d }, ... ],            // flat plaza / green parcels
//
//   landmarks: [                               // voxel hero buildings
//     { x, z, footprint, height, kind }, ...   // kind: "tower"
//   ],
//
//   trees: [                                   // low-poly street/park trees
//     { x, z,                                  // trunk center (world)
//       trunkH, trunkR,                        // trunk box (dark)
//       canopyH, canopyR }, ...                // canopy cone (teal), on trunk
//   ],
//
//   lamps: [ { x, z, h }, ... ]                // lamp posts: pole height h,
//                                              // small gold head at the top
// }
//
// Trees and lamps double as LIDAR obstacles: their world footprints are pure
// data here so lidar.js can box them without touching any QML.
//
// EDGE DETERMINISM (why roads connect across tile borders):
// A tile's road crossings on each of its four edges are derived from an
// edgeSeed keyed to the CANONICAL edge identity (the shared boundary index),
// never from the tile itself. Two tiles sharing an edge therefore compute the
// identical crossing positions independently, so feeder roads line up exactly
// where tiles meet. Internal routing (spines, jogs) is private to a tile and
// free to vary without ever breaking a seam.
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

// ---- salts (keep the four hash families disjoint) -------------------------

var SALT_H_EDGE  = 0x484F5249; // "HORI" - crossings on a constant-Z boundary
var SALT_V_EDGE  = 0x56455254; // "VERT" - crossings on a constant-X boundary
var SALT_TILE    = 0x54494C45; // "TILE" - per-tile interior variation
var SALT_LMK     = 0x4C4D4B21; // "LMK!" - landmark placement
var SALT_FOLIAGE = 0x464F4C49; // "FOLI" - trees + lamp posts (lidar targets)

// ---- public: per-tile seed ------------------------------------------------

function tileSeed(globalSeed, tileX, tileZ) {
    return hashN(globalSeed, SALT_TILE, tileX, tileZ);
}

// ---- edge crossing positions ----------------------------------------------
// A boundary at index b between tile b-1 and tile b is identified by b alone,
// so both neighbours hash the same seed and agree on the crossings.

function hEdgeSeed(g, col, boundaryZ) { return hashN(g, SALT_H_EDGE, col, boundaryZ); }
function vEdgeSeed(g, boundaryX, row) { return hashN(g, SALT_V_EDGE, boundaryX, row); }

// Returns sorted absolute coordinates (origin + fraction*tileSize) of the
// 2..4 road crossings on one edge. Fractions live in [0.15, 0.85] so every
// crossing sits comfortably inside the interior band and reaches a spine.
function edgeCrossings(seed, origin, tileSize) {
    var rng = rngFrom(seed);
    var n = 2 + Math.floor(rng() * 3); // 2, 3 or 4
    var fr = [];
    for (var i = 0; i < n; ++i) fr.push(0.15 + rng() * 0.70);
    fr.sort(function (a, b) { return a - b; });
    var out = [];
    for (i = 0; i < n; ++i) out.push(origin + fr[i] * tileSize);
    return out;
}

// ---- geometry helper ------------------------------------------------------

function minArr(a) { var m = a[0]; for (var i = 1; i < a.length; ++i) if (a[i] < m) m = a[i]; return m; }
function maxArr(a) { var m = a[0]; for (var i = 1; i < a.length; ++i) if (a[i] > m) m = a[i]; return m; }

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

// ---- roadside foliage + lamps (deterministic, also lidar obstacles) -------
//
// Walks every road and drops lamp posts at a fixed spacing, offset to the curb
// and alternating sides, plus a sparse scatter of trees in the same curb band.
// Parks get a small deterministic tree cluster. Everything keys off a foliage
// salt so it never disturbs the building/road/car streams (lane export stays
// byte-identical). No Math.random - pure function of (seed, road/park index).
function generateFoliage(seed, roads, parks, bounds) {
    var trees = [];
    var lamps = [];

    var LAMP_SP = 30.0;        // world units between lamp posts along a road
    var CURB = 2.5;            // gap from the carriageway edge to the pole
    var TREE_OUT = 2.0;        // trees sit a touch further out than the lamps

    for (var i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var cl = r.centerline;
        var a = cl[0], b = cl[cl.length - 1];
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
            lamps.push({ x: lx, z: lz, h: 9.0 + rng() * 1.5 });
            // Sparse trees on the opposite curb, so they never sit under a lamp.
            if (rng() < 0.45) {
                var tx = a.x + ux * s - pex * side * (half + CURB + TREE_OUT);
                var tz = a.z + uz * s - pez * side * (half + CURB + TREE_OUT);
                trees.push(_makeTree(tx, tz, rng));
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
            trees.push(_makeTree(jx, jz, prng));
        }
    }

    return { trees: trees, lamps: lamps };
}

function _makeTree(x, z, rng) {
    var scale = 0.85 + rng() * 0.5;
    return {
        x: x, z: z,
        trunkH: 3.0 * scale, trunkR: 0.55 * scale,
        canopyH: 6.0 * scale, canopyR: 2.4 * scale
    };
}

// ---- main generator -------------------------------------------------------

function generateTile(globalSeed, tileX, tileZ, tileSize) {
    var seed = tileSeed(globalSeed, tileX, tileZ);
    var rng = rngFrom(seed);

    var xmin = tileX * tileSize, zmin = tileZ * tileSize;
    var xmax = xmin + tileSize,  zmax = zmin + tileSize;

    // Edge crossings (shared with neighbours via canonical boundary indices).
    var topX   = edgeCrossings(hEdgeSeed(globalSeed, tileX, tileZ),     xmin, tileSize);
    var botX   = edgeCrossings(hEdgeSeed(globalSeed, tileX, tileZ + 1), xmin, tileSize);
    var leftZ  = edgeCrossings(vEdgeSeed(globalSeed, tileX, tileZ),     zmin, tileSize);
    var rightZ = edgeCrossings(vEdgeSeed(globalSeed, tileX + 1, tileZ), zmin, tileSize);

    // Interior avenues (spines) - private to this tile.
    var spineZ = zmin + tileSize * (0.40 + rng() * 0.20); // horizontal avenue
    var spineX = xmin + tileSize * (0.40 + rng() * 0.20); // vertical avenue

    var mainW   = Math.max(8, tileSize * 0.045);
    var feederW = Math.max(5, tileSize * 0.028);

    var roads = [];
    var nextId = 0;
    function addRoad(kind, axis, width, pts) {
        roads.push({ id: nextId++, kind: kind, axis: axis, width: width, centerline: pts });
    }

    // Vertical feeders drop from the top/bottom edges to the horizontal spine.
    var allSpineHx = [spineX];
    for (var i = 0; i < topX.length; ++i) {
        addRoad("feeder", "v", feederW, [{ x: topX[i], z: zmin }, { x: topX[i], z: spineZ }]);
        allSpineHx.push(topX[i]);
    }
    for (i = 0; i < botX.length; ++i) {
        addRoad("feeder", "v", feederW, [{ x: botX[i], z: zmax }, { x: botX[i], z: spineZ }]);
        allSpineHx.push(botX[i]);
    }
    // Horizontal feeders reach from the left/right edges to the vertical spine.
    var allSpineVz = [spineZ];
    for (i = 0; i < leftZ.length; ++i) {
        addRoad("feeder", "h", feederW, [{ x: xmin, z: leftZ[i] }, { x: spineX, z: leftZ[i] }]);
        allSpineVz.push(leftZ[i]);
    }
    for (i = 0; i < rightZ.length; ++i) {
        addRoad("feeder", "h", feederW, [{ x: xmax, z: rightZ[i] }, { x: spineX, z: rightZ[i] }]);
        allSpineVz.push(rightZ[i]);
    }

    // The two avenues span just far enough to gather every feeder they serve.
    var hMinX = minArr(allSpineHx), hMaxX = maxArr(allSpineHx);
    var vMinZ = minArr(allSpineVz), vMaxZ = maxArr(allSpineVz);
    addRoad("spine", "h", mainW, [{ x: hMinX, z: spineZ }, { x: hMaxX, z: spineZ }]);
    addRoad("spine", "v", mainW, [{ x: spineX, z: vMinZ }, { x: spineX, z: vMaxZ }]);

    // Intersections: the main crossing plus every feeder/spine junction.
    var intersections = [{ x: spineX, z: spineZ, roadIds: [] }];
    for (i = 0; i < topX.length; ++i) intersections.push({ x: topX[i], z: spineZ, roadIds: [] });
    for (i = 0; i < botX.length; ++i) intersections.push({ x: botX[i], z: spineZ, roadIds: [] });
    for (i = 0; i < leftZ.length; ++i) intersections.push({ x: spineX, z: leftZ[i], roadIds: [] });
    for (i = 0; i < rightZ.length; ++i) intersections.push({ x: spineX, z: rightZ[i], roadIds: [] });

    // Segment list for fast "is this cell on a road?" tests.
    var segs = [];
    for (i = 0; i < roads.length; ++i) {
        var cl = roads[i].centerline;
        for (var s = 0; s + 1 < cl.length; ++s)
            segs.push([cl[s].x, cl[s].z, cl[s + 1].x, cl[s + 1].z, roads[i].width * 0.5]);
    }

    // ---- parcels: grid the tile, drop cells that a road runs through ------
    var N = 7;
    var cell = tileSize / N;
    var buildable = cell * 0.68; // footprint side, leaves a gap to the street
    var clearance = Math.max(feederW, mainW) * 0.5 + cell * 0.18;

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
            var onRoad = false;
            for (var k = 0; k < segs.length; ++k) {
                var g = segs[k];
                if (distSqToSeg(wx, wz, g[0], g[1], g[2], g[3]) < (g[4] + clearance) * (g[4] + clearance)) {
                    onRoad = true; break;
                }
            }
            if (onRoad) continue;

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

            // Height: taller near the central intersection and on downtown tiles.
            var ddx = (wx - spineX) / (tileSize * 0.6);
            var ddz = (wz - spineZ) / (tileSize * 0.6);
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

    var foliage = generateFoliage(seed, roads, parks, { xmin: xmin, zmin: zmin, xmax: xmax, zmax: zmax });

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
