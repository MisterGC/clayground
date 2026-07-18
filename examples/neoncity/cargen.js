// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Deterministic car routing for the neoncity demo. PURE: turns the citygen
// road graph into drivable right-hand lane routes and seeds a fixed set of
// cars from the tile seed, so the traffic layout is identical on every run.
//
// A "route" is one direction of travel along a road, offset to the right-hand
// lane. Cars drive a route to its end, then pick a connected route at the
// intersection (nextRoute) - or respawn if the route ran off the tile edge.

.pragma library

function u32(x) { return x >>> 0; }
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

// Deterministic 32-bit hash of two integers (reload-stable, shared with the
// junction-decision RNG so every car turns identically on every run).
function hash2(a, b) {
    var h = (u32(a) ^ 0x9e3779b9) >>> 0;
    h = Math.imul(h ^ (u32(b) + 0x85ebca6b), 0x27d4eb2f) >>> 0;
    h ^= h >>> 15;
    return h >>> 0;
}

// Right-hand travel-lane offset magnitude for a road (world units off the
// centerline). It lands the car ON a lane center that lanegen actually paints:
// a spine has two lanes per carriageway half (centers at 0.25h and 0.75h), so
// the outer right lane is 0.75h; a feeder has one lane per half at 0.5h.
function rightMag(road) {
    var h = road.width * 0.5;
    return road.kind === "spine" ? 0.75 * h : 0.5 * h;
}

// Width of one travel lane on a road (world units). A spine half-carriageway
// (h) holds two lanes; a feeder half holds one - so cars can be sized to the
// narrowest lane they may ever drive and still fit with margin.
function laneWidth(road) {
    return road.kind === "spine" ? 0.25 * road.width : 0.5 * road.width;
}

// Build both directional right-lane routes for every straight road segment.
function buildRoutes(cityData, laneY) {
    var y = (laneY === undefined) ? 1.8 : laneY;
    var routes = [];
    var roads = cityData.roads;
    for (var i = 0; i < roads.length; ++i) {
        var r = roads[i];
        var cl = r.centerline;
        // citygen roads are single straight segments; use first/last point.
        var a = cl[0], b = cl[cl.length - 1];
        var dx = b.x - a.x, dz = b.z - a.z;
        var len = Math.sqrt(dx * dx + dz * dz);
        if (len < 1e-3) continue;
        var ux = dx / len, uz = dz / len;
        var mag = rightMag(r);
        var lw = laneWidth(r);

        // Forward (A->B): right = (uz, -ux).
        var rx = uz, rz = -ux;
        routes.push({
            sx: a.x + rx * mag, sz: a.z + rz * mag,
            ex: b.x + rx * mag, ez: b.z + rz * mag,
            dx: ux, dz: uz, len: len, y: y, roadId: r.id, laneW: lw
        });
        // Backward (B->A): right = (-uz, ux).
        routes.push({
            sx: b.x - rx * mag, sz: b.z - rz * mag,
            ex: a.x - rx * mag, ez: a.z - rz * mag,
            dx: -ux, dz: -uz, len: len, y: y, roadId: r.id, laneW: lw
        });
    }
    return routes;
}

// Narrowest travel lane across all routes (used to size the cars once).
function minLaneWidth(routes) {
    var m = 1e30;
    for (var i = 0; i < routes.length; ++i)
        if (routes[i].laneW < m) m = routes[i].laneW;
    return (m === 1e30) ? 2.5 : m;
}

// Seed `count` cars across the routes deterministically from `seed`. Each car
// carries a stable hash (its junction-decision RNG stream), a paint index, and
// the driving state the CarSystem advances (mode 0 = straight, 1 = turning).
function initCars(seed, routes, count, baseSpeed) {
    var rng = rngFrom(u32(seed ^ 0x43415221)); // "CAR!"
    var bs = baseSpeed === undefined ? 32.0 : baseSpeed;
    var cars = [];
    if (routes.length === 0) return cars;
    for (var i = 0; i < count; ++i) {
        var ri = Math.floor(rng() * routes.length);
        cars.push({
            route: ri,
            t: rng() * routes[ri].len,          // arc position along the route
            speed: bs * (0.7 + 0.6 * rng()),    // world units / second
            paint: Math.floor(rng() * 8),       // body palette index
            hash: u32(Math.floor(rng() * 4294967296)),
            mode: 0,                             // 0 = driving, 1 = turning
            turns: 0,                            // junctions crossed (RNG salt)
            plan: null, curve: null, ct: 0,
            yaw: 0, yawInit: false
        });
    }
    return cars;
}

// Pick a route continuing THROUGH the junction at (ex,ez) - the end of route
// `fromIdx`. A candidate is any other-road route whose lane passes near the
// junction. Straight continuations are preferred; otherwise a turn is chosen
// deterministically from `rand` (0..1). Returns the route index, or -1 to
// respawn (nothing connects, e.g. the route ran off the tile edge).
function chooseNext(routes, ex, ez, fromIdx, rand) {
    var from = routes[fromIdx];
    var R = 12.0;                 // junction capture radius (world units)
    var MIN_AHEAD = 12.0;         // road that must remain AHEAD after the merge
    var straight = [], straightDot = [], turns = [];
    for (var i = 0; i < routes.length; ++i) {
        if (i === fromIdx) continue;
        var r = routes[i];
        // U-turn back down the same road: never.
        if (r.roadId === from.roadId && r.dx === -from.dx && r.dz === -from.dz) continue;
        // Where the junction projects onto this route's lane.
        var wx = ex - r.sx, wz = ez - r.sz;
        var proj = wx * r.dx + wz * r.dz;
        if (proj < -R || proj > r.len + R) continue;
        var px = r.sx + r.dx * proj, pz = r.sz + r.dz * proj;
        var d2 = (ex - px) * (ex - px) + (ez - pz) * (ez - pz);
        if (d2 > R * R) continue;
        // The car resumes AT the merge point and drives forward from there, so
        // the route must have real road left ahead - otherwise it would merge
        // right at a road end and immediately re-plan (endless micro-turning).
        var jt = proj < 0 ? 0 : (proj > r.len ? r.len : proj);
        if (r.len - jt < MIN_AHEAD) continue;
        var dot = r.dx * from.dx + r.dz * from.dz; // 1 straight, 0 turn, -1 back
        if (dot > 0.7) { straight.push(i); straightDot.push(dot); }
        else if (dot > -0.3) turns.push(i);
    }
    // Best (straightest) straight option.
    var sIdx = -1, sBest = -2;
    for (i = 0; i < straight.length; ++i)
        if (straightDot[i] > sBest) { sBest = straightDot[i]; sIdx = straight[i]; }

    if (sIdx >= 0 && (turns.length === 0 || rand < 0.7)) return sIdx;
    if (turns.length > 0) {
        var r2 = (rand * 7.0) % 1.0;             // decorrelated pick within turns
        return turns[Math.min(turns.length - 1, Math.floor(r2 * turns.length))];
    }
    return sIdx; // may be -1 -> respawn
}

// Plan a smooth turn curve from the end of route `fromIdx` onto route `toIdx`.
// The quadratic Bezier runs from the exit point of `from`, bends through the
// junction corner (tangent intersection of the two lanes), and lands on the
// point of `to` nearest the junction. joinTexit is the arc position on `to`
// where straight driving resumes; startT is the from-arc position to begin.
var TURN_LEAD = 8.0; // world units the arc reaches back into `from` / ahead on `to`

function planTurn(routes, fromIdx, toIdx) {
    var from = routes[fromIdx], to = routes[toIdx];

    // Where the junction (from's exit) sits along route `to`.
    var jt = (from.ex - to.sx) * to.dx + (from.ez - to.sz) * to.dz;
    if (jt < 0) jt = 0; else if (jt > to.len) jt = to.len;

    // Start the arc a little BEFORE the end of `from` and land it a little AFTER
    // the junction on `to`, so the curve has real length and leaves/enters each
    // lane tangent to it (no degenerate near-zero arc that snaps the heading).
    var startArc = Math.max(0, from.len - TURN_LEAD);
    var joinArc = Math.min(to.len, jt + TURN_LEAD);
    var p0 = { x: from.sx + from.dx * startArc, z: from.sz + from.dz * startArc };
    var p2 = { x: to.sx + to.dx * joinArc, z: to.sz + to.dz * joinArc };

    // Control point: intersection of line(p0, from.dir) and line(p2, to.dir).
    var det = to.dx * from.dz - from.dx * to.dz;
    var ctrl;
    if (Math.abs(det) < 1e-6) {
        ctrl = { x: 0.5 * (p0.x + p2.x), z: 0.5 * (p0.z + p2.z) }; // near-straight
    } else {
        var s = ((p2.x - p0.x) * (-to.dz) - (-to.dx) * (p2.z - p0.z)) / det;
        ctrl = { x: p0.x + s * from.dx, z: p0.z + s * from.dz };
    }

    // Arc length by sampling.
    var len = 0, prev = p0;
    for (var k = 1; k <= 8; ++k) {
        var t = k / 8, u = 1 - t;
        var x = u * u * p0.x + 2 * u * t * ctrl.x + t * t * p2.x;
        var z = u * u * p0.z + 2 * u * t * ctrl.z + t * t * p2.z;
        len += Math.sqrt((x - prev.x) * (x - prev.x) + (z - prev.z) * (z - prev.z));
        prev = { x: x, z: z };
    }
    return { p0: p0, ctrl: ctrl, p2: p2, len: Math.max(0.5, len),
             toIdx: toIdx, joinTexit: joinArc, startT: startArc };
}

// Point on a quadratic Bezier turn curve at parameter t in [0,1].
function bezPoint(curve, t) {
    var u = 1 - t;
    return {
        x: u * u * curve.p0.x + 2 * u * t * curve.ctrl.x + t * t * curve.p2.x,
        z: u * u * curve.p0.z + 2 * u * t * curve.ctrl.z + t * t * curve.p2.z
    };
}

// Tangent (direction of travel) on the turn curve at parameter t.
function bezTangent(curve, t) {
    var u = 1 - t;
    var tx = 2 * u * (curve.ctrl.x - curve.p0.x) + 2 * t * (curve.p2.x - curve.ctrl.x);
    var tz = 2 * u * (curve.ctrl.z - curve.p0.z) + 2 * t * (curve.p2.z - curve.ctrl.z);
    var m = Math.sqrt(tx * tx + tz * tz);
    if (m < 1e-6) return { x: curve.p2.x - curve.p0.x, z: curve.p2.z - curve.p0.z };
    return { x: tx / m, z: tz / m };
}

// Deterministic transmitter placement: 1-3 masts on the tallest structures.
function transmitterSites(cityData) {
    var seed = cityData.seed >>> 0;
    var rng = rngFrom(u32(seed ^ 0x584D4954)); // "XMIT"
    var count = 1 + Math.floor(rng() * 3); // 1..3

    var sites = [];
    for (var i = 0; i < cityData.landmarks.length; ++i) {
        var lm = cityData.landmarks[i];
        sites.push({ x: lm.x, z: lm.z, top: lm.height });
    }
    // Tallest buildings as fallback / fill.
    var bs = cityData.buildings.slice();
    bs.sort(function (a, b) { return b.height - a.height; });
    for (i = 0; i < bs.length && sites.length < count + 2; ++i)
        sites.push({ x: bs[i].x, z: bs[i].z, top: bs[i].height });

    return sites.slice(0, Math.max(0, Math.min(count, sites.length)));
}
