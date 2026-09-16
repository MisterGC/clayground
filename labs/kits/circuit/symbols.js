// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Schematic symbols (IEC 60617), drawn into any 2D canvas context.
//
// Shared on purpose: the palette draws them next to each part and the
// schematic minimap draws the same shapes for the whole board, so the symbol a
// learner sees in the list is exactly the one that appears in the diagram.

// How tall a symbol wants to be, as a fraction of its width. Two-terminal
// parts are a lead-body-lead strip and read best wide; a transistor reaches
// downwards for its base lead - the pad the part carries on its near side -
// so it needs a square box or the base ends up outside the frame. A gate is
// the package's own footprint, 14 by 11.2 units, so its box has to be that
// shape or the two input leads stop lining up with the pads they come from.
function aspect(type) {
    return type === "transistor" ? 1.0
         : type === "gate" ? 0.8
         : 0.66;
}

// Where a symbol's leads meet the edge of its box, as fractions of the box.
//
// A caller that draws a symbol next to real wires needs this, because the box
// is not a bounding box - it is defined BY the leads. Every symbol runs its
// two side leads out to x = +/- w/2, so a box narrower than the part's pads
// are apart leaves the wire ending in one place and the lead in another, and
// the diagram shows a circuit with gaps in it. Two symbols also have a lead
// leaving off-axis, and their `y` says where: a transistor's base comes in at
// h/2 from below, a gate's two inputs at 0.23 h above and below the axis.
// Anything else returns y = 0, meaning "nothing leaves sideways, so the height
// is a drawing ratio rather than a measurement" - see aspect().
function leadFractions(type) {
    return { x: 0.5,
             y: type === "transistor" ? 0.5
              : type === "gate" ? 0.23
              : 0 };
}

// Draws `type` centred at (cx, cy) inside a w x h box.
// opts: { ink, lineWidth, rot (degrees, board yaw), on (switch closed),
//         func (gate function: and / or / xor / nand / nor / not) }
function draw(ctx, type, cx, cy, w, h, opts) {
    const o = opts || {}
    const ink = o.ink || "#2f3437"

    ctx.save()
    ctx.translate(cx, cy)
    // board yaw turns counter-clockwise seen from above; canvas y points down
    if (o.rot) ctx.rotate(-o.rot * Math.PI / 180)
    ctx.strokeStyle = ink
    ctx.fillStyle = ink
    ctx.lineWidth = o.lineWidth || 1.6
    ctx.lineCap = "round"

    const hw = w / 2
    const r = Math.min(h / 2, w / 4)

    function leads(bodyHalf) {
        ctx.beginPath()
        ctx.moveTo(-hw, 0); ctx.lineTo(-bodyHalf, 0)
        ctx.moveTo(bodyHalf, 0); ctx.lineTo(hw, 0)
        ctx.stroke()
    }
    function dot(x, rad) {
        ctx.beginPath(); ctx.arc(x, 0, rad, 0, 2 * Math.PI); ctx.fill()
    }

    if (type === "resistor") {
        leads(hw * 0.55)
        ctx.strokeRect(-hw * 0.55, -h * 0.26, hw * 1.1, h * 0.52)
    } else if (type === "battery") {
        const g = w * 0.09
        leads(g * 2.4)
        ctx.beginPath()
        ctx.moveTo(-g * 2.4, -r);     ctx.lineTo(-g * 2.4, r)        // long: plus
        ctx.moveTo(-g * 0.8, -r * 0.5); ctx.lineTo(-g * 0.8, r * 0.5)
        ctx.moveTo(g * 0.8, -r);      ctx.lineTo(g * 0.8, r)
        ctx.moveTo(g * 2.4, -r * 0.5);  ctx.lineTo(g * 2.4, r * 0.5) // short: minus
        ctx.stroke()
    } else if (type === "switch") {
        leads(hw * 0.55)
        ctx.beginPath()
        ctx.moveTo(-hw * 0.55, 0)
        if (o.on) ctx.lineTo(hw * 0.55, 0)                            // closed
        else ctx.lineTo(hw * 0.45, -h * 0.42)                         // open blade
        ctx.stroke()
        dot(-hw * 0.55, ctx.lineWidth * 1.1)
        dot(hw * 0.55, ctx.lineWidth * 1.1)
    } else if (type === "led") {
        leads(hw * 0.55)
        ctx.beginPath()                                               // anode triangle
        ctx.moveTo(-hw * 0.55, -r); ctx.lineTo(-hw * 0.55, r)
        ctx.lineTo(hw * 0.55, 0); ctx.closePath(); ctx.stroke()
        ctx.beginPath()                                               // cathode bar
        ctx.moveTo(hw * 0.55, -r); ctx.lineTo(hw * 0.55, r); ctx.stroke()
        for (let i = 0; i < 2; ++i) {                                 // emission arrows
            const x = i * w * 0.2 - w * 0.04
            ctx.beginPath()
            ctx.moveTo(x, -r * 1.15); ctx.lineTo(x + h * 0.2, -r * 1.7)
            ctx.moveTo(x + h * 0.2, -r * 1.7); ctx.lineTo(x + h * 0.08, -r * 1.62)
            ctx.moveTo(x + h * 0.2, -r * 1.7); ctx.lineTo(x + h * 0.17, -r * 1.42)
            ctx.stroke()
        }
    } else if (type === "diode") {
        // the LED's shape without the light: a filled triangle into a bar, so
        // the two are told apart at a glance rather than by counting arrows
        leads(hw * 0.55)
        ctx.beginPath()
        ctx.moveTo(-hw * 0.55, -r); ctx.lineTo(-hw * 0.55, r)
        ctx.lineTo(hw * 0.55, 0); ctx.closePath(); ctx.fill()
        ctx.beginPath()                                               // cathode bar
        ctx.moveTo(hw * 0.55, -r); ctx.lineTo(hw * 0.55, r); ctx.stroke()
    } else if (type === "transistor") {
        // NPN, laid out the way the part lies on the board: collector left,
        // emitter right, base coming in from the near side (below). That is a
        // textbook symbol turned a quarter, and turning it is what keeps the
        // diagram and the board saying the same thing about which pad is which.
        const rr = Math.min(w, h) * 0.36
        const barY = rr * 0.5                       // the base bar, below the axis
        const barX = rr * 0.62
        ctx.beginPath()                             // envelope
        ctx.arc(0, 0, rr, 0, 2 * Math.PI); ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(0, h / 2); ctx.lineTo(0, barY)   // base lead, from below
        ctx.moveTo(-barX, barY); ctx.lineTo(barX, barY)                // base bar
        ctx.moveTo(-w / 2, 0); ctx.lineTo(-rr * 0.42, 0)               // collector
        ctx.lineTo(-rr * 0.42, barY * 0.34); ctx.lineTo(-barX * 0.55, barY)
        ctx.moveTo(w / 2, 0); ctx.lineTo(rr * 0.42, 0)                 // emitter
        ctx.lineTo(rr * 0.42, barY * 0.34); ctx.lineTo(barX * 0.55, barY)
        ctx.stroke()
        // the arrow on the emitter, pointing AWAY from the base: that is the
        // whole of "this one is an NPN"
        const ax = (rr * 0.42 + barX * 0.55) / 2, ay = (barY * 0.34 + barY) / 2
        const dx = rr * 0.42 - barX * 0.55, dy = barY * 0.34 - barY
        const len = Math.hypot(dx, dy) || 1
        const ux = dx / len, uy = dy / len, s = rr * 0.42
        ctx.beginPath()
        ctx.moveTo(ax + ux * s * 0.5, ay + uy * s * 0.5)
        ctx.lineTo(ax - ux * s * 0.5 - uy * s * 0.3, ay - uy * s * 0.5 + ux * s * 0.3)
        ctx.lineTo(ax - ux * s * 0.5 + uy * s * 0.3, ay - uy * s * 0.5 - ux * s * 0.3)
        ctx.closePath(); ctx.fill()
    } else if (type === "gate") {
        // The ANSI distinctive shapes rather than the IEC rectangle with a
        // "&" in it: this kit is read by people who have seen the D and the
        // shield in every textbook and datasheet, and the shape alone says
        // which gate it is from across the board - a rectangle needs its label
        // read first. The bubble on the output is the "N", everywhere.
        //
        // VCC and GND are NOT drawn. That is the schematic convention and it
        // is worth stating: every gate in a family hangs on the same two
        // rails, so drawing them turns a logic diagram into a wiring diagram.
        // The pads are still on the board and still have to be wired there.
        const f = o.func || "and"
        const inverted = (f === "nand" || f === "nor" || f === "not")
        const curved = (f === "or" || f === "nor" || f === "xor")
        const bh = h * 0.38                  // body half height
        const x0 = -w * 0.24, x1 = w * 0.24  // back edge, output tip
        const dx = x1 - x0
        const rb = h * 0.10                  // the inversion bubble
        const inY = h * 0.23                 // exactly where the A and B pads sit

        // Both input leads are drawn for every function, NOT included: the
        // package carries two input pads whatever its function, and a wire
        // running to a pad the symbol has no lead for would end in mid air.
        // A curved back is met from slightly inside, the way it is drawn by
        // hand, or the lead stops short of the shape it belongs to.
        const inX = curved ? x0 + w * 0.05 : x0
        ctx.beginPath()
        ctx.moveTo(-hw, -inY); ctx.lineTo(inX, -inY)
        ctx.moveTo(-hw, inY); ctx.lineTo(inX, inY)
        ctx.moveTo(inverted ? x1 + 2 * rb : x1, 0); ctx.lineTo(hw, 0)
        ctx.stroke()

        ctx.beginPath()
        if (f === "not") {
            ctx.moveTo(x0, -bh); ctx.lineTo(x0, bh); ctx.lineTo(x1, 0)
            ctx.closePath()
        } else if (curved) {
            // the shield: two edges sweeping to a point, on a back that bows
            // towards the output
            ctx.moveTo(x0, -bh)
            ctx.bezierCurveTo(x0 + dx * 0.45, -bh, x1 - dx * 0.18, -bh * 0.62, x1, 0)
            ctx.bezierCurveTo(x1 - dx * 0.18, bh * 0.62, x0 + dx * 0.45, bh, x0, bh)
            ctx.quadraticCurveTo(x0 + dx * 0.30, 0, x0, -bh)
        } else {
            // the D: a straight back and a semicircle whose radius IS the
            // body half height, so the shape closes on the output axis
            ctx.moveTo(x0, -bh); ctx.lineTo(x1 - bh, -bh)
            ctx.arc(x1 - bh, 0, bh, -Math.PI / 2, Math.PI / 2)
            ctx.lineTo(x0, bh)
            ctx.closePath()
        }
        ctx.stroke()

        if (f === "xor") {   // the second back curve is the whole of "exclusive"
            const xx = x0 - w * 0.07
            ctx.beginPath()
            ctx.moveTo(xx, -bh)
            ctx.quadraticCurveTo(xx + dx * 0.30, 0, xx, bh)
            ctx.stroke()
        }
        if (inverted) {
            ctx.beginPath()
            ctx.arc(x1 + rb, 0, rb, 0, 2 * Math.PI); ctx.stroke()
        }
    } else if (type === "bulb") {
        leads(r)
        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI); ctx.stroke()
        const d = r * 0.707
        ctx.beginPath()
        ctx.moveTo(-d, -d); ctx.lineTo(d, d)
        ctx.moveTo(d, -d); ctx.lineTo(-d, d)
        ctx.stroke()
    } else if (type === "ammeter" || type === "voltmeter") {
        leads(r)
        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI); ctx.stroke()
        ctx.font = "bold " + Math.round(r * 1.35) + "px sans-serif"
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(type === "ammeter" ? "A" : "V", 0, r * 0.06)
    } else if (type === "junction") {
        dot(0, Math.max(2, ctx.lineWidth * 1.7))
    }

    ctx.restore()
}
