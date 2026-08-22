// Box3D's cartoon outline, as a part rather than as a file.
//
// Composed into box3d.frag, and into any other fragment shader that draws a
// Box3DGeometry and has to outline it the same way - see clay_compose_shader()
// in cmake/clayshader.cmake. A body part whose material is not box3d.frag still
// has to carry the same line weight as the twenty next to it, and a second
// hand-kept copy of this arithmetic would drift the first time either is
// touched.
//
// Deliberately free of VARYING declarations: every value it needs arrives as a
// parameter, so it can be concatenated ahead of whatever varyings the host
// shader declares. It does read the uniforms the material is expected to carry:
// showEdges, edgeThickness, edgeColorFactor, edgeColor, edgeMask, edgeMode.

// Whether the edge under this fragment is one the mask asked for.
//
// The distances arrive in pixels - .x to u=0, .y to u=1, .z to v=0, .w to v=1 -
// so this test tracks the band clayEdgeMix actually draws at any zoom. A fixed
// UV threshold stops agreeing with it the moment the face is small on screen,
// which clipped masked edges at the wide end of edgeThickness.
bool shouldShowEdge(float faceId, vec4 pixDist, float limit) {
    // First, identify which edge we're on
    bool isLeftEdge = pixDist.x <= limit;
    bool isRightEdge = pixDist.y <= limit;
    bool isBottomEdge = pixDist.z <= limit;
    bool isTopEdge = pixDist.w <= limit;

    // If we're not on any edge, return false
    if (!(isLeftEdge || isRightEdge || isBottomEdge || isTopEdge)) {
        return false;
    }

    // The bit constants are Box3DGeometry::EdgeFlags. Eight bits for twelve
    // edges, so a bit means different things on different faces: bit 3 is the
    // front face's top border AND the left face's left border. Anything
    // choosing a mask has to be read against this table rather than against
    // the combined names, which do not partition.
    int edgeBit = 0;

    if (faceId == 1.0) { // Right face
        if (isTopEdge) edgeBit = 0x10;    // bit 4
        if (isBottomEdge) edgeBit = 0x01; // bit 0
        if (isLeftEdge) edgeBit = 0x40;   // bit 6
        if (isRightEdge) edgeBit = 0x04;  // bit 2
    }
    else if (faceId == 2.0) { // Left face
        if (isTopEdge) edgeBit = 0x20;    // bit 5
        if (isBottomEdge) edgeBit = 0x02; // bit 1
        if (isLeftEdge) edgeBit = 0x08;   // bit 3
        if (isRightEdge) edgeBit = 0x80;  // bit 7
    }
    else if (faceId == 3.0) { // Top face
        if (isLeftEdge) edgeBit = 0x20;   // bit 5
        if (isRightEdge) edgeBit = 0x10;  // bit 4
        if (isBottomEdge) edgeBit = 0x08; // bit 3
        if (isTopEdge) edgeBit = 0x04;    // bit 2
    }
    else if (faceId == 4.0) { // Bottom face
        if (isLeftEdge) edgeBit = 0x02;   // bit 1
        if (isRightEdge) edgeBit = 0x01;  // bit 0
        if (isBottomEdge) edgeBit = 0x40; // bit 6
        if (isTopEdge) edgeBit = 0x80;    // bit 7
    }
    else if (faceId == 5.0) { // Front face
        if (isLeftEdge) edgeBit = 0x02;   // bit 1
        if (isRightEdge) edgeBit = 0x01;  // bit 0
        if (isBottomEdge) edgeBit = 0x80; // bit 7
        if (isTopEdge) edgeBit = 0x08;    // bit 3
    }
    else if (faceId == 6.0) { // Back face
        if (isLeftEdge) edgeBit = 0x20;   // bit 5
        if (isRightEdge) edgeBit = 0x10;  // bit 4
        if (isBottomEdge) edgeBit = 0x04; // bit 2
        if (isTopEdge) edgeBit = 0x40;    // bit 6
    }

    // Check if the edge's bit is set in the mask
    return (edgeMask & edgeBit) != 0;
}

// The outline, mixed over whatever the surface would otherwise have been.
//
// `tint` is the colour the edge darkens FROM, which is not always `base`: a
// shader that draws something on the face - an eye, a label - passes the box's
// own colour here, so the outline stays one continuous line instead of turning
// white where it runs past a white shape.
vec4 clayEdgeMix(vec4 base, vec4 tint, vec2 uv, float faceId, vec3 bary) {
    if (!showEdges) return base;

    float edgeFactor = 0.0;
    bool showThisEdge = true;

    // A line straddles the boundary it marks, so each side draws half of
    // it - the same rule voxel_map.frag follows, and what makes
    // edgeThickness: N mean the same visible width on both types. What
    // used to happen here was a smoothstep ramping out over the whole of
    // edgeThickness in UV space, which reads several times thinner than a
    // voxel grid line at the same setting; the demo carried a x4 factor
    // on the boxes to compensate.
    float halfWidth = edgeThickness * 0.5;

    if (edgeMode == 1) {
        // Triangles: the box's own triangulation, diagonals included. The
        // barycentric coordinate is zero along every edge of the triangle
        // it belongs to, so the smallest of its three components is the
        // distance to the nearest one. edgeMask does not apply here - a
        // triangulation missing some of its lines is not a triangulation.
        // Pixel distance per component from the true screen-space
        // gradient, length(dFdx, dFdy), not fwidth. fwidth is the sum of
        // the two, which on a diagonal - where they are equal - overstates
        // the gradient by up to sqrt(2) and draws the line that much too
        // wide. A face border is axis-aligned and unaffected, so the error
        // shows up precisely as diagonals heavier than the borders they
        // sit between.
        vec3 pix = vec3(
            bary.x / max(length(vec2(dFdx(bary.x), dFdy(bary.x))), 1e-8),
            bary.y / max(length(vec2(dFdx(bary.y), dFdy(bary.y))), 1e-8),
            bary.z / max(length(vec2(dFdx(bary.z), dFdy(bary.z))), 1e-8));
        float p = min(min(pix.x, pix.y), pix.z);
        edgeFactor = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, p);
    } else {
        // FaceBorders: the twelve borders, read off the per-face UVs.
        // Screen-space derivatives give us how much UV one pixel covers,
        // so a UV distance divided by one of them is a pixel count.
        float fwU = max(fwidth(uv.x), 1e-8);
        float fwV = max(fwidth(uv.y), 1e-8);

        // Pixels to each of the four borders of this face
        vec4 pixDist = vec4(uv.x, 1.0 - uv.x, uv.y, 1.0 - uv.y)
                     / vec4(fwU, fwU, fwV, fwV);

        // Solid out to halfWidth, then one pixel of ramp to keep it from
        // aliasing - which is the one thing the voxel grid, with its hard
        // threshold, does worse.
        float p = min(min(pixDist.x, pixDist.y), min(pixDist.z, pixDist.w));
        edgeFactor = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, p);

        // Check if we should show this edge based on the mask
        showThisEdge = shouldShowEdge(faceId, pixDist, halfWidth + 0.5);
    }

    if (edgeFactor > 0.0 && showThisEdge) {
        // edgeColor wins whenever it is set at all, and "set" means a
        // visible alpha - a fully transparent edge has no meaning, so it
        // is free to serve as the sentinel. Without one, "unset" and an
        // opaque black edge would be the same value.
        vec3 e = edgeColor.a > 0.0 ? edgeColor.rgb
                                   : tint.rgb * edgeColorFactor;
        return mix(base, vec4(e, 1.0), edgeFactor);
    }
    return base;
}
