// Box3D edge detection vertex shader
VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;

void MAIN()
{
    // Use baseColor from the CustomMaterial if available, else use vertex COLOR
    if (baseColor.a > 0.0) {
        colorOut = baseColor;
    } else {
        colorOut = COLOR;
    }

    // Pass texture coordinates for edge detection
    vUV = UV0;

    // Save original position
    vOrigPosition = VERTEX;

    // Transform to world space
    vec4 worldPos = MODEL_MATRIX * vec4(VERTEX, 1.0);
    vWorldPosition = worldPos.xyz;

    // Calculate view vector (from vertex to camera in world space)
    vViewVec = VIEW_MATRIX[3].xyz - worldPos.xyz;

    // Transform normal to world space
    vNormal = normalize(mat3(MODEL_MATRIX) * NORMAL);

    // Encode face ID for potential use in fragment shader
    // This is helpful for face-specific edge handling
    vec3 absNormal = abs(NORMAL);
    if (absNormal.x > 0.9) {
        vFaceID = NORMAL.x > 0.0 ? 1.0 : 2.0; // Right or Left face
    } else if (absNormal.y > 0.9) {
        vFaceID = NORMAL.y > 0.0 ? 3.0 : 4.0; // Top or Bottom face
    } else {
        vFaceID = NORMAL.z > 0.0 ? 5.0 : 6.0; // Front or Back face
    }
}
