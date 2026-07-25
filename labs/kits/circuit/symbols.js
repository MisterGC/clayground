// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Schematic symbols (IEC 60617), drawn into any 2D canvas context.
//
// Shared on purpose: the palette draws them next to each part and the
// schematic minimap draws the same shapes for the whole board, so the symbol a
// learner sees in the list is exactly the one that appears in the diagram.

// Draws `type` centred at (cx, cy) inside a w x h box.
// opts: { ink, lineWidth, rot (degrees, board yaw), on (switch closed) }
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
