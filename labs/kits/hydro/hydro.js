// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Steady-state incompressible flow solver for the hydraulics lab - pure and
// deterministic. This is the water analogy taught beside Ohm's law, and it is
// written as the same solver deliberately: pressure difference plays the part
// of voltage, volume flow the part of current, hydraulic resistance the part
// of ohms. A lab built on this kit reads line for line like electronics-101,
// which is the whole point of teaching the analogy at all.
//
//   pressure difference   dp   kPa
//   volume flow           q    L/s
//   hydraulic resistance  R    kPa*s/L
//
// The units are chosen so power falls out with no conversion factor:
// 1 kPa * 1 L/s = 1 W exactly.
//
// Model: every element has two terminals. Pipes (wires) merge terminals into
// nets (union-find). Each element stamps a Norton companion (conductance
// between its two nets + optional flow source) into a nodal G matrix which is
// solved by Gaussian elimination. Everything here is LINEAR - dp = R * q - so
// unlike the circuit kit's diode there is nothing to iterate: one stamp, one
// solve, `iterations` is always 1 and exists only so the result shape matches.
//
// Element types and their models:
//   pump       ideal pressure source + RINT internal resistance (Norton pair)
//   valve      open: RCLOSED, closed: ROPEN
//   pipe       a narrow pipe / restriction, `value` kPa*s/L
//   wheel      water wheel: fixed RWHEEL load, turning above P_TURN watts
//   flowmeter  RMETER (reads its own flow)
//   gauge      pressure gauge, RGAUGE, wired ACROSS (reads dp)
//   junction   a T-piece: RCLOSED between coincident terminals
//
// TERMINAL 0 OF A PUMP IS THE OUTLET - its high-pressure side, the analogue of
// a cell's + terminal, and marked as such on the part. Terminal 1 is the
// suction side. Every sign in this file follows from that, exactly as the
// circuit kit's signs follow from "terminal 0 is +".
//
// solve() returns { ok, perElement: {id: {q, dp, power, on, speed}}, netCount,
//                   wireFlow: {id: q|null}, pumps: {id: {...}},
//                   shorted, overloaded, iterations } - all numbers finite.
//
// A short and an overload are different faults and are reported separately,
// for the same reason as in the circuit kit. A short is not "a lot of flow":
// it is the external resistance collapsing to the order of the pump's own, so
// the pump churns its head away inside itself and almost no pressure reaches
// the parts. A heavy but honest load (two wheels in parallel, say) moves a lot
// of water with its outlet pressure nearly intact - an overload at worst.

var P0_DEFAULT = 40;    // pump head, kPa (range 10..120)
var RINT    = 2.0;      // pump internal resistance (kPa*s/L)
// Named after the electrical analogue, not the valve: RCLOSED is the
// resistance of a CLOSED CONTACT, which is an OPEN valve. Kept spelled this
// way so the two kits' constant tables line up row for row.
var RCLOSED = 0.02;     // open valve / plain pipe joint (kPa*s/L)
var ROPEN   = 1e9;      // closed valve (kPa*s/L)
var RMETER  = 0.02;     // flowmeter body (kPa*s/L)
var RGAUGE  = 1e7;      // pressure gauge, wired across (kPa*s/L)
var RWHEEL  = 24.0;     // water wheel load (kPa*s/L)
var RPIPE_DEFAULT = 8;  // a narrow pipe, kPa*s/L
var GLEAK   = 1e-9;     // per-net leak to ground keeps islands solvable
var Q_RATED = 3.0;      // what a pump is meant to deliver (L/s) - above this
                        // it is overloaded, which is NOT the same as shorted
var P_TURN  = 0.5;      // watts on the wheel below which it does not turn
var RPM_PER_FLOW = 60;  // wheel speed, rpm per L/s - a display scale, not a
                        // torque model: the wheel is a resistance, not a rotor

// The step ladder a pipe's resistance walks, a preferred-number series in the
// spirit of the resistor's E12: 1-1.5-2-3-5-8 per decade, which is why the
// default 8 is a rung and not a number someone typed.
var pipeSteps = (function () {
    var base = [1, 1.5, 2, 3, 5, 8];
    var out = [];
    for (var dec = 1; dec <= 100; dec *= 10)
        for (var i = 0; i < base.length; ++i) out.push(base[i] * dec);
    out.push(1000);
    return out;
})();

// Nearest rung to `r`, measured in log space so a decade counts the same
// everywhere on the ladder.
function pipeStepOf(r) {
    var best = 0, bd = Infinity;
    for (var i = 0; i < pipeSteps.length; ++i) {
        var d = Math.abs(Math.log(pipeSteps[i]) - Math.log(Math.max(0.1, r)));
        if (d < bd) { bd = d; best = i; }
    }
    return best;
}

// ---- nets via union-find ---------------------------------------------------

function termKey(elId, ti) { return elId + ":" + ti; }

// Returns {netOf: {termKey: netIndex}, count}. Terminals joined by pipes share
// a net; unconnected terminals get their own net each.
function buildNets(elements, wires) {
    var parent = {};
    function find(k) {
        while (parent[k] !== k) { parent[k] = parent[parent[k]]; k = parent[k]; }
        return k;
    }
    for (var i = 0; i < elements.length; ++i) {
        var a = termKey(elements[i].id, 0), b = termKey(elements[i].id, 1);
        parent[a] = a; parent[b] = b;
    }
    for (i = 0; i < wires.length; ++i) {
        var w = wires[i];
        var ka = find(termKey(w.a[0], w.a[1]));
        var kb = find(termKey(w.b[0], w.b[1]));
        if (ka !== kb) parent[ka] = kb;
    }
    var netOf = {}, index = {}, count = 0;
    for (var k in parent) {
        var r = find(k);
        if (!(r in index)) index[r] = count++;
        netOf[k] = index[r];
    }
    return { netOf: netOf, count: count };
}

// ---- linear algebra --------------------------------------------------------

function solveLinear(G, I) {
    var n = I.length;
    var a = [];
    for (var r = 0; r < n; ++r) { a.push(G[r].slice()); a[r].push(I[r]); }
    for (var c = 0; c < n; ++c) {
        var piv = c;
        for (r = c + 1; r < n; ++r)
            if (Math.abs(a[r][c]) > Math.abs(a[piv][c])) piv = r;
        if (Math.abs(a[piv][c]) < 1e-15) return null;
        if (piv !== c) { var t = a[piv]; a[piv] = a[c]; a[c] = t; }
        for (r = 0; r < n; ++r) {
            if (r === c) continue;
            var f = a[r][c] / a[c][c];
            if (f === 0) continue;
            for (var cc = c; cc <= n; ++cc) a[r][cc] -= f * a[c][cc];
        }
    }
    var v = [];
    for (r = 0; r < n; ++r) v.push(a[r][n] / a[r][r]);
    return v;
}

// ---- element stamping ------------------------------------------------------

function resistanceOf(el) {
    switch (el.type) {
    case "pump":      return RINT;
    case "pipe":      return Math.max(0.01, el.value || RPIPE_DEFAULT);
    case "wheel":     return RWHEEL;
    case "valve":     return el.on ? RCLOSED : ROPEN;
    // a junction is a T-piece: a place for pipes to meet, hydraulically just
    // a short between its (coincident) terminals
    case "junction":  return RCLOSED;
    case "flowmeter": return RMETER;
    case "gauge":     return RGAUGE;
    }
    return ROPEN;
}

function conductanceOf(el) { return 1 / resistanceOf(el); }

// ---- solver ----------------------------------------------------------------

function solve(elements, wires) {
    var nets = buildNets(elements, wires);
    var n = nets.count;
    var result = { ok: true, perElement: {}, pumps: {}, netCount: n,
                   shorted: false, overloaded: false, iterations: 0 };
    if (n === 0) { result.wireFlow = {}; return result; }

    var G = [], I = [], i, r, c;
    for (r = 0; r < n; ++r) {
        var row = [];
        for (c = 0; c < n; ++c) row.push(0);
        G.push(row); I.push(0);
    }
    // Leak anchors every net so disconnected islands stay solvable.
    for (r = 0; r < n; ++r) G[r][r] += GLEAK;

    for (i = 0; i < elements.length; ++i) {
        var el = elements[i];
        var na = nets.netOf[termKey(el.id, 0)];
        var nb = nets.netOf[termKey(el.id, 1)];
        var g = conductanceOf(el);
        G[na][na] += g; G[nb][nb] += g;
        G[na][nb] -= g; G[nb][na] -= g;
        if (el.type === "pump") {
            // Norton: source P0/RINT flowing into the outlet (terminal 0).
            var qsrc = (el.value || P0_DEFAULT) / RINT;
            I[na] += qsrc; I[nb] -= qsrc;
        }
    }

    var press = solveLinear(G, I);
    result.iterations = 1;      // linear model: one stamp, one solve, always
    if (!press) { result.ok = false; result.wireFlow = {}; return result; }

    for (i = 0; i < elements.length; ++i) {
        el = elements[i];
        var pa = press[nets.netOf[termKey(el.id, 0)]];
        var pb = press[nets.netOf[termKey(el.id, 1)]];
        var dp = pa - pb;
        var q;
        if (el.type === "pump")
            q = ((el.value || P0_DEFAULT) - dp) / RINT;   // delivery out of the outlet
        else
            q = dp * conductanceOf(el);
        if (!isFinite(dp)) dp = 0;
        if (!isFinite(q)) q = 0;
        var entry = { q: q, dp: dp, on: false, power: Math.abs(dp * q), speed: 0 };
        if (el.type === "valve") entry.on = !!el.on;
        if (el.type === "wheel") {
            entry.on = entry.power > P_TURN;
            entry.speed = Math.abs(q) * RPM_PER_FLOW;
        }
        if (el.type === "pump") {
            var qp = Math.abs(q);
            var pTerm = Math.abs(dp);
            var p0 = el.value || P0_DEFAULT;
            // external resistance the pump actually works against
            var rExt = qp > 1e-3 ? pTerm / qp : Infinity;
            var isShort = rExt < 2 * RINT;
            result.pumps[el.id] = {
                p0: p0, q: q, pTerm: pTerm, rExt: rExt,
                internalDrop: Math.max(0, p0 - pTerm),
                rated: Q_RATED,
                shorted: isShort,
                overloaded: !isShort && qp > Q_RATED
            };
            if (isShort) result.shorted = true;
            else if (qp > Q_RATED) result.overloaded = true;
        }
        result.perElement[el.id] = entry;
    }
    result.wireFlow = attributeWireFlows(elements, wires, result.perElement);
    return result;
}

// ---- per-pipe flow ---------------------------------------------------------
//
// A connecting pipe cannot be oriented by pressure: it IS the net here (ideal,
// zero resistance), so both of its ends sit at exactly the same pressure. What
// is known instead is every element's flow, so the connections follow from
// continuity - KCL by another name, and for water it is the more obvious of
// the two: what goes into a junction comes out of it.
//
// Sign convention out of the solver: dp = p(term0) - p(term1) and, for passive
// elements, q = dp * G - so a positive flow runs internally 0 -> 1 and
// therefore leaves terminal 1. A pump is the other way round: positive is
// delivery, leaving terminal 0 (its outlet).
function terminalOutflow(el, ti, q) {
    var out = (el.type === "pump") ? (ti === 0) : (ti === 1);
    return out ? q : -q;
}

// Peels terminals that have exactly one connection of unknown flow and applies
// continuity there, repeating until nothing new can be resolved. Tree-shaped
// plumbing resolves completely; genuinely ambiguous connections (two pipes in
// parallel between the same pair of terminals - a redundant loop) stay null and
// simply do not animate, which is honest.
function attributeWireFlows(elements, wires, perElement) {
    var byId = {}, i, w, k;
    for (i = 0; i < elements.length; ++i) byId[elements[i].id] = elements[i];

    var atTerm = {};                 // termKey -> [wire index]
    for (i = 0; i < wires.length; ++i) {
        w = wires[i];
        var ka = termKey(w.a[0], w.a[1]), kb = termKey(w.b[0], w.b[1]);
        (atTerm[ka] = atTerm[ka] || []).push(i);
        (atTerm[kb] = atTerm[kb] || []).push(i);
    }

    var flow = [];                   // signed along a -> b, null while unknown
    for (i = 0; i < wires.length; ++i) flow.push(null);

    // flow leaving terminal `key` through connection `idx`
    function leaving(idx, key) {
        var ww = wires[idx];
        if (flow[idx] === null) return 0;
        return termKey(ww.a[0], ww.a[1]) === key ? flow[idx] : -flow[idx];
    }

    var progress = true;
    while (progress) {
        progress = false;
        for (k in atTerm) {
            var list = atTerm[k], unknown = -1, unknownCount = 0;
            for (i = 0; i < list.length; ++i)
                if (flow[list[i]] === null) { unknown = list[i]; ++unknownCount; }
            if (unknownCount !== 1) continue;

            var parts = k.split(":");
            var el = byId[parts[0]] || byId[parseInt(parts[0], 10)];
            var entry = el ? perElement[el.id] : null;
            if (!el || !entry) continue;

            var need = terminalOutflow(el, parseInt(parts[1], 10), entry.q);
            for (i = 0; i < list.length; ++i)
                if (list[i] !== unknown) need -= leaving(list[i], k);

            w = wires[unknown];
            flow[unknown] = termKey(w.a[0], w.a[1]) === k ? need : -need;
            progress = true;
        }
    }

    var out = {};
    for (i = 0; i < wires.length; ++i) out[wires[i].id] = flow[i];
    return out;
}
