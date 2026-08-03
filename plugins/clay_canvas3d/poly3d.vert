// Poly3D vertex shader - fill only, no edge channel yet.
VARYING vec4 colorOut;

void MAIN()
{
    // baseColor is auto-connected from the CustomMaterial; COLOR is the
    // fallback for a geometry that ever grows a per-vertex colour.
    colorOut = baseColor.a > 0.0 ? baseColor : COLOR;
}
