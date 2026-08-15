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
        // edgeCoord is the corner's barycentric coordinate, lifted by a
        // multiple of EDGE_SUPPRESS_OFFSET that says what sits on the other
        // side of the edge opposite that corner:
        //
        //   0x  a rim, with nothing on the other side
        //   1x  an interior diagonal of the triangulation
        //   2x  a seam with another surface of the same object - the cap rim,
        //       a wall's upright or its foot on an extruded polygon
        //
        // A barycentric coordinate lives in [0, 1], so steps at half and one
        // and a half offsets read the multiple back with room to spare, and
        // taking it out again leaves the plain barycentric triangle. The lift
        // is the same on all three corners of a triangle, so it survives
        // interpolation untouched and never disturbs the gradients below.
        vec3 lifted = step(vec3(EDGE_SUPPRESS_OFFSET * 0.5), edgeCoord);
        vec3 seamed = step(vec3(EDGE_SUPPRESS_OFFSET * 1.5), edgeCoord);
        vec3 b = edgeCoord - (lifted + seamed) * EDGE_SUPPRESS_OFFSET;

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

        // Split the three by what kind of edge each one is. A rim has nothing
        // on the other side: only the triangle inside it draws anything, so the
        // outward half of the line falls on nowhere and it must be laid down at
        // full width to read as edgeThickness pixels. Everything shared - an
        // interior diagonal between two triangles, or a seam where a prism's
        // cap meets a wall - is drawn from both sides at half width, which is
        // the straddling rule that makes a box border, a voxel map border and
        // an extruded polygon's border come out the same weight.
        const float kFar = 1.0e6;
        vec3 rimPix  = mix(pix, vec3(kFar), lifted);
        vec3 seamPix = mix(vec3(kFar), pix, seamed);
        vec3 diagPix = mix(vec3(kFar), pix, lifted - seamed);

        // Solid out to the width, then one pixel of ramp so the line does not
        // crawl when the camera moves.
        float halfWidth = edgeThickness * 0.5;
        float rim = 1.0 - smoothstep(edgeThickness - 0.5, edgeThickness + 0.5,
                                     min(min(rimPix.x, rimPix.y), rimPix.z));
        float seam = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5,
                                      min(min(seamPix.x, seamPix.y), seamPix.z));
        float diag = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5,
                                      min(min(diagPix.x, diagPix.y), diagPix.z));

        // Both modes draw the object's face borders - the rims, and the seams
        // between its own surfaces. Triangles adds the triangulation on top.
        float border = max(rim, seam);
        float edgeFactor = (edgeMode == 1) ? max(border, diag) : border;

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
