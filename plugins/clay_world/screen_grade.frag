#version 440
// (c) Clayground Contributors - MIT License, see "LICENSE" file

// The half of ScreenFx2d that has to read the scene: chromatic aberration,
// colour grade, low-health desaturation and posterise + dither. Drawn instead
// of the (hidden) world canvas.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
    float temperature;
    float saturation;
    float contrast;
    float brightness;
    // Channel offset at the screen edge, in texture coordinates.
    float aberration;
    float lowHealth;
    float levels;
    float dither;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c;
    if (ubuf.aberration > 0.0) {
        // Radial: nothing at the centre, full offset at the corners.
        vec2 dir = (uv - 0.5) * ubuf.aberration * 2.0;
        vec4 g = texture(source, uv);
        float r = texture(source, uv + dir).r;
        float b = texture(source, uv - dir).b;
        c = vec4(r, g.g, b, g.a);
    } else {
        c = texture(source, uv);
    }

    // The canvas is premultiplied; grade the straight colour.
    vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);

    rgb *= ubuf.tint.rgb;
    rgb *= vec3(1.0 + 0.2 * ubuf.temperature, 1.0 + 0.03 * ubuf.temperature,
                1.0 - 0.2 * ubuf.temperature);
    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    // Colour drains with health, but only partly: a grey screen reads as a
    // broken picture, not as a dying hero.
    float sat = ubuf.saturation * (1.0 - 0.35 * ubuf.lowHealth);
    rgb = mix(vec3(luma), rgb, sat);
    rgb = (rgb - 0.5) * ubuf.contrast + 0.5 + ubuf.brightness;
    rgb = clamp(rgb, 0.0, 1.0);

    // Posterise the brightness (the largest channel), not each channel: on a
    // dark scene per-channel steps turn browns olive and pink wherever one
    // channel rounds down and the next one up.
    if (ubuf.levels > 1.5) {
        float steps = ubuf.levels - 1.0;
        float t = (bayer4(gl_FragCoord.xy) - 0.5) * ubuf.dither;
        float v = max(rgb.r, max(rgb.g, rgb.b));
        float q = clamp(floor(v * steps + 0.5 + t) / steps, 0.0, 1.0);
        rgb *= v > 0.0 ? q / v : 0.0;
        rgb = clamp(rgb, 0.0, 1.0);
    }

    fragColor = vec4(rgb * c.a, c.a) * ubuf.qt_Opacity;
}
