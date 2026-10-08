#version 440
// (c) Clayground Contributors - MIT License, see "LICENSE" file

// The held frame of a view-only hit stop, moved by the live camera shake and
// kick. The strip the move uncovers mirrors the frame's own edge: it carries
// the same light and colour as its neighbour, where an empty strip or a
// stretched edge row reads as a crack at the side of the screen.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 shift;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0 - ubuf.shift;
    // Mirrored repeat: -0.1 reads 0.1, 1.1 reads 0.9.
    uv = 1.0 - abs(1.0 - abs(uv));
    fragColor = texture(source, uv) * ubuf.qt_Opacity;
}
