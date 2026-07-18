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

// Right-hand lane offset magnitude for a road (world units off centerline).
function rightMag(road) {
    var h = road.width * 0.5;
    return road.kind === "spine" ? 0.6 * h : 0.5 * h;
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

        // Forward (A->B): right = (uz, -ux).
        var rx = uz, rz = -ux;
        routes.push({
            sx: a.x + rx * mag, sz: a.z + rz * mag,
            ex: b.x + rx * mag, ez: b.z + rz * mag,
            dx: ux, dz: uz, len: len, y: y, roadId: r.id
        });
        // Backward (B->A): right = (-uz, ux).
        routes.push({
            sx: b.x - rx * mag, sz: b.z - rz * mag,
            ex: a.x - rx * mag, ez: a.z - rz * mag,
            dx: -ux, dz: -uz, len: len, y: y, roadId: r.id
        });
    }
    return routes;
}

// Seed `count` cars across the routes deterministically from `seed`.
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
            speed: bs * (0.7 + 0.6 * rng())     // world units / second
        });
    }
    return cars;
}

// Find a route continuing from (ex,ez), the end of route `fromIdx`. Prefers the
// straightest onward direction; returns -1 when nothing connects (respawn).
function nextRoute(routes, ex, ez, fromIdx) {
    var from = routes[fromIdx];
    var R = 14.0;               // intersection capture radius (world units)
    var best = -1, bestDot = -2.0;
    for (var i = 0; i < routes.length; ++i) {
        if (i === fromIdx) continue;
        var r = routes[i];
        var d2 = (r.sx - ex) * (r.sx - ex) + (r.sz - ez) * (r.sz - ez);
        if (d2 > R * R) continue;
        // Skip an immediate U-turn back down the same road.
        if (r.roadId === from.roadId && (r.dx === -from.dx && r.dz === -from.dz)) continue;
        var dot = r.dx * from.dx + r.dz * from.dz; // 1 straight, 0 turn, -1 back
        if (dot > bestDot) { bestDot = dot; best = i; }
    }
    return best;
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
