// LabelBatch3D glyph fragment shader.
// Unlit SDF text: sample the single-channel atlas, smoothstep at the 0.5 cutoff
// with ~1px anti-aliasing (fwidth), optional halo as a second, wider threshold.
// Material uniforms:
//   atlasTex   = R8 SDF atlas (sampler)
//   haloColor  = halo rgba
//   haloWidth  = halo band in SDF units past the 0.5 edge (0 = no halo)
//   labelOpacity = batch-wide opacity multiplier

VARYING vec2 vUV;
VARYING vec4 vColor;
VARYING float vOpacity;

void MAIN()
{
    float d = texture(atlasTex, vUV).r;
    float aa = max(fwidth(d), 0.001);

    float textCov = smoothstep(0.5 - aa, 0.5 + aa, d);

    float haloCov = 0.0;
    if (haloWidth > 0.0) {
        float edge = 0.5 - haloWidth;
        haloCov = smoothstep(edge - aa, edge + aa, d);
    }

    vec3 rgb = mix(haloColor.rgb, vColor.rgb, textCov);
    float haloA = haloCov * haloColor.a;
    float textA = textCov * vColor.a;
    float a = max(textA, haloA) * vOpacity * labelOpacity;
    if (a < 0.003)
        discard;

    FRAGCOLOR = vec4(rgb, a);
}
