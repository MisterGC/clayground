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
        // Taking the offset back out gives the plain barycentric triangle;
        // the step() that found it also tells us, per component, whether the
        // edge opposite that corner is a diagonal or part of a ring - which is
        // what lets the two be drawn at different widths below.
        vec3 interior = step(vec3(EDGE_SUPPRESS_OFFSET * 0.5), edgeCoord);
        vec3 b = edgeCoord - interior * EDGE_SUPPRESS_OFFSET;

        // Distance to each of the triangle's three edges, in barycentric
        // units, turned into pixels by its own screen-space gradient. That is
        // what keeps a line one weight wide however far away or however
        // steeply tilted the polygon is - the rule Box3D and VoxelMap follow.
        //
        // The gradient is length(dFdx, dFdy) rather than the usual fwidth().
        // fwidth is |dFdx| + |dFdy|, which for a diagonal - where the two are
        // equal - overstates the true gradient by up to sqrt(2) and lays the
        // line down that much too wide. An axis-aligned edge has one of the
        // two at zero, so it is unaffected, and the error shows up exactly as
        // a triangulation whose diagonals are heavier than its outline.
        // Measured on a square at edgeThickness 4: 5.33 px against the rim's
        // 4.00 with fwidth, both 4.00 with this.
        vec3 pix = vec3(b.x / max(length(vec2(dFdx(b.x), dFdy(b.x))), 1e-8),
                        b.y / max(length(vec2(dFdx(b.y), dFdy(b.y))), 1e-8),
                        b.z / max(length(vec2(dFdx(b.z), dFdy(b.z))), 1e-8));

        // Split the three by what kind of edge each one is. A ring edge is the
        // outline of the polygon: only the triangle inside it draws anything,
        // so the outward half of the line falls on nothing and it must be laid
        // down at full width to read as edgeThickness pixels. An interior
        // diagonal is shared by the two triangles either side, so each draws
        // half - the same straddling rule that makes a box border and a voxel
        // map border come out the same weight.
        const float kFar = 1.0e6;
        vec3 ringPix = mix(pix, vec3(kFar), interior);
        vec3 diagPix = mix(vec3(kFar), pix, interior);

        // Solid out to the width, then one pixel of ramp so the line does not
        // crawl when the camera moves.
        float halfWidth = edgeThickness * 0.5;
        float ring = 1.0 - smoothstep(edgeThickness - 0.5, edgeThickness + 0.5,
                                      min(min(ringPix.x, ringPix.y), ringPix.z));
        float diag = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5,
                                      min(min(diagPix.x, diagPix.y), diagPix.z));

        // FaceBorders draws the outline only; Triangles adds the diagonals.
        float edgeFactor = (edgeMode == 1) ? max(ring, diag) : ring;

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
