// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// PathLabel3D word-quad fragment stage. Inked texels blend AND write depth so
// the word deterministically occludes the line beneath it regardless of the
// blended-pass draw order; transparent texels are discarded entirely, so they
// write neither color nor depth and can never punch holes into the line (the
// PrincipledMaterial depth modes cannot express this split - Blend never
// discards, Mask kills the halo's soft edges).
VARYING vec2 vUV;

void MAIN()
{
    vec4 c = texture(wordTex, vUV);
    if (c.a < 0.05)
        discard;
    FRAGCOLOR = c;
}
