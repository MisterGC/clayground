#version 440
// (c) Clayground Contributors - MIT License, see "LICENSE" file

// One overlay that lights the scene below it. Qt Quick blends premultiplied
// (ONE, ONE_MINUS_SRC_ALPHA), so the result on screen is
//     glow + scene * (1 - a)
// which is why alpha carries "how dark" and rgb carries the additive colour
// of the light. Everything is computed in world units, so the result does not
// depend on the resolution the layer renders at.
//
// Written for GLSL ES 1.00 / 3.00 as well (WebGL): no arrays, no dynamic
// indexing, loops with constant bounds only, and the lights are unrolled
// calls guarded by a uniform count.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // x, y: world position of the viewport's top-left corner; z, w: viewport
    // size in world units.
    vec4 view;
    vec4 ambient;
    // x, y: world position of occluder cell (0,0)'s lower-left corner;
    // z: cell size in world units; w: 1 when an occluder map is set.
    vec4 occ;
    // x, y: occluder map size in cells; z: shadow hardness; w: unused.
    vec4 occParams;
    float time;
    float lightCount;
    float glow;
    float bands;
    float dither;
    float falloff;
    // Per light: p = (xWu, yWu, radiusWu, phase), c = (rgb * intensity,
    // flicker). A negative phase marks a light that casts no shadow.
    vec4 p0;  vec4 c0;  vec4 p1;  vec4 c1;  vec4 p2;  vec4 c2;  vec4 p3;  vec4 c3;
    vec4 p4;  vec4 c4;  vec4 p5;  vec4 c5;  vec4 p6;  vec4 c6;  vec4 p7;  vec4 c7;
    vec4 p8;  vec4 c8;  vec4 p9;  vec4 c9;  vec4 p10; vec4 c10; vec4 p11; vec4 c11;
    vec4 p12; vec4 c12; vec4 p13; vec4 c13; vec4 p14; vec4 c14; vec4 p15; vec4 c15;
} ubuf;

layout(binding = 1) uniform sampler2D occluders;

// Three samples per cell: the occupancy along a ray through a linearly
// filtered map is piecewise linear, and at that rate the midpoint sum is smooth
// without per-pixel jitter (jitter showed as a stipple at shadow edges). 48
// covers a light of radius 16 cells; longer rays spread their samples out.
const int MAX_STEPS = 48;
const float SAMPLES_PER_CELL = 3.0;
// Longest solid run at either end of a ray that is measured exactly; a
// pixel deeper inside a wall than this is dark anyway.
const int MAX_WALL_CELLS = 4;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

// Ordered 4x4 Bayer threshold in [0, 1).
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// 1 when cell c (integer cell coordinates, y up) is solid. Read at the texel
// centre, where linear filtering returns the cell's own value.
float cellSolid(vec2 c) {
    vec2 uv = (c + 0.5) / ubuf.occParams.xy;
    uv.y = 1.0 - uv.y;
    return texture(occluders, uv).r;
}

// How far (in cells) a ray from p (cell space) along the unit direction d
// runs inside the solid cells it starts in; 0 when p is in an open cell.
// Walked cell by cell (a DDA), so the result is exact and moves smoothly
// with p - sampling it showed as contour rings across walls.
float solidExit(vec2 p, vec2 d, float maxC) {
    vec2 c = floor(p);
    if (cellSolid(c) < 0.5)
        return 0.0;
    vec2 stepDir = vec2(d.x >= 0.0 ? 1.0 : -1.0, d.y >= 0.0 ? 1.0 : -1.0);
    vec2 delta = vec2(abs(d.x) > 1e-6 ? abs(1.0 / d.x) : 1e6,
                      abs(d.y) > 1e-6 ? abs(1.0 / d.y) : 1e6);
    vec2 border = c + max(stepDir, vec2(0.0));
    vec2 tMax = abs(border - p) * delta;
    float t = 0.0;
    for (int i = 0; i < MAX_WALL_CELLS; ++i) {
        if (tMax.x < tMax.y) {
            t = tMax.x;
            tMax.x += delta.x;
            c.x += stepDir.x;
        } else {
            t = tMax.y;
            tMax.y += delta.y;
            c.y += stepDir.y;
        }
        if (t >= maxC || cellSolid(c) < 0.5)
            break;
    }
    return min(t, maxC);
}

// Fraction of light that passes from l to w.
//
// The walls at the two ends of the ray are measured exactly: a pixel inside a
// wall is lit about one cell deep on the side that looks at the light (wall
// tops stay lit, a long wall does not carry light along its inside), and a
// torch set into a wall shines out of it. In between, the ray is marched
// through the linearly filtered occluder map and the occupancy integrated, so
// a ray grazing a wall corner is only partly blocked: that is the soft edge.
// The march starts where the pixel's wall ends and steps a fixed distance, so
// the samples slide along with the pixel instead of jumping.
float visibility(vec2 l, vec2 w, float dist) {
    float cell = ubuf.occ.z;
    vec2 pc = (w - ubuf.occ.xy) / cell;
    vec2 lc = (l - ubuf.occ.xy) / cell;
    float distC = dist / cell;
    vec2 d = (lc - pc) / max(distC, 1e-6);
    float ownPixel = solidExit(pc, d, distC);
    float ownLight = solidExit(lc, -d, distC);
    float depth = max(ownPixel - 1.0, 0.0);
    // Past the soft edge of the end walls (see the smoothstep below).
    float start = ownPixel > 0.0 ? ownPixel + 0.2 : 0.0;
    float end = distC - (ownLight > 0.0 ? ownLight + 0.2 : 0.0);
    float span = end - start;
    if (span <= 0.0)
        return clamp(1.0 - depth * ubuf.occParams.z, 0.0, 1.0);
    float stepC = max(1.0 / SAMPLES_PER_CELL, span / float(MAX_STEPS));
    vec2 mapC = ubuf.occParams.xy;
    for (int i = 0; i < MAX_STEPS; ++i) {
        float done = float(i) * stepC;
        if (done >= span)
            break;
        // The last step is cut short at the end of the span.
        float len = min(stepC, span - done);
        vec2 uv = (pc + d * (start + done + 0.5 * len)) / mapC;
        uv.y = 1.0 - uv.y;
        // Linear filtering spreads a wall half a cell into the room; the
        // smoothstep pulls that back to a soft edge of about 0.2 cells on
        // either side of the true face, so a ray running along a wall - a
        // torch mounted on it - is not dimmed by a wall it never crosses.
        depth += smoothstep(0.3, 0.7, texture(occluders, uv).r) * len;
    }
    return clamp(1.0 - depth * ubuf.occParams.z, 0.0, 1.0);
}

vec3 shade(vec2 w, vec4 p, vec4 c) {
    vec2 d = w - p.xy;
    float dist = length(d);
    if (dist >= p.z)
        return vec3(0.0);
    float ph = abs(p.w);
    float f = sin(ubuf.time * 9.1 + ph) * 0.5
            + sin(ubuf.time * 15.3 + ph * 1.7) * 0.3
            + sin(ubuf.time * 27.7 + ph * 2.3) * 0.2;
    float radius = p.z * (1.0 + 0.06 * c.a * f);
    float x = clamp(dist / radius, 0.0, 1.0);
    // (1 - x)^falloff: reaches zero at the radius with a flat tangent, and
    // with the default 2 the light pools around its source instead of
    // filling its circle evenly (the scene is in sRGB, where a gentle
    // falloff reads as a flat disc with a rim).
    float att = pow(1.0 - x, ubuf.falloff);
    att *= 1.0 + 0.25 * c.a * f;
    if (p.w >= 0.0 && ubuf.occ.w > 0.5)
        att *= visibility(p.xy, w, dist);
    return c.rgb * att;
}

void main() {
    vec2 w = ubuf.view.xy + vec2(qt_TexCoord0.x * ubuf.view.z,
                                 -qt_TexCoord0.y * ubuf.view.w);
    float threshold = bayer4(gl_FragCoord.xy);

    vec3 lit = vec3(0.0);
    float n = ubuf.lightCount;
    if (n > 0.5)  lit += shade(w, ubuf.p0,  ubuf.c0);
    if (n > 1.5)  lit += shade(w, ubuf.p1,  ubuf.c1);
    if (n > 2.5)  lit += shade(w, ubuf.p2,  ubuf.c2);
    if (n > 3.5)  lit += shade(w, ubuf.p3,  ubuf.c3);
    if (n > 4.5)  lit += shade(w, ubuf.p4,  ubuf.c4);
    if (n > 5.5)  lit += shade(w, ubuf.p5,  ubuf.c5);
    if (n > 6.5)  lit += shade(w, ubuf.p6,  ubuf.c6);
    if (n > 7.5)  lit += shade(w, ubuf.p7,  ubuf.c7);
    if (n > 8.5)  lit += shade(w, ubuf.p8,  ubuf.c8);
    if (n > 9.5)  lit += shade(w, ubuf.p9,  ubuf.c9);
    if (n > 10.5) lit += shade(w, ubuf.p10, ubuf.c10);
    if (n > 11.5) lit += shade(w, ubuf.p11, ubuf.c11);
    if (n > 12.5) lit += shade(w, ubuf.p12, ubuf.c12);
    if (n > 13.5) lit += shade(w, ubuf.p13, ubuf.c13);
    if (n > 14.5) lit += shade(w, ubuf.p14, ubuf.c14);
    if (n > 15.5) lit += shade(w, ubuf.p15, ubuf.c15);

    vec3 e = ubuf.ambient.rgb + lit;
    float level = max(e.r, max(e.g, e.b));

    // Retro knobs. Bands quantise the total light level, not every light on
    // its own, so overlapping lights make one set of rings instead of a moire.
    // The dither moves the band edges by an ordered pattern; without bands it
    // breaks up the 8-bit steps of a slow gradient.
    if (ubuf.bands > 0.5) {
        float q = floor(level * ubuf.bands + 0.5 + (threshold - 0.5) * ubuf.dither)
                / ubuf.bands;
        lit *= q / max(level, 1e-4);
        e *= q / max(level, 1e-4);
        level = q;
    } else if (ubuf.dither > 0.0) {
        float q = level + (threshold - 0.5) * ubuf.dither / 16.0;
        lit *= q / max(level, 1e-4);
        e *= q / max(level, 1e-4);
        level = q;
    }

    float k = clamp(level, 0.0, 1.0);
    // The lights' own colour is added on top, so a torch pools warm on grey
    // stone; the ambient adds only its hue (what it has beyond grey), so a
    // dusk ambient tints the dark without lifting it.
    vec3 amb = ubuf.ambient.rgb;
    vec3 ambHue = amb - vec3(min(amb.r, min(amb.g, amb.b)));
    vec3 glow = ubuf.glow * (lit + ambHue);
    fragColor = vec4(glow, 1.0 - k) * ubuf.qt_Opacity;
}
