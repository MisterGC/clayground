// Box3D edge detection fragment shader
VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;

void MAIN()
{
    // Basic lighting calculation
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.8));
    vec3 normal = normalize(vNormal);
    float diffuse = max(0.2, dot(normal, lightDir));

    // Apply basic lighting to the original color
    vec4 finalColor = vec4(colorOut.rgb * diffuse, colorOut.a);

    if (showEdges) {
        // Calculate distance from edges using UV coordinates
        float distanceFromEdgeU = min(vUV.x, 1.0 - vUV.x);
        float distanceFromEdgeV = min(vUV.y, 1.0 - vUV.y);

        // View-dependent edge thickness to maintain consistent edge appearance at different distances
        float viewDistance = length(vViewVec);
        float adjustedThickness = edgeThickness * (1.0 + (viewDistance * viewDistanceFactor));

        // Process edges
        if (distanceFromEdgeU < adjustedThickness || distanceFromEdgeV < adjustedThickness) {
            // Get the minimum distance to any edge
            float minDist = min(distanceFromEdgeU, distanceFromEdgeV);

            // Calculate a smooth transition factor based on distance
            float edgeFactor = smoothstep(0.0, adjustedThickness * edgeFalloff, minDist);

            // Generate the edge color based on the original color, but keep some lighting
            vec3 edgeRGB = colorOut.rgb * edgeDarkness * max(0.5, diffuse);

            // Mix original color with edge color based on distance
            finalColor.rgb = mix(edgeRGB, finalColor.rgb, edgeFactor);

            // Special handling for corners (where both U and V are near edges)
            if (distanceFromEdgeU < adjustedThickness && distanceFromEdgeV < adjustedThickness) {
                // Calculate combined distance for corner effect
                float cornerDist = distanceFromEdgeU + distanceFromEdgeV;
                float cornerFactor = smoothstep(0.0, adjustedThickness * 1.5, cornerDist);

                // Apply darker color at corners, but maintain some lighting
                vec3 cornerRGB = edgeRGB * cornerDarkness;
                finalColor.rgb = mix(cornerRGB, finalColor.rgb, cornerFactor);
            }
        }
    }

    // Ensure alpha is fully opaque
    finalColor.a = 1.0;

    BASE_COLOR = finalColor;
}
