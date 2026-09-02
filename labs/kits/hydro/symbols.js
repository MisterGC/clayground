// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Schematic symbols for fluid power (the ISO 1219 family), drawn into any 2D
// canvas context.
//
// Shared on purpose: the palette draws them next to each part and a schematic
// minimap draws the same shapes for the whole board, so the symbol a learner
// sees in the list is exactly the one that appears in the diagram - and the
// symbols are the real convention, because half of what a hydraulics diagram
// teaches is how to read a hydraulics diagram.

// Draws `type` centred at (cx, cy) inside a w x h box.
// opts: { ink, lineWidth, rot (degrees, board yaw), on (valve open) }
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
    function circle(rad) {
        ctx.beginPath(); ctx.arc(0, 0, rad, 0, 2 * Math.PI); ctx.stroke()
    }
    function letter(s, rad) {
        ctx.font = "bold " + Math.round(rad * 1.3) + "px sans-serif"
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(s, 0, rad * 0.06)
    }

    if (type === "pump") {
        // ISO 1219: a circle with a solid triangle pointing at the outlet.
        // The board's terminal 0 is the outlet, and terminal 0 is on the LEFT,
        // so the triangle points left - the symbol states the polarity the
        // part is wired with.
        leads(r)
        circle(r)
        ctx.beginPath()
        ctx.moveTo(-r * 0.72, 0)
        ctx.lineTo(r * 0.34, -r * 0.52)
        ctx.lineTo(r * 0.34, r * 0.52)
        ctx.closePath()
        ctx.fill()
    } else if (type === "valve") {
        // the bow tie: two triangles meeting at the stem. Filled when shut,
        // hollow when open - the same "you can see through it" reading a real
        // sight glass gives.
        const b = hw * 0.5
        leads(b)
        ctx.beginPath()
        ctx.moveTo(-b, -r * 0.85); ctx.lineTo(-b, r * 0.85); ctx.lineTo(0, 0)
        ctx.closePath()
        ctx.moveTo(b, -r * 0.85); ctx.lineTo(b, r * 0.85); ctx.lineTo(0, 0)
        ctx.closePath()
        if (o.on) ctx.stroke()
        else ctx.fill()
        ctx.beginPath()                                   // stem and handwheel
        ctx.moveTo(0, 0); ctx.lineTo(0, -h * 0.44)
        ctx.moveTo(-w * 0.11, -h * 0.44); ctx.lineTo(w * 0.11, -h * 0.44)
        ctx.stroke()
    } else if (type === "pipe") {
        // a restriction: the bore pinches in and opens out again
        const b = hw * 0.42
        leads(b)
        ctx.beginPath()
        ctx.moveTo(-b, -r * 0.9); ctx.lineTo(-b * 0.26, -r * 0.22)
        ctx.lineTo(b * 0.26, -r * 0.22); ctx.lineTo(b, -r * 0.9)
        ctx.moveTo(-b, r * 0.9); ctx.lineTo(-b * 0.26, r * 0.22)
        ctx.lineTo(b * 0.26, r * 0.22); ctx.lineTo(b, r * 0.9)
        ctx.stroke()
    } else if (type === "wheel") {
        // a paddle wheel: hub, rim and the blades that stand out of it
        leads(r)
        circle(r * 0.62)
        for (let i = 0; i < 8; ++i) {
            const a = i * Math.PI / 4
            const ca = Math.cos(a), sa = Math.sin(a)
            ctx.beginPath()
            ctx.moveTo(ca * r * 0.62, sa * r * 0.62)
            ctx.lineTo(ca * r, sa * r)
            ctx.stroke()
        }
    } else if (type === "flowmeter" || type === "gauge") {
        leads(r)
        circle(r)
        letter(type === "flowmeter" ? "Q" : "p", r)
    } else if (type === "junction") {
        dot(0, Math.max(2, ctx.lineWidth * 1.7))
    }

    ctx.restore()
}
