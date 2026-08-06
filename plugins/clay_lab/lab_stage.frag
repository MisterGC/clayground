// LabStage3D fragment shader - millimeter paper (light) / blueprint (dark),
// computed rather than sampled.
//
// No texture: every rule, every peg mark and the horizon itself is a function
// of the fragment's world XZ. That is what makes the plane legible at any zoom
// - a bitmap raster either blurs when you lean in or turns to moire when you
// pull out, and a lab is a thing you lean into.
//
// The lighting half is the same half-lambert code Box3D and Poly3D run, copied
// rather than shared because CustomMaterial snippets have no #include. A toon
// box standing on this ground has to be lit by the same rule as the ground it
// stands on, or the two read as two pictures.

VARYING vec3 vWorld;

// Uniforms exposed from the CustomMaterial:
// - vec4  sheetColor, tableColor, boardColor   the three paper steps
// - vec4  minorColor, majorColor               the rules
// - vec4  cueColor, edgeColor                  peg marks, work-area boundary
// - float cellSize, majorEvery                 the raster, in world units
// - float minorWidth, majorWidth, edgeWidth    line weights, in PIXELS
// - float cueArm, cueWidth, cueRadius          the snap cue, in PIXELS
// - bool  snapping                             GridMode's mode
// - float toneScale                            what the light rig gives back
// - vec2  workHalf                             half the work area; 0 = none
// - float horizonNear, horizonFar              where the plane dissolves

// World units per pixel along each axis, from the screen-space gradient of the
// coordinate itself.
//
// length(dFdx, dFdy) and not fwidth(): fwidth is |dFdx| + |dFdy|, which for a
// direction where the two are equal overstates the true gradient by up to
// sqrt(2) and lays the line down that much too wide. Poly3D measured it - a
// diagonal came out at 5.33 px against an axis-aligned 4.00 - and a ground
// raster seen at a grazing angle is nothing but diagonals.
vec2 worldPerPixel(vec2 p)
{
    return vec2(max(length(vec2(dFdx(p.x), dFdy(p.x))), 1e-8),
                max(length(vec2(dFdx(p.y), dFdy(p.y))), 1e-8));
}

// Distance, in pixels, to the nearest line of a raster of the given period -
// one component per axis. The fract() is taken on the plain coordinate and the
// gradient on the coordinate too, so the wrap never leaks into the derivative.
vec2 rasterPixels(vec2 p, vec2 wpp, float period)
{
    vec2 d = abs(fract(p / period + 0.5) - 0.5) * period;
    return d / wpp;
}

// One weight wide whatever the distance or the tilt, with a pixel of ramp so
// the line does not crawl while the camera moves.
float ruleMask(vec2 pix, float widthPx)
{
    float d = min(pix.x, pix.y);
    return 1.0 - smoothstep(widthPx * 0.5 - 0.5, widthPx * 0.5 + 0.5, d);
}

// A raster whose cells have shrunk to a few pixels is not a grid any more, it
// is noise - so it is faded out before it can alias. The minor rules go first
// and the major ones survive longer, which is exactly how paper behaves as you
// step back from it.
float densityFade(float period, vec2 wpp)
{
    return smoothstep(2.5, 9.0, period / max(wpp.x, wpp.y));
}

void MAIN()
{
    vec2 p = vWorld.xz;
    vec2 wpp = worldPerPixel(p);

    // --- the paper -------------------------------------------------------
    // Sheet inside the work area, table outside it: the same horizon step the
    // labs used to build out of a table Model with a sheet Model on top of it,
    // except that here it costs no geometry and has no edge to catch the light.
    float sheetMask = 1.0;
    bool hasWork = workHalf.x > 0.0 && workHalf.y > 0.0;
    if (hasWork) {
        vec2 e = (abs(p) - workHalf) / wpp;
        sheetMask = 1.0 - smoothstep(-1.0, 1.0, max(e.x, e.y));
    }
    vec3 paper = mix(tableColor.rgb, sheetColor.rgb, sheetMask);

    // --- the rules -------------------------------------------------------
    float majorPeriod = cellSize * majorEvery;
    vec2 minorPix = rasterPixels(p, wpp, cellSize);
    vec2 majorPix = rasterPixels(p, wpp, majorPeriod);

    float minorFade = densityFade(cellSize, wpp);
    float majorFade = densityFade(majorPeriod, wpp);

    vec3 c = mix(paper, minorColor.rgb, ruleMask(minorPix, minorWidth) * minorFade);
    c = mix(c, majorColor.rgb, ruleMask(majorPix, majorWidth) * majorFade);

    // --- the snap cue ----------------------------------------------------
    // Crosses at the intersections while the raster snaps, dots when placement
    // is free. This is GridMode's contract, and the reason it belongs to the
    // surface: the board itself says which mode you are in, so the mode never
    // has to be looked up. It used to cost one Model per peg.
    //
    // The mark is capped against the cell it sits in: pull the camera back far
    // enough and a 5-pixel arm is wider than the whole cell, at which point the
    // marks merge into a wash instead of thinning out. A third of a cell is the
    // most a peg may ever take.
    float cellPix = cellSize / max(wpp.x, wpp.y);
    float arm = min(cueArm, cellPix * 0.34);
    float cue;
    if (snapping) {
        float halfW = min(cueWidth, cellPix * 0.2) * 0.5;
        float acrossY = 1.0 - smoothstep(halfW - 0.5, halfW + 0.5, minorPix.y);
        float alongX = 1.0 - smoothstep(arm - 0.5, arm + 0.5, minorPix.x);
        float acrossX = 1.0 - smoothstep(halfW - 0.5, halfW + 0.5, minorPix.x);
        float alongY = 1.0 - smoothstep(arm - 0.5, arm + 0.5, minorPix.y);
        cue = max(alongX * acrossY, alongY * acrossX);
    } else {
        float r = min(cueRadius, cellPix * 0.17);
        cue = 1.0 - smoothstep(r - 0.5, r + 0.5, length(minorPix));
    }
    // Only where the work is: a peg raster running to the horizon would be a
    // pattern rather than a cue.
    c = mix(c, cueColor.rgb, cue * minorFade * sheetMask);

    // --- the work-area boundary ------------------------------------------
    // A thin rule where the sheet ends, in place of the rim the labs used to
    // stand around it. Signed distance to the rectangle, so the corners close.
    if (hasWork && edgeWidth > 0.0) {
        vec2 q = abs(p) - workHalf;
        float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
        float pix = abs(sd) / max(wpp.x, wpp.y);
        c = mix(c, edgeColor.rgb,
                (1.0 - smoothstep(edgeWidth * 0.5 - 0.5, edgeWidth * 0.5 + 0.5, pix))
                * 0.75);   // a hint of where the sheet ends, not a frame
    }

    // --- the horizon -----------------------------------------------------
    // The far half of the plane is EMISSIVE rather than lit, so it lands on
    // exactly the clear colour and the quad has no visible edge at all. Fading
    // the base colour towards the sky instead would land on the sky times
    // whatever the light rig happens to be worth, and leave a ring.
    float horizon = smoothstep(horizonNear, horizonFar, length(p));

    // toneScale is what the light rig gives back: three lights all shining
    // down onto one upward-facing plane add up to more than one, so a paper
    // colour handed over raw comes back white. Measured, not guessed - see
    // LabStage3D::toneScale.
    BASE_COLOR = vec4(c * toneScale * (1.0 - horizon), 1.0);
    EMISSIVE_COLOR = boardColor.rgb * horizon;

    // Matte, like everything else in a lab: no metal, no specular highlight.
    METALNESS = 0.0;
    ROUGHNESS = 1.0;
}

// ===== TOON SHADING =====
// Half-lambert, the model Box3D and Poly3D use, so the ground and the objects
// standing on it are lit by one rule. SHADOW_CONTRIB is what makes the plane
// RECEIVE shadows - it casts none itself.

vec3 diffuseToonSimple(in vec3 normal, in vec3 toLightDirection)
{
    float NdotL = dot(normal, toLightDirection);
    return vec3((NdotL + 1.0) * 0.5);   // half-lambert
}

void DIRECTIONAL_LIGHT()
{
    DIFFUSE += diffuseToonSimple(NORMAL, TO_LIGHT_DIR) * BASE_COLOR.rgb
             * LIGHT_COLOR * SHADOW_CONTRIB;
}

void POINT_LIGHT()
{
    DIFFUSE += diffuseToonSimple(NORMAL, TO_LIGHT_DIR) * BASE_COLOR.rgb
             * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION;
}

void SPOT_LIGHT()
{
    DIFFUSE += diffuseToonSimple(NORMAL, TO_LIGHT_DIR) * BASE_COLOR.rgb
             * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION * SPOT_FACTOR;
}

// Defining these at all replaces Qt's default term with nothing, and there is
// no way to opt back in per frame. Box3D and Poly3D make the same trade, which
// is what keeps a box, a prism and the ground matte together.
void SPECULAR_LIGHT()
{
}

void IBL_PROBE()
{
}
