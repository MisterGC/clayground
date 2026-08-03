// Poly3D vertex shader - fill, plus the channel the wireframe is derived from.
VARYING vec4 colorOut;
VARYING vec3 edgeCoord;

void MAIN()
{
    // baseColor is auto-connected from the CustomMaterial; COLOR is the
    // fallback for a geometry that ever grows a per-vertex colour.
    colorOut = baseColor.a > 0.0 ? baseColor : COLOR;

    // TANGENT carries data here, not a tangent frame: Poly3DGeometry packs the
    // corner's barycentric coordinate into it, with an offset on any component
    // whose opposite edge is an interior diagonal. Passed straight through -
    // anything that rescales it (normal mapping, a Qt that starts
    // orthogonalising tangents) breaks the wireframe, which is what the
    // rendering test in tests/ is there to catch.
    edgeCoord = TANGENT;
}
