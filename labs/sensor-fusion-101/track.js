// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Rounded-rectangle loop track in plan coordinates (x, y); 3D maps y -> z.
.pragma library

var _segs = null
var _total = 0

function _build() {
    var r = 8
    _segs = []
    _total = 0
    function line(x0, y0, x1, y1) {
        var dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy)
        _segs.push({t: "l", x0: x0, y0: y0, hx: dx / len, hy: dy / len, len: len})
        _total += len
    }
    function arc(cx, cy, a0, a1) {
        var len = Math.abs(a1 - a0) * r
        _segs.push({t: "a", cx: cx, cy: cy, a0: a0, a1: a1, r: r, len: len})
        _total += len
    }
    line(-14, 14, 14, 14)
    arc(14, 6, Math.PI / 2, 0)
    line(22, 6, 22, -6)
    arc(14, -6, 0, -Math.PI / 2)
    line(14, -14, -14, -14)
    arc(-14, -6, -Math.PI / 2, -Math.PI)
    line(-22, -6, -22, 6)
    arc(-14, 6, Math.PI, Math.PI / 2)
}

function length() {
    if (!_segs) _build()
    return _total
}

function poseAt(s) {
    if (!_segs) _build()
    s = ((s % _total) + _total) % _total
    for (var i = 0; i < _segs.length; ++i) {
        var seg = _segs[i]
        if (s > seg.len) { s -= seg.len; continue }
        if (seg.t === "l")
            return {x: seg.x0 + seg.hx * s, y: seg.y0 + seg.hy * s,
                    heading: Math.atan2(seg.hy, seg.hx)}
        var dir = seg.a1 > seg.a0 ? 1 : -1
        var a = seg.a0 + dir * s / seg.r
        return {x: seg.cx + seg.r * Math.cos(a), y: seg.cy + seg.r * Math.sin(a),
                heading: Math.atan2(dir * Math.cos(a), -dir * Math.sin(a))}
    }
    return {x: -14, y: 14, heading: 0}
}

function ringCoords(yHeight, n) {
    if (!_segs) _build()
    var pts = []
    for (var i = 0; i <= n; ++i) {
        var p = poseAt(_total * i / n)
        pts.push(Qt.vector3d(p.x, yHeight, p.y))
    }
    return pts
}
