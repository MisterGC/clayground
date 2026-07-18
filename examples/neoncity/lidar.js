// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Pure, deterministic simulation of a spinning roof lidar for the neoncity
// demo. NO QML types, NO Math.random: given the same scanner config, the same
// obstacle set and the same car pose, it produces the same point cloud - so the
// inspector view is reproducible for a given seed + car + time (modulo motion).
//
// HOW IT WORKS
// ------------
// A scanner has C elevation channels (approx -15 deg .. +10 deg) and A azimuth
// steps per revolution. Each frame it advances only a few azimuth COLUMNS (a
// "slice"), casting C rays per column, so a full revolution takes ~1.5 s like a
// real device. The last full revolution's hits live in a ring buffer indexed by
// (channel, azimuth); a fresh column overwrites the stale one at that azimuth.
//
// Rays are cast in the CAR-LOCAL frame (azimuth measured from the car's heading)
// and every hit is stored in car-local coordinates, so the cloud is stable
// relative to the car and simply rotates with it - exactly what the PiP wants.
//
// Obstacles are axis-aligned boxes (buildings, tree trunks + canopies, lamp
// posts, landmarks) plus oriented boxes (other cars) plus the ground plane. A
// uniform XZ spatial grid over the static boxes means each ray only slab-tests
// the handful of boxes in the cells it crosses, not the whole city.

.pragma library

var GROUND_KIND = 0, BUILDING_KIND = 1, TREE_KIND = 2, LAMP_KIND = 3, CAR_KIND = 4;
var HEIGHT_MAX = 60.0;   // color ramp saturates here (world units of height)

// ---- obstacle boxes from a tile's pure city data --------------------------
// Emits axis-aligned boxes (min/max corners) for everything the lidar can hit
// on one tile, tagged with a kind used only for the color ramp fallback. Cars
// are handled separately (they move every frame).
function tileBoxes(data, out) {
    var i, b;
    for (i = 0; i < data.buildings.length; ++i) {
        b = data.buildings[i];
        _pushBox(out, b.x, 0, b.z, b.w * 0.5, b.height, b.d * 0.5, BUILDING_KIND);
    }
    for (i = 0; i < data.landmarks.length; ++i) {
        var lm = data.landmarks[i];
        _pushBox(out, lm.x, 0, lm.z, lm.footprint * 0.5, lm.height, lm.footprint * 0.5, BUILDING_KIND);
    }
    for (i = 0; i < data.trees.length; ++i) {
        var t = data.trees[i];
        // trunk
        _pushBox(out, t.x, 0, t.z, t.trunkR, t.trunkH, t.trunkR, TREE_KIND);
        // canopy (cone approximated by its bounding box)
        _pushBoxYRange(out, t.x, t.z, t.trunkH, t.trunkH + t.canopyH, t.canopyR, TREE_KIND);
    }
    for (i = 0; i < data.lamps.length; ++i) {
        var lp = data.lamps[i];
        _pushBox(out, lp.x, 0, lp.z, 0.35, lp.h, 0.35, LAMP_KIND);       // pole
        _pushBoxYRange(out, lp.x, lp.z, lp.h - 0.6, lp.h + 0.6, 0.6, LAMP_KIND); // head
    }
    return out;
}

// center (cx,cz), base at y=0, given half-width hx / height H / half-depth hz.
function _pushBox(out, cx, cy, cz, hx, H, hz, kind) {
    out.push({ minx: cx - hx, miny: 0, minz: cz - hz,
               maxx: cx + hx, maxy: H, maxz: cz + hz, kind: kind });
}
function _pushBoxYRange(out, cx, cz, y0, y1, hxz, kind) {
    out.push({ minx: cx - hxz, miny: y0, minz: cz - hxz,
               maxx: cx + hxz, maxy: y1, maxz: cz + hxz, kind: kind });
}

// ---- static scene: near boxes bucketed into a uniform XZ grid -------------
// Keeps only boxes within `range` (+margin) of (cx,cz) and indexes them by XZ
// cell so a ray tests just the cells it crosses.
function buildStatic(allBoxes, cx, cz, range) {
    var cell = 12.0;
    var reach = range + 6.0;
    var boxes = [];
    for (var i = 0; i < allBoxes.length; ++i) {
        var b = allBoxes[i];
        // nearest point of the box footprint to the scanner
        var nx = cx < b.minx ? b.minx : (cx > b.maxx ? b.maxx : cx);
        var nz = cz < b.minz ? b.minz : (cz > b.maxz ? b.maxz : cz);
        var dx = nx - cx, dz = nz - cz;
        if (dx * dx + dz * dz <= reach * reach) boxes.push(b);
    }
    var grid = {};
    for (i = 0; i < boxes.length; ++i) {
        var bx = boxes[i];
        var c0 = Math.floor(bx.minx / cell), c1 = Math.floor(bx.maxx / cell);
        var d0 = Math.floor(bx.minz / cell), d1 = Math.floor(bx.maxz / cell);
        for (var gx = c0; gx <= c1; ++gx)
            for (var gz = d0; gz <= d1; ++gz) {
                var key = gx + "," + gz;
                (grid[key] || (grid[key] = [])).push(i);
            }
    }
    return { cell: cell, boxes: boxes, grid: grid,
             stamp: new Int32Array(boxes.length), stampGen: 0 };
}

// ---- scanner state --------------------------------------------------------
// A slot (channel, azimuth) maps to a FIXED LineBatch3D line index, so the
// point cloud is uploaded once and then patched in place each frame (only the
// azimuth columns scanned this frame move). Misses park at HIDDEN, far outside
// the PiP frustum so they cull away. Colors are baked per elevation channel
// (a stable height proxy: down channels hit ground/low -> teal, up channels hit
// high geometry -> gold), which lets the fast no-color patch path do the work.
var HIDDEN_Y = -5000.0;

function createScanner(cfg) {
    var C = cfg.channels, A = cfg.azSteps;
    var elev = new Float32Array(C);
    var degMin = cfg.elevMinDeg, degMax = cfg.elevMaxDeg;
    for (var c = 0; c < C; ++c) {
        var f = C > 1 ? c / (C - 1) : 0;
        elev[c] = (degMin + (degMax - degMin) * f) * Math.PI / 180;
    }
    var N = C * A;

    // Fixed instance table buffers.
    var posBuf = new Float32Array(N * 6);   // p0.xyz, p1.xyz per line (p0 == p1)
    var startBuf = new Uint32Array(N + 1);
    var colBuf = new Uint8Array(N * 4);
    var widBuf = new Float32Array(N);
    for (var s = 0; s < N; ++s) {
        posBuf[s * 6 + 1] = HIDDEN_Y; posBuf[s * 6 + 4] = HIDDEN_Y;
        startBuf[s] = s * 2;
        widBuf[s] = cfg.pointWidth;
        var ch = Math.floor(s / A);
        _channelColor(ch, C, colBuf, s * 4);
    }
    startBuf[N] = N * 2;

    var valid = new Uint8Array(N);
    return {
        channels: C, azSteps: A, range: cfg.range, elev: elev,
        azCursor: 0, revolutions: 0, visible: 0,
        posBuf: posBuf, startBuf: startBuf, colBuf: colBuf, widBuf: widBuf,
        valid: valid, raysThisAdvance: 0
    };
}

// Initial buffers for the one-time LineBatch3D.setBulk (establishes N lines).
function initBuffers(scanner) {
    return { positions: scanner.posBuf.buffer, starts: scanner.startBuf.buffer,
             colors: scanner.colBuf.buffer, widths: scanner.widBuf.buffer };
}

// teal -> cyan -> gold across the elevation channels (low index = down).
function _channelColor(ch, C, out, o) {
    var h = C > 1 ? ch / (C - 1) : 0;
    var r, g, b;
    if (h < 0.5) { var f = h / 0.5; r = 15 + (0 - 15) * f; g = 157 + (217 - 157) * f; b = 154 + (255 - 154) * f; }
    else { var f2 = (h - 0.5) / 0.5; r = 0 + 255 * f2; g = 217; b = 255 + (61 - 255) * f2; }
    out[o] = r; out[o + 1] = g; out[o + 2] = b; out[o + 3] = 255;
}

// ---- ray vs axis-aligned box (returns entry distance or -1) ---------------
function _rayAabb(ox, oy, oz, dx, dy, dz, b, maxT) {
    var tmin = 0, tmax = maxT, inv, t1, t2, tt;
    if (dx > -1e-9 && dx < 1e-9) { if (ox < b.minx || ox > b.maxx) return -1; }
    else { inv = 1 / dx; t1 = (b.minx - ox) * inv; t2 = (b.maxx - ox) * inv;
           if (t1 > t2) { tt = t1; t1 = t2; t2 = tt; }
           if (t1 > tmin) tmin = t1; if (t2 < tmax) tmax = t2; if (tmin > tmax) return -1; }
    if (dy > -1e-9 && dy < 1e-9) { if (oy < b.miny || oy > b.maxy) return -1; }
    else { inv = 1 / dy; t1 = (b.miny - oy) * inv; t2 = (b.maxy - oy) * inv;
           if (t1 > t2) { tt = t1; t1 = t2; t2 = tt; }
           if (t1 > tmin) tmin = t1; if (t2 < tmax) tmax = t2; if (tmin > tmax) return -1; }
    if (dz > -1e-9 && dz < 1e-9) { if (oz < b.minz || oz > b.maxz) return -1; }
    else { inv = 1 / dz; t1 = (b.minz - oz) * inv; t2 = (b.maxz - oz) * inv;
           if (t1 > t2) { tt = t1; t1 = t2; t2 = tt; }
           if (t1 > tmin) tmin = t1; if (t2 < tmax) tmax = t2; if (tmin > tmax) return -1; }
    return tmin;
}

// ray vs oriented (yaw about Y) box centered at (cx,cy,cz), half (hx,hy,hz).
function _rayObox(ox, oy, oz, dx, dy, dz, box, maxT) {
    var px = ox - box.cx, py = oy - box.cy, pz = oz - box.cz;
    var cy = Math.cos(box.yaw), sy = Math.sin(box.yaw);
    var lpx = cy * px - sy * pz, lpz = sy * px + cy * pz;
    var ldx = cy * dx - sy * dz, ldz = sy * dx + cy * dz;
    var b = { minx: -box.hx, miny: -box.hy, minz: -box.hz,
              maxx: box.hx, maxy: box.hy, maxz: box.hz };
    return _rayAabb(lpx, py, lpz, ldx, dy, ldz, b, maxT);
}

// ---- advance the sweep by `azColumns` azimuth columns ---------------------
// Casts channels x azColumns rays; writes hits (car-local) into the ring
// buffer. `carBoxes` is the array from CarSystem.carBoxesInRange (already near).
// Returns the number of full revolutions completed during this advance.
function advance(scanner, scene, carBoxes, ox, oy, oz, yaw, azColumns) {
    var C = scanner.channels, A = scanner.azSteps, range = scanner.range;
    var elev = scanner.elev, posBuf = scanner.posBuf, valid = scanner.valid;
    var cy = Math.cos(yaw), sy = Math.sin(yaw);
    var completedRevs = 0;
    var rays = 0;

    for (var col = 0; col < azColumns; ++col) {
        var azi = scanner.azCursor;
        var a = (azi / A) * Math.PI * 2.0;
        var sa = Math.sin(a), ca = Math.cos(a);

        for (var ch = 0; ch < C; ++ch) {
            var e = elev[ch], ce = Math.cos(e), se = Math.sin(e);
            // car-local direction (forward = +z), then rotate into world by yaw
            var ldx = sa * ce, ldy = se, ldz = ca * ce;
            var wdx = ldx * cy + ldz * sy;
            var wdz = -ldx * sy + ldz * cy;
            var wdy = ldy;

            var bestT = range, hit = false;

            // ground plane y = 0
            if (wdy < -1e-6) {
                var tg = -oy / wdy;
                if (tg > 0 && tg < bestT) { bestT = tg; hit = true; }
            }

            // static boxes via the XZ grid the ray crosses
            var t = _traceStatic(scene, ox, oy, oz, wdx, wdy, wdz, bestT);
            if (t >= 0 && t < bestT) { bestT = t; hit = true; }

            // moving cars (small in-range list -> linear)
            for (var k = 0; k < carBoxes.length; ++k) {
                var tc = _rayObox(ox, oy, oz, wdx, wdy, wdz, carBoxes[k], bestT);
                if (tc >= 0 && tc < bestT) { bestT = tc; hit = true; }
            }

            var slot = ch * A + azi, o = slot * 6;
            if (hit) {
                var wx = ox + wdx * bestT, wy = oy + wdy * bestT, wz = oz + wdz * bestT;
                // world -> car-local (origin at the car ground point, y kept absolute)
                var rx = wx - ox, rz = wz - oz;
                var lx = cy * rx - sy * rz;      // right
                var lz = sy * rx + cy * rz;      // forward
                posBuf[o + 0] = lx; posBuf[o + 1] = wy; posBuf[o + 2] = lz;
                posBuf[o + 3] = lx; posBuf[o + 4] = wy; posBuf[o + 5] = lz;
                if (!valid[slot]) { valid[slot] = 1; scanner.visible++; }
            } else {
                posBuf[o + 1] = HIDDEN_Y; posBuf[o + 4] = HIDDEN_Y;
                if (valid[slot]) { valid[slot] = 0; scanner.visible--; }
            }
            rays++;
        }

        scanner.azCursor = (azi + 1) % A;
        if (scanner.azCursor === 0) { scanner.revolutions++; completedRevs++; }
    }
    scanner.raysThisAdvance = rays;
    return completedRevs;
}

// Trace a ray against the static grid, returning the nearest entry t or -1.
function _traceStatic(scene, ox, oy, oz, dx, dy, dz, maxT) {
    var cell = scene.cell, grid = scene.grid, boxes = scene.boxes, stamp = scene.stamp;
    scene.stampGen++;
    var gen = scene.stampGen;
    var best = -1;

    var hlen = Math.sqrt(dx * dx + dz * dz);
    if (hlen < 1e-6) {
        // near-vertical ray: only its own cell matters
        var key0 = Math.floor(ox / cell) + "," + Math.floor(oz / cell);
        return _testCell(grid[key0], boxes, stamp, gen, ox, oy, oz, dx, dy, dz, maxT, best);
    }

    // 2D DDA (Amanatides-Woo) over the XZ grid, front to back, up to maxT.
    var gx = Math.floor(ox / cell), gz = Math.floor(oz / cell);
    var stepX = dx > 0 ? 1 : -1, stepZ = dz > 0 ? 1 : -1;
    var invx = dx !== 0 ? 1 / dx : 1e30, invz = dz !== 0 ? 1 / dz : 1e30;
    var nbx = (dx > 0 ? (gx + 1) * cell : gx * cell);
    var nbz = (dz > 0 ? (gz + 1) * cell : gz * cell);
    var tMaxX = dx !== 0 ? (nbx - ox) * invx : 1e30;
    var tMaxZ = dz !== 0 ? (nbz - oz) * invz : 1e30;
    var tDeltaX = dx !== 0 ? Math.abs(cell * invx) : 1e30;
    var tDeltaZ = dz !== 0 ? Math.abs(cell * invz) : 1e30;

    // horizontal travel budget: convert the 3D range to horizontal distance
    var hMax = maxT * hlen;
    var travelled = 0;
    var guard = 0;
    while (travelled <= hMax && guard++ < 256) {
        best = _testCell(grid[gx + "," + gz], boxes, stamp, gen, ox, oy, oz, dx, dy, dz, maxT, best);
        if (best >= 0) return best;   // front-to-back: first cell with a hit wins
        if (tMaxX < tMaxZ) { travelled = tMaxX; tMaxX += tDeltaX; gx += stepX; }
        else { travelled = tMaxZ; tMaxZ += tDeltaZ; gz += stepZ; }
    }
    return best;
}

function _testCell(idxs, boxes, stamp, gen, ox, oy, oz, dx, dy, dz, maxT, best) {
    if (idxs === undefined) return best;
    var bestT = best >= 0 ? best : maxT;
    for (var i = 0; i < idxs.length; ++i) {
        var bi = idxs[i];
        if (stamp[bi] === gen) continue;
        stamp[bi] = gen;
        var t = _rayAabb(ox, oy, oz, dx, dy, dz, boxes[bi], bestT);
        if (t >= 0 && t < bestT) { bestT = t; best = t; }
    }
    return best;
}

// Quality presets: [channels, azSteps, range, azPerFrame, pointWidth].
function quality(level) {
    if (level === "low")  return { channels: 16, azSteps: 360, range: 68,
                                   elevMinDeg: -15, elevMaxDeg: 10, azPerFrame: 4, pointWidth: 2.6 };
    if (level === "high") return { channels: 32, azSteps: 720, range: 76,
                                   elevMinDeg: -15, elevMaxDeg: 10, azPerFrame: 8, pointWidth: 2.0 };
    return { channels: 24, azSteps: 540, range: 72,               // "med" (default)
             elevMinDeg: -15, elevMaxDeg: 10, azPerFrame: 6, pointWidth: 2.3 };
}
