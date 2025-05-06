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
// - float viewportHeight        // still exposed for compatibility, but not used here

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

        if (edgeFactor > 0.0) {
            vec3 edgeColor = colorOut.rgb * edgeColorFactor;
            finalColor = mix(finalColor, vec4(edgeColor, 1.0), edgeFactor);
        }
    }

    BASE_COLOR = finalColor;
}
