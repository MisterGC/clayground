#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 lightPos;
    float innerPx;
    float outerPx;
    float time;
    float flicker;
    vec4 tintColor;
    vec4 darkColor;
} ubuf;

void main() {
    vec2 p = qt_TexCoord0 * ubuf.resolution;
    float d = distance(p, ubuf.lightPos);

    float inner = ubuf.innerPx;
    if (ubuf.flicker > 0.0) {
        float f = sin(ubuf.time * 6.2831) * 0.6
                + sin(ubuf.time * 13.17)  * 0.3
                + sin(ubuf.time * 21.3)   * 0.1;
        inner *= (1.0 + f * 0.15 * ubuf.flicker);
    }

    float t = smoothstep(inner, ubuf.outerPx, d);
    // Pure multiplicative darkening (Diablo-style): the dark edge color fades
    // in as t -> 1. No warm cast on the scene — atmosphere comes from the
    // assets, not the lighting. tintColor is currently unused.
    fragColor = ubuf.darkColor * t * ubuf.qt_Opacity;
}
