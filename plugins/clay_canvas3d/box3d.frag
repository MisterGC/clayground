// Box3D edge detection fragment shader with screen-space consistent edges

VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;

// Uniforms exposed from the CustomMaterial
// - bool showEdges
// - float edgeThickness         // thickness in pixels
// - float edgeColorFactor
// - int edgeMask                // bit mask for selective edge rendering
// - float viewportHeight        // still exposed for compatibility, but not used here

// Helper function to check if an edge should be displayed based on the mask
bool shouldShowEdge(float faceId, vec2 uv) {
    // First, identify which edge we're on
    bool isLeftEdge = uv.x < 0.05;
    bool isRightEdge = uv.x > 0.95;
    bool isBottomEdge = uv.y < 0.05;
    bool isTopEdge = uv.y > 0.95;

    // If we're not on any edge, return false
    if (!(isLeftEdge || isRightEdge || isBottomEdge || isTopEdge)) {
        return false;
    }

    // Map to the bit constants from Box3DGeometry::EdgeFlags
    // TopEdges = 0x3C (00111100)
    // BottomEdges = 0x03 (00000011)
    // FrontEdges = 0x99 (10011001)
    // BackEdges = 0x66 (01100110)
    // LeftEdges = 0xAA (10101010)
    // RightEdges = 0x55 (01010101)

    // Determine the bit mask for the current edge
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

void MAIN()
{
    vec4 finalColor = colorOut;

    if (showEdges) {
        // Compute distance from nearest U and V edges
        float dU = min(vUV.x, 1.0 - vUV.x);
        float dV = min(vUV.y, 1.0 - vUV.y);

        // Screen-space derivatives give us pixel-relative UV size
        float fwU = fwidth(vUV.x);
        float fwV = fwidth(vUV.y);

        // Convert edgeThickness (pixels) to UV space via fwidth
        float edgeU = smoothstep(0.0, fwU * edgeThickness, dU);
        float edgeV = smoothstep(0.0, fwV * edgeThickness, dV);

        // Combine: 0 near edge, 1 in center; we want the inverse
        float edgeFactor = 1.0 - min(edgeU, edgeV);

        // Check if we should show this edge based on the mask
        bool showThisEdge = shouldShowEdge(vFaceID, vUV);

        if (edgeFactor > 0.0 && showThisEdge) {
            vec3 edgeColor = colorOut.rgb * edgeColorFactor;
            finalColor = mix(finalColor, vec4(edgeColor, 1.0), edgeFactor);
        }
    }

    BASE_COLOR = finalColor;
}
