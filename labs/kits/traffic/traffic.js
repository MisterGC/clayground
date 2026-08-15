// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The traffic sim: cars walking the lane graph derived by lanemodel.js.
// PURE and DETERMINISTIC - every random draw comes from the rng passed in
// (the lab hands it SimClock.random), and step() is called with a FIXED dt, so
// a run is reproducible from (seed, graph, parameter set) alone.
//
// A car is deliberately almost nothing: which lane or turn it is on, how far
// along, and how fast. Three rules move it:
//
//   FOLLOW   keep a speed-dependent gap to whatever is ahead, looking one
//            element past the end of the current one so a queue backs up
//            through a junction instead of piling into it.
//   YIELD    a turn is CLAIMED while a car is in it. A car may only enter when
//            no conflicting turn is claimed and its exit lane has room. That
//            single rule is the whole right-of-way model, and it is what makes
//            a crossing look like a crossing rather than a collision.
//   LEAVE    a lane with no exits is a dead end: the car fades out over the
//            last stretch of it and is gone.
//
// Cars never appear from off-stage: they spawn anywhere there is room on any
// lane, which is what makes the network - not an entry point - the thing under
// study. Note that `demand` is a REQUEST: a spawn needs a clear gap, so past a
// certain point asking for more traffic simply does not produce more, and the
// gap between targetCount() and the live count is the network's capacity
// showing itself.
//
// HOUSES - the one exception, and it is opt-in (`par.houses`, a list of node
// ids). With houses declared, journeys stop being anonymous: a car is placed
// only on a lane LEAVING a house, and a car reaching the far end of a lane
// ARRIVING at a house is absorbed there and counted as an arrival. That is the
// whole of it. It is deliberately NOT a routing model: a driver still picks
// uniformly among its legal exits, so a car leaving house A does not aim for
// house B - it wanders until it happens to reach a house. What houses buy is a
// FAIR COMPARISON: pin the four places traffic enters and leaves, pin the fleet
// size with `par.target`, and two networks joining the same houses differ only
// in their shape. Without that, `demand` scales with lane length and a bigger
// network silently gets more cars, so a topology comparison measures lane
// length as much as topology. The kit's model card states the limit; a study
// that uses houses has to restate it (see labs/street-network-101/studies/).

// element kinds, used as the first half of a car's address
var LANE = 0
var CONN = 1

var TAU = 12.0            // seconds; smoothing window behind the per-road rate
var FADE_DIST = 14.0      // how far before a dead end a car starts to dissolve
var FADE_IN = 0.7         // seconds of fade-in after spawning
var LOOK_AHEAD = 45.0     // no point braking for something further off than this
var STOP_MARGIN = 0.6     // how far short of the stop line a held car waits

function defaultParams() {
    return {
        vmax: 15.0,       // free-flow speed, world units per second
        accel: 7.0,
        brake: 18.0,
        headway: 0.85,    // seconds of gap a car wants to its leader
        minGap: 2.4,      // standstill gap, world units
        carLen: 4.4,
        carWid: 2.0,
        demand: 0.5,      // cars asked for per 38 units of lane; the
                          // network may refuse to hold that many
        spawnRate: 9.0,   // spawn attempts per second while below target
        maxCars: 140,

        // The fixed origin/sink model, off by default so the open model above
        // is what a lab gets unless it asks otherwise.
        houses: null,     // [nodeId] - journeys start and end here
        target: null      // explicit fleet size, overriding the lane-length rule
    }
}

function createState() {
    return {
        cars: [], nextId: 1,
        spawnAccum: 0,
        claims: {},        // connector index -> car id currently inside it
        crossings: {},     // road id -> monotone count of lanes completed
        rate: {},          // road id -> smoothed cars per minute
        arrived: 0,        // journeys that ended AT A HOUSE
        arrivedAt: {},     // house node id -> arrivals there
        arrivalRate: 0,    // smoothed arrivals per minute, all houses together
        spawned: 0, gone: 0,
        blockedTime: 0,    // car-seconds spent held at a stop line
        movingTime: 0,
        t: 0
    }
}

// ---- the step --------------------------------------------------------------

function step(net, st, dt, rng, par) {
    if (!net || !net.lanes.length) return st
    st.t += dt

    _decayRates(net, st, dt)
    _spawn(net, st, dt, rng, par)

    // Occupancy index, rebuilt each step: element key -> car indices sorted by
    // s. Cheap at these counts, and it keeps the follow rule a lookup rather
    // than an O(n^2) scan.
    var occ = _occupancy(net, st)

    // --- pass A: who may enter a junction ---------------------------------
    // Resolved BEFORE anyone moves, and ordered by how long each car has been
    // waiting, so a busy approach cannot starve a quiet one. Ties break on id,
    // which keeps the whole thing reproducible.
    //
    // A grant is a BOOKING the car keeps until it is through, not a per-step
    // verdict. That distinction is load-bearing: re-polling every step
    // livelocks, because `wait` resets the instant a car starts rolling, so
    // the car that was just waved on immediately loses priority to the ones
    // still standing, brakes, re-queues, and the junction never clears.

    // Revalidate first, and this pass is the one that keeps junctions alive.
    // A booking is only good while its holder is still the car at the stop
    // line, and being the lead car at GRANT time is not enough: a car can
    // spawn in front afterwards and the one behind then holds a turn it can
    // never reach, while the car ahead waits on a conflicting turn that the
    // booking blocks. Neither ever moves. Re-checking every step makes the
    // invariant self-healing rather than merely established once - which is
    // what a 625-run sweep across five network shapes needed to stay clean.
    for (var v = 0; v < st.cars.length; ++v) {
        var bc = st.cars[v]
        if (bc.booked === -1 || bc.kind !== LANE) continue
        if (_isLeadCar(st, occ, bc)) continue
        if (st.claims[bc.booked] === bc.id) delete st.claims[bc.booked]
        bc.booked = -1
    }

    var wanting = []
    for (var i = 0; i < st.cars.length; ++i) {
        var c = st.cars[i]
        if (c.kind !== LANE || c.next === null) continue
        if (c.booked === c.next.idx) continue            // already holds one
        var remain = net.lanes[c.idx].length - c.s
        // book early enough that a free-flowing car never has to brake for a
        // junction it was always going to be waved through
        if (remain > Math.max(6.0, c.v * 1.3)) continue
        // Only the car at the head of the queue may claim the junction. This
        // is the cheap guard - it stops the bad state being created. The pass
        // above is the one that GUARANTEES it, by healing the state if it
        // arises anyway; without this line the sim still behaves, it just
        // churns bookings it has to revoke a step later.
        if (!_isLeadCar(st, occ, c)) continue
        wanting.push(i)
    }
    wanting.sort(function (p, q) {
        var d = st.cars[q].wait - st.cars[p].wait
        return d !== 0 ? d : st.cars[p].id - st.cars[q].id
    })
    for (var w = 0; w < wanting.length; ++w) {
        var car = st.cars[wanting[w]]
        if (!_mayClaim(net, st, occ, car, par)) continue
        car.booked = car.next.idx
        st.claims[car.booked] = car.id
    }

    // --- pass B: move ------------------------------------------------------
    for (var m = 0; m < st.cars.length; ++m) _advance(net, st, occ, st.cars[m], dt, rng, par)

    // --- pass C: retire ----------------------------------------------------
    var kept = []
    for (var k = 0; k < st.cars.length; ++k) {
        var kc = st.cars[k]
        if (kc.dead) {
            // a car may die holding either an occupancy or a booking it never
            // got to use; leaving one behind would wedge that junction shut
            if (st.claims[kc.claimed] === kc.id) delete st.claims[kc.claimed]
            if (st.claims[kc.booked] === kc.id) delete st.claims[kc.booked]
            // Two different endings, kept apart on purpose: a journey that
            // reached a HOUSE arrived somewhere, one that ran out of road did
            // not. A study measuring throughput wants only the first.
            if (kc.arrived) st.arrived++
            else st.gone++
        } else kept.push(kc)
    }
    st.cars = kept
    return st
}

// Is this car the frontmost on its element? occ lists are sorted by s, so the
// leader is simply the last entry.
function _isLeadCar(st, occ, car) {
    var list = occ[car.kind * 1000000 + car.idx]
    if (!list || !list.length) return true
    return st.cars[list[list.length - 1]].id === car.id
}

function _occupancy(net, st) {
    var occ = {}
    for (var i = 0; i < st.cars.length; ++i) {
        var c = st.cars[i]
        var key = c.kind * 1000000 + c.idx
        if (!occ[key]) occ[key] = []
        occ[key].push(i)
    }
    for (var key2 in occ) {
        occ[key2].sort(function (a, b) { return st.cars[a].s - st.cars[b].s })
    }
    return occ
}

// May this car take its chosen turn? Three questions: is the turn itself free,
// is every conflicting turn free, and is there anywhere to go at the far end.
// The last one is what stops a junction from filling up with cars that cannot
// leave it - the classic way a naive sim gridlocks.
function _mayClaim(net, st, occ, car, par) {
    var ci = car.next.idx
    if (car.next.kind !== CONN) return true
    var held = st.claims[ci]
    if (held !== undefined && held !== car.id) return false
    var conn = net.connectors[ci]
    for (var i = 0; i < conn.conflicts.length; ++i) {
        var h = st.claims[conn.conflicts[i]]
        if (h !== undefined && h !== car.id) return false
    }
    // room on the far side: the first car on the exit lane must be clear of
    // the mouth, or this car would stop inside the box
    var exitKey = LANE * 1000000 + conn.toLane
    var list = occ[exitKey]
    if (list && list.length) {
        var first = st.cars[list[0]]
        if (first.s - par.carLen < par.carLen + par.minGap) return false
    }
    return true
}

function _isHouse(par, nodeId) {
    var houses = par.houses
    if (!houses || !houses.length) return false
    for (var i = 0; i < houses.length; ++i) if (houses[i] === nodeId) return true
    return false
}

// Does a journey end at the far end of this lane? A dead end always ends one -
// there is nowhere else to go. A lane ARRIVING at a house ends one too, and
// that is the whole fixed-sink model: no destination is chosen, the car simply
// stops being a car when it gets to a house.
//
// The two overlap, and the overlap is the COMMON case rather than an edge one:
// a house on a spur sits at a degree-1 node, so its arrival lane is terminal
// anyway. Which is why "did it arrive?" is asked of the NODE and never of
// `lane.terminal` - reading it off the lane counts every house on a spur as a
// journey that ran out of road, and a study of arrivals then measures nothing.
function _absorbs(net, par, laneIdx) {
    var L = net.lanes[laneIdx]
    return L.terminal || _isHouse(par, L.toNode)
}

function _advance(net, st, occ, c, dt, rng, par) {
    var elemLen = c.kind === LANE ? net.lanes[c.idx].length
                                  : net.connectors[c.idx].length
    var remain = elemLen - c.s

    // --- how much room is there ahead? ---
    var gap = _gapAhead(net, st, occ, c, par)

    // a stop line the car has no booking through is an obstacle like any
    // other, which is what makes it queue instead of teleport
    if (c.kind === LANE && c.next !== null && c.next.kind === CONN
        && c.booked !== c.next.idx)
        gap = Math.min(gap, Math.max(0, remain - STOP_MARGIN))

    // --- speed ---
    var want = par.vmax * (c.speedFactor === undefined ? 1 : c.speedFactor)
    // a turn is taken slower than a straight, as it is in life
    if (c.kind === CONN && net.connectors[c.idx].turn !== "straight") want *= 0.55
    var need = par.minGap + c.v * par.headway
    if (gap < need) {
        // brake proportionally to how badly the gap is missed, so a car eases
        // into a queue instead of slamming between full speed and stopped
        var deficit = Math.min(1, (need - gap) / Math.max(1e-3, need))
        c.v = Math.max(0, c.v - par.brake * deficit * dt)
    } else if (c.v < want) {
        c.v = Math.min(want, c.v + par.accel * dt)
    } else {
        c.v = Math.max(want, c.v - par.brake * 0.25 * dt)
    }
    if (c.v * dt > gap) c.v = Math.max(0, gap / Math.max(dt, 1e-6))

    if (c.v < 0.15) { c.wait += dt; st.blockedTime += dt }
    else { c.wait = 0; st.movingTime += dt }

    c.s += c.v * dt
    c.dist += c.v * dt

    // --- element transitions ---
    while (c.s >= elemLen) {
        if (c.kind === LANE) {
            var lane = net.lanes[c.idx]
            if (_absorbs(net, par, c.idx)) {
                // the road ran out, or the car got home: either way the
                // journey ends here
                _countCrossing(st, lane.roadId)
                if (_isHouse(par, lane.toNode)) {
                    c.arrived = true
                    _countArrival(st, lane.toNode)
                }
                c.dead = true
                return
            }
            if (c.next === null || c.booked !== c.next.idx) {
                // held at the line - the gate above normally stops a car well
                // short of here, so this is a guard, not the usual path
                c.s = elemLen - 1e-4
                c.v = 0
                return
            }
            _countCrossing(st, lane.roadId)
            c.s -= elemLen
            c.kind = CONN; c.idx = c.next.idx
            c.claimed = c.idx      // the booking becomes an occupancy
            c.booked = -1
            c.next = { kind: LANE, idx: net.connectors[c.idx].toLane }
            elemLen = net.connectors[c.idx].length
        } else {
            var conn = net.connectors[c.idx]
            if (st.claims[c.idx] === c.id) delete st.claims[c.idx]
            c.claimed = -1
            c.s -= elemLen
            c.kind = LANE; c.idx = conn.toLane
            c.next = _pickExit(net, c.idx, rng)
            elemLen = net.lanes[c.idx].length
        }
        if (elemLen < 1e-4) { c.dead = true; return }
    }

    // --- how solid is it? ---
    // Fading is a pure function of where the car is, not a countdown: it
    // dissolves over the last stretch of a dead-end lane and firms up over the
    // first moments of its life.
    var alpha = 1
    if (c.kind === LANE && _absorbs(net, par, c.idx)) {
        var left = net.lanes[c.idx].length - c.s
        alpha = Math.max(0, Math.min(1, left / FADE_DIST))
    }
    var age = st.t - c.born
    if (age < FADE_IN) alpha = Math.min(alpha, age / FADE_IN)
    c.alpha = alpha
}

// Distance to whatever is in front: the leader on this element, or - once this
// element runs out - the first car on the one the driver has already chosen.
function _gapAhead(net, st, occ, c, par) {
    var key = c.kind * 1000000 + c.idx
    var list = occ[key]
    if (list) {
        for (var i = 0; i < list.length; ++i) {
            var o = st.cars[list[i]]
            if (o.id === c.id || o.s <= c.s) continue
            return Math.max(0, o.s - par.carLen - c.s)
        }
    }
    var elemLen = c.kind === LANE ? net.lanes[c.idx].length
                                  : net.connectors[c.idx].length
    var remain = elemLen - c.s
    if (remain > LOOK_AHEAD || c.next === null) return LOOK_AHEAD
    var nkey = c.next.kind * 1000000 + c.next.idx
    var nlist = occ[nkey]
    if (nlist && nlist.length) {
        var first = st.cars[nlist[0]]
        return Math.max(0, remain + first.s - par.carLen)
    }
    return LOOK_AHEAD
}

// The turn a driver takes. Uniform over the legal exits - no origin/destination
// model, because the lesson here is what the NETWORK does, not what a
// commuter wants.
function _pickExit(net, laneIdx, rng) {
    var ex = net.lanes[laneIdx].exits
    if (!ex.length) return null
    var pick = ex[Math.min(ex.length - 1, Math.floor(rng() * ex.length))]
    return { kind: CONN, idx: pick }
}

function _countCrossing(st, roadId) {
    st.crossings[roadId] = (st.crossings[roadId] || 0) + 1
    st.rate[roadId] = (st.rate[roadId] || 0) + 60 / TAU
}

// Same exponential smoother as the per-road rate, for the same reason: an
// arrival is an instant, and "cars per minute" only means something over a
// window. TAU is that window, so `arrivalRate` reads like a needle rather than
// a Geiger counter - which is what makes its stddev a statement about the
// NETWORK and not about the counting.
function _countArrival(st, nodeId) {
    st.arrivedAt[nodeId] = (st.arrivedAt[nodeId] || 0) + 1
    st.arrivalRate += 60 / TAU
}

function _decayRates(net, st, dt) {
    var f = Math.exp(-dt / TAU)
    for (var i = 0; i < net.roads.length; ++i) {
        var id = net.roads[i].id
        if (st.rate[id]) st.rate[id] *= f
    }
    if (st.arrivalRate) st.arrivalRate *= f
}

// ---- spawning --------------------------------------------------------------

function targetCount(net, par) {
    // An explicit target is what makes two networks comparable: the
    // lane-length rule below hands a bigger network more cars, so a topology
    // comparison run on it would measure how much road was drawn.
    if (par.target !== null && par.target !== undefined)
        return Math.max(0, Math.min(par.maxCars, Math.round(par.target)))
    var byLength = Math.round(par.demand * net.stats.laneLength / 38)
    return Math.max(0, Math.min(par.maxCars, byLength))
}

// The lanes a car may be placed on: those leaving a house, or every lane when
// no houses are declared. An empty result with houses declared is meaningful
// and is NOT silently widened to "anywhere" - four houses none of which sits on
// a road is a plan with nowhere for traffic to come from, and it should show as
// an empty road rather than as the open model in disguise.
function originLanes(net, par) {
    var houses = par.houses
    if (!houses || !houses.length) return null
    var out = []
    for (var i = 0; i < net.lanes.length; ++i)
        for (var h = 0; h < houses.length; ++h)
            if (net.lanes[i].fromNode === houses[h]) { out.push(i); break }
    return out
}

function _spawn(net, st, dt, rng, par) {
    var target = targetCount(net, par)
    st.spawnAccum += dt * par.spawnRate
    var budget = Math.floor(st.spawnAccum)
    st.spawnAccum -= budget
    for (var i = 0; i < budget; ++i) {
        if (st.cars.length >= target) { st.spawnAccum = 0; return }
        _trySpawn(net, st, rng, par)
    }
}

function _trySpawn(net, st, rng, par) {
    // One rng draw either way, so declaring houses does not shift the stream
    // relative to the open model beyond the choice it is actually making.
    var pool = originLanes(net, par)
    var idx
    if (pool === null)
        idx = Math.min(net.lanes.length - 1, Math.floor(rng() * net.lanes.length))
    else if (!pool.length) return false
    else idx = pool[Math.min(pool.length - 1, Math.floor(rng() * pool.length))]
    var lane = net.lanes[idx]
    var need = par.carLen * 2 + par.minGap
    if (lane.length < need) return false
    // never drop a car into the fading stretch of a dead end - it would
    // materialise already half transparent
    var usable = _absorbs(net, par, idx) ? lane.length - FADE_DIST : lane.length
    if (usable < need) return false
    var s = par.carLen + rng() * Math.max(0.01, usable - par.carLen * 2)

    for (var i = 0; i < st.cars.length; ++i) {
        var o = st.cars[i]
        if (o.kind !== LANE || o.idx !== idx) continue
        if (Math.abs(o.s - s) < par.carLen + par.minGap * 2) return false
    }
    // speed spread: identical cars make a queue look like a train
    var factor = 0.82 + rng() * 0.36
    st.cars.push({
        id: st.nextId++, kind: LANE, idx: idx, s: s,
        v: par.vmax * factor * 0.55,
        speedFactor: factor,
        next: _pickExit(net, idx, rng),
        alpha: 0, born: st.t, wait: 0, dist: 0,
        claimed: -1, booked: -1, dead: false, arrived: false,
        tone: Math.floor(rng() * 6)
    })
    st.spawned++
    return true
}

// ---- editing while it runs -------------------------------------------------

// A graph edit rebuilds the lane model from scratch, so every car's address
// becomes meaningless. Rather than clearing the road (which would make editing
// feel destructive), each car is re-placed on the lane that best matches where
// it actually is and which way it is actually pointing. Cars whose lane is
// gone - the road under them was deleted - are dropped.
function rehome(net, oldNet, st) {
    var kept = []
    for (var i = 0; i < st.cars.length; ++i) {
        var c = st.cars[i]
        var pose = _poseOf(oldNet, c)
        if (!pose) continue
        var best = -1, bestD = 9.0, bestS = 0
        for (var l = 0; l < net.lanes.length; ++l) {
            var L = net.lanes[l]
            if (L.length < 1e-3) continue
            // heading must agree, or a car would be flipped into oncoming
            // traffic by a lane that merely happens to be close
            var fx = Math.sin(pose.yaw), fz = Math.cos(pose.yaw)
            if (fx * L.ux + fz * L.uz < 0.7) continue
            var dx = pose.x - L.x0, dz = pose.z - L.z0
            var t = (dx * L.ux + dz * L.uz)
            if (t < 0 || t > L.length) continue
            var px = L.x0 + L.ux * t, pz = L.z0 + L.uz * t
            var d = Math.hypot(pose.x - px, pose.z - pz)
            if (d < bestD) { bestD = d; best = l; bestS = t }
        }
        if (best === -1) continue
        c.kind = LANE; c.idx = best; c.s = bestS
        c.claimed = -1; c.booked = -1
        c.next = null      // re-chosen on the next step
        kept.push(c)
    }
    st.cars = kept
    st.claims = {}
    // every car needs a fresh choice now that the exits may be different
    for (var k = 0; k < st.cars.length; ++k)
        if (st.cars[k].next === null)
            st.cars[k].next = _firstExit(net, st.cars[k].idx)
    return st
}

function _firstExit(net, laneIdx) {
    var ex = net.lanes[laneIdx].exits
    return ex.length ? { kind: CONN, idx: ex[0] } : null
}

function _poseOf(net, c) {
    if (!net) return null
    if (c.kind === LANE) {
        if (c.idx >= net.lanes.length) return null
        var L = net.lanes[c.idx]
        var t = L.length > 1e-6 ? Math.max(0, Math.min(1, c.s / L.length)) : 0
        return { x: L.x0 + (L.x1 - L.x0) * t, z: L.z0 + (L.z1 - L.z0) * t,
                 yaw: Math.atan2(L.ux, L.uz) }
    }
    if (c.idx >= net.connectors.length) return null
    var C = net.connectors[c.idx]
    var n = C.pts.length / 2
    var i = Math.max(1, Math.min(n - 1, Math.round((c.s / C.length) * (n - 1))))
    return { x: C.pts[i * 2], z: C.pts[i * 2 + 1],
             yaw: Math.atan2(C.pts[i * 2] - C.pts[i * 2 - 2],
                             C.pts[i * 2 + 1] - C.pts[i * 2 - 1]) }
}

// ---- readouts --------------------------------------------------------------

function meanSpeed(st) {
    if (!st.cars.length) return 0
    var sum = 0
    for (var i = 0; i < st.cars.length; ++i) sum += st.cars[i].v
    return sum / st.cars.length
}

function stoppedShare(st) {
    if (!st.cars.length) return 0
    var n = 0
    for (var i = 0; i < st.cars.length; ++i) if (st.cars[i].v < 0.15) ++n
    return n / st.cars.length
}

function roadRate(st, roadId) { return st.rate[roadId] || 0 }

// Smoothed arrivals per minute across all houses - the throughput of a plan
// whose journeys have somewhere to end. Zero, always, without houses.
function arrivalRate(st) { return st.arrivalRate || 0 }

function summary(net, st, par) {
    return {
        cars: st.cars.length,
        target: targetCount(net, par),
        spawned: st.spawned,
        goneAtDeadEnds: st.gone,
        arrived: st.arrived,
        arrivedAt: st.arrivedAt,
        arrivalRate: arrivalRate(st),
        meanSpeed: meanSpeed(st),
        stoppedShare: stoppedShare(st),
        simTime: st.t
    }
}
