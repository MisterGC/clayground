// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// DC circuit solver for the electronics lab - pure and deterministic.
//
// Model: every element has two, three or five terminals. Wires merge terminals
// into nets (union-find). Each element stamps a Norton companion (conductances
// between its nets + optional current sources) into a nodal G matrix which is
// solved by Gaussian elimination. Non-linear parts - diodes, transistors and
// logic gates - are piecewise linear: each carries a discrete STATE, the
// network is solved with those states assumed, the states are re-read off the
// answer, and the loop repeats until nothing flips.
//
// Element types and their models:
//   battery    ideal V source + RINT internal resistance (Norton pair)
//   resistor   value ohms
//   bulb       RBULB ohms, brightness = dissipated power
//   diode      off: open; on: I = (V - VF_DIODE) / RDIODE, terminal 0 = anode
//   led        the same diode with a higher knee, and it glows
//   switch     closed: RCLOSED, open: ROPEN
//   transistor NPN, three terminals: 0 = collector, 1 = base, 2 = emitter
//   gate       logic package, five terminals: 0 = VCC, 1 = A, 2 = B,
//              3 = Y (output), 4 = GND - it swings between its own supply pins
//   ammeter    RSHUNT (reads its own current)
//   voltmeter  RVOLT (reads voltage across its terminals)
//
// solve() returns { ok, perElement: {id: {v, i, on, power}}, netCount,
//                   wireCurrent: {id: amps|null}, batteries: {id: {...}},
//                   shorted, overloaded, iterations } - all numbers finite.
// A transistor's entry carries {mode, ib, ic, vbe, vce} on top of that, and
// its v/i are its collector-emitter pair so the generic readouts still work.
// A gate's entry carries {func, vcc, a, b, y, powered} plus a `term` array of
// what each of its five pads sends into the wires, and its v/i are the output
// pin against the GND pin for the same reason.
//
// A short and an overload are different faults and are reported separately.
// A short is not "a lot of current": it is the external resistance collapsing
// to the order of the cell's own internal resistance, so the cell burns its
// EMF inside itself and almost nothing reaches the parts. A heavy but honest
// load (two bulbs in parallel, say) draws a lot of current with its terminal
// voltage nearly intact - that is an overload at worst, never a short.

var RINT    = 0.5;     // battery internal resistance (ohm)
var RCLOSED = 0.01;    // closed switch / plain contact (ohm)
var ROPEN   = 1e9;     // open switch / non-conducting junction (ohm)
var RSHUNT  = 0.01;    // ammeter shunt (ohm)
var RVOLT   = 1e7;     // voltmeter input impedance (ohm)
var RBULB   = 6.0;     // incandescent bulb filament (ohm)
var RLED    = 15.0;    // LED series resistance when conducting (ohm)
var VF_LED  = 2.0;     // LED forward voltage (volt)
var RDIODE  = 10.0;    // small-signal silicon diode, conducting (ohm)
var VF_DIODE = 0.7;    // silicon forward voltage (volt)
var GLEAK   = 1e-9;    // per-net leak to ground keeps islands solvable
var I_RATED = 1.5;     // what a cell is meant to deliver (A) - above this it
                       // is overloaded, which is NOT the same as shorted

// ---- NPN transistor --------------------------------------------------------
//
// A piecewise-linear NPN, in the three regions a school course names:
//
//   off     base-emitter below its knee: both junctions open
//   active  the base-emitter diode conducts and the collector carries
//           BETA times the base current, whatever the collector volts are
//   sat(urated)  the collector cannot get that much current - it has run
//           into the supply - so it sits at VCE_SAT and behaves like a
//           (very small) resistor instead
//
// The base-emitter branch is the SAME companion the diodes use, which is why
// a transistor's base current comes out of the network rather than out of a
// rule: put 4.7 kOhm in front of the base and the base current is what that
// resistor allows.
var BETA    = 100;     // forward current gain (dimensionless)
var VF_BE   = 0.7;     // base-emitter knee (volt)
var R_BE    = 25.0;    // base-emitter bulk resistance when conducting (ohm)
var VCE_SAT = 0.15;    // collector-emitter volts once saturated (volt)
var R_SAT   = 4.0;     // collector-emitter resistance in saturation (ohm)
var R_EARLY = 1e5;     // collector-emitter leak while active (ohm)

// Cut-off leakage, and it has to be MUCH lower than an open switch's ROPEN.
// A base fed through an open switch would otherwise sit on a 1e9-over-1e9
// divider - half the supply, well past the 0.7 V knee - and a transistor whose
// input is disconnected would switch itself on. Real silicon leaks in the
// tens of nanoamps while a real open contact leaks nothing measurable, so the
// two numbers belong decades apart; here they are two and three decades apart.
var R_BE_OFF = 1e7;    // base-emitter, cut off (ohm)
var R_CE_OFF = 1e8;    // collector-emitter, cut off (ohm)

// ---- logic gate ------------------------------------------------------------
//
// A gate is a PACKAGE, not a discrete part: it has real supply pins and its
// output can only swing between the voltages actually present on them. Wire no
// supply and it does nothing at all. That is the point of modelling it this
// way - a gate that invented its own rail would teach that logic levels come
// from nowhere, and this lab is about where they come from.
//
// Terminals: 0 = VCC, 1 = A, 2 = B, 3 = Y (output), 4 = GND. "not" reads A
// only; B stays a real pad with a real input resistor, the logic simply never
// looks at it.
//
// The output is push-pull onto the PADS, never onto a made-up source: high is
// R_GATE_OUT to whatever the VCC pin sits at, low is R_GATE_OUT to the GND
// pin. So a loaded output sags exactly as far as that resistance and the
// supply allow, and a gate hanging off a drooping cell answers with drooping
// levels rather than with a clean 5 V that is nowhere on the board.
//
// The threshold is ratiometric - half the supply the gate measures for itself
// - rather than a fixed 1.5 V, so one part behaves at 3 V and at 9 V.
//
// The output level is a discrete STATE ("high" / "low" / "hiz") carried
// through the same assume-solve-re-check loop the diodes and transistors use,
// and it starts at "hiz" because a gate that has not been solved yet knows
// nothing to assert. A combinational network settles in a pass or two; a
// feedback loop oscillates and gets pinned by the flip-lock, which is the
// honest answer here - the solver has no notion of time, so sequential logic
// is not something it can be asked for.
var R_GATE_IN  = 1e6;  // each input to the GND pad (ohm) - a floating input
                       // then reads LOW rather than undefined
var R_GATE_Q   = 1e5;  // VCC to GND (ohm): the quiescent current a real chip
                       // draws doing nothing, and it should be measurable
var R_GATE_OUT = 50.0; // push-pull output, to whichever pad it drives (ohm)
var V_GATE_MIN = 0.5;  // below this supply the gate is unpowered (volt)

// The six functions the package comes in. An unknown name is an AND, so a typo
// in a board file gives a working part instead of a dead one.
function gateOutput(func, a, b) {
    switch (func) {
    case "or":   return a || b;
    case "xor":  return a !== b;
    case "nand": return !(a && b);
    case "nor":  return !(a || b);
    case "not":  return !a;              // B is a no-connect: never read
    }
    return a && b;
}

// ---- terminals -------------------------------------------------------------
//
// Two terminals is the rule and everything else the exception, so the
// exceptions are a table rather than a branch in five places. Terminal ORDER
// is part of the part's identity: 0 is an LED's anode, a battery's plus, a
// transistor's collector and a gate's supply pin - reverse a wire and you get
// a different circuit, not an error.
var TERMINALS = { transistor: 3, gate: 5 };

function terminalCount(type) {
    return TERMINALS[type] !== undefined ? TERMINALS[type] : 2;
}

// The diode family, by knee and slope. An LED is a diode you can see.
var DIODES = {
    "led":   { vf: VF_LED,   r: RLED },
    "diode": { vf: VF_DIODE, r: RDIODE }
};
function diodeSpec(type) {
    return DIODES[type] !== undefined ? DIODES[type] : null;
}

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
        var n = terminalCount(elements[i].type);
        for (var t = 0; t < n; ++t) {
            var k = termKey(elements[i].id, t);
            parent[k] = k;
        }
    }
    for (i = 0; i < wires.length; ++i) {
        var w = wires[i];
        var ka = find(termKey(w.a[0], w.a[1]));
        var kb = find(termKey(w.b[0], w.b[1]));
        if (ka !== kb) parent[ka] = kb;
    }
    var netOf = {}, index = {}, count = 0;
    for (var key in parent) {
        var r = find(key);
        if (!(r in index)) index[r] = count++;
        netOf[key] = index[r];
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

// Two-terminal conductance. Transistors and gates never come through here -
// they stamp several branches of their own, see stampNetwork.
function conductanceOf(el, onState) {
    switch (el.type) {
    case "battery":   return 1 / RINT;
    case "resistor":  return 1 / Math.max(0.1, el.value || 470);
    case "bulb":      return 1 / RBULB;
    case "switch":    return el.on ? 1 / RCLOSED : 1 / ROPEN;
    // a junction is a solder dot: a place for wires to meet, electrically
    // just a short between its (coincident) terminals
    case "junction":  return 1 / RCLOSED;
    case "ammeter":   return 1 / RSHUNT;
    case "voltmeter": return 1 / RVOLT;
    case "led":       return onState ? 1 / RLED : 1 / ROPEN;
    case "diode":     return onState ? 1 / RDIODE : 1 / ROPEN;
    case "transistor": return 1 / ROPEN;
    case "gate":      return 1 / ROPEN;
    }
    return 1 / ROPEN;
}

// ---- solver ----------------------------------------------------------------

// One linearized network, given every non-linear part's assumed state.
// Returns { G, I } ready for solveLinear.
function stampNetwork(elements, nets, n, state) {
    var G = [], I = [], r, c;
    for (r = 0; r < n; ++r) {
        var row = [];
        for (c = 0; c < n; ++c) row.push(0);
        G.push(row); I.push(0);
    }
    // Leak anchors every net so disconnected islands stay solvable.
    for (r = 0; r < n; ++r) G[r][r] += GLEAK;

    // a conductance g between two nets
    function pair(na, nb, g) {
        G[na][na] += g; G[nb][nb] += g;
        G[na][nb] -= g; G[nb][na] -= g;
    }
    // a current source of `amps` flowing INTO na and out of nb
    function inject(na, nb, amps) { I[na] += amps; I[nb] -= amps; }

    for (var i = 0; i < elements.length; ++i) {
        var el = elements[i];
        var t0 = nets.netOf[termKey(el.id, 0)];
        var t1 = nets.netOf[termKey(el.id, 1)];

        if (el.type === "transistor") {
            var nc = t0, nb = t1, ne = nets.netOf[termKey(el.id, 2)];
            var mode = state[el.id];
            if (mode === "off") {
                pair(nb, ne, 1 / R_BE_OFF);
                pair(nc, ne, 1 / R_CE_OFF);
                continue;
            }
            // base-emitter: the same diode companion the LED uses, which is
            // why a base current comes out of the network rather than out of
            // a rule
            var gbe = 1 / R_BE;
            pair(nb, ne, gbe);
            inject(nb, ne, VF_BE * gbe);
            if (mode === "sat") {
                var gsat = 1 / R_SAT;
                pair(nc, ne, gsat);
                inject(nc, ne, VCE_SAT * gsat);
            } else {
                // active: Ic = BETA * Ib = BETA * gbe * (Vbe - VF_BE), a
                // current flowing c -> e that depends on Vbe somewhere ELSE in
                // the matrix. That is the one asymmetric stamp in this solver,
                // and the reason the matrix is solved by plain elimination
                // rather than by anything that assumes symmetry.
                var gm = BETA * gbe;
                G[nc][nb] += gm; G[nc][ne] -= gm;
                G[ne][nb] -= gm; G[ne][ne] += gm;
                inject(nc, ne, BETA * VF_BE * gbe);
                pair(nc, ne, 1 / R_EARLY);
            }
            continue;
        }

        if (el.type === "gate") {
            var gv = t0, ga = t1;
            var gb = nets.netOf[termKey(el.id, 2)];
            var gy = nets.netOf[termKey(el.id, 3)];
            var gg = nets.netOf[termKey(el.id, 4)];
            pair(gv, gg, 1 / R_GATE_Q);
            pair(ga, gg, 1 / R_GATE_IN);
            pair(gb, gg, 1 / R_GATE_IN);
            // The output pulls to a PAD, so what it can deliver is whatever
            // the supply pins carry - and with no supply it pulls to nothing
            // at all rather than to a rail that is not there.
            var out = state[el.id];
            if (out === "high") pair(gv, gy, 1 / R_GATE_OUT);
            else if (out === "low") pair(gg, gy, 1 / R_GATE_OUT);
            else pair(gg, gy, 1 / ROPEN);
            continue;
        }

        var spec = diodeSpec(el.type);
        var on = spec ? !!state[el.id] : false;
        pair(t0, t1, conductanceOf(el, on));
        if (el.type === "battery") {
            // Norton: source V/RINT flowing into the + terminal (0).
            inject(t0, t1, (el.value || 4.5) / RINT);
        } else if (spec && on) {
            // Conducting diode companion: I = g*V - VF/R, so the constant term
            // injects INTO the anode (same sign rule as the Norton source).
            inject(t0, t1, spec.vf / spec.r);
        }
    }
    return { G: G, I: I };
}

// What a gate reads at this operating point. The supply comes first because
// the threshold is a fraction of it, not a number of its own.
function gateLevels(el, volts, nets) {
    var vg = volts[nets.netOf[termKey(el.id, 4)]];
    var vcc = volts[nets.netOf[termKey(el.id, 0)]] - vg;
    var half = vcc / 2;
    return { vcc: vcc,
             a: (volts[nets.netOf[termKey(el.id, 1)]] - vg) > half,
             b: (volts[nets.netOf[termKey(el.id, 2)]] - vg) > half };
}

// What a part's state SHOULD be, given the volts the last solve produced.
function stateFrom(el, volts, nets, was) {
    var spec = diodeSpec(el.type);
    if (spec) {
        var v = volts[nets.netOf[termKey(el.id, 0)]]
              - volts[nets.netOf[termKey(el.id, 1)]];
        // Conducting until the current actually reverses - NOT until it falls
        // below some small positive figure. A diode feeding a load that is
        // itself still assumed off carries almost nothing on that pass, and a
        // threshold of 1e-7 A read that as "stopped": the diode switched off,
        // the load then had no supply and switched off too, and the pair
        // oscillated until the flip-lock pinned both. That is exactly the
        // diode-OR gate, and it came out dark. The tolerance here is against
        // floating-point noise at the knee, nothing more.
        return was ? ((v - spec.vf) / spec.r > -1e-12) : (v > spec.vf);
    }
    if (el.type === "gate") {
        var lv = gateLevels(el, volts, nets);
        // No supply, no output. An unpowered gate must not assert a level it
        // has no way to produce, which is the whole reason this state has
        // three values and not two.
        if (lv.vcc < V_GATE_MIN) return "hiz";
        return gateOutput(el.func || "and", lv.a, lv.b) ? "high" : "low";
    }
    var vbe = volts[nets.netOf[termKey(el.id, 1)]]
            - volts[nets.netOf[termKey(el.id, 2)]];
    var vce = volts[nets.netOf[termKey(el.id, 0)]]
            - volts[nets.netOf[termKey(el.id, 2)]];
    if (vbe < VF_BE) return "off";
    if (was === "sat") {
        // still saturated as long as the collector wants no more than
        // BETA * Ib; ask for more and it has left saturation
        var ib = (vbe - VF_BE) / R_BE;
        var ic = (vce - VCE_SAT) / R_SAT;
        return (ic > BETA * ib) ? "active" : "sat";
    }
    return (vce < VCE_SAT) ? "sat" : "active";
}

function solve(elements, wires) {
    var nets = buildNets(elements, wires);
    var n = nets.count;
    var result = { ok: true, perElement: {}, batteries: {}, netCount: n,
                   shorted: false, overloaded: false, iterations: 0 };
    if (n === 0) { result.wireCurrent = {}; return result; }

    var i, el, v;

    // Piecewise-linear states, iterated to a fixed point: assume, solve,
    // re-read, repeat. A part that keeps flip-flopping sits in a branch that
    // cannot carry current (e.g. behind an open switch, where leak dividers
    // fake a forward voltage) - after a few flips it is pinned where it is,
    // which is the physical answer.
    var state = {}, nonlinear = [], flips = {};
    for (i = 0; i < elements.length; ++i) {
        el = elements[i];
        if (diodeSpec(el.type)) { state[el.id] = false; nonlinear.push(el); }
        else if (el.type === "transistor") { state[el.id] = "off"; nonlinear.push(el); }
        else if (el.type === "gate") { state[el.id] = "hiz"; nonlinear.push(el); }
    }

    var volts = null;
    var maxIter = nonlinear.length === 0 ? 1 : 40;
    for (var iter = 0; iter < maxIter; ++iter) {
        result.iterations = iter + 1;
        var sys = stampNetwork(elements, nets, n, state);
        volts = solveLinear(sys.G, sys.I);
        if (!volts) { result.ok = false; result.wireCurrent = {}; return result; }

        var changed = false;
        for (i = 0; i < nonlinear.length; ++i) {
            el = nonlinear[i];
            var want = stateFrom(el, volts, nets, state[el.id]);
            if (want === state[el.id]) continue;
            flips[el.id] = (flips[el.id] || 0) + 1;
            if (flips[el.id] > 6) continue;      // pinned: the branch is dead
            state[el.id] = want;
            changed = true;
        }
        if (!changed) break;
    }

    for (i = 0; i < elements.length; ++i) {
        el = elements[i];
        var entry;
        if (el.type === "transistor") {
            var vc = volts[nets.netOf[termKey(el.id, 0)]];
            var vb = volts[nets.netOf[termKey(el.id, 1)]];
            var ve = volts[nets.netOf[termKey(el.id, 2)]];
            var vbeR = vb - ve, vceR = vc - ve;
            var mode = state[el.id], ibR, icR;
            if (mode === "off") {
                ibR = vbeR / R_BE_OFF;
                icR = vceR / R_CE_OFF;
            } else if (mode === "sat") {
                ibR = (vbeR - VF_BE) / R_BE;
                icR = (vceR - VCE_SAT) / R_SAT;
            } else {
                ibR = (vbeR - VF_BE) / R_BE;
                icR = BETA * ibR + vceR / R_EARLY;
            }
            if (!isFinite(vbeR)) vbeR = 0;
            if (!isFinite(vceR)) vceR = 0;
            if (!isFinite(ibR)) ibR = 0;
            if (!isFinite(icR)) icR = 0;
            // v and i are the collector-emitter pair, so every generic readout
            // in the lab - value labels, the plot, the voltmeter - reads a
            // transistor without knowing what one is
            result.perElement[el.id] = {
                v: vceR, i: icR, on: mode !== "off",
                power: Math.abs(vceR * icR) + Math.abs(vbeR * ibR),
                mode: mode, ib: ibR, ic: icR, vbe: vbeR, vce: vceR };
            continue;
        }

        if (el.type === "gate") {
            var gvv = volts[nets.netOf[termKey(el.id, 0)]];
            var gva = volts[nets.netOf[termKey(el.id, 1)]];
            var gvb = volts[nets.netOf[termKey(el.id, 2)]];
            var gvy = volts[nets.netOf[termKey(el.id, 3)]];
            var gvg = volts[nets.netOf[termKey(el.id, 4)]];
            var lvl = gateLevels(el, volts, nets);
            var outState = state[el.id];
            var hi = outState === "high";
            // Every branch inside the package, signed as it flows internally:
            // quiescent and the two input resistors run down to the GND pad,
            // and the output runs from whichever pad it is driving out to Y.
            var iQ = (gvv - gvg) / R_GATE_Q;
            var iA = (gva - gvg) / R_GATE_IN;
            var iB = (gvb - gvg) / R_GATE_IN;
            var vDrive = hi ? gvv : gvg;
            var rOut = (outState === "hiz") ? ROPEN : R_GATE_OUT;
            var iY = (vDrive - gvy) / rOut;      // out of Y, + = sourcing
            if (!isFinite(iQ)) iQ = 0;
            if (!isFinite(iA)) iA = 0;
            if (!isFinite(iB)) iB = 0;
            if (!isFinite(iY)) iY = 0;
            // Five pads cannot be signed by a rule the way two or three can,
            // so the solver writes down what each one sends into the wires and
            // terminalOutflow just reads it back. They sum to zero by
            // construction, which is the check worth having.
            var term = [ -(iQ + (hi ? iY : 0)), -iA, -iB, iY,
                         iQ + iA + iB - (hi ? 0 : iY) ];
            var gPow = Math.abs(iQ * (gvv - gvg)) + Math.abs(iA * (gva - gvg))
                     + Math.abs(iB * (gvb - gvg)) + Math.abs(iY * (vDrive - gvy));
            var gVout = gvy - gvg;
            var gVcc = lvl.vcc;
            if (!isFinite(gVout)) gVout = 0;
            if (!isFinite(gVcc)) gVcc = 0;
            if (!isFinite(gPow)) gPow = 0;
            // v and i are the output pin against the ground pin, and `on` is
            // the logic level under the same name the LED uses for "lit" - so
            // every generic readout in the lab reads a gate without knowing
            // what one is.
            result.perElement[el.id] = {
                v: gVout, i: iY, on: hi, power: gPow,
                func: el.func || "and", vcc: gVcc,
                a: lvl.a, b: lvl.b, y: hi, powered: gVcc >= V_GATE_MIN,
                term: term };
            continue;
        }

        var va = volts[nets.netOf[termKey(el.id, 0)]];
        var vbT = volts[nets.netOf[termKey(el.id, 1)]];
        v = va - vbT;
        var spD = diodeSpec(el.type);
        var cur;
        if (el.type === "battery")
            cur = ((el.value || 4.5) - v) / RINT;      // discharge current out of +
        else if (spD)
            cur = state[el.id] ? (v - spD.vf) / spD.r : 0;
        else
            cur = v * conductanceOf(el, false);
        if (!isFinite(v)) v = 0;
        if (!isFinite(cur)) cur = 0;
        entry = { v: v, i: cur, on: false, power: Math.abs(v * cur) };
        if (spD) entry.on = state[el.id] && cur > 1e-5;
        if (el.type === "bulb") entry.on = entry.power > 0.005;
        if (el.type === "switch") entry.on = !!el.on;
        if (el.type === "battery") {
            var ib = Math.abs(cur);
            var vTerm = Math.abs(v);
            var emf = el.value || 4.5;
            // external resistance the cell actually sees
            var rExt = ib > 1e-3 ? vTerm / ib : Infinity;
            var isShort = rExt < 2 * RINT;
            result.batteries[el.id] = {
                emf: emf, i: cur, vTerm: vTerm, rExt: rExt,
                internalDrop: Math.max(0, emf - vTerm),
                rated: I_RATED,
                shorted: isShort,
                overloaded: !isShort && ib > I_RATED
            };
            if (isShort) result.shorted = true;
            else if (ib > I_RATED) result.overloaded = true;
        }
        result.perElement[el.id] = entry;
    }
    result.wireCurrent = attributeWireCurrents(elements, wires, result.perElement);
    return result;
}

// ---- per-wire current ------------------------------------------------------
//
// A wire cannot be oriented by potential: it IS the net here (ideal, zero
// resistance), so both of its ends sit at exactly the same voltage. What is
// known instead is every element's current, so the wires follow from KCL.
//
// Sign convention out of the solver: v = V(term0) - V(term1) and, for passive
// elements, i = v * G - so a positive current runs internally 0 -> 1 and
// therefore leaves terminal 1. A battery is the other way round: positive is
// discharge, leaving terminal 0 (its + side). A transistor has its own
// bookkeeping: collector and base currents flow IN, and the emitter carries
// both of them back out. A part with more pads than that (a gate has five)
// cannot be signed by any such rule, so it hands the solver an explicit
// per-terminal list instead and this reads it straight off.
function terminalOutflow(el, ti, entry) {
    if (entry.term) return entry.term[ti];
    if (el.type === "transistor") {
        if (ti === 0) return -entry.ic;
        if (ti === 1) return -entry.ib;
        return entry.ic + entry.ib;
    }
    var out = (el.type === "battery") ? (ti === 0) : (ti === 1);
    return out ? entry.i : -entry.i;
}

// Peels terminals that have exactly one wire of unknown current and applies
// KCL there, repeating until nothing new can be resolved. Tree-shaped wiring
// resolves completely; genuinely ambiguous wires (two wires in parallel
// between the same pair of terminals - a redundant connection) stay null and
// simply do not animate, which is honest.
function attributeWireCurrents(elements, wires, perElement) {
    var byId = {}, i, w, k;
    for (i = 0; i < elements.length; ++i) byId[elements[i].id] = elements[i];

    var atTerm = {};                 // termKey -> [wire index]
    for (i = 0; i < wires.length; ++i) {
        w = wires[i];
        var ka = termKey(w.a[0], w.a[1]), kb = termKey(w.b[0], w.b[1]);
        (atTerm[ka] = atTerm[ka] || []).push(i);
        (atTerm[kb] = atTerm[kb] || []).push(i);
    }

    var cur = [];                    // signed along a -> b, null while unknown
    for (i = 0; i < wires.length; ++i) cur.push(null);

    // current leaving terminal `key` through wire `idx`
    function leaving(idx, key) {
        var ww = wires[idx];
        if (cur[idx] === null) return 0;
        return termKey(ww.a[0], ww.a[1]) === key ? cur[idx] : -cur[idx];
    }

    var progress = true;
    while (progress) {
        progress = false;
        for (k in atTerm) {
            var list = atTerm[k], unknown = -1, unknownCount = 0;
            for (i = 0; i < list.length; ++i)
                if (cur[list[i]] === null) { unknown = list[i]; ++unknownCount; }
            if (unknownCount !== 1) continue;

            var parts = k.split(":");
            var el = byId[parts[0]] || byId[parseInt(parts[0], 10)];
            var entry = el ? perElement[el.id] : null;
            if (!el || !entry) continue;

            var need = terminalOutflow(el, parseInt(parts[1], 10), entry);
            for (i = 0; i < list.length; ++i)
                if (list[i] !== unknown) need -= leaving(list[i], k);

            w = wires[unknown];
            cur[unknown] = termKey(w.a[0], w.a[1]) === k ? need : -need;
            progress = true;
        }
    }

    var out = {};
    for (i = 0; i < wires.length; ++i) out[wires[i].id] = cur[i];
    return out;
}
