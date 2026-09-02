// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The board contract: everything a generic Board store needs to know about a
// hydro part without knowing anything about hydraulics. Pure data plus four
// one-line helpers, so the same file serves the store, the 3D part component
// and the node suite - one place where a pad offset lives, rather than three
// that drift.
//
// spec[type] = {
//   terminals: [{x, y}, ...],  // local pad offsets in world units (y is the
//                              // board's z axis: the board is flat, so a
//                              // part's plan geometry is 2D)
//   half:      {x, y},         // body footprint half-extents
//   actuator:  {x, y} | null,  // operable region, tested BEFORE the pads
//   (the keep-out is the board's: derived from `half`, two pegs for a real
//   part and one for a T-piece, so it can never disagree with the body)
//   fields:    {value, on},    // domain state and its defaults per type
//   rows:      ["state"],      // card rows the domain offers for this type
//   termNames: ["a", "b"]      // what the pads are, for labels and hints
// }
//
// The numbers are the circuit kit's, deliberately: both kits sit on the same
// peg raster of 5 units, so a two-terminal part is 9.2 x 6.8 with pads at
// x = -/+3.5, and a T-piece is a 4.6 square dot. A board that can lay out one
// kit can lay out the other without a special case.
//
// TERMINAL 0 OF A PUMP IS ITS OUTLET (see hydro.js) - the high-pressure side,
// the analogue of a cell's + terminal, and the one the part marks in gold.

var PAD = 3.5;          // pad offset from a two-terminal part's centre
var HALF_X = 4.6;       // body half-width  (along the part's local x)
var HALF_Y = 3.4;       // body half-depth  (along the board's z)
var JUNCTION_HALF = 2.3;

function _pair() { return [{ x: -PAD, y: 0 }, { x: PAD, y: 0 }]; }
function _half() { return { x: HALF_X, y: HALF_Y }; }

var spec = {
    "pump": {
        terminals: _pair(), half: _half(), actuator: null,
        fields: { value: 40, on: false }, rows: ["value"],
        termNames: ["out", "in"]
    },
    "valve": {
        terminals: _pair(), half: _half(),
        // the one part you operate rather than configure: the handwheel sits
        // in the middle of the body and is tested before the pads, so grabbing
        // the handle never starts a pipe run by accident
        actuator: { x: 2.6, y: 2.0 },
        fields: { value: 0, on: true }, rows: ["state"],
        termNames: ["in", "out"]
    },
    "pipe": {
        terminals: _pair(), half: _half(), actuator: null,
        fields: { value: 8, on: false }, rows: ["value"],
        termNames: ["in", "out"]
    },
    "wheel": {
        terminals: _pair(), half: _half(), actuator: null,
        fields: { value: 0, on: false }, rows: [],
        termNames: ["in", "out"]
    },
    "flowmeter": {
        terminals: _pair(), half: _half(), actuator: null,
        fields: { value: 0, on: false }, rows: [],
        termNames: ["in", "out"]
    },
    "gauge": {
        terminals: _pair(), half: _half(), actuator: null,
        fields: { value: 0, on: false }, rows: [],
        termNames: ["+", "-"]
    },
    "junction": {
        // one pad, at the part's own origin: a T-piece is a place, not a body
        terminals: [{ x: 0, y: 0 }],
        half: { x: JUNCTION_HALF, y: JUNCTION_HALF }, actuator: null,
        fields: { value: 0, on: false }, rows: [],
        termNames: ["tap"]
    }
};

// Palette order and part colours. No junction: a T-piece is not placed from
// the palette, it appears where a pipe run is tapped.
//
// The colours are the circuit kit's, part for analogous part - the source is
// teal, the actuator is clay, the flow meter wears the ammeter's forest and
// the pressure gauge the voltmeter's plum. Two labs taught side by side should
// agree about what a colour means.
var catalog = [
    { type: "pump", color: "#3e9b92" },
    { type: "valve", color: "#c56c54" },
    { type: "pipe", color: "#9fb3c8" },
    { type: "wheel", color: "#b5813f" },
    { type: "flowmeter", color: "#3f7a57" },
    { type: "gauge", color: "#8160a8" }
];

// ---- helpers ---------------------------------------------------------------

function specOf(type) { return spec[type] || null; }

function terminalCount(type) {
    var s = spec[type];
    return s ? s.terminals.length : 0;
}

// A fresh copy of the type's domain defaults - never the shared object, or the
// first part placed would become every later part's state.
function defaults(type) {
    var s = spec[type];
    if (!s) return {};
    var out = {};
    for (var k in s.fields) out[k] = s.fields[k];
    return out;
}

// Where pad `i` of a part centred at (cx, cz) with yaw `rot` degrees lands on
// the board. Board yaw turns counter-clockwise seen from above, which with x
// right and z toward the viewer is this pair of signs - the one place they are
// written down.
function padAt(type, i, cx, cz, rot) {
    var s = spec[type];
    if (!s || i < 0 || i >= s.terminals.length) return { x: cx, z: cz };
    var t = s.terminals[i];
    var a = (rot || 0) * Math.PI / 180;
    var ca = Math.cos(a), sa = Math.sin(a);
    return { x: cx + t.x * ca + t.y * sa,
             z: cz - t.x * sa + t.y * ca };
}

// The colour the palette and the 3D body agree on, or "" for the T-piece,
// which wears ink.
function colorOf(type) {
    for (var i = 0; i < catalog.length; ++i)
        if (catalog[i].type === type) return catalog[i].color;
    return "";
}
