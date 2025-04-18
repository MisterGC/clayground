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
    // Pass the color through (baseColor is auto-connected from CustomMaterial)
    colorOut = baseColor.a > 0.0 ? baseColor : COLOR;

    // Pass through texture coordinates for edge detection
    vUV = UV0;

    // Store original position for edge calculations
    vOrigPosition = VERTEX;

    // Calculate world position for possible use in fragment shader
    vWorldPosition = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Calculate view vector (from vertex to camera)
    vViewVec = VIEW_MATRIX[3].xyz - vWorldPosition;

    // Pass normal (in world space)
    vNormal = normalize(mat3(MODEL_MATRIX) * NORMAL);

    // Determine which face of the cube we're on based on normal
    vec3 absNormal = abs(NORMAL);
    if (absNormal.x > 0.9) {
        vFaceID = NORMAL.x > 0.0 ? 1.0 : 2.0; // Right or Left face
    } else if (absNormal.y > 0.9) {
        vFaceID = NORMAL.y > 0.0 ? 3.0 : 4.0; // Top or Bottom face
    } else {
        vFaceID = NORMAL.z > 0.0 ? 5.0 : 6.0; // Front or Back face
    }
}
