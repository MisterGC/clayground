#version 440
// (c) Clayground Contributors - MIT License, see "LICENSE" file

// The half of ScreenFx2d that needs no copy of the scene: vignette, the
// low-health red edge, film grain and the flash. A premultiplied overlay, so
// each effect is composed "over" the previous one and the result is blended
// over the world like any other item.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 vignetteColor;
    float vignette;
    float vignetteRadius;
    float vignetteSoftness;
    float lowHealth;
    float grain;
    float time;
    vec4 flashColor;
    float flash;
} ubuf;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec4 over(vec4 src, vec4 dst) {
    return src + dst * (1.0 - src.a);
}

void main() {
    vec2 uv = qt_TexCoord0;
    // Distance from the centre with the aspect ratio kept, 1.0 at a corner.
    vec2 d = (uv - 0.5) * vec2(ubuf.resolution.x / ubuf.resolution.y, 1.0);
    float r = length(d) / length(vec2(ubuf.resolution.x / ubuf.resolution.y, 1.0) * 0.5);

    vec4 acc = vec4(0.0);

    if (ubuf.vignette > 0.0) {
        float v = smoothstep(ubuf.vignetteRadius,
                             ubuf.vignetteRadius + ubuf.vignetteSoftness, r);
        float a = v * ubuf.vignette * ubuf.vignetteColor.a;
        acc = over(vec4(ubuf.vignetteColor.rgb * a, a), acc);
    }

    if (ubuf.lowHealth > 0.0) {
        // A slow heartbeat: a double pulse once a second.
        float t = fract(ubuf.time);
        // pow() is undefined for a negative base in GLSL, hence x * x.
        float b1 = (t - 0.08) * 14.0;
        float b2 = (t - 0.3) * 14.0;
        float beat = exp(-b1 * b1) + 0.6 * exp(-b2 * b2);
        float edge = smoothstep(0.35, 1.05, r);
        float a = clamp(edge * ubuf.lowHealth * (0.55 + 0.45 * beat), 0.0, 1.0);
        acc = over(vec4(vec3(0.55, 0.02, 0.02) * a, a), acc);
    }

    if (ubuf.grain > 0.0) {
        float n = hash(floor(gl_FragCoord.xy) + fract(ubuf.time * 7.13) * 311.0);
        float a = abs(n - 0.5) * ubuf.grain * 0.35;
        vec3 col = n > 0.5 ? vec3(1.0) : vec3(0.0);
        acc = over(vec4(col * a, a), acc);
    }

    if (ubuf.flash > 0.0) {
        float a = ubuf.flash * ubuf.flashColor.a;
        acc = over(vec4(ubuf.flashColor.rgb * a, a), acc);
    }

    fragColor = acc * ubuf.qt_Opacity;
}
