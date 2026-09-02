// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// What the board needs to know about each circuit part: where its pads sit
// in the part's OWN frame, how far its body reaches, whether it has a region
// you operate, how much clearance it wants, which state it carries and which
// rows its card offers. CircuitElement3D draws the pads from the same
// numbers, so pads, hit test and visuals cannot drift apart. The keep-out is
// left to the board, which derives it from the footprint - two pegs of
// clearance for a real part, one for a solder dot, more for a package.
//
// Two pads in a line is the rule. The transistor is the first exception -
// collector and emitter in line like everything else, the base on the part's
// near side, so all three stay far enough apart to be clicked. The gate is
// the second and a different kind of part: a PACKAGE with supply pins that
// are not optional - inputs on the left, output on the right, the way it is
// read in a diagram, VCC and GND across the short sides where a board's
// rails run.

var TWO_PADS = [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }]
var BODY = { x: 4.6, y: 3.4 }

// Every part carries the same three fields, whatever it uses of them, so a
// serialized board reads alike whichever part it holds: `value` (ohms,
// volts), `on` (a switch), `func` (a gate's logic).
function fields(value, func) {
    return { value: value, on: false, func: func === undefined ? "" : func }
}

function twoPad(value, rows) {
    return { terminals: TWO_PADS, half: BODY, actuator: null,
             fields: fields(value), rows: rows || [] }
}

var DEFAULT_VOLTS = 4.5

var spec = {
    battery: twoPad(DEFAULT_VOLTS, ["value"]),
    // A switch is 4.6 wide and its two pads sit at +-3.5 with a 2.3 grab
    // radius, so the pads reach inward to 1.2 and left a 2.4-wide strip in
    // the middle as the only place a click toggled rather than started a
    // wire. The actuator is a region in its own right, tested BEFORE the
    // terminals, covering the body inboard of the pads.
    switch: { terminals: TWO_PADS, half: BODY, actuator: { x: 2.6, y: 2.0 },
              fields: fields(0), rows: ["state"] },
    resistor: twoPad(470, ["value"]),
    led: twoPad(0),
    bulb: twoPad(0),
    diode: twoPad(0),
    ammeter: twoPad(0),
    voltmeter: twoPad(0),
    transistor: {
        terminals: [{ x: -3.5, y: 0 },      // collector
                    { x: 0, y: 3.5 },       // base
                    { x: 3.5, y: 0 }],      // emitter
        half: { x: 4.6, y: 4.6 }, actuator: null,
        fields: fields(0), rows: []
    },
    gate: {
        terminals: [{ x: 0, y: -4.6 },      // VCC
                    { x: -6.0, y: -2.6 },   // A
                    { x: -6.0, y: 2.6 },    // B
                    { x: 6.0, y: 0 },       // Y
                    { x: 0, y: 4.6 }],      // GND
        // nearly three cells wide, so it asks for more room than the rest -
        // the board derives the keep-out from this footprint
        half: { x: 7.0, y: 5.6 }, actuator: null,
        fields: fields(0, "and"), rows: ["func"]
    },
    // A solder dot: the board's reserved type, with this kit's field set so
    // it serializes like every other part - and TWO pads, coincident, because
    // the solver models it as RCLOSED between its terminals like a closed
    // switch; every wire that meets here is on pad 0, pad 1 floats.
    junction: { terminals: [{ x: 0, y: 0 }, { x: 0, y: 0 }], half: { x: 2.3, y: 2.3 },
                actuator: null, fields: fields(0), rows: [], watch: false }
}

// The palette, in this order, each with the colour it wears on the board.
var catalog = [
    { type: "battery", color: "#3e9b92" },
    { type: "switch", color: "#c56c54" },
    { type: "resistor", color: "#d9c9a0" },
    { type: "led", color: "#e05a40" },
    { type: "bulb", color: "#d4ba6a" },
    { type: "diode", color: "#3a3630" },
    { type: "transistor", color: "#2a2724" },
    { type: "gate", color: "#4a4f55" },
    { type: "ammeter", color: "#3f7a57" },
    { type: "voltmeter", color: "#8160a8" }
]
