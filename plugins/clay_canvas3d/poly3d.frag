// Poly3D fragment shader - flat filled area, optional toon lighting.
//
// The lighting half is deliberately the same code Box3D runs, copied rather
// than shared: CustomMaterial snippets have no #include, so a polygon next to
// a box in the same scene can only match by repeating it.

VARYING vec4 colorOut;
VARYING vec3 edgeCoord;

// Uniforms exposed from the CustomMaterial
// - bool useToonShading      // enables toon/cartoon style lighting
// - bool showEdges
// - int edgeMode             // 0 = FaceBorders, 1 = Triangles
// - float edgeThickness      // thickness in pixels
// - float edgeColorFactor
// - vec4 edgeColor           // absolute edge colour; alpha 0 means "unset"

// Must match kPoly3DEdgeSuppressOffset in src/poly3dgeometry.h.
const float EDGE_SUPPRESS_OFFSET = 10.0;

void MAIN()
{
    vec4 finalColor = colorOut;

    if (showEdges) {
        // edgeCoord is the corner's barycentric coordinate, plus
        // EDGE_SUPPRESS_OFFSET on every component whose opposite edge is an
        // interior diagonal rather than a polygon ring edge. A barycentric
        // coordinate lives in [0, 1], so a component above half the offset is
        // unambiguously a lifted one.
        //
        // FaceBorders reads the channel as it stands: a lifted component never
        // comes near zero, so min() never sees the diagonal. Triangles takes
        // the offset back out and gets the plain barycentric triangle, where
        // every one of the three edges reaches zero.
        vec3 lift = step(vec3(EDGE_SUPPRESS_OFFSET * 0.5), edgeCoord) * EDGE_SUPPRESS_OFFSET;
        vec3 b = (edgeMode == 1) ? edgeCoord - lift : edgeCoord;

        // Distance to the nearest edge, in barycentric units, turned into
        // pixels by its own screen-space derivative. That is what keeps the
        // line one weight wide however far away or however steeply tilted the
        // polygon is - the same rule Box3D and VoxelMap edges follow.
        float d = min(min(b.x, b.y), b.z);
        float w = max(fwidth(d), 1e-8);
        float edgeFactor = 1.0 - smoothstep(0.0, w * edgeThickness, d);

        if (edgeFactor > 0.0) {
            // edgeColor wins whenever it is set at all, and "set" means a
            // visible alpha - a fully transparent edge has no meaning, so it is
            // free to serve as the sentinel.
            vec3 e = edgeColor.a > 0.0 ? edgeColor.rgb
                                       : colorOut.rgb * edgeColorFactor;
            finalColor = mix(finalColor, vec4(e, 1.0), edgeFactor);
        }
    }

    BASE_COLOR = finalColor;

    // Toon shading wants a matte surface: no metal, no specular highlight.
    if (useToonShading) {
        METALNESS = 0.0;
        ROUGHNESS = 1.0;
    }
}

// ===== TOON SHADING IMPLEMENTATION =====
// Half-lambert lighting, the same model Box3D uses, so a Poly3D floor and the
// Box3D buildings standing on it read as one scene.

vec3 diffuseToonSimple(in vec3 normal, in vec3 toLightDirection) {
    float NdotL = dot(normal, toLightDirection);
    float value = (NdotL + 1.0) * 0.5;  // Half-lambert formula
    return vec3(value);
}

void DIRECTIONAL_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        DIFFUSE += diffuse * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    } else {
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    }
}

void POINT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION;
    } else {
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION;
    }
}

void SPOT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION * SPOT_FACTOR;
    } else {
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION * SPOT_FACTOR;
    }
}

// Defining these at all replaces Qt's default term with nothing - there is no
// way to opt back in per frame. Toon shading wants them gone, and Box3D makes
// the same trade, so a polygon and a box keep the same matte look.
void SPECULAR_LIGHT() {
}

void IBL_PROBE() {
}
