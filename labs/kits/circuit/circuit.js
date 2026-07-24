// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// DC circuit solver for the electronics lab - pure and deterministic.
//
// Model: every element has two terminals. Wires merge terminals into nets
// (union-find). Each element stamps a Norton companion (conductance between
// its two nets + optional current source) into a nodal G matrix which is
// solved by Gaussian elimination. LEDs are piecewise-linear diodes solved by
// a short fixed-point iteration over their conducting state.
//
// Element types and their models:
//   battery   ideal V source + RINT internal resistance (Norton pair)
//   resistor  value ohms
//   bulb      RBULB ohms, brightness = dissipated power
//   led       off: open; on: I = (V - VF) / RLED, polarity terminal 0 = anode
//   switch    closed: RCLOSED, open: ROPEN
//   ammeter   RSHUNT (reads its own current)
//   voltmeter RVOLT (reads voltage across its terminals)
//
// solve() returns { ok, perElement: {id: {v, i, on, power}}, netCount,
//                   shorted, iterations } - all numbers finite.

var RINT    = 0.5;     // battery internal resistance (ohm)
var RCLOSED = 0.01;    // closed switch / plain contact (ohm)
var ROPEN   = 1e9;     // open switch / non-conducting LED (ohm)
var RSHUNT  = 0.01;    // ammeter shunt (ohm)
var RVOLT   = 1e7;     // voltmeter input impedance (ohm)
var RBULB   = 6.0;     // incandescent bulb filament (ohm)
var RLED    = 15.0;    // LED series resistance when conducting (ohm)
var VF_LED  = 2.0;     // LED forward voltage (volt)
var GLEAK   = 1e-9;    // per-net leak to ground keeps islands solvable
var I_SHORT = 1.5;     // battery current above this counts as a short (A)

// ---- nets via union-find ---------------------------------------------------

function termKey(elId, ti) { return elId + ":" + ti; }

// Returns {netOf: {termKey: netIndex}, count}. Terminals joined by wires
// share a net; unconnected terminals get their own net each.
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

function conductanceOf(el, ledOn) {
    switch (el.type) {
    case "battery":   return 1 / RINT;
    case "resistor":  return 1 / Math.max(0.1, el.value || 470);
    case "bulb":      return 1 / RBULB;
    case "switch":    return el.on ? 1 / RCLOSED : 1 / ROPEN;
    case "ammeter":   return 1 / RSHUNT;
    case "voltmeter": return 1 / RVOLT;
    case "led":       return ledOn ? 1 / RLED : 1 / ROPEN;
    }
    return 1 / ROPEN;
}

// ---- solver ----------------------------------------------------------------

function solve(elements, wires) {
    var nets = buildNets(elements, wires);
    var n = nets.count;
    var result = { ok: true, perElement: {}, netCount: n, shorted: false,
                   iterations: 0 };
    if (n === 0) return result;

    // LED conducting states, iterated to a fixed point. An LED that keeps
    // flip-flopping sits in a branch that cannot carry current (e.g. behind
    // an open switch, where leak dividers fake a forward voltage) - after a
    // few flips it is pinned off, which is the physical answer.
    var ledOn = {}, flips = {};
    for (var i = 0; i < elements.length; ++i)
        if (elements[i].type === "led") ledOn[elements[i].id] = false;

    var volts = null;
    var maxIter = 12;
    for (var iter = 0; iter < maxIter; ++iter) {
        result.iterations = iter + 1;
        var G = [], I = [];
        for (var r = 0; r < n; ++r) {
            var row = [];
            for (var c = 0; c < n; ++c) row.push(0);
            G.push(row); I.push(0);
        }
        // Leak anchors every net so disconnected islands stay solvable.
        for (r = 0; r < n; ++r) G[r][r] += GLEAK;

        for (i = 0; i < elements.length; ++i) {
            var el = elements[i];
            var na = nets.netOf[termKey(el.id, 0)];
            var nb = nets.netOf[termKey(el.id, 1)];
            var g = conductanceOf(el, ledOn[el.id]);
            G[na][na] += g; G[nb][nb] += g;
            G[na][nb] -= g; G[nb][na] -= g;
            if (el.type === "battery") {
                // Norton: source V/RINT flowing into the + terminal (0).
                var isrc = (el.value || 4.5) / RINT;
                I[na] += isrc; I[nb] -= isrc;
            } else if (el.type === "led" && ledOn[el.id]) {
                // Conducting LED companion: I = g*V - VF/RLED, so the
                // constant term injects INTO the anode (same sign rule as
                // the battery's Norton source above).
                var iled = VF_LED / RLED;
                I[na] += iled; I[nb] -= iled;
            }
        }

        volts = solveLinear(G, I);
        if (!volts) { result.ok = false; return result; }

        // Re-evaluate LED states; stable set -> done.
        var changed = false;
        for (i = 0; i < elements.length; ++i) {
            el = elements[i];
            if (el.type !== "led") continue;
            var v = volts[nets.netOf[termKey(el.id, 0)]]
                  - volts[nets.netOf[termKey(el.id, 1)]];
            var want = ledOn[el.id] ? ((v - VF_LED) / RLED > 1e-7)
                                    : (v > VF_LED);
            if (want !== ledOn[el.id]) {
                flips[el.id] = (flips[el.id] || 0) + 1;
                if (flips[el.id] > 3) want = false;
                if (want !== ledOn[el.id]) { ledOn[el.id] = want; changed = true; }
            }
        }
        if (!changed) break;
    }

    for (i = 0; i < elements.length; ++i) {
        el = elements[i];
        var va = volts[nets.netOf[termKey(el.id, 0)]];
        var vb = volts[nets.netOf[termKey(el.id, 1)]];
        v = va - vb;
        var cur;
        if (el.type === "battery")
            cur = ((el.value || 4.5) - v) / RINT;      // discharge current out of +
        else if (el.type === "led")
            cur = ledOn[el.id] ? (v - VF_LED) / RLED : 0;
        else
            cur = v * conductanceOf(el, false);
        if (!isFinite(v)) v = 0;
        if (!isFinite(cur)) cur = 0;
        var entry = { v: v, i: cur, on: false, power: Math.abs(v * cur) };
        if (el.type === "led") entry.on = ledOn[el.id] && cur > 1e-5;
        if (el.type === "bulb") entry.on = entry.power > 0.005;
        if (el.type === "switch") entry.on = !!el.on;
        if (el.type === "battery" && Math.abs(cur) > I_SHORT)
            result.shorted = true;
        result.perElement[el.id] = entry;
    }
    return result;
}
